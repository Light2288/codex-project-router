import test from "node:test";
import assert from "node:assert/strict";
import { Writable } from "node:stream";
import { admitRequest } from "../src/admission.js";
import { emitDiagnostic } from "../src/diagnostics.js";
import { headers, T1, P1 } from "./helpers/fixtures.js";
const auth = ["Authorization", "Bearer CREDENTIAL_SENTINEL"];
for (const [method, path, kind, suffix] of [
  ["GET", "/healthz", "health", null],
  ["GET", "/v1/models?client_version=1", "catalog", "/models?client_version=1"],
  ["POST", "/v1/responses", "model", "/responses"],
  ["POST", "/v1/responses/compact", "model", "/responses/compact"],
]) {
  test(`admits only the intended ${method} ${path} operation`, () => {
    const a = admitRequest(method, path, auth);
    assert.equal(a.kind, kind);
    assert.equal(a.upstreamPath, suffix);
  });
}
for (const [method, path, raw] of [
  ["POST", "/v1/models", auth],
  ["GET", "/v1/responses", auth],
  ["POST", "https://example.invalid/v1/responses", auth],
  ["POST", "/v1/a/../responses", auth],
  ["POST", "/v1/%72esponses", auth],
  ["POST", "//v1/responses", auth],
  ["POST", "/v1/responses#secret", auth],
  ["POST", "/v1/responses", [...auth, "Upgrade", "websocket"]],
  ["GET", "/healthz?upstream=secret", []],
]) {
  test(`rejects unsupported operation ${method} ${path}`, () =>
    assert.throws(() => admitRequest(method, path, raw), {
      code: "ROUTE_UNSUPPORTED",
    }));
}
test("catalog requires a credential while health does not", () => {
  assert.equal(admitRequest("GET", "/healthz", []).kind, "health");
  for (const path of ["/v1/models", "/v1/responses"])
    assert.throws(
      () => admitRequest(path.endsWith("models") ? "GET" : "POST", path, []),
      { code: "AUTH_REQUIRED" },
    );
});
test("rejects repeated identity and authentication fields even with matching values", () => {
  for (const raw of [
    [...auth, ...auth],
    [...auth, ...headers(), "thread-id", T1],
    [...auth, "x-codex-turn-metadata", "{}", "X-Codex-Turn-Metadata", "{}"],
  ])
    assert.throws(() => admitRequest("POST", "/v1/responses", raw), {
      code: "IDENTITY_INVALID",
    });
});
test("diagnostics contain only fixed events and allowlisted safe metadata", () => {
  let output = "";
  const stream = new Writable({
    write(chunk, encoding, cb) {
      output += chunk;
      cb();
    },
  });
  emitDiagnostic(stream, {
    event: "started",
    requestId: T1,
    threadId: T1,
    projectId: P1,
    routeAlias: "route-a",
    source: "direct",
    operation: "compact",
    authorization: "CREDENTIAL_SENTINEL",
    body: "PROMPT_SENTINEL",
    headers: { x: "RESPONSE_SENTINEL" },
    error: new Error("ERROR_SENTINEL"),
  });
  emitDiagnostic(stream, {
    event: "RESPONSE_SENTINEL",
    errorCode: "ERROR_SENTINEL",
    threadId: "PROMPT_SENTINEL",
    routeAlias: "BAD\nCREDENTIAL_SENTINEL",
    operation: "RESPONSE_SENTINEL",
  });
  assert.doesNotMatch(output, /SENTINEL/);
  const first = JSON.parse(output.split("\n")[0]);
  assert.equal(first.projectId, P1);
  assert.equal(first.routeAlias, "route-a");
  assert.equal(first.event, "started");
  assert.equal(first.operation, "compact");
  assert.ok(first.timestamp);
});
test("diagnostics independently reject forged observation content", () => {
  let output = "";
  const stream = new Writable({write(chunk, encoding, cb) {output += chunk; cb();}});
  emitDiagnostic(stream, {event: "completed", requestMetadata: {state: "RAW_SENTINEL", headers: {authorization: "CREDENTIAL_SENTINEL"}}});
  assert.equal(JSON.parse(output).requestMetadata.state, "unavailable");
  assert.doesNotMatch(output, /SENTINEL/);
});
