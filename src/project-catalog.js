import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { UUID } from "./config.js";
import { RouterError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
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
export async function inspectProjectCatalog(codexHome, cfg) {
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
    // Bind only discovered identities and names; saved configuration revisions
    // separately bind mappings, including entries absent from desktop discovery.
    const identitiesAndNames = Object.entries(projects).map(([id, project]) => [id, project.name])
      .sort(([a], [b]) => a.localeCompare(b));
    const revision = createHash("sha256").update(JSON.stringify(identitiesAndNames)).digest("hex");
    return { state: "ready", revision, entries };
  } catch {
    return { state: "unavailable", entries: [] };
  }
}
