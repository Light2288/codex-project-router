import { UUID } from "./config.js";

const features = ["thread_source", "turn_trigger", "request_kind"];
const members = [...features, "thread_id", "session_id", "parent_thread_id", "forked_from_thread_id"];
const headers = ["thread-id", "session-id", "x-codex-parent-thread-id"];
const metadataHeader = "x-codex-turn-metadata";
const labels = new Set([
  "user", "desktop_app", "thread_title", "thread_title_reconsideration",
  "thread_description", "thread_summary", "compact", "compaction", "subagent",
]);
const object = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const entry = (state, type) => ({state, type, conflict: "unassessed"});
const emptyFields = (names, state) => Object.fromEntries(names.map((name) =>
  [name, entry(state, state === "absent" ? "absent" : "unknown")]));
function snapshot(state = "collected") {
  const initial = state === "collected" ? "absent" : "unavailable";
  return {
    state,
    turnMetadata: {
      state: initial,
      type: initial === "absent" ? "absent" : "unknown",
      fields: emptyFields(members, initial),
    },
    headers: emptyFields(headers, initial),
  };
}
function jsonType(value) {
  return value === null ? "null" : Array.isArray(value) ? "array" : typeof value;
}
function observeField(value, identifier) {
  const type = jsonType(value);
  if (type === "object" || type === "array") return entry("unsupported", type);
  if (type !== "string") return entry("invalid", type);
  if (!identifier)
    return {...entry("valid", type), label: labels.has(value) ? value : "other"};
  return UUID.test(value)
    ? {...entry("valid", type), id: value.toLowerCase()}
    : entry("invalid", type);
}
function compareClaims(observation) {
  for (const [header, member] of [
    ["thread-id", "thread_id"], ["session-id", "session_id"],
    ["x-codex-parent-thread-id", "parent_thread_id"],
  ]) {
    const a = observation.headers[header], b = observation.turnMetadata.fields[member];
    if (a.state === "valid" && b.state === "valid")
      a.conflict = b.conflict = a.id === b.id ? "none" : "different";
  }
  return observation;
}
function duplicateMembers(text) {
  const seen = new Set(), duplicates = new Set();
  let depth = 0;
  // Decode only top-level key tokens. String contents and nested names cannot
  // introduce fields, and escaped spellings cannot evade duplicate detection.
  for (const token of text.matchAll(/"(?:\\.|[^"\\])*"|[{}\[\]]/g)) {
    const value = token[0];
    if (value === "{" || value === "[") depth++;
    else if (value === "}" || value === "]") depth--;
    else if (depth === 1 && /^\s*:/.test(text.slice(token.index + value.length))) {
      const key = JSON.parse(value);
      if (!members.includes(key)) continue;
      if (seen.has(key)) duplicates.add(key);
      seen.add(key);
    }
  }
  return duplicates;
}
export function collectRequestMetadata(rawHeaders) {
  try {
    if (!Array.isArray(rawHeaders) || rawHeaders.length % 2) return snapshot("unavailable");
    const values = new Map(), observation = snapshot();
    for (let i = 0; i < rawHeaders.length; i += 2) {
      if (typeof rawHeaders[i] !== "string" || typeof rawHeaders[i + 1] !== "string")
        return snapshot("unavailable");
      const name = rawHeaders[i].toLowerCase();
      if (headers.includes(name) || name === metadataHeader)
        values.set(name, values.has(name) ? null : rawHeaders[i + 1]);
    }
    for (const name of headers) {
      if (!values.has(name)) continue;
      observation.headers[name] = values.get(name) === null
        ? entry("duplicate", "unknown") : observeField(values.get(name), true);
    }
    if (!values.has(metadataHeader)) return observation;
    const text = values.get(metadataHeader), turn = observation.turnMetadata;
    turn.fields = emptyFields(members, "unavailable");
    turn.type = "unknown";
    if (text === null) {
      turn.state = "duplicate";
      return observation;
    }
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      turn.state = "malformed";
      return observation;
    }
    turn.type = jsonType(parsed);
    if (!object(parsed)) {
      turn.state = "unsupported";
      return observation;
    }
    turn.state = "present";
    const duplicates = duplicateMembers(text);
    turn.fields = Object.fromEntries(members.map((name) => [name,
      duplicates.has(name) ? entry("duplicate", "unknown")
        : Object.hasOwn(parsed, name) ? observeField(parsed[name], !features.includes(name))
          : entry("absent", "absent"),
    ]));
    return compareClaims(observation);
  } catch {
    // Observation is advisory. An unexpected collector failure cannot change
    // admission or expose the exception that caused it.
    return snapshot("unavailable");
  }
}

function sanitizeField(value, identifier) {
  if (!object(value) || !["state", "type", "conflict"].every((key) => Object.hasOwn(value, key))) return null;
  const {state, type, conflict} = value;
  if (!["none", "different", "unassessed"].includes(conflict)) return null;
  const result = entry(state, type);
  if (state === "valid" && type === "string") {
    const claim = identifier ? value.id : value.label;
    if (identifier && typeof claim === "string" && UUID.test(claim))
      return {...result, id: claim.toLowerCase()};
    if (!identifier && (labels.has(claim) || claim === "other"))
      return {...result, label: claim};
    return null;
  }
  if (Object.hasOwn(value, "id") || Object.hasOwn(value, "label")) return null;
  if ((state === "absent" && type === "absent") ||
    (["duplicate", "unavailable"].includes(state) && type === "unknown") ||
    (state === "unsupported" && ["object", "array"].includes(type)) ||
    (state === "invalid" && ["number", "boolean", "null", ...(identifier ? ["string"] : [])].includes(type)))
    return result;
  return null;
}
export function sanitizeRequestMetadata(value) {
  try {
    if (!object(value) || !Object.hasOwn(value, "state") || value.state !== "collected")
      return snapshot("unavailable");
    const turn = value.turnMetadata, headerFields = value.headers;
    if (!object(turn)) return snapshot("unavailable");
    const {state, type, fields} = turn;
    if (!object(fields) || !object(headerFields)) return snapshot("unavailable");
    const validContainer =
      (state === "present" && type === "object") ||
      (state === "absent" && type === "absent") ||
      (["duplicate", "malformed", "unavailable"].includes(state) && type === "unknown") ||
      (state === "unsupported" && ["string", "number", "boolean", "null", "array"].includes(type));
    if (!validContainer) return snapshot("unavailable");
    const result = snapshot();
    result.turnMetadata.state = state;
    result.turnMetadata.type = type;
    for (const name of members) {
      if (!Object.hasOwn(fields, name)) return snapshot("unavailable");
      const field = sanitizeField(fields[name], !features.includes(name));
      if (!field || (state === "absent" && field.state !== "absent") ||
        (state === "present" && field.state === "unavailable") ||
        (!["absent", "present"].includes(state) && field.state !== "unavailable"))
        return snapshot("unavailable");
      result.turnMetadata.fields[name] = field;
    }
    for (const name of headers) {
      if (!Object.hasOwn(headerFields, name)) return snapshot("unavailable");
      const field = sanitizeField(headerFields[name], true);
      if (!field) return snapshot("unavailable");
      result.headers[name] = field;
    }
    return compareClaims(result);
  } catch {
    return snapshot("unavailable");
  }
}
