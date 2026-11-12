import nodeTest from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import https from "node:https";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { PassThrough, Writable } from "node:stream";
import { access, readFile, realpath, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { fixture } from "./helpers/fixtures.js";

const sessionId = "44444444-4444-4444-8444-444444444444";
const test = (name, body) => nodeTest(name, { timeout: 15000 }, body);
const requestIds = [
  "55555555-5555-4555-8555-555555555555",
  "66666666-6666-4666-8666-666666666666",
  "77777777-7777-4777-8777-777777777777",
];
const tick = () => new Promise(resolve => setImmediate(resolve));
const frame = (action, requestId = requestIds[0], mode) => JSON.stringify({
  schemaVersion: 1, sessionId, requestId, action,
  ...(mode === undefined ? {} : { mode }),
}) + "\n";

function lines(stream) {
  const values = [], waiters = [];
  let pending = "", ended;
  const finish = () => {
    ended = new Error("Protocol stream ended before reply");
    for (const waiter of waiters.splice(0)) waiter.reject(ended);
  };
  stream.on("end", finish);
  stream.on("close", finish);
  stream.on("error", finish);
  stream.on("data", chunk => {
    pending += chunk;
    while (pending.includes("\n")) {
      const index = pending.indexOf("\n");
      const value = JSON.parse(pending.slice(0, index));
      pending = pending.slice(index + 1);
      const waiter = waiters.shift();
      if (waiter) waiter.resolve(value);
      else values.push(value);
    }
  });
  return { values, next: () => values.length > 0
    ? Promise.resolve(values.shift())
    : ended ? Promise.reject(ended)
    : new Promise((resolve, reject) => waiters.push({ resolve, reject })) };
}

async function availablePort() {
  const reserve = http.createServer();
  await new Promise(resolve => reserve.listen(0, "127.0.0.1", resolve));
  const port = reserve.address().port;
  await new Promise(resolve => reserve.close(resolve));
  return port;
}

async function prepare(t) {
  const f = await fixture(t);
  f.config.listenPort = await availablePort();
  await f.saveConfig();
  return f;
}

async function managed(t, options = {}) {
  const f = await prepare(t);
  if (options.configure) {
    await options.configure(f);
    await f.saveConfig();
  }
  const input = options.input ?? new PassThrough();
  const output = options.output ?? new PassThrough();
  const diagnostics = new PassThrough();
  let diagnosticText = "";
  diagnostics.on("data", chunk => { diagnosticText += chunk; });
  const replies = options.output ? undefined : lines(output);
  const { startManagedRouter } = await import("../src/managed-serve.js");
  const router = await startManagedRouter({
    configPath: await realpath(f.configPath), sessionId, input, output, diagnostics,
  });
  t.after(() => {
    router.closeControl();
    router.server.closeAllConnections();
    return new Promise(resolve => router.server.close(resolve));
  });
  return { ...f, ...router, input, output, replies,
    diagnosticText: () => diagnosticText };
}

async function health(router) {
  const response = await fetch(`http://127.0.0.1:${router.config.listenPort}/healthz`);
  assert.equal(response.status, 200);
  return response.json();
}

// Starting On, leaking config secrets, or probing an upstream before a request breaks this contract.
test("managed start is off before first request", async t => {
  const router = await managed(t);
  const ready = await router.replies.next();
  assert.deepEqual(ready, {
    schemaVersion: 1, type: "ready", sessionId,
    context: { configPath: await realpath(router.configPath),
      codexHome: router.config.codexHome, providerId: "test_gateway",
      listenPort: router.config.listenPort }, mode: "off",
  });
  assert.equal(router.server.address().address, "127.0.0.1");
  await health(router);
});

// A failed pre-ready channel cannot be represented as a usable controlled startup.
test("control bytes before ready suppress ready and leave listener off", async t => {
  const input = new PassThrough();
  input.write(frame("set_mode", requestIds[0], "on"));
  const router = await managed(t, { input });
  await tick();
  assert.equal(router.replies.values.length, 0);
  input.write(frame("set_mode", requestIds[1], "on"));
  await tick();
  await health(router);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "off");
});

// Relative/toggled commands and acknowledgements preceding application break exact absolute results.
test("absolute commands acknowledge applied mode", async t => {
  const router = await managed(t);
  await router.replies.next();
  const initialHealth = await health(router);
  for (const [index, mode] of ["on", "on", "off"].entries()) {
    const requestId = requestIds[index];
    router.input.write(frame("set_mode", requestId, mode));
    assert.deepEqual(await router.replies.next(), {
      schemaVersion: 1, type: "mode", sessionId, requestId, mode,
    });
    router.input.write(frame("get_mode", requestId));
    assert.deepEqual(await router.replies.next(), {
      schemaVersion: 1, type: "mode", sessionId, requestId, mode,
    });
  }
  assert.deepEqual(await health(router), initialHealth);
});

// A parser that loses partial frames or reorders a coalesced pipe batch produces wrong modes/IDs.
test("split and coalesced commands preserve order", async t => {
  const router = await managed(t);
  await router.replies.next();
  const first = frame("set_mode", requestIds[0], "on");
  router.input.write(first.slice(0, 31));
  await tick();
  assert.equal(router.replies.values.length, 0);
  router.input.write(first.slice(31) + frame("get_mode", requestIds[1]) +
    frame("set_mode", requestIds[2], "off"));
  for (const [index, mode] of ["on", "on", "off"].entries())
    assert.deepEqual(await router.replies.next(), {
      schemaVersion: 1, type: "mode", sessionId, requestId: requestIds[index], mode,
    });
});

// Every malformed input must close the control capability rather than accepting a subsequent command.
test("invalid session fields encoding and oversized frames disable control", async t => {
  const base = JSON.parse(frame("get_mode"));
  const cases = [
    { ...base, schemaVersion: 2 }, { ...base, sessionId: requestIds[0] },
    { ...base, requestId: "not-a-uuid" }, { ...base, extra: "SECRET_SENTINEL" },
    { ...base, action: "reload" }, { ...base, action: "set_mode" },
    { ...base, action: "set_mode", mode: "ON" }, { ...base, mode: "off" },
    { ...base, sessionId: 1 }, { ...base, requestId: null }, [], null,
    "{SECRET_SENTINEL\n", Buffer.from([0xff, 0x0a]),
    "\n",
    " ".repeat(16384) + "\n", "x".repeat(65536),
  ];
  for (const [index, invalid] of cases.entries()) await t.test(String(index), async t => {
    const router = await managed(t);
    await router.replies.next();
    router.input.write(frame("set_mode", requestIds[0], "on"));
    await router.replies.next();
    const payload = typeof invalid === "string" || Buffer.isBuffer(invalid)
      ? invalid : JSON.stringify(invalid) + "\n";
    router.input.write(payload);
    await tick();
    router.input.write(frame("set_mode", requestIds[1], "off"));
    await tick();
    assert.equal(router.replies.values.length, 0);
    assert.equal(router.server.listening, true);
    await health(router);
    const completed = router.diagnosticText().trim().split("\n").map(line => JSON.parse(line));
    assert.equal(completed.at(-1).routingMode, "on");
    assert.doesNotMatch(router.diagnosticText(), /SECRET_SENTINEL|SyntaxError|�/);
  });
});

// Continuing to parse while a reply is blocked changes mode without an ordered acknowledgement.
test("blocked output is bounded", async t => {
  let release, blocked = false, retainedInputBytes = 0,
    maxRetainedInputBytes = 0, maxRetainedOutputBytes = 0;
  const input = new PassThrough();
  const originalRead = input.read.bind(input);
  input.read = size => {
    const chunk = originalRead(size);
    if (blocked && chunk && Number.isInteger(size) && size > 0) {
      retainedInputBytes += chunk.length;
      maxRetainedInputBytes = Math.max(maxRetainedInputBytes, retainedInputBytes);
    }
    return chunk;
  };
  const output = new Writable({ highWaterMark: 1, write(chunk, _encoding, done) {
    maxRetainedOutputBytes = Math.max(maxRetainedOutputBytes, output.writableLength);
    if (blocked) release = done;
    else done();
  } });
  const router = await managed(t, { input, output });
  await tick();
  blocked = true;
  input.write(frame("set_mode", requestIds[0], "on"));
  await tick();
  input.write(frame("set_mode", requestIds[1], "off"));
  await tick();
  await health(router);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "on");
  assert.ok(maxRetainedInputBytes <= 32768);
  assert.ok(maxRetainedOutputBytes <= 32768);
  blocked = false;
  release();
  await tick();
  await health(router);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "off");
  blocked = true;
  input.write(frame("set_mode", requestIds[0], "on"));
  await tick();
  input.write(Buffer.alloc(65536, 0x78));
  await tick();
  blocked = false;
  release();
  await tick();
  input.write(frame("set_mode", requestIds[1], "off"));
  await tick();
  await health(router);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "on");
  assert.ok(maxRetainedInputBytes <= 32768);
  assert.ok(maxRetainedOutputBytes <= 32768);
});

// The newline is part of the frame budget; a legal boundary-sized frame still works.
test("frame limit includes newline and preserves split UTF-8", async t => {
  const router = await managed(t);
  await router.replies.next();
  const command = frame("get_mode");
  router.input.write(" ".repeat(16384 - Buffer.byteLength(command)) + command);
  assert.equal((await router.replies.next()).mode, "off");
  const malformed = Buffer.from('{"schemaVersion":1,"type":"é"}\n');
  const split = malformed.indexOf(0xc3) + 1;
  router.input.write(malformed.subarray(0, split));
  await tick();
  router.input.write(malformed.subarray(split));
  await tick();
  router.input.write(frame("set_mode", requestIds[0], "on"));
  await tick();
  assert.equal(router.replies.values.length, 0);
});

// Control EOF/error/explicit close cannot reset mode or stop the HTTP service.
test("control eof preserves last mode and listener", async t => {
  for (const loss of ["eof", "input-error", "output-error", "explicit"]) await t.test(loss, async t => {
    const router = await managed(t);
    await router.replies.next();
    router.input.write(frame("set_mode", requestIds[0], "on"));
    await router.replies.next();
    if (loss === "eof") router.input.end();
    if (loss === "input-error") router.input.emit("error", new Error("SECRET_SENTINEL"));
    if (loss === "output-error") router.output.emit("error", Object.assign(new Error("SECRET_SENTINEL"), { code: "EPIPE" }));
    if (loss === "explicit") router.closeControl();
    await tick();
    if (loss !== "eof") router.input.write(frame("set_mode", requestIds[1], "off"));
    await tick();
    await health(router);
    assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "on");
    assert.equal(router.replies.values.length, 0);
    assert.doesNotMatch(router.diagnosticText(), /SECRET_SENTINEL|EPIPE/);
  });
});

// A dropped control pipe must leave model forwarding usable under its last confirmed mode.
test("model response survives control eof", async t => {
  const key = await readFile(new URL("./fixtures/tls/test-only-key.pem", import.meta.url));
  const cert = await readFile(new URL("./fixtures/tls/test-only-cert.pem", import.meta.url));
  const calls = [];
  const upstream = https.createServer({ key, cert }, (req, res) => {
    calls.push({ url: req.url, authorization: req.headers.authorization });
    req.resume();
    req.on("end", () => res.end("last-mode-forwarding"));
  });
  await new Promise(resolve => upstream.listen(0, "127.0.0.1", resolve));
  t.after(() => { upstream.closeAllConnections(); return new Promise(resolve => upstream.close(resolve)); });
  const previousAgent = https.globalAgent;
  const agent = new https.Agent({ ca: cert });
  https.globalAgent = agent;
  t.after(() => { https.globalAgent = previousAgent; agent.destroy(); });
  const router = await managed(t, { configure: f => {
    f.config.upstreamBaseUrl = `https://127.0.0.1:${upstream.address().port}/v1`;
  } });
  await router.replies.next();
  router.input.write(frame("set_mode", requestIds[0], "on"));
  await router.replies.next();
  router.input.end();
  await tick();
  const response = await fetch(`http://127.0.0.1:${router.config.listenPort}/v1/responses`, {
    method: "POST", headers: { authorization: "Bearer synthetic-token",
      "thread-id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }, body: "synthetic-body",
  });
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "last-mode-forwarding");
  assert.deepEqual(calls, [{ url: "/v1/responses", authorization: "Bearer synthetic-token" }]);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "on");
});

// Importing the managed entry must have no server/process side effects.
test("managed module import does not start a listener", async () => {
  const proc = spawn(process.execPath, ["--input-type=module", "-e", "await import('./src/managed-serve.js')"], {
    cwd: new URL("../", import.meta.url), stdio: ["ignore", "pipe", "pipe"],
  });
  let stdout = "", stderr = "";
  proc.stdout.on("data", chunk => { stdout += chunk; });
  proc.stderr.on("data", chunk => { stderr += chunk; });
  assert.deepEqual(await once(proc, "exit"), [0, null]);
  assert.equal(stdout, "");
  assert.equal(stderr, "");
});

function child(args, nodeArgs = []) {
  return spawn(process.execPath, [...nodeArgs, "src/managed-serve.js", ...args], {
    cwd: new URL("../", import.meta.url), stdio: ["pipe", "pipe", "pipe"],
  });
}

// Loading the real entry and changing modes must never invoke credentials, auth helpers, or upstreams.
test("managed startup performs no credential or upstream lookup", async t => {
  const f = await prepare(t);
  const key = await readFile(new URL("./fixtures/tls/test-only-key.pem", import.meta.url));
  const cert = await readFile(new URL("./fixtures/tls/test-only-cert.pem", import.meta.url));
  let upstreamCalls = 0;
  const upstream = https.createServer({ key, cert }, (_req, res) => {
    upstreamCalls++;
    res.end("unexpected");
  });
  await new Promise(resolve => upstream.listen(0, "127.0.0.1", resolve));
  t.after(() => { upstream.closeAllConnections(); return new Promise(resolve => upstream.close(resolve)); });
  f.config.upstreamBaseUrl = `https://127.0.0.1:${upstream.address().port}/v1`;
  const reference = { keychainPath: "/nonexistent/synthetic.keychain-db", service: "synthetic-service", account: "synthetic-account" };
  f.config.credentialRouting = { globalCredential: reference, routeTargets: {
    "route-a": { upstreamBaseUrl: f.config.upstreamBaseUrl, credential: reference },
  } };
  await f.saveConfig();
  await writeFile(join(f.dir, "config.toml"), '[model_providers.test_gateway.auth]\ncommand = "/definitely-not-a-key-helper"\n');
  const marker = join(f.dir, "unexpected-child-process");
  const preload = join(f.dir, "deny-child-process.mjs");
  await writeFile(preload, `import childProcess from "node:child_process";
import { writeFileSync } from "node:fs";
import { syncBuiltinESMExports } from "node:module";
childProcess.spawn = () => { writeFileSync(${JSON.stringify(marker)}, "attempted"); throw new Error("SECRET_SENTINEL"); };
syncBuiltinESMExports();`);
  const proc = child(["--config", await realpath(f.configPath), "--session", sessionId], ["--import", pathToFileURL(preload).href]);
  t.after(() => proc.kill());
  let stderr = "";
  proc.stderr.on("data", chunk => { stderr += chunk; });
  const replies = lines(proc.stdout);
  assert.equal((await replies.next()).mode, "off");
  for (const [index, mode] of ["on", "off"].entries()) {
    proc.stdin.write(frame("set_mode", requestIds[index], mode));
    assert.deepEqual(await replies.next(), { schemaVersion: 1, type: "mode", sessionId, requestId: requestIds[index], mode });
  }
  proc.stdin.end();
  assert.equal((await fetch(`http://127.0.0.1:${f.config.listenPort}/healthz`)).status, 200);
  await assert.rejects(access(marker), { code: "ENOENT" });
  assert.equal(upstreamCalls, 0);
  assert.doesNotMatch(stderr, /SECRET_SENTINEL|synthetic-service|synthetic-account/);
  const exit = once(proc, "exit");
  proc.kill("SIGTERM");
  assert.deepEqual(await exit, [0, null]);
});

// Invalid startup cannot emit ready, expose raw supplied data, or accept the legacy CLI shape.
test("managed entry rejects malformed configuration and listen failures without ready", async t => {
  const f = await prepare(t);
  const configPath = await realpath(f.configPath);
  const reserve = http.createServer();
  await new Promise(resolve => reserve.listen(f.config.listenPort, "127.0.0.1", resolve));
  t.after(() => new Promise(resolve => reserve.close(resolve)));
  const scenarios = [
    ["--config", configPath, "--session", sessionId],
    ["--config", configPath, "--session", "SECRET_SENTINEL"],
    ["serve", "--config", configPath],
    ["--config", configPath + "/../router.json", "--session", sessionId],
  ];
  for (const args of scenarios) {
    const proc = child(args);
    let stdout = "", stderr = "";
    proc.stdout.on("data", chunk => { stdout += chunk; });
    proc.stderr.on("data", chunk => { stderr += chunk; });
    const [code] = await once(proc, "exit");
    assert.equal(code, 1);
    assert.equal(stdout, "");
    assert.doesNotMatch(stderr, /SECRET_SENTINEL|EADDRINUSE|127\.0\.0\.1|SyntaxError/);
    assert.ok(["CONFIG_INVALID", "PROXY_NOT_READY"].includes(JSON.parse(stderr).error.code));
  }
  await writeFile(f.configPath, "{SECRET_SENTINEL");
  const proc = child(["--config", configPath, "--session", sessionId]);
  let stdout = "", stderr = "";
  proc.stdout.on("data", chunk => { stdout += chunk; });
  proc.stderr.on("data", chunk => { stderr += chunk; });
  assert.equal((await once(proc, "exit"))[0], 1);
  assert.equal(stdout, "");
  assert.equal(JSON.parse(stderr).error.code, "CONFIG_UNAVAILABLE");
  assert.doesNotMatch(stderr, /SECRET_SENTINEL|SyntaxError/);
});
