import { readFile, realpath, stat } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { RouterError } from "./errors.js";
export const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const root = fileURLToPath(new URL("../", import.meta.url));
export async function loadRouterConfig(configPath) {
  let value, actualPath;
  try {
    actualPath = await realpath(configPath);
    const within = relative(root, actualPath);
    if (!within.startsWith("..") && !isAbsolute(within))
      throw new RouterError("CONFIG_INVALID");
    const info = await stat(actualPath);
    if (
      !info.isFile() ||
      (info.mode & 0o077) !== 0 ||
      info.uid !== process.getuid()
    )
      throw new RouterError("CONFIG_INVALID");
    value = JSON.parse(await readFile(actualPath, "utf8"));
  } catch (e) {
    throw e instanceof RouterError ? e : new RouterError("CONFIG_UNAVAILABLE");
  }
  const fields = [
    "schemaVersion",
    "codexHome",
    "providerId",
    "upstreamBaseUrl",
    "listenPort",
    "projectRoutes",
    "observeRequestMetadata",
    "allowUnassignedThreadTitles",
  ];
  if (
    !object(value) ||
    Object.keys(value).some((k) => !fields.includes(k)) ||
    value.schemaVersion !== 1 ||
    (Object.hasOwn(value, "observeRequestMetadata") &&
      typeof value.observeRequestMetadata !== "boolean") ||
    (Object.hasOwn(value, "allowUnassignedThreadTitles") &&
      typeof value.allowUnassignedThreadTitles !== "boolean") ||
    typeof value.codexHome !== "string" ||
    !isAbsolute(value.codexHome) ||
    !/^[a-zA-Z0-9_-]+$/.test(value.providerId ?? "") ||
    !object(value.projectRoutes)
  )
    throw new RouterError("CONFIG_INVALID");
  let upstream;
  try {
    upstream = new URL(value.upstreamBaseUrl);
  } catch {
    throw new RouterError("CONFIG_INVALID");
  }
  const port = value.listenPort ?? 8787;
  if (
    upstream.protocol !== "https:" ||
    upstream.username ||
    upstream.password ||
    upstream.search ||
    upstream.hash ||
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65535
  )
    throw new RouterError("CONFIG_INVALID");
  for (const [id, alias] of Object.entries(value.projectRoutes)) {
    if (
      !UUID.test(id) ||
      typeof alias !== "string" ||
      !/^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/.test(alias)
    )
      throw new RouterError("CONFIG_INVALID");
  }
  return Object.freeze({
    ...value,
    codexHome: resolve(value.codexHome),
    upstreamBaseUrl: upstream.href.replace(/\/$/, ""),
    listenPort: port,
    observeRequestMetadata: value.observeRequestMetadata ?? false,
    allowUnassignedThreadTitles: value.allowUnassignedThreadTitles ?? false,
    projectRoutes: Object.freeze({ ...value.projectRoutes }),
  });
}
export function configFingerprint(config) {
  const canonical = [
    config.schemaVersion,
    config.codexHome,
    config.providerId,
    config.upstreamBaseUrl,
    config.listenPort,
    Object.entries(config.projectRoutes).sort(([a], [b]) => a.localeCompare(b)),
  ];
  // Keep the existing default-mode fingerprint compatible with running proxies.
  if (config.observeRequestMetadata === true) canonical.push("observeRequestMetadata:true");
  if (config.allowUnassignedThreadTitles === true) canonical.push("allowUnassignedThreadTitles:true");
  return createHash("sha256").update(JSON.stringify(canonical)).digest("hex");
}
