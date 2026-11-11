import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { EventEmitter, getEventListeners, once } from "node:events";
import { PassThrough } from "node:stream";
import { setImmediate as nextTurn } from "node:timers/promises";
import { RouterError } from "../src/errors.js";

const moduleUrl = new URL("../src/credentials.js", import.meta.url);
let readKeychainCredential;
try {
  ({ readKeychainCredential } = await import(moduleUrl.href));
} catch (error) {
  if (error.code !== "ERR_MODULE_NOT_FOUND" || error.url !== moduleUrl.href) {
    throw error;
  }
}
function lookup(reference, options) {
  assert.equal(
    typeof readKeychainCredential,
    "function",
    "readKeychainCredential is not implemented",
  );
  return readKeychainCredential(reference, options);
}

const reference = {
  account: "SYNTHETIC_ACCOUNT;$(unused)",
  service: "SYNTHETIC_SERVICE with spaces",
  keychainPath: "/synthetic/keychains/test keychain-db",
};

function fakeChild() {
  const child = new EventEmitter();
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  child.killSignals = [];
  child.kill = (signal) => {
    child.killSignals.push(signal);
    return true;
  };
  return child;
}
function closeChild(child, code = 0, signal = null) {
  child.stdout.end();
  child.stderr.end();
  child.emit("close", code, signal);
}
function controlledLookup(options = {}) {
  const child = fakeChild();
  const promise = lookup(reference, {
    ...options,
    spawnProcess: () => child,
  });
  // Attach the rejection handler before triggering process events.
  const outcome = promise.then(
    (value) => ({ value }),
    (error) => ({ error }),
  );
  return { child, promise, outcome };
}
function assertSafeError(error, code = "CREDENTIAL_UNAVAILABLE") {
  const expected = new RouterError(code);
  assert.ok(error instanceof RouterError);
  assert.equal(error.code, code);
  assert.equal(error.status, expected.status);
  assert.equal(error.message, expected.message);
  assert.equal(Object.hasOwn(error, "cause"), false);
  assert.doesNotMatch(`${error.stack}\n${JSON.stringify(error)}`, /SENTINEL/);
}
function assertDetached(child, signal) {
  for (const event of ["close", "error"]) {
    assert.equal(child.listenerCount(event), 0, `child ${event} listener leaked`);
  }
  for (const stream of [child.stdout, child.stderr]) {
    for (const event of ["data", "error"]) {
      assert.equal(stream.listenerCount(event), 0, `stream ${event} listener leaked`);
    }
  }
  if (signal) assert.equal(getEventListeners(signal, "abort").length, 0);
}

test("retrieves password-only output with fixed executable and literal arguments", async () => {
  let calls = 0;
  const child = fakeChild();
  const promise = lookup(reference, {
    spawnProcess(executable, args, options) {
      calls += 1;
      assert.equal(executable, "/usr/bin/security");
      assert.deepEqual(args, [
        "find-generic-password",
        "-a", reference.account,
        "-s", reference.service,
        "-w", reference.keychainPath,
      ]);
      assert.deepEqual(options, {
        shell: false,
        stdio: ["ignore", "pipe", "pipe"],
      });
      return child;
    },
  });
  child.stdout.write("SYNTHETIC_TOKEN\n");
  closeChild(child);
  assert.equal(await promise, "SYNTHETIC_TOKEN");
  assert.equal(calls, 1);
  assertDetached(child);
});

const tokenCases = [
  { name: "zero bytes", chunks: [Buffer.alloc(0)] },
  { name: "one byte without LF", chunks: [Buffer.from("A")], want: "A" },
  { name: "visible ASCII endpoints", chunks: [Buffer.from("!~")], want: "!~" },
  { name: "8192 bytes", chunks: [Buffer.alloc(8192, 65)], want: "A".repeat(8192) },
  { name: "8193 bytes", chunks: [Buffer.alloc(8193, 65)] },
  { name: "one terminal LF", chunks: [Buffer.from("TOKEN\n")], want: "TOKEN" },
  { name: "LF in a separate chunk at maximum token length", chunks: [Buffer.alloc(8192, 65), Buffer.from("\n")], want: "A".repeat(8192) },
  { name: "LF alone", chunks: [Buffer.from("\n")] },
  { name: "multiple terminal LFs", chunks: [Buffer.from("TOKEN\n"), Buffer.from("\n")] },
  { name: "embedded LF", chunks: [Buffer.from("TO\nKEN")] },
  { name: "CRLF", chunks: [Buffer.from("TOKEN\r"), Buffer.from("\n")] },
  { name: "space", chunks: [Buffer.from("TO KEN")] },
  { name: "leading and trailing spaces", chunks: [Buffer.from(" TOKEN ")] },
  { name: "tab", chunks: [Buffer.from("TO\tKEN")] },
  { name: "NUL", chunks: [Buffer.from([65, 0, 66])] },
  { name: "DEL", chunks: [Buffer.from([65, 127, 66])] },
  { name: "UTF-8 split across chunks", chunks: [Buffer.from([65, 0xc3]), Buffer.from([0xa9, 66])] },
  { name: "invalid non-ASCII byte", chunks: [Buffer.from([65, 0xff, 66])] },
];
for (const { name, chunks, want } of tokenCases) {
  test(`validates credential bytes: ${name}`, async () => {
    const { child, outcome } = controlledLookup();
    for (const chunk of chunks) child.stdout.write(chunk);
    closeChild(child);
    const result = await outcome;
    if (want === undefined) assertSafeError(result.error);
    else assert.equal(result.value, want);
    assertDetached(child);
  });
}

test("waits for close before accepting successful exit and final output", async () => {
  const controller = new AbortController();
  const { child, outcome } = controlledLookup({ signal: controller.signal });
  let settled = false;
  outcome.then(() => { settled = true; });
  child.stdout.write("FIRST");
  child.emit("exit", 0, null);
  await nextTurn();
  assert.equal(settled, false);
  child.stdout.write("_FINAL\n");
  closeChild(child);
  assert.equal((await outcome).value, "FIRST_FINAL");
  assertDetached(child, controller.signal);
  controller.abort();
  assert.equal(child.killSignals.length, 0);
});

for (const [name, code, signal] of [
  ["nonzero exit", 44, null],
  ["signal termination", null, "SIGTERM"],
  ["unknown exit status", null, null],
  ["signal despite zero exit", 0, "SIGTERM"],
]) {
  test(`rejects plausible stdout after ${name}`, async () => {
    const { child, outcome } = controlledLookup();
    child.stdout.write("CREDENTIAL_SENTINEL\n");
    child.stderr.write("KEYCHAIN_ERROR_SENTINEL");
    closeChild(child, code, signal);
    assertSafeError((await outcome).error);
    assertDetached(child);
  });
}

test("sanitizes synchronous spawn exceptions with a fresh error", async () => {
  const original = new RouterError("CREDENTIAL_UNAVAILABLE");
  original.message = "SPAWN_SENTINEL";
  const error = await lookup(reference, {
    spawnProcess() { throw original; },
  }).then(() => assert.fail("lookup succeeded"), (error) => error);
  assertSafeError(error);
  assert.notEqual(error, original);
});

for (const source of ["child", "stdout", "stderr"]) {
  test(`sanitizes ${source} errors and waits for child closure`, async () => {
    const controller = new AbortController();
    const { child, outcome } = controlledLookup({ signal: controller.signal });
    let settled = false;
    outcome.then(() => { settled = true; });
    child.stdout.write("CREDENTIAL_SENTINEL\n");
    const original = new RouterError("CREDENTIAL_UNAVAILABLE");
    original.message = "PROCESS_ERROR_SENTINEL";
    (source === "child" ? child : child[source]).emit("error", original);
    await nextTurn();
    assert.equal(settled, false);
    assert.ok(child.killSignals.length > 0);
    closeChild(child, null, "SIGKILL");
    const { error } = await outcome;
    assertSafeError(error);
    assert.notEqual(error, original);
    assertDetached(child, controller.signal);
  });
}

test("allows stderr at the independent 16384-byte limit", async () => {
  const { child, outcome } = controlledLookup();
  child.stdout.write("TOKEN");
  child.stderr.write(Buffer.alloc(16384, 65));
  assert.equal(child.killSignals.length, 0);
  closeChild(child);
  assert.equal((await outcome).value, "TOKEN");
  assertDetached(child);
});

test("does not terminate stdout at exactly 16384 bytes before final validation", async () => {
  const { child, outcome } = controlledLookup();
  child.stdout.write(Buffer.alloc(16384, 65));
  assert.equal(child.killSignals.length, 0);
  closeChild(child);
  assertSafeError((await outcome).error);
  assertDetached(child);
});

for (const stream of ["stdout", "stderr"]) {
  test(`terminates on ${stream} overflow across chunks and waits for close`, async () => {
    const controller = new AbortController();
    const { child, outcome } = controlledLookup({ signal: controller.signal });
    let settled = false;
    outcome.then(() => { settled = true; });
    if (stream === "stderr") child.stdout.write("CREDENTIAL_SENTINEL\n");
    child[stream].write(Buffer.alloc(16384, 65));
    assert.equal(child.killSignals.length, 0);
    child[stream].write(Buffer.from("A"));
    await nextTurn();
    assert.equal(settled, false);
    assert.ok(child.killSignals.length > 0);
    closeChild(child, 0);
    assertSafeError((await outcome).error);
    assertDetached(child, controller.signal);
  });
}

test("counts stderr bytes before decoding multibyte chunks", async () => {
  const { child, outcome } = controlledLookup();
  child.stdout.write("TOKEN");
  child.stderr.write(Buffer.alloc(8192, 0xc3));
  child.stderr.write(Buffer.alloc(8192, 0xa9));
  assert.equal(child.killSignals.length, 0);
  child.stderr.write(Buffer.from([0xc3, 0xa9]));
  assert.ok(child.killSignals.length > 0);
  closeChild(child, 0);
  assertSafeError((await outcome).error);
});

test("pre-cancellation avoids spawning and ignores the abort reason", async () => {
  const controller = new AbortController();
  const reason = new Error("ABORT_REASON_SENTINEL");
  controller.abort(reason);
  let calls = 0;
  const error = await lookup(reference, {
    signal: controller.signal,
    spawnProcess() { calls += 1; throw new Error("must not spawn"); },
  }).then(() => assert.fail("lookup succeeded"), (error) => error);
  assertSafeError(error, "CANCELLED");
  assert.notEqual(error, reason);
  assert.equal(calls, 0);
  assert.equal(getEventListeners(controller.signal, "abort").length, 0);
});

test("cancellation during lookup terminates and waits for child closure", async () => {
  const controller = new AbortController();
  const { child, outcome } = controlledLookup({ signal: controller.signal });
  let settled = false;
  outcome.then(() => { settled = true; });
  child.stdout.write("CREDENTIAL_SENTINEL\n");
  controller.abort(new Error("ABORT_REASON_SENTINEL"));
  await nextTurn();
  assert.equal(settled, false);
  assert.ok(child.killSignals.length > 0);
  closeChild(child, 0);
  assertSafeError((await outcome).error, "CANCELLED");
  assertDetached(child, controller.signal);
});

test("cancellation during spawn is observed before waiting for output", async () => {
  const child = fakeChild();
  const controller = new AbortController();
  const promise = lookup(reference, {
    signal: controller.signal,
    spawnProcess() {
      controller.abort(new Error("ABORT_REASON_SENTINEL"));
      return child;
    },
  });
  const outcome = promise.then((value) => ({ value }), (error) => ({ error }));
  assert.ok(child.killSignals.length > 0);
  closeChild(child, 0);
  assertSafeError((await outcome).error, "CANCELLED");
  assertDetached(child, controller.signal);
});

test("fresh requests independently retrieve changed values without caching", async () => {
  for (const token of ["FIRST_TOKEN", "ROTATED_TOKEN"]) {
    const { child, outcome } = controlledLookup();
    child.stdout.write(token);
    closeChild(child);
    assert.equal((await outcome).value, token);
  }
  const { child, outcome } = controlledLookup();
  closeChild(child, 44);
  assertSafeError((await outcome).error);
});

function syntheticLookup(t, source, options = {}) {
  let child;
  let closed = false;
  const started = performance.now();
  const promise = lookup(reference, {
    ...options,
    spawnProcess(_executable, _args, spawnOptions) {
      child = spawn(process.execPath, ["--input-type=module", "-e", source], spawnOptions);
      child.once("close", () => { closed = true; });
      return child;
    },
  });
  t.after(async () => {
    if (!closed) {
      child.kill("SIGKILL");
      await once(child, "close");
    }
  });
  return {
    child,
    started,
    isClosed: () => closed,
    outcome: promise.then((value) => ({ value }), (error) => ({ error })),
  };
}
function assertReaped(lookup) {
  assert.equal(lookup.isClosed(), true);
  assert.ok(lookup.child.exitCode !== null || lookup.child.signalCode !== null);
  assert.throws(() => process.kill(lookup.child.pid, 0), { code: "ESRCH" });
}

test("real synthetic child returns output only after successful closure", { timeout: 12000 }, async (t) => {
  const run = syntheticLookup(t, 'process.stdout.write("SYNTHETIC_TOKEN\\n");');
  assert.equal((await run.outcome).value, "SYNTHETIC_TOKEN");
  assertReaped(run);
});

test("real cancellation reaps a child that ignores SIGTERM before rejecting", { timeout: 12000 }, async (t) => {
  const controller = new AbortController();
  const run = syntheticLookup(t, 'process.on("SIGTERM", () => {}); process.stderr.write("READY"); setInterval(() => {}, 1000);', { signal: controller.signal });
  await once(run.child.stderr, "data");
  controller.abort();
  assertSafeError((await run.outcome).error, "CANCELLED");
  assertReaped(run);
});

for (const stream of ["stdout", "stderr"]) {
  test(`real ${stream} overflow reaps the child before rejecting`, { timeout: 12000 }, async (t) => {
    const run = syntheticLookup(t, `process.${stream}.write(Buffer.alloc(16385, 65)); setInterval(() => {}, 1000);`);
    assertSafeError((await run.outcome).error);
    assertReaped(run);
  });
}

test("five-second timeout reaps a child that ignores SIGTERM before rejecting", { timeout: 12000 }, async (t) => {
  const run = syntheticLookup(t, 'process.on("SIGTERM", () => {}); process.stderr.write("READY"); setInterval(() => {}, 1000);');
  await once(run.child.stderr, "data");
  assertSafeError((await run.outcome).error);
  assert.ok(performance.now() - run.started >= 4900, "lookup timed out before five seconds");
  assertReaped(run);
});
