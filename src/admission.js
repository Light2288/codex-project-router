import { RouterError } from "./errors.js";
export function admitRequest(method, rawUrl, rawHeaders) {
  if (!Array.isArray(rawHeaders) || rawHeaders.length % 2)
    throw new RouterError("IDENTITY_INVALID");
  const fields = new Map(),
    unique = new Set([
      "authorization",
      "thread-id",
      "session-id",
      "x-codex-turn-metadata",
    ]);
  for (let i = 0; i < rawHeaders.length; i += 2) {
    const key = String(rawHeaders[i]).toLowerCase(),
      value = rawHeaders[i + 1];
    if (typeof value !== "string" || (unique.has(key) && fields.has(key)))
      throw new RouterError("IDENTITY_INVALID");
    fields.set(key, value);
  }
  if (
    fields.has("upgrade") ||
    typeof rawUrl !== "string" ||
    rawUrl.includes("#") ||
    rawUrl.includes("\\")
  )
    throw new RouterError("ROUTE_UNSUPPORTED");
  if (method === "GET" && rawUrl === "/healthz")
    return { kind: "health", upstreamPath: null };
  const at = rawUrl.indexOf("?"),
    path = at < 0 ? rawUrl : rawUrl.slice(0, at),
    query = at < 0 ? "" : rawUrl.slice(at);
  let kind;
  if (method === "GET" && path === "/v1/models") kind = "catalog";
  else if (
    method === "POST" &&
    ["/v1/responses", "/v1/responses/compact"].includes(path)
  )
    kind = "model";
  else throw new RouterError("ROUTE_UNSUPPORTED");
  if (!/^Bearer [^\s]+$/i.test(fields.get("authorization") ?? ""))
    throw new RouterError("AUTH_REQUIRED");
  return { kind, upstreamPath: path.slice(3) + query };
}
