import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { once } from "node:events";
import fs, { readFile, writeFile, unlink, realpath, symlink, readdir } from "node:fs/promises";
import { syncBuiltinESMExports } from "node:module";
import { join } from "node:path";
import { configFingerprint } from "../src/config.js";
import { activate } from "../src/activation.js";
import { inspectCompanion, runCompanionControl } from "../src/companion.js";
import { fixture, P1, P2 } from "./helpers/fixtures.js";

const P3 = "33333333-3333-4333-8333-333333333333";
const P4 = "44444444-4444-4444-8444-444444444444";
const secret = /gateway\.example|destination-sentinel|REF_SENTINEL|AUTH_COMMAND_SENTINEL|SECRET_SENTINEL/i;
const reference = { keychainPath: "/REF_SENTINEL.keychain-db", service: "REF_SENTINEL", account: "REF_SENTINEL" };
async function setup(t, credential = false) {
  const f = await fixture(t);
  f.configPath = await realpath(f.configPath);
  f.state["local-projects"][P1].name = "Alpha";
  f.state["local-projects"][P2].name = "Beta";
  await f.saveState();
  if (credential) f.config.credentialRouting = {
    globalCredential: reference,
    routeTargets: { "route-a": { upstreamBaseUrl: "https://destination-sentinel.invalid/v1", credential: reference } },
  };
  const ready = http.createServer((req, res) => res.end(JSON.stringify({
    service: "codex-project-router", schemaVersion: 1, configFingerprint: configFingerprint(f.config),
  })));
  ready.listen(0, "127.0.0.1");
  await once(ready, "listening");
  f.config.listenPort = ready.address().port;
  await f.saveConfig();
  const stop = () => new Promise(resolve => ready.close(resolve));
  t.after(stop);
  const original = `model_provider = "test_gateway"\nmodel = "synthetic-model"\n[model_providers.test_gateway]\nbase_url = "${f.config.upstreamBaseUrl}"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.test_gateway.auth]\ncommand = "/AUTH_COMMAND_SENTINEL"\nargs = ["SECRET_SENTINEL"]\n`;
  const providerPath = join(f.dir, "config.toml");
  await writeFile(providerPath, original, { mode: 0o600 });
  return { ...f, original, providerPath, stop };
}
const contextFor = f => ({ configPath: f.configPath, codexHome: f.dir, providerId: "test_gateway", listenPort: f.config.listenPort });
const expectedEntries = credential => [
  { id: P1, name: "Alpha", routeAlias: "route-a", routeState: "mapped" },
  { id: P2, name: "Beta", routeAlias: "route-b", routeState: credential ? "target_missing" : "mapped" },
];

test("inspection projects each mode without secrets", async t => {
  for (const credential of [false, true]) {
    const f = await setup(t, credential);
    const before = await Promise.all([readFile(f.configPath), readFile(f.providerPath), readFile(f.statePath)]);
    const result = await inspectCompanion({ configPath: f.configPath });
    assert.deepEqual(result.configuration, { state: "valid", path: f.configPath, mode: credential ? "credential" : "legacy" });
    assert.deepEqual(result.context, contextFor(f));
    assert.deepEqual(result.provider, { state: "direct", recoveryRequired: false, proxyReady: true, recordPhase: "none" });
    assert.deepEqual(result.catalog, { state: "ready", entries: expectedEntries(credential) });
    assert.match(result.revision, /^[a-f0-9]{64}$/);
    assert.deepEqual(Object.keys(result).sort(), ["catalog", "configuration", "context", "provider", "revision"]);
    assert.doesNotMatch(JSON.stringify(result), secret);
    assert.deepEqual(await Promise.all([readFile(f.configPath), readFile(f.providerPath), readFile(f.statePath)]), before);
  }
});
test("catalog survives provider failure", async t => {
  const f = await setup(t);
  for (const source of ["{SECRET_SENTINEL", f.original.replace("supports_websockets = false", "supports_websockets = true")]) {
    await writeFile(f.providerPath, source);
    const result = await inspectCompanion({ configPath: f.configPath });
    assert.deepEqual(result.catalog, { state: "ready", entries: expectedEntries(false) });
    assert.deepEqual(result.provider, { state: "unavailable", recoveryRequired: true, proxyReady: null, recordPhase: "unavailable" });
    assert.doesNotMatch(JSON.stringify(result), secret);
  }
});
test("new and absent catalog projects remain explicit", async t => {
  const f = await setup(t, true);
  delete f.state["local-projects"][P2];
  f.state["local-projects"][P3] = { id: P3, name: "Alpha" };
  await f.saveState();
  assert.deepEqual((await inspectCompanion({ configPath: f.configPath })).catalog, { state: "ready", entries: [
    { id: P2, name: "", routeAlias: "route-b", routeState: "catalog_missing" },
    { id: P1, name: "Alpha", routeAlias: "route-a", routeState: "mapped" },
    { id: P3, name: "Alpha", routeAlias: null, routeState: "unmapped" },
  ] });
  f.state["local-projects"][P4] = { id: P4, name: "Newest" };
  await f.saveState();
  const browsed = await inspectCompanion({ configPath: null, browseHome: f.dir });
  assert.deepEqual(browsed.configuration, { state: "missing" });
  assert.equal(browsed.catalog.entries.length, 3);
  assert.ok(browsed.catalog.entries.every(e => e.routeAlias === null && e.routeState === "unmapped"));
  assert.equal(f.config.projectRoutes[P4], undefined);
});
test("catalog rejects malformed and normalized conflicting identities without using thread state", async t => {
  const f = await setup(t);
  f.state["thread-project-assignments"] = "ignored SECRET_SENTINEL";
  await f.saveState();
  assert.equal((await inspectCompanion({ configPath: f.configPath })).catalog.state, "ready");
  const id = "abcdefab-abcd-4abc-8abc-abcdefabcdef";
  for (const projects of [null, [], { [P1]: { id: P2, name: "Wrong" } },
    { [P1]: { id: P1 } }, { [P1]: { id: P1, name: 42 } },
    { [id]: { id, name: "First" }, [id.toUpperCase()]: { id, name: "Second" } }]) {
    f.state["local-projects"] = projects;
    await f.saveState();
    const result = await inspectCompanion({ configPath: f.configPath });
    assert.deepEqual(result.catalog, { state: "unavailable", entries: [] });
    assert.equal(result.provider.state, "direct");
    assert.doesNotMatch(JSON.stringify(result), secret);
  }
});
test("catalog preserves exact mapping key semantics", async t => {
  const f = await setup(t);
  const id = "abcdefab-abcd-4abc-8abc-abcdefabcdef";
  f.state["local-projects"] = { [id]: { id: id.toUpperCase(), name: "Case project" } };
  f.config.projectRoutes = { [id.toUpperCase()]: "route-a" };
  await f.saveState(); await f.saveConfig();
  assert.deepEqual((await inspectCompanion({ configPath: f.configPath })).catalog.entries, [
    { id: id.toUpperCase(), name: "", routeAlias: "route-a", routeState: "catalog_missing" },
    { id, name: "Case project", routeAlias: null, routeState: "unmapped" },
  ]);
});
test("mutation rejects changed activation context", async t => {
  const f = await setup(t);
  const expectedContext = contextFor(f);
  for (const change of [{ codexHome: "/different-home" }, { providerId: "different" }, { listenPort: 12345 }, { configPath: f.configPath + ".other" }]) {
    for (const action of ["activate", "rollback"])
      await assert.rejects(runCompanionControl({ action, configPath: f.configPath, expectedContext: { ...expectedContext, ...change } }), { code: "ACTIVATION_CONFLICT" });
  }
  f.config.listenPort++;
  await f.saveConfig();
  await assert.rejects(runCompanionControl({ action: "rollback", configPath: f.configPath, expectedContext }), { code: "ACTIVATION_CONFLICT" });
  assert.equal(await readFile(f.providerPath, "utf8"), f.original);
});
test("controls preserve helper recovery and conflicts in both modes", async t => {
  for (const credential of [false, true]) {
    const f = await setup(t, credential), expectedContext = contextFor(f);
    const control = action => runCompanionControl({ action, configPath: f.configPath, expectedContext });
    assert.deepEqual(await control("activate"), { state: "active", changed: true, restartRequired: true });
    assert.equal((await inspectCompanion({ configPath: f.configPath })).provider.state, "router");
    const recordPath = join(f.dir, "activation.json"), record = JSON.parse(await readFile(recordPath));
    record.phase = "prepared";
    await writeFile(recordPath, JSON.stringify(record));
    assert.equal((await inspectCompanion({ configPath: f.configPath })).provider.recoveryRequired, true);
    const edited = f.original.replace("synthetic-model", "later-model");
    await writeFile(f.providerPath, edited.replace(f.config.upstreamBaseUrl, `http://127.0.0.1:${f.config.listenPort}/v1`));
    f.config.projectRoutes[P3] = "later-route";
    await f.saveConfig(); await f.stop();
    assert.deepEqual(await control("rollback"), { state: "direct", changed: true, restartRequired: true });
    assert.equal(await readFile(f.providerPath, "utf8"), edited);
    assert.equal((await inspectCompanion({ configPath: f.configPath })).provider.recordPhase, "restored");
    for (const remove of [false, true]) {
      if (remove) await unlink(join(f.dir, record.backupFile));
      else await writeFile(join(f.dir, record.backupFile), "changed SECRET_SENTINEL");
      const result = await inspectCompanion({ configPath: f.configPath });
      assert.equal(result.provider.state, "unavailable");
      assert.equal(result.catalog.state, "ready");
      await assert.rejects(control("rollback"), { code: "ACTIVATION_CONFLICT" });
      assert.equal(await readFile(f.providerPath, "utf8"), edited);
    }
  }
});
test("controls retain competing locks and unsupported provider bytes", async t => {
  const f = await setup(t), expectedContext = contextFor(f);
  const lock = join(f.dir, ".activation.lock");
  await writeFile(lock, "busy", { mode: 0o600 });
  await assert.rejects(runCompanionControl({ action: "activate", configPath: f.configPath, expectedContext }), { code: "ACTIVATION_CONFLICT" });
  assert.equal(await readFile(lock, "utf8"), "busy");
  await unlink(lock);
  const source = f.original.replace("supports_websockets = false", "supports_websockets = true");
  await writeFile(f.providerPath, source);
  await assert.rejects(runCompanionControl({ action: "activate", configPath: f.configPath, expectedContext }), { code: "CONFIG_UNSUPPORTED" });
  assert.equal(await readFile(f.providerPath, "utf8"), source);
});

for (const action of ["activate", "rollback"]) {
  for (const replacement of ["same-path configuration replacement", "symlink retarget"]) {
    test(`${action} rejects ${replacement} after companion validation before any lock or write`, async t => {
      const a = await setup(t), b = await setup(t);
      const originalConfiguration = await readFile(a.configPath);
      if (replacement === "symlink retarget") {
        // Only canonical configuration/recovery location differs; home/provider/port remain authorized A.
        Object.assign(b.config, a.config);
        await b.saveConfig();
      }
      if (action === "rollback") {
        if (replacement === "symlink retarget") await activate(b.configPath);
        else {
          // Leave valid B recovery evidence where the replacement would load it.
          await writeFile(a.configPath, JSON.stringify(b.config));
          await activate(a.configPath);
          await writeFile(a.configPath, originalConfiguration);
        }
      }
      const snapshot = async f => Object.fromEntries(await Promise.all(
        (await readdir(f.dir)).filter(name => !(f === a && name === "router.json"))
          .map(async name => [name, await readFile(join(f.dir, name))]),
      ));
      const before = await Promise.all([snapshot(a), snapshot(b)]);
      const originalRead = fs.readFile, originalOpen = fs.open;
      let replaced = false;
      const locks = [];
      // Keep real reads/writes; replace only the scheduling window after validation's read of A.
      t.mock.method(fs, "readFile", async (path, ...args) => {
        const bytes = await originalRead(path, ...args);
        if (path === a.configPath && !replaced) {
          replaced = true;
          if (replacement === "symlink retarget") {
            await unlink(a.configPath);
            await symlink(b.configPath, a.configPath);
          } else await writeFile(a.configPath, JSON.stringify(b.config));
        }
        return bytes;
      });
      t.mock.method(fs, "open", async (path, ...args) => {
        if (String(path).endsWith(".activation.lock")) locks.push(path);
        return originalOpen(path, ...args);
      });
      syncBuiltinESMExports();
      try {
        await assert.rejects(runCompanionControl({ action, configPath: a.configPath, expectedContext: contextFor(a) }),
          { code: "ACTIVATION_CONFLICT" });
      } finally {
        t.mock.restoreAll();
        syncBuiltinESMExports();
      }
      assert.equal(replaced, true);
      assert.deepEqual(locks, []);
      assert.deepEqual(await Promise.all([snapshot(a), snapshot(b)]), before);
      if (replacement === "symlink retarget") assert.equal(await realpath(a.configPath), b.configPath);
      else assert.equal(await readFile(a.configPath, "utf8"), JSON.stringify(b.config));
    });
  }
}
