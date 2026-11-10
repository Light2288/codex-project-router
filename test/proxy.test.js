import nodeTest from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import https from "node:https";
import net from "node:net";
import { readFile } from "node:fs/promises";
import { PassThrough } from "node:stream";
import { once } from "node:events";
import { setTimeout as delay } from "node:timers/promises";
import { createProxy } from "../src/proxy.js";
import { fixture, headers, P1, P2, T1, T2, CHILD, duplicateIdentityMetadata } from "./helpers/fixtures.js";
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
  const f = await fixture(t),
    calls = [];
  const upstream = https.createServer({ key, cert }, async (req, res) => {
    let body = "";
    for await (const chunk of req) body += chunk;
    calls.push({ url: req.url, headers: req.headers, body });
    await handler(req, res, calls);
  });
  const port = await listening(upstream, t);
  f.config.upstreamBaseUrl = `https://127.0.0.1:${port}/api/v1`;
  f.config.observeRequestMetadata = options.observeRequestMetadata ?? false;
  const logs = new PassThrough();
  let output = "";
  logs.on("data", (c) => (output += c));
  const agent = new https.Agent({ ca: cert });
  t.after(() => agent.destroy());
  const proxy = createProxy(f.config, {
    diagnostics: logs,
    upstreamAgent: options.untrusted ? undefined : agent,
    inactivityTimeoutMs: options.timeoutMs,
  });
  const proxyPort = await listening(proxy, t);
  return { ...f, calls, proxy, proxyPort, logs: () => output };
}
function request(
  f,
  {
    path = "/v1/responses",
    method = "POST",
    raw = headers(),
    token = "CREDENTIAL_SENTINEL",
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
          ...(authenticated ? ["Authorization", `Bearer ${token}`] : []),
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
for (const observationMode of [false, true]) {
const test = (name, run) => nodeTest(`${name} (observation ${observationMode})`, run);
const setup = (t, handler, options = {}) => setupProxy(t, handler, {...options, observeRequestMetadata: observationMode});
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
test("forwards streamed chunks before the response finishes", async (t) => {
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
test("does not follow redirects or retry upstream responses", async (t) => {
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
test("removes connection-nominated hop headers and sets the upstream host", async (t) => {
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
test("rejects untrusted TLS certificates without disabling verification", async (t) => {
  const f = await setup(t, async (req, res) => res.end("unexpected"), {
    untrusted: true,
  });
  assert.equal((await request(f)).status, 502);
  assert.equal(f.calls.length, 0);
});
test("upstream disconnect before headers is sanitized and is not retried", async (t) => {
  const f = await setup(t, async (req, res) =>
    res.destroy(new Error("RESPONSE_SENTINEL")),
  );
  const result = await request(f);
  assert.equal(result.status, 502);
  assert.equal(f.calls.length, 1);
  assert.doesNotMatch(result.body + f.logs(), /SENTINEL/);
});
test("a broken upstream stream closes the client instead of appending a fabricated response", async (t) => {
  const f = await setup(t, async (req, res) => {
    res.write("partial");
    await delay(20);
    res.destroy();
  });
  await assert.rejects(request(f));
  assert.equal(f.calls.length, 1);
  assert.doesNotMatch(f.logs(), /SENTINEL/);
});
test("upstream inactivity is bounded without retrying", async (t) => {
  const f = await setup(t, async () => {}, { timeoutMs: 70 });
  assert.equal((await request(f)).status, 502);
  assert.equal(f.calls.length, 1);
});
test("slow clients receive the complete streamed body under backpressure", async (t) => {
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
test("client cancellation closes the upstream response and is not reported as an upstream failure", async (t) => {
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
          authorization: "Bearer CREDENTIAL_SENTINEL",
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
test("malformed HTTP input produces a fixed response without dumping the packet", async (t) => {
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
