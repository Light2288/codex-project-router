import { readFile, realpath } from "node:fs/promises";
import { isAbsolute, join } from "node:path";
import { isDeepStrictEqual } from "node:util";
import { loadRouterConfig, UUID } from "./config.js";
import { inspectActivation, activate, rollback } from "./activation.js";
import { RouterError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const unavailable = recoveryRequired => ({ state: "unavailable", recoveryRequired, proxyReady: null, recordPhase: "unavailable" });
const activationContext = (configPath, cfg) => ({ configPath, codexHome: cfg.codexHome, providerId: cfg.providerId, listenPort: cfg.listenPort });
async function selectedConfig(configPath) {
  if (typeof configPath !== "string" || !isAbsolute(configPath) || await realpath(configPath) !== configPath)
    throw new RouterError("CONFIG_INVALID");
  return loadRouterConfig(configPath);
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
      entries.push({ id, name: project.name, routeAlias,
        routeState: routeAlias === null ? "unmapped" : cfg.credentialRouting &&
          !Object.hasOwn(cfg.credentialRouting.routeTargets, routeAlias) ? "target_missing" : "mapped" });
    }
    if (cfg) {
      const mappings = new Map();
      for (const [id, routeAlias] of Object.entries(cfg.projectRoutes)) {
        const normalized = id.toLowerCase();
        if (mappings.has(normalized) || identities.has(normalized) && !Object.hasOwn(projects, id))
          throw new RouterError("STATE_UNAVAILABLE");
        mappings.set(normalized, routeAlias);
        if (!Object.hasOwn(projects, id)) entries.push({ id, name: "", routeAlias, routeState: "catalog_missing" });
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
  let cfg;
  try {
    cfg = await selectedConfig(configPath);
  } catch (e) {
    const state = e.code === "ENOENT" ? "missing" : e.code === "CONFIG_INVALID" ? "invalid" : "unavailable";
    return { configuration: { state }, provider: unavailable(true), catalog: { state: "unavailable", entries: [] } };
  }
  const result = {
    configuration: { state: "valid", path: configPath, mode: cfg.credentialRouting ? "credential" : "legacy" },
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
    cfg = await selectedConfig(configPath);
  } catch {
    throw new RouterError("ACTIVATION_CONFLICT");
  }
  if (!isDeepStrictEqual(expectedContext, activationContext(configPath, cfg)))
    throw new RouterError("ACTIVATION_CONFLICT");
  return { activate, rollback }[action](configPath, { expectedContext });
}
