import { mkdtemp, writeFile, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
export const P1 = "11111111-1111-4111-8111-111111111111";
export const P2 = "22222222-2222-4222-8222-222222222222";
export const T1 = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
export const T2 = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
export const CHILD = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
export const duplicateIdentityMetadata = [
  { id: T2, metadata: '{"thread_id":"' + T1 + '","thread_id":"' + T2 + '"}' },
  { id: T2, metadata: '{"thr\\u0065ad_id":"' + T1 + '","thread_id":"' + T2 + '"}' },
  { id: T2, metadata: '{"session_id":"' + T1 + '","session_id":"' + T2 + '"}' },
  { id: T2, metadata: '{"session_id":"' + T1 + '","\\u0073ession_id":"' + T2 + '"}' },
  { id: CHILD, metadata: '{"parent_thread_id":"' + T2 + '","parent_thread_id":"' + T1 + '"}' },
  { id: CHILD, metadata: '{"\\u0070arent_thread_id":"' + T2 + '","parent_thread_id":"' + T1 + '"}' },
  { id: T1, metadata: '{"thread_id":"' + T1 + '","thread_id":"' + T1 + '"}' },
];
export function headers(id = T1, metadata = {}) {
  return [
    "thread-id",
    id,
    "session-id",
    id,
    "x-codex-turn-metadata",
    JSON.stringify({ thread_id: id, session_id: id, ...metadata }),
  ];
}
export async function fixture(t) {
  const dir = await mkdtemp(join(tmpdir(), "router-test-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const config = {
    schemaVersion: 1,
    codexHome: dir,
    providerId: "test_gateway",
    upstreamBaseUrl: "https://gateway.example.invalid/api/v1",
    listenPort: 8787,
    projectRoutes: { [P1]: "route-a", [P2]: "route-b" },
  };
  const state = {
    "local-projects": { [P1]: { id: P1 }, [P2]: { id: P2 } },
    "thread-project-assignments": {
      [T1]: { projectKind: "local", projectId: P1 },
      [T2]: { projectKind: "local", projectId: P2 },
    },
    "projectless-thread-ids": [],
  };
  const statePath = join(dir, ".codex-global-state.json");
  const saveState = () => writeFile(statePath, JSON.stringify(state));
  await saveState();
  const dbPath = join(dir, "state_5.sqlite");
  const db = new DatabaseSync(dbPath);
  db.exec(
    "CREATE TABLE thread_spawn_edges(parent_thread_id TEXT NOT NULL, child_thread_id TEXT NOT NULL PRIMARY KEY, status TEXT NOT NULL)",
  );
  db.close();
  const configPath = join(dir, "router.json");
  const saveConfig = () =>
    writeFile(configPath, JSON.stringify(config), { mode: 0o600 });
  await saveConfig();
  return {
    dir,
    config,
    configPath,
    state,
    statePath,
    saveState,
    saveConfig,
    dbPath,
    edge(parent, child) {
      const d = new DatabaseSync(dbPath);
      try {
        d.prepare("INSERT INTO thread_spawn_edges VALUES(?,?,?)").run(
          parent,
          child,
          "completed",
        );
      } finally {
        d.close();
      }
    },
    snapshot: () => Promise.all([readFile(statePath), readFile(dbPath)]),
  };
}
