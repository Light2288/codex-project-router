import fsPromises from "node:fs/promises";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { setImmediate as yieldToEventLoop } from "node:timers/promises";
import { UUID } from "./config.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const identity = value => typeof value === "string" && UUID.test(value) ? value.toLowerCase() : null;
const checkpointPrefix = "electron-owner-value:app-server-projects-migration-by-host:";
const bridgeKey = "app-server-project-id-by-legacy-project-id-by-host";
const reasonPriority = ["metadata_unavailable", "incomplete_metadata", "unsupported_metadata", "missing_record", "conflicting_membership"];
const strongerReason = (previous, next) => reasonPriority.indexOf(next) > reasonPriority.indexOf(previous) ? next : previous;

function supportedCheckpoint(value) {
  if (!object(value) || value.version !== 1 || value.projectsMigrated !== true ||
      value.threadAssignmentsMigrated !== false || Object.hasOwn(value, "threadAssignmentsReadMigrated") ||
      !Array.isArray(value.pendingThreadAssignmentIds)) return false;
  const ids = value.pendingThreadAssignmentIds.map(identity);
  return ids.every(Boolean) && new Set(ids).size === ids.length;
}

function internalSource(text) {
  if (typeof text !== "string" || text.length > 16 * 1024) return null;
  let source;
  try { source = JSON.parse(text); } catch { return null; }
  if (!object(source) || !object(source.subagent)) return null;
  // JSON.parse discards duplicate members, which could conceal a contradictory role or parent.
  // Scan only this bounded source value; object-local sets also recognize escaped key spellings.
  const containers = [];
  for (const match of text.matchAll(/"(?:\\.|[^"\\])*"|[{}\[\]]/g)) {
    const token = match[0];
    if (token === "{") containers.push(new Set());
    else if (token === "[") containers.push(null);
    else if (token === "}" || token === "]") containers.pop();
    else if (/^\s*:/.test(text.slice(match.index + token.length))) {
      const keys = containers.at(-1), key = JSON.parse(token);
      if (!keys || keys.has(key)) return null;
      keys.add(key);
    }
  }
  return source;
}

function recordKind(row, parents) {
  if (row.archived !== 0 && row.archived !== 1 ||
      !Object.hasOwn(row, "project_id") || !Object.hasOwn(row, "attached_thread_parent_id")) return "unsupported";
  const attached = row.attached_thread_parent_id;
  if (attached !== null && !identity(attached)) return "unsupported";
  if (row.source === "vscode") {
    return ["user", "agent_created_thread"].includes(row.thread_source) && attached === null && parents.length === 0
      ? "ordinary" : "unsupported";
  }
  const source = internalSource(row.source);
  if (!source) return "unsupported";
  const subagent = source.subagent;
  if (subagent.other === "guardian" && !Object.hasOwn(subagent, "thread_spawn")) {
    return row.thread_source === "guardian_review" && attached === null && parents.length === 0 ? "internal" : "unsupported";
  }
  const spawn = subagent.thread_spawn;
  if (!object(spawn) || Object.hasOwn(subagent, "other") || row.thread_source !== "subagent") return "unsupported";
  const parent = identity(spawn.parent_thread_id);
  // Completed edges still identify spawned records. Names and paths carry no membership authority.
  return parent && parents.length === 1 && parents[0] === parent &&
    (attached === null || identity(attached) === parent) ? "internal" : "unsupported";
}

/** Pure activity evidence: threads/spawnEdges are row arrays; backfillStatus is the status scalar. */
export function classifyProjectActivitySnapshot({ state, codexHome, threads, spawnEdges, backfillStatus }) {
  const projects = new Map();
  const negatives = new Map(), conflicts = new Set(), positives = new Set();
  let globalReason = null;
  const barrier = reason => { globalReason = strongerReason(globalReason, reason); };
  const uncertain = (id, reason, conflict = false) => {
    if (!projects.has(id)) return;
    negatives.set(id, strongerReason(negatives.get(id), reason));
    if (conflict) conflicts.add(id);
  };
  const discovered = state?.["local-projects"];
  if (!object(discovered)) return projects;
  for (const [rawId, project] of Object.entries(discovered)) {
    const id = identity(rawId);
    if (!id) { barrier("unsupported_metadata"); continue; }
    const duplicate = projects.has(id);
    projects.set(id, null);
    if (duplicate || !object(project) || identity(project.id) !== id)
      uncertain(id, "conflicting_membership", true);
  }
  if (!object(state) || !Array.isArray(threads) || !Array.isArray(spawnEdges)) {
    for (const id of projects.keys()) projects.set(id, { state: "unknown", reason: "metadata_unavailable" });
    return projects;
  }

  const homeKey = `local:${codexHome}`;
  const checkpoint = state[`${checkpointPrefix}signed-out`];
  if (!object(checkpoint) || !Object.hasOwn(checkpoint, homeKey)) barrier("incomplete_metadata");
  else if (!supportedCheckpoint(checkpoint[homeKey])) barrier("unsupported_metadata");
  for (const [key, owners] of Object.entries(state)) {
    if (!key.startsWith(checkpointPrefix) || key === `${checkpointPrefix}signed-out`) continue;
    if (!object(owners) || Object.hasOwn(owners, homeKey) && !supportedCheckpoint(owners[homeKey]))
      barrier("unsupported_metadata");
    else if (Object.hasOwn(owners, homeKey) && supportedCheckpoint(checkpoint?.[homeKey]) &&
      JSON.stringify(owners[homeKey].pendingThreadAssignmentIds.map(identity).sort()) !==
      JSON.stringify(checkpoint[homeKey].pendingThreadAssignmentIds.map(identity).sort()))
      barrier("conflicting_membership");
  }
  if (backfillStatus !== "complete") barrier("incomplete_metadata");

  const bridge = state[bridgeKey];
  const canonicalProjects = new Map();
  if (!object(bridge) || !object(bridge[homeKey])) barrier("incomplete_metadata");
  else {
    const seenLegacy = new Set();
    for (const [rawLegacy, rawCanonical] of Object.entries(bridge[homeKey])) {
      const legacy = identity(rawLegacy), canonical = identity(rawCanonical);
      if (!legacy) { barrier("unsupported_metadata"); continue; }
      if (!canonical) { uncertain(legacy, "unsupported_metadata"); continue; }
      const existing = canonicalProjects.get(canonical);
      if (seenLegacy.has(legacy) || existing && existing !== legacy) {
        uncertain(legacy, "conflicting_membership", true);
        if (existing) uncertain(existing, "conflicting_membership", true);
      }
      seenLegacy.add(legacy);
      canonicalProjects.set(canonical, legacy);
    }
  }

  const memberships = new Map(), assignmentThreadKeys = new Set(), duplicateAssignments = new Set();
  const assignments = state["thread-project-assignments"];
  if (!object(assignments)) barrier("incomplete_metadata");
  else for (const [rawThread, value] of Object.entries(assignments)) {
    const thread = identity(rawThread), project = object(value) ? identity(value.projectId) : null;
    if (thread) {
      if (assignmentThreadKeys.has(thread)) duplicateAssignments.add(thread);
      assignmentThreadKeys.add(thread);
    }
    if (!thread || !project) {
      if (project) uncertain(project, "unsupported_metadata");
      else barrier("unsupported_metadata");
      continue;
    }
    const claims = memberships.get(thread) ?? [];
    claims.push({ project, supported: value.projectKind === "local" });
    memberships.set(thread, claims);
    if (value.projectKind !== "local") uncertain(project, "unsupported_metadata");
  }
  for (const thread of duplicateAssignments)
    for (const claim of memberships.get(thread) ?? []) uncertain(claim.project, "conflicting_membership", true);
  const affectThread = (thread, reason, conflict = false) => {
    const claims = memberships.get(thread);
    if (claims?.length) for (const claim of claims) uncertain(claim.project, reason, conflict);
    else barrier(reason);
  };

  const hosts = new Map(), duplicateHosts = new Set();
  const hostState = state["thread-project-membership-host-ids"];
  if (!object(hostState)) barrier("incomplete_metadata");
  else for (const [rawThread, host] of Object.entries(hostState)) {
    const thread = identity(rawThread);
    if (!thread) { barrier("unsupported_metadata"); continue; }
    if (hosts.has(thread)) { duplicateHosts.add(thread); affectThread(thread, "conflicting_membership", true); }
    hosts.set(thread, host);
  }
  const projectless = new Set();
  if (!Array.isArray(state["projectless-thread-ids"])) barrier("incomplete_metadata");
  else for (const rawThread of state["projectless-thread-ids"]) {
    const thread = identity(rawThread);
    if (!thread) { barrier("unsupported_metadata"); continue; }
    if (projectless.has(thread) || memberships.has(thread)) affectThread(thread, "conflicting_membership", true);
    projectless.add(thread);
  }

  const parentsByChild = new Map(), invalidParents = new Set();
  for (const edge of spawnEdges) {
    const child = identity(edge?.child_thread_id), parent = identity(edge?.parent_thread_id);
    if (!child || !parent) {
      if (child) { invalidParents.add(child); affectThread(child, "unsupported_metadata"); }
      else barrier("unsupported_metadata");
      continue;
    }
    const parents = parentsByChild.get(child) ?? [];
    parents.push(parent);
    parentsByChild.set(child, parents);
  }

  const rows = new Map(), duplicateRows = new Set();
  for (const row of threads) {
    const thread = identity(row?.id);
    if (!thread) { barrier("unsupported_metadata"); continue; }
    if (rows.has(thread)) { duplicateRows.add(thread); affectThread(thread, "conflicting_membership", true); }
    rows.set(thread, row);
    if (!Object.hasOwn(row, "project_id")) barrier("incomplete_metadata");
    // Canonical membership is evidence of a representation we do not yet implement.
    if (row.project_id !== null && row.project_id !== undefined) {
      const canonical = canonicalProjects.get(identity(row.project_id));
      const claims = memberships.get(thread) ?? [];
      if (!canonical) {
        barrier("unsupported_metadata");
        for (const claim of claims) uncertain(claim.project, "unsupported_metadata");
      } else {
        const disagreement = claims.some(claim => claim.project !== canonical) || projectless.has(thread);
        uncertain(canonical, disagreement ? "conflicting_membership" : "unsupported_metadata", disagreement);
        for (const claim of claims) uncertain(claim.project,
          disagreement ? "conflicting_membership" : "unsupported_metadata", disagreement);
      }
    }
  }

  for (const [thread, claims] of memberships) {
    if (claims.length !== 1) continue;
    const { project, supported } = claims[0];
    if (!supported || projectless.has(thread) || duplicateHosts.has(thread) || duplicateRows.has(thread)) continue;
    if (hosts.get(thread) !== "local") { uncertain(project, "unsupported_metadata"); continue; }
    const row = rows.get(thread);
    if (!row) { uncertain(project, "missing_record"); continue; }
    if (invalidParents.has(thread)) continue;
    const kind = recordKind(row, parentsByChild.get(thread) ?? []);
    if (kind === "unsupported" || row.project_id !== null) { uncertain(project, "unsupported_metadata"); continue; }
    if (kind === "ordinary" && row.archived === 0) positives.add(project);
  }
  for (const id of projects.keys()) {
    if (positives.has(id) && !conflicts.has(id)) projects.set(id, { state: "unarchived", reason: null });
    else {
      const reason = strongerReason(globalReason, negatives.get(id));
      projects.set(id, reason ? { state: "unknown", reason } : { state: "no_active_chats", reason: null });
    }
  }
  return projects;
}

const activityFields = new Set(["local-projects", "thread-project-assignments", "thread-project-membership-host-ids", "projectless-thread-ids"]);
function relevantPath(path, homeKey) {
  const [field, home] = path;
  return activityFields.has(field) ||
    (field === bridgeKey || field?.startsWith(checkpointPrefix)) && (home === undefined || home === homeKey);
}
function hasDuplicateObservationKeys(text, homeKey) {
  // JSON.parse loses repeated claims. Inspect decoded keys only in this observation's evidence,
  // leaving independent catalog parsing and unrelated saved settings untouched.
  const stack = [];
  for (const match of text.matchAll(/"(?:\\.|[^"\\])*"|[{}\[\]]/g)) {
    const token = match[0], parent = stack.at(-1);
    if (token === "{" || token === "[") {
      stack.push({ path: parent ? [...parent.path, ...(parent.key === undefined ? [] : [parent.key])] : [],
        keys: token === "{" ? new Set() : null });
      if (parent) parent.key = undefined;
    } else if (token === "}" || token === "]") stack.pop();
    else if (/^\s*:/.test(text.slice(match.index + token.length))) {
      const key = JSON.parse(token), path = [...parent.path, key];
      if (parent.keys.has(key) && relevantPath(path, homeKey)) return true;
      parent.keys.add(key); parent.key = key;
    }
  }
  return false;
}
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  return object(value) ? Object.fromEntries(Object.keys(value).sort().map(key => [key, stable(value[key])])) : value;
}
const encoded = value => JSON.stringify(stable(value));
const fileIdentity = stat => `${stat.dev}:${stat.ino}`;
function discoveryProjection(state) {
  const projects = state?.["local-projects"], ids = new Set();
  if (!object(projects)) throw new Error("Invalid discovery");
  return Object.entries(projects).map(([key, project]) => {
    const id = identity(key);
    if (!id || !object(project) || identity(project.id) !== id || typeof project.name !== "string" || ids.has(id))
      throw new Error("Invalid discovery");
    ids.add(id);
    return [id, project.name];
  }).sort(([a], [b]) => a.localeCompare(b));
}
function normalizedEvidence(value) {
  if (typeof value === "string") return identity(value) ?? value;
  if (Array.isArray(value)) return ["array", value.map(normalizedEvidence).sort((a, b) => encoded(a).localeCompare(encoded(b)))];
  // Keep entries as pairs so normalized duplicate keys cannot disappear during comparison.
  return object(value) ? ["object", Object.entries(value).map(([key, child]) =>
    [identity(key) ?? key, normalizedEvidence(child)]).sort((a, b) => encoded(a).localeCompare(encoded(b)))] : value;
}
function membershipProjection(state, homeKey) {
  const projectIDs = Object.entries(state["local-projects"]).map(([key, value]) => [key, value.id]);
  const projection = { projects: projectIDs.sort(([a], [b]) => a.localeCompare(b)) };
  for (const field of activityFields) if (field !== "local-projects") projection[field] = state[field];
  for (const [key, value] of Object.entries(state)) if (key === bridgeKey || key.startsWith(checkpointPrefix))
    projection[key] = object(value) ? value[homeKey] : value;
  return encoded(normalizedEvidence(projection));
}
function databaseProjection(db) {
  let projection, failure;
  try {
    db.exec("BEGIN");
    const threads = db.prepare("SELECT id, archived, source, thread_source, project_id, attached_thread_parent_id FROM threads").all();
    const spawnEdges = db.prepare("SELECT parent_thread_id, child_thread_id, status FROM thread_spawn_edges").all();
    const statuses = db.prepare("SELECT status FROM backfill_state").all();
    projection = { threads, spawnEdges, backfillStatus: statuses.length === 1 ? statuses[0].status : null };
  } catch (error) { failure = error; }
  finally {
    try { db.exec("ROLLBACK"); } catch (error) { failure ??= error; }
  }
  if (failure) throw failure;
  return projection;
}
function projectionIdentity(projection) {
  if (!projection) return null;
  return encoded({ ...projection,
    threads: projection.threads.map(row => encoded(normalizedEvidence(row))).sort(),
    spawnEdges: projection.spawnEdges.map(row => encoded(normalizedEvidence(row))).sort() });
}
function unknownActivities(state, reason) {
  return new Map(Object.keys(state?.["local-projects"] ?? {}).map(id => [id.toLowerCase(), { state: "unknown", reason }]));
}

/** Read-only display evidence. This result never grants catalog editing or routing authority. */
export async function readProjectActivitySnapshot(codexHome, {
  fs = fsPromises, openDatabase = (path, options) => new DatabaseSync(path, options),
  now = Date.now, yieldOnce = yieldToEventLoop,
} = {}) {
  const statePath = join(codexHome, ".codex-global-state.json"), dbPath = join(codexHome, "state_5.sqlite");
  const homeKey = `local:${codexHome}`, started = now();
  const readState = async () => {
    const before = fileIdentity(await fs.stat(statePath));
    const text = await fs.readFile(statePath, "utf8"), state = JSON.parse(text);
    const after = fileIdentity(await fs.stat(statePath));
    return { state, file: after, changed: before !== after, discovery: encoded(discoveryProjection(state)),
      membership: membershipProjection(state, homeKey), duplicate: hasDuplicateObservationKeys(text, homeKey) };
  };
  let latest = null, discoveryChanged = false;
  for (let attempt = 0; attempt < 2; attempt++) {
    let db, first, middle, last, beforeDB, afterDB, projectionA, projectionB, unavailable = false;
    try {
      first = await readState();
      try {
        beforeDB = fileIdentity(await fs.stat(dbPath));
        db = openDatabase(dbPath, { readOnly: true });
        afterDB = fileIdentity(await fs.stat(dbPath));
        db.exec("PRAGMA busy_timeout = 0");
        projectionA = databaseProjection(db);
      } catch { unavailable = true; }
      middle = await readState();
      if (db) {
        try { projectionB = databaseProjection(db); } catch { unavailable = true; }
      }
      last = await readState(); latest = last.state;
      if (beforeDB !== undefined) {
        try {
          const finalDB = fileIdentity(await fs.stat(dbPath));
          if (db && afterDB !== beforeDB) beforeDB = null;
          afterDB = finalDB;
        } catch { afterDB = null; }
      }
    } catch {
      // Without valid current discovery no previously observed absence can be published.
      latest = null; discoveryChanged = true;
    } finally {
      if (db) {
        try { db.close(); } catch { unavailable = true; }
      }
    }
    if (first && middle && last) {
      discoveryChanged = first.discovery !== middle.discovery || middle.discovery !== last.discovery;
      const changed = discoveryChanged || first.changed || middle.changed || last.changed ||
        first.file !== middle.file || middle.file !== last.file ||
        first.membership !== middle.membership || middle.membership !== last.membership ||
        beforeDB !== afterDB || projectionIdentity(projectionA) !== projectionIdentity(projectionB);
      if (!changed) {
        const duplicate = first.duplicate || middle.duplicate || last.duplicate;
        return { state: latest, activityByProject: duplicate ? unknownActivities(latest, "conflicting_membership") :
          unavailable ? unknownActivities(latest, "metadata_unavailable") :
          classifyProjectActivitySnapshot({state:latest,codexHome,...projectionB}) };
      }
    }
    if (attempt === 1 || now() - started >= 250) break;
    await yieldOnce();
    if (now() - started >= 250) break;
  }
  return { state: discoveryChanged ? null : latest,
    activityByProject: unknownActivities(discoveryChanged ? null : latest, "changed_during_read") };
}
