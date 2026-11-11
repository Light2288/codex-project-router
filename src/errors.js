const definitions = {
  CONFIG_INVALID: [400, "Router configuration is invalid or unsupported."],
  CONFIG_UNAVAILABLE: [503, "Router configuration could not be read."],
  IDENTITY_INVALID: [400, "Request identity is missing or malformed."],
  IDENTITY_CONFLICT: [
    409,
    "Request identity conflicts with saved project membership.",
  ],
  PROJECT_UNRESOLVED: [422, "No supported project assignment was found."],
  ROUTE_UNMAPPED: [422, "The assigned project has no explicit route alias."],
  STATE_UNAVAILABLE: [
    503,
    "Desktop identity state could not be resolved within the lookup window.",
  ],
  CANCELLED: [499, "The request was cancelled."],
  ROUTE_UNSUPPORTED: [404, "This operation is not supported by the router."],
  AUTH_REQUIRED: [401, "Existing provider bearer authentication is required."],
  AUTH_INVALID: [401, "The incoming bearer credential is not accepted."],
  CREDENTIAL_UNMAPPED: [422, "The assigned route has no credential reference."],
  CREDENTIAL_UNAVAILABLE: [503, "The required credential could not be retrieved."],
  UPSTREAM_FAILED: [502, "The upstream connection failed."],
  INTERNAL_ERROR: [500, "The router could not complete this operation."],
  ACTIVATION_CONFLICT: [
    409,
    "Configuration or activation state changed; no overwrite was performed.",
  ],
  PROXY_NOT_READY: [503, "A matching local proxy is not ready."],
  CONFIG_UNSUPPORTED: [
    422,
    "The active Codex provider configuration is unsupported.",
  ],
  STORAGE_FAILED: [
    500,
    "Private configuration state could not be safely updated.",
  ],
};
export class RouterError extends Error {
  constructor(code) {
    const [status, message] = definitions[code] ?? definitions.INTERNAL_ERROR;
    super(message);
    this.name = "RouterError";
    this.code = Object.hasOwn(definitions, code) ? code : "INTERNAL_ERROR";
    this.status = status;
  }
}
export function safeError(error) {
  return error instanceof RouterError
    ? error
    : new RouterError("INTERNAL_ERROR");
}
