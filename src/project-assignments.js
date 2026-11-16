import { createHash } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import { inspectRouterConfigurationValue, UUID } from "./config.js";
import { RouterError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const digest = source => createHash("sha256").update(source).digest("hex");
const conflict = () => new RouterError("ACTIVATION_CONFLICT");
const invalid = () => new RouterError("CONFIG_INVALID");
function assignmentSummary(config, projectId) {
  const routing = config.accountRouting;
  const hasMapping = Object.hasOwn(config.projectRoutes, projectId);
  const routeAlias = hasMapping ? config.projectRoutes[projectId] : undefined;
  const hasBinding = hasMapping && Object.hasOwn(routing.routeAccounts, routeAlias);
  const kind = !hasMapping ? "inherited" : !hasBinding
    ? "target_missing" : routing.routeAccounts[routeAlias] === null ? "legacy_inherited" : "override";
  const accountId = kind === "target_missing" ? undefined : kind === "override"
    ? routing.routeAccounts[routeAlias] : routing.defaultAccountId;
  return { kind, ...(accountId === undefined ? {} : { account: { id: accountId, displayName: routing.accounts[accountId].displayName } }),
    ...(hasMapping ? { routeAlias } : {}) };
}
function validatedSource(source) {
  if (!object(source) || typeof source.source !== "string" ||
    typeof source.configurationRevision !== "string" || digest(source.source) !== source.configurationRevision) throw conflict();
  let parsed;
  try { parsed = JSON.parse(source.source); } catch { throw conflict(); }
  if (!isDeepStrictEqual(parsed, source.value)) throw conflict();
  const inspection = inspectRouterConfigurationValue(parsed);
  if (inspection.config.schemaVersion !== 2 || inspection.setupState !== "ready") throw invalid();
  if (!isDeepStrictEqual(inspection.config, source.config)) throw conflict();
  const catalog = source.catalog;
  if (!object(catalog) || catalog.state !== "ready" || !/^[a-f0-9]{64}$/.test(catalog.revision ?? "") || !Array.isArray(catalog.entries)) throw conflict();
  const identities = new Set();
  for (const entry of catalog.entries) {
    if (!object(entry) || typeof entry.id !== "string" || !UUID.test(entry.id) || identities.has(entry.id.toLowerCase())) throw conflict();
    identities.add(entry.id.toLowerCase());
  }
  return inspection.config;
}
export function prepareProjectAssignment(source, { projectId, accountId, operationId } = {}) {
  const config = validatedSource(source);
  if (typeof projectId !== "string" || !UUID.test(projectId) || typeof operationId !== "string" || !UUID.test(operationId) ||
    accountId !== null && (typeof accountId !== "string" || !Object.hasOwn(config.accountRouting.accounts, accountId))) throw invalid();
  if (!source.catalog.entries.some(entry => entry.id === projectId)) throw conflict();
  const value = structuredClone(source.value), routing = value.accountRouting;
  const before = assignmentSummary(config, projectId);
  if (accountId === null) delete value.projectRoutes[projectId];
  else {
    const current = Object.hasOwn(value.projectRoutes, projectId) ? value.projectRoutes[projectId] : null;
    let alias = current !== null && Object.hasOwn(routing.routeAccounts, current) && routing.routeAccounts[current] === accountId
      ? current : Object.keys(routing.routeAccounts).sort().find(key => routing.routeAccounts[key] === accountId);
    if (alias === undefined) {
      alias = `assignment-${operationId.toLowerCase().replaceAll("-", "")}`;
      // Unresolved project labels reserve aliases too: creating that binding
      // would otherwise repair a different project's missing target implicitly.
      if (Object.hasOwn(routing.routeAccounts, alias) || Object.values(value.projectRoutes).includes(alias)) throw conflict();
      routing.routeAccounts[alias] = accountId;
    }
    value.projectRoutes[projectId] = alias;
  }
  const changed = !isDeepStrictEqual(value, source.value);
  const nextSource = changed ? JSON.stringify(value, null, 2) + "\n" : source.source;
  const candidate = inspectRouterConfigurationValue(value);
  if (candidate.setupState !== "ready" || candidate.config.schemaVersion !== 2) throw invalid();
  return { value, config: candidate.config, source: nextSource,
    configurationRevision: changed ? digest(nextSource) : source.configurationRevision,
    changed, operationId, projectId, before, after: assignmentSummary(candidate.config, projectId) };
}
