import test from "node:test";
import assert from "node:assert/strict";
import { readFile, writeFile, unlink, mkdir, copyFile, symlink } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { setTimeout as delay } from "node:timers/promises";
import * as configuration from "../src/config.js";
import { loadRouterConfig, configFingerprint } from "../src/config.js";
import { identifyProject } from "../src/identity.js";
import { fixture, headers, titleHeaders, P1, P2, T1, T2, CHILD, duplicateIdentityMetadata, accountRouting, A1, A2 } from "./helpers/fixtures.js";
import { DatabaseSync } from "node:sqlite";

const credentialReference = () => ({
  keychainPath: "/nonexistent/synthetic.keychain-db",
  service: "synthetic-service",
  account: "synthetic-account",
});
const routeTarget = (credential = credentialReference()) => ({
  upstreamBaseUrl: "https://project.example.invalid/region/v1",
  credential,
});
const credentialRouting = () => ({
  globalCredential: credentialReference(),
  routeTargets: { "route-a": routeTarget() },
});

test("relocated runtime preserves private configuration containment", async t => {
  const f = await fixture(t);
  const runtime = join(f.dir, "relocated-runtime");
  await mkdir(join(runtime, "src"), { recursive: true });
  await writeFile(join(runtime, "package.json"), '{"type":"module"}');
  for (const file of ["config.js", "errors.js"])
    await copyFile(new URL("../src/" + file, import.meta.url), join(runtime, "src", file));
  const relocated = await import(pathToFileURL(join(runtime, "src", "config.js")));
  assert.equal((await relocated.loadRouterConfig(f.configPath)).providerId, "test_gateway");
  for (const marker of ["git-directory", "git-file", "Application.app"]) {
    const enclosing = join(f.dir, marker), nested = join(enclosing, "deep", "private");
    await mkdir(nested, { recursive: true });
    if (marker === "git-directory") await mkdir(join(enclosing, ".git"));
    if (marker === "git-file") await writeFile(join(enclosing, ".git"), "gitdir: elsewhere");
    const path = join(nested, "router.json"), link = join(f.dir, marker + "-external.json");
    await writeFile(path, JSON.stringify(f.config), { mode: 0o600 });
    await symlink(path, link);
    for (const load of [loadRouterConfig, relocated.loadRouterConfig])
      for (const candidate of [path, link])
        await assert.rejects(load(candidate), { code: "CONFIG_INVALID" });
  }
});

test("legacy loading omits credential routing and enabled targets are deeply frozen", async (t) => {
  const f = await fixture(t);
  assert.equal(Object.hasOwn(await loadRouterConfig(f.configPath), "credentialRouting"), false);
  f.config.credentialRouting = credentialRouting();
  await f.saveConfig();
  const config = await loadRouterConfig(f.configPath);
  assert.deepEqual(config.credentialRouting, credentialRouting());
  for (const value of [config, config.credentialRouting,
    config.credentialRouting.globalCredential, config.credentialRouting.routeTargets,
    config.credentialRouting.routeTargets["route-a"], config.credentialRouting.routeTargets["route-a"].credential])
    assert.ok(Object.isFrozen(value));
  assert.throws(() => { config.credentialRouting.globalCredential.account = "changed"; }, TypeError);
  assert.throws(() => { config.credentialRouting.routeTargets["route-a"].upstreamBaseUrl = "changed"; }, TypeError);
  assert.throws(() => { config.credentialRouting.routeTargets["route-a"].credential.service = "changed"; }, TypeError);
});

test("credential routing permits empty maps, shared targets, unused aliases and own aliases", async (t) => {
  const f = await fixture(t), shared = routeTarget();
  for (const routeTargets of [{}, {
    "route-a": shared, "route-b": shared,
    unused: routeTarget(), constructor: routeTarget(), toString: routeTarget(), ["a".repeat(64)]: routeTarget(),
  }]) {
    f.config.credentialRouting = { globalCredential: credentialReference(), routeTargets };
    await f.saveConfig();
    const config = await loadRouterConfig(f.configPath);
    assert.deepEqual(config.credentialRouting.routeTargets, routeTargets);
    for (const alias of ["constructor", "toString"]) if (Object.hasOwn(routeTargets, alias)) {
      assert.ok(Object.hasOwn(config.credentialRouting.routeTargets, alias));
      assert.ok(Object.isFrozen(config.credentialRouting.routeTargets[alias]));
      assert.ok(Object.isFrozen(config.credentialRouting.routeTargets[alias].credential));
    }
  }
});

test("credential references accept the 1024-character boundary and preserve literal absolute paths", async (t) => {
  const f = await fixture(t);
  const reference = { keychainPath: "/" + "p".repeat(1023), service: "s".repeat(1024), account: "a".repeat(1024) };
  f.config.credentialRouting = { globalCredential: reference, routeTargets: { "route-a": routeTarget(reference) } };
  await f.saveConfig();
  const config = await loadRouterConfig(f.configPath);
  assert.deepEqual(config.credentialRouting.globalCredential, reference);
  assert.deepEqual(config.credentialRouting.routeTargets["route-a"].credential, reference);
  const literal = "/$HOME/${SYNTHETIC_HOME}/~/synthetic.keychain-db";
  f.config.credentialRouting.globalCredential.keychainPath = literal;
  await f.saveConfig();
  assert.equal((await loadRouterConfig(f.configPath)).credentialRouting.globalCredential.keychainPath, literal);
});

test("explicit target schema rejects obsolete and incomplete routing", async (t) => {
  const f = await fixture(t);
  const invalid = [
    null, true, false, [], "SECRET_SENTINEL", 1, {},
    { globalCredential: credentialReference() },
    { routeTargets: {} },
    { globalCredential: credentialReference(), routeCredentials: {} },
    { ...credentialRouting(), routeCredentials: { "route-a": credentialReference() } },
    { ...credentialRouting(), unexpected: "SECRET_SENTINEL" },
    ...[null, [], true, "SECRET_SENTINEL"].map(globalCredential => ({ ...credentialRouting(), globalCredential })),
    ...[null, [], true, "SECRET_SENTINEL"].map(routeTargets => ({ ...credentialRouting(), routeTargets })),
    ...["", "_route", "route.invalid", "route\nSECRET_SENTINEL", "a".repeat(65)].map(alias => ({
      globalCredential: credentialReference(), routeTargets: { [alias]: routeTarget() },
    })),
    ...[null, [], true, "SECRET_SENTINEL", {}, credentialReference(),
      { credential: credentialReference() }, { upstreamBaseUrl: "https://project.example.invalid/v1" },
      { ...routeTarget(), extra: "SECRET_SENTINEL" },
    ].map(target => ({ ...credentialRouting(), routeTargets: { "route-a": target } })),
  ];
  for (const [index, value] of invalid.entries()) await t.test(`invalid structure ${index}`, async () => {
    f.config.credentialRouting = value;
    await f.saveConfig();
    await assert.rejects(loadRouterConfig(f.configPath), error =>
      error.code === "CONFIG_INVALID" && error.message === "Router configuration is invalid or unsupported.");
  });
  // Global and project destinations must enforce the same URL policy, including unused targets.
  for (const url of ["http://project.example.invalid/v1", "ftp://project.example.invalid/v1",
    "https://user:SECRET_SENTINEL@project.example.invalid/v1", "https://user@project.example.invalid/v1",
    "https://project.example.invalid/v1?SECRET_SENTINEL", "https://project.example.invalid/v1#SECRET_SENTINEL",
    "/region/v1", "//project.example.invalid/v1", "SECRET_SENTINEL", "", null, true, {},
  ]) for (const location of ["global", "target"]) await t.test(`invalid ${location} URL ${JSON.stringify(url)}`, async () => {
    f.config.credentialRouting = credentialRouting();
    f.config.upstreamBaseUrl = location === "global" ? url : "https://global.example.invalid/api/v1";
    f.config.credentialRouting.routeTargets.unused = { ...routeTarget(), upstreamBaseUrl: location === "target" ? url : routeTarget().upstreamBaseUrl };
    await f.saveConfig();
    await assert.rejects(loadRouterConfig(f.configPath), error =>
      error.code === "CONFIG_INVALID" && error.message === "Router configuration is invalid or unsupported.");
  });
});

test("both global and route references require exactly three bounded control-free strings", async (t) => {
  const f = await fixture(t);
  const malformed = [null, true, [], "SECRET_SENTINEL", {}, { ...credentialReference(), extra: "SECRET_SENTINEL" }];
  for (const field of ["keychainPath", "service", "account"]) {
    const missing = credentialReference();
    delete missing[field];
    malformed.push(missing);
    for (const value of [null, true, 1, [], {}, "", "x".repeat(1025), "SECRET_SENTINEL\n", "\u0000", "\u001f", "\u007f", "\u0085", "\u009f"])
      malformed.push({ ...credentialReference(), [field]: field === "keychainPath" && typeof value === "string" && value ? "/" + value : value });
  }
  for (const keychainPath of ["relative.keychain-db", "~/synthetic.keychain-db", "$HOME/synthetic.keychain-db"])
    malformed.push({ ...credentialReference(), keychainPath });
  for (const location of ["global", "route"]) for (const [index, reference] of malformed.entries())
    await t.test(`${location} malformed reference ${index}`, async () => {
      const routing = credentialRouting();
      if (location === "global") routing.globalCredential = reference;
      else routing.routeTargets["route-a"].credential = reference;
      f.config.credentialRouting = routing;
      await f.saveConfig();
      await assert.rejects(loadRouterConfig(f.configPath), error =>
        error.code === "CONFIG_INVALID" && error.message === "Router configuration is invalid or unsupported.");
    });
});

test("target fingerprints preserve legacy compatibility and include normalized destinations", async (t) => {
  const f = await fixture(t);
  assert.equal(configFingerprint({ ...f.config, codexHome: "/Users/example/.codex" }),
    "e9cc34013d43cefc6db257f4cc9b78301221267c20638afa165e9caa574111fc");
  const routing = credentialRouting();
  routing.routeTargets.constructor = routeTarget({ ...credentialReference(), service: "synthetic-other" });
  f.config.credentialRouting = routing;
  await f.saveConfig();
  const config = await loadRouterConfig(f.configPath);
  const reverseReference = reference => ({ account: reference.account, service: reference.service, keychainPath: reference.keychainPath });
  f.config.credentialRouting = {
    routeTargets: Object.fromEntries(Object.entries(routing.routeTargets).reverse().map(([alias, target]) => [alias, {
      credential: reverseReference(target.credential),
      upstreamBaseUrl: "https://PROJECT.example.invalid:443/region/./v1/",
    }])),
    globalCredential: reverseReference(routing.globalCredential),
  };
  f.config.upstreamBaseUrl = "https://GATEWAY.example.invalid:443/api/./v1/";
  await f.saveConfig();
  const reordered = await loadRouterConfig(f.configPath);
  const fingerprint = configFingerprint(config);
  assert.equal(reordered.credentialRouting.routeTargets["route-a"].upstreamBaseUrl, "https://project.example.invalid/region/v1");
  assert.match(fingerprint, /^[a-f0-9]{64}$/);
  assert.equal(fingerprint, configFingerprint(reordered));
  const legacy = { ...config }; delete legacy.credentialRouting;
  assert.notEqual(fingerprint, configFingerprint(legacy));
  for (const location of ["global", "route"]) for (const field of ["keychainPath", "service", "account"]) {
    const changed = structuredClone(config);
    const reference = location === "global" ? changed.credentialRouting.globalCredential : changed.credentialRouting.routeTargets["route-a"].credential;
    reference[field] += "-changed";
    assert.notEqual(fingerprint, configFingerprint(changed), `${location} ${field} must affect readiness`);
  }
  for (const url of ["https://other.example.invalid/region/v1", "https://project.example.invalid/other/v1"]) {
    const changed = structuredClone(config);
    changed.credentialRouting.routeTargets["route-a"].upstreamBaseUrl = url;
    assert.notEqual(fingerprint, configFingerprint(changed), "destination must affect readiness");
  }
  const changed = structuredClone(config);
  changed.credentialRouting.routeTargets["route-b"] = changed.credentialRouting.routeTargets["route-a"];
  assert.notEqual(fingerprint, configFingerprint(changed));
  delete changed.credentialRouting.routeTargets["route-a"];
  assert.notEqual(fingerprint, configFingerprint(changed));
  const empty = { ...legacy, credentialRouting: { globalCredential: credentialReference(), routeTargets: {} } };
  assert.notEqual(configFingerprint(empty), configFingerprint(legacy));
  assert.notEqual(configFingerprint(empty), fingerprint);
});

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
  ["schemaVersion", 3],
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

test("managed membership permits inheritance without weakening catalog proof", async t => {
  const f = await fixture(t);
  delete f.config.projectRoutes[P1];
  const result = await identifyProject(headers(), f.config, {requireRoute: false});
  assert.deepEqual(result, {threadId: T1, ownerThreadId: T1, projectId: P1, source: "direct"});
  assert.ok(Object.isFrozen(result));
  await assert.rejects(identifyProject(headers(), f.config), {code: "ROUTE_UNMAPPED"});
  for (const record of [{}, {id: P2}, {id: "invalid"}]) {
    f.state["local-projects"][P1] = record;
    await f.saveState();
    await assert.rejects(identifyProject(headers(), f.config, {requireRoute: false}), {code: "IDENTITY_CONFLICT"});
  }
});

test("managed identity rejects normalized catalog and mapping ambiguity", async t => {
  const id = "abcdefab-abcd-4abc-8abc-abcdefabcdef";
  for (const problem of ["duplicate catalog", "case mapping", "duplicate mapping same alias", "duplicate mapping other alias"]) {
    const f = await fixture(t);
    f.state["local-projects"] = {[id]: {id: id.toUpperCase()}};
    f.state["thread-project-assignments"][T1].projectId = id;
    f.config.projectRoutes = {[id]: "route-a"};
    if (problem === "duplicate catalog") f.state["local-projects"][id.toUpperCase()] = {id};
    if (problem === "case mapping") delete f.config.projectRoutes[id];
    if (problem !== "duplicate catalog") f.config.projectRoutes[id.toUpperCase()] = problem === "duplicate mapping other alias" ? "route-b" : "route-a";
    await f.saveState();
    await assert.rejects(identifyProject(headers(), f.config, {requireRoute: false}), {code: "IDENTITY_CONFLICT"}, problem);
  }
});

test("managed ancestry and projectless conflicts never become inheritance", async t => {
  const f = await fixture(t);
  f.edge(T1, CHILD);
  f.config.projectRoutes = {};
  f.state["thread-project-assignments"][CHILD] = {projectKind: "local", projectId: P2};
  await f.saveState();
  await assert.rejects(identifyProject(headers(CHILD), f.config, {requireRoute: false}), {code: "IDENTITY_CONFLICT"});
  delete f.state["thread-project-assignments"][CHILD];
  f.state["projectless-thread-ids"].push(CHILD);
  await f.saveState();
  await assert.rejects(identifyProject(headers(CHILD), f.config, {requireRoute: false}), {code: "PROJECT_UNRESOLVED"});
});

test("managed title permission and membership permission remain independent", async t => {
  for (const requireRoute of [true, false]) for (const allowUnassignedTitle of [true, false]) {
    const f = await fixture(t);
    f.config.allowUnassignedThreadTitles = true;
    const options = {requireRoute, allowUnassignedTitle};
    if (allowUnassignedTitle) assert.deepEqual(await identifyProject(titleHeaders(), f.config, options), {threadId: CHILD, source: "unassigned_title"});
    else await assert.rejects(identifyProject(titleHeaders(), f.config, options), {code: "STATE_UNAVAILABLE"});
    delete f.config.projectRoutes[P1];
    if (requireRoute) await assert.rejects(identifyProject(titleHeaders(T1), f.config, options), {code: "ROUTE_UNMAPPED"});
    else assert.equal((await identifyProject(titleHeaders(T1), f.config, options)).projectId, P1);
  }
});

test("managed inheritance uses own mappings and preserves bounded state lookup", async t => {
  const f = await fixture(t);
  f.config.projectRoutes = Object.create({[P1]: "route-a"});
  assert.equal(Object.hasOwn(await identifyProject(headers(), f.config, {requireRoute: false}), "routeAlias"), false);
  await writeFile(f.statePath, "{");
  const recovering = identifyProject(headers(), f.config, {requireRoute: false});
  await delay(70);
  await f.saveState();
  assert.equal((await recovering).projectId, P1);
  await unlink(f.statePath);
  const start = Date.now();
  await assert.rejects(identifyProject(headers(), f.config, {requireRoute: false}), {code: "STATE_UNAVAILABLE"});
  assert.ok(Date.now() - start < 1800);
  await assert.rejects(identifyProject(headers(), f.config, {requireRoute: false, signal: AbortSignal.abort()}), {code: "CANCELLED"});
});

test("managed accounts resolve explicit projectless identity", async t => {
  const f = await fixture(t);
  f.config.schemaVersion = 2;
  f.config.accountRouting = accountRouting();
  delete f.state["thread-project-assignments"][T1];
  f.state["projectless-thread-ids"] = [T1.toUpperCase(), T1];
  f.edge(T1.toUpperCase(), CHILD.toUpperCase());
  await f.saveState();
  const before = await f.snapshot();
  const configBefore = await readFile(f.configPath);
  for (const requireRoute of [true, false]) {
    const options = {allowProjectless: true, requireRoute};
    const direct = await identifyProject(headers(T1), f.config, options);
    assert.deepEqual(direct, {threadId: T1, ownerThreadId: T1, source: "projectless"});
    assert.ok(Object.isFrozen(direct));
    const descendant = await identifyProject(headers(CHILD), f.config, options);
    assert.deepEqual(descendant, {threadId: CHILD, ownerThreadId: T1, source: "projectless"});
    assert.ok(Object.isFrozen(descendant));
  }
  assert.deepEqual(await f.snapshot(), before);
  assert.deepEqual(await readFile(f.configPath), configBefore);
  f.state["projectless-thread-ids"].push(CHILD);
  await f.saveState();
  assert.deepEqual(await identifyProject(headers(CHILD), f.config, {allowProjectless: true}),
    {threadId: CHILD, ownerThreadId: CHILD, source: "projectless"});
  f.state["projectless-thread-ids"].pop();
  await f.saveState();
  assert.deepEqual(await f.snapshot(), before);
  assert.deepEqual(await readFile(f.configPath), configBefore);
});

test("projectless ancestry is checked through conflicting ancestors", async t => {
  for (const scenario of ["own project", "ancestor project", "descendant project"]) await t.test(scenario, async t => {
    const f = await fixture(t);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    if (scenario !== "own project") f.edge(T1, CHILD);
    f.state["projectless-thread-ids"] = [scenario === "descendant project" ? T1 : CHILD];
    if (scenario !== "ancestor project")
      f.state["thread-project-assignments"][CHILD] = {projectKind: "local", projectId: P1};
    if (scenario === "descendant project") delete f.state["thread-project-assignments"][T1];
    await f.saveState();
    await assert.rejects(identifyProject(headers(CHILD), f.config, {allowProjectless: true, requireRoute: false}),
      {code: "IDENTITY_CONFLICT"});
  });
});

test("projectless proof rejects case-shadowed membership and edges", async t => {
  for (const scenario of ["uppercase assignment", "uppercase edge", "duplicate assignment", "duplicate parent"]) await t.test(scenario, async t => {
    const f = await fixture(t);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    f.state["projectless-thread-ids"] = [CHILD.toUpperCase()];
    if (scenario === "uppercase assignment")
      f.state["thread-project-assignments"][CHILD.toUpperCase()] = {projectKind: "local", projectId: P1};
    if (scenario === "uppercase edge") f.edge(T1.toUpperCase(), CHILD.toUpperCase());
    if (scenario === "duplicate assignment") {
      delete f.state["thread-project-assignments"][T1];
      f.state["thread-project-assignments"][CHILD] = {projectKind: "local", projectId: P1};
      f.state["thread-project-assignments"][CHILD.toUpperCase()] = {projectKind: "local", projectId: P1};
      f.state["projectless-thread-ids"] = [];
    }
    if (scenario === "duplicate parent") {
      delete f.state["thread-project-assignments"][T1];
      f.edge(T1, CHILD);
      f.edge(T1.toUpperCase(), CHILD.toUpperCase());
    }
    await f.saveState();
    await assert.rejects(identifyProject(headers(CHILD), f.config, {allowProjectless: true, requireRoute: false}),
      {code: "IDENTITY_CONFLICT"});
  });
});

test("projectless proof preserves session cycle and state guards", async t => {
  for (const [scenario, code] of [
    ["cycle", "IDENTITY_CONFLICT"], ["forged parent", "STATE_UNAVAILABLE"],
    ["incompatible session", "IDENTITY_CONFLICT"], ["malformed marker", "STATE_UNAVAILABLE"],
    ["missing database", "STATE_UNAVAILABLE"], ["locked database", "STATE_UNAVAILABLE"],
    ["malformed parent", "STATE_UNAVAILABLE"], ["saved thread only", "STATE_UNAVAILABLE"],
    ["33 nodes", "IDENTITY_CONFLICT"],
  ]) await t.test(scenario, async t => {
    const f = await fixture(t);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    f.state["projectless-thread-ids"] = [CHILD];
    let raw = headers(CHILD), writer;
    if (scenario === "cycle") {f.edge(T1, CHILD);f.edge(CHILD, T1);delete f.state["thread-project-assignments"][T1];}
    if (scenario === "forged parent") raw = headers(CHILD, {parent_thread_id: T1});
    if (scenario === "incompatible session") raw = ["thread-id", CHILD, "session-id", T1];
    if (scenario === "malformed marker") f.state["projectless-thread-ids"].push(null);
    if (scenario === "missing database") await unlink(f.dbPath);
    if (scenario === "locked database") {writer = new DatabaseSync(f.dbPath);writer.exec("BEGIN EXCLUSIVE");}
    if (scenario === "malformed parent") f.edge("invalid", CHILD);
    if (scenario === "saved thread only") {f.thread(CHILD);f.state["projectless-thread-ids"] = [];}
    if (scenario === "33 nodes") {
      let child = CHILD;
      for (let i = 1; i <= 32; i++) {
        const parent = `${String(i).padStart(8, "0")}-dddd-4ddd-8ddd-dddddddddddd`;
        f.edge(parent, child);
        child = parent;
      }
    }
    await f.saveState();
    const before = await readFile(f.statePath);
    const databaseBefore = scenario === "missing database" ? undefined : await readFile(f.dbPath);
    try {
      await assert.rejects(identifyProject(raw, f.config, {allowProjectless: true}), {code});
    } finally {
      if (writer) {writer.exec("ROLLBACK");writer.close();}
    }
    assert.deepEqual(await readFile(f.statePath), before);
    if (databaseBefore) assert.deepEqual(await readFile(f.dbPath), databaseBefore);
    else await assert.rejects(readFile(f.dbPath), {code: "ENOENT"});
  });
  await t.test("32 nodes and supported session", async t => {
    const f = await fixture(t);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    let child = CHILD;
    for (let i = 1; i <= 31; i++) {
      const parent = `${String(i).padStart(8, "0")}-dddd-4ddd-8ddd-dddddddddddd`;
      f.edge(parent, child);
      child = parent;
    }
    f.state["projectless-thread-ids"] = ["00000031-dddd-4ddd-8ddd-dddddddddddd"];
    await f.saveState();
    assert.deepEqual(await identifyProject(["thread-id", CHILD, "session-id", "00000031-dddd-4ddd-8ddd-dddddddddddd"],
      f.config, {allowProjectless: true}),
    {threadId: CHILD, ownerThreadId: "00000031-dddd-4ddd-8ddd-dddddddddddd", source: "projectless"});
  });
  await t.test("cancelled lookups", async t => {
    const f = await fixture(t);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    await assert.rejects(identifyProject(headers(CHILD), f.config,
      {allowProjectless: true, signal: AbortSignal.abort()}), {code: "CANCELLED"});
    const controller = new AbortController();
    const pending = identifyProject(headers(CHILD), f.config, {allowProjectless: true, signal: controller.signal});
    await delay(70);
    controller.abort();
    await assert.rejects(pending, {code: "CANCELLED"});
  });
});

test("fresh projectless marker may appear within the existing lookup window", async t => {
  const f = await fixture(t);
  f.config.schemaVersion = 2;
  f.config.accountRouting = accountRouting();
  const pending = identifyProject(headers(CHILD), f.config, {allowProjectless: true});
  await delay(70);
  f.state["projectless-thread-ids"] = [CHILD];
  await f.saveState();
  const before = await f.snapshot();
  assert.deepEqual(await pending, {threadId: CHILD, ownerThreadId: CHILD, source: "projectless"});
  assert.deepEqual(await f.snapshot(), before);
});

test("projectless permission leaves legacy and title admission unchanged", async t => {
  for (const [schemaVersion, accounts, permission] of [
    [2, true, undefined], [2, true, false], [2, true, "true"], [1, true, true], [2, false, true],
  ]) await t.test(`legacy ${schemaVersion} ${accounts} ${permission}`, async t => {
    const f = await fixture(t);
    f.config.schemaVersion = schemaVersion;
    if (accounts) f.config.accountRouting = accountRouting();
    f.state["projectless-thread-ids"] = [CHILD];
    await f.saveState();
    await assert.rejects(identifyProject(headers(CHILD), f.config, {allowProjectless: permission}), {code: "PROJECT_UNRESOLVED"});
  });
  await t.test("ordinary identity takes title precedence", async t => {
    const f = await fixture(t);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    f.state["projectless-thread-ids"] = [CHILD];
    await f.saveState();
    for (const optIn of [false, true]) {
      f.config.allowUnassignedThreadTitles = optIn;
      assert.deepEqual(await identifyProject(titleHeaders(CHILD), f.config, {allowProjectless: true, allowUnassignedTitle: true}),
        {threadId: CHILD, ownerThreadId: CHILD, source: "projectless"});
      assert.equal((await identifyProject(titleHeaders(T1), f.config, {allowProjectless: true, allowUnassignedTitle: true})).projectId, P1);
    }
  });
  await t.test("unknown title still requires opt-in and absence proof", async t => {
    const f = await fixture(t);
    f.config.schemaVersion = 2;
    f.config.accountRouting = accountRouting();
    await assert.rejects(identifyProject(titleHeaders(), f.config, {allowProjectless: true, allowUnassignedTitle: true}),
      {code: "STATE_UNAVAILABLE"});
    f.config.allowUnassignedThreadTitles = true;
    assert.deepEqual(await identifyProject(titleHeaders(), f.config, {allowProjectless: true, allowUnassignedTitle: true}),
      {threadId: CHILD, source: "unassigned_title"});
    await assert.rejects(identifyProject(titleHeaders(), f.config, {allowProjectless: true}), {code: "STATE_UNAVAILABLE"});
    f.thread(CHILD);
    await assert.rejects(identifyProject(titleHeaders(), f.config, {allowProjectless: true, allowUnassignedTitle: true}),
      {code: "STATE_UNAVAILABLE"});
  });
});


test("account schema separates incoming default and direct identities", async t => {
  const f = await fixture(t);
  f.config.schemaVersion = 2;
  f.config.accountRouting = accountRouting();
  await f.saveConfig();
  const cfg = await loadRouterConfig(f.configPath);
  assert.equal(cfg.upstreamBaseUrl, "https://gateway.example.invalid/api/v1");
  assert.equal(cfg.accountRouting.accounts[A1].upstreamBaseUrl, "https://default.example.invalid/api/region/v1");
  assert.equal(cfg.accountRouting.accounts[A2].upstreamBaseUrl, "https://project.example.invalid/full/prefix/v1");
  assert.notDeepEqual(cfg.accountRouting.incomingCredential, cfg.accountRouting.accounts[A1].credential);
  assert.equal(Object.hasOwn(cfg, "credentialRouting"), false);
  for (const value of [cfg, cfg.accountRouting, cfg.accountRouting.incomingCredential,
    cfg.accountRouting.accounts, cfg.accountRouting.accounts[A1], cfg.accountRouting.accounts[A1].credential, cfg.accountRouting.routeAccounts])
    assert.ok(Object.isFrozen(value));
  const inspection = await configuration.inspectRouterConfiguration(f.configPath);
  assert.equal(inspection.setupState, "ready");
  assert.match(inspection.configurationRevision, /^[a-f0-9]{64}$/);
  await writeFile(f.configPath, JSON.stringify(f.config, null, 2));
  assert.notEqual((await configuration.inspectRouterConfiguration(f.configPath)).configurationRevision, inspection.configurationRevision);
  f.config.accountRouting.accounts[A1].displayName = "😀".repeat(80);
  await f.saveConfig();
  assert.equal((await loadRouterConfig(f.configPath)).accountRouting.accounts[A1].displayName, "😀".repeat(80));
  const recovery = await configuration.loadRecoveryConfig(f.configPath);
  assert.equal(Object.hasOwn(recovery, "accountRouting"), false);
  assert.equal(Object.hasOwn(recovery, "credentialRouting"), false);
  assert.equal(recovery.upstreamBaseUrl, cfg.upstreamBaseUrl);
});

test("legacy inheritance differs from missing override", async t => {
  const f = await fixture(t);
  assert.equal((await configuration.inspectRouterConfiguration(f.configPath)).setupState, "migration_required");
  f.config.schemaVersion = 2;
  f.config.accountRouting = accountRouting();
  f.config.accountRouting.routeAccounts = { "route-a": null, constructor: A1, toString: A2 };
  await f.saveConfig();
  const cfg = await loadRouterConfig(f.configPath);
  assert.equal(cfg.accountRouting.routeAccounts["route-a"], null);
  assert.equal(Object.hasOwn(cfg.accountRouting.routeAccounts, "route-b"), false);
  assert.equal(Object.hasOwn(cfg.accountRouting.routeAccounts, "constructor"), true);
  assert.equal(cfg.accountRouting.routeAccounts.constructor, A1);
  for (const patch of [{ incomingCredential: null }, { defaultAccountId: null }, { accounts: {}, defaultAccountId: null, routeAccounts: {} }]) {
    f.config.accountRouting = { ...accountRouting(), ...patch };
    await f.saveConfig();
    assert.equal((await configuration.inspectRouterConfiguration(f.configPath)).setupState, "required");
    await assert.rejects(loadRouterConfig(f.configPath), { code: "ACCOUNT_SETUP_REQUIRED" });
  }
});

test("account validation rejects malformed metadata without leaking values", async t => {
  const f = await fixture(t);
  f.config.schemaVersion = 2;
  const mutations = [
    () => null, () => ({}),
    r => { delete r.incomingCredential; return r; },
    r => { delete r.defaultAccountId; return r; },
    r => ({ ...r, credentialRouting: {} }),
    r => ({ ...r, incomingCredential: { ...r.incomingCredential, extra: "SECRET_SENTINEL" } }),
    r => ({ ...r, incomingCredential: { ...r.incomingCredential, keychainPath: "relative" } }),
    r => ({ ...r, incomingCredential: { ...r.incomingCredential, service: "SECRET_SENTINEL\n" } }),
    r => ({ ...r, defaultAccountId: A1.toUpperCase() }),
    r => ({ ...r, defaultAccountId: "ffffffff-ffff-4fff-8fff-ffffffffffff" }),
    r => ({ ...r, accounts: { ...r.accounts, [A1.toUpperCase()]: r.accounts[A1] } }),
    r => ({ ...r, accounts: { ...r.accounts, invalid: r.accounts[A1] } }),
    r => ({ ...r, routeAccounts: { "route-a": "ffffffff-ffff-4fff-8fff-ffffffffffff" } }),
    r => ({ ...r, routeAccounts: { "route-a": false } }),
    r => ({ ...r, routeAccounts: { "invalid.alias": null } }),
    ...["", "  ", " untrimmed", "untrimmed ", "a".repeat(81), "SECRET_SENTINEL\n", "\u0085"].map(displayName => r => {
      r.accounts[A1].displayName = displayName; return r;
    }),
    r => { r.accounts[A2].displayName = "DEFAULT ACCOUNT"; return r; },
    r => { r.accounts[A1].extra = "SECRET_SENTINEL"; return r; },
    r => { r.accounts[A1].credential = null; return r; },
    r => { r.accounts[A1].upstreamBaseUrl = "https://user:SECRET_SENTINEL@invalid.example/v1"; return r; },
    r => { r.accounts[A1].upstreamBaseUrl = "https://invalid.example/v1?SECRET_SENTINEL"; return r; },
  ];
  for (const [index, mutate] of mutations.entries()) await t.test(`invalid account metadata ${index}`, async () => {
    f.config.accountRouting = mutate(accountRouting());
    await f.saveConfig();
    const inspection = await configuration.inspectRouterConfiguration(f.configPath);
    assert.equal(inspection.setupState, "invalid");
    assert.equal(inspection.configurationRevision, null);
    assert.equal(Object.hasOwn(inspection.config, "accountRouting"), false);
    await assert.rejects(loadRouterConfig(f.configPath), e => e.code === "ACCOUNT_SETUP_INVALID" && !e.message.includes("SENTINEL"));
    assert.equal((await configuration.loadRecoveryConfig(f.configPath)).providerId, "test_gateway");
  });
  f.config.accountRouting = accountRouting();
  for (const invalid of [{ ...f.config, schemaVersion: 99 }, { ...f.config, extra: "SECRET_SENTINEL" }, { ...f.config, credentialRouting: credentialRouting() }]) {
    await writeFile(f.configPath, JSON.stringify(invalid));
    await assert.rejects(configuration.loadRecoveryConfig(f.configPath), { code: "CONFIG_INVALID" });
  }
  await writeFile(f.configPath, "{SECRET_SENTINEL");
  await assert.rejects(configuration.loadRecoveryConfig(f.configPath), { code: "CONFIG_UNAVAILABLE" });
});

test("account fingerprints preserve historical compatibility", async t => {
  const f = await fixture(t);
  assert.equal(configFingerprint({ ...f.config, codexHome: "/Users/example/.codex" }), "e9cc34013d43cefc6db257f4cc9b78301221267c20638afa165e9caa574111fc");
  f.config.schemaVersion = 2;
  f.config.accountRouting = accountRouting();
  await f.saveConfig();
  const cfg = await loadRouterConfig(f.configPath), fingerprint = configFingerprint(cfg);
  const reordered = structuredClone(f.config);
  reordered.accountRouting.accounts = Object.fromEntries(Object.entries(reordered.accountRouting.accounts).reverse());
  reordered.accountRouting.routeAccounts = Object.fromEntries(Object.entries(reordered.accountRouting.routeAccounts).reverse());
  reordered.accountRouting.accounts[A1].upstreamBaseUrl = "https://DEFAULT.example.invalid:443/api/./region/v1/";
  await writeFile(f.configPath, JSON.stringify(reordered));
  assert.equal(configFingerprint(await loadRouterConfig(f.configPath)), fingerprint);
  for (const change of [
    r => { r.defaultAccountId = A2; },
    r => { r.incomingCredential.service += "changed"; },
    r => { r.accounts[A1].displayName += " changed"; },
    r => { r.accounts[A1].credential.account += "changed"; },
    r => { r.accounts[A1].upstreamBaseUrl += "/changed"; },
    r => { r.routeAccounts["route-a"] = A1; },
    r => { delete r.routeAccounts["route-b"]; },
  ]) {
    const changed = structuredClone(cfg); change(changed.accountRouting);
    assert.notEqual(configFingerprint(changed), fingerprint);
  }
  assert.notEqual(configuration.operationalFingerprint(await configuration.loadRecoveryConfig(f.configPath)), fingerprint);
});


test("pure configuration validation matches file validation without accepting source text", async t => {
  const f = await fixture(t);
  for (const accountMode of [false, true]) {
    if (accountMode) { f.config.schemaVersion = 2; f.config.accountRouting = accountRouting(); }
    await f.saveConfig();
    const fromFile = await configuration.inspectRouterConfiguration(f.configPath);
    const pure = configuration.inspectRouterConfigurationValue(f.config);
    assert.deepEqual(pure, { config: fromFile.config, setupState: fromFile.setupState });
    assert.equal(Object.hasOwn(pure, "configurationRevision"), false);
    assert.ok(Object.isFrozen(pure.config));
  }
  f.config.accountRouting.accounts[A1].displayName = "";
  const invalid = configuration.inspectRouterConfigurationValue(f.config);
  assert.equal(invalid.setupState, "invalid");
  assert.equal(Object.hasOwn(invalid.config, "accountRouting"), false);
  assert.equal(Object.hasOwn(invalid, "configurationRevision"), false);
  assert.throws(() => configuration.inspectRouterConfigurationValue("{untrusted source}"), { code: "CONFIG_INVALID" });
});
