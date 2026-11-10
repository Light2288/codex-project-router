import test from "node:test";
import assert from "node:assert/strict";
import { writeFile, unlink } from "node:fs/promises";
import { setTimeout as delay } from "node:timers/promises";
import { loadRouterConfig, configFingerprint } from "../src/config.js";
import { identifyProject } from "../src/identity.js";
import { fixture, headers, titleHeaders, P1, P2, T1, T2, CHILD, duplicateIdentityMetadata } from "./helpers/fixtures.js";
import { DatabaseSync } from "node:sqlite";

test("eligible titles require both policy and route permission and freeze their result", async t => {
  const f=await fixture(t);
  f.config.allowUnassignedThreadTitles=true;
  await assert.rejects(identifyProject(titleHeaders(),f.config),{code:"STATE_UNAVAILABLE"});
  const first=await identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true});
  assert.deepEqual(first,{threadId:CHILD,source:"unassigned_title"});
  assert.ok(Object.isFrozen(first));
  f.state["thread-project-assignments"][CHILD]={projectKind:"local",projectId:P2};await f.saveState();
  assert.equal((await identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true})).source,"direct");
  assert.equal(first.source,"unassigned_title");
});
test("ordinary outcomes take precedence over forged title markers",async t => {
  const f=await fixture(t);f.config.allowUnassignedThreadTitles=true;
  assert.equal((await identifyProject(titleHeaders(T1),f.config,{allowUnassignedTitle:true})).projectId,P1);
  delete f.config.projectRoutes[P1];
  await assert.rejects(identifyProject(titleHeaders(T1),f.config,{allowUnassignedTitle:true}),{code:"ROUTE_UNMAPPED"});
  f.state["projectless-thread-ids"].push(CHILD);await f.saveState();
  await assert.rejects(identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true}),{code:"PROJECT_UNRESOLVED"});
});
test("saved threads and outgoing orphan relationships cannot become unattributed titles",async t => {
  const f=await fixture(t);f.config.allowUnassignedThreadTitles=true;
  f.thread(CHILD);
  await assert.rejects(identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true}),{code:"STATE_UNAVAILABLE"});
  const db=new DatabaseSync(f.dbPath);db.exec("DELETE FROM threads");db.close();
  f.edge(CHILD,T1);
  await assert.rejects(identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true}),{code:"STATE_UNAVAILABLE"});
});
test("missing title-only schema leaves ordinary mapped requests unchanged",async t => {
  const f=await fixture(t);f.config.allowUnassignedThreadTitles=true;
  const db=new DatabaseSync(f.dbPath);db.exec("DROP TABLE threads");db.close();
  assert.equal((await identifyProject(titleHeaders(T1),f.config,{allowUnassignedTitle:true})).projectId,P1);
  const start=Date.now();
  await assert.rejects(identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true}),{code:"STATE_UNAVAILABLE"});
  assert.ok(Date.now()-start<1800,"must share one lookup budget");
});
test("title proof recovers from partial state and rereads saved identity between requests",async t => {
  const f=await fixture(t);f.config.allowUnassignedThreadTitles=true;
  await writeFile(f.statePath,"{");
  const pending=identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true});
  await delay(70);await f.saveState();
  assert.equal((await pending).source,"unassigned_title");
  f.thread(CHILD);
  const controller=new AbortController();
  const cancelled=identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true,signal:controller.signal});
  const rejection=assert.rejects(cancelled,{code:"CANCELLED"});
  controller.abort();await rejection;
  f.config.allowUnassignedThreadTitles=false;
  await assert.rejects(identifyProject(titleHeaders(),f.config,{allowUnassignedTitle:true}),{code:"STATE_UNAVAILABLE"});
});

test("unassigned title policy defaults off and accepts only booleans", async (t) => {
  const f = await fixture(t);
  assert.equal((await loadRouterConfig(f.configPath)).allowUnassignedThreadTitles, false);
  for (const mode of [true, false]) {
    f.config.allowUnassignedThreadTitles = mode;
    await f.saveConfig();
    assert.equal((await loadRouterConfig(f.configPath)).allowUnassignedThreadTitles, mode);
  }
  for (const value of [null, "SECRET_SENTINEL", 0, 1, [], {}]) {
    f.config.allowUnassignedThreadTitles = value;
    await f.saveConfig();
    await assert.rejects(loadRouterConfig(f.configPath), e =>
      e.code === "CONFIG_INVALID" && !e.message.includes("SENTINEL"));
  }
});
test("policy readiness preserves prior modes and separates all enabled combinations", async (t) => {
  const f = await fixture(t), fingerprints = new Set();
  for (const observeRequestMetadata of [false, true]) {
    const old = {...f.config, observeRequestMetadata};
    assert.equal(configFingerprint(old), configFingerprint({...old, allowUnassignedThreadTitles:false}));
    for (const allowUnassignedThreadTitles of [false, true])
      fingerprints.add(configFingerprint({...old, allowUnassignedThreadTitles}));
  }
  assert.equal(fingerprints.size, 4);
});

test("metadata observation defaults off and accepts only explicit booleans", async (t) => {
  const f = await fixture(t);
  assert.equal((await loadRouterConfig(f.configPath)).observeRequestMetadata, false);
  for (const mode of [false, true]) {
    f.config.observeRequestMetadata = mode;
    await f.saveConfig();
    assert.equal((await loadRouterConfig(f.configPath)).observeRequestMetadata, mode);
  }
});
for (const value of [null, "SECRET_SENTINEL", 0, 1, [], {}]) {
  test(`rejects nonboolean observation mode ${JSON.stringify(value)}`, async (t) => {
    const f = await fixture(t);
    f.config.observeRequestMetadata = value;
    await f.saveConfig();
    await assert.rejects(loadRouterConfig(f.configPath), (e) =>
      e.code === "CONFIG_INVALID" && !e.message.includes("SENTINEL"));
  });
}
test("readiness distinguishes observation mode while omitted and false match", async (t) => {
  const f = await fixture(t);
  assert.equal(configFingerprint(f.config), configFingerprint({...f.config, observeRequestMetadata: false}));
  assert.notEqual(configFingerprint(f.config), configFingerprint({...f.config, observeRequestMetadata: true}));
  assert.equal(configFingerprint({...f.config, codexHome: "/Users/example/.codex", observeRequestMetadata: false}),
    "e9cc34013d43cefc6db257f4cc9b78301221267c20638afa165e9caa574111fc");
});

test("loads an explicit private HTTPS configuration and defaults the loopback port", async (t) => {
  const f = await fixture(t);
  delete f.config.listenPort;
  await f.saveConfig();
  const config = await loadRouterConfig(f.configPath);
  assert.equal(config.listenPort, 8787);
  assert.equal(config.projectRoutes[P1], "route-a");
});
for (const [field, value] of [
  ["upstreamBaseUrl", "http://example.invalid"],
  ["upstreamBaseUrl", "https://secret@example.invalid"],
  ["listenPort", 0],
  ["schemaVersion", 2],
  ["projectRoutes", { [P1]: "alias\nINJECT" }],
]) {
  test(`rejects unsafe configuration ${field} ${JSON.stringify(value)}`, async (t) => {
    const f = await fixture(t);
    f.config[field] = value;
    await f.saveConfig();
    await assert.rejects(loadRouterConfig(f.configPath), {
      code: "CONFIG_INVALID",
    });
  });
}
test("rejects unknown configuration fields without reflecting secrets", async (t) => {
  const f = await fixture(t);
  f.config.apiKey = "SECRET_SENTINEL";
  await f.saveConfig();
  await assert.rejects(
    loadRouterConfig(f.configPath),
    (e) =>
      e.code === "CONFIG_INVALID" && !e.message.includes("SECRET_SENTINEL"),
  );
});
test("resolves explicit assignments and follows completed-agent ancestry without writing state", async (t) => {
  const f = await fixture(t);
  f.edge(T1, CHILD);
  const before = await f.snapshot();
  assert.deepEqual(await identifyProject(headers(CHILD), f.config), {
    threadId: CHILD,
    ownerThreadId: T1,
    projectId: P1,
    routeAlias: "route-a",
    source: "ancestor",
  });
  assert.equal((await identifyProject(headers(T2), f.config)).projectId, P2);
  assert.deepEqual(await f.snapshot(), before);
});
test("reads new assignments per request and freezes the previous result", async (t) => {
  const f = await fixture(t);
  const first = await identifyProject(headers(), f.config);
  f.state["thread-project-assignments"][T1].projectId = P2;
  await f.saveState();
  const second = await identifyProject(headers(), f.config);
  assert.equal(first.projectId, P1);
  assert.equal(second.projectId, P2);
  assert.ok(Object.isFrozen(first));
});
for (const raw of [
  [],
  ["thread-id", "invalid"],
  [...headers(), "thread-id", T1],
  headers(T1, { thread_id: T2 }),
  ["x-codex-turn-metadata", "{SECRET_SENTINEL"],
]) {
  test(`rejects malformed or conflicting request identifiers ${JSON.stringify(raw).slice(0, 50)}`, async (t) => {
    const f = await fixture(t);
    await assert.rejects(
      identifyProject(raw, f.config),
      (e) =>
        ["IDENTITY_INVALID", "IDENTITY_CONFLICT"].includes(e.code) &&
        !e.message.includes("SECRET_SENTINEL"),
    );
  });
}
test("does not trust a parent hint without a saved relationship", async (t) => {
  const f = await fixture(t);
  await assert.rejects(
    identifyProject(headers(CHILD, { parent_thread_id: T1 }), f.config),
    { code: "STATE_UNAVAILABLE" },
  );
});
test("rejects duplicate top-level metadata identities including escaped key spellings", async (t) => {
  const f = await fixture(t);
  f.edge(T1, CHILD);
  for (const { id, metadata } of duplicateIdentityMetadata)
    await assert.rejects(identifyProject([
      "thread-id", id, "session-id", id, "x-codex-turn-metadata", metadata,
    ], f.config), { code: "IDENTITY_INVALID" });
});
test("ignores nested identity names and identity-looking string contents", async (t) => {
  const f = await fixture(t);
  const metadata = JSON.stringify({
    thread_id: T1,
    extra: { thread_id: T2, session_id: T2 },
    text: '{"thread_id":"' + T2 + '"} [braces] \\',
  });
  assert.equal((await identifyProject([
    "thread-id", T1, "x-codex-turn-metadata", metadata,
  ], f.config)).projectId, P1);
});
test("rejects explicit child assignment conflicting with its ancestor", async (t) => {
  const f = await fixture(t);
  f.edge(T1, CHILD);
  f.state["thread-project-assignments"][CHILD] = {
    projectKind: "local",
    projectId: P2,
  };
  await f.saveState();
  await assert.rejects(identifyProject(headers(CHILD), f.config), {
    code: "IDENTITY_CONFLICT",
  });
});
test("detects ancestry cycles even when a node has an assignment", async (t) => {
  const f = await fixture(t);
  f.edge(T1, CHILD);
  f.edge(CHILD, T1);
  await assert.rejects(identifyProject(headers(CHILD), f.config), {
    code: "IDENTITY_CONFLICT",
  });
});
test("rejects projectless chats and missing aliases without a global fallback", async (t) => {
  const f = await fixture(t);
  f.state["projectless-thread-ids"] = [T1];
  await f.saveState();
  await assert.rejects(identifyProject(headers(), f.config), {
    code: "IDENTITY_CONFLICT",
  });
  delete f.state["thread-project-assignments"][T1];
  await f.saveState();
  await assert.rejects(identifyProject(headers(), f.config), {
    code: "PROJECT_UNRESOLVED",
  });
  delete f.config.projectRoutes[P2];
  await assert.rejects(identifyProject(headers(T2), f.config), {
    code: "ROUTE_UNMAPPED",
  });
});
test("recovers from a partial desktop-state write within the lookup window", async (t) => {
  const f = await fixture(t);
  await writeFile(f.statePath, "{");
  const pending = identifyProject(headers(), f.config);
  await delay(70);
  await f.saveState();
  assert.equal((await pending).projectId, P1);
});
test("missing state and cancelled lookups surface typed errors", async (t) => {
  const f = await fixture(t);
  await unlink(f.statePath);
  await assert.rejects(identifyProject(headers(), f.config), {
    code: "STATE_UNAVAILABLE",
  });
  await assert.rejects(
    identifyProject(headers(), f.config, { signal: AbortSignal.abort() }),
    { code: "CANCELLED" },
  );
});
