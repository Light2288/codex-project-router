import { UUID } from "./config.js";

const members = new Set([
  "thread_source", "turn_trigger", "request_kind", "thread_id", "session_id",
  "parent_thread_id", "forked_from_thread_id",
]);
const relevantHeaders = new Set([
  "thread-id", "session-id", "x-codex-turn-metadata", "x-codex-parent-thread-id",
]);

export function matchUnassignedTitle(rawHeaders) {
  try {
    if (!Array.isArray(rawHeaders) || rawHeaders.length % 2) return undefined;
    const fields = new Map();
    for (let i = 0; i < rawHeaders.length; i += 2) {
      if (typeof rawHeaders[i] !== "string" || typeof rawHeaders[i + 1] !== "string")
        return undefined;
      const key = rawHeaders[i].toLowerCase();
      if (!relevantHeaders.has(key)) continue;
      if (fields.has(key)) return undefined;
      fields.set(key, rawHeaders[i + 1]);
    }
    if (fields.has("x-codex-parent-thread-id")) return undefined;
    const text = fields.get("x-codex-turn-metadata");
    if (typeof text !== "string") return undefined;
    const meta = JSON.parse(text);
    if (meta === null || typeof meta !== "object" || Array.isArray(meta)) return undefined;
    const seen = new Set();
    let depth = 0;
    // JSON.parse loses duplicate members. Decode only top-level key tokens so
    // escaped spellings count, while nested keys and string contents do not.
    for (const token of text.matchAll(/"(?:\\.|[^"\\])*"|[{}\[\]]/g)) {
      const value = token[0];
      if (value === "{" || value === "[") depth++;
      else if (value === "}" || value === "]") depth--;
      else if (depth === 1 && /^\s*:/.test(text.slice(token.index + value.length))) {
        const key = JSON.parse(value);
        if (!members.has(key)) continue;
        if (seen.has(key)) return undefined;
        seen.add(key);
      }
    }
    for (const key of ["thread_source", "turn_trigger"])
      if (!Object.hasOwn(meta, key) || meta[key] !== "thread_title") return undefined;
    if (Object.hasOwn(meta, "parent_thread_id") || Object.hasOwn(meta, "forked_from_thread_id"))
      return undefined;
    if (!Object.hasOwn(meta, "thread_id") || !Object.hasOwn(meta, "session_id")) return undefined;
    const claims = [fields.get("thread-id"), fields.get("session-id"), meta.thread_id, meta.session_id];
    if (claims.some(value => typeof value !== "string" || !UUID.test(value))) return undefined;
    const normalized = claims.map(value => value.toLowerCase());
    return new Set(normalized).size === 1 ? normalized[0] : undefined;
  } catch {
    // Unusable claims deny only this exception; ordinary resolution still owns
    // request errors. Neither parser errors nor metadata leave this matcher.
    return undefined;
  }
}
