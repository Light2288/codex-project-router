import { DatabaseSync } from "node:sqlite";
import { fixture, P1, P2, T1, T2 } from "./fixtures.js";

export const C1 = "33333333-3333-4333-8333-333333333333";
export const C2 = "44444444-4444-4444-8444-444444444444";
export const checkpointKey = "electron-owner-value:app-server-projects-migration-by-host:signed-out";
export const bridgeKey = "app-server-project-id-by-legacy-project-id-by-host";
export const activityRow = (id, changes = {}) => ({
  id, archived: 1, source: "vscode", thread_source: "user", project_id: null,
  attached_thread_parent_id: null, has_user_event: 0, ...changes,
});

// Extend a private routing fixture; request-identity fixtures keep their smaller schema.
export async function projectActivityFixture(t) {
  const f = await fixture(t);
  const homeKey = `local:${f.dir}`;
  for (const project of Object.values(f.state["local-projects"])) {
    Object.assign(project, { name: "Synthetic project", rootPaths: [], createdAt: 1, updatedAt: 1 });
  }
  f.state["thread-project-membership-host-ids"] = { [T1]: "local", [T2]: "local" };
  f.state[checkpointKey] = {
    [homeKey]: { version: 1, projectsMigrated: true, threadAssignmentsMigrated: false, pendingThreadAssignmentIds: [T1, T2] },
  };
  f.state[bridgeKey] = { [homeKey]: { [P1]: C1, [P2]: C2 } };
  await f.saveState();
  const withDatabase = action => {
    const db = new DatabaseSync(f.dbPath);
    try { return action(db); } finally { db.close(); }
  };
  withDatabase(db => db.exec(`
    DROP TABLE threads;
    CREATE TABLE threads(id TEXT PRIMARY KEY, archived INTEGER, source TEXT, thread_source TEXT,
      project_id TEXT, attached_thread_parent_id TEXT, has_user_event INTEGER);
    CREATE TABLE backfill_state(status TEXT);
    INSERT INTO backfill_state VALUES('complete');
  `));
  const insertRow = (db, row) => db.prepare("INSERT INTO threads VALUES(?,?,?,?,?,?,?)")
    .run(row.id, row.archived, row.source, row.thread_source, row.project_id, row.attached_thread_parent_id, row.has_user_event);
  const replaceThreads = rows => withDatabase(db => {
    db.exec("DELETE FROM threads");
    for (const row of rows) insertRow(db, row);
  });
  replaceThreads([activityRow(T1), activityRow(T2)]);
  return {
    ...f, homeKey, replaceThreads,
    thread(id, changes = {}) { withDatabase(db => insertRow(db, activityRow(id, changes))); },
    replaceSpawnEdges(edges) {
      withDatabase(db => {
        db.exec("DELETE FROM thread_spawn_edges");
        const insert = db.prepare("INSERT INTO thread_spawn_edges VALUES(?,?,?)");
        for (const edge of edges) insert.run(edge.parent_thread_id, edge.child_thread_id, edge.status);
      });
    },
    setBackfillStatus(status) {
      withDatabase(db => db.prepare("UPDATE backfill_state SET status = ?").run(status));
    },
    activitySnapshot() {
      return withDatabase(db => ({
        state: structuredClone(f.state), codexHome: f.dir,
        threads: db.prepare("SELECT * FROM threads").all(),
        spawnEdges: db.prepare("SELECT * FROM thread_spawn_edges").all(),
        backfillStatus: db.prepare("SELECT status FROM backfill_state").get().status,
      }));
    },
  };
}
