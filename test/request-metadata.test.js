import test from "node:test";
import assert from "node:assert/strict";
import { collectRequestMetadata, sanitizeRequestMetadata } from "../src/request-metadata.js";
import { T1, T2, CHILD } from "./helpers/fixtures.js";

const features = ["thread_source", "turn_trigger", "request_kind"];
const identifiers = ["thread_id", "session_id", "parent_thread_id", "forked_from_thread_id"];
const headerNames = ["thread-id", "session-id", "x-codex-parent-thread-id"];
const labels = ["user", "desktop_app", "thread_title", "thread_title_reconsideration", "thread_description", "thread_summary", "compact", "compaction", "subagent"];
const meta = (value, extra = []) => collectRequestMetadata([...extra, "x-codex-turn-metadata", JSON.stringify(value)]);
const rawMeta = (text, extra = []) => collectRequestMetadata([...extra, "x-codex-turn-metadata", text]);

test("missing metadata and headers are distinguished from unavailable collection", () => {
  const o = collectRequestMetadata([]);
  assert.equal(o.state, "collected");
  assert.equal(o.turnMetadata.state, "absent");
  for (const f of [...Object.values(o.turnMetadata.fields), ...Object.values(o.headers)])
    assert.deepEqual(f, {state: "absent", type: "absent", conflict: "unassessed"});
  assert.deepEqual(Object.keys(o.turnMetadata.fields), [...features, ...identifiers]);
  assert.deepEqual(Object.keys(o.headers), headerNames);
});

for (const name of features) {
  test(`classifies only fixed labels in ${name}`, () => {
    for (const label of labels)
      assert.deepEqual(meta({[name]: label}).turnMetadata.fields[name],
        {state: "valid", type: "string", conflict: "unassessed", label});
    for (const value of ["VALUE_SENTINEL", "Thread_title", "thread_title ", ""])
      assert.deepEqual(meta({[name]: value}).turnMetadata.fields[name],
        {state: "valid", type: "string", conflict: "unassessed", label: "other"});
  });
}
for (const name of identifiers) {
  test(`emits only normalized UUID claims in ${name}`, () => {
    assert.deepEqual(meta({[name]: T1.toUpperCase()}).turnMetadata.fields[name],
      {state: "valid", type: "string", conflict: "unassessed", id: T1});
    for (const value of ["ID_SENTINEL", T1 + " extra", ""])
      assert.deepEqual(meta({[name]: value}).turnMetadata.fields[name],
        {state: "invalid", type: "string", conflict: "unassessed"});
  });
}
for (const name of [...features, ...identifiers]) {
  test(`reports nonstring types without capturing their contents in ${name}`, () => {
    for (const [value, type, state] of [
      [null, "null", "invalid"], [42, "number", "invalid"], [true, "boolean", "invalid"],
      [["ARRAY_SENTINEL"], "array", "unsupported"], [{private: "OBJECT_SENTINEL"}, "object", "unsupported"],
    ]) {
      const o = meta({[name]: value});
      assert.deepEqual(o.turnMetadata.fields[name], {state, type, conflict: "unassessed"});
      assert.doesNotMatch(JSON.stringify(o), /SENTINEL|private/);
    }
  });
}
for (const name of headerNames) {
  test(`observes case-insensitive UUID header ${name} and rejects duplicate winners`, () => {
    const good = collectRequestMetadata([name.toUpperCase(), T1.toUpperCase()]);
    assert.deepEqual(good.headers[name], {state: "valid", type: "string", conflict: "unassessed", id: T1});
    assert.equal(collectRequestMetadata([name, "ID_SENTINEL"]).headers[name].state, "invalid");
    for (const second of [T1, T2]) {
      const o = collectRequestMetadata([name, T1, name.toUpperCase(), second]);
      assert.deepEqual(o.headers[name], {state: "duplicate", type: "unknown", conflict: "unassessed"});
    }
  });
}
for (const name of [...features, ...identifiers]) {
  test(`suppresses duplicate ${name} members including escaped spellings`, () => {
    const value = features.includes(name) ? "thread_title" : T1;
    const escapedName = "\\u" + name.charCodeAt(0).toString(16).padStart(4, "0") + name.slice(1);
    for (const spelling of [name, escapedName]) {
      for (const second of [value, "VALUE_SENTINEL"]) {
        const o = rawMeta(`{"${name}":"${value}","${spelling}":"${second}"}`);
        assert.deepEqual(o.turnMetadata.fields[name], {state: "duplicate", type: "unknown", conflict: "unassessed"});
        assert.doesNotMatch(JSON.stringify(o), /SENTINEL/);
      }
    }
  });
}

test("nested names and strings containing structural tokens cannot invent top-level claims", () => {
  const o = meta({
    ignored: {thread_source: "thread_title", thread_id: T2},
    more: [{session_id: T2}],
    text: '} { "thread_id": "VALUE_SENTINEL", \\"',
    thread_id: T1,
  });
  assert.equal(o.turnMetadata.fields.thread_id.id, T1);
  assert.equal(o.turnMetadata.fields.session_id.state, "absent");
  assert.equal(o.turnMetadata.fields.thread_source.state, "absent");
  assert.doesNotMatch(JSON.stringify(o), /SENTINEL|ignored|more|text/);
  const escaped = rawMeta(`{"thr\\u0065ad_id":"${T1}"}`);
  assert.equal(escaped.turnMetadata.fields.thread_id.id, T1);
});

test("malformed and unsupported metadata retain safe independent header observations", () => {
  const cases = [
    ["{BAD_SENTINEL", "malformed", "unknown"],
    ['{"thread_source":"user",}', "malformed", "unknown"],
    ['"ROOT_SENTINEL"', "unsupported", "string"],
    ["[]", "unsupported", "array"], ["null", "unsupported", "null"],
    ["5", "unsupported", "number"], ["true", "unsupported", "boolean"],
  ];
  for (const [text, state, type] of cases) {
    const o = rawMeta(text, ["thread-id", T1]);
    assert.equal(o.state, "collected");
    assert.equal(o.turnMetadata.state, state);
    assert.equal(o.turnMetadata.type, type);
    for (const field of Object.values(o.turnMetadata.fields))
      assert.deepEqual(field, {state: "unavailable", type: "unknown", conflict: "unassessed"});
    assert.equal(o.headers["thread-id"].id, T1);
    assert.doesNotMatch(JSON.stringify(o), /SENTINEL/);
  }
});
test("duplicate metadata headers never select a metadata value", () => {
  const o = collectRequestMetadata(["thread-id", T1, "x-codex-turn-metadata", "{}", "X-Codex-Turn-Metadata", '{"thread_id":"' + T2 + '"}']);
  assert.equal(o.turnMetadata.state, "duplicate");
  assert.equal(o.turnMetadata.type, "unknown");
  assert.equal(o.turnMetadata.fields.thread_id.state, "unavailable");
  assert.equal(o.headers["thread-id"].id, T1);
});
test("same-role claims record disagreement without merging distinct roles", () => {
  for (const [header, member] of [["thread-id", "thread_id"], ["session-id", "session_id"], ["x-codex-parent-thread-id", "parent_thread_id"]]) {
    for (const [other, expected] of [[T1.toUpperCase(), "none"], [T2, "different"]]) {
      const o = meta({[member]: other}, [header, T1]);
      assert.equal(o.headers[header].conflict, expected);
      assert.equal(o.turnMetadata.fields[member].conflict, expected);
      assert.equal(o.headers[header].id, T1);
      assert.equal(o.turnMetadata.fields[member].id, other.toLowerCase());
    }
    assert.equal(meta({[member]: "BAD_SENTINEL"}, [header, T1]).headers[header].conflict, "unassessed");
  }
  const o = meta({thread_id: CHILD, session_id: T1, parent_thread_id: T1, forked_from_thread_id: T2});
  for (const name of identifiers) assert.equal(o.turnMetadata.fields[name].conflict, "unassessed");
});
test("collection failures produce a fixed unavailable snapshot without exception text", () => {
  const raw = [];
  Object.defineProperty(raw, 0, {get() {throw new Error("EXCEPTION_SENTINEL");}});
  raw.length = 2;
  for (const value of [null, {}, ["odd"], raw]) {
    const o = collectRequestMetadata(value);
    assert.equal(o.state, "unavailable");
    assert.equal(o.turnMetadata.state, "unavailable");
    assert.doesNotMatch(JSON.stringify(o), /SENTINEL/);
  }
});
test("sanitization rebuilds only fixed fields and rejects forged or inconsistent claims", () => {
  const o = meta({request_kind: "thread_title", thread_id: T1});
  o.turnMetadata.fields.thread_id.extra = "EXTRA_SENTINEL";
  o.turnMetadata.fields.extra = "KEY_SENTINEL";
  o.headers.authorization = "CREDENTIAL_SENTINEL";
  o.extra = "RAW_SENTINEL";
  const safe = sanitizeRequestMetadata(o);
  assert.equal(safe.turnMetadata.fields.thread_id.id, T1);
  assert.equal(safe.turnMetadata.fields.request_kind.label, "thread_title");
  assert.doesNotMatch(JSON.stringify(safe), /SENTINEL|authorization|extra/);
  const cases = [
    (v) => {v.turnMetadata.fields.thread_id.id = "ID_SENTINEL";},
    (v) => {v.turnMetadata.fields.request_kind.label = "LABEL_SENTINEL";},
    (v) => {v.turnMetadata.fields.thread_id.type = "TYPE_SENTINEL";},
    (v) => {v.turnMetadata.fields.thread_id.state = "STATE_SENTINEL";},
    (v) => {v.turnMetadata.fields.thread_id.conflict = "CONFLICT_SENTINEL";},
    (v) => {v.turnMetadata.fields.thread_id.state = "duplicate";},
    (v) => {v.turnMetadata.state = "absent";},
    (v) => {delete v.turnMetadata.fields.session_id;},
    (v) => {v.state = "STATE_SENTINEL";},
  ];
  for (const forge of cases) {
    const value = meta({request_kind: "thread_title", thread_id: T1});
    forge(value);
    const rejected = sanitizeRequestMetadata(value);
    assert.equal(rejected.state, "unavailable");
    assert.doesNotMatch(JSON.stringify(rejected), /SENTINEL/);
  }
  assert.equal(sanitizeRequestMetadata({get state() {throw new Error("GETTER_SENTINEL");}}).state, "unavailable");
});
test("diagnostic sanitization validates the same scalar snapshots that it emits", () => {
  for (const name of ["label", "state", "id"]) {
    const value = meta({request_kind: "thread_title", thread_id: T1});
    const object = name === "label" ? value.turnMetadata.fields.request_kind
      : name === "state" ? value.turnMetadata : value.turnMetadata.fields.thread_id;
    const first = object[name];
    let reads = 0;
    Object.defineProperty(object, name, {get() {return ++reads === 1 ? first : "GETTER_SENTINEL";}});
    const safe = sanitizeRequestMetadata(value);
    assert.equal(safe.state, "collected");
    assert.equal(safe.turnMetadata.state, "present");
    assert.equal(safe.turnMetadata.fields.request_kind.label, "thread_title");
    assert.equal(safe.turnMetadata.fields.thread_id.id, T1);
    assert.doesNotMatch(JSON.stringify(safe), /SENTINEL/);
  }
});
