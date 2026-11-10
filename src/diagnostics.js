import { UUID } from "./config.js";
import { RouterError } from "./errors.js";
import { sanitizeRequestMetadata } from "./request-metadata.js";
export function emitDiagnostic(stream, event) {
  const record = {
    timestamp: new Date().toISOString(),
    event: ["started", "completed", "rejected"].includes(event.event)
      ? event.event
      : "rejected",
  };
  const unattributedTitle = event.source === "unassigned_title";
  for (const key of unattributedTitle ? ["requestId", "threadId"] : ["requestId", "threadId", "ownerThreadId", "projectId"])
    if (typeof event[key] === "string" && UUID.test(event[key]))
      record[key] = event[key];
  if (
    !unattributedTitle && typeof event.routeAlias === "string" &&
    /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/.test(event.routeAlias)
  )
    record.routeAlias = event.routeAlias;
  if (["direct", "ancestor", "catalog", "unassigned_title"].includes(event.source))
    record.source = event.source;
  if (["responses", "compact", "catalog", "health"].includes(event.operation))
    record.operation = event.operation;
  if (
    Number.isInteger(event.status) &&
    event.status >= 100 &&
    event.status <= 599
  )
    record.status = event.status;
  if (Number.isFinite(event.elapsedMs) && event.elapsedMs >= 0)
    record.elapsedMs = event.elapsedMs;
  if (event.errorCode !== undefined)
    record.errorCode = new RouterError(event.errorCode).code;
  if (event.requestMetadata !== undefined)
    record.requestMetadata = sanitizeRequestMetadata(event.requestMetadata);
  return stream.write(JSON.stringify(record) + "\n");
}
