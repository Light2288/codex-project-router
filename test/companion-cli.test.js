import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import http from "node:http";
import https from "node:https";
import { once } from "node:events";
import { readFile, writeFile, realpath, access } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { configFingerprint } from "../src/config.js";
import { fixture, P1, P2 } from "./helpers/fixtures.js";

const cli = new URL("../src/companion-cli.js", import.meta.url);
function run(input, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [...(options.nodeArgs ?? []), cli.pathname], { stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "", stderr = "";
    child.on("error", reject);
    child.stdout.on("data", b => { stdout += b; });
    child.stderr.on("data", b => { stderr += b; });
    child.stdin.on("error", e => { if (e.code !== "EPIPE") reject(e); });
    child.on("close", code => resolve({ code, stdout, stderr, envelope: JSON.parse(stdout) }));
    child.stdin.end(typeof input === "string" ? input : JSON.stringify(input));
  });
}
test("CLI returns one safe bounded envelope and validates applicable parameters", async t => {
  const f = await fixture(t);
  for (const [id, project] of Object.entries(f.state["local-projects"])) project.name = id === P1 ? "Alpha" : "Beta";
  await f.saveState();
  const result = await run({ schemaVersion: 1, action: "inspect", configPath: null, browseHome: f.dir });
  assert.equal(result.code, 0);
  assert.equal(result.stderr, "");
  assert.equal(result.stdout.trim().split("\n").length, 1);
  assert.deepEqual(result.envelope.result.catalog.entries, [
    { id: P1, name: "Alpha", routeAlias: null, routeState: "unmapped" },
    { id: P2, name: "Beta", routeAlias: null, routeState: "unmapped" },
  ]);
  for (const input of ["{SECRET_SENTINEL", "{}\n{}", [], null,
    { schemaVersion: 2, action: "inspect", configPath: null, browseHome: f.dir },
    { schemaVersion: 1, action: "inspect", configPath: null },
    { schemaVersion: 1, action: "inspect", configPath: "relative" },
    { schemaVersion: 1, action: "inspect", configPath: f.configPath, browseHome: f.dir },
    { schemaVersion: 1, action: "serve", configPath: f.configPath },
    { schemaVersion: 1, action: "rollback", configPath: f.configPath, expectedContext: {} },
    { schemaVersion: 1, action: "inspect", configPath: null, browseHome: f.dir, extra: "SECRET_SENTINEL" },
    " ".repeat(16 * 1024 + 1)]) {
    const failed = await run(input);
    assert.notEqual(failed.code, 0);
    assert.deepEqual(failed.envelope, { schemaVersion: 1, ok: false, error: { code: "CONFIG_INVALID", message: "Router configuration is invalid or unsupported." } });
    assert.equal(failed.stderr, "");
    assert.doesNotMatch(failed.stdout, /SECRET_SENTINEL/);
  }
});
test("CLI rejects response overflow without returning a partial catalog", async t => {
  const f = await fixture(t);
  for (const project of Object.values(f.state["local-projects"])) project.name = "x".repeat(600000);
  await f.saveState();
  const result = await run({ schemaVersion: 1, action: "inspect", configPath: null, browseHome: f.dir });
  assert.notEqual(result.code, 0);
  assert.equal(result.envelope.ok, false);
  assert.ok(Buffer.byteLength(result.stdout) < 1024);
  assert.equal(result.envelope.result, undefined);
});

test("inspection activation and offline rollback never call credentials helpers or destinations", async t => {
  const key = await readFile(new URL("./fixtures/tls/test-only-key.pem", import.meta.url));
  const cert = await readFile(new URL("./fixtures/tls/test-only-cert.pem", import.meta.url));
  for (const credential of [false, true]) {
    const f = await fixture(t), configPath = await realpath(f.configPath);
    for (const project of Object.values(f.state["local-projects"])) project.name = "Synthetic";
    await f.saveState();
    const counts = [0, 0], destinations = [];
    for (let i = 0; i < 2; i++) {
      const destination = https.createServer({ key, cert }, (req, res) => { counts[i]++; res.end("unexpected"); });
      destination.listen(0, "127.0.0.1");
      await once(destination, "listening");
      destinations.push(`https://127.0.0.1:${destination.address().port}/v1`);
      t.after(() => new Promise(resolve => { destination.closeAllConnections(); destination.close(resolve); }));
    }
    f.config.upstreamBaseUrl = destinations[0];
    const reference = { keychainPath: "/REF_SENTINEL.keychain-db", service: "REF_SENTINEL", account: "REF_SENTINEL" };
    if (credential) f.config.credentialRouting = { globalCredential: reference,
      routeTargets: { "route-a": { upstreamBaseUrl: destinations[1], credential: reference } } };
    const ready = http.createServer((req, res) => res.end(JSON.stringify({ service: "codex-project-router", schemaVersion: 1, configFingerprint: configFingerprint(f.config) })));
    ready.listen(0, "127.0.0.1"); await once(ready, "listening");
    t.after(() => new Promise(resolve => ready.close(resolve)));
    f.config.listenPort = ready.address().port;
    await f.saveConfig();
    const marker = join(f.dir, "forbidden-child-used"), guard = join(f.dir, "child-guard.mjs");
    await writeFile(guard, `import cp from "node:child_process";\nimport {writeFileSync} from "node:fs";\nimport {syncBuiltinESMExports} from "node:module";\nfor (const key of ["spawn", "spawnSync", "exec", "execSync", "execFile", "execFileSync", "fork"]) cp[key] = () => { writeFileSync(${JSON.stringify(marker)}, "called"); throw new Error("FORBIDDEN_CHILD_SENTINEL"); };\nsyncBuiltinESMExports();\n`);
    const original = `model_provider = "test_gateway"\nmodel = "synthetic"\n[model_providers.test_gateway]\nbase_url = "${destinations[0]}"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.test_gateway.auth]\ncommand = "/AUTH_COMMAND_SENTINEL"\n`;
    const providerPath = join(f.dir, "config.toml");
    await writeFile(providerPath, original, { mode: 0o600 });
    const nodeArgs = ["--import", pathToFileURL(guard).href];
    const invoke = async input => {
      const result = await run({ schemaVersion: 1, configPath, ...input }, { nodeArgs });
      assert.equal(result.code, 0);
      assert.equal(result.stderr, "");
      assert.doesNotMatch(result.stdout, /REF_SENTINEL|AUTH_COMMAND_SENTINEL|FORBIDDEN_CHILD_SENTINEL|https:/);
      return result.envelope.result;
    };
    const inspected = await invoke({ action: "inspect" });
    assert.equal(inspected.provider.state, "direct");
    assert.equal(inspected.provider.proxyReady, true);
    const expectedContext = inspected.context;
    assert.equal((await invoke({ action: "activate", expectedContext })).state, "active");
    await new Promise(resolve => ready.close(resolve));
    assert.equal((await invoke({ action: "inspect" })).provider.proxyReady, false);
    assert.equal((await invoke({ action: "rollback", expectedContext })).state, "direct");
    assert.equal(await readFile(providerPath, "utf8"), original);
    await assert.rejects(access(marker), { code: "ENOENT" });
    assert.deepEqual(counts, [0, 0]);
  }
});

test("setup preview is a bounded metadata-only one-shot action", async t => {
  const f = await fixture(t), configPath = await realpath(f.configPath);
  await writeFile(join(f.dir,"config.toml"), `model_provider = "test_gateway"\n[model_providers.test_gateway]\nbase_url = "${f.config.upstreamBaseUrl}"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.test_gateway.auth]\ncommand = "/OPAQUE_HELPER_SENTINEL"\nargs = ["SECRET_SENTINEL"]\n`, {mode:0o600});
  const result = await run({schemaVersion:1,action:"setup_preview",configPath});
  assert.equal(result.code,0); assert.equal(result.stderr,""); assert.equal(result.envelope.result.sourceKind,"legacy");
  assert.equal(result.envelope.result.incomingHint,null);
  assert.doesNotMatch(result.stdout,/OPAQUE_HELPER_SENTINEL|SECRET_SENTINEL/);
  const padded=JSON.stringify({schemaVersion:1,action:"setup_preview",configPath})+" ".repeat(20*1024);
  assert.equal((await run(padded)).code,0);
  const old=JSON.stringify({schemaVersion:1,action:"inspect",configPath})+" ".repeat(20*1024);
  assert.equal((await run(old)).envelope.error.code,"CONFIG_INVALID");
  for(const input of [
    JSON.stringify({schemaVersion:1,action:"setup_preview",configPath})+" ".repeat(1024*1024),
    {schemaVersion:1,action:"setup_commit",configPath,expectedContext:{},expectedRevision:"x",operationId:"x",change:{}},
    {schemaVersion:1,action:"setup_preview",configPath,secret:"SECRET_SENTINEL"},
  ]) {
    const failed=await run(input); assert.equal(failed.envelope.ok,false); assert.equal(failed.envelope.error.code,"CONFIG_INVALID"); assert.doesNotMatch(failed.stdout,/SECRET_SENTINEL/);
  }
});

test("setup commit validates native parent lease and returns only saved metadata", async t => {
  const f=await fixture(t), configPath=await realpath(f.configPath);
  await writeFile(join(f.dir,"config.toml"), `model_provider = "test_gateway"\n[model_providers.test_gateway]\nbase_url = "${f.config.upstreamBaseUrl}"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.test_gateway.auth]\ncommand = "/OPAQUE_HELPER_SENTINEL"\n`, {mode:0o600});
  const preview=(await run({schemaVersion:1,action:"setup_preview",configPath})).envelope.result;
  const operationId="aaaaaaaa-1111-4111-8111-111111111111", ref={keychainPath:"/synthetic.keychain-db",service:"synthetic",account:"synthetic"};
  await writeFile(join(f.dir,".activation.lock"),JSON.stringify({pid:process.pid,setupOperationId:operationId,configPath}),{mode:0o600});
  const change={kind:"migrate",accounts:preview.accounts.map(({sourceAlias,...a})=>({...a,credential:ref})),incomingCredential:ref,defaultAccountId:null};
  const committed=await run({schemaVersion:1,action:"setup_commit",configPath,expectedContext:preview.context,expectedRevision:preview.configurationRevision,operationId,change});
  assert.equal(committed.code,0); assert.equal(committed.envelope.result.setupState,"required");
  assert.doesNotMatch(committed.stdout,/OPAQUE_HELPER_SENTINEL|keychain|synthetic|https:/); assert.equal(committed.stderr,"");
});
