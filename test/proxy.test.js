import nodeTest from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import https from "node:https";
import net from "node:net";
import { spawn } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { PassThrough } from "node:stream";
import { EventEmitter, getEventListeners, once } from "node:events";
import { setTimeout as delay } from "node:timers/promises";
import { createProxy } from "../src/proxy.js";
import { RouterError } from "../src/errors.js";
import { readKeychainCredential } from "../src/credentials.js";
import { fixture, headers, titleHeaders, P1, P2, T1, T2, CHILD, duplicateIdentityMetadata } from "./helpers/fixtures.js";
const key = await readFile(
  new URL("./fixtures/tls/test-only-key.pem", import.meta.url),
);
const cert = await readFile(
  new URL("./fixtures/tls/test-only-cert.pem", import.meta.url),
);
async function listening(server, t) {
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => {
    server.closeAllConnections();
    return new Promise((r) => server.close(r));
  });
  return server.address().port;
}
async function setupProxy(t, handler, options = {}) {
  const f = await fixture(t), calls = [], projectCalls = [];
  const upstream = (handler, captured) => https.createServer({ key, cert }, async (req, res) => {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    const bodyBytes = Buffer.concat(chunks);
    captured.push({ url: req.url, headers: req.headers, body: bodyBytes.toString(), bodyBytes });
    await handler(req, res, captured);
  });
  const port = await listening(upstream(handler, calls), t);
  const globalBaseUrl = `https://127.0.0.1:${port}/api/v1`;
  const projectUpstream = options.projectHandler ? upstream(options.projectHandler, projectCalls) : undefined;
  const projectPort = projectUpstream ? await listening(projectUpstream, t) : undefined;
  const projectBaseUrl = projectUpstream ? `https://127.0.0.1:${projectPort}/region/v1` : globalBaseUrl;
  f.config.upstreamBaseUrl = globalBaseUrl;
  f.config.observeRequestMetadata = options.observeRequestMetadata ?? false;
  f.config.allowUnassignedThreadTitles = options.allowUnassignedThreadTitles ?? false;
  if (options.credentialRouting !== undefined)
    f.config.credentialRouting = typeof options.credentialRouting === "function"
      ? options.credentialRouting({ globalBaseUrl, projectBaseUrl })
      : options.credentialRouting;
  const logs = new PassThrough();
  let output = "";
  logs.on("data", (c) => (output += c));
  const agent = new https.Agent({ ca: cert });
  if (options.untrustedProject) {
    const createConnection = agent.createConnection;
    // Keep the healthy origin trusted while exercising a real TLS rejection at the selected origin.
    agent.createConnection = function (connectionOptions, ...args) {
      return createConnection.call(this, {
        ...connectionOptions,
        ...(Number(connectionOptions.port) === projectPort ? { ca: [] } : {}),
      }, ...args);
    };
  }
  t.after(() => agent.destroy());
  const proxy = createProxy(f.config, {
    diagnostics: logs,
    upstreamAgent: options.untrusted ? undefined : agent,
    inactivityTimeoutMs: options.timeoutMs,
    credentialReader: options.credentialReader,
    getProjectRoutingMode: options.getProjectRoutingMode,
  });
  const proxyPort = await listening(proxy, t);
  return { ...f, calls, projectCalls, globalBaseUrl, projectBaseUrl, projectUpstream, proxy, proxyPort, logs: () => output };
}
function request(
  f,
  {
    path = "/v1/responses",
    method = "POST",
    raw = headers(),
    token = "CREDENTIAL_SENTINEL",
    authorization = `Bearer ${token}`,
    authenticated = true,
    body = '{"model":"unchanged","input":"PROMPT_SENTINEL"}',
    onChunk,
    pauseMs = 0,
  } = {},
) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: f.proxyPort,
        path,
        method,
        headers: [
          "Host",
          "127.0.0.1",
          ...(authenticated ? ["Authorization", authorization] : []),
          ...raw,
        ],
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => {
          chunks.push(c);
          onChunk?.(c);
        });
        res.on("error", reject);
        if (pauseMs) {
          res.pause();
          setTimeout(() => res.resume(), pauseMs);
        }
        res.on("end", () =>
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: Buffer.concat(chunks).toString(),
          }),
        );
      },
    );
    req.on("error", reject);
    req.end(body);
  });
}
const globalReference = {
  keychainPath: "/synthetic/KEYCHAIN_REFERENCE_SENTINEL",
  service: "GLOBAL_SERVICE_SENTINEL",
  account: "GLOBAL_ACCOUNT_SENTINEL",
};
const projectAReference = {
  keychainPath: "/synthetic/KEYCHAIN_REFERENCE_SENTINEL",
  service: "PROJECT_SERVICE_SENTINEL",
  account: "PROJECT_A_ACCOUNT_SENTINEL",
};
const projectBReference = {
  keychainPath: "/synthetic/KEYCHAIN_REFERENCE_SENTINEL",
  service: "PROJECT_SERVICE_SENTINEL",
  account: "PROJECT_B_ACCOUNT_SENTINEL",
};
function credentialRouting({ globalBaseUrl, projectBaseUrl }) {
  return {
    globalCredential: globalReference,
    routeTargets: {
      "route-a": { upstreamBaseUrl: projectBaseUrl, credential: projectAReference },
      "route-b": { upstreamBaseUrl: projectBaseUrl, credential: projectBReference },
      controller: { upstreamBaseUrl: globalBaseUrl, credential: globalReference },
    },
  };
}
function syntheticCredentialReader(reads) {
  return async (reference, { signal }) => {
    assert.ok(signal instanceof AbortSignal);
    assert.equal(signal.aborted, false);
    reads.push(reference);
    if (reference === globalReference) return "GLOBAL_CREDENTIAL_SENTINEL";
    if (reference === projectAReference) return "PROJECT_A_CREDENTIAL_SENTINEL";
    if (reference === projectBReference) return "PROJECT_B_CREDENTIAL_SENTINEL";
    throw new Error("Unexpected synthetic reference");
  };
}
async function within(promise, message) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(message)), 3000); }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
function diagnosticEvents(f) {
  return f.logs().trim().split("\n").filter(Boolean).map(JSON.parse);
}
function processCredentialReader(t, blockedReference, {holdClose = false} = {}) {
  const ready = Promise.withResolvers(), runs = [];
  const reader = (reference, {signal}) => {
    assert.ok(reference === globalReference || reference === projectAReference);
    const closed = Promise.withResolvers(), releaseClose = Promise.withResolvers();
    const run = {reference, signal, closed: false, settled: false, releaseClose};
    const token = reference === globalReference ? "GLOBAL_CREDENTIAL_SENTINEL" : "PROJECT_A_CREDENTIAL_SENTINEL";
    const blocked = reference === blockedReference;
    const lookup = readKeychainCredential(reference, {
      signal,
      spawnProcess(_executable, _args, options) {
        const source = blocked
          ? `process.stdout.write(${JSON.stringify(token)}); process.stderr.write("READY"); setInterval(() => {}, 1000);`
          : `process.stdout.write(${JSON.stringify(token)});`;
        const child = spawn(process.execPath, ["--input-type=module", "-e", source], options);
        run.child = child;
        // Hold only notification of a real child's closure to test late reader settlement.
        const readerChild = holdClose && blocked ? new EventEmitter() : child;
        if (readerChild !== child) {
          readerChild.stdout = child.stdout;
          readerChild.stderr = child.stderr;
          readerChild.kill = terminationSignal => child.kill(terminationSignal);
          child.once("error", error => readerChild.emit("error", error));
        }
        child.once("close", (code, terminationSignal) => {
          run.closed = true;
          closed.resolve();
          if (readerChild !== child)
            releaseClose.promise.then(() => readerChild.emit("close", code, terminationSignal));
        });
        if (blocked) child.stderr.once("data", () => ready.resolve(run));
        return readerChild;
      },
    });
    run.outcome = lookup.then(value => ({value}), error => ({error})).then(outcome => {
      run.settled = true;
      return outcome;
    });
    run.whenClosed = closed.promise;
    runs.push(run);
    t.after(async () => {
      releaseClose.resolve();
      if (!run.closed) run.child.kill("SIGKILL");
      await within(closed.promise, "synthetic credential child survived cleanup");
      await within(run.outcome, "synthetic credential lookup survived cleanup");
    });
    return lookup;
  };
  return {reader, ready: ready.promise, runs};
}
for (const observationMode of [false, true]) for (const policyMode of [false,true]) {
const test = (name, run) => nodeTest(`${name} (observation ${observationMode}, title policy ${policyMode})`, run);
const setup = (t, handler, options = {}) => setupProxy(t, handler, {...options, observeRequestMetadata: observationMode, allowUnassignedThreadTitles:policyMode});
const transportTest = (name, run) => {
  for (const routingMode of [false, true]) test(`${name} (credential routing ${routingMode})`, async t => {
    const fixtures = [], reads = [], token = routingMode ? "GLOBAL_CREDENTIAL_SENTINEL" : "CREDENTIAL_SENTINEL";
    const transportSetup = async (t, handler, options = {}) => {
      const f = await setup(t, handler, {
        ...options,
        credentialReader: syntheticCredentialReader(reads),
        ...(routingMode ? {credentialRouting: credentialRouting} : {}),
      });
      fixtures.push(f);
      return f;
    };
    await run(t, transportSetup, (f, options) => request(f, {token, ...options}), token);
    for (const f of fixtures) {
      if (routingMode) for (const call of f.calls) assert.equal(call.headers.authorization,
        call.headers["thread-id"] === CHILD ? "Bearer GLOBAL_CREDENTIAL_SENTINEL" : "Bearer PROJECT_A_CREDENTIAL_SENTINEL");
      assert.doesNotMatch(f.logs(), /SENTINEL/);
    }
    if (!routingMode) assert.deepEqual(reads, []);
  });
};
test("terminal credential failures record their initiating outcome before aborting request work", async t => {
  for (const failure of ["mismatch", "project unavailable"]) {
    let requestSignal, eventsAtAbort;
    const f = await setup(t, async (req, res) => res.end("unexpected"), {
      credentialRouting: credentialRouting,
      credentialReader: async (reference, {signal}) => {
        if (!requestSignal) {
          requestSignal = signal;
          signal.addEventListener("abort", () => { eventsAtAbort = diagnosticEvents(f); }, {once: true});
        }
        if (reference === projectAReference) throw new RouterError("CREDENTIAL_UNAVAILABLE");
        return "GLOBAL_CREDENTIAL_SENTINEL";
      },
    });
    const result = await request(f, {token: failure === "mismatch" ? "WRONG_CREDENTIAL_SENTINEL" : "GLOBAL_CREDENTIAL_SENTINEL"});
    const expectedCode = failure === "mismatch" ? "AUTH_INVALID" : "CREDENTIAL_UNAVAILABLE";
    assert.equal(result.status, failure === "mismatch" ? 401 : 503);
    assert.equal(JSON.parse(result.body).error.code, expectedCode);
    assert.equal(requestSignal.aborted, true, "terminal failure retained request work");
    assert.equal(eventsAtAbort.length, 1);
    assert.equal(eventsAtAbort[0].errorCode, expectedCode);
    assert.equal(diagnosticEvents(f).length, 1);
    assert.equal(f.calls.length, 0);
    assert.doesNotMatch(result.body + f.logs(), /SENTINEL/);
  }
});
for (const stage of ["global", "project"]) for (const cancellation of ["client disconnect", "forced connection closure", "request error", "delayed child completion"]) {
test(`${cancellation} during ${stage} retrieval reaps real child work and preserves cancellation`, async t => {
  const processes = processCredentialReader(t, stage === "global" ? globalReference : projectAReference, {
    holdClose: cancellation === "delayed child completion",
  });
  const f = await setup(t, async (req, res) => res.end("unexpected"), {
    projectHandler: async (req, res) => res.end("unexpected"),
    credentialRouting: credentialRouting, credentialReader: processes.reader,
  });
  let serverRequest, client;
  f.proxy.once("request", req => { serverRequest = req; });
  const clientOutcome = new Promise(resolve => {
    client = http.request({
      host: "127.0.0.1", port: f.proxyPort, path: "/v1/responses", method: "POST",
      headers: ["Host", "127.0.0.1", "Authorization", "Bearer GLOBAL_CREDENTIAL_SENTINEL", ...headers()],
    }, res => {
      let body = "";
      res.on("data", chunk => { body += chunk; });
      res.on("end", () => resolve({status: res.statusCode, body}));
      res.on("error", error => resolve({error}));
    });
    client.on("error", error => resolve({error}));
    client.end("{}");
  });
  t.after(() => client.destroy());
  const pending = await within(processes.ready, "synthetic lookup did not become pending");
  assert.equal(pending.settled, false);
  let eventsAtAbort;
  pending.signal.addEventListener("abort", () => { eventsAtAbort = diagnosticEvents(f); }, {once: true});
  if (cancellation === "request error") serverRequest.emit("error", new Error("REQUEST_ERROR_SENTINEL"));
  else if (cancellation === "forced connection closure") f.proxy.closeAllConnections();
  else client.destroy();
  await within(pending.whenClosed, "cancelled credential child was not reaped");
  assert.ok(pending.child.exitCode !== null || pending.child.signalCode !== null);
  assert.throws(() => process.kill(pending.child.pid, 0), {code: "ESRCH"});
  if (cancellation === "delayed child completion") {
    assert.equal(pending.settled, false, "reader settled before child close notification");
    const completed = diagnosticEvents(f);
    assert.equal(completed.length, 1);
    assert.equal(completed[0].status, 499);
    assert.equal(completed[0].errorCode, "CANCELLED");
    pending.releaseClose.resolve();
  }
  const outcome = await within(pending.outcome, "cancelled credential lookup did not settle");
  assert.equal(outcome.error.code, "CANCELLED");
  assert.equal(pending.signal.aborted, true);
  assert.equal(eventsAtAbort.length, 1, "cancellation was not recorded before aborting child work");
  assert.equal(eventsAtAbort[0].status, 499);
  assert.equal(eventsAtAbort[0].errorCode, "CANCELLED");
  assert.equal(getEventListeners(pending.signal, "abort").length, 0);
  assert.deepEqual(processes.runs.map(run => run.reference), stage === "global"
    ? [globalReference] : [globalReference, projectAReference]);
  const result = await within(clientOutcome, "cancelled client did not settle");
  if (cancellation === "request error") {
    assert.equal(result.status, 499);
    assert.equal(JSON.parse(result.body).error.code, "CANCELLED");
    assert.doesNotMatch(result.body, /SENTINEL/);
  } else assert.ok(result.error);
  assert.equal(f.calls.length, 0);
  assert.equal(f.projectCalls.length, 0);
  const events = diagnosticEvents(f);
  assert.equal(events.length, 1);
  assert.equal(events[0].event, "completed");
  assert.equal(events[0].status, 499);
  assert.equal(events[0].errorCode, "CANCELLED");
  assert.equal(Object.hasOwn(events[0], "requestMetadata"), stage === "project" && observationMode);
  if (stage === "project") assert.equal(events[0].projectId, P1);
  else for (const field of ["threadId", "projectId", "routeAlias", "source"])
    assert.equal(Object.hasOwn(events[0], field), false);
  assert.doesNotMatch(f.logs(), /SENTINEL|READY/);
});
}
test("credential routing rejects global mismatch before broken state or observations", async t => {
  const reads = [];
  const f = await setup(t, async (req, res) => res.end("unexpected"), {
    projectHandler: async (req, res) => res.end("unexpected"),
    credentialRouting: credentialRouting, credentialReader: syntheticCredentialReader(reads),
  });
  assert.notEqual(f.globalBaseUrl, f.projectBaseUrl);
  assert.notEqual(new URL(f.globalBaseUrl).origin, new URL(f.projectBaseUrl).origin);
  await writeFile(f.statePath, "{STATE_SENTINEL");
  for (const token of ["WRONG_CREDENTIAL_SENTINEL", "global_credential_sentinel", "GLOBAL_CREDENTIAL_SENTINEL_EXTRA"]) {
    const result = await request(f, {token, raw: titleHeaders()});
    assert.equal(result.status, 401);
    assert.equal(JSON.parse(result.body).error.code, "AUTH_INVALID");
    assert.doesNotMatch(result.body, /SENTINEL/);
  }
  assert.deepEqual(reads, [globalReference, globalReference, globalReference]);
  assert.equal(f.calls.length, 0);
  assert.equal(f.projectCalls.length, 0);
  for (const event of f.logs().trim().split("\n").map(JSON.parse)) {
    assert.equal(event.event, "completed");
    for (const field of ["requestMetadata", "threadId", "projectId", "source"])
      assert.equal(Object.hasOwn(event, field), false);
  }
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
test("global credential failure precedes identity lookup and project reads", async t => {
  const reads = [];
  const f = await setup(t, async (req, res) => res.end("unexpected"), {
    projectHandler: async (req, res) => res.end("unexpected"),
    credentialRouting: credentialRouting,
    credentialReader: async reference => { reads.push(reference); throw new RouterError("CREDENTIAL_UNAVAILABLE"); },
  });
  assert.notEqual(f.globalBaseUrl, f.projectBaseUrl);
  assert.notEqual(new URL(f.globalBaseUrl).origin, new URL(f.projectBaseUrl).origin);
  await writeFile(f.statePath, "{STATE_SENTINEL");
  const result = await request(f, {raw: titleHeaders(), token: "GLOBAL_CREDENTIAL_SENTINEL"});
  assert.equal(result.status, 503);
  assert.equal(JSON.parse(result.body).error.code, "CREDENTIAL_UNAVAILABLE");
  assert.deepEqual(reads, [globalReference]);
  assert.equal(f.calls.length, 0);
  assert.equal(f.projectCalls.length, 0);
  const event = JSON.parse(f.logs().trim());
  assert.equal(event.event, "completed");
  for (const field of ["requestMetadata", "threadId", "projectId", "source"])
    assert.equal(Object.hasOwn(event, field), false);
  assert.doesNotMatch(result.body + f.logs(), /SENTINEL/);
});
test("mapped route selects its exact credential destination and prefix", async t => {
  const reads = [];
  const f = await setup(t, async (req, res) => res.end("global"), {
    projectHandler: async (req, res) => res.end("project"),
    credentialRouting: credentialRouting, credentialReader: syntheticCredentialReader(reads),
  });
  const bodyBytes = Buffer.from([0x7b, 0x22, 0x78, 0x22, 0x3a, 0x22, 0xc3, 0xa9, 0xff, 0x22, 0x7d]);
  const result = await request(f, {
    path: "/v1/responses?x=a%2Fb&x=2", body: bodyBytes,
    raw: [...headers(T1), "Connection", "authorization, x-drop", "x-drop", "DROP_SENTINEL"],
    token: "GLOBAL_CREDENTIAL_SENTINEL",
  });
  assert.equal(result.status, 200);
  assert.equal(result.body, "project");
  assert.equal(f.calls.length, 0);
  assert.equal(f.projectCalls.length, 1);
  assert.equal(f.projectCalls[0].url, "/region/v1/responses?x=a%2Fb&x=2");
  assert.equal(f.projectCalls[0].headers.host, new URL(f.projectBaseUrl).host);
  assert.equal(f.projectCalls[0].headers.authorization, "Bearer PROJECT_A_CREDENTIAL_SENTINEL");
  assert.deepEqual(f.projectCalls[0].bodyBytes, bodyBytes);
  assert.equal(f.projectCalls[0].headers["x-drop"], undefined);
  f.edge(T1, CHILD);
  const fork = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
  f.state["thread-project-assignments"][fork] = { projectKind: "local", projectId: P2 };
  await f.saveState();
  for (const [path, raw] of [
    ["/v1/responses/compact?unchanged=yes", headers(T2)],
    ["/v1/responses", headers(CHILD)],
    ["/v1/responses", titleHeaders(T1)],
    ["/v1/responses", headers(fork, { forked_from_thread_id: T2 })],
    ["/v1/responses", headers(fork)],
  ]) {
    assert.equal((await request(f, { path, raw, authorization: "bEaReR GLOBAL_CREDENTIAL_SENTINEL" })).body, "project");
  }
  assert.equal(f.calls.length, 0);
  assert.deepEqual(f.projectCalls.map(call => call.headers.authorization), [
    "Bearer PROJECT_A_CREDENTIAL_SENTINEL", "Bearer PROJECT_B_CREDENTIAL_SENTINEL",
    "Bearer PROJECT_A_CREDENTIAL_SENTINEL", "Bearer PROJECT_A_CREDENTIAL_SENTINEL",
    "Bearer PROJECT_B_CREDENTIAL_SENTINEL", "Bearer PROJECT_B_CREDENTIAL_SENTINEL",
  ]);
  assert.deepEqual(f.projectCalls.map(call => call.url), [
    "/region/v1/responses?x=a%2Fb&x=2", "/region/v1/responses/compact?unchanged=yes",
    "/region/v1/responses", "/region/v1/responses", "/region/v1/responses", "/region/v1/responses",
  ]);
  for (const call of f.projectCalls.slice(1)) {
    assert.equal(call.headers.host, new URL(f.projectBaseUrl).host);
    assert.equal(call.body, '{"model":"unchanged","input":"PROMPT_SENTINEL"}');
  }
  assert.deepEqual(reads, [globalReference, projectAReference, globalReference, projectBReference,
    globalReference, projectAReference, globalReference, projectAReference,
    globalReference, projectBReference, globalReference, projectBReference]);
  const starts = diagnosticEvents(f).filter(event => event.event === "started");
  assert.equal(starts[2].source, "ancestor");
  assert.equal(starts[2].ownerThreadId, T1);
  assert.equal(starts[3].projectId, P1);
  assert.equal(starts[3].source, "direct");
  for (const event of starts) assert.equal(Object.hasOwn(event, "requestMetadata"), observationMode);
  // The controller is an ordinary explicit target, deliberately sharing the global pair.
  f.config.projectRoutes[P1] = "controller";
  assert.equal((await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL"})).body, "global");
  assert.equal(f.calls.length, 1);
  assert.equal(f.projectCalls.length, 6);
  assert.equal(f.calls[0].url, "/api/v1/responses");
  assert.equal(f.calls[0].headers.host, new URL(f.globalBaseUrl).host);
  assert.equal(f.calls[0].headers.authorization, "Bearer GLOBAL_CREDENTIAL_SENTINEL");
  assert.deepEqual(reads.slice(-2), [globalReference, globalReference]);
  assert.equal(diagnosticEvents(f).filter(event => event.event === "started").at(-1).routeAlias, "controller");
  assert.doesNotMatch(f.logs(), /SENTINEL|https:|127\.0\.0\.1/);
});
test("shared aliases and shared references select the same exact project credential", async t => {
  const reads = [];
  const routing = urls => {
    const routing = credentialRouting(urls);
    routing.routeTargets["route-b"] = routing.routeTargets["route-a"];
    return routing;
  };
  const f = await setup(t, async (req, res) => res.end("accepted"), {
    projectHandler: async (req, res) => res.end("accepted"),
    credentialRouting: routing, credentialReader: syntheticCredentialReader(reads),
  });
  assert.equal((await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL", raw: headers(T2)})).status, 200);
  f.config.projectRoutes[P2] = "route-a";
  assert.equal((await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL", raw: headers(T2)})).status, 200);
  assert.deepEqual(f.projectCalls.map(call => call.headers.authorization), [
    "Bearer PROJECT_A_CREDENTIAL_SENTINEL", "Bearer PROJECT_A_CREDENTIAL_SENTINEL",
  ]);
  assert.equal(f.calls.length, 0);
  for (const call of f.projectCalls) {
    assert.equal(call.url, "/region/v1/responses");
    assert.equal(call.headers.host, new URL(f.projectBaseUrl).host);
  }
  assert.deepEqual(reads, [globalReference, projectAReference, globalReference, projectAReference]);
});
test("missing credential mappings reject only the affected project with no fallback", async t => {
  const reads = [];
  const routing = urls => {
    const routing = credentialRouting(urls);
    delete routing.routeTargets["route-a"];
    return routing;
  };
  const f = await setup(t, async (req, res) => res.end("healthy"), {
    projectHandler: async (req, res) => res.end("healthy"),
    credentialRouting: routing, credentialReader: syntheticCredentialReader(reads),
  });
  for (const alias of ["route-a", "constructor", "toString"]) {
    f.config.projectRoutes[P1] = alias;
    const result = await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL", raw: titleHeaders(T1)});
    assert.equal(result.status, 422);
    assert.equal(JSON.parse(result.body).error.code, "CREDENTIAL_UNMAPPED");
  }
  assert.deepEqual(reads, [globalReference, globalReference, globalReference]);
  assert.equal((await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL", raw: headers(T2)})).body, "healthy");
  assert.equal(f.projectCalls.length, 1);
  assert.equal(f.projectCalls[0].headers.authorization, "Bearer PROJECT_B_CREDENTIAL_SENTINEL");
  const starts = f.logs().trim().split("\n").map(JSON.parse).filter(event => event.event === "started");
  assert.equal(starts.length, 1);
  assert.equal(starts[0].projectId, P2);
  assert.equal(f.calls.length, 0);
  for (const call of f.projectCalls) {
    assert.equal(call.headers.host, new URL(f.projectBaseUrl).host);
    assert.equal(call.url, "/region/v1/responses");
  }
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
test("explicit own constructor and toString credential mappings work", async t => {
  const reads = [];
  const routing = urls => {
    const routing = credentialRouting(urls);
    routing.routeTargets.constructor = routing.routeTargets["route-a"];
    routing.routeTargets.toString = routing.routeTargets["route-b"];
    return routing;
  };
  const f = await setup(t, async (req, res) => res.end("accepted"), {
    projectHandler: async (req, res) => res.end("accepted"),
    credentialRouting: routing, credentialReader: syntheticCredentialReader(reads),
  });
  f.config.projectRoutes[P1] = "constructor";
  f.config.projectRoutes[P2] = "toString";
  assert.equal((await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL"})).status, 200);
  assert.equal((await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL", raw: headers(T2)})).status, 200);
  assert.deepEqual(f.projectCalls.map(call => call.headers.authorization), [
    "Bearer PROJECT_A_CREDENTIAL_SENTINEL", "Bearer PROJECT_B_CREDENTIAL_SENTINEL",
  ]);
  assert.equal(f.calls.length, 0);
  for (const call of f.projectCalls) {
    assert.equal(call.url, "/region/v1/responses");
    assert.equal(call.headers.host, new URL(f.projectBaseUrl).host);
  }
  assert.deepEqual(reads, [globalReference, projectAReference, globalReference, projectBReference]);
});
test("project credential failure keeps a second project healthy and records no start for rejection", async t => {
  const reads = [], reader = syntheticCredentialReader(reads);
  const f = await setup(t, async (req, res) => res.end("healthy"), {
    projectHandler: async (req, res) => res.end("healthy"),
    credentialRouting: credentialRouting,
    credentialReader: async (reference, options) => {
      if (reference === projectAReference) { reads.push(reference); throw new RouterError("CREDENTIAL_UNAVAILABLE"); }
      return reader(reference, options);
    },
  });
  const rejected = await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL", raw: titleHeaders(T1)});
  assert.equal(rejected.status, 503);
  assert.equal(JSON.parse(rejected.body).error.code, "CREDENTIAL_UNAVAILABLE");
  assert.equal((await request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL", raw: headers(T2)})).body, "healthy");
  assert.equal(f.projectCalls.length, 1);
  assert.equal(f.projectCalls[0].headers.authorization, "Bearer PROJECT_B_CREDENTIAL_SENTINEL");
  assert.deepEqual(reads, [globalReference, projectAReference, globalReference, projectBReference]);
  const events = f.logs().trim().split("\n").map(JSON.parse);
  assert.equal(events.filter(event => event.event === "started").length, 1);
  assert.equal(events[0].event, "completed");
  assert.equal(events[0].projectId, P1);
  assert.equal(Object.hasOwn(events[0], "requestMetadata"), observationMode);
  assert.equal(f.calls.length, 0);
  for (const call of f.projectCalls) {
    assert.equal(call.headers.host, new URL(f.projectBaseUrl).host);
    assert.equal(call.url, "/region/v1/responses");
  }
  assert.doesNotMatch(rejected.body + f.logs(), /SENTINEL/);
});
test("catalog and eligible unassigned titles retain verified authorization without project reads", async t => {
  const reads = [];
  const f = await setup(t, async (req, res) => res.end("accepted"), {
    projectHandler: async (req, res) => res.end("unexpected"),
    credentialRouting: credentialRouting, credentialReader: syntheticCredentialReader(reads),
  });
  const authorization = "bEaReR GLOBAL_CREDENTIAL_SENTINEL";
  assert.equal((await request(f, {path: "/v1/models?unchanged=yes", method: "GET", raw: ["Connection", "authorization"], authorization, body: ""})).status, 200);
  const title = await request(f, {raw: [...titleHeaders(), "Connection", "authorization"], authorization});
  assert.equal(title.status, policyMode ? 200 : 503);
  assert.deepEqual(reads, [globalReference, globalReference]);
  assert.equal(f.calls.length, policyMode ? 2 : 1);
  assert.equal(f.projectCalls.length, 0);
  assert.equal(f.calls[0].url, "/api/v1/models?unchanged=yes");
  if (policyMode) assert.equal(f.calls[1].url, "/api/v1/responses");
  for (const call of f.calls) {
    assert.equal(call.headers.authorization, authorization);
    assert.equal(call.headers.host, new URL(f.globalBaseUrl).host);
  }
  const starts = f.logs().trim().split("\n").map(JSON.parse).filter(event => event.event === "started");
  assert.equal(starts[0].source, "catalog");
  if (policyMode) {
    assert.equal(starts[1].source, "unassigned_title");
    assert.equal(starts[1].threadId, CHILD);
    for (const field of ["projectId", "ownerThreadId", "routeAlias"])
      assert.equal(Object.hasOwn(starts[1], field), false);
    assert.equal(Object.hasOwn(starts[1], "requestMetadata"), observationMode);
  }
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
test("health and rejected admission make no credential reads in routing mode", async t => {
  const reads = [];
  const f = await setup(t, async (req, res) => res.end("unexpected"), {
    credentialRouting: credentialRouting, credentialReader: syntheticCredentialReader(reads),
  });
  assert.equal((await request(f, {path: "/healthz", method: "GET", authenticated: false, raw: [], body: ""})).status, 200);
  assert.equal((await request(f, {authenticated: false})).status, 401);
  assert.equal((await request(f, {path: "/unsupported"})).status, 404);
  assert.deepEqual(reads, []);
  assert.equal(f.calls.length, 0);
});
test("legacy mode forwards its original credential without any credential reads", async t => {
  const reads = [];
  const f = await setup(t, async (req, res) => res.end("accepted"), {credentialReader: syntheticCredentialReader(reads)});
  assert.equal((await request(f, {authorization: "bEaReR LEGACY_CREDENTIAL_SENTINEL"})).status, 200);
  assert.deepEqual(reads, []);
  assert.equal(f.calls[0].headers.authorization, "bEaReR LEGACY_CREDENTIAL_SENTINEL");
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
test("fresh global and project reads observe rotation and deletion without stale fallback", async t => {
  const reads = [];
  const values = new Map([
    [globalReference, "GLOBAL_FIRST_SENTINEL"],
    [projectAReference, "PROJECT_A_FIRST_SENTINEL"],
    [projectBReference, "PROJECT_B_FIRST_SENTINEL"],
  ]);
  const f = await setup(t, async (req, res) => res.end("accepted"), {
    credentialRouting: credentialRouting,
    credentialReader: async reference => {
      reads.push(reference);
      if (!values.has(reference)) throw new RouterError("CREDENTIAL_UNAVAILABLE");
      return values.get(reference);
    },
  });
  const first = {token: "GLOBAL_FIRST_SENTINEL"};
  assert.equal((await request(f, first)).status, 200);
  values.set(projectAReference, "PROJECT_A_ROTATED_SENTINEL");
  assert.equal((await request(f, first)).status, 200);
  values.delete(projectAReference);
  const deleted = await request(f, first);
  assert.equal(deleted.status, 503);
  assert.equal(JSON.parse(deleted.body).error.code, "CREDENTIAL_UNAVAILABLE");
  assert.equal((await request(f, {...first, raw: headers(T2)})).status, 200);
  values.set(globalReference, "GLOBAL_ROTATED_SENTINEL");
  const stale = await request(f, {...first, raw: headers(T2)});
  assert.equal(stale.status, 401);
  assert.equal(JSON.parse(stale.body).error.code, "AUTH_INVALID");
  assert.equal((await request(f, {token: "GLOBAL_ROTATED_SENTINEL", raw: headers(T2)})).status, 200);
  values.delete(globalReference);
  const globalDeleted = await request(f, {token: "GLOBAL_ROTATED_SENTINEL", raw: headers(T2)});
  assert.equal(globalDeleted.status, 503);
  assert.equal(JSON.parse(globalDeleted.body).error.code, "CREDENTIAL_UNAVAILABLE");
  assert.deepEqual(reads, [
    globalReference, projectAReference, globalReference, projectAReference,
    globalReference, projectAReference, globalReference, projectBReference,
    globalReference, globalReference, projectBReference, globalReference,
  ]);
  assert.deepEqual(f.calls.map(call => call.headers.authorization), [
    "Bearer PROJECT_A_FIRST_SENTINEL", "Bearer PROJECT_A_ROTATED_SENTINEL",
    "Bearer PROJECT_B_FIRST_SENTINEL", "Bearer PROJECT_B_FIRST_SENTINEL",
  ]);
  assert.equal(diagnosticEvents(f).filter(event => event.event === "started").length, 4);
  assert.doesNotMatch(deleted.body + stale.body + globalDeleted.body + f.logs(), /SENTINEL/);
});
test("a reference shared by global and project roles is read independently for each role", async t => {
  const reads = [];
  const routing = urls => {
    const routing = credentialRouting(urls);
    routing.routeTargets["route-a"].credential = globalReference;
    return routing;
  };
  const values = ["SHARED_CALLER_SENTINEL", "SHARED_PROJECT_SENTINEL", "ROTATED_CALLER_SENTINEL", "ROTATED_PROJECT_SENTINEL"];
  const f = await setup(t, async (req, res) => res.end("accepted"), {
    credentialRouting: routing,
    credentialReader: async reference => { reads.push(reference); return values.shift(); },
  });
  assert.equal((await request(f, {token: "SHARED_CALLER_SENTINEL"})).status, 200);
  assert.equal((await request(f, {token: "ROTATED_CALLER_SENTINEL"})).status, 200);
  assert.deepEqual(reads, [globalReference, globalReference, globalReference, globalReference]);
  assert.deepEqual(f.calls.map(call => call.headers.authorization), [
    "Bearer SHARED_PROJECT_SENTINEL", "Bearer ROTATED_PROJECT_SENTINEL",
  ]);
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
test("overlapping requests never coalesce global or project credential lookups", async t => {
  const bothGlobal = Promise.withResolvers(), bothProject = Promise.withResolvers();
  let globals = 0, projects = 0;
  t.after(() => { bothGlobal.resolve(); bothProject.resolve(); });
  const f = await setup(t, async (req, res) => res.end("accepted"), {
    credentialRouting: credentialRouting,
    credentialReader: async reference => {
      if (reference === globalReference) {
        if (++globals === 2) bothGlobal.resolve();
        await within(bothGlobal.promise, "global lookups were coalesced");
        return "GLOBAL_CREDENTIAL_SENTINEL";
      }
      assert.equal(reference, projectAReference);
      const ordinal = ++projects;
      if (projects === 2) bothProject.resolve();
      await within(bothProject.promise, "project lookups were coalesced");
      return ordinal === 1 ? "FIRST_PROJECT_SENTINEL" : "SECOND_PROJECT_SENTINEL";
    },
  });
  const results = await Promise.all([
    request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL"}),
    request(f, {token: "GLOBAL_CREDENTIAL_SENTINEL"}),
  ]);
  assert.deepEqual(results.map(result => result.status), [200, 200]);
  assert.equal(globals, 2);
  assert.equal(projects, 2);
  assert.deepEqual(f.calls.map(call => call.headers.authorization).sort(), [
    "Bearer FIRST_PROJECT_SENTINEL", "Bearer SECOND_PROJECT_SENTINEL",
  ]);
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
for (const moveAt of ["selected project lookup", "active stream"]) {
test(`reassignment during ${moveAt} preserves the selected destination and credential snapshot`, async t => {
  const selected = Promise.withResolvers(), releaseLookup = Promise.withResolvers();
  const streamed = Promise.withResolvers(), releaseStream = Promise.withResolvers();
  t.after(() => { releaseLookup.resolve(); releaseStream.resolve(); });
  const reads = [], reader = syntheticCredentialReader(reads);
  const f = await setup(t, async (req, res) => {
    res.write("old-route-");
    await releaseStream.promise;
    res.end("stream");
  }, {
    projectHandler: async (req, res) => {
      res.writeHead(400);
      res.end("GATEWAY_CONTINUATION_REJECTION_SENTINEL");
    },
    credentialRouting: urls => {
      const routing = credentialRouting(urls);
      routing.routeTargets["route-a"].upstreamBaseUrl = urls.globalBaseUrl;
      return routing;
    },
    credentialReader: async (reference, options) => {
      const value = await reader(reference, options);
      if (reference === projectAReference) {
        selected.resolve();
        await releaseLookup.promise;
      }
      return value;
    },
  });
  assert.notEqual(new URL(f.globalBaseUrl).origin, new URL(f.projectBaseUrl).origin);
  const body = '{"model":"unchanged","previous_response_id":"CONTINUATION_SENTINEL","input":"PROMPT_SENTINEL"}';
  const first = request(f, {path: "/v1/responses?held=a%2Fb", body, token: "GLOBAL_CREDENTIAL_SENTINEL", onChunk: () => streamed.resolve()});
  await within(selected.promise, "the first request did not select its project credential");
  if (moveAt === "active stream") {
    releaseLookup.resolve();
    await within(streamed.promise, "the first stream did not start");
  }
  f.state["thread-project-assignments"][T1].projectId = P2;
  await f.saveState();
  releaseLookup.resolve();
  await within(streamed.promise, "the selected stream did not start");
  const next = await request(f, {path: "/v1/responses?next=b%2Fc", body, token: "GLOBAL_CREDENTIAL_SENTINEL"});
  assert.equal(next.status, 400);
  assert.equal(next.body, "GATEWAY_CONTINUATION_REJECTION_SENTINEL");
  releaseStream.resolve();
  assert.equal((await first).body, "old-route-stream");
  assert.equal(f.calls.length, 1);
  assert.equal(f.projectCalls.length, 1);
  assert.deepEqual(f.calls.map(call => call.headers.authorization), ["Bearer PROJECT_A_CREDENTIAL_SENTINEL"]);
  assert.deepEqual(f.projectCalls.map(call => call.headers.authorization), ["Bearer PROJECT_B_CREDENTIAL_SENTINEL"]);
  assert.equal(f.calls[0].url, "/api/v1/responses?held=a%2Fb");
  assert.equal(f.projectCalls[0].url, "/region/v1/responses?next=b%2Fc");
  for (const call of [...f.calls, ...f.projectCalls])
    assert.equal(call.body, '{"model":"unchanged","previous_response_id":"CONTINUATION_SENTINEL","input":"PROMPT_SENTINEL"}');
  assert.equal(f.calls[0].headers.host, new URL(f.globalBaseUrl).host);
  assert.equal(f.projectCalls[0].headers.host, new URL(f.projectBaseUrl).host);
  assert.deepEqual(reads, [globalReference, projectAReference, globalReference, projectBReference]);
  const starts = diagnosticEvents(f).filter(event => event.event === "started");
  assert.deepEqual(starts.map(event => [event.projectId, event.routeAlias]), [[P1, "route-a"], [P2, "route-b"]]);
  for (const start of starts) {
    const complete = diagnosticEvents(f).find(event => event.event === "completed" && event.requestId === start.requestId);
    assert.equal(complete.projectId, start.projectId);
    assert.equal(complete.routeAlias, start.routeAlias);
  }
  assert.doesNotMatch(f.logs(), /SENTINEL|https:|127\.0\.0\.1/);
});
}
test("routing streams overlap across origins with independent project controller and title outcomes", async t => {
  const controllerThread = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
  const controllerProject = "33333333-3333-4333-8333-333333333333";
  const otherTitle = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
  const ids = [T1, T2, controllerThread, CHILD, otherTitle], expectedActive = policyMode ? 5 : 3;
  const statuses = [200, 201, 202, 203, 206];
  const releases = new Map(ids.map(id => [id, Promise.withResolvers()]));
  const firstChunks = new Map(ids.map(id => [id, Promise.withResolvers()]));
  const allActive = Promise.withResolvers(), finished = new Set(), reads = [];
  t.after(() => { for (const gate of releases.values()) gate.resolve(); });
  let active = 0, max = 0;
  const stream = async (req, res) => {
    const id = req.headers["thread-id"], ordinal = ids.indexOf(id);
    max = Math.max(max, ++active);
    res.writeHead(statuses[ordinal], {"content-type": "text/event-stream"});
    res.write(`stream-${ordinal}-`);
    if (active === expectedActive) allActive.resolve();
    await releases.get(id).promise;
    res.end("done");
    active--;
  };
  const f = await setup(t, stream, {
    projectHandler: stream,
    credentialRouting: urls => {
      const routing = credentialRouting(urls);
      routing.routeTargets["route-a"].upstreamBaseUrl = urls.globalBaseUrl;
      return routing;
    },
    credentialReader: syntheticCredentialReader(reads),
  });
  assert.notEqual(new URL(f.globalBaseUrl).origin, new URL(f.projectBaseUrl).origin);
  f.config.projectRoutes[controllerProject] = "controller";
  f.state["local-projects"][controllerProject] = {id: controllerProject};
  f.state["thread-project-assignments"][controllerThread] = {projectKind: "local", projectId: controllerProject};
  await f.saveState();
  const pending = ids.map((id, index) => request(f, {
    path: `/v1/responses?stream=${index}`, body: `{"model":"unchanged","input":"STREAM_${index}_SENTINEL"}`,
    raw: index < 3 ? headers(id) : titleHeaders(id), token: "GLOBAL_CREDENTIAL_SENTINEL",
    onChunk: () => firstChunks.get(id).resolve(),
  }).then(result => { finished.add(id); return result; }));
  await within(allActive.promise, "streams did not overlap across origins");
  await within(Promise.all(ids.slice(0, expectedActive).map(id => firstChunks.get(id).promise)), "stream chunks were buffered");
  assert.equal(active, expectedActive);
  assert.equal(max, expectedActive);
  releases.get(T2).resolve();
  assert.equal((await pending[1]).body, "stream-1-done");
  for (const id of [T1, controllerThread, ...(policyMode ? [CHILD, otherTitle] : [])]) assert.equal(finished.has(id), false);
  releases.get(controllerThread).resolve();
  assert.equal((await pending[2]).body, "stream-2-done");
  assert.equal(finished.has(T1), false);
  if (policyMode) {
    releases.get(CHILD).resolve();
    assert.equal((await pending[3]).body, "stream-3-done");
    assert.equal(finished.has(otherTitle), false);
    assert.equal(finished.has(T1), false);
  }
  for (const gate of releases.values()) gate.resolve();
  const results = await Promise.all(pending);
  assert.deepEqual(results.map(result => result.status), policyMode ? [200, 201, 202, 203, 206] : [200, 201, 202, 503, 503]);
  assert.deepEqual(results.slice(0, expectedActive).map(result => result.body), policyMode
    ? ["stream-0-done", "stream-1-done", "stream-2-done", "stream-3-done", "stream-4-done"]
    : ["stream-0-done", "stream-1-done", "stream-2-done"]);
  const firstOrigin = f.calls.map(call => [call.headers["thread-id"], call.headers.authorization, call.url, call.body]).sort();
  assert.deepEqual(firstOrigin, (policyMode ? [
    [T1, "Bearer PROJECT_A_CREDENTIAL_SENTINEL", "/api/v1/responses?stream=0", '{"model":"unchanged","input":"STREAM_0_SENTINEL"}'],
    [controllerThread, "Bearer GLOBAL_CREDENTIAL_SENTINEL", "/api/v1/responses?stream=2", '{"model":"unchanged","input":"STREAM_2_SENTINEL"}'],
    [CHILD, "Bearer GLOBAL_CREDENTIAL_SENTINEL", "/api/v1/responses?stream=3", '{"model":"unchanged","input":"STREAM_3_SENTINEL"}'],
    [otherTitle, "Bearer GLOBAL_CREDENTIAL_SENTINEL", "/api/v1/responses?stream=4", '{"model":"unchanged","input":"STREAM_4_SENTINEL"}'],
  ] : [
    [T1, "Bearer PROJECT_A_CREDENTIAL_SENTINEL", "/api/v1/responses?stream=0", '{"model":"unchanged","input":"STREAM_0_SENTINEL"}'],
    [controllerThread, "Bearer GLOBAL_CREDENTIAL_SENTINEL", "/api/v1/responses?stream=2", '{"model":"unchanged","input":"STREAM_2_SENTINEL"}'],
  ]).sort());
  assert.deepEqual(f.projectCalls.map(call => [call.headers["thread-id"], call.headers.authorization, call.url, call.body]), [
    [T2, "Bearer PROJECT_B_CREDENTIAL_SENTINEL", "/region/v1/responses?stream=1", '{"model":"unchanged","input":"STREAM_1_SENTINEL"}'],
  ]);
  for (const call of f.calls) assert.equal(call.headers.host, new URL(f.globalBaseUrl).host);
  assert.equal(f.projectCalls[0].headers.host, new URL(f.projectBaseUrl).host);
  assert.equal(reads.filter(reference => reference === globalReference).length, 6);
  assert.equal(reads.filter(reference => reference === projectAReference).length, 1);
  assert.equal(reads.filter(reference => reference === projectBReference).length, 1);
  const starts = diagnosticEvents(f).filter(event => event.event === "started");
  assert.equal(starts.length, expectedActive);
  assert.equal(starts.find(event => event.threadId === controllerThread).routeAlias, "controller");
  assert.equal(starts.filter(event => event.source === "unassigned_title").length, policyMode ? 2 : 0);
  for (const event of starts) {
    assert.equal(Object.hasOwn(event, "requestMetadata"), observationMode);
    if (observationMode) assert.equal(event.requestMetadata.headers["thread-id"].id, event.threadId);
    const complete = diagnosticEvents(f).find(completed => completed.event === "completed" && completed.requestId === event.requestId);
    assert.equal(complete.threadId, event.threadId);
    assert.equal(complete.projectId, event.projectId);
    assert.equal(complete.routeAlias, event.routeAlias);
    if (observationMode) assert.deepEqual(complete.requestMetadata, event.requestMetadata);
    if (event.source === "unassigned_title") for (const field of ["projectId", "ownerThreadId", "routeAlias"])
      assert.equal(Object.hasOwn(event, field), false);
  }
  assert.doesNotMatch(f.logs(), /SENTINEL|https:|127\.0\.0\.1/);
});
for (const failure of ["401", "cross-origin 307", "connection failure", "TLS rejection", "broken stream"]) {
test(`selected-origin ${failure} never forwards to another origin and leaves a separate target healthy`, async t => {
  const reads = [], firstChunk = Promise.withResolvers(), tlsRejected = Promise.withResolvers();
  t.after(() => firstChunk.resolve());
  const f = await setup(t, async (req, res) => res.end("healthy-target"), {
    projectHandler: async (req, res) => {
      if (failure === "401") {
        res.writeHead(401, {"www-authenticate": "Bearer GATEWAY_AUTH_FRAGMENT_SENTINEL"});
        res.end("GATEWAY_ERROR_FRAGMENT_SENTINEL");
      } else if (failure === "cross-origin 307") {
        res.writeHead(307, {location: `${f.globalBaseUrl}/REDIRECT_DESTINATION_SENTINEL`});
        res.end("GATEWAY_REDIRECT_FRAGMENT_SENTINEL");
      } else if (failure === "broken stream") {
        res.writeHead(200, {"content-type": "text/event-stream"});
        res.write("GATEWAY_STREAM_FRAGMENT_SENTINEL");
        await firstChunk.promise;
        res.destroy(new Error("GATEWAY_STREAM_ERROR_SENTINEL"));
      } else res.end("unexpected selected-origin success");
    },
    untrustedProject: failure === "TLS rejection",
    credentialRouting: urls => {
      const routing = credentialRouting(urls);
      routing.routeTargets["route-b"].upstreamBaseUrl = urls.globalBaseUrl;
      return routing;
    },
    credentialReader: syntheticCredentialReader(reads),
  });
  assert.notEqual(new URL(f.globalBaseUrl).origin, new URL(f.projectBaseUrl).origin);
  if (failure === "connection failure") {
    await new Promise(resolve => f.projectUpstream.close(resolve));
    assert.equal(f.projectUpstream.listening, false);
  }
  if (failure === "TLS rejection") f.projectUpstream.once("tlsClientError", () => tlsRejected.resolve());
  const body = '{"model":"unchanged","previous_response_id":"CONTINUATION_SENTINEL","input":"PROMPT_SENTINEL"}';
  const chunks = [];
  const selected = request(f, {
    path: "/v1/responses?selected=a%2Fb", body, token: "GLOBAL_CREDENTIAL_SENTINEL",
    onChunk: chunk => { chunks.push(chunk.toString()); firstChunk.resolve(); },
  });
  if (failure === "broken stream") {
    await assert.rejects(within(selected, "broken selected stream did not close"), {code: "ECONNRESET"});
    assert.equal(chunks.join(""), "GATEWAY_STREAM_FRAGMENT_SENTINEL");
  } else {
    const result = await within(selected, "selected-origin failure did not settle");
    if (failure === "401") {
      assert.equal(result.status, 401);
      assert.equal(result.headers["www-authenticate"], "Bearer GATEWAY_AUTH_FRAGMENT_SENTINEL");
      assert.equal(result.body, "GATEWAY_ERROR_FRAGMENT_SENTINEL");
    } else if (failure === "cross-origin 307") {
      assert.equal(result.status, 307);
      assert.equal(result.headers.location, `${f.globalBaseUrl}/REDIRECT_DESTINATION_SENTINEL`);
      assert.equal(result.body, "GATEWAY_REDIRECT_FRAGMENT_SENTINEL");
    } else {
      assert.equal(result.status, 502);
      assert.equal(JSON.parse(result.body).error.code, "UPSTREAM_FAILED");
      assert.doesNotMatch(result.body, /SENTINEL|https:|127\.0\.0\.1/);
    }
  }
  if (failure === "TLS rejection") await within(tlsRejected.promise, "selected origin did not reject TLS");
  assert.equal(f.calls.length, 0, "failed request reached the fallback or redirect origin");
  const selectedCalls = failure === "connection failure" || failure === "TLS rejection" ? 0 : 1;
  assert.equal(f.projectCalls.length, selectedCalls, "selected request was retried");
  const healthy = await request(f, {path: "/v1/responses?healthy=c%2Fd", raw: headers(T2), body, token: "GLOBAL_CREDENTIAL_SENTINEL"});
  assert.equal(healthy.status, 200);
  assert.equal(healthy.body, "healthy-target");
  assert.equal(f.calls.length, 1);
  assert.equal(f.projectCalls.length, selectedCalls);
  assert.equal(f.calls[0].url, "/api/v1/responses?healthy=c%2Fd");
  assert.equal(f.calls[0].headers.authorization, "Bearer PROJECT_B_CREDENTIAL_SENTINEL");
  assert.equal(f.calls[0].headers.host, new URL(f.globalBaseUrl).host);
  assert.equal(f.calls[0].body, '{"model":"unchanged","previous_response_id":"CONTINUATION_SENTINEL","input":"PROMPT_SENTINEL"}');
  for (const call of f.projectCalls) {
    assert.equal(call.url, "/region/v1/responses?selected=a%2Fb");
    assert.equal(call.headers.authorization, "Bearer PROJECT_A_CREDENTIAL_SENTINEL");
    assert.equal(call.headers.host, new URL(f.projectBaseUrl).host);
    assert.equal(call.body, '{"model":"unchanged","previous_response_id":"CONTINUATION_SENTINEL","input":"PROMPT_SENTINEL"}');
  }
  assert.deepEqual(reads, [globalReference, projectAReference, globalReference, projectBReference]);
  const completions = diagnosticEvents(f).filter(event => event.event === "completed");
  assert.equal(completions.length, 2);
  assert.equal(completions[0].projectId, P1);
  assert.equal(completions[0].status, failure === "401" ? 401 : failure === "cross-origin 307" ? 307 : 502);
  assert.equal(completions[0].errorCode, failure === "401" || failure === "cross-origin 307" ? undefined : "UPSTREAM_FAILED");
  assert.equal(completions[1].projectId, P2);
  assert.equal(completions[1].status, 200);
  assert.doesNotMatch(f.logs(), /SENTINEL|https:|127\.0\.0\.1/);
});
}
test("exact initial titles forward only when enabled without project ownership",async t => {
  const f=await setup(t, async (req,res) => {
    res.writeHead(201,{"content-type":"text/event-stream"});
    res.write("data: first\n\n");await delay(60);res.end("data: RESPONSE_SENTINEL\n\n");
  });
  const chunks=[];
  const raw=titleHeaders(CHILD,{request_kind:"UNKNOWN_SENTINEL",unknown:"METADATA_SENTINEL"});
  const result=await request(f,{raw,path:"/v1/responses?mode=unchanged",token:"TITLE_CREDENTIAL_SENTINEL",onChunk:c=>chunks.push(c.toString())});
  assert.equal(result.status,policyMode ? 201 : 503);
  const events=f.logs().trim().split("\n").map(JSON.parse);
  if(policyMode) {
    assert.equal(f.calls.length,1);
    assert.equal(f.calls[0].url,"/api/v1/responses?mode=unchanged");
    assert.equal(f.calls[0].headers.authorization,"Bearer TITLE_CREDENTIAL_SENTINEL");
    assert.equal(f.calls[0].headers["x-codex-turn-metadata"],raw[5]);
    assert.equal(f.calls[0].body,'{"model":"unchanged","input":"PROMPT_SENTINEL"}');
    assert.ok(chunks.length>=2);
    assert.equal(result.body,"data: first\n\ndata: RESPONSE_SENTINEL\n\n");
    for(const event of events) {
      assert.equal(event.source,"unassigned_title");assert.equal(event.threadId,CHILD);
      for(const field of ["projectId","ownerThreadId","routeAlias"]) assert.equal(Object.hasOwn(event,field),false);
    }
  } else {assert.equal(f.calls.length,0);assert.equal(events.at(-1).source,undefined);}
  for(const event of events) assert.equal(Object.hasOwn(event,"requestMetadata"),observationMode);
  assert.doesNotMatch(f.logs(),/SENTINEL/);
});
test("title labels preserve mapped priority and cannot admit known identities",async t => {
  const f=await setup(t,async(req,res)=>res.end("mapped"));
  const mapped=await request(f,{raw:titleHeaders(T1)});
  assert.equal(mapped.status,200);
  assert.equal(JSON.parse(f.logs().trim().split("\n").at(-1)).projectId,P1);
  const duplicateFeature=["thread-id",T1,"session-id",T1,"x-codex-turn-metadata",`{"thread_source":"user","thread_source":"thread_title"}`];
  assert.equal((await request(f,{raw:duplicateFeature})).status,200);
  delete f.config.projectRoutes[P1];
  assert.equal((await request(f,{raw:titleHeaders(T1)})).status,422);
  f.state["projectless-thread-ids"].push(CHILD);await f.saveState();
  assert.equal((await request(f,{raw:titleHeaders()})).status,422);
  f.state["projectless-thread-ids"]=[];await f.saveState();f.thread(CHILD);
  assert.equal((await request(f,{raw:titleHeaders()})).status,503);
  const orphan="eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
  f.edge(orphan,T2);
  assert.equal((await request(f,{raw:titleHeaders(orphan)})).status,503);
  assert.equal(f.calls.length,2);
});
test("title markers never bypass routes, authentication, identity or state failures",async t => {
  const f=await setup(t,async(req,res)=>res.end("unexpected"));
  for(const [options,status] of [
    [{path:"/v1/responses/compact",raw:titleHeaders()},503],
    [{authenticated:false,raw:titleHeaders()},401],
    [{method:"GET",raw:titleHeaders(),body:""},404],
    [{raw:[...titleHeaders(),"thread-id",CHILD]},400],
    [{raw:titleHeaders(CHILD,{thread_id:T1})},409],
    [{raw:titleHeaders(CHILD,{forked_from_thread_id:T1})},503],
    [{raw:titleHeaders(CHILD,{parent_thread_id:null})},503],
  ]) {
    assert.equal((await request(f,options)).status,status);
  }
  await writeFile(f.statePath,"{STATE_SENTINEL");
  assert.equal((await request(f,{raw:titleHeaders()})).status,503);
  assert.equal(f.calls.length,0);
  assert.ok(f.logs().trim().split("\n").map(JSON.parse).every(e=>e.source!=="unassigned_title"));
  assert.doesNotMatch(f.logs(),/SENTINEL/);
});
if(policyMode) {
test("mapped and multiple title streams overlap with independent credentials and observations",async t => {
  let active=0,max=0;
  const f=await setup(t,async(req,res)=>{max=Math.max(max,++active);res.write("first");await delay(100);res.end("last");active--;});
  const other="dddddddd-dddd-4ddd-8ddd-dddddddddddd";
  const results=await Promise.all([
    request(f,{raw:headers(T1),token:"MAPPED_KEY"}),
    request(f,{raw:titleHeaders(),token:"TITLE_A_KEY"}),
    request(f,{raw:titleHeaders(other),token:"TITLE_B_KEY"}),
  ]);
  assert.deepEqual(results.map(r=>r.body),["firstlast","firstlast","firstlast"]);
  assert.equal(max,3);
  assert.deepEqual(f.calls.map(c=>c.headers.authorization).sort(),["Bearer MAPPED_KEY","Bearer TITLE_A_KEY","Bearer TITLE_B_KEY"]);
  const starts=f.logs().trim().split("\n").map(JSON.parse).filter(e=>e.event==="started");
  assert.equal(starts.filter(e=>e.source==="unassigned_title").length,2);
  assert.equal(starts.find(e=>e.threadId===T1).projectId,P1);
  for(const event of starts) if(observationMode) assert.equal(event.requestMetadata.headers["thread-id"].id,event.threadId);
  assert.doesNotMatch(f.logs(),/MAPPED_KEY|TITLE_A_KEY|TITLE_B_KEY|SENTINEL/);
});
test("title cancellation releases upstream work and lookup cancellation makes zero calls",async t => {
  let closed;const done=new Promise(r=>closed=r);
  const f=await setup(t,async(req,res)=>{res.on("close",closed);res.write("first");});
  await new Promise((resolve,reject)=>{
    const req=http.request({host:"127.0.0.1",port:f.proxyPort,path:"/v1/responses",method:"POST",headers:["Host","127.0.0.1","Authorization","Bearer CREDENTIAL_SENTINEL",...titleHeaders()]},
      res=>res.once("data",()=>{res.destroy();resolve();}));
    req.on("error",reject);req.end("{}");
  });
  await Promise.race([done,delay(1500).then(()=>{throw new Error("title upstream retained");})]);
  const completed=f.logs().trim().split("\n").map(JSON.parse).find(e=>e.event==="completed");
  assert.equal(completed.source,"unassigned_title");assert.equal(completed.errorCode,"CANCELLED");
  await writeFile(f.statePath,"{");
  await new Promise(resolve=>{
    const req=http.request({host:"127.0.0.1",port:f.proxyPort,path:"/v1/responses",method:"POST",headers:["Host","127.0.0.1","Authorization","Bearer CREDENTIAL_SENTINEL",...titleHeaders()]});
    req.on("error",resolve);req.end("{}");setTimeout(()=>req.destroy(),50);
  });
  await delay(50);assert.equal(f.calls.length,1);
  assert.equal(JSON.parse(f.logs().trim().split("\n").at(-1)).errorCode,"CANCELLED");
});
transportTest("title redirects are not followed or retried", async (t, setup, request, token) => {
  const f=await setup(t,async(req,res)=>{res.writeHead(307,{location:"https://example.invalid/ignored"});res.end("redirect");});
  assert.equal((await request(f,{raw:titleHeaders()})).status,307);
  assert.equal(f.calls.length,1);
});
}
test("overlapping requests preserve identities, original body bytes and per-request credentials", async (t) => {
  let active = 0,
    max = 0,
    release;
  const both = new Promise((r) => (release = r));
  const f = await setup(t, async (req, res, calls) => {
    max = Math.max(max, ++active);
    if (calls.length === 2) release();
    await both;
    res.end("RESPONSE_SENTINEL");
    active--;
  });
  const results = await Promise.all([
    request(f, { raw: headers(T1, {request_kind: "user"}), token: "KEY_A" }),
    request(f, { raw: headers(T2, {request_kind: "subagent"}), token: "KEY_B" }),
  ]);
  assert.equal(max, 2);
  assert.deepEqual(
    results.map((r) => r.status),
    [200, 200],
  );
  assert.deepEqual(f.calls.map((c) => c.headers.authorization).sort(), [
    "Bearer KEY_A",
    "Bearer KEY_B",
  ]);
  assert.ok(
    f.calls.every(
      (c) =>
        c.url === "/api/v1/responses" &&
        c.body === '{"model":"unchanged","input":"PROMPT_SENTINEL"}',
    ),
  );
  const starts = f
    .logs()
    .trim()
    .split("\n")
    .map(JSON.parse)
    .filter((r) => r.event === "started");
  assert.deepEqual(starts.map((r) => r.projectId).sort(), [P1, P2]);
  for (const start of starts) {
    assert.equal(Object.hasOwn(start, "requestMetadata"), observationMode);
    if (observationMode) {
      assert.equal(start.requestMetadata.headers["thread-id"].id, start.threadId);
      assert.equal(start.requestMetadata.turnMetadata.fields.request_kind.label, start.threadId === T1 ? "user" : "subagent");
      const completed = f.logs().trim().split("\n").map(JSON.parse)
        .find((event) => event.event === "completed" && event.requestId === start.requestId);
      assert.deepEqual(completed.requestMetadata, start.requestMetadata);
    }
  }
  assert.doesNotMatch(f.logs(), /SENTINEL|KEY_A|KEY_B/);
});
transportTest("forwards streamed chunks before the response finishes", async (t, setup, request, token) => {
  const f = await setup(t, async (req, res) => {
    res.writeHead(201, { "content-type": "text/event-stream" });
    res.write("data: first\n\n");
    await delay(80);
    res.end("data: second\n\n");
  });
  const times = [];
  const result = await request(f, { onChunk: () => times.push(Date.now()) });
  assert.equal(result.status, 201);
  assert.equal(result.body, "data: first\n\ndata: second\n\n");
  assert.ok(times.length >= 2);
  assert.ok(times.at(-1) - times[0] >= 50);
});
test("catalog works without identity, compaction requires and retains it, health stays local", async (t) => {
  const f = await setup(t, async (req, res) => res.end("{}"));
  assert.equal(
    (await request(f, { path: "/healthz", method: "GET", raw: [], body: "" }))
      .status,
    200,
  );
  assert.equal(f.calls.length, 0);
  assert.equal(
    (
      await request(f, {
        path: "/v1/models?client_version=1",
        method: "GET",
        raw: [],
        body: "",
      })
    ).status,
    200,
  );
  assert.equal(
    (await request(f, { path: "/v1/responses/compact" })).status,
    200,
  );
  assert.deepEqual(
    f.calls.map((c) => c.url),
    ["/api/v1/models?client_version=1", "/api/v1/responses/compact"],
  );
  assert.equal(
    (await request(f, { path: "/v1/responses/compact", raw: [] })).status,
    400,
  );
  assert.equal(f.calls.length, 2);
  const starts = f.logs().trim().split("\n").map(JSON.parse)
    .filter((event) => event.event === "started");
  assert.deepEqual(starts.map((event) => event.operation), ["catalog", "compact"]);
  for (const event of f.logs().trim().split("\n").map(JSON.parse))
    assert.equal(Object.hasOwn(event, "requestMetadata"), observationMode && event.operation === "compact");
});
test("blocked and unmapped model requests make zero upstream calls", async (t) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"));
  assert.equal(
    (await request(f, { raw: headers(T1, { thread_id: T2 }) })).status,
    409,
  );
  delete f.config.projectRoutes[P1];
  assert.equal((await request(f)).status, 422);
  assert.equal(f.calls.length, 0);
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
transportTest("does not follow redirects or retry upstream responses", async (t, setup, request, token) => {
  const f = await setup(t, async (req, res) => {
    res.writeHead(307, { location: "https://other.example.invalid" });
    res.end("redirect");
  });
  assert.equal((await request(f)).status, 307);
  assert.equal(f.calls.length, 1);
});
test("duplicate metadata identities never reach an upstream model", async (t) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"));
  f.edge(T1, CHILD);
  for (const { id, metadata } of duplicateIdentityMetadata) {
    const result = await request(f, {
      raw: ["thread-id", id, "session-id", id, "x-codex-turn-metadata", metadata],
    });
    assert.equal(result.status, 400);
    assert.equal(JSON.parse(result.body).error.code, "IDENTITY_INVALID");
    assert.equal(f.calls.length, 0);
  }
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
test("unresolved requests retain only the validated chat identifier for diagnosis", async (t) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"));
  delete f.state["thread-project-assignments"][T1];
  await f.saveState();
  assert.equal((await request(f)).status, 503);
  const completion = f.logs().trim().split("\n").map(JSON.parse)
    .find((event) => event.event === "completed");
  assert.equal(completion.threadId, T1);
  assert.equal(completion.errorCode, "STATE_UNAVAILABLE");
  assert.equal(f.calls.length, 0);
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
transportTest("removes connection-nominated hop headers and sets the upstream host", async (t, setup, request, token) => {
  const f = await setup(t, async (req, res) => {
    res.setHeader("Connection", "x-private-hop");
    res.setHeader("x-private-hop", "not-forwarded");
    res.end("{}");
  });
  const result = await request(f, {
    raw: [
      ...headers(),
      "Connection",
      "x-private-hop",
      "x-private-hop",
      "remove-me",
    ],
  });
  assert.equal(f.calls[0].headers["x-private-hop"], undefined);
  assert.match(f.calls[0].headers.host, /^127\.0\.0\.1:\d+$/);
  assert.equal(result.headers["x-private-hop"], undefined);
});
transportTest("rejects untrusted TLS certificates without disabling verification", async (t, setup, request, token) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"), {
    untrusted: true,
  });
  assert.equal((await request(f)).status, 502);
  assert.equal(f.calls.length, 0);
});
transportTest("upstream disconnect before headers is sanitized and is not retried", async (t, setup, request, token) => {
  const f = await setup(t, async (req, res) =>
    res.destroy(new Error("RESPONSE_SENTINEL")),
  );
  const result = await request(f);
  assert.equal(result.status, 502);
  assert.equal(f.calls.length, 1);
  assert.doesNotMatch(result.body + f.logs(), /SENTINEL/);
});
transportTest("a broken upstream stream closes the client instead of appending a fabricated response", async (t, setup, request, token) => {
  const f = await setup(t, async (req, res) => {
    res.write("partial");
    await delay(20);
    res.destroy();
  });
  await assert.rejects(request(f));
  assert.equal(f.calls.length, 1);
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
transportTest("upstream inactivity is bounded without retrying", async (t, setup, request, token) => {
  const f = await setup(t, async () => {}, { timeoutMs: 70 });
  assert.equal((await request(f)).status, 502);
  assert.equal(f.calls.length, 1);
});
transportTest("slow clients receive the complete streamed body under backpressure", async (t, setup, request, token) => {
  let blocked = false;
  const size = 64 * 1024;
  const f = await setup(t, async (req, res) => {
    for (let i = 0; i < 64; i++) {
      if (!res.write(Buffer.alloc(size, 65))) {
        blocked = true;
        await once(res, "drain");
      }
    }
    res.end();
  });
  const result = await request(f, { pauseMs: 100 });
  assert.equal(result.body.length, size * 64);
  assert.ok(blocked);
});
transportTest("client cancellation closes the upstream response and is not reported as an upstream failure", async (t, setup, request, token) => {
  let closed;
  const done = new Promise((r) => (closed = r));
  const f = await setup(t, async (req, res) => {
    res.on("close", closed);
    res.write("first");
  });
  await new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: f.proxyPort,
        path: "/v1/responses",
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "thread-id": T1,
        },
      },
      (res) =>
        res.once("data", () => {
          res.destroy();
          resolve();
        }),
    );
    req.on("error", reject);
    req.end("{}");
  });
  await Promise.race([
    done,
    delay(1500).then(() => {
      throw new Error("upstream did not close");
    }),
  ]);
  const completion = f.logs().trim().split("\n").map(JSON.parse)
    .find((event) => event.event === "completed");
  assert.equal(completion.status, 499);
  assert.equal(completion.errorCode, "CANCELLED");
  assert.equal(Object.hasOwn(completion, "requestMetadata"), observationMode);
  if (observationMode) assert.equal(completion.requestMetadata.headers["thread-id"].id, T1);
});
transportTest("malformed HTTP input produces a fixed response without dumping the packet", async (t, setup, request, token) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"));
  const text = await new Promise((resolve, reject) => {
    const socket = net.connect(f.proxyPort, "127.0.0.1");
    let text = "";
    socket.on("connect", () => socket.end("BAD_SENTINEL\r\n\r\n"));
    socket.on("data", (c) => (text += c));
    socket.on("end", () => resolve(text));
    socket.on("error", reject);
  });
  assert.match(text, /400/);
  assert.doesNotMatch(text + f.logs(), /SENTINEL/);
  assert.equal(f.calls.length, 0);
});

test("early admission rejection does not collect observations", async (t) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"));
  for (const options of [
    {path: "/unhandled?RAW_SENTINEL", raw: headers()},
    {authenticated: false, raw: headers()},
    {raw: [...headers(), "thread-id", T1]},
    {raw: [...headers(), "Authorization", "Bearer CREDENTIAL_SENTINEL"]},
    {raw: [...headers(), "x-codex-turn-metadata", "META_SENTINEL"]},
  ]) {
    const result = await request(f, options);
    assert.ok([400, 401, 404].includes(result.status));
    assert.doesNotMatch(result.body, /SENTINEL/);
  }
  assert.equal(f.calls.length, 0);
  for (const event of f.logs().trim().split("\n").map(JSON.parse))
    assert.equal(Object.hasOwn(event, "requestMetadata"), false);
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});

test("post-admission identity failures retain safe observations", async (t) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"));
  const cases = [
    [["thread-id", T1, "x-codex-turn-metadata", "{META_SENTINEL"], 400, "malformed"],
    [headers("ID_SENTINEL"), 400, "present"],
    [["thread-id", T1, "x-codex-turn-metadata", `{"thread_id":"${T1}","thr\\u0065ad_id":"${T2}"}`], 400, "present"],
    [headers(T1, {thread_id: T2}), 409, "present"],
  ];
  for (const [raw, status, metadataState] of cases) {
    const result = await request(f, {raw});
    assert.equal(result.status, status);
    const event = f.logs().trim().split("\n").map(JSON.parse).at(-1);
    assert.equal(Object.hasOwn(event, "requestMetadata"), observationMode);
    if (observationMode) assert.equal(event.requestMetadata.turnMetadata.state, metadataState);
    assert.doesNotMatch(result.body + f.logs(), /SENTINEL/);
  }
  delete f.config.projectRoutes[P1];
  assert.equal((await request(f)).status, 422);
  const last = f.logs().trim().split("\n").map(JSON.parse).at(-1);
  assert.equal(Object.hasOwn(last, "requestMetadata"), observationMode);
  assert.equal(f.calls.length, 0);
});

test("observation-only fields preserve forwarding and cannot redirect a mapped project", async (t) => {
  const f = await setup(t, async (req, res) => res.end("accepted"));
  const raw = [...headers(T1, {
    thread_source: {ignored: "META_SENTINEL"}, turn_trigger: null, request_kind: "UNKNOWN_SENTINEL",
    forked_from_thread_id: T2, unknown: "KEY_SENTINEL",
  }), "x-codex-parent-thread-id", "HEADER_SENTINEL"];
  assert.equal((await request(f, {raw})).body, "accepted");
  assert.equal(f.calls[0].headers["x-codex-turn-metadata"], raw[5]);
  assert.equal(f.calls[0].headers["x-codex-parent-thread-id"], "HEADER_SENTINEL");
  const event = f.logs().trim().split("\n").map(JSON.parse).at(-1);
  assert.equal(event.projectId, P1);
  if (observationMode) {
    assert.equal(event.requestMetadata.turnMetadata.fields.thread_source.state, "unsupported");
    assert.equal(event.requestMetadata.turnMetadata.fields.request_kind.label, "other");
    assert.equal(event.requestMetadata.turnMetadata.fields.forked_from_thread_id.id, T2);
  }
  const duplicate = ["thread-id", T1, "x-codex-turn-metadata", `{"request_kind":"user","request_\\u006bind":"thread_title"}`];
  assert.equal((await request(f, {raw: duplicate})).status, 200);
  const last = f.logs().trim().split("\n").map(JSON.parse).at(-1);
  if (observationMode) assert.equal(last.requestMetadata.turnMetadata.fields.request_kind.state, "duplicate");
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});

test("new parent and fork claims cannot admit an unresolved chat", async (t) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"));
  const raw = [...headers(CHILD, {forked_from_thread_id: T1, request_kind: "thread_title"}), "x-codex-parent-thread-id", T1];
  const result = await request(f, {raw});
  assert.equal(result.status, 503);
  assert.equal(JSON.parse(result.body).error.code, "STATE_UNAVAILABLE");
  assert.equal(f.calls.length, 0);
  const event = f.logs().trim().split("\n").map(JSON.parse).at(-1);
  assert.equal(Object.hasOwn(event, "requestMetadata"), observationMode);
  if (observationMode) {
    assert.equal(event.requestMetadata.headers["x-codex-parent-thread-id"].id, T1);
    assert.equal(event.requestMetadata.turnMetadata.fields.forked_from_thread_id.id, T1);
  }
});
}

function managedCredentialReader(reads) {
  return async reference => {
    reads.push(reference);
    if (reference === globalReference) return "synthetic-global";
    if (reference === projectAReference || reference === projectBReference) return "synthetic-project";
    throw new Error("REFERENCE_SENTINEL");
  };
}
nodeTest("managed modes select exact paired origins and credentials", async t => {
  let mode = "off";
  const reads = [];
  const f = await setupProxy(t, async (req, res) => res.end("global"), {
    projectHandler: async (req, res) => res.end("project"),
    credentialRouting, credentialReader: managedCredentialReader(reads), getProjectRoutingMode: () => mode,
  });
  delete f.config.projectRoutes[P2];
  const sentBodyBytes = Buffer.from(' {"model":"original-model","previous_response_id":"continuation-original","input":"π"} \n');
  const options = {token: "synthetic-global", path: "/v1/responses?x=a%2Fb&x=2", body: sentBodyBytes};
  assert.equal((await request(f, options)).body, "global");
  assert.equal((await request(f, {...options, raw: headers(T2)})).body, "global");
  mode = "on";
  assert.equal((await request(f, options)).body, "project");
  assert.equal((await request(f, {...options, raw: headers(T2)})).body, "global");
  assert.equal(f.calls[0].headers.authorization, "Bearer synthetic-global");
  assert.equal(f.projectCalls[0].headers.authorization, "Bearer synthetic-project");
  assert.deepEqual(f.projectCalls[0].bodyBytes, sentBodyBytes);
  assert.equal(f.calls.length, 3);
  assert.equal(f.projectCalls.length, 1);
  for (const call of f.calls) {
    assert.equal(call.headers.authorization, "Bearer synthetic-global");
    assert.equal(call.url, "/api/v1/responses?x=a%2Fb&x=2");
    assert.deepEqual(call.bodyBytes, sentBodyBytes);
  }
  assert.equal(f.projectCalls[0].url, "/region/v1/responses?x=a%2Fb&x=2");
  assert.deepEqual(reads, [globalReference, globalReference, globalReference, projectAReference, globalReference]);
  assert.deepEqual(diagnosticEvents(f).filter(e => e.event === "started").map(e => [e.routingMode, e.routeSelection, e.routeAlias]), [
    ["off", "global", undefined], ["off", "global", undefined], ["on", "override", "route-a"], ["on", "global", undefined],
  ]);
  assert.doesNotMatch(f.logs(), /synthetic|SENTINEL/);
});
nodeTest("managed legacy preserves caller authorization without Keychain", async t => {
  for (const mode of ["off", "on", undefined]) {
    const f = await setupProxy(t, async (req, res) => res.end("global"), {
      projectHandler: async (req, res) => res.end("unexpected"),
      credentialReader: () => { throw new Error("KEYCHAIN_MUST_NOT_RUN"); },
      ...(mode === undefined ? {} : {getProjectRoutingMode: () => mode}),
    });
    assert.equal((await request(f, {authorization: "bEaReR caller-original"})).status, 200);
    delete f.config.projectRoutes[P1];
    const result = await request(f, {authorization: "bEaReR caller-original"});
    if (mode === undefined) {
      assert.equal(result.status, 422);
      assert.equal(JSON.parse(result.body).error.code, "ROUTE_UNMAPPED");
    } else assert.equal(result.status, 200);
    assert.equal(f.projectCalls.length, 0);
    for (const call of f.calls) assert.equal(call.headers.authorization, "bEaReR caller-original");
    if (mode !== undefined) for (const event of diagnosticEvents(f)) assert.equal(Object.hasOwn(event, "routeAlias"), false);
  }
});
nodeTest("managed off suspends missing or unavailable explicit target", async t => {
  for (const problem of ["missing", "unavailable", "shared reference"]) {
    const reads = [];
    const f = await setupProxy(t, async (req, res) => res.end("global"), {
      projectHandler: async (req, res) => res.end("unexpected"),
      credentialRouting: urls => {
        const value = credentialRouting(urls);
        if (problem === "missing") delete value.routeTargets["route-a"];
        if (problem === "shared reference") value.routeTargets["route-a"].credential = globalReference;
        return value;
      },
      getProjectRoutingMode: () => "off",
      credentialReader: async reference => {
        reads.push(reference);
        if (reference !== globalReference || reads.length > 2) throw new RouterError("CREDENTIAL_UNAVAILABLE");
        return "synthetic-global";
      },
    });
    assert.equal((await request(f, {token: "incorrect"})).status, 401);
    assert.equal((await request(f, {token: "synthetic-global"})).body, "global");
    assert.deepEqual(reads, [globalReference, globalReference]);
    assert.equal(f.calls.length, 1);
    assert.equal(f.projectCalls.length, 0);
    assert.equal(Object.hasOwn(diagnosticEvents(f).find(e => e.event === "started"), "routeAlias"), false);
  }
});
nodeTest("managed on explicit failure never inherits", async t => {
  for (const failure of ["missing", "credential", "shared reference", 402, 429, 503, "TLS", "connection", 307]) {
    const reads = [];
    let mode = "on";
    const f = await setupProxy(t, async (req, res) => res.end("unexpected-global"), {
      projectHandler: async (req, res) => {
        res.writeHead(typeof failure === "number" ? failure : 200, failure === 307 ? {location: `${f.globalBaseUrl}/redirect`} : {});
        res.end("selected-response");
      },
      untrustedProject: failure === "TLS",
      credentialRouting: urls => {
        const value = credentialRouting(urls);
        if (failure === "missing") delete value.routeTargets["route-a"];
        if (failure === "shared reference") value.routeTargets["route-a"].credential = globalReference;
        return value;
      },
      getProjectRoutingMode: () => mode,
      credentialReader: async reference => {
        reads.push(reference);
        if (reads.length === 1) return "synthetic-global";
        if (failure === "credential" || failure === "shared reference") throw new RouterError("CREDENTIAL_UNAVAILABLE");
        return "synthetic-project";
      },
    });
    if (failure === "connection") await new Promise(resolve => f.projectUpstream.close(resolve));
    const result = await request(f, {token: "synthetic-global"});
    const expectedStatus = failure === "missing" ? 422 : failure === "credential" || failure === "shared reference" ? 503 : failure === "TLS" || failure === "connection" ? 502 : failure;
    assert.equal(result.status, expectedStatus, String(failure));
    assert.equal(mode, "on");
    assert.equal(f.calls.length, 0);
    assert.equal(f.projectCalls.length, typeof failure === "number" ? 1 : 0);
    assert.equal(reads.length, failure === "missing" ? 1 : 2);
    assert.doesNotMatch(f.logs(), /synthetic|SENTINEL/);
  }
});
nodeTest("managed identity ambiguity never inherits", async t => {
  const id = "abcdefab-abcd-4abc-8abc-abcdefabcdef";
  for (const mode of ["off", "on"]) for (const problem of ["catalog mismatch", "duplicate catalog", "mapping mismatch", "duplicate mapping", "ancestor conflict", "projectless", "header conflict"]) {
    const f = await setupProxy(t, async (req, res) => res.end("unexpected"), {getProjectRoutingMode: () => mode});
    f.state["local-projects"] = {[id]: {id}};
    f.state["thread-project-assignments"][T1].projectId = id;
    f.config.projectRoutes = {};
    if (problem === "catalog mismatch") f.state["local-projects"][id].id = P2;
    if (problem === "duplicate catalog") f.state["local-projects"][id.toUpperCase()] = {id};
    if (problem === "mapping mismatch" || problem === "duplicate mapping") f.config.projectRoutes[id.toUpperCase()] = "route-a";
    if (problem === "duplicate mapping") f.config.projectRoutes[id] = "route-a";
    if (problem === "ancestor conflict") {
      f.state["local-projects"][P2] = {id: P2};
      f.edge(T2, T1);
    }
    if (problem === "projectless") f.state["projectless-thread-ids"].push(T1);
    await f.saveState();
    const result = await request(f, problem === "header conflict" ? {raw: headers(T1, {thread_id: T2})} : {});
    const rejected = JSON.parse(result.body);
    assert.equal(rejected.error.code, "IDENTITY_CONFLICT");
    assert.equal(f.calls.length + f.projectCalls.length, 0);
  }
});
nodeTest("new identified project inherits before browsing", async t => {
  const f = await setupProxy(t, async (req, res) => res.end("global"), {getProjectRoutingMode: () => "on"});
  const project = "33333333-3333-4333-8333-333333333333";
  f.state["local-projects"][project] = {id: project};
  f.state["thread-project-assignments"][CHILD] = {projectKind: "local", projectId: project};
  await f.saveState();
  assert.equal((await request(f, {raw: headers(CHILD)})).body, "global");
  assert.equal(f.calls.length, 1);
  assert.equal(Object.hasOwn(f.config.projectRoutes, project), false);
});
nodeTest("managed catalog and title permissions remain independent", async t => {
  for (const mode of ["off", "on"]) for (const policy of [false, true]) for (const observe of [false, true]) {
    const reads = [];
    const f = await setupProxy(t, async (req, res) => res.end("global"), {
      getProjectRoutingMode: () => mode, allowUnassignedThreadTitles: policy, observeRequestMetadata: observe,
      credentialRouting, credentialReader: managedCredentialReader(reads),
    });
    assert.equal((await request(f, {token: "synthetic-global", method: "GET", path: "/v1/models?x=1", raw: [], body: ""})).status, 200);
    assert.equal((await request(f, {token: "synthetic-global", raw: titleHeaders()})).status, policy ? 200 : 503);
    assert.equal((await request(f, {token: "synthetic-global", path: "/v1/responses/compact", raw: titleHeaders()})).status, 503);
    assert.equal(f.calls.length, policy ? 2 : 1);
    assert.deepEqual(reads, [globalReference, globalReference, globalReference]);
    for (const event of diagnosticEvents(f).filter(e => e.event === "started")) {
      assert.equal(event.routingMode, mode);
      assert.equal(event.routeSelection, "global");
      assert.equal(Object.hasOwn(event, "routeAlias"), false);
    }
  }
});
nodeTest("managed mode is captured synchronously and invalid results fail closed", async t => {
  let mode = "off", getterCalls = 0;
  const entered = Promise.withResolvers(), release = Promise.withResolvers();
  const f = await setupProxy(t, async (req, res) => res.end("global"), {
    projectHandler: async (req, res) => res.end("project"), credentialRouting,
    getProjectRoutingMode: () => { getterCalls++; return mode; },
    credentialReader: async reference => {
      if (reference === globalReference) { entered.resolve(); await release.promise; return "synthetic-global"; }
      return "synthetic-project";
    },
  });
  const pending = request(f, {token: "synthetic-global"});
  await within(entered.promise, "global lookup did not begin");
  mode = "on";
  release.resolve();
  assert.equal((await pending).body, "global");
  assert.equal(getterCalls, 1);
  for (const invalid of [undefined, null, true, "ON", Promise.resolve("on")]) {
    const denied = await setupProxy(t, async (req, res) => res.end("unexpected"), {getProjectRoutingMode: () => invalid});
    assert.equal((await request(denied)).status, 500);
    assert.equal(denied.calls.length, 0);
  }
});
