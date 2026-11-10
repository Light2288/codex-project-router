import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { once } from "node:events";
import { readFile, writeFile, stat, readdir } from "node:fs/promises";
import { join } from "node:path";
import { parse } from "smol-toml";
import { activate, rollback, status } from "../src/activation.js";
import { configFingerprint } from "../src/config.js";
import { fixture } from "./helpers/fixtures.js";
async function setup(t, { ready = true, mismatch = false } = {}) {
  const f = await fixture(t);
  const server = http.createServer((req, res) => {
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
    codexConfigPath,
    recordPath: join(f.dir, "activation.json"),
    localUrl: `http://127.0.0.1:${f.config.listenPort}/v1`,
  };
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
