import { readFile, realpath, stat, lstat } from "node:fs/promises";
import { isAbsolute, relative, resolve, dirname, basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { RouterError } from "./errors.js";
export const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const routeAlias = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/;
const referenceFields = ["keychainPath", "service", "account"];
function normalizeUpstreamBaseUrl(value) {
  let upstream;
  try {
    upstream = new URL(value);
  } catch {
    throw new RouterError("CONFIG_INVALID");
  }
  if (
    upstream.protocol !== "https:" || upstream.username || upstream.password ||
    upstream.search || upstream.hash
  )
    throw new RouterError("CONFIG_INVALID");
  return upstream.href.replace(/\/$/, "");
}
function credentialReference(value) {
  if (
    !object(value) ||
    Object.keys(value).length !== referenceFields.length ||
    referenceFields.some((field) =>
      typeof value[field] !== "string" || !value[field].length ||
      value[field].length > 1024 || /[\u0000-\u001f\u007f-\u009f]/.test(value[field])) ||
    !isAbsolute(value.keychainPath)
  )
    throw new RouterError("CONFIG_INVALID");
  return Object.freeze({ keychainPath: value.keychainPath, service: value.service, account: value.account });
}
function credentialRouting(value) {
  if (
    !object(value) || Object.keys(value).length !== 2 ||
    !Object.hasOwn(value, "globalCredential") ||
    !Object.hasOwn(value, "routeTargets") || !object(value.routeTargets)
  )
    throw new RouterError("CONFIG_INVALID");
  const globalCredential = credentialReference(value.globalCredential);
  const routeTargets = Object.fromEntries(Object.entries(value.routeTargets).map(([alias, target]) => {
    if (
      !routeAlias.test(alias) || !object(target) || Object.keys(target).length !== 2 ||
      !Object.hasOwn(target, "upstreamBaseUrl") || !Object.hasOwn(target, "credential")
    ) throw new RouterError("CONFIG_INVALID");
    return [alias, Object.freeze({
      upstreamBaseUrl: normalizeUpstreamBaseUrl(target.upstreamBaseUrl),
      credential: credentialReference(target.credential),
    })];
  }));
  return Object.freeze({ globalCredential, routeTargets: Object.freeze(routeTargets) });
}
const root = fileURLToPath(new URL("../", import.meta.url));
async function readConfiguration(configPath) {
  let value, actualPath, source;
  try {
    actualPath = await realpath(configPath);
    const within = relative(root, actualPath);
    if (!within.startsWith("..") && !isAbsolute(within))
      throw new RouterError("CONFIG_INVALID");
    // Packaging relocates the source root; canonical ancestors remain the
    // authority for keeping private configuration out of any checkout/bundle.
    for (let dir = dirname(actualPath); ; dir = dirname(dir)) {
      if (basename(dir).toLowerCase().endsWith(".app"))
        throw new RouterError("CONFIG_INVALID");
      try {
        await lstat(join(dir, ".git"));
        throw new RouterError("CONFIG_INVALID");
      } catch (e) {
        if (e.code !== "ENOENT") throw e;
      }
      if (dirname(dir) === dir) break;
    }
    const info = await stat(actualPath);
    if (
      !info.isFile() ||
      (info.mode & 0o077) !== 0 ||
      info.uid !== process.getuid()
    )
      throw new RouterError("CONFIG_INVALID");
    source = await readFile(actualPath, "utf8");
    value = JSON.parse(source);
  } catch (e) {
    throw e instanceof RouterError ? e : new RouterError("CONFIG_UNAVAILABLE");
  }
  return { value, source };
}
function operationalConfig(value) {
  const fields = [
    "schemaVersion",
    "codexHome",
    "providerId",
    "upstreamBaseUrl",
    "listenPort",
    "projectRoutes",
    "observeRequestMetadata",
    "allowUnassignedThreadTitles",
    ...(value?.schemaVersion === 1 ? ["credentialRouting"] : ["accountRouting"]),
  ];
  if (
    !object(value) ||
    Object.keys(value).some((k) => !fields.includes(k)) ||
    ![1, 2].includes(value.schemaVersion) ||
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
  const upstreamBaseUrl = normalizeUpstreamBaseUrl(value.upstreamBaseUrl);
  const port = value.listenPort ?? 8787;
  if (
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65535
  )
    throw new RouterError("CONFIG_INVALID");
  for (const [id, alias] of Object.entries(value.projectRoutes)) {
    if (
      !UUID.test(id) ||
      typeof alias !== "string" ||
      !routeAlias.test(alias)
    )
      throw new RouterError("CONFIG_INVALID");
  }
  return Object.freeze({
    schemaVersion: value.schemaVersion,
    providerId: value.providerId,
    codexHome: resolve(value.codexHome),
    upstreamBaseUrl,
    listenPort: port,
    observeRequestMetadata: value.observeRequestMetadata ?? false,
    allowUnassignedThreadTitles: value.allowUnassignedThreadTitles ?? false,
    projectRoutes: Object.freeze({ ...value.projectRoutes }),
  });
}
function accountRouting(value) {
  if (!object(value) || Object.keys(value).length !== 4 ||
    !["incomingCredential", "defaultAccountId", "accounts", "routeAccounts"].every(key => Object.hasOwn(value, key)) ||
    !object(value.accounts) || !object(value.routeAccounts)) throw new RouterError("ACCOUNT_SETUP_INVALID");
  try {
    const incomingCredential = value.incomingCredential === null ? null : credentialReference(value.incomingCredential);
    const ids = new Set(), names = new Set();
    const accounts = Object.fromEntries(Object.entries(value.accounts).map(([id, account]) => {
      if (!UUID.test(id) || ids.has(id.toLowerCase()) || !object(account) || Object.keys(account).length !== 3 ||
        !["displayName", "upstreamBaseUrl", "credential"].every(key => Object.hasOwn(account, key)) ||
        typeof account.displayName !== "string" || account.displayName.trim() !== account.displayName ||
        !account.displayName.length || [...account.displayName].length > 80 ||
        /[\u0000-\u001f\u007f-\u009f]/.test(account.displayName) || names.has(account.displayName.toLowerCase()))
        throw new RouterError("ACCOUNT_SETUP_INVALID");
      ids.add(id.toLowerCase()); names.add(account.displayName.toLowerCase());
      return [id, Object.freeze({ displayName: account.displayName,
        upstreamBaseUrl: normalizeUpstreamBaseUrl(account.upstreamBaseUrl), credential: credentialReference(account.credential) })];
    }));
    const resolves = id => typeof id === "string" && UUID.test(id) && Object.hasOwn(accounts, id);
    if (value.defaultAccountId !== null && !resolves(value.defaultAccountId)) throw new RouterError("ACCOUNT_SETUP_INVALID");
    const routeAccounts = Object.fromEntries(Object.entries(value.routeAccounts).map(([alias, id]) => {
      if (!routeAlias.test(alias) || id !== null && !resolves(id)) throw new RouterError("ACCOUNT_SETUP_INVALID");
      return [alias, id];
    }));
    return Object.freeze({ incomingCredential, defaultAccountId: value.defaultAccountId,
      accounts: Object.freeze(accounts), routeAccounts: Object.freeze(routeAccounts) });
  } catch (error) {
    if (!(error instanceof RouterError)) throw error;
    throw new RouterError("ACCOUNT_SETUP_INVALID");
  }
}
export async function inspectRouterConfiguration(configPath) {
  const { value, source } = await readConfiguration(configPath);
  const core = operationalConfig(value);
  let config, setupState;
  if (value.schemaVersion === 1) {
    config = Object.freeze({ ...core, ...(Object.hasOwn(value, "credentialRouting")
      ? { credentialRouting: credentialRouting(value.credentialRouting) } : {}) });
    setupState = "migration_required";
  } else {
    let routing;
    try { routing = accountRouting(value.accountRouting); }
    catch (error) {
      if (error.code !== "ACCOUNT_SETUP_INVALID") throw error;
      // Unsafe account metadata is neither exposed nor hashed. Core validation
      // remains authoritative for browsing and restoring the original provider.
      return Object.freeze({ config: core, setupState: "invalid", configurationRevision: null });
    }
    config = Object.freeze({ ...core, accountRouting: routing });
    setupState = routing.incomingCredential !== null && routing.defaultAccountId !== null ? "ready" : "required";
  }
  return Object.freeze({ config, setupState,
    configurationRevision: createHash("sha256").update(source).digest("hex") });
}
export async function loadRouterConfig(configPath) {
  const inspection = await inspectRouterConfiguration(configPath);
  if (inspection.setupState === "invalid") throw new RouterError("ACCOUNT_SETUP_INVALID");
  if (inspection.setupState === "required") throw new RouterError("ACCOUNT_SETUP_REQUIRED");
  return inspection.config;
}
export async function loadRecoveryConfig(configPath) {
  const { value } = await readConfiguration(configPath);
  return operationalConfig(value);
}
export function operationalFingerprint(config) {
  // A recovery revision cannot impersonate a complete routing fingerprint.
  return createHash("sha256").update(JSON.stringify(["operational-recovery", operationalCanonical(config)])).digest("hex");
}
function operationalCanonical(config) {
  return [config.schemaVersion, config.codexHome, config.providerId, config.upstreamBaseUrl,
    config.listenPort, Object.entries(config.projectRoutes).sort(([a], [b]) => a.localeCompare(b))];
}
export function configFingerprint(config) {
  const canonical = operationalCanonical(config);
  // Keep the existing default-mode fingerprint compatible with running proxies.
  if (config.observeRequestMetadata === true) canonical.push("observeRequestMetadata:true");
  if (config.allowUnassignedThreadTitles === true) canonical.push("allowUnassignedThreadTitles:true");
  if (Object.hasOwn(config, "credentialRouting")) {
    const reference = ({ keychainPath, service, account }) => [keychainPath, service, account];
    canonical.push([
      "credentialRouting",
      reference(config.credentialRouting.globalCredential),
      Object.entries(config.credentialRouting.routeTargets)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([alias, target]) => [alias, target.upstreamBaseUrl, reference(target.credential)]),
    ]);
  }
  if (config.schemaVersion === 2) {
    const routing = config.accountRouting;
    if (!routing) throw new RouterError("ACCOUNT_SETUP_INVALID");
    const reference = value => value === null ? null : [value.keychainPath, value.service, value.account];
    canonical.push(["accountRouting", reference(routing.incomingCredential), routing.defaultAccountId,
      Object.entries(routing.accounts).sort(([a], [b]) => a.localeCompare(b)).map(([id, account]) =>
        [id, account.displayName, account.upstreamBaseUrl, reference(account.credential)]),
      Object.entries(routing.routeAccounts).sort(([a], [b]) => a.localeCompare(b))]);
  }
  return createHash("sha256").update(JSON.stringify(canonical)).digest("hex");
}
