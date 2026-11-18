import nodeTest from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import https from "node:https";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { PassThrough, Writable } from "node:stream";
import { access, readFile, realpath, writeFile, open, lstat, rename, chmod, mkdir, symlink } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { fixture, accountRouting, P1, P2, A1, A2 } from "./helpers/fixtures.js";

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
    ...(options.commitAssignment ? { commitAssignment: options.commitAssignment } : {}),
    ...(options.readAssignmentState ? { readAssignmentState: options.readAssignmentState } : {}),
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

// Losing the companion's diagnostic pipe must not crash the owned listener or reset mode.
test("broken stderr preserves managed mode and HTTP listener", async t => {
  const f = await prepare(t);
  const proc = child(["--config", await realpath(f.configPath), "--session", sessionId]);
  t.after(() => proc.kill());
  const exit = once(proc, "exit");
  const replies = lines(proc.stdout);
  assert.equal((await replies.next()).mode, "off");
  proc.stdin.write(frame("set_mode", requestIds[0], "on"));
  assert.equal((await replies.next()).mode, "on");
  const diagnosticClose = once(proc.stderr, "close");
  proc.stderr.destroy();
  await diagnosticClose;
  for (let index = 0; index < 2; index++) {
    const response = await fetch(`http://127.0.0.1:${f.config.listenPort}/healthz`);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).service, "codex-project-router");
    proc.stdin.write(frame("get_mode", requestIds[index + 1]));
    assert.deepEqual(await replies.next(), {
      schemaVersion: 1, type: "mode", sessionId, requestId: requestIds[index + 1], mode: "on",
    });
  }
  assert.equal(proc.exitCode, null);
  proc.kill("SIGTERM");
  assert.deepEqual(await exit, [0, null]);
});

// Loading the real entry and changing modes must never invoke credentials, auth helpers, or upstreams.
for (const schemaVersion of [1, 2])
test(`managed startup performs no credential or upstream lookup (schema ${schemaVersion})`, async t => {
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
  if (schemaVersion === 2) {
    f.config.schemaVersion = 2;
    delete f.config.credentialRouting;
    f.config.accountRouting = accountRouting();
    f.state["local-projects"][P1].name = "Alpha";
    f.state["local-projects"][P2].name = "Beta";
    await f.saveState();
  }
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
  const ready = await replies.next();
  assert.equal(ready.mode, "off");
  if (schemaVersion === 2) {
    assert.deepEqual(ready.capabilities, ["project_assignments_v1"]);
    proc.stdin.write(assignmentFrame("get_assignment", { expectedContext: ready.context, projectId: P1, operationId: null }));
    const state = (await replies.next()).state;
    assert.equal(typeof state.catalogRevision, "string", "assignment fixture requires a healthy named catalog");
    proc.stdin.write(assignmentChange({ context: ready.context }, state, { accountId: null }));
    const result = await replies.next();
    assert.equal(result.outcome, "applied");
    assert.equal(result.state.runningAssignment.kind, "inherited");
  }
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


// A startup and native consent/commit share exactly one exclusive lock boundary.
test("startup lease excludes setup through load and bind", async t => {
  const { withRouterStartupLock } = await import("../src/managed-serve.js");
  assert.equal(typeof withRouterStartupLock, "function");
  const f = await prepare(t), lockPath = join(f.dir, ".activation.lock");
  const entered = Promise.withResolvers(), release = Promise.withResolvers();
  t.after(() => release.resolve());
  const pending = withRouterStartupLock(f.configPath, async config => {
    assert.equal(config.listenPort, f.config.listenPort);
    entered.resolve();
    await release.promise;
  });
  await entered.promise;
  await assert.rejects(open(lockPath, "wx", 0o600), { code: "EEXIST" });
  await assert.rejects(withRouterStartupLock(f.configPath, () => assert.fail("competing bind")), { code: "ACTIVATION_CONFLICT" });
  assert.equal((await lstat(lockPath)).mode & 0o077, 0);
  release.resolve();
  await pending;
  await assert.rejects(access(lockPath), { code: "ENOENT" });
});
test("startup does not remove replaced or unsafe locks", async t => {
  const { withRouterStartupLock } = await import("../src/managed-serve.js");
  assert.equal(typeof withRouterStartupLock, "function");
  for (const kind of ["replacement", "permissions", "symlink"]) {
    const f = await prepare(t), lockPath = join(f.dir, ".activation.lock"), preserved = join(f.dir, "held-startup-lock");
    await assert.rejects(withRouterStartupLock(f.configPath, async () => {
      if (kind === "permissions") await chmod(lockPath, 0o644);
      else {
        await rename(lockPath, preserved);
        if (kind === "symlink") await symlink(preserved, lockPath);
        else await writeFile(lockPath, "replacement", {mode: 0o600});
      }
    }), { code: "ACTIVATION_CONFLICT" });
    if (kind === "replacement") assert.equal(await readFile(lockPath, "utf8"), "replacement");
    else if (kind === "permissions") assert.equal((await lstat(lockPath)).mode & 0o077, 0o044);
    else assert.equal((await lstat(lockPath)).isSymbolicLink(), true);
  }
});
test("managed startup rejects setup state and every existing lock before binding", async t => {
  const { startManagedRouter } = await import("../src/managed-serve.js");
  for (const kind of ["setup", "stale", "malformed", "unsafe", "directory", "symlink", "required", "invalid"]) {
    const f = await prepare(t), lockPath = join(f.dir, ".activation.lock");
    if (kind === "required" || kind === "invalid") {
      f.config.schemaVersion = 2;
      f.config.accountRouting = accountRouting();
      if (kind === "required") f.config.accountRouting.defaultAccountId = null;
      else f.config.accountRouting.extra = "invalid";
      await f.saveConfig();
    } else if (kind === "directory") await mkdir(lockPath, {mode: 0o700});
    else if (kind === "symlink") await symlink(f.configPath, lockPath);
    else await writeFile(lockPath, kind === "malformed" ? "{" : JSON.stringify(kind === "setup"
      ? { pid: process.pid, setupOperationId: requestIds[0], configPath: await realpath(f.configPath) }
      : {pid: 2147483647}), {mode: kind === "unsafe" ? 0o644 : 0o600});
    const input = new PassThrough(), output = new PassThrough();
    let ready = "";
    output.on("data", chunk => ready += chunk);
    let unexpectedlyStarted;
    await assert.rejects(async () => {
      unexpectedlyStarted = await startManagedRouter({configPath: await realpath(f.configPath), sessionId, input, output, diagnostics: new PassThrough()});
      unexpectedlyStarted.server.closeAllConnections();
      await new Promise(resolve => unexpectedlyStarted.server.close(resolve));
    }, {code: kind === "required" ? "ACCOUNT_SETUP_REQUIRED" : kind === "invalid" ? "ACCOUNT_SETUP_INVALID" : "ACTIVATION_CONFLICT"});
    assert.equal(ready, "");
    if (!["required", "invalid"].includes(kind)) await lstat(lockPath);
  }
});

test("shared configuration lock retains startup compatibility alias and rejects canonical directory replacement",async t=>{
  const {withConfigurationLock}=await import("../src/configuration-lock.js");
  const {withRouterStartupLock}=await import("../src/managed-serve.js");
  assert.equal(withRouterStartupLock,withConfigurationLock);
  const f=await prepare(t), moved=f.dir+"-moved";
  const fs=await import("node:fs/promises");
  t.after(()=>fs.rm(moved,{recursive:true,force:true}));
  await assert.rejects(withConfigurationLock(f.configPath,async(config,lease)=>{
    assert.equal(config.listenPort,f.config.listenPort);
    await fs.rename(f.dir,moved);await fs.mkdir(f.dir,{mode:0o700});
    await writeFile(join(f.dir,".activation.lock"),"replacement",{mode:0o600});
    await lease.assertUnchanged();
  }),{code:"ACTIVATION_CONFLICT"});
  assert.equal(await readFile(join(f.dir,".activation.lock"),"utf8"),"replacement");
  assert.ok((await lstat(join(moved,".activation.lock"))).isFile());
});


const assignmentFrame = (action, fields = {}, requestId = requestIds[0]) => JSON.stringify({
  schemaVersion: 1, sessionId, requestId, action, ...fields,
}) + "\n";
async function assignmentRouter(t, options = {}) {
  const router = await managed(t, { ...options, async configure(f) {
    f.config.codexHome = await realpath(f.dir);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    f.state["local-projects"][P1].name = "Café project";
    f.state["local-projects"][P2].name = "Beta";
    await f.saveState();
    await options.configure?.(f);
  } });
  const ready = await router.replies?.next();
  if (ready) assert.deepEqual(ready.capabilities, ["project_assignments_v1"]);
  return { ...router, context: ready?.context };
}
async function assignmentState(router, { projectId = P1, operationId = null, requestId = requestIds[0] } = {}) {
  router.input.write(assignmentFrame("get_assignment", { expectedContext: router.context, projectId, operationId }, requestId));
  const reply = await router.replies.next();
  assert.equal(reply.type, "assignment_state");
  return reply.state;
}
function assignmentChange(router, state, fields = {}, requestId = requestIds[1]) {
  return assignmentFrame("set_assignment", {
    expectedContext: router.context, expectedSavedRevision: state.savedRevision,
    expectedConfigurationIdentity: state.savedIdentity, expectedRunningRevision: state.runningRevision,
    expectedCatalogRevision: state.catalogRevision, projectId: P1, accountId: A1, ...fields,
  }, requestId);
}

// A reply before persistence/publication or a startup-only getter reports the wrong live snapshot.
test("owned assignment command acknowledges durable published snapshot", async t => {
  const router = await assignmentRouter(t), before = await assignmentState(router);
  assert.equal(before.mode, "off");
  router.input.write(frame("set_mode", requestIds[0], "on") + assignmentChange(router, before) + frame("get_mode", requestIds[2]));
  assert.equal((await router.replies.next()).mode, "on");
  const reply = await router.replies.next();
  assert.equal(reply.type, "assignment_result");
  assert.equal(reply.outcome, "applied");
  assert.equal(reply.code, null);
  assert.equal(reply.commit.operationId, requestIds[1]);
  assert.equal(reply.commit.beforeRevision, before.savedRevision);
  assert.equal(reply.state.savedRevision, reply.state.runningRevision);
  assert.equal(reply.state.savedIdentity, reply.state.runningIdentity);
  assert.equal(reply.state.mode, "on");
  assert.equal(reply.state.runningAssignment.account.id, A1);
  assert.equal(reply.state.lastAttempt.outcome, "applied");
  assert.equal((await health(router)).configFingerprint, reply.state.runningFingerprint);
  assert.notEqual(reply.state.runningFingerprint, before.runningFingerprint);
  assert.equal((await router.replies.next()).mode, "on");
  await assert.rejects(access(join(router.dir, ".activation.lock")), { code: "ENOENT" });
  const disk = JSON.parse(await readFile(router.configPath, "utf8"));
  assert.equal(disk.projectRoutes[P1], "assignment-66666666666646668666666666666666");
  const inherited = await assignmentState(router);
  router.input.write(assignmentChange(router, inherited, { accountId: null }, requestIds[2]));
  const removed = await router.replies.next();
  assert.equal(removed.outcome, "applied");
  assert.equal(removed.state.runningAssignment.kind, "inherited");
  assert.equal(removed.state.mode, "on");
  assert.equal(Object.hasOwn(JSON.parse(await readFile(router.configPath, "utf8")).projectRoutes, P1), false);
  const unselected = await assignmentState(router, { projectId: null });
  assert.equal(unselected.projectId, null);
  assert.equal(unselected.savedAssignment, null);
  assert.equal(unselected.runningAssignment, null);
  assert.equal(unselected.intent, null);
  assert.equal(unselected.lastAttempt, null);
  assert.doesNotMatch(JSON.stringify(reply), /upstreamBaseUrl|keychainPath|synthetic-incoming|projectRoutes|routeAccounts/);
});

// A read queued behind a renamed-but-unsettled writer cannot be treated as completed reconciliation.
test("queued read waits for uncertain write to settle", async t => {
  const fs = await import("node:fs/promises");
  const { commitProjectAssignment } = await import("../src/project-assignments.js");
  const renamed = Promise.withResolvers(), release = Promise.withResolvers();
  t.after(() => release.resolve());
  let settled = false, reconciliationWasReturnedBeforeWriteSettled = false;
  const router = await assignmentRouter(t, { async commitAssignment(input, options) {
    try { return await commitProjectAssignment(input, { ...options, fs: { ...fs, async rename(...args) {
      await fs.rename(...args); renamed.resolve(); await release.promise;
      throw new Error("PRIVATE_RENAME_FAILURE");
    } } }); } finally { settled = true; }
  } });
  const before = await assignmentState(router);
  router.input.write(assignmentChange(router, before));
  await renamed.promise;
  router.input.write(assignmentFrame("get_assignment", { expectedContext: router.context, projectId: P1,
    operationId: requestIds[1] }, requestIds[2]));
  const pendingResult = router.replies.next();
  pendingResult.then(() => { reconciliationWasReturnedBeforeWriteSettled = !settled; });
  await tick();
  assert.equal(router.replies.values.length, 0);
  assert.equal((await health(router)).configFingerprint, before.runningFingerprint);
  release.resolve();
  const result = await pendingResult;
  assert.equal(result.type, "assignment_result");
  assert.equal(result.outcome, "uncertain");
  assert.equal(result.code, "ASSIGNMENT_UNCERTAIN");
  assert.equal(result.commit, null);
  const stateReply = await router.replies.next();
  assert.equal(stateReply.type, "assignment_state");
  assert.equal(reconciliationWasReturnedBeforeWriteSettled, false);
  assert.equal(stateReply.state.lastAttempt.outcome, "uncertain");
  assert.equal(stateReply.state.lastAttempt.code, "ASSIGNMENT_UNCERTAIN");
  assert.equal(stateReply.state.savedRevision, stateReply.state.intent.candidateRevision);
  assert.equal(stateReply.state.runningRevision, before.runningRevision);
  assert.notEqual(stateReply.state.savedRevision, stateReply.state.runningRevision);
  assert.equal(stateReply.state.mode, "off");
  assert.doesNotMatch(router.diagnosticText(), /PRIVATE_RENAME_FAILURE/);
  // Fresh saved tokens cannot turn divergence into a live finish-applying command.
  router.input.write(assignmentChange(router, stateReply.state, { accountId: A2 }, requestIds[0]));
  assert.equal((await router.replies.next()).outcome, "rejected");
});

// Stale/context/catalog/account checks must reject without rewriting or publishing any candidate.
test("stale revisions context account or catalog reject unchanged", async t => {
  const cases = [
    { expectedSavedRevision: "0".repeat(64) }, { expectedRunningRevision: "0".repeat(64) },
    { expectedConfigurationIdentity: "0".repeat(64) }, { expectedCatalogRevision: "0".repeat(64) },
    { accountId: "99999999-9999-4999-8999-999999999999" },
    { projectId: "99999999-9999-4999-8999-999999999999" },
    { expectedContext: "different" },
  ];
  for (const fields of cases) await t.test(Object.keys(fields)[0], async t => {
    const router = await assignmentRouter(t), before = await assignmentState(router);
    const source = await readFile(router.configPath);
    if (fields.expectedContext) fields.expectedContext = { ...router.context, providerId: "different" };
    router.input.write(assignmentChange(router, before, fields));
    const reply = await router.replies.next();
    assert.equal(reply.outcome, "rejected");
    assert.ok(["ASSIGNMENT_CONFLICT", "ASSIGNMENT_INVALID"].includes(reply.code));
    assert.equal(reply.commit, null);
    assert.deepEqual(await readFile(router.configPath), source);
    assert.equal((await health(router)).configFingerprint, before.runningFingerprint);
    assert.equal((await assignmentState(router)).runningRevision, before.runningRevision);
  });
  for (const drift of ["catalog", "same-bytes", "assignment"]) await t.test(drift, async t => {
    const router = await assignmentRouter(t), before = await assignmentState(router);
    if (drift === "catalog") { router.state["local-projects"][P1].name = "Changed"; await router.saveState(); }
    else if (drift === "same-bytes") {
      const other = join(router.dir, "replacement");
      await writeFile(other, await readFile(router.configPath), { mode: 0o600 }); await rename(other, router.configPath);
    } else { delete router.config.projectRoutes[P1]; await router.saveConfig(); }
    const source = await readFile(router.configPath);
    // Even a fresh read is for recovery; it cannot authorize applying a divergent saved baseline.
    const fresh = await assignmentState(router);
    router.input.write(assignmentChange(router, drift === "catalog" ? before : fresh));
    const reply = await router.replies.next();
    assert.equal(reply.outcome, "rejected");
    assert.equal(reply.code, "ASSIGNMENT_CONFLICT");
    assert.deepEqual(await readFile(router.configPath), source);
    assert.equal(reply.state.runningRevision, before.runningRevision);
    assert.equal((await health(router)).configFingerprint, before.runningFingerprint);
  });
});

// Input/output/control loss after acceptance cannot cancel durability or reset On/Off.
test("control loss does not cancel accepted write or listener", async t => {
  const { commitProjectAssignment } = await import("../src/project-assignments.js");
  for (const loss of ["eof", "input-error", "output-error", "explicit", "overflow", "malformed"]) await t.test(loss, async t => {
    const entered = Promise.withResolvers(), release = Promise.withResolvers(), completed = Promise.withResolvers();
    t.after(() => release.resolve());
    const router = await assignmentRouter(t, { async commitAssignment(...args) {
      entered.resolve(); await release.promise;
      try { return await commitProjectAssignment(...args); } finally { completed.resolve(); }
    } });
    const before = await assignmentState(router);
    router.input.write(frame("set_mode", requestIds[0], "on")); await router.replies.next();
    router.input.write(assignmentChange(router, before)); await entered.promise;
    if (loss === "eof") router.input.end();
    if (loss === "input-error") router.input.emit("error", new Error("PRIVATE_CONTROL"));
    if (loss === "output-error") router.output.emit("error", new Error("PRIVATE_CONTROL"));
    if (loss === "explicit") router.closeControl();
    if (loss === "overflow") router.input.write(Buffer.alloc(65536, 0x78));
    if (loss === "malformed") router.input.write("invalid\n");
    await tick(); release.resolve(); await completed.promise; await tick();
    const disk = JSON.parse(await readFile(router.configPath, "utf8"));
    assert.equal(disk.accountRouting.routeAccounts[disk.projectRoutes[P1]], A1);
    assert.notEqual((await health(router)).configFingerprint, before.runningFingerprint);
    assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "on");
    assert.equal(router.server.listening, true);
    assert.doesNotMatch(router.diagnosticText(), /PRIVATE_CONTROL/);
  });
});

// Assignment protocol never grants an account/default/static configuration reload.
test("saved static drift never reloads", async t => {
  for (const kind of ["default", "incoming", "endpoint", "flag"]) await t.test(kind, async t => {
    const router = await assignmentRouter(t), before = await assignmentState(router);
    if (kind === "default") router.config.accountRouting.defaultAccountId = A2;
    if (kind === "incoming") router.config.accountRouting.incomingCredential.service = "Changed";
    if (kind === "endpoint") router.config.accountRouting.accounts[A1].upstreamBaseUrl = "https://changed.example.invalid/v1";
    if (kind === "flag") router.config.observeRequestMetadata = true;
    await router.saveConfig();
    const fresh = await assignmentState(router), source = await readFile(router.configPath);
    router.input.write(assignmentChange(router, fresh));
    const reply = await router.replies.next();
    assert.equal(reply.outcome, "rejected");
    assert.equal(reply.code, "ASSIGNMENT_CONFLICT");
    assert.deepEqual(await readFile(router.configPath), source);
    assert.equal((await health(router)).configFingerprint, before.runningFingerprint);
  });
});

test("runtime summary retains running account name after disk edit", async t => {
  const router = await assignmentRouter(t), before = await assignmentState(router);
  router.config.accountRouting.accounts[A2].displayName = "Renamed saved account";
  await router.saveConfig();
  const state = await assignmentState(router);
  assert.equal(state.savedAssignment.account.displayName, "Renamed saved account");
  assert.equal(state.runningAssignment.account.displayName, "Project account");
  assert.equal(state.runningRevision, before.runningRevision);
  await writeFile(router.configPath, "unavailable source");
  const unavailable = await assignmentState(router);
  assert.equal(unavailable.savedState, "unavailable");
  assert.equal(unavailable.savedRevision, null);
  assert.equal(unavailable.runningRevision, before.runningRevision);
  assert.equal(unavailable.runningAssignment.account.displayName, "Project account");
  assert.equal(unavailable.mode, "off");
});

// Missing optional capability leaves schema-1 children mode-only and cannot grant writes.
test("mode-only startup does not grant assignment capability", async t => {
  const router = await managed(t), ready = await router.replies.next();
  assert.equal(Object.hasOwn(ready, "capabilities"), false);
  const source = await readFile(router.configPath);
  router.input.write(assignmentFrame("set_assignment", { expectedContext: ready.context,
    expectedSavedRevision: "0".repeat(64), expectedConfigurationIdentity: "0".repeat(64),
    expectedRunningRevision: "0".repeat(64), expectedCatalogRevision: "0".repeat(64), projectId: P1, accountId: null }));
  await tick();
  assert.equal(router.replies.values.length, 0);
  assert.deepEqual(await readFile(router.configPath), source);
  assert.equal(router.server.listening, true);
});

// Assignment frames keep the exact field/null/token rules and close malformed channels safely.
test("assignment frames reject wrong excess missing and invalid UTF-8 fields", async t => {
  const changes = [
    value => { value.extra = true; }, value => { delete value.accountId; },
    value => { value.accountId = false; }, value => { value.projectId = null; },
    value => { value.expectedSavedRevision = "A".repeat(64); },
    value => { value.expectedContext.extra = true; }, value => { value.expectedContext.listenPort = "8787"; },
    value => { value.expectedRunningRevision = null; }, value => { value.operationId = requestIds[0]; },
  ];
  for (const [index, change] of changes.entries()) await t.test(String(index), async t => {
    const router = await assignmentRouter(t), before = await assignmentState(router);
    const command = JSON.parse(assignmentChange(router, before)); change(command);
    router.input.write(JSON.stringify(command) + "\n"); await tick();
    router.input.write(frame("set_mode", requestIds[0], "on")); await tick();
    assert.equal(router.replies.values.length, 0);
    assert.equal((await health(router)).configFingerprint, before.runningFingerprint);
    assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "off");
  });
});

// A repeated successful no-op has no artifact, so the child's bounded last attempt must prevent reexecution.
test("repeated assignment operation IDs never execute twice", async t => {
  let attempts = 0;
  const { commitProjectAssignment } = await import("../src/project-assignments.js");
  const router = await assignmentRouter(t, { async commitAssignment(...args) { attempts++; return commitProjectAssignment(...args); } });
  const state = await assignmentState(router);
  router.input.write(assignmentChange(router, state, { accountId: A2 }));
  const result = await router.replies.next();
  assert.equal(result.outcome, "applied"); assert.equal(result.commit.changed, false);
  router.input.write(assignmentChange(router, result.state, { accountId: A1 }));
  assert.equal((await router.replies.next()).outcome, "rejected");
  assert.equal(attempts, 1);
  assert.equal((await assignmentState(router)).runningAssignment.account.id, A2);
});

// Partial UTF-8 decodes only when complete; semantic mismatches do not break ordered mode control.
test("split and coalesced assignment frames preserve nullable selection and mode order", async t => {
  const router = await assignmentRouter(t), before = await assignmentState(router);
  const command = assignmentChange(router, before, { expectedContext: { ...router.context, configPath: router.context.configPath + "-café" } });
  const bytes = Buffer.from(command), split = bytes.indexOf(0xc3) + 1;
  router.input.write(bytes.subarray(0, split)); await tick();
  assert.equal(router.replies.values.length, 0);
  router.input.write(Buffer.concat([bytes.subarray(split), Buffer.from(frame("set_mode", requestIds[2], "on")),
    Buffer.from(assignmentFrame("get_assignment", { expectedContext: router.context, projectId: null, operationId: null }))]));
  assert.equal((await router.replies.next()).outcome, "rejected");
  assert.equal((await router.replies.next()).mode, "on");
  const state = (await router.replies.next()).state;
  assert.equal(state.mode, "on"); assert.equal(state.projectId, null);
  assert.equal(state.lastAttempt, null);
});

// A blocked assignment reply must stop command execution, while a flooded channel leaves publication intact.
test("blocked assignment output bounds queued commands and preserves publication", async t => {
  let held = false, release;
  const sink = new PassThrough(), replies = lines(sink);
  const output = new Writable({ highWaterMark: 1, write(chunk, _encoding, done) {
    sink.write(chunk);
    if (held) release = done;
    else done();
  } });
  const router = await assignmentRouter(t, { output });
  router.replies = replies;
  const ready = await replies.next();
  assert.deepEqual(ready.capabilities, ["project_assignments_v1"]);
  router.context = ready.context;
  const before = await assignmentState(router);
  router.input.write(frame("set_mode", requestIds[0], "on")); await replies.next(); await tick();
  held = true;
  router.input.write(assignmentChange(router, before) + frame("set_mode", requestIds[2], "off"));
  const result = await replies.next();
  assert.equal(result.outcome, "applied");
  assert.equal(output.writableLength <= 32768, true);
  await health(router);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "on");
  router.input.write(Buffer.alloc(65536, 0x78)); await tick();
  held = false; release(); await tick();
  assert.equal(replies.values.length, 0);
  assert.equal((await health(router)).configFingerprint, result.state.runningFingerprint);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "on");
});

// Publication is visible before a failed lease release, but cleanup uncertainty remains unconfirmed.
test("post-publication lock cleanup failure stays uncertain with actual runtime evidence", async t => {
  const fs = await import("node:fs/promises");
  const { commitProjectAssignment } = await import("../src/project-assignments.js");
  const router = await assignmentRouter(t, { commitAssignment(input, options) {
    return commitProjectAssignment(input, { ...options, fs: { ...fs, async unlink(path) {
      if (path.endsWith("/.activation.lock")) throw new Error("PRIVATE_CLEANUP_FAILURE");
      return fs.unlink(path);
    } } });
  } });
  const before = await assignmentState(router);
  router.input.write(assignmentChange(router, before));
  const result = await router.replies.next();
  assert.equal(result.outcome, "uncertain");
  assert.equal(result.code, "ASSIGNMENT_UNCERTAIN");
  assert.equal(result.commit, null);
  assert.equal(result.state.savedRevision, result.state.runningRevision);
  assert.equal(result.state.savedIdentity, result.state.runningIdentity);
  assert.notEqual(result.state.runningRevision, before.runningRevision);
  assert.equal(result.state.lastAttempt.candidateRevision, result.state.runningRevision);
  assert.equal(result.state.mode, "off");
  const state = await assignmentState(router, { operationId: requestIds[1] });
  assert.equal(state.lastAttempt.outcome, "uncertain");
  assert.equal((await health(router)).configFingerprint, result.state.runningFingerprint);
  assert.doesNotMatch(router.diagnosticText(), /PRIVATE_CLEANUP_FAILURE/);
});

// A missing explicit nullable field in a read cannot silently change which evidence is requested.
test("assignment reads require exact nullable fields and keep wrong contexts from attesting state", async t => {
  for (const change of [value => { delete value.projectId; }, value => { delete value.operationId; },
    value => { value.operationId = false; }, value => { value.projectId = 12; }, value => { value.accountId = null; }]) {
    const router = await assignmentRouter(t);
    const value = JSON.parse(assignmentFrame("get_assignment", { expectedContext: router.context, projectId: null, operationId: null }));
    change(value); router.input.write(JSON.stringify(value) + "\n"); await tick();
    router.input.write(frame("set_mode", requestIds[0], "on")); await tick();
    assert.equal(router.replies.values.length, 0);
    assert.equal(router.server.listening, true);
  }
  const router = await assignmentRouter(t);
  router.input.write(assignmentFrame("get_assignment", { expectedContext: { ...router.context, listenPort: 1 }, projectId: P1, operationId: null }));
  const result = await router.replies.next();
  assert.equal(result.outcome, "rejected");
  assert.equal(result.code, "ASSIGNMENT_CONFLICT");
  assert.equal(result.state, null);
  assert.equal((await assignmentState(router)).mode, "off");
});

// Ready and assignment replies share the same frame budget as incoming commands.
test("oversized outbound evidence closes control without writing an oversized frame", async t => {
  const router = await managed(t, { configure(f) { f.config.codexHome = "/" + "x".repeat(17000); } });
  await tick();
  assert.equal(router.replies.values.length, 0);
  router.input.write(frame("set_mode", requestIds[0], "on")); await tick();
  assert.equal(router.replies.values.length, 0);
  assert.equal((await health(router)).service, "codex-project-router");
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "off");
});

// A read from fresh source cannot bypass the startup setup guard's earlier account readiness check.
test("managed startup rejects setup drift between lock load and retained source read", async t => {
  const f = await prepare(t), configPath = await realpath(f.configPath);
  f.config.schemaVersion = 2; f.config.accountRouting = accountRouting(); await f.saveConfig();
  const notReady = structuredClone(f.config); notReady.accountRouting.defaultAccountId = null;
  const preload = join(f.dir, "setup-drift.mjs");
  await writeFile(preload, `import fs from "node:fs/promises";
import {writeFileSync} from "node:fs";
import {syncBuiltinESMExports} from "node:module";
const read = fs.readFile; let changed = false;
fs.readFile = async function(path, ...args) {
  const value = await read.call(this, path, ...args);
  if (!changed && path === ${JSON.stringify(configPath)}) {
    changed = true; writeFileSync(path, ${JSON.stringify(JSON.stringify(notReady))});
  }
  return value;
}; syncBuiltinESMExports();`);
  const proc = child(["--config", configPath, "--session", sessionId], ["--import", pathToFileURL(preload).href]);
  t.after(() => proc.kill());
  const observed = Promise.withResolvers(); let stderr = "";
  proc.stdout.on("data", () => observed.resolve("ready"));
  proc.stderr.on("data", chunk => { stderr += chunk; });
  proc.once("exit", () => observed.resolve("exit"));
  assert.equal(await observed.promise, "exit");
  assert.equal(proc.exitCode, 1);
  assert.equal(JSON.parse(stderr).error.code, "ACCOUNT_SETUP_REQUIRED");
});

// A pending read owns the same serialized queue as writes and absolute mode commands.
test("mode command waits for pending assignment read", async t => {
  const { readProjectAssignmentState } = await import("../src/project-assignments.js");
  const entered = Promise.withResolvers(), release = Promise.withResolvers();
  t.after(() => release.resolve());
  let hold = true;
  const router = await assignmentRouter(t, { async readAssignmentState(...args) {
    const state = await readProjectAssignmentState(...args);
    if (hold) { entered.resolve(); await release.promise; }
    return state;
  } });
  const read = assignmentState(router);
  await entered.promise;
  router.input.write(frame("set_mode", requestIds[2], "on")); await tick();
  assert.equal(router.replies.values.length, 0);
  await health(router);
  assert.equal(JSON.parse(router.diagnosticText().trim().split("\n").at(-1)).routingMode, "off");
  hold = false; release.resolve();
  assert.equal((await read).mode, "off");
  assert.equal((await router.replies.next()).mode, "on");
  assert.equal((await assignmentState(router)).mode, "on");
});
