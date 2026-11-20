import test from "node:test";
import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { inspectRouterConfiguration } from "../src/config.js";
import { inspectProjectCatalog } from "../src/project-catalog.js";
import { prepareProjectAssignment } from "../src/project-assignments.js";
import { fixture, P1, P2, A1, A2, accountRouting } from "./helpers/fixtures.js";

const P3 = "33333333-3333-4333-8333-333333333333";
const OP = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const NEW_ALIAS = "assignment-aaaaaaaabbbb4ccc8dddeeeeeeeeeeee";
const digest = source => createHash("sha256").update(source).digest("hex");
const change = (accountId, projectId = P1) => ({ projectId, accountId, operationId: OP });
async function setup(t) {
  const f = await fixture(t);
  f.config.schemaVersion = 2;
  f.config.accountRouting = accountRouting();
  f.state["local-projects"][P1].name = "Alpha";
  f.state["local-projects"][P2].name = "Beta";
  await f.saveState();
  const source = async () => {
    await f.saveConfig();
    const bytes = await readFile(f.configPath, "utf8");
    const inspection = await inspectRouterConfiguration(f.configPath);
    return { value: JSON.parse(bytes), config: inspection.config, source: bytes,
      configurationRevision: inspection.configurationRevision,
      catalog: await inspectProjectCatalog(f.dir, inspection.config) };
  };
  return { ...f, source };
}

// A broad configuration reconstruction would lose raw values or optional-property presence.
test("assign switch and inherit preserve exact unrelated data", async t => {
  for (const present of [false, true]) await t.test(`optional property present ${present}`, async t => {
    const f = await setup(t);
    if (present) { f.config.allowUnassignedThreadTitles = false; f.config.observeRequestMetadata = true; }
    f.config.upstreamBaseUrl = "https://GATEWAY.example.invalid:443/api/./v1/";
    f.config.accountRouting.accounts[A1].upstreamBaseUrl = "https://DEFAULT.example.invalid:443/api/./region/v1/";
    const s = await f.source(), before = structuredClone(s.value);
    const assigned = prepareProjectAssignment(s, change(A1));
    assert.equal(assigned.changed, true);
    assert.equal(assigned.operationId, OP);
    assert.equal(assigned.projectId, P1);
    assert.deepEqual(assigned.before, { kind: "override", account: { id: A2, displayName: "Project account" }, routeAlias: "route-a" });
    assert.deepEqual(assigned.after, { kind: "override", account: { id: A1, displayName: "Default account" }, routeAlias: NEW_ALIAS });
    assert.equal(assigned.value.projectRoutes[P1], NEW_ALIAS);
    assert.equal(assigned.value.accountRouting.routeAccounts[NEW_ALIAS], A1);
    assert.deepEqual(assigned.value.projectRoutes[P2], before.projectRoutes[P2]);
    assert.deepEqual(assigned.value.accountRouting.accounts, before.accountRouting.accounts);
    assert.deepEqual(assigned.value.accountRouting.incomingCredential, before.accountRouting.incomingCredential);
    assert.equal(Object.hasOwn(assigned.value, "allowUnassignedThreadTitles"), present);
    const expected = structuredClone(before);
    expected.projectRoutes[P1] = NEW_ALIAS; expected.accountRouting.routeAccounts[NEW_ALIAS] = A1;
    assert.deepEqual(assigned.value, expected);
    assert.equal(assigned.configurationRevision, digest(assigned.source));
    assert.deepEqual(JSON.parse(assigned.source), expected);
    assert.ok(Object.isFrozen(assigned.config.accountRouting.accounts[A1]));
    const removed = prepareProjectAssignment({ ...assigned, catalog: await inspectProjectCatalog(f.dir, assigned.config) }, change(null));
    assert.equal(Object.hasOwn(removed.value.projectRoutes, P1), false);
    assert.deepEqual(removed.value.accountRouting, assigned.value.accountRouting);
    assert.deepEqual(removed.after, { kind: "inherited", account: { id: A1, displayName: "Default account" } });
    assert.deepEqual(s.value, before);
    assert.deepEqual(await readFile(f.configPath, "utf8"), s.source);
  });
});

// Retargeting even an exclusive current binding would break retained runtime snapshots.
test("shared alias never retargets", async t => {
  const f = await setup(t);
  f.config.projectRoutes[P2] = "route-a";
  const s = await f.source(), before = structuredClone(s.value);
  const assigned = prepareProjectAssignment(s, change(A1));
  assert.equal(assigned.value.projectRoutes[P2], "route-a");
  assert.equal(assigned.value.accountRouting.routeAccounts["route-a"], A2);
  assert.equal(assigned.value.projectRoutes[P1], NEW_ALIAS);
  assert.deepEqual(assigned.value.accountRouting.accounts, before.accountRouting.accounts);
  assert.deepEqual(prepareProjectAssignment(s, change(null)).value.accountRouting, before.accountRouting);
});

// Allocating an alias already used by an unresolved mapping would silently repair another project.
test("new alias avoids unresolved labels and own constructor binding", async t => {
  const f = await setup(t);
  f.config.projectRoutes[P2] = NEW_ALIAS;
  let s = await f.source();
  assert.throws(() => prepareProjectAssignment(s, change(A1)), { code: "ACTIVATION_CONFLICT" });
  f.config.projectRoutes[P2] = "route-b";
  f.config.accountRouting.routeAccounts[NEW_ALIAS] = null;
  s = await f.source();
  assert.throws(() => prepareProjectAssignment(s, change(A1)), { code: "ACTIVATION_CONFLICT" });
  delete f.config.accountRouting.routeAccounts[NEW_ALIAS];
  f.config.accountRouting.routeAccounts.constructor = A1;
  s = await f.source();
  const assigned = prepareProjectAssignment(s, change(A1));
  assert.equal(assigned.value.projectRoutes[P1], "constructor");
  assert.equal(Object.hasOwn(assigned.value.accountRouting.routeAccounts, "constructor"), true);
  assert.deepEqual(assigned.value.accountRouting.routeAccounts, s.value.accountRouting.routeAccounts);
});

// Null binding, missing binding, and an explicit override to the default are different saved choices.
test("legacy inheritance and missing target repair remain distinct", async t => {
  const f = await setup(t);
  let s = await f.source();
  const explicit = prepareProjectAssignment(s, change(A1, P2));
  assert.deepEqual(explicit.before, { kind: "legacy_inherited", routeAlias: "route-b", account: { id: A1, displayName: "Default account" } });
  assert.equal(explicit.after.kind, "override");
  assert.equal(explicit.value.accountRouting.routeAccounts["route-b"], null);
  const inherited = prepareProjectAssignment(s, change(null, P2));
  assert.equal(inherited.before.kind, "legacy_inherited");
  assert.equal(inherited.after.kind, "inherited");
  assert.equal(Object.hasOwn(inherited.value.projectRoutes, P2), false);
  delete f.config.accountRouting.routeAccounts["route-b"];
  s = await f.source();
  const repaired = prepareProjectAssignment(s, change(A2, P2));
  assert.deepEqual(repaired.before, { kind: "target_missing", routeAlias: "route-b" });
  assert.equal(repaired.value.projectRoutes[P2], "route-a");
  assert.equal(Object.hasOwn(repaired.value.accountRouting.routeAccounts, "route-b"), false);
});

// Treating an unavailable desktop catalog as an empty catalog could grant writes to stale identities.
test("configured-only row requires a healthy catalog", async t => {
  const f = await setup(t);
  delete f.state["local-projects"][P2];
  await f.saveState();
  const s = await f.source();
  assert.equal(s.catalog.entries.find(e => e.id === P2).routeState, "catalog_missing");
  assert.equal(prepareProjectAssignment(s, change(A2, P2)).value.projectRoutes[P2], "route-a");
  await writeFile(f.statePath, "{");
  const catalog = await inspectProjectCatalog(f.dir, s.config);
  assert.deepEqual(catalog, { state: "unavailable", entries: [] });
  assert.throws(() => prepareProjectAssignment({ ...s, catalog }, change(A2, P2)), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment(s, change(A2, P3)), { code: "ACTIVATION_CONFLICT" });
});

// Case-folded lookups or detached revisions would allow stale or ambiguous assignment edits.
test("catalog identity or revision conflict rejects", async t => {
  const f = await setup(t), id = "abcdefab-abcd-4abc-8abc-abcdefabcdef";
  f.state["local-projects"] = { [id]: { id, name: "Case project" }, [id.toUpperCase()]: { id, name: "Duplicate" } };
  await f.saveState();
  let s = await f.source();
  assert.equal(s.catalog.state, "unavailable");
  assert.throws(() => prepareProjectAssignment(s, change(A1)), { code: "ACTIVATION_CONFLICT" });
  delete f.state["local-projects"][id.toUpperCase()];
  f.config.projectRoutes = { [id.toUpperCase()]: "route-a" };
  await f.saveState(); s = await f.source();
  assert.equal(s.catalog.state, "unavailable");
  assert.throws(() => prepareProjectAssignment(s, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
  f.config.projectRoutes = { [id]: "route-a" };
  s = await f.source();
  assert.throws(() => prepareProjectAssignment(s, change(A1, id.toUpperCase())), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment({ ...s, configurationRevision: "0".repeat(64) }, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment({ ...s, source: s.source + " " }, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment({ ...s, value: { ...s.value, listenPort: 1234 } }, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
});

// Canonicalizing an unchanged mapping would create a spurious save and discard exact source bytes.
test("current alias and inherited no-ops preserve exact source", async t => {
  const f = await setup(t);
  f.config.accountRouting.routeAccounts["a-compatible"] = A2;
  let s = await f.source();
  s.source = " \n" + s.source + "\n\t"; s.configurationRevision = digest(s.source);
  const same = prepareProjectAssignment(s, change(A2));
  assert.equal(same.changed, false);
  assert.equal(same.value.projectRoutes[P1], "route-a");
  assert.equal(same.source, s.source);
  assert.equal(same.configurationRevision, s.configurationRevision);
  const removed = prepareProjectAssignment(s, change(null));
  s = { ...removed, catalog: await inspectProjectCatalog(f.dir, removed.config) };
  const inherited = prepareProjectAssignment(s, change(null));
  assert.equal(inherited.changed, false);
  assert.equal(inherited.source, removed.source);
  assert.deepEqual(inherited.value.accountRouting.routeAccounts, f.config.accountRouting.routeAccounts);
});

// Reusing the first insertion rather than lexical binding would make choices depend on file key order.
test("switch reuses lexicographically first compatible own binding", async t => {
  const f = await setup(t);
  Object.assign(f.config.accountRouting.routeAccounts, { "z-match": A1, "a-match": A1 });
  const s = await f.source(), assigned = prepareProjectAssignment(s, change(A1));
  assert.equal(assigned.value.projectRoutes[P1], "a-match");
  assert.deepEqual(assigned.value.accountRouting.routeAccounts, s.value.accountRouting.routeAccounts);
});

// A missing/null account choice must not be mistaken for an exact existing account ID.
test("assignment choices require exact accounts, UUID operations and ready schema 2", async t => {
  const f = await setup(t), s = await f.source();
  for (const accountId of [undefined, false, "", A1.toUpperCase(), P3])
    assert.throws(() => prepareProjectAssignment(s, change(accountId)), { code: "CONFIG_INVALID" });
  for (const operationId of [null, "invalid"])
    assert.throws(() => prepareProjectAssignment(s, { ...change(A1), operationId }), { code: "CONFIG_INVALID" });
  f.config.accountRouting.defaultAccountId = null;
  let notReady = await f.source();
  assert.throws(() => prepareProjectAssignment(notReady, change(A1)), { code: "CONFIG_INVALID" });
  f.config.schemaVersion = 1; delete f.config.accountRouting;
  notReady = await f.source();
  assert.throws(() => prepareProjectAssignment(notReady, change(null)), { code: "CONFIG_INVALID" });
});

// Object.prototype aliases are unresolved unless the binding is an own property.
test("missing own prototype-named binding can be repaired or inherited safely", async t => {
  const f = await setup(t);
  f.config.projectRoutes[P1] = "constructor";
  let s = await f.source();
  const inherited = prepareProjectAssignment(s, change(null));
  assert.deepEqual(inherited.before, { kind: "target_missing", routeAlias: "constructor" });
  assert.equal(inherited.after.kind, "inherited");
  assert.equal(Object.hasOwn(inherited.value.accountRouting.routeAccounts, "constructor"), false);
  assert.equal(prepareProjectAssignment(s, change(A2)).value.projectRoutes[P1], "route-a");
  f.config.projectRoutes[P1] = "toString";
  s = await f.source();
  assert.deepEqual(prepareProjectAssignment(s, change(null)).before, { kind: "target_missing", routeAlias: "toString" });
});

// These persistence tests fail if a writer trusts a stale UI source, a port's mode,
// or evidence created after replacement as proof of a certain rejection.
const assignments = await import("../src/project-assignments.js");
const fs = await import("node:fs/promises");
const { join } = await import("node:path");
const { default: net } = await import("node:net");
const { once } = await import("node:events");
async function persistenceSetup(t) {
  const f = await setup(t);
  f.dir=await fs.realpath(f.dir);f.configPath=join(f.dir,"router.json");f.config.codexHome=f.dir;
  const reserve = net.createServer(); reserve.listen(0, "127.0.0.1"); await once(reserve, "listening");
  f.config.listenPort = reserve.address().port;
  await new Promise(resolve => reserve.close(resolve));
  await f.source();
  const providerPath = join(f.dir, "config.toml");
  await writeFile(providerPath, `model_provider = "test_gateway"\n[model_providers.test_gateway]\nbase_url = "${f.config.upstreamBaseUrl}"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.test_gateway.auth]\ncommand = "/synthetic/must-never-run"\nargs = ["PRIVATE_AUTH_SENTINEL"]\n`, {mode:0o600});
  const context = {configPath:f.configPath,codexHome:f.dir,providerId:f.config.providerId,listenPort:f.config.listenPort};
  return {...f,providerPath,context, async input(accountId = A1, operationId = OP) {
    const state = await assignments.readProjectAssignmentState({configPath:f.configPath,expectedContext:context,projectId:P1,operationId:null});
    return {configPath:f.configPath,expectedContext:context,expectedSavedRevision:state.savedRevision,
      expectedConfigurationIdentity:state.savedIdentity,expectedCatalogRevision:state.catalogRevision,operationId,projectId:P1,accountId};
  }};
}
function injectedFS(fail, intercept = async () => {}) {
  return {...fs,
    async open(path, ...args) {
      await intercept("open",path);
      if (fail("open",path)) throw Object.assign(new Error("SYNTHETIC_IO_FAILURE"),{code:"EIO"});
      const handle = await fs.open(path,...args);
      return new Proxy(handle,{get(target,key) {
        if (["sync","writeFile","close"].includes(key)) return async (...values) => {
          await intercept(key,path);
          if (fail(key,path)) { if (key === "close") await target.close(); throw Object.assign(new Error("SYNTHETIC_IO_FAILURE"),{code:"EIO"}); }
          return target[key](...values);
        };
        const value = target[key]; return typeof value === "function" ? value.bind(target) : value;
      }});
    },
    async rename(from,to) {
      await intercept("rename",from,to);
      if (fail("rename",from)) throw Object.assign(new Error("SYNTHETIC_IO_FAILURE"),{code:"EIO"});
      return fs.rename(from,to);
    },
    async unlink(path) {
      await intercept("unlink",path);
      if (fail("unlink",path)) throw Object.assign(new Error("SYNTHETIC_IO_FAILURE"),{code:"EIO"});
      return fs.unlink(path);
    }};
}

test("stopped Direct save checkpoints and preserves provider", async t => {
  const f = await persistenceSetup(t), input = await f.input();
  const before = await readFile(f.configPath), providerBefore = await readFile(f.providerPath);
  const result = await assignments.commitProjectAssignment(input);
  const persisted = await readFile(f.configPath);
  assert.equal(result.changed,true);
  assert.deepEqual(await readFile(result.checkpointPath),before);
  assert.deepEqual(await readFile(f.providerPath),providerBefore);
  assert.equal(result.savedRevision,digest(persisted));
  assert.equal(result.intent.candidateRevision,result.savedRevision);
  assert.equal(result.intent.candidateIdentity,result.savedIdentity);
  assert.equal(result.runningRevision,null);
  const state = await assignments.readProjectAssignmentState({configPath:f.configPath,expectedContext:f.context,projectId:P1,operationId:OP});
  assert.equal(state.savedState,"ready");
  assert.equal(state.savedIdentity,result.savedIdentity);
  assert.deepEqual(state.savedAssignment,{kind:"override",account:{id:A1,displayName:"Default account"},routeAlias:NEW_ALIAS});
  assert.deepEqual(state.intent,result.intent);
  assert.equal(state.lastAttempt,null);
  assert.doesNotMatch(JSON.stringify(state),/PRIVATE_AUTH_SENTINEL|keychainPath|upstreamBaseUrl|routeAccounts/);
  await assert.rejects(fs.access(join(f.dir,".activation.lock")),{code:"ENOENT"});
});

test("semantic no-op preserves exact bytes and creates no persistence artifacts", async t => {
  const f = await persistenceSetup(t), input = await f.input(A2), before = await readFile(f.configPath);
  const result = await assignments.commitProjectAssignment(input);
  assert.equal(result.changed,false); assert.equal(result.checkpointPath,null); assert.equal(result.intent,null);
  assert.deepEqual(await readFile(f.configPath),before);
  assert.equal(result.beforeIdentity,result.savedIdentity);
  assert.deepEqual((await fs.readdir(f.dir)).filter(name=>name.startsWith("assignment-")),[]);
});

test("Off or occupied unknown port never authorizes stopped write", async t => {
  for (const provider of ["direct","router"]) await t.test(provider,async t => {
    const f = await persistenceSetup(t), input = await f.input(), before = await readFile(f.configPath);
    if (provider === "router") await writeFile(f.providerPath,(await readFile(f.providerPath,"utf8")).replace(f.config.upstreamBaseUrl,`http://127.0.0.1:${f.config.listenPort}/v1`));
    const server = net.createServer(); t.after(()=>new Promise(resolve=>server.close(resolve)));
    server.listen(f.config.listenPort,"127.0.0.1"); await once(server,"listening");
    await assert.rejects(assignments.commitProjectAssignment(input),{code:"ASSIGNMENT_CONFLICT"});
    assert.deepEqual(await readFile(f.configPath),before);
  });
});

test("stale source catalog replacement or setup lease rejects", async t => {
  for (const kind of ["source","catalog","same_bytes","setup","stale_lock"]) await t.test(kind,async t => {
    const f = await persistenceSetup(t), input = await f.input();
    if (kind === "source") await fs.appendFile(f.configPath,"\n");
    if (kind === "catalog") { f.state["local-projects"][P1].name="Renamed"; await f.saveState(); }
    if (kind === "same_bytes") { const replacement=join(f.dir,"replacement"); await writeFile(replacement,await readFile(f.configPath),{mode:0o600}); await fs.rename(replacement,f.configPath); }
    if (["setup","stale_lock"].includes(kind)) await writeFile(join(f.dir,".activation.lock"),kind === "setup" ? JSON.stringify({pid:process.pid,setupOperationId:OP,configPath:f.configPath}) : JSON.stringify({pid:2147483647}),{mode:0o600});
    const before=await readFile(f.configPath), lease=["setup","stale_lock"].includes(kind) ? await readFile(join(f.dir,".activation.lock")) : null;
    await assert.rejects(assignments.commitProjectAssignment(input),{code:"ASSIGNMENT_CONFLICT"});
    assert.deepEqual(await readFile(f.configPath),before);
    if(lease) assert.deepEqual(await readFile(join(f.dir,".activation.lock")),lease);
  });
});

test("live writer rejects changed static accounts default verifier or optional flags", async t => {
  for (const kind of ["account","default","incoming","flag"]) await t.test(kind,async t => {
    const f=await persistenceSetup(t), original=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
    const running={config:original.config,configurationRevision:original.configurationRevision,configurationIdentity:original.configurationIdentity,mode:"off"};
    if(kind === "account") f.config.accountRouting.accounts[A1].displayName="Changed";
    if(kind === "default") f.config.accountRouting.defaultAccountId=A2;
    if(kind === "incoming") f.config.accountRouting.incomingCredential.service="changed";
    if(kind === "flag") f.config.allowUnassignedThreadTitles=true;
    await f.saveConfig();
    const input={...await f.input(),expectedRunningRevision:running.configurationRevision}, before=await readFile(f.configPath);
    let published=false;
    await assert.rejects(assignments.commitProjectAssignment(input,{running,publish(){published=true;}}),{code:"ASSIGNMENT_CONFLICT"});
    assert.equal(published,false); assert.deepEqual(await readFile(f.configPath),before);
  });
});

test("live save publishes retained immutable snapshot synchronously after durable persistence", async t => {
  const f=await persistenceSetup(t), source=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
  const running={config:source.config,configurationRevision:source.configurationRevision,configurationIdentity:source.configurationIdentity,mode:"on"};
  let published=null;
  const result=await assignments.commitProjectAssignment({...await f.input(),expectedRunningRevision:running.configurationRevision},{running,publish(next){published=next;}});
  assert.equal(published.mode,"on"); assert.equal(published.configurationRevision,result.savedRevision);
  assert.ok(Object.isFrozen(published)); assert.ok(Object.isFrozen(published.config.projectRoutes));
  assert.equal(result.runningIdentity,result.savedIdentity);
  assert.equal(running.config.projectRoutes[P1],"route-a");
});

test("fault phase determines rejection versus uncertainty", async t => {
  for (const phase of ["temp_create","temp_write","temp_sync","checkpoint_create","checkpoint_sync","intent_create","intent_sync","directory_sync_before","rename","directory_sync_after","publish","release"]) await t.test(phase,async t => {
    const f=await persistenceSetup(t), input=await f.input(), before=await readFile(f.configPath);
    let renamed=false;
    const io=injectedFS((method,path)=> {
      const temp=String(path).includes(".assignment-") && String(path).endsWith(".tmp"), checkpoint=String(path).includes("assignment-checkpoint-"), intent=String(path).includes("assignment-intent-");
      return phase === "temp_create" && method === "open" && temp || phase === "temp_write" && method === "writeFile" && temp ||
        phase === "temp_sync" && method === "sync" && temp || phase === "checkpoint_create" && method === "open" && checkpoint ||
        phase === "checkpoint_sync" && method === "sync" && checkpoint || phase === "intent_create" && method === "open" && intent ||
        phase === "intent_sync" && method === "sync" && intent || phase === "directory_sync_before" && method === "sync" && path === f.dir && !renamed ||
        phase === "rename" && method === "rename" || phase === "directory_sync_after" && method === "sync" && path === f.dir && renamed ||
        phase === "release" && method === "unlink" && String(path).endsWith(".activation.lock");
    },async(method)=>{if(method === "rename") renamed=true;});
    let options={fs:io};
    if(phase === "publish") {
      const source=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
      options={...options,running:{config:source.config,configurationRevision:source.configurationRevision,configurationIdentity:source.configurationIdentity,mode:"off"},publish(){throw new Error("SYNTHETIC_PUBLISH_FAILURE");}};
      input.expectedRunningRevision=source.configurationRevision;
    }
    const uncertain=["directory_sync_after","publish","release"].includes(phase);
    await assert.rejects(assignments.commitProjectAssignment(input,options),{code:uncertain ? "ASSIGNMENT_UNCERTAIN" : "ASSIGNMENT_UNAVAILABLE"});
    assert.equal((await readFile(f.configPath)).equals(before),!uncertain);
    if(uncertain) {
      assert.deepEqual(await readFile(join(f.dir,`assignment-checkpoint-${OP}.json`)),before);
      const state=await assignments.readProjectAssignmentState({configPath:f.configPath,expectedContext:f.context,projectId:P1,operationId:OP});
      assert.equal(state.intent.candidateRevision,state.savedRevision);
    }
  });
});

test("unsafe configuration paths never grant assignment authority", async t => {
  for(const kind of ["symlink","hardlink","mode","directory_mode"]) await t.test(kind,async t=>{
    const f=await persistenceSetup(t), input=await f.input();
    if(kind === "symlink") {await fs.rename(f.configPath,join(f.dir,"original")); await fs.symlink(join(f.dir,"original"),f.configPath);}
    if(kind === "hardlink") await fs.link(f.configPath,join(f.dir,"extra-link"));
    if(kind === "mode") await fs.chmod(f.configPath,0o644);
    if(kind === "directory_mode") await fs.chmod(f.dir,0o755);
    const before=await readFile(f.configPath);
    await assert.rejects(assignments.commitProjectAssignment(input),{code:"ASSIGNMENT_CONFLICT"});
    assert.deepEqual(await readFile(f.configPath),before);
  });
});

test("pre-replacement revalidation preserves replaced lock and rejects source directory or provider races",async t=>{
  for(const kind of ["lock","source","catalog","directory","provider"]) await t.test(kind,async t=>{
    const f=await persistenceSetup(t), input=await f.input(); let changed=false;
    const before=await readFile(f.configPath);
    const io=injectedFS(()=>false,async(method,path)=>{
      if(changed || method!=="sync" || !String(path).includes("assignment-intent-")) return;
      changed=true;
      if(kind === "lock") {await fs.rename(join(f.dir,".activation.lock"),join(f.dir,"old-lock"));await writeFile(join(f.dir,".activation.lock"),"replacement",{mode:0o600});}
      if(kind === "source") {await writeFile(join(f.dir,"replacement"),before,{mode:0o600});await fs.rename(join(f.dir,"replacement"),f.configPath);}
      if(kind === "catalog") {f.state["local-projects"][P1].name="Replaced";await f.saveState();}
      if(kind === "directory") {await fs.rename(f.dir,f.dir+"-moved");await fs.mkdir(f.dir,{mode:0o700});t.after(()=>fs.rm(f.dir+"-moved",{recursive:true,force:true}));}
      if(kind === "provider") await fs.appendFile(f.providerPath,"\n");
    });
    await assert.rejects(assignments.commitProjectAssignment(input,{fs:io}),{code:"ASSIGNMENT_CONFLICT"});
    if(kind!=="directory") assert.deepEqual(await readFile(f.configPath),before);
    if(kind === "lock") assert.equal(await readFile(join(f.dir,".activation.lock"),"utf8"),"replacement");
  });
});

test("read reconciliation observes intent without replay and preserves running evidence on unavailable source",async t=>{
  const f=await persistenceSetup(t), source=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
  const running={config:source.config,configurationRevision:source.configurationRevision,configurationIdentity:source.configurationIdentity,mode:"off"};
  await fs.unlink(f.configPath);
  const state=await assignments.readProjectAssignmentState({configPath:f.configPath,expectedContext:f.context,projectId:P1,operationId:OP},running);
  assert.equal(state.savedState,"unavailable"); assert.equal(state.savedRevision,null);
  assert.equal(state.runningRevision,running.configurationRevision); assert.equal(state.mode,"off");
  assert.deepEqual(state.runningAssignment,{kind:"override",account:{id:A2,displayName:"Project account"},routeAlias:"route-a"});
  await assert.rejects(fs.access(f.configPath),{code:"ENOENT"});
});

test("immutable intent and checkpoint replacement before rename rejects without changing source",async t=>{
  for(const kind of ["intent","checkpoint"]) await t.test(kind,async t=>{
    const f=await persistenceSetup(t),input=await f.input(),before=await readFile(f.configPath);let changed=false;
    const io=injectedFS(()=>false,async(method,path)=>{
      if(changed || method!=="sync" || path!==f.dir) return;
      changed=true;
      const artifact=join(f.dir,kind === "intent" ? `assignment-intent-${OP}.json` : `assignment-checkpoint-${OP}.json`);
      await fs.unlink(artifact);await writeFile(artifact,"{}\n",{mode:0o600});
    });
    await assert.rejects(assignments.commitProjectAssignment(input,{fs:io}),{code:"ASSIGNMENT_CONFLICT"});
    assert.deepEqual(await readFile(f.configPath),before);
  });
});

test("late source replacement during candidate verification rejects before rename",async t=>{
  const f=await persistenceSetup(t),input=await f.input(),before=await readFile(f.configPath);let synced=false,replaced=false;
  const io=injectedFS(()=>false,async(method,path)=>{
    if(method==="sync" && path===f.dir) synced=true;
    if(!synced || replaced || method!=="open" || !String(path).endsWith(".tmp")) return;
    replaced=true;await writeFile(join(f.dir,"replacement"),before,{mode:0o600});await fs.rename(join(f.dir,"replacement"),f.configPath);
  });
  await assert.rejects(assignments.commitProjectAssignment(input,{fs:io}),{code:"ASSIGNMENT_CONFLICT"});
  assert.deepEqual(await readFile(f.configPath),before);
});

test("an attempted rename that completes before throwing remains uncertain",async t=>{
  const f=await persistenceSetup(t),input=await f.input(),before=await readFile(f.configPath);
  const io={...fs,async rename(from,to){await fs.rename(from,to);throw Object.assign(new Error("SYNTHETIC_AFTER_RENAME"),{code:"EIO"});}};
  await assert.rejects(assignments.commitProjectAssignment(input,{fs:io}),{code:"ASSIGNMENT_UNCERTAIN"});
  assert.notDeepEqual(await readFile(f.configPath),before);
  const state=await assignments.readProjectAssignmentState({configPath:f.configPath,expectedContext:f.context,projectId:P1,operationId:OP});
  assert.equal(state.savedRevision,state.intent.candidateRevision);
});

test("unsafe owner and immutable intent evidence cannot be used for reconciliation",async t=>{
  const f=await persistenceSetup(t),input=await f.input();
  const io={...fs,async lstat(path){const info=await fs.lstat(path);if(path===f.configPath) info.uid=process.getuid()+1;return info;}};
  await assert.rejects(assignments.commitProjectAssignment(input,{fs:io}),{code:"ASSIGNMENT_CONFLICT"});
  await assignments.commitProjectAssignment(input);
  const intentPath=join(f.dir,`assignment-intent-${OP}.json`),saved=await readFile(f.configPath),intent=JSON.parse(await readFile(intentPath));
  intent.checkpointName="../outside.json";await writeFile(intentPath,JSON.stringify(intent));
  const state=await assignments.readProjectAssignmentState({configPath:f.configPath,expectedContext:f.context,projectId:P1,operationId:OP});
  assert.equal(state.savedState,"conflict");assert.equal(state.intent,null);
  assert.deepEqual(await readFile(f.configPath),saved);
});

test("stopped save rejects unsafe provider or restored recovery evidence",async t=>{
  for(const kind of ["provider_link","provider_symlink","provider_mode","record_link","backup_link"]) await t.test(kind,async t=>{
    const f=await persistenceSetup(t),input=await f.input(),before=await readFile(f.configPath);
    if(kind === "provider_link") await fs.link(f.providerPath,join(f.dir,"extra-provider"));
    if(kind === "provider_symlink") {await fs.rename(f.providerPath,join(f.dir,"provider-original"));await fs.symlink(join(f.dir,"provider-original"),f.providerPath);}
    if(kind === "provider_mode") await fs.chmod(f.providerPath,0o666);
    if(["record_link","backup_link"].includes(kind)) {
      const backupName=`codex-config-${OP}.toml`,backup=join(f.dir,backupName),provider=await readFile(f.providerPath);
      await writeFile(backup,provider,{mode:0o600});
      const recordPath=join(f.dir,"activation.json");
      await writeFile(recordPath,JSON.stringify({schemaVersion:1,routerConfigPath:f.configPath,codexConfigPath:f.providerPath,
        providerId:f.config.providerId,originalBaseUrl:f.config.upstreamBaseUrl,proxyBaseUrl:`http://127.0.0.1:${f.config.listenPort}/v1`,
        backupFile:backupName,backupHash:digest(provider),phase:"restored"}),{mode:0o600});
      await fs.link(kind === "record_link" ? recordPath : backup,join(f.dir,"unsafe-link"));
    }
    await assert.rejects(assignments.commitProjectAssignment(input),{code:"ASSIGNMENT_CONFLICT"});
    assert.deepEqual(await readFile(f.configPath),before);
  });
});

test("a changed source during descriptor read cannot yield editing authority",async t=>{
  const f=await persistenceSetup(t),{readRouterConfigurationSource}=await import("../src/config.js");let changed=false;
  const io={...fs,async open(path,...args){const handle=await fs.open(path,...args);if(path!==f.configPath) return handle;
    return new Proxy(handle,{get(target,key){if(key==="readFile") return async(...values)=>{const bytes=await target.readFile(...values);if(!changed){changed=true;await fs.appendFile(f.configPath,"\n");}return bytes;};const value=target[key];return typeof value==="function" ? value.bind(target) : value;}});}};
  await assert.rejects(readRouterConfigurationSource(f.configPath,{fs:io}),{code:"ACTIVATION_CONFLICT"});
});

test("existing operation evidence is preserved and never reused for another save",async t=>{
  const f=await persistenceSetup(t),input=await f.input();await assignments.commitProjectAssignment(input);
  const intentPath=join(f.dir,`assignment-intent-${OP}.json`),intent=await readFile(intentPath),before=await readFile(f.configPath);
  await assert.rejects(assignments.commitProjectAssignment(await f.input(A2)),{code:"ASSIGNMENT_CONFLICT"});
  assert.deepEqual(await readFile(f.configPath),before);assert.deepEqual(await readFile(intentPath),intent);
});

test("post-rename source replacement before publication reports uncertainty and retains running snapshot",async t=>{
  const f=await persistenceSetup(t),input=await f.input(),source=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
  const running={config:source.config,configurationRevision:source.configurationRevision,configurationIdentity:source.configurationIdentity,mode:"on"};
  let renamed=false,published=false;
  const io=injectedFS(()=>false,async(method,path)=>{
    if(method==="rename") renamed=true;
    if(renamed && method==="sync" && path===f.dir) await fs.appendFile(f.configPath,"\n");
  });
  await assert.rejects(assignments.commitProjectAssignment({...input,expectedRunningRevision:running.configurationRevision},{running,fs:io,publish(){published=true;}}),{code:"ASSIGNMENT_UNCERTAIN"});
  assert.equal(published,false);assert.equal(running.config.projectRoutes[P1],"route-a");
});

test("a rejected asynchronous publication is reported uncertain without an unhandled rejection",async t=>{
  const f=await persistenceSetup(t),input=await f.input(),source=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
  const running={config:source.config,configurationRevision:source.configurationRevision,configurationIdentity:source.configurationIdentity,mode:"off"};
  await assert.rejects(assignments.commitProjectAssignment({...input,expectedRunningRevision:running.configurationRevision},{running,async publish(){throw new Error("SYNTHETIC_ASYNC_PUBLICATION");}}),{code:"ASSIGNMENT_UNCERTAIN"});
  await new Promise(resolve=>setImmediate(resolve));
});

// Evidence checked before preflight can be replaced while that preflight awaits.
// Such replacement must never publish or replace the canonical configuration.
test("late candidate checkpoint or intent replacement during preflight rejects before publication",async t=>{
  for(const kind of ["candidate","checkpoint","intent"]) await t.test(kind,async t=>{
    const f=await persistenceSetup(t),input=await f.input(),source=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
    const running={config:source.config,configurationRevision:source.configurationRevision,configurationIdentity:source.configurationIdentity,mode:"on"};
    const before=await readFile(f.configPath);
    let synced=false,candidateVerified=false,replaced=false,published=false;
    const artifact=join(f.dir,kind === "candidate" ? `.assignment-${OP}.tmp` : `assignment-${kind}-${OP}.json`);
    const io=injectedFS(()=>false,async(method,path)=>{
      if(method==="sync" && path===f.dir) synced=true;
      if(synced && method==="open" && String(path).endsWith(".tmp")) candidateVerified=true;
      if(!candidateVerified || replaced || method!=="open" || path!==f.configPath) return;
      replaced=true;await fs.unlink(artifact);await writeFile(artifact,"{}\n",{mode:0o600});
    });
    await assert.rejects(assignments.commitProjectAssignment({...input,expectedRunningRevision:running.configurationRevision},
      {running,fs:io,publish(){published=true;}}),{code:"ASSIGNMENT_CONFLICT"});
    assert.equal(replaced,true);assert.equal(published,false);
    assert.deepEqual(await readFile(f.configPath),before);
    assert.equal(await readFile(artifact,"utf8"),"{}\n");
    assert.equal(running.config.projectRoutes[P1],"route-a");
  });
});

test("source or catalog changes during second artifact pass reject before replacement",async t=>{
  for(const kind of ["source_bytes","source_identity","catalog_name","catalog_identity","lease"]) await t.test(kind,async t=>{
    const f=await persistenceSetup(t),input=await f.input(),source=await (await import("../src/config.js")).readRouterConfigurationSource(f.configPath);
    const running={config:source.config,configurationRevision:source.configurationRevision,configurationIdentity:source.configurationIdentity,mode:"on"};
    const before=await readFile(f.configPath);let tempChecks=0,changed=false,synced=false,published=false;
    const io=injectedFS(()=>false,async(method,path)=>{
      if(method==="sync" && path===f.dir) synced=true;
      if(!synced || method!=="open" || !String(path).endsWith(".tmp") || ++tempChecks!==2) return;
      changed=true;
      if(kind==="source_bytes") await fs.appendFile(f.configPath,"\n");
      if(kind==="source_identity") {await writeFile(join(f.dir,"replacement"),before,{mode:0o600});await fs.rename(join(f.dir,"replacement"),f.configPath);}
      if(kind==="catalog_name") {f.state["local-projects"][P1].name="Later name";await f.saveState();}
      if(kind==="catalog_identity") {f.state["local-projects"][P1].id=P2;await f.saveState();}
      if(kind==="lease") {await fs.rename(join(f.dir,".activation.lock"),join(f.dir,"prior-lock"));await writeFile(join(f.dir,".activation.lock"),"replacement",{mode:0o600});}
    });
    await assert.rejects(assignments.commitProjectAssignment({...input,expectedRunningRevision:running.configurationRevision},{running,fs:io,publish(){published=true;}}),{code:"ASSIGNMENT_CONFLICT"});
    assert.equal(changed,true);assert.equal(published,false);
    assert.deepEqual(await readFile(f.configPath),kind==="source_bytes" ? Buffer.concat([before,Buffer.from("\n")]) : before);
    if(kind==="lease") assert.equal(await readFile(join(f.dir,".activation.lock"),"utf8"),"replacement");
  });
});

test("stopped provider changes during second artifact pass reject before replacement",async t=>{
  const f=await persistenceSetup(t),input=await f.input(),before=await readFile(f.configPath);let tempChecks=0,synced=false,changed=false;
  const io=injectedFS(()=>false,async(method,path)=>{
    if(method==="sync" && path===f.dir) synced=true;
    if(synced && method==="open" && String(path).endsWith(".tmp") && ++tempChecks===2) {changed=true;await fs.appendFile(f.providerPath,"\n");}
  });
  await assert.rejects(assignments.commitProjectAssignment(input,{fs:io}),{code:"ASSIGNMENT_CONFLICT"});
  assert.equal(changed,true);assert.deepEqual(await readFile(f.configPath),before);
});

test("unrelated desktop metadata during final preflight preserves catalog authority",async t=>{
  const f=await persistenceSetup(t),input=await f.input();let tempChecks=0,synced=false,changed=false;
  const io=injectedFS(()=>false,async(method,path)=>{
    if(method==="sync" && path===f.dir) synced=true;
    if(synced && method==="open" && String(path).endsWith(".tmp") && ++tempChecks===2) {changed=true;f.state["unrelated-desktop-metadata"]={counter:1};await f.saveState();}
  });
  const result=await assignments.commitProjectAssignment(input,{fs:io});
  assert.equal(changed,true);assert.equal(result.changed,true);
});

test("final authority guard dispatches replacement without yielding to queued source edits",async t=>{
  const f=await persistenceSetup(t),input=await f.input(),syncFS=await import("node:fs");
  let scheduled=false,dispatched=false,interleaved=false;
  const synchronous={...syncFS,lstatSync(path,...args){
    const result=syncFS.lstatSync(path,...args);
    if(path===f.dir && !scheduled) {scheduled=true;queueMicrotask(()=>{if(!dispatched){interleaved=true;syncFS.appendFileSync(f.configPath,"\n");}});}
    return result;
  }};
  const io={...fs,rename(from,to){dispatched=true;return fs.rename(from,to);}};
  const result=await assignments.commitProjectAssignment(input,{fs:io,syncFS:synchronous});
  assert.equal(scheduled,true);assert.equal(dispatched,true);assert.equal(interleaved,false);assert.equal(result.changed,true);
});

test("final synchronous source read failure rejects before replacement",async t=>{
  const f=await persistenceSetup(t),input=await f.input(),before=await readFile(f.configPath),syncFS=await import("node:fs");let observed=false;
  const synchronous={...syncFS,openSync(path,...args){if(path===f.configPath){observed=true;throw Object.assign(new Error("SYNTHETIC_FINAL_READ"),{code:"EIO"});}return syncFS.openSync(path,...args);}};
  await assert.rejects(assignments.commitProjectAssignment(input,{syncFS:synchronous}),{code:"ASSIGNMENT_UNAVAILABLE"});
  assert.equal(observed,true);assert.deepEqual(await readFile(f.configPath),before);
});

test("activity failure preserves catalog and editing revision", async t => {
  const {projectActivityFixture,activityRow} = await import("./helpers/project-activity.js");
  const {T1,T2} = await import("./helpers/fixtures.js");
  const {unlink} = await import("node:fs/promises");
  const f = await projectActivityFixture(t);
  f.config.schemaVersion=2;f.config.accountRouting=accountRouting();await f.saveConfig();
  f.replaceThreads([activityRow(T1,{archived:0}),activityRow(T2)]);
  const bytes = await readFile(f.configPath,"utf8"), config=(await inspectRouterConfiguration(f.configPath)).config;
  const before=await inspectProjectCatalog(f.dir,config);
  const enriched=await inspectProjectCatalog(f.dir,config,{includeActivity:true});
  assert.deepEqual(enriched.entries.find(e=>e.id===P1).chatActivity,{state:"unarchived",reason:null});
  await unlink(f.dbPath);
  const failed=await inspectProjectCatalog(f.dir,config,{includeActivity:true});
  assert.equal(failed.revision,before.revision);assert.equal(enriched.revision,before.revision);
  assert.deepEqual(failed.entries.find(e=>e.id===P1).chatActivity,{state:"unknown",reason:"metadata_unavailable"});
  const after=await inspectProjectCatalog(f.dir,config);
  assert.deepEqual(after,before,"authority reads must not depend on activity databases");
  const source={value:JSON.parse(bytes),config,source:bytes,configurationRevision:digest(bytes)};
  assert.deepEqual(prepareProjectAssignment({...source,catalog:before},change(A1)),prepareProjectAssignment({...source,catalog:after},change(A1)));
  assert.equal(await readFile(f.configPath,"utf8"),bytes);
});
