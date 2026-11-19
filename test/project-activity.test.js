import test from "node:test";
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
