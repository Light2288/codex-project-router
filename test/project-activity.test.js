import test from "node:test";
import fs from "node:fs/promises";
import { DatabaseSync } from "node:sqlite";
import * as activity from "../src/project-activity.js";
import { inspectProjectCatalog } from "../src/project-catalog.js";
import assert from "node:assert/strict";
import { classifyProjectActivitySnapshot as classify } from "../src/project-activity.js";
import { P1, P2, T1, T2, CHILD } from "./helpers/fixtures.js";
import { projectActivityFixture, activityRow, checkpointKey, bridgeKey, C1, C2 } from "./helpers/project-activity.js";

const inactive = { state: "no_active_chats", reason: null };
const active = { state: "unarchived", reason: null };
const unknown = reason => ({ state: "unknown", reason });

// Catches dropping empty projects, treating has_user_event as activity, or age-based filtering.
test("supported empty archived and mixed projects", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  delete snapshot.state["thread-project-assignments"][T1];
  assert.deepEqual(classify(snapshot).get(P1), inactive);
  assert.deepEqual(classify(snapshot).get(P2), inactive);
  snapshot.state["thread-project-assignments"][T1] = { projectKind: "local", projectId: P1 };
  snapshot.state["thread-project-assignments"][T2].projectId = P1;
  for (const kind of ["user", "agent_created_thread"]) {
    snapshot.threads[0] = activityRow(T1, { archived: 0, thread_source: kind, has_user_event: 0 });
    assert.deepEqual(classify(snapshot).get(P1), active);
  }
  snapshot.threads[0].archived = 1;
  assert.deepEqual(classify(snapshot).get(P1), inactive);
});

// Catches treating a completed index or vanished row as archived evidence.
test("deleted referenced chat remains unknown", async t => {
  const f = await projectActivityFixture(t);
  f.replaceThreads([activityRow(T1)]);
  const result = classify(f.activitySnapshot());
  assert.deepEqual(result.get(P2), unknown("missing_record"));
  assert.deepEqual(result.get(P1), inactive);
});

// Catches ancestor propagation or ignoring completed spawn edges as parent evidence.
test("explicit direct membership never expands ancestry", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  snapshot.threads.push(activityRow(CHILD, { archived: 0,
    source: JSON.stringify({ subagent: { thread_spawn: { parent_thread_id: T1, depth: 1,
      agent_path: "synthetic", agent_nickname: "Synthetic", agent_role: "worker" } } }), thread_source: "subagent" }));
  snapshot.spawnEdges.push({ parent_thread_id: T1, child_thread_id: CHILD, status: "completed" });
  assert.deepEqual(classify(snapshot).get(P1), inactive);
  snapshot.state["thread-project-assignments"][CHILD] = { projectKind: "local", projectId: P2 };
  snapshot.state["thread-project-membership-host-ids"][CHILD] = "local";
  assert.deepEqual(classify(snapshot).get(P2), inactive);
  snapshot.threads[2].attached_thread_parent_id = T2;
  assert.deepEqual(classify(snapshot).get(P2), unknown("unsupported_metadata"));
  snapshot.threads[2].attached_thread_parent_id = null;
  snapshot.spawnEdges = [];
  assert.deepEqual(classify(snapshot).get(P2), unknown("unsupported_metadata"));
});

// Catches broadening ordinary source support or assuming a different migration owner is safe.
test("unsupported source and owner checkpoint stay visible", async t => {
  const f = await projectActivityFixture(t);
  for (const source of ["cli", "exec", "new_source", '{"subagent":{"other":"unknown"}}']) {
    const snapshot = f.activitySnapshot();
    snapshot.threads[0].source = source;
    assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"), source);
    assert.deepEqual(classify(snapshot).get(P2), inactive);
  }
  const snapshot = f.activitySnapshot();
  snapshot.state["electron-owner-value:app-server-projects-migration-by-host:account:synthetic"] = {
    [f.homeKey]: { version: 2, projectsMigrated: true, threadAssignmentsMigrated: true },
  };
  assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
  snapshot.threads[0].archived = 0;
  assert.deepEqual(classify(snapshot).get(P1), active);
});

// Catches trusting canonical membership as a second backend or accepting disagreement as positive.
test("canonical conflicts cannot establish absence", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  snapshot.threads[0].project_id = C1;
  assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
  assert.deepEqual(classify(snapshot).get(P2), inactive);
  snapshot.threads[0].project_id = C2;
  snapshot.threads[0].archived = 0;
  assert.deepEqual(classify(snapshot).get(P1), unknown("conflicting_membership"));
  assert.deepEqual(classify(snapshot).get(P2), unknown("conflicting_membership"));
  snapshot.threads[0].project_id = CHILD;
  assert.deepEqual(classify(snapshot).get(P2), unknown("unsupported_metadata"));
});

test("guardian records require consistent source role and parent evidence", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  snapshot.threads[0] = activityRow(T1, { archived: 0,
    source: '{"subagent":{"other":"guardian"}}', thread_source: "guardian_review" });
  assert.deepEqual(classify(snapshot).get(P1), inactive);
  snapshot.threads[0].thread_source = "user";
  assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
  snapshot.threads[0].thread_source = "guardian_review";
  snapshot.spawnEdges.push({ parent_thread_id: T2, child_thread_id: T1, status: "completed" });
  assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
});

test("duplicate internal source members cannot conceal contradictory role or parent evidence", async t => {
  const f = await projectActivityFixture(t);
  for (const source of [
    '{"subagent":{"other":"unsupported","other":"guardian"}}',
    '{"subagent":{"other":"unsupported","oth\\u0065r":"guardian"}}',
    '{"subagent":{"other":"unsupported"},"subagent":{"other":"guardian"}}',
  ]) {
    const snapshot = f.activitySnapshot();
    snapshot.threads[0] = activityRow(T1, { archived: 0, source, thread_source: "guardian_review" });
    assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
  }
  const snapshot = f.activitySnapshot();
  snapshot.threads[0] = activityRow(T1, { archived: 0, thread_source: "subagent",
    source: `{"subagent":{"thread_spawn":{"parent_thread_id":"${CHILD}","parent_thread_id":"${T2}"}}}` });
  snapshot.spawnEdges = [{ parent_thread_id: T2, child_thread_id: T1, status: "completed" }];
  assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
});

test("oversized internal source metadata remains unknown", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  snapshot.threads[0] = activityRow(T1, { archived: 0, thread_source: "guardian_review",
    source: '{"subagent":{"other":"guardian"}}' + " ".repeat(16 * 1024) });
  assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
});

test("malformed archive values never prove either known state", async t => {
  const f = await projectActivityFixture(t);
  for (const archived of [null, "0", "1", false, true, -1, 2, undefined]) {
    const snapshot = f.activitySnapshot();
    snapshot.threads[0].archived = archived;
    assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
  }
});

test("normalized duplicate identities and projectless contradictions are rejected", async t => {
  const f = await projectActivityFixture(t);
  const original = f.activitySnapshot();
  for (const mutate of [
    s => { s.threads.push(activityRow(T1.toUpperCase(), { archived: 0 })); },
    s => { s.state["thread-project-assignments"][T1.toUpperCase()] = { projectKind: "local", projectId: P2 }; },
    s => { s.state["projectless-thread-ids"] = [T1]; s.threads[0].archived = 0; },
  ]) {
    const snapshot = structuredClone(original);
    mutate(snapshot);
    assert.deepEqual(classify(snapshot).get(P1), unknown("conflicting_membership"));
  }
  const duplicateProjects = structuredClone(original);
  // Use a letter-bearing UUID because numeric-only fixture IDs have no case variant.
  duplicateProjects.state["local-projects"][T1] = { id: T1, name: "Synthetic" };
  duplicateProjects.state["local-projects"][T1.toUpperCase()] = { id: T1.toUpperCase(), name: "Synthetic" };
  assert.deepEqual(classify(duplicateProjects).get(T1), unknown("conflicting_membership"));
});

for (const malformedFirst of [false, true]) {
  test(`malformed duplicate assignment conflicts with valid membership (${malformedFirst ? "malformed first" : "valid first"})`, async t => {
    const f = await projectActivityFixture(t);
    const snapshot = f.activitySnapshot();
    const valid = [T1, { projectKind: "local", projectId: P1 }];
    const malformed = [T1.toUpperCase(), { projectKind: "local", projectId: "invalid" }];
    snapshot.state["thread-project-assignments"] = Object.fromEntries(
      malformedFirst ? [malformed, valid] : [valid, malformed],
    );
    snapshot.threads[0].archived = 0;
    assert.deepEqual(classify(snapshot).get(P1), unknown("conflicting_membership"));
  });
}

test("remote missing and conflicting host evidence cannot classify its membership", async t => {
  const f = await projectActivityFixture(t);
  for (const host of ["remote:synthetic", null, undefined]) {
    const snapshot = f.activitySnapshot();
    snapshot.state["thread-project-membership-host-ids"][T1] = host;
    snapshot.threads[0].archived = 0;
    assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
    assert.deepEqual(classify(snapshot).get(P2), inactive);
  }
  const snapshot = f.activitySnapshot();
  snapshot.state["thread-project-membership-host-ids"][T1.toUpperCase()] = "remote:synthetic";
  assert.deepEqual(classify(snapshot).get(P1), unknown("conflicting_membership"));
});

test("unsupported checkpoint and index profiles block negatives only", async t => {
  const f = await projectActivityFixture(t);
  for (const mutate of [
    s => { delete s.state[checkpointKey]; },
    s => { s.state[checkpointKey][f.homeKey].version = 2; },
    s => { s.state[checkpointKey][f.homeKey].threadAssignmentsMigrated = true; },
    s => { s.state[checkpointKey][f.homeKey].threadAssignmentsReadMigrated = false; },
    s => { s.state[checkpointKey][f.homeKey].pendingThreadAssignmentIds = ["invalid"]; },
    s => { s.backfillStatus = "in_progress"; },
  ]) {
    const snapshot = f.activitySnapshot();
    mutate(snapshot);
    assert.equal(classify(snapshot).get(P1).state, "unknown");
    snapshot.threads[0].archived = 0;
    assert.deepEqual(classify(snapshot).get(P1), active);
  }
});

test("additional owner checkpoints require matching normalized pending membership sets", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  const ownerKey = "electron-owner-value:app-server-projects-migration-by-host:account:synthetic";
  snapshot.state[ownerKey] = { [f.homeKey]: {
    version: 1, projectsMigrated: true, threadAssignmentsMigrated: false,
    pendingThreadAssignmentIds: [T2.toUpperCase(), T1.toUpperCase()],
  } };
  assert.deepEqual(classify(snapshot).get(P1), inactive);
  snapshot.state[ownerKey][f.homeKey].pendingThreadAssignmentIds = [T2];
  assert.deepEqual(classify(snapshot).get(P1), unknown("conflicting_membership"));
  snapshot.threads[0].archived = 0;
  assert.deepEqual(classify(snapshot).get(P1), active);
  snapshot.threads[0].archived = 1;
  snapshot.state[ownerKey] = { "local:/synthetic-other-home": { version: 99 } };
  assert.deepEqual(classify(snapshot).get(P1), inactive);
});

test("unlocalizable malformed evidence blocks absence without hiding supported positive evidence", async t => {
  const f = await projectActivityFixture(t);
  for (const mutate of [
    s => { s.state["thread-project-assignments"].invalid = { projectKind: "local", projectId: "invalid" }; },
    s => { s.state["projectless-thread-ids"] = ["invalid"]; },
    s => { s.state[bridgeKey][f.homeKey].invalid = C1; },
    s => { s.spawnEdges.push({ parent_thread_id: "invalid", child_thread_id: "invalid", status: "completed" }); },
    s => { s.threads.push(activityRow("invalid")); },
  ]) {
    const snapshot = f.activitySnapshot();
    mutate(snapshot);
    assert.equal(classify(snapshot).get(P2).state, "unknown");
    snapshot.threads[0].archived = 0;
    assert.deepEqual(classify(snapshot).get(P1), active);
  }
});

test("unavailable projections degrade discovered identities without inventing configured ones", async t => {
  const f = await projectActivityFixture(t);
  for (const key of ["threads", "spawnEdges"]) {
    const snapshot = f.activitySnapshot();
    snapshot[key] = null;
    assert.deepEqual(classify(snapshot).get(P1), unknown("metadata_unavailable"));
  }
  const snapshot = f.activitySnapshot();
  snapshot.state["local-projects"] = { [P1.toUpperCase()]: { id: P1.toUpperCase(), name: "Synthetic" } };
  assert.deepEqual([...classify(snapshot).keys()], [P1]);
  assert.equal(classify(snapshot).has(P2), false);
});

test("missing canonical projection cannot establish absence for unassigned rows", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  delete snapshot.state["thread-project-assignments"][T1];
  delete snapshot.threads[0].project_id;
  assert.deepEqual(classify(snapshot).get(P1), unknown("incomplete_metadata"));
  assert.deepEqual(classify(snapshot).get(P2), unknown("incomplete_metadata"));
});

test("bridge conflicts remain scoped to the projects with contradictory identities", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  snapshot.state["local-projects"][T1] = { id: T1, name: "Synthetic third project" };
  snapshot.state[bridgeKey][f.homeKey][T1] = C1;
  assert.deepEqual(classify(snapshot).get(P1), unknown("conflicting_membership"));
  assert.deepEqual(classify(snapshot).get(T1), unknown("conflicting_membership"));
  assert.deepEqual(classify(snapshot).get(P2), inactive);
});

test("malformed bridge targets remain scoped when the legacy identity is valid", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  snapshot.state[bridgeKey][f.homeKey][P1] = "invalid";
  assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
  assert.deepEqual(classify(snapshot).get(P2), inactive);
});

test("uppercase project membership and chat identities normalize consistently", async t => {
  const f = await projectActivityFixture(t);
  const snapshot = f.activitySnapshot();
  snapshot.state["local-projects"] = { [T1.toUpperCase()]: { id: T1, name: "Synthetic" } };
  snapshot.state["thread-project-assignments"] = { [T2.toUpperCase()]: { projectKind: "local", projectId: T1.toUpperCase() } };
  snapshot.state["thread-project-membership-host-ids"] = { [T2]: "local" };
  snapshot.threads = [activityRow(T2.toUpperCase(), { archived: 0 })];
  assert.deepEqual([...classify(snapshot)], [[T1, active]]);
});

test("ordinary roots with parent evidence and malformed direct memberships stay unknown", async t => {
  const f = await projectActivityFixture(t);
  for (const mutate of [
    s => { s.threads[0].attached_thread_parent_id = T2; },
    s => { s.spawnEdges.push({ parent_thread_id: T2, child_thread_id: T1, status: "completed" }); },
    s => { s.state["thread-project-assignments"][T1].projectKind = "remote"; },
  ]) {
    const snapshot = f.activitySnapshot();
    mutate(snapshot);
    assert.deepEqual(classify(snapshot).get(P1), unknown("unsupported_metadata"));
  }
});

test("fixture replacements preserve complete synthetic projection and saved state", async t => {
  const f = await projectActivityFixture(t);
  f.replaceThreads([activityRow(T2, { archived: 0 })]);
  f.replaceSpawnEdges([{ parent_thread_id: T1, child_thread_id: CHILD, status: "completed" }]);
  f.setBackfillStatus("pending");
  delete f.state["thread-project-assignments"][T1];
  await f.saveState();
  const snapshot = f.activitySnapshot();
  assert.deepEqual(classify(snapshot).get(P2), active);
  assert.equal(snapshot.spawnEdges[0].status, "completed");
  assert.equal(snapshot.backfillStatus, "pending");
});

// These exercise real SQLite/JSON; injected boundaries deterministically place writes between reads.
function observingDatabase(events, onOpen = () => {}) {
  return (path, options) => {
    assert.equal(options.readOnly, true);
    onOpen();
    const db = new DatabaseSync(path, options);
    events.push("open");
    return {
      exec(sql) { events.push(sql); return db.exec(sql); },
      prepare(sql) { return db.prepare(sql); },
      close() { events.push("close"); db.close(); },
    };
  };
}
function changingJSON(f, mutate) {
  let reads = 0;
  return { ...fs, async readFile(path, ...args) {
    if (path === f.statePath) await mutate(++reads);
    return fs.readFile(path, ...args);
  } };
}

test("activity snapshots detect membership archive and file replacement races", async t => {
  for (const race of ["membership", "archive", "database replacement", "state replacement", "spawn", "backfill"]) {
    await t.test(race, async t => {
      const f = await projectActivityFixture(t), events = [];
      let changes = 0, yields = 0;
      const injectedFS = changingJSON(f, async read => {
        if (read % 3 !== 2) return;
        changes++;
        if (race === "membership") {
          f.state["thread-project-assignments"][T1].projectId = changes % 2 ? P2 : P1;
          await f.saveState();
        } else if (race === "archive") f.replaceThreads([activityRow(T1, { archived: (changes + 1) % 2 }), activityRow(T2)]);
        else if (race === "database replacement") {
          await fs.copyFile(f.dbPath, f.dbPath + ".replacement");
          await fs.rename(f.dbPath + ".replacement", f.dbPath);
        } else if (race === "state replacement") {
          await fs.copyFile(f.statePath, f.statePath + ".replacement");
          await fs.rename(f.statePath + ".replacement", f.statePath);
        } else if (race === "spawn") f.replaceSpawnEdges(changes % 2 ? [{parent_thread_id:T2,child_thread_id:T1,status:"completed"}] : []);
        else f.setBackfillStatus(changes % 2 ? "pending" : "complete");
      });
      const result = await activity.readProjectActivitySnapshot(f.dir, {
        fs: injectedFS, openDatabase: observingDatabase(events), now: () => 0, yieldOnce: async () => { yields++; },
      });
      assert.deepEqual(result.activityByProject.get(P1), unknown("changed_during_read"));
      assert.deepEqual(result.activityByProject.get(P2), unknown("changed_during_read"));
      assert.equal(events.filter(e => e === "open").length, 2);
      assert.equal(events.filter(e => e === "close").length, 2);
      assert.equal(events.filter(e => e === "BEGIN").length, 4);
      assert.equal(events.filter(e => e === "ROLLBACK").length, 4);
      assert.equal(yields, 1);
    });
  }
});

test("unrelated token and read-state changes preserve activity", async t => {
  const f = await projectActivityFixture(t), events = [];
  f.replaceThreads([activityRow(T1, {archived:0}), activityRow(T2)]);
  const before = await f.snapshot();
  let opens = 0;
  const result = await activity.readProjectActivitySnapshot(f.dir, { openDatabase: observingDatabase(events, () => opens++),
    fs: changingJSON(f, async read => {
      f.state["thread-read-state"] = { [T1]: read };
      f.state["local-projects"][P1].updatedAt = read;
      await f.saveState();
      const db = new DatabaseSync(f.dbPath);
      try { db.exec("CREATE TABLE IF NOT EXISTS tokens(value INTEGER)"); db.prepare("INSERT INTO tokens VALUES(?)").run(read); }
      finally { db.close(); }
    }),
  });
  assert.deepEqual(result.activityByProject.get(P1), active);
  assert.deepEqual(result.activityByProject.get(P2), inactive);
  assert.equal(opens, 1);
  const settled = await f.snapshot();
  const observed = await activity.readProjectActivitySnapshot(f.dir);
  assert.deepEqual(observed.activityByProject.get(P1), active);
  assert.deepEqual(await f.snapshot(), settled, "observation must not write either store");
  assert.notDeepEqual(settled, before, "synthetic writer actually changed unrelated metadata");
});

test("settled archive unarchive move and deletion converge on refresh", async t => {
  const f = await projectActivityFixture(t);
  delete f.state["thread-project-assignments"][T2];
  await f.saveState();
  f.replaceThreads([activityRow(T1, {archived:0})]);
  const configuration = await fs.readFile(f.configPath);
  const revision = (await inspectProjectCatalog(f.dir, f.config)).revision;
  const check = async (a, b) => {
    const state = await fs.readFile(f.statePath), db = await fs.readFile(f.dbPath);
    const catalog = await inspectProjectCatalog(f.dir, f.config, {includeActivity:true});
    assert.equal(catalog.state, "ready"); assert.equal(catalog.revision, revision);
    assert.deepEqual(catalog.entries.find(e => e.id === P1).chatActivity, a);
    assert.deepEqual(catalog.entries.find(e => e.id === P2).chatActivity, b);
    assert.deepEqual(await fs.readFile(f.configPath), configuration);
    assert.deepEqual(await fs.readFile(f.statePath), state);
    assert.deepEqual(await fs.readFile(f.dbPath), db);
    assert.deepEqual(f.config.projectRoutes, {[P1]:"route-a",[P2]:"route-b"});
  };
  await check(active, inactive);
  f.replaceThreads([activityRow(T1)]); await check(inactive, inactive);
  f.replaceThreads([activityRow(T1, {archived:0})]); await check(active, inactive);
  f.state["thread-project-assignments"][T1].projectId = P2; await f.saveState();
  await check(inactive, active);
  f.replaceThreads([]); await check(inactive, unknown("missing_record"));
});

test("activity retries recover once and respect the 250 ms budget", async t => {
  const f = await projectActivityFixture(t);
  let opens = 0, yields = 0;
  const events = [];
  const dependencies = { fs: changingJSON(f, async read => {
    if (read === 2) { f.replaceThreads([activityRow(T1, {archived:0}),activityRow(T2)]); }
  }), openDatabase: observingDatabase(events, () => opens++), now: () => 0, yieldOnce: async () => { yields++; } };
  assert.deepEqual((await activity.readProjectActivitySnapshot(f.dir, dependencies)).activityByProject.get(P1), active);
  assert.equal(opens, 2); assert.equal(yields, 1);
  opens = 0; yields = 0; let time = 0;
  const result = await activity.readProjectActivitySnapshot(f.dir, {
    ...dependencies, now: () => time,
    fs: changingJSON(f, async read => { if (read === 2) { time = 250; f.replaceThreads([activityRow(T1)]); } }),
  });
  assert.deepEqual(result.activityByProject.get(P1), unknown("changed_during_read"));
  assert.equal(opens, 1); assert.equal(yields, 0);
});

test("old missing locked and failing activity databases degrade without writes or leaked transactions", async t => {
  for (const kind of ["old", "missing", "locked", "open failure", "query failure"]) await t.test(kind, async t => {
    const f = await projectActivityFixture(t), events = [];
    let lock;
    if (kind === "old") { const db = new DatabaseSync(f.dbPath); db.exec("ALTER TABLE threads DROP COLUMN project_id"); db.close(); }
    if (kind === "missing") await fs.unlink(f.dbPath);
    if (kind === "locked") { lock = new DatabaseSync(f.dbPath); lock.exec("BEGIN EXCLUSIVE"); }
    const before = await fs.readdir(f.dir);
    const state = await fs.readFile(f.statePath);
    const dbBytes = kind === "missing" ? null : await fs.readFile(f.dbPath);
    try {
      const result = await activity.readProjectActivitySnapshot(f.dir, { openDatabase: kind === "query failure" ? (path, options) => {
        const db = observingDatabase(events)(path, options);
        return { ...db, prepare() { throw new Error("PRIVATE_SQL_SENTINEL"); } };
      } : kind === "open failure" ? () => { throw new Error("PRIVATE_OPEN_SENTINEL"); } : observingDatabase(events) });
      assert.deepEqual(result.activityByProject.get(P1), unknown("metadata_unavailable"));
      assert.equal(result.state["local-projects"][P1].id, P1);
      assert.equal(events.filter(e => e === "open").length, events.filter(e => e === "close").length);
      assert.equal(events.filter(e => e === "BEGIN").length, events.filter(e => e === "ROLLBACK").length);
      if (events.includes("open")) assert.ok(events.includes("PRAGMA busy_timeout = 0"));
      assert.doesNotMatch(JSON.stringify([...result.activityByProject]), /PRIVATE_SQL_SENTINEL/);
      assert.deepEqual(await fs.readdir(f.dir), before);
      assert.deepEqual(await fs.readFile(f.statePath), state);
      if (dbBytes) assert.deepEqual(await fs.readFile(f.dbPath), dbBytes);
    } finally { if (lock) { lock.exec("ROLLBACK"); lock.close(); } }
  });
});

test("changing or lost global discovery remains catalog unavailable", async t => {
  const f = await projectActivityFixture(t);
  for (const change of ["rename", "identity", "unreadable"]) {
    const result = await activity.readProjectActivitySnapshot(f.dir, {now:()=>0,yieldOnce:async()=>{},
      fs: changingJSON(f, async read => {
        if (change === "unreadable") throw new Error("PRIVATE_STATE_SENTINEL");
        if (change === "rename") f.state["local-projects"][P1].name = `Synthetic ${read}`;
        else if (read % 2) delete f.state["local-projects"][P2];
        else f.state["local-projects"][P2] = {id:P2,name:"Synthetic"};
        await f.saveState();
      }),
    });
    assert.equal(result.state, null);
    assert.equal(result.activityByProject.size, 0);
  }
});

test("raw duplicate identity claims including escaped keys cannot establish known activity", async t => {
  const f = await projectActivityFixture(t);
  for (const duplicate of [
    `"${T1}":{"projectId":"${P2}","projectKind":"local"},"${T1}":{"projectId":"${P1}","projectKind":"local"}`,
    `"${T1}":{"projectId":"${P2}","projectId":"${P1}","projectKind":"local"}`,
    `"${T1}":{"projectId":"${P2}","project\\u0049d":"${P1}","projectKind":"local"}`,
  ]) {
    f.replaceThreads([activityRow(T1,{archived:0}),activityRow(T2)]);
    const raw = JSON.stringify(f.state).replace(/"thread-project-assignments":\{.*?\},"projectless-thread-ids"/, `"thread-project-assignments":{${duplicate}},"projectless-thread-ids"`);
    await fs.writeFile(f.statePath, raw);
    const result = await activity.readProjectActivitySnapshot(f.dir);
    assert.deepEqual(result.activityByProject.get(P1), unknown("conflicting_membership"));
    assert.deepEqual(result.activityByProject.get(P2), unknown("conflicting_membership"));
    assert.equal((await inspectProjectCatalog(f.dir,f.config)).state, "ready");
  }
  f.state.unrelated = {value:1};
  await fs.writeFile(f.statePath,JSON.stringify(f.state).replace('"unrelated":{"value":1}', '"unrelated":{"value":0,"value":1}'));
  assert.deepEqual((await activity.readProjectActivitySnapshot(f.dir)).activityByProject.get(P1), active);
});

test("normalized identity spelling and set ordering do not create false activity races", async t => {
  const f = await projectActivityFixture(t), events = [];
  const result = await activity.readProjectActivitySnapshot(f.dir, {
    fs: changingJSON(f, async read => {
      f.state["thread-project-assignments"] = read % 2 ? {
        [T1]:{projectId:P1,projectKind:"local"},[T2]:{projectId:P2,projectKind:"local"},
      } : {[T2.toUpperCase()]:{projectId:P2.toUpperCase(),projectKind:"local"},[T1.toUpperCase()]:{projectId:P1.toUpperCase(),projectKind:"local"}};
      f.state[checkpointKey][f.homeKey].pendingThreadAssignmentIds = read % 2 ? [T1,T2] : [T2.toUpperCase(),T1.toUpperCase()];
      await f.saveState();
      f.replaceThreads(read % 2 ? [activityRow(T1,{archived:0}),activityRow(T2)] : [activityRow(T2.toUpperCase()),activityRow(T1.toUpperCase(),{archived:0})]);
    }), openDatabase: observingDatabase(events), now:()=>0,yieldOnce:async()=>{},
  });
  assert.deepEqual(result.activityByProject.get(P1),active);
  assert.deepEqual(result.activityByProject.get(P2),inactive);
  assert.equal(events.filter(e=>e==="open").length,1);
});

test("final JSON comparison detects late membership changes and bounds retries after yielding", async t => {
  const f = await projectActivityFixture(t), events = [];
  let time=0,yields=0;
  const result=await activity.readProjectActivitySnapshot(f.dir,{
    fs:changingJSON(f,async read=>{
      if(read===3){f.state["thread-project-assignments"][T1].projectId=P2;await f.saveState();time=249;}
    }),openDatabase:observingDatabase(events),now:()=>time,yieldOnce:async()=>{yields++;time=250;},
  });
  assert.equal(result.state["thread-project-assignments"][T1].projectId,P2);
  assert.deepEqual(result.activityByProject.get(P1),unknown("changed_during_read"));
  assert.equal(events.filter(e=>e==="open").length,1);assert.equal(yields,1);
});

test("catalog-only configured projects remain unresolved in enriched browsing", async t => {
  const f=await projectActivityFixture(t);
  delete f.state["local-projects"][P2];await f.saveState();
  const pure=await inspectProjectCatalog(f.dir,f.config);
  const enriched=await inspectProjectCatalog(f.dir,f.config,{includeActivity:true});
  assert.equal(pure.revision,enriched.revision);
  assert.deepEqual(enriched.entries.find(e=>e.id===P2),{
    id:P2,name:"",routeAlias:"route-b",routeState:"catalog_missing",chatActivity:unknown("project_unresolved"),
  });
});

test("state loss after opening SQLite closes the observation before degrading discovery", async t => {
  const f=await projectActivityFixture(t),events=[];
  const result=await activity.readProjectActivitySnapshot(f.dir,{
    fs:changingJSON(f,async read=>{if(read>=2)throw new Error("PRIVATE_DISCOVERY_SENTINEL");}),
    openDatabase:observingDatabase(events),now:()=>0,yieldOnce:async()=>{},
  });
  assert.equal(result.state,null);assert.equal(result.activityByProject.size,0);
  assert.equal(events.filter(e=>e==="open").length,events.filter(e=>e==="close").length);
  assert.equal(events.filter(e=>e==="BEGIN").length,events.filter(e=>e==="ROLLBACK").length);
});

// Catches reading only the checkpointed main database and writes during WAL observation.
test("activity observes committed current WAL records without changing application-store bytes", async t => {
  const f = await projectActivityFixture(t);
  const writer = new DatabaseSync(f.dbPath);
  const checkpointPath = f.dbPath + '.checkpoint';
  try {
    writer.exec("PRAGMA journal_mode = WAL; PRAGMA wal_autocheckpoint = 0; PRAGMA wal_checkpoint(TRUNCATE)");
    await fs.copyFile(f.dbPath, checkpointPath);
    const mainBefore = await fs.readFile(f.dbPath);
    writer.prepare("UPDATE threads SET archived = 0 WHERE id = ?").run(T1);
    assert.deepEqual(await fs.readFile(f.dbPath), mainBefore, "committed update must exist only in WAL");
    assert.ok((await fs.stat(f.dbPath + '-wal')).size > 0);
    const checkpoint = new DatabaseSync(checkpointPath, {readOnly:true});
    try { assert.equal(checkpoint.prepare("SELECT archived FROM threads WHERE id = ?").get(T1).archived, 1); }
    finally { checkpoint.close(); }
    const paths = [f.statePath, f.dbPath, f.dbPath + '-wal', f.configPath];
    const before = await Promise.all(paths.map(path => fs.readFile(path)));
    const observed = await activity.readProjectActivitySnapshot(f.dir);
    assert.deepEqual(observed.activityByProject.get(P1), active);
    assert.deepEqual(observed.activityByProject.get(P2), inactive);
    assert.deepEqual(await Promise.all(paths.map(path => fs.readFile(path))), before,
      "global JSON, main DB, committed WAL and configuration bytes must be unchanged");
    // SQLite may create/update its SHM coordination sidecar; directory immutability is not claimed.
  } finally { writer.close(); }
});
