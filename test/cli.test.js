import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { access, readFile, writeFile } from "node:fs/promises";
import http from "node:http";
import https from "node:https";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { fixture } from "./helpers/fixtures.js";
const key = await readFile(new URL("./fixtures/tls/test-only-key.pem", import.meta.url));
const cert = await readFile(new URL("./fixtures/tls/test-only-cert.pem", import.meta.url));
function cli(args, nodeArgs = []) {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, [...nodeArgs, "src/cli.js", ...args], {
      cwd: new URL("../", import.meta.url),
    });
    let stdout = "",
      stderr = "";
    p.stdout.on("data", (c) => (stdout += c));
    p.stderr.on("data", (c) => (stderr += c));
    p.on("error", reject);
    p.on("exit", (code) => resolve({ code, stdout, stderr }));
  });
}
test("CLI usage and failures never echo supplied arguments or parse errors", async (t) => {
  assert.equal((await cli(["--help"])).code, 0);
  const bad = await cli(["SECRET_SENTINEL"]);
  assert.notEqual(bad.code, 0);
  assert.doesNotMatch(bad.stdout + bad.stderr, /SECRET_SENTINEL/);
  const f = await fixture(t);
  await writeFile(f.configPath, "{CREDENTIAL_SENTINEL");
  const invalid = await cli(["status", "--config", f.configPath]);
  assert.notEqual(invalid.code, 0);
  assert.doesNotMatch(invalid.stdout + invalid.stderr, /SENTINEL|SyntaxError/);
});
for (const routingEnabled of [false, true])
test(`CLI controls and startup avoid credential reads (routing ${routingEnabled})`, async (t) => {
  const f = await fixture(t);
  const destinationCalls = { global: 0, project: 0 }, bases = {};
  for (const name of ["global", "project"]) {
    const destination = https.createServer({ key, cert }, (req, res) => {
      destinationCalls[name]++;
      res.end("unexpected destination preflight");
    });
    await new Promise(resolve => destination.listen(0, "127.0.0.1", resolve));
    bases[name] = `https://127.0.0.1:${destination.address().port}/${name}/v1`;
    t.after(() => {
      destination.closeAllConnections();
      return new Promise(resolve => destination.close(resolve));
    });
  }
  f.config.upstreamBaseUrl = bases.global;
  if (routingEnabled) f.config.credentialRouting = {
    globalCredential: {
      keychainPath: "/nonexistent/synthetic.keychain-db",
      service: "synthetic-global", account: "synthetic-account",
    },
    routeTargets: { "route-a": {
      upstreamBaseUrl: bases.project,
      credential: {
        keychainPath: "/nonexistent/synthetic.keychain-db",
        service: "synthetic-project", account: "synthetic-account",
      },
    } },
  };
  const attemptedChild = join(f.dir, "unexpected-child-process");
  const preloadPath = join(f.dir, "deny-child-process.mjs");
  // Block the real boundary before CLI modules load; even a swallowed lookup
  // leaves evidence, and no test can accidentally contact the user's Keychain.
  await writeFile(preloadPath, `
import childProcess from "node:child_process";
import { writeFileSync } from "node:fs";
import { syncBuiltinESMExports } from "node:module";
childProcess.spawn = () => {
  writeFileSync(${JSON.stringify(attemptedChild)}, "attempted");
  throw new Error("unexpected child process");
};
syncBuiltinESMExports();
`);
  const nodeArgs = ["--import", pathToFileURL(preloadPath).href];
  const original = `model_provider = "test_gateway"
model = "test-model"
[model_providers.test_gateway]
base_url = "${f.config.upstreamBaseUrl}"
wire_api = "responses"
supports_websockets = false
[model_providers.test_gateway.auth]
command = "/definitely-not-a-key-helper"
`;
  const codexConfigPath = join(f.dir, "config.toml");
  await writeFile(codexConfigPath, original);
  f.config.listenPort = 0;
  await f.saveConfig();
  assert.notEqual((await cli(["serve", "--config", f.configPath], nodeArgs)).code, 0);
  const reserve = http.createServer();
  await new Promise((r) => reserve.listen(0, "127.0.0.1", r));
  f.config.listenPort = reserve.address().port;
  await new Promise((r) => reserve.close(r));
  await f.saveConfig();
  const p = spawn(process.execPath, [
    ...nodeArgs,
    "src/cli.js",
    "serve",
    "--config",
    f.configPath,
  ]);
  t.after(() => p.kill());
  let stdout = "",
    stderr = "";
  p.stderr.on("data", (c) => (stderr += c));
  const ready = await new Promise((resolve, reject) => {
    p.stdout.on("data", (c) => {
      stdout += c;
      if (stdout.includes("\n")) resolve(JSON.parse(stdout.trim()));
    });
    p.on("error", reject);
    p.on("exit", (code) => {
      if (!stdout) reject(new Error(`serve exited ${code}`));
    });
  });
  assert.equal(ready.host, "127.0.0.1");
  assert.equal(ready.state, "listening");
  assert.equal((await fetch(`http://127.0.0.1:${f.config.listenPort}/healthz`)).status, 200);
  const inspect = await cli(["status", "--config", f.configPath], nodeArgs);
  assert.equal(inspect.code, 0);
  assert.deepEqual(JSON.parse(inspect.stdout), {
    state: "direct", proxyReady: true, recoveryRequired: false,
  });
  const activation = await cli(["activate", "--config", f.configPath], nodeArgs);
  assert.equal(activation.code, 0);
  assert.equal(JSON.parse(activation.stdout).state, "active");
  await writeFile(codexConfigPath, (await readFile(codexConfigPath, "utf8"))
    .replace('"test-model"', '"changed-model"'));
  p.kill("SIGTERM");
  assert.equal(await new Promise((r) => p.on("exit", r)), 0);
  const recovery = await cli(["rollback", "--config", f.configPath], nodeArgs);
  assert.equal(recovery.code, 0);
  assert.equal(JSON.parse(recovery.stdout).state, "direct");
  assert.equal(await readFile(codexConfigPath, "utf8"),
    original.replace('"test-model"', '"changed-model"'));
  await assert.rejects(access(attemptedChild), { code: "ENOENT" });
  assert.deepEqual(destinationCalls, { global: 0, project: 0 });
  assert.doesNotMatch(stderr, /SENTINEL/);
  assert.doesNotMatch(inspect.stdout + activation.stdout + recovery.stdout,
    /synthetic-global|synthetic-account|synthetic\.keychain-db/);
});
