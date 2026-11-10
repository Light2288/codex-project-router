import { readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { UUID } from "./config.js";
import { RouterError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const sameFile = (a, b) => a.isFile() && b.isFile() &&
  ["dev", "ino", "size", "mtimeNs", "ctimeNs"].every(key => a[key] === b[key]);

export async function proveUnassignedTitle(threadId, config, { signal, deadline }) {
  let db;
  const check = () => {
    if (signal?.aborted) throw new RouterError("CANCELLED");
    if (!Number.isFinite(deadline) || Date.now() >= deadline)
      throw new RouterError("STATE_UNAVAILABLE");
  };
  try {
    check();
    if (typeof threadId !== "string" || !UUID.test(threadId))
      throw new RouterError("STATE_UNAVAILABLE");
    const id = threadId.toLowerCase(),
      statePath = join(config.codexHome, ".codex-global-state.json"),
      dbPath = join(config.codexHome, "state_5.sqlite"),
      stateBefore = await stat(statePath, { bigint: true }),
      bytes = await readFile(statePath),
      state = JSON.parse(bytes.toString("utf8"));
    if (!object(state)) throw new RouterError("STATE_UNAVAILABLE");
    const assignments = state["thread-project-assignments"],
      projects = state["local-projects"],
      projectless = state["projectless-thread-ids"];
    if (!object(assignments) || !object(projects) || !Array.isArray(projectless) ||
      projectless.some(value => typeof value !== "string" || !UUID.test(value)))
      throw new RouterError("STATE_UNAVAILABLE");
    if (Object.keys(assignments).some(key => key.toLowerCase() === id) ||
      projectless.some(value => value.toLowerCase() === id)) return false;
    check();
    const databaseBefore = await stat(dbPath, { bigint: true });
    db = new DatabaseSync(dbPath, { readOnly: true });
    const version = db.prepare("PRAGMA data_version").get().data_version;
    let known;
    db.exec("BEGIN");
    try {
      const saved = db.prepare("SELECT 1 FROM threads WHERE id = ? COLLATE NOCASE LIMIT 1").get(id);
      const edge = db.prepare(
        "SELECT 1 FROM thread_spawn_edges WHERE parent_thread_id = ? COLLATE NOCASE OR child_thread_id = ? COLLATE NOCASE LIMIT 1",
      ).get(id, id);
      known = Boolean(saved || edge);
    } finally {
      db.exec("ROLLBACK");
    }
    if (known) return false;
    // A prior healthy snapshot is insufficient. Finish every check successfully
    // on this attempt, including changes committed through SQLite's WAL.
    const finalBytes = await readFile(statePath),
      stateAfter = await stat(statePath, { bigint: true }),
      databaseAfter = await stat(dbPath, { bigint: true }),
      finalVersion = db.prepare("PRAGMA data_version").get().data_version;
    if (!bytes.equals(finalBytes) || !sameFile(stateBefore, stateAfter) ||
      !sameFile(databaseBefore, databaseAfter) || version !== finalVersion)
      throw new RouterError("STATE_UNAVAILABLE");
    check();
    return true;
  } catch (error) {
    if (error instanceof RouterError) throw error;
    throw new RouterError(signal?.aborted ? "CANCELLED" : "STATE_UNAVAILABLE");
  } finally {
    try { db?.close(); }
    catch { throw new RouterError("STATE_UNAVAILABLE"); }
  }
}
