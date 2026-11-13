import { readFile, realpath, lstat } from "node:fs/promises";
import { isAbsolute, join, dirname } from "node:path";
import { isDeepStrictEqual } from "node:util";
import { loadRouterConfig, loadRecoveryConfig, inspectRouterConfiguration, UUID } from "./config.js";
import { inspectActivation, activate, rollback } from "./activation.js";
import { RouterError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
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
function catalogEntry(id, name, routeAlias, cfg, catalogMissing = false) {
  const entry = { id, name, routeAlias,
    routeState: catalogMissing ? "catalog_missing" : routeAlias === null ? "unmapped" : cfg?.credentialRouting &&
      !Object.hasOwn(cfg.credentialRouting.routeTargets, routeAlias) ? "target_missing" : "mapped" };
  if (cfg?.schemaVersion !== 2) return entry;
  const routing = cfg.accountRouting;
  let account;
  if (routeAlias === null) {
    entry.assignmentKind = "inherited";
    account = accountSummary(routing, routing?.defaultAccountId);
  } else if (!routing || !Object.hasOwn(routing.routeAccounts, routeAlias)) {
    entry.assignmentKind = "target_missing";
    if (!catalogMissing) entry.routeState = "target_missing";
  } else if (routing.routeAccounts[routeAlias] === null) {
    entry.assignmentKind = "legacy_inherited";
    account = accountSummary(routing, routing.defaultAccountId);
  } else {
    entry.assignmentKind = "override";
    account = accountSummary(routing, routing.routeAccounts[routeAlias]);
  }
  if (account) entry.account = account;
  return entry;
}
async function catalog(codexHome, cfg) {
  try {
    const state = JSON.parse(await readFile(join(codexHome, ".codex-global-state.json"), "utf8"));
    const projects = state?.["local-projects"];
    if (!object(projects)) throw new RouterError("STATE_UNAVAILABLE");
    const identities = new Set(), entries = [];
    for (const [id, project] of Object.entries(projects)) {
      if (!UUID.test(id) || !object(project) || typeof project.id !== "string" ||
        !UUID.test(project.id) || id.toLowerCase() !== project.id.toLowerCase() ||
        typeof project.name !== "string" || identities.has(id.toLowerCase()))
        throw new RouterError("STATE_UNAVAILABLE");
      identities.add(id.toLowerCase());
      const routeAlias = cfg && Object.hasOwn(cfg.projectRoutes, id) ? cfg.projectRoutes[id] : null;
      entries.push(catalogEntry(id, project.name, routeAlias, cfg));
    }
    if (cfg) {
      const mappings = new Map();
      for (const [id, routeAlias] of Object.entries(cfg.projectRoutes)) {
        const normalized = id.toLowerCase();
        if (mappings.has(normalized) || identities.has(normalized) && !Object.hasOwn(projects, id))
          throw new RouterError("STATE_UNAVAILABLE");
        mappings.set(normalized, routeAlias);
        if (!Object.hasOwn(projects, id)) entries.push(catalogEntry(id, "", routeAlias, cfg, true));
      }
    }
    entries.sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
    return { state: "ready", entries };
  } catch {
    return { state: "unavailable", entries: [] };
  }
}
export async function inspectCompanion({ configPath, browseHome } = {}) {
  if (configPath === null) {
    if (typeof browseHome !== "string" || !isAbsolute(browseHome)) throw new RouterError("CONFIG_INVALID");
    return { configuration: { state: "missing" }, provider: unavailable(false), catalog: await catalog(browseHome) };
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
    return { configuration: { state }, provider: unavailable(true),
      catalog: absent ? await catalog(browseHome) : { state: "unavailable", entries: [] } };
  }
  const result = {
    configuration: { state: "valid", path: configPath,
      mode: cfg.schemaVersion === 2 ? "accounts" : cfg.credentialRouting ? "credential" : "legacy",
      setupState: inspection.setupState,
      ...(accountSummary(cfg.accountRouting, cfg.accountRouting?.defaultAccountId)
        ? { defaultAccount: accountSummary(cfg.accountRouting, cfg.accountRouting.defaultAccountId) } : {}) },
    context: activationContext(configPath, cfg),
    provider: unavailable(true),
    catalog: await catalog(cfg.codexHome, cfg),
  };
  try {
    const inspection = await inspectActivation(configPath);
    // A concurrent context edit cannot produce a mixed-context projection.
    if (!isDeepStrictEqual(inspection.context, result.context)) return result;
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
