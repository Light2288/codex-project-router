import { readFile, realpath, lstat, readdir } from "node:fs/promises";
import { isAbsolute, join, dirname } from "node:path";
import { isDeepStrictEqual } from "node:util";
import { loadRouterConfig, loadRecoveryConfig, inspectRouterConfiguration, readRouterConfigurationSource } from "./config.js";
import { inspectActivation, inspectProviderConfiguration, activate, rollback } from "./activation.js";
import { inspectProjectCatalog } from "./project-catalog.js";
import { RouterError } from "./errors.js";
import { parse } from "smol-toml";

const unavailable = recoveryRequired => ({ state: "unavailable", recoveryRequired, proxyReady: null, recordPhase: "unavailable" });
const activationContext = (configPath, cfg) => ({ configPath, codexHome: cfg.codexHome, providerId: cfg.providerId, listenPort: cfg.listenPort });
async function selectedConfig(configPath, load = loadRouterConfig) {
  if (typeof configPath !== "string" || !isAbsolute(configPath) || await realpath(configPath) !== configPath)
    throw new RouterError("CONFIG_INVALID");
  return load(configPath);
}
function accountSummary(routing, id) {
  return routing && typeof id === "string" && Object.hasOwn(routing.accounts, id)
    ? { id, displayName: routing.accounts[id].displayName } : undefined;
}
async function missingProviderSettled(configPath, browseHome) {
  try {
    const directory = dirname(configPath), parent = await lstat(directory);
    if (!parent.isDirectory() || parent.uid !== process.getuid() || parent.mode & 0o077 ||
        await realpath(directory) !== directory || await realpath(browseHome) !== browseHome) return false;
    const recoveryEvidence = name => name === "activation.json" || name === "companion-journal.json" ||
      /^codex-config-.*\.toml$/.test(name) || /^account-setup-checkpoint-/.test(name);
    if ((await readdir(directory)).some(recoveryEvidence)) return false;
    const providerPath = join(browseHome, "config.toml"), before = await lstat(providerPath);
    if (!before.isFile() || before.uid !== process.getuid() || before.nlink !== 1 || before.mode & 0o022) return false;
    const source = await readFile(providerPath, "utf8"), providerId = parse(source).model_provider;
    if (typeof providerId !== "string" || !/^[a-zA-Z0-9_-]+$/.test(providerId)) return false;
    const provider = inspectProviderConfiguration(source, { providerId }), url = new URL(provider.url);
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) return false;
    const after = await lstat(providerPath), latestParent = await lstat(directory);
    // Setup receipts/leases belong to the native transaction guard, including its
    // own prepared receipt during revalidation. They do not prove provider use.
    return before.dev === after.dev && before.ino === after.ino && before.mode === after.mode &&
      before.uid === after.uid && before.nlink === after.nlink && await readFile(providerPath, "utf8") === source &&
      parent.dev === latestParent.dev && parent.ino === latestParent.ino && parent.mode === latestParent.mode &&
      !(await readdir(directory)).some(recoveryEvidence) &&
      await lstat(configPath).then(() => false, error => error.code === "ENOENT");
  } catch {
    // Unreadable, unsafe or incompatible evidence keeps recovery required.
    return false;
  }
}
export async function inspectCompanion({ configPath, browseHome } = {}) {
  if (configPath === null) {
    if (typeof browseHome !== "string" || !isAbsolute(browseHome)) throw new RouterError("CONFIG_INVALID");
    return { configuration: { state: "missing" }, provider: unavailable(false), catalog: await inspectProjectCatalog(browseHome) };
  }
  let cfg, inspection;
  try {
    inspection = await selectedConfig(configPath, inspectRouterConfiguration);
    cfg = inspection.config;
  } catch (e) {
    const state = e.code === "ENOENT" ? "missing" : e.code === "CONFIG_INVALID" ? "invalid" : "unavailable";
    // Only a genuinely absent file in a canonical existing directory permits the
    // normal-home catalog fallback. Existing unsafe evidence grants no fallback.
    const absent = state === "missing" && typeof browseHome === "string" && isAbsolute(browseHome) &&
      await lstat(configPath).then(() => false, error => error.code === "ENOENT") &&
      await realpath(dirname(configPath)).then(parent => parent === dirname(configPath), () => false);
    return { configuration: { state }, provider: unavailable(!(absent && await missingProviderSettled(configPath, browseHome))),
      catalog: absent ? await inspectProjectCatalog(browseHome) : { state: "unavailable", entries: [] } };
  }
  let source;
  try {
    source = await readRouterConfigurationSource(configPath);
    // Account/catalog summaries must be projected from the descriptor-bound source.
    inspection = source; cfg = source.config;
  } catch {
    // Optional editing authority must not tighten legacy catalog browsing.
  }
  const result = {
    configuration: { state: "valid", path: configPath,
      mode: cfg.schemaVersion === 2 ? "accounts" : cfg.credentialRouting ? "credential" : "legacy",
      setupState: inspection.setupState,
      ...(cfg.schemaVersion === 2 && cfg.accountRouting ? { accounts: Object.entries(cfg.accountRouting.accounts)
        .sort(([a], [b]) => a.localeCompare(b)).map(([id, account]) => ({ id, displayName: account.displayName })) } : {}),
      ...(accountSummary(cfg.accountRouting, cfg.accountRouting?.defaultAccountId)
        ? { defaultAccount: accountSummary(cfg.accountRouting, cfg.accountRouting.defaultAccountId) } : {}) },
    context: activationContext(configPath, cfg),
    provider: unavailable(true),
    catalog: await inspectProjectCatalog(cfg.codexHome, cfg, { includeActivity: cfg.schemaVersion === 2 }),
  };
  try {
    const inspection = await inspectActivation(configPath);
    // A concurrent context edit cannot produce a mixed-context projection.
    if (!isDeepStrictEqual(inspection.context, result.context)) return result;
    if (source && (source.configurationRevision !== inspection.configurationRevision ||
        source.configurationIdentity !== inspection.configurationIdentity)) return result;
    if (source) {
      result.configurationRevision = inspection.configurationRevision;
      result.configurationIdentity = inspection.configurationIdentity;
      result.routingFingerprint = inspection.routingFingerprint;
    }
    result.recoveryRevision = inspection.recoveryRevision;
    result.revision = inspection.revision;
    result.provider = { ...inspection.status, state: inspection.status.state === "active" ? "router" : inspection.status.state, recordPhase: inspection.recordPhase };
  } catch {
    // Catalog browsing is independent of provider/recovery compatibility.
  }
  return result;
}
export async function runCompanionControl({ action, configPath, expectedContext } = {}) {
  if (!["activate", "rollback"].includes(action)) throw new RouterError("CONFIG_INVALID");
  let cfg;
  try {
    cfg = await selectedConfig(configPath, action === "rollback" ? loadRecoveryConfig : loadRouterConfig);
  } catch (error) {
    if (["ACCOUNT_SETUP_REQUIRED", "ACCOUNT_SETUP_INVALID"].includes(error.code)) throw error;
    throw new RouterError("ACTIVATION_CONFLICT");
  }
  if (!isDeepStrictEqual(expectedContext, activationContext(configPath, cfg)))
    throw new RouterError("ACTIVATION_CONFLICT");
  return { activate, rollback }[action](configPath, { expectedContext });
}

// Setup remains a one-shot metadata boundary, separate from managed mode control.
export { previewAccountSetup, commitAccountSetup } from "./account-setup.js";

// Stopped assignment helpers accept no running-child or publication authority.
export { readProjectAssignmentState, commitProjectAssignment } from "./project-assignments.js";
