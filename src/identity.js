import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { setTimeout as delay } from "node:timers/promises";
import { UUID } from "./config.js";
import { RouterError } from "./errors.js";
import { matchUnassignedTitle } from "./title-policy.js";
import { proveUnassignedTitle } from "./title-state.js";
const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
function identity(raw) {
  if (!Array.isArray(raw) || raw.length % 2)
    throw new RouterError("IDENTITY_INVALID");
  const fields = new Map();
  for (let i = 0; i < raw.length; i += 2) {
    const key = String(raw[i]).toLowerCase();
    if (!["thread-id", "session-id", "x-codex-turn-metadata"].includes(key))
      continue;
    if (fields.has(key) || typeof raw[i + 1] !== "string")
      throw new RouterError("IDENTITY_INVALID");
    fields.set(key, raw[i + 1]);
  }
  let meta = {};
  if (fields.has("x-codex-turn-metadata")) {
    try {
      const text = fields.get("x-codex-turn-metadata"), seen = new Set();
      let depth = 0;
      // Check top-level identity keys before JSON.parse discards duplicates.
      // Tokenizing whole strings excludes braces and key-like text in values;
      // decoding key tokens also catches equivalent Unicode escape spellings.
      for (const token of text.matchAll(/"(?:\\.|[^"\\])*"|[{}\[\]]/g)) {
        const value = token[0];
        if (value === "{" || value === "[") depth++;
        else if (value === "}" || value === "]") depth--;
        else if (depth === 1 && /^\s*:/.test(text.slice(token.index + value.length))) {
          const key = JSON.parse(value);
          if (["thread_id", "session_id", "parent_thread_id"].includes(key)) {
            if (seen.has(key)) throw new RouterError("IDENTITY_INVALID");
            seen.add(key);
          }
        }
      }
      meta = JSON.parse(text);
    } catch {
      throw new RouterError("IDENTITY_INVALID");
    }
    if (!object(meta)) throw new RouterError("IDENTITY_INVALID");
  }
  const id = (value) => {
    if (value === undefined || value === null) return undefined;
    if (typeof value !== "string" || !UUID.test(value))
      throw new RouterError("IDENTITY_INVALID");
    return value.toLowerCase();
  };
  const agree = (values) => {
    const present = values.map(id).filter(Boolean);
    if (new Set(present).size > 1) throw new RouterError("IDENTITY_CONFLICT");
    return present[0];
  };
  const thread = agree([fields.get("thread-id"), meta.thread_id]);
  const session = agree([fields.get("session-id"), meta.session_id]);
  if (!thread && !session) throw new RouterError("IDENTITY_INVALID");
  return {
    threadId: thread ?? session,
    sessionId: session,
    parentId: id(meta.parent_thread_id),
  };
}
async function resolveOnce(ids, config, requireRoute) {
  let db;
  try {
    const state = JSON.parse(
      await readFile(
        join(config.codexHome, ".codex-global-state.json"),
        "utf8",
      ),
    );
    const assignments = state["thread-project-assignments"],
      projects = state["local-projects"],
      projectless = state["projectless-thread-ids"];
    if (
      !object(assignments) ||
      !object(projects) ||
      !Array.isArray(projectless)
    )
      throw new RouterError("STATE_UNAVAILABLE");
    db = new DatabaseSync(join(config.codexHome, "state_5.sqlite"), {
      readOnly: true,
    });
    const parent = db.prepare(
      "SELECT parent_thread_id FROM thread_spawn_edges WHERE child_thread_id = ?",
    );
    const seen = new Set(),
      memberships = [];
    let current = ids.threadId;
    for (let depth = 0; current; depth++) {
      if (depth >= 32 || seen.has(current))
        throw new RouterError("IDENTITY_CONFLICT");
      seen.add(current);
      const assignment = Object.hasOwn(assignments, current) ? assignments[current] : undefined;
      if (projectless.includes(current))
        throw new RouterError(
          assignment ? "IDENTITY_CONFLICT" : "PROJECT_UNRESOLVED",
        );
      if (assignment !== undefined) {
        if (
          !object(assignment) ||
          assignment.projectKind !== "local" ||
          typeof assignment.projectId !== "string" ||
          !UUID.test(assignment.projectId) ||
          !Object.hasOwn(projects, assignment.projectId) ||
          !object(projects[assignment.projectId])
        )
          throw new RouterError("PROJECT_UNRESOLVED");
        if (!requireRoute) {
          const project = projects[assignment.projectId],
            normalized = assignment.projectId.toLowerCase();
          // Inheritance must never turn a catalog identity inconsistency into
          // an apparently absent override. Display names are not identity proof.
          if (typeof project.id !== "string" || !UUID.test(project.id) ||
            project.id.toLowerCase() !== normalized ||
            Object.keys(projects).filter(id => id.toLowerCase() === normalized).length !== 1)
            throw new RouterError("IDENTITY_CONFLICT");
        }
        memberships.push({
          ownerThreadId: current,
          projectId: assignment.projectId,
        });
      }
      const parents = parent.all(current);
      if (parents.length > 1) throw new RouterError("IDENTITY_CONFLICT");
      const next = parents[0]?.parent_thread_id;
      if (next !== undefined && (typeof next !== "string" || !UUID.test(next)))
        throw new RouterError("STATE_UNAVAILABLE");
      if (depth === 0 && ids.parentId && ids.parentId !== next?.toLowerCase())
        throw new RouterError("STATE_UNAVAILABLE");
      current = next?.toLowerCase();
    }
    if (ids.sessionId && !seen.has(ids.sessionId))
      throw new RouterError("IDENTITY_CONFLICT");
    if (!memberships.length) throw new RouterError("STATE_UNAVAILABLE");
    if (new Set(memberships.map((m) => requireRoute ? m.projectId : m.projectId.toLowerCase())).size > 1)
      throw new RouterError("IDENTITY_CONFLICT");
    const { ownerThreadId, projectId } = memberships[0];
    if (!requireRoute) {
      const matchingKeys = Object.keys(config.projectRoutes).filter(id => id.toLowerCase() === projectId.toLowerCase());
      if (matchingKeys.length > 1 || matchingKeys.length === 1 && matchingKeys[0] !== projectId)
        throw new RouterError("IDENTITY_CONFLICT");
    }
    const routeAlias = Object.hasOwn(config.projectRoutes, projectId) ? config.projectRoutes[projectId] : undefined;
    if (requireRoute && !routeAlias) throw new RouterError("ROUTE_UNMAPPED");
    return Object.freeze({
      threadId: ids.threadId,
      ownerThreadId,
      projectId,
      ...(routeAlias === undefined ? {} : { routeAlias }),
      source: ownerThreadId === ids.threadId ? "direct" : "ancestor",
    });
  } catch (e) {
    throw e instanceof RouterError ? e : new RouterError("STATE_UNAVAILABLE");
  } finally {
    db?.close();
  }
}
export async function identifyProject(rawHeaders, config, { signal, allowUnassignedTitle = false, requireRoute = true } = {}) {
  if (signal?.aborted) throw new RouterError("CANCELLED");
  const ids = identity(rawHeaders),
    deadline = Date.now() + 1000,
    titleId = allowUnassignedTitle === true && config.allowUnassignedThreadTitles === true
      ? matchUnassignedTitle(rawHeaders) : undefined;
  for (;;) {
    if (signal?.aborted) throw new RouterError("CANCELLED");
    try {
      return await resolveOnce(ids, config, requireRoute !== false);
    } catch (e) {
      if (titleId && e instanceof RouterError && e.code === "STATE_UNAVAILABLE" && Date.now() < deadline) {
        try {
          if (await proveUnassignedTitle(titleId, config, { signal, deadline }))
            return Object.freeze({threadId:titleId,source:"unassigned_title"});
        } catch (proofError) {
          e = proofError;
        }
      }
      if (
        !(e instanceof RouterError) ||
        e.code !== "STATE_UNAVAILABLE" ||
        Date.now() >= deadline
      ) {
        if (e instanceof RouterError) e.threadId = ids.threadId;
        throw e;
      }
      try {
        await delay(Math.min(50, deadline - Date.now()), undefined, { signal });
      } catch {
        throw new RouterError("CANCELLED");
      }
    }
  }
}
