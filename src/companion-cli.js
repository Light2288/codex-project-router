import { isAbsolute } from "node:path";
import { inspectCompanion, runCompanionControl } from "./companion.js";
import { RouterError, safeError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const exact = (value, fields) => object(value) && Object.keys(value).length === fields.length && fields.every(field => Object.hasOwn(value, field));
const absolute = value => typeof value === "string" && isAbsolute(value);
function validate(input) {
  if (process.versions.node.split(".")[0] !== "24" || !object(input) || input.schemaVersion !== 1)
    throw new RouterError("CONFIG_INVALID");
  if (input.action === "inspect") {
    const fields = input.configPath === null ? ["schemaVersion", "action", "configPath", "browseHome"] : ["schemaVersion", "action", "configPath"];
    if (!exact(input, fields) || (input.configPath === null ? !absolute(input.browseHome) : !absolute(input.configPath)))
      throw new RouterError("CONFIG_INVALID");
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
    if (bytes > 16 * 1024) throw new RouterError("CONFIG_INVALID");
    chunks.push(chunk);
  }
  try {
    return validate(JSON.parse(Buffer.concat(chunks).toString("utf8")));
  } catch {
    throw new RouterError("CONFIG_INVALID");
  }
}
async function main() {
  const input = await readInput();
  const result = input.action === "inspect" ? await inspectCompanion(input) : await runCompanionControl(input);
  const output = JSON.stringify({ schemaVersion: 1, ok: true, result }) + "\n";
  if (Buffer.byteLength(output) > 1024 * 1024) throw new RouterError("CONFIG_INVALID");
  process.stdout.write(output);
}
main().catch(error => {
  const safe = safeError(error);
  process.stdout.write(JSON.stringify({ schemaVersion: 1, ok: false, error: { code: safe.code, message: safe.message } }) + "\n");
  process.exitCode = 1;
});
