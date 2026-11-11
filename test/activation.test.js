import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import https from "node:https";
import { once } from "node:events";
import { readFile, writeFile, stat, readdir } from "node:fs/promises";
import { join } from "node:path";
import { parse } from "smol-toml";
import { activate, rollback, status } from "../src/activation.js";
import { configFingerprint } from "../src/config.js";
import { createProxy } from "../src/proxy.js";
import { fixture } from "./helpers/fixtures.js";
const key = await readFile(new URL("./fixtures/tls/test-only-key.pem", import.meta.url));
const cert = await readFile(new URL("./fixtures/tls/test-only-cert.pem", import.meta.url));
async function setup(t, { ready = true, mismatch = false, credentialReader } = {}) {
  const f = await fixture(t);
  const destinationCalls = { global: 0, project: 0 };
  if (credentialReader) {
    const bases = {};
    for (const name of ["global", "project"]) {
      const destination = https.createServer({ key, cert }, (req, res) => {
        destinationCalls[name]++;
        res.end("unexpected destination preflight");
      });
      destination.listen(0, "127.0.0.1");
      await once(destination, "listening");
      bases[name] = `https://127.0.0.1:${destination.address().port}/${name}/v1`;
      t.after(() => {
        destination.closeAllConnections();
        return new Promise(resolve => destination.close(resolve));
      });
    }
    f.config.upstreamBaseUrl = bases.global;
    f.config.credentialRouting = credentialRouting(bases.project);
  }
  const server = credentialReader ? createProxy(f.config, {
    diagnostics: { write() {} },
    credentialReader,
  }) : http.createServer((req, res) => {
    res.setHeader("content-type", "application/json");
    res.end(
      JSON.stringify({
        service: "codex-project-router",
        schemaVersion: 1,
        configFingerprint: mismatch ? "wrong" : configFingerprint(f.config),
      }),
    );
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  f.config.listenPort = server.address().port;
  await f.saveConfig();
  t.after(() => {
    server.closeAllConnections();
    return new Promise((r) => server.close(r));
  });
  if (!ready) await new Promise((r) => server.close(r));
  const original = `# untouched comment\nmodel_provider = "test_gateway"\nmodel = "test-model"\n[model_providers.test_gateway]\nname = "Test"\nbase_url = "${f.config.upstreamBaseUrl}" # preserve comment\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.test_gateway.auth]\ncommand = "/definitely-not-a-key-helper"\nargs = ["SECRET_SENTINEL"]\n`;
  const codexConfigPath = join(f.dir, "config.toml");
  await writeFile(codexConfigPath, original, { mode: 0o600 });
  return {
    ...f,
    original,
    destinationCalls,
    codexConfigPath,
    recordPath: join(f.dir, "activation.json"),
    stopProxy: () => new Promise((r) => server.close(r)),
    localUrl: `http://127.0.0.1:${f.config.listenPort}/v1`,
  };
}
const credentialRouting = (upstreamBaseUrl = "https://project.example.invalid/region/v1") => ({
  globalCredential: { keychainPath: "/nonexistent/synthetic.keychain-db", service: "synthetic-global", account: "synthetic-account" },
  routeTargets: { "route-a": {
    upstreamBaseUrl,
    credential: { keychainPath: "/nonexistent/synthetic.keychain-db", service: "synthetic-project", account: "synthetic-account" },
  } },
});
test("real proxy startup health status activation and recovery avoid credentials and destination preflight", async (t) => {
  let credentialReads = 0;
  const f = await setup(t, {
    credentialReader: async () => {
      credentialReads++;
      throw new Error("control paths must not retrieve credentials");
    },
  });
  assert.equal(credentialReads, 0);
  assert.deepEqual(f.destinationCalls, { global: 0, project: 0 });
  assert.equal((await fetch(`http://127.0.0.1:${f.config.listenPort}/healthz`)).status, 200);
  assert.deepEqual(await status(f.configPath), {
    state: "direct", proxyReady: true, recoveryRequired: false,
  });
  assert.equal((await activate(f.configPath)).changed, true);
  assert.equal((await activate(f.configPath)).changed, false);
  assert.equal((await status(f.configPath)).state, "active");
  assert.equal((await rollback(f.configPath)).state, "direct");
  assert.equal(credentialReads, 0);

  await activate(f.configPath);
  const record = JSON.parse(await readFile(f.recordPath, "utf8"));
  record.phase = "prepared";
  await writeFile(f.recordPath, JSON.stringify(record));
  const edited = f.original.replace('"test-model"', '"changed-model"');
  await writeFile(f.codexConfigPath, edited.replace(f.config.upstreamBaseUrl, f.localUrl));
  await f.stopProxy();
  f.config.credentialRouting.globalCredential.service = "changed-synthetic-global";
  await f.saveConfig();
  assert.equal((await status(f.configPath)).recoveryRequired, true);
  assert.equal((await rollback(f.configPath)).state, "direct");
  assert.equal(await readFile(f.codexConfigPath, "utf8"), edited);
  assert.deepEqual(await status(f.configPath), {
    state: "direct", proxyReady: false, recoveryRequired: false,
  });
  assert.equal(credentialReads, 0);
  assert.deepEqual(f.destinationCalls, { global: 0, project: 0 });
});
for (const runningEnabled of [false, true])
  test(`activation refuses opposite credential routing mode (running ${runningEnabled})`, async (t) => {
    const f = await setup(t);
    const enabled = { ...f.config, credentialRouting: credentialRouting() };
    if (runningEnabled) f.config.credentialRouting = enabled.credentialRouting;
    await writeFile(f.configPath, JSON.stringify(runningEnabled ? { ...f.config, credentialRouting: undefined } : enabled));
    await assert.rejects(activate(f.configPath), { code: "PROXY_NOT_READY" });
    assert.equal((await status(f.configPath)).proxyReady, false);
    assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
    assert.ok(!(await readdir(f.dir)).includes("activation.json"));
  });
test("activation rejects changed target URLs and references while canonical reordering stays ready", async (t) => {
  const f = await setup(t);
  f.config.credentialRouting = credentialRouting();
  const routing = f.config.credentialRouting;
  const reverse = ref => ({ account: ref.account, service: ref.service, keychainPath: ref.keychainPath });
  await writeFile(f.configPath, JSON.stringify({ ...f.config, credentialRouting: {
    routeTargets: { "route-a": {
      credential: reverse(routing.routeTargets["route-a"].credential),
      upstreamBaseUrl: "https://PROJECT.example.invalid:443/region/./v1/",
    } },
    globalCredential: reverse(routing.globalCredential),
  } }));
  assert.equal((await status(f.configPath)).proxyReady, true);
  for (const location of ["global", "route"]) for (const field of ["keychainPath", "service", "account"]) {
    const changed = structuredClone(f.config);
    const reference = location === "global" ? changed.credentialRouting.globalCredential : changed.credentialRouting.routeTargets["route-a"].credential;
    reference[field] += "-changed";
    await writeFile(f.configPath, JSON.stringify(changed));
    await assert.rejects(activate(f.configPath), { code: "PROXY_NOT_READY" });
    assert.equal((await status(f.configPath)).proxyReady, false);
  }
  for (const upstreamBaseUrl of ["https://other.example.invalid/region/v1", "https://project.example.invalid/other/v1"]) {
    const changed = structuredClone(f.config);
    changed.credentialRouting.routeTargets["route-a"].upstreamBaseUrl = upstreamBaseUrl;
    await writeFile(f.configPath, JSON.stringify(changed));
    await assert.rejects(activate(f.configPath), { code: "PROXY_NOT_READY" });
    assert.equal((await status(f.configPath)).proxyReady, false);
  }
  await f.saveConfig();
  assert.equal((await activate(f.configPath)).state, "active");
  assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original.replace(f.config.upstreamBaseUrl, f.localUrl));
  assert.equal((await rollback(f.configPath)).state, "direct");
  assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
});
for (const phase of ["active", "prepared"]) for (const initiallyEnabled of [false, true])
  test(`offline ${phase} recovery tolerates credential routing changes (initially enabled ${initiallyEnabled})`, async (t) => {
    const f = await setup(t);
    if (initiallyEnabled) f.config.credentialRouting = credentialRouting();
    await f.saveConfig();
    await activate(f.configPath);
    const record = JSON.parse(await readFile(f.recordPath, "utf8"));
    assert.equal(Object.hasOwn(record, "credentialRouting"), false);
    record.phase = phase;
    await writeFile(f.recordPath, JSON.stringify(record));
    const edited = f.original.replace('"test-model"', '"changed-model"');
    await writeFile(f.codexConfigPath, edited.replace(f.config.upstreamBaseUrl, f.localUrl));
    f.config.credentialRouting = credentialRouting();
    f.config.credentialRouting.globalCredential.service = "changed-synthetic-global";
    await f.saveConfig();
    await f.stopProxy();
    assert.equal((await rollback(f.configPath)).state, "direct");
    assert.equal(await readFile(f.codexConfigPath, "utf8"), edited);
    assert.deepEqual(await status(f.configPath), { state: "direct", proxyReady: false, recoveryRequired: false });
  });
for (const runningMode of [false, true]) {
  test(`activation refuses opposite title policy (running ${runningMode})`, async (t) => {
    const f = await setup(t);
    f.config.allowUnassignedThreadTitles = runningMode;
    await writeFile(f.configPath, JSON.stringify({...f.config, allowUnassignedThreadTitles: !runningMode}));
    await assert.rejects(activate(f.configPath), {code:"PROXY_NOT_READY"});
    assert.equal((await status(f.configPath)).proxyReady, false);
    assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
    assert.ok(!(await readdir(f.dir)).includes("activation.json"));
  });
  test(`activation refuses opposite observation mode (running ${runningMode})`, async (t) => {
    const f = await setup(t);
    f.config.observeRequestMetadata = runningMode;
    await writeFile(f.configPath, JSON.stringify({...f.config, observeRequestMetadata: !runningMode}));
    await assert.rejects(activate(f.configPath), {code: "PROXY_NOT_READY"});
    assert.equal((await status(f.configPath)).proxyReady, false);
    assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
    assert.ok(!(await readdir(f.dir)).includes("activation.json"));
  });
}
for (const phase of ["active", "prepared"]) for (const replaced of [false, true])
for (const flags of [
  {allowUnassignedThreadTitles:true},
  {observeRequestMetadata:true},
  {allowUnassignedThreadTitles:true, observeRequestMetadata:true},
]) {
  test(`offline ${phase} recovery preserves edits with changed modes ${JSON.stringify(flags)} (replaced ${replaced})`, async (t) => {
    const f = await setup(t);
    await activate(f.configPath);
    const record = JSON.parse(await readFile(f.recordPath,"utf8"));
    assert.equal(Object.hasOwn(record,"allowUnassignedThreadTitles"), false);
    record.phase = phase;
    await writeFile(f.recordPath, JSON.stringify(record));
    const edited = f.original.replace('"test-model"', '"changed-model"');
    await writeFile(f.codexConfigPath, replaced ? edited.replace(f.config.upstreamBaseUrl,f.localUrl) : edited);
    await writeFile(f.configPath, JSON.stringify({...f.config,...flags}));
    await f.stopProxy();
    assert.equal((await rollback(f.configPath)).state,"direct");
    assert.equal(await readFile(f.codexConfigPath,"utf8"),edited);
    assert.deepEqual(await status(f.configPath),{state:"direct",proxyReady:false,recoveryRequired:false});
  });
}
for (const phase of ["active", "prepared"]) {
  test(`legacy ${phase} records roll back offline after an observation mode change`, async (t) => {
    const f = await setup(t);
    await activate(f.configPath);
    const record = JSON.parse(await readFile(f.recordPath, "utf8"));
    assert.equal(Object.hasOwn(record, "observeRequestMetadata"), false);
    record.phase = phase;
    await writeFile(f.recordPath, JSON.stringify(record));
    await writeFile(f.codexConfigPath, (await readFile(f.codexConfigPath, "utf8")).replace('"test-model"', '"changed-model"'));
    await writeFile(f.configPath, JSON.stringify({...f.config, observeRequestMetadata: true}));
    await f.stopProxy();
    assert.equal((await rollback(f.configPath)).state, "direct");
    assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original.replace('"test-model"', '"changed-model"'));
    assert.deepEqual(await status(f.configPath), {state:"direct", proxyReady:false, recoveryRequired:false});
  });
}
test("activation changes only the base URL; rollback preserves later unrelated changes", async (t) => {
  const f = await setup(t);
  const a = await activate(f.configPath);
  assert.equal(a.state, "active");
  assert.equal(a.changed, true);
  assert.equal(a.restartRequired, true);
  const text = await readFile(f.codexConfigPath, "utf8");
  assert.equal(text, f.original.replace(f.config.upstreamBaseUrl, f.localUrl));
  const expected = parse(f.original);
  expected.model_providers.test_gateway.base_url = f.localUrl;
  assert.deepEqual(parse(text), expected);
  await writeFile(
    f.codexConfigPath,
    text.replace('"test-model"', '"changed-model"'),
  );
  assert.equal((await rollback(f.configPath)).state, "direct");
  assert.equal(
    await readFile(f.codexConfigPath, "utf8"),
    f.original.replace('"test-model"', '"changed-model"'),
  );
  assert.doesNotMatch(JSON.stringify(a), /SECRET_SENTINEL|gateway\.example/);
});
test("backups and activation records are private and repeated commands are safe", async (t) => {
  const f = await setup(t);
  await activate(f.configPath);
  const record = JSON.parse(await readFile(f.recordPath, "utf8"));
  assert.equal((await stat(f.recordPath)).mode & 0o777, 0o600);
  assert.equal(
    (await stat(join(f.dir, record.backupFile))).mode & 0o777,
    0o600,
  );
  assert.equal(
    await readFile(join(f.dir, record.backupFile), "utf8"),
    f.original,
  );
  assert.equal((await activate(f.configPath)).changed, false);
  assert.equal((await status(f.configPath)).state, "active");
  assert.equal((await rollback(f.configPath)).changed, true);
  assert.equal((await rollback(f.configPath)).changed, false);
  assert.equal((await status(f.configPath)).state, "direct");
});
for (const option of [{ ready: false }, { mismatch: true }])
  test(`activation requires matching readiness ${JSON.stringify(option)}`, async (t) => {
    const f = await setup(t, option);
    await assert.rejects(activate(f.configPath), { code: "PROXY_NOT_READY" });
    assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
    assert.ok(!(await readdir(f.dir)).includes("activation.json"));
  });
for (const edit of [
  (s) => s.replace("supports_websockets = false", "supports_websockets = true"),
  (s) => 'profile = "other"\n' + s,
  (s) =>
    s
      .replace('base_url = "', 'base_url = """')
      .replace('" # preserve', '""" # preserve'),
  (s) =>
    s.replace(
      'model_provider = "test_gateway"',
      'model_provider = "different"',
    ),
])
  test("unsupported provider/configuration syntax is not rewritten", async (t) => {
    const f = await setup(t);
    const source = edit(f.original);
    await writeFile(f.codexConfigPath, source);
    await assert.rejects(activate(f.configPath), {
      code: "CONFIG_UNSUPPORTED",
    });
    assert.equal(await readFile(f.codexConfigPath, "utf8"), source);
  });
test("rollback refuses an unexpected base URL without overwriting it", async (t) => {
  const f = await setup(t);
  await activate(f.configPath);
  const changed = (await readFile(f.codexConfigPath, "utf8")).replace(
    f.localUrl,
    "https://unexpected.example.invalid/v1",
  );
  await writeFile(f.codexConfigPath, changed);
  await assert.rejects(rollback(f.configPath), { code: "ACTIVATION_CONFLICT" });
  assert.equal(await readFile(f.codexConfigPath, "utf8"), changed);
});
test("a competing helper lock prevents changes", async (t) => {
  const f = await setup(t);
  await writeFile(join(f.dir, ".activation.lock"), "busy", { mode: 0o600 });
  await assert.rejects(activate(f.configPath), { code: "ACTIVATION_CONFLICT" });
  assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
});
for (const alreadyChanged of [false, true])
  test(`rollback recovers an interrupted prepared activation (${alreadyChanged})`, async (t) => {
    const f = await setup(t);
    await activate(f.configPath);
    const record = JSON.parse(await readFile(f.recordPath, "utf8"));
    record.phase = "prepared";
    await writeFile(f.recordPath, JSON.stringify(record));
    if (!alreadyChanged) await writeFile(f.codexConfigPath, f.original);
    assert.equal((await rollback(f.configPath)).state, "direct");
    assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
  });
test("unknown or malformed activation state is not overwritten", async (t) => {
  const f = await setup(t);
  await writeFile(f.recordPath, "{SECRET_SENTINEL", { mode: 0o600 });
  await assert.rejects(
    activate(f.configPath),
    (e) =>
      e.code === "ACTIVATION_CONFLICT" &&
      !e.message.includes("SECRET_SENTINEL"),
  );
  assert.equal(await readFile(f.recordPath, "utf8"), "{SECRET_SENTINEL");
  assert.equal(await readFile(f.codexConfigPath, "utf8"), f.original);
});
