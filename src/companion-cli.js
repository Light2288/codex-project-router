import { isAbsolute } from "node:path";
import { inspectCompanion, runCompanionControl, previewAccountSetup, commitAccountSetup } from "./companion.js";
import { RouterError, safeError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const exact = (value, fields) => object(value) && Object.keys(value).length === fields.length && fields.every(field => Object.hasOwn(value, field));
const absolute = value => typeof value === "string" && isAbsolute(value);
const context = c => exact(c, ["configPath", "codexHome", "providerId", "listenPort"]) && absolute(c.configPath) &&
  absolute(c.codexHome) && typeof c.providerId === "string" && /^[a-zA-Z0-9_-]+$/.test(c.providerId) &&
  Number.isInteger(c.listenPort) && c.listenPort >= 1 && c.listenPort <= 65535;
function validate(input) {
  if (process.versions.node.split(".")[0] !== "24" || !object(input) || input.schemaVersion !== 1)
    throw new RouterError("CONFIG_INVALID");
  if (input.action === "inspect") {
    const hasBrowseHome = Object.hasOwn(input, "browseHome");
    const fields = hasBrowseHome ? ["schemaVersion", "action", "configPath", "browseHome"] : ["schemaVersion", "action", "configPath"];
    if (!exact(input, fields) || (input.configPath === null ? !hasBrowseHome : !absolute(input.configPath)) ||
      hasBrowseHome && !absolute(input.browseHome))
      throw new RouterError("CONFIG_INVALID");
  } else if (input.action === "setup_preview") {
    const fields = Object.hasOwn(input,"browseHome") ? ["schemaVersion","action","configPath","browseHome"] : ["schemaVersion","action","configPath"];
    if (!exact(input,fields) || !absolute(input.configPath) || Object.hasOwn(input,"browseHome") && !absolute(input.browseHome)) throw new RouterError("CONFIG_INVALID");
  } else if (input.action === "setup_commit") {
    if (!exact(input,["schemaVersion","action","configPath","expectedContext","expectedRevision","operationId","change"]) ||
      !absolute(input.configPath) || !context(input.expectedContext) || typeof input.expectedRevision !== "string" || !/^[a-f0-9]{64}$/.test(input.expectedRevision) ||
      typeof input.operationId !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.operationId) || !object(input.change)) throw new RouterError("CONFIG_INVALID");
  } else {
    const c = input.expectedContext;
    if (!["activate", "rollback"].includes(input.action) ||
      !exact(input, ["schemaVersion", "action", "configPath", "expectedContext"]) || !absolute(input.configPath) ||
      !exact(c, ["configPath", "codexHome", "providerId", "listenPort"]) || !absolute(c.configPath) ||
      !absolute(c.codexHome) || typeof c.providerId !== "string" || !/^[a-zA-Z0-9_-]+$/.test(c.providerId) ||
      !Number.isInteger(c.listenPort) || c.listenPort < 1 || c.listenPort > 65535)
      throw new RouterError("CONFIG_INVALID");
  }
  return input;
}
async function readInput() {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of process.stdin) {
    bytes += chunk.length;
    if (bytes > 1024 * 1024) throw new RouterError("CONFIG_INVALID");
    chunks.push(chunk);
  }
  try {
    const input = validate(JSON.parse(Buffer.concat(chunks).toString("utf8")));
    if (!["setup_preview","setup_commit"].includes(input.action) && bytes > 16 * 1024) throw new RouterError("CONFIG_INVALID");
    return input;
  } catch {
    throw new RouterError("CONFIG_INVALID");
  }
}
async function main() {
  const input = await readInput();
  let result;
  if (input.action === "inspect") result = await inspectCompanion(input);
  else if (input.action === "setup_preview") result = await previewAccountSetup({configPath:input.configPath,...(Object.hasOwn(input,"browseHome")?{browseHome:input.browseHome}:{})});
  else if (input.action === "setup_commit") {
    const {schemaVersion,action,...commit} = input;
    result = await commitAccountSetup(commit);
  } else result = await runCompanionControl(input);
  const output = JSON.stringify({ schemaVersion: 1, ok: true, result }) + "\n";
  if (Buffer.byteLength(output) > 1024 * 1024) throw new RouterError("CONFIG_INVALID");
  process.stdout.write(output);
}
main().catch(error => {
  const safe = safeError(error);
  process.stdout.write(JSON.stringify({ schemaVersion: 1, ok: false, error: { code: safe.code, message: safe.message } }) + "\n");
  process.exitCode = 1;
});
