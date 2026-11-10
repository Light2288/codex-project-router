import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { writeFile } from "node:fs/promises";
import http from "node:http";
import { fixture } from "./helpers/fixtures.js";
function cli(args) {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, ["src/cli.js", ...args], {
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
test("serve listens on loopback and terminates cleanly on SIGTERM", async (t) => {
  const f = await fixture(t);
  f.config.listenPort = 0;
  await f.saveConfig();
  assert.notEqual((await cli(["serve", "--config", f.configPath])).code, 0);
  const reserve = http.createServer();
  await new Promise((r) => reserve.listen(0, "127.0.0.1", r));
  f.config.listenPort = reserve.address().port;
  await new Promise((r) => reserve.close(r));
  await f.saveConfig();
  const p = spawn(process.execPath, [
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
  p.kill("SIGTERM");
  await new Promise((r) => p.on("exit", r));
  assert.doesNotMatch(stderr, /SENTINEL/);
});
