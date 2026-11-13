import test from "node:test";
import assert from "node:assert/strict";
import fs, { writeFile, readFile, realpath, unlink, chmod, stat, readdir, symlink } from "node:fs/promises";
import net from "node:net";
import { once } from "node:events";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { syncBuiltinESMExports } from "node:module";
import * as setup from "../src/account-setup.js";
import { activate, status } from "../src/activation.js";
import { fixture, P1, P2, A1, accountRouting } from "./helpers/fixtures.js";
const ref = { keychainPath: "/synthetic.keychain-db", service: "service", account: "account" };
async function fixtureSetup(t, mode = "enabled") {
  const f = await fixture(t);
  f.dir = await realpath(f.dir); f.configPath = await realpath(f.configPath); f.config.codexHome = f.dir;
  const port = net.createServer(); port.listen(0, "127.0.0.1"); await once(port, "listening");
  f.config.listenPort = port.address().port; await new Promise(resolve => port.close(resolve));
  if (mode === "enabled") f.config.credentialRouting = { globalCredential: ref, routeTargets: {
    "route-a": { upstreamBaseUrl: f.config.upstreamBaseUrl, credential: ref },
    unused: { upstreamBaseUrl: "https://unused.invalid/prefix/v1", credential: ref },
    constructor: { upstreamBaseUrl: "https://constructor.invalid/v1", credential: ref },
  } };
  if (mode === "accounts") { f.config.schemaVersion = 2; f.config.accountRouting = accountRouting(); }
  await f.saveConfig();
  f.providerPath = join(f.dir, "config.toml");
  f.original = `model_provider = "test_gateway"\n[model_providers.test_gateway]\nbase_url = "${f.config.upstreamBaseUrl}"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.test_gateway.auth]\ncommand = "/usr/bin/security"\nargs = ["find-generic-password", "-s", "service", "-a", "account", "-w", "/synthetic.keychain-db"]\n`;
  await writeFile(f.providerPath, f.original, { mode: 0o600 });
  f.lease = async operationId => writeFile(join(f.dir, ".activation.lock"), JSON.stringify({ pid: process.pid, setupOperationId: operationId, configPath: f.configPath }), { mode: 0o600 });
  f.preview = () => setup.previewAccountSetup({ configPath: f.configPath, browseHome: f.dir });
  f.commit = async (preview, change, operationId = randomUUID()) => {
    await f.lease(operationId);
    return setup.commitAccountSetup({ configPath: f.configPath, expectedContext: preview.context, expectedRevision: preview.configurationRevision, operationId, change });
  };
  return f;
}
function migration(preview) { return { kind: "migrate", accounts: preview.accounts.map(account => ({ id: account.id, displayName: account.displayName, upstreamBaseUrl: account.upstreamBaseUrl, credential: account.credential ?? ref })), incomingCredential: ref, defaultAccountId: null }; }
function newAccount(id = randomUUID()) { return { id, displayName: "Added", upstreamBaseUrl: "https://new.invalid/full/v1", credential: ref }; }

test("enabled migration preserves explicit old-global and unused pairs", async t => {
  const f = await fixtureSetup(t), source = await readFile(f.configPath), before = await readFile(f.providerPath);
  const preview = await f.preview(), again = await f.preview();
  assert.deepEqual(preview, again);
  assert.equal(preview.accounts.length, 4);
  assert.equal(preview.sourceKind, "enabled");
  assert.deepEqual(preview.incomingHint, ref);
  assert.equal(Object.hasOwn(preview.routeAccounts, "constructor"), true);
  assert.equal(Object.hasOwn(preview.routeAccounts, "route-b"), false);
  const change = migration(preview); change.defaultAccountId = preview.originalDirect.id;
  const result = await f.commit(preview, change), saved = JSON.parse(await readFile(f.configPath));
  assert.equal(result.setupState, "ready"); assert.match(result.configurationRevision, /^[a-f0-9]{64}$/);
  assert.equal(saved.schemaVersion, 2); assert.equal(saved.credentialRouting, undefined);
  assert.deepEqual(saved.projectRoutes, f.config.projectRoutes);
  assert.equal(saved.upstreamBaseUrl, f.config.upstreamBaseUrl);
  assert.equal(Object.hasOwn(saved, "observeRequestMetadata"), false);
  assert.equal(Object.hasOwn(saved, "allowUnassignedThreadTitles"), false);
  assert.notEqual(saved.accountRouting.routeAccounts["route-a"], saved.accountRouting.defaultAccountId);
  assert.equal(Object.hasOwn(saved.accountRouting.routeAccounts, "route-b"), false);
  assert.equal(Object.keys(saved.accountRouting.accounts).length, 4);
  assert.deepEqual(await readFile(result.checkpointPath), source);
  assert.equal((await stat(result.checkpointPath)).mode & 0o777, 0o600);
  assert.deepEqual(await readFile(f.providerPath), before);
  assert.equal(await readFile(join(f.dir, ".activation.lock"), "utf8") !== "", true);
});

test("legacy migration preserves labels as inheritance and exact case-sensitive mapping keys", async t => {
  const f = await fixtureSetup(t, "legacy");
  f.config.projectRoutes = { [P1.toUpperCase()]: "constructor", [P2]: "Route-A" }; await f.saveConfig();
  const p = await f.preview(); assert.deepEqual(p.routeAccounts, { constructor: null, "Route-A": null });
  const c = migration(p); c.accounts[0].displayName = "Desktop";
  await f.commit(p, c);
  const saved = JSON.parse(await readFile(f.configPath));
  assert.deepEqual(saved.projectRoutes, f.config.projectRoutes); assert.deepEqual(saved.accountRouting.routeAccounts, p.routeAccounts);
  assert.equal(saved.accountRouting.defaultAccountId, null);
});

test("default requires explicit confirmation and adding never changes the default", async t => {
  const f = await fixtureSetup(t, "accounts"), p = await f.preview(), account = newAccount();
  const result = await f.commit(p, { kind: "add_account", account });
  assert.equal(result.setupState, "ready"); assert.equal(JSON.parse(await readFile(f.configPath)).accountRouting.defaultAccountId, A1);
  await unlink(join(f.dir, ".activation.lock"));
  const p2 = await f.preview();
  await f.commit(p2, { kind: "set_default", defaultAccountId: account.id });
  assert.equal(JSON.parse(await readFile(f.configPath)).accountRouting.defaultAccountId, account.id);
  const legacy = await fixtureSetup(t, "legacy"), lp = await legacy.preview(), change = migration(lp); delete change.defaultAccountId;
  await assert.rejects(legacy.commit(lp, change), { code: "ACCOUNT_SETUP_INVALID" });
});

test("first setup preserves compatible desktop configuration and empty assignments", async t => {
  const f = await fixtureSetup(t, "legacy"); await unlink(f.configPath);
  const p = await f.preview(); assert.equal(p.sourceKind, "missing"); assert.equal(p.setupState, "required");
  assert.equal(p.context.configPath, f.configPath); assert.equal(p.context.listenPort, 8787);
  const account = newAccount();
  const result = await f.commit(p, { kind: "create_configuration", account, incomingCredential: ref, defaultAccountId: null });
  const saved = JSON.parse(await readFile(f.configPath));
  assert.equal(result.setupState, "required"); assert.equal(result.checkpointPath, null);
  assert.deepEqual(saved.projectRoutes, {}); assert.equal(saved.upstreamBaseUrl, f.config.upstreamBaseUrl);
  assert.equal(await readFile(f.providerPath, "utf8"), f.original);
});

test("unknown recovery evidence and unsafe missing destinations block creation", async t => {
  for (const name of ["activation.json", "codex-config-11111111-1111-4111-8111-111111111111.toml", "account-setup.json"]) {
    const f = await fixtureSetup(t, "legacy"); await unlink(f.configPath); await writeFile(join(f.dir, name), "unknown", {mode: 0o600});
    await assert.rejects(f.preview(), { code: "ACCOUNT_SETUP_CONFLICT" });
  }
  const f = await fixtureSetup(t, "legacy"); await unlink(f.configPath); await chmod(f.dir, 0o755);
  await assert.rejects(f.preview(), { code: "ACCOUNT_SETUP_CONFLICT" });
  await chmod(f.dir, 0o700);
});

test("opaque and transforming helpers receive no inferred reference", async t => {
  const f = await fixtureSetup(t, "legacy");
  for (const auth of ['command = "/opaque-helper"\nargs = ["SECRET_SENTINEL"]', 'command = "/usr/bin/security"\nargs = ["find-generic-password", "-s", "s", "-s", "other", "-a", "a", "-w"]', 'command = "/usr/bin/security"\nargs = ["find-generic-password", "-s", "s", "-a", "a", "-w", "-g"]']) {
    await writeFile(f.providerPath, f.original.slice(0, f.original.indexOf('command =')) + auth + "\n");
    const p = await f.preview(); assert.equal(p.incomingHint, null); assert.doesNotMatch(JSON.stringify(p), /SECRET_SENTINEL|opaque-helper|find-generic-password/);
  }
});

test("migration resolves duplicate names in preview while preserving separate pairs", async t => {
  const f = await fixtureSetup(t);
  f.config.credentialRouting.routeTargets = { "Default": { upstreamBaseUrl: f.config.upstreamBaseUrl, credential: ref }, "default": { upstreamBaseUrl: f.config.upstreamBaseUrl, credential: ref } }; await f.saveConfig();
  const p = await f.preview(); assert.equal(new Set(p.accounts.map(a => a.displayName.toLowerCase())).size, 3);
  await f.commit(p, migration(p)); assert.equal(Object.keys(JSON.parse(await readFile(f.configPath)).accountRouting.accounts).length, 3);
});

test("commit rejects changed context revision lock or listener", async t => {
  for (const condition of ["context", "revision", "missing_lock", "wrong_operation", "dead_owner", "unsafe_lock", "listener", "provider", "symlink"]) {
    const f = await fixtureSetup(t), p = await f.preview(), before = await readFile(f.configPath), operationId = randomUUID(); await f.lease(operationId);
    let expectedContext = p.context, expectedRevision = p.configurationRevision;
    if (condition === "context") expectedContext = { ...p.context, providerId: "other" };
    if (condition === "revision") expectedRevision = "0".repeat(64);
    if (condition === "missing_lock") await unlink(join(f.dir, ".activation.lock"));
    if (condition === "wrong_operation") await f.lease(randomUUID());
    if (condition === "dead_owner") await writeFile(join(f.dir, ".activation.lock"), JSON.stringify({pid:2147483647,setupOperationId:operationId,configPath:f.configPath}));
    if (condition === "unsafe_lock") await chmod(join(f.dir, ".activation.lock"), 0o644);
    if (condition === "provider") await writeFile(f.providerPath, f.original.replace(f.config.upstreamBaseUrl, "http://127.0.0.1:8787/v1"));
    if (condition === "symlink") { await unlink(f.configPath); await writeFile(f.configPath + ".other", before, {mode:0o600}); await symlink(f.configPath + ".other", f.configPath); }
    if (condition === "listener") { const s = net.createServer(); s.listen(f.config.listenPort, "127.0.0.1"); await once(s,"listening"); t.after(() => new Promise(resolve => s.close(resolve))); }
    await assert.rejects(setup.commitAccountSetup({configPath:f.configPath,expectedContext,expectedRevision,operationId,change:migration(p)}), {code:"ACCOUNT_SETUP_CONFLICT"}, condition);
    assert.deepEqual(await readFile(f.configPath), before);
  }
});

test("failed commit preserves original and private checkpoint after lock replacement", async t => {
  const f = await fixtureSetup(t), p = await f.preview(), before = await readFile(f.configPath), originalOpen = fs.open;
  let replaced = false;
  t.mock.method(fs,"open",async (path,...args) => {
    const handle = await originalOpen(path,...args);
    if (String(path).includes("account-setup-checkpoint-") && !replaced) {
      replaced = true; await unlink(join(f.dir,".activation.lock")); await writeFile(join(f.dir,".activation.lock"),"replacement",{mode:0o600});
    }
    return handle;
  }); syncBuiltinESMExports();
  try { await assert.rejects(f.commit(p,migration(p)),{code:"ACCOUNT_SETUP_CONFLICT"}); }
  finally { t.mock.restoreAll(); syncBuiltinESMExports(); }
  assert.equal(replaced,true); assert.deepEqual(await readFile(f.configPath),before);
  const checkpoint=(await readdir(f.dir)).find(n=>n.startsWith("account-setup-checkpoint-"));
  assert.deepEqual(await readFile(join(f.dir,checkpoint)),before); assert.equal(await readFile(join(f.dir,".activation.lock"),"utf8"),"replacement");
});

test("setup-held activation lock excludes activation while status remains read-only", async t => {
  const f = await fixtureSetup(t), operationId = randomUUID(); await f.lease(operationId);
  await assert.rejects(activate(f.configPath),{code:"ACTIVATION_CONFLICT"});
  assert.equal((await status(f.configPath)).state,"direct");
  assert.equal(JSON.parse(await readFile(join(f.dir,".activation.lock"))).setupOperationId,operationId);
});

test("first setup accepts only the same-operation durable native receipt", async t => {
  const f=await fixtureSetup(t,"legacy"); await unlink(f.configPath);
  const p=await f.preview(), account=newAccount(), operationId=randomUUID();
  const receipt={schemaVersion:1,operationId,accountId:account.id,reference:ref,account,context:p.context,phase:"committing"};
  await writeFile(join(f.dir,"account-setup.json"),JSON.stringify(receipt),{mode:0o600});
  await f.lease(operationId);
  const result=await setup.commitAccountSetup({configPath:f.configPath,expectedContext:p.context,expectedRevision:p.configurationRevision,operationId,change:{kind:"create_configuration",account,incomingCredential:ref,defaultAccountId:account.id}});
  assert.equal(result.setupState,"ready"); assert.deepEqual(JSON.parse(await readFile(join(f.dir,"account-setup.json"))),receipt);
});

test("missing-source revisions exclude all provider authentication bytes", async t => {
  const f=await fixtureSetup(t,"legacy"); await unlink(f.configPath);
  const p=await f.preview();
  await writeFile(f.providerPath,f.original.replace('command = "/usr/bin/security"','command = "/different-opaque-helper"').replace('"service"','"SECRET_SENTINEL"'));
  assert.equal((await f.preview()).configurationRevision,p.configurationRevision);
});

test("incomplete account setup permits explicit verifier completion without rotation", async t => {
  const f=await fixtureSetup(t,"accounts"); f.config.accountRouting.incomingCredential=null; await f.saveConfig();
  const p=await f.preview();
  await f.commit(p,{kind:"set_default",defaultAccountId:A1,incomingCredential:ref});
  const saved=JSON.parse(await readFile(f.configPath)); assert.deepEqual(saved.accountRouting.incomingCredential,ref);
  await unlink(join(f.dir,".activation.lock"));
  const p2=await f.preview();
  await assert.rejects(f.commit(p2,{kind:"add_account",account:newAccount(),incomingCredential:{...ref,account:"replacement"}}),{code:"ACCOUNT_SETUP_INVALID"});
  await unlink(join(f.dir,".activation.lock"));
  await assert.rejects(f.commit(p2,{kind:"set_default",defaultAccountId:A1,incomingCredential:null}),{code:"ACCOUNT_SETUP_INVALID"});
});

test("stale source preview and unsafe configuration cannot be overwritten", async t => {
  for (const condition of ["changed","unsafe","empty-targets"]) {
    const f=await fixtureSetup(t), p=await f.preview();
    if(condition==="changed") { f.config.projectRoutes[P1]="later"; await f.saveConfig(); }
    if(condition==="unsafe") await chmod(f.configPath,0o644);
    if(condition==="empty-targets") { f.config.credentialRouting.routeTargets={}; await f.saveConfig(); }
    const before=await readFile(f.configPath);
    await assert.rejects(f.commit(p,migration(p)),{code:"ACCOUNT_SETUP_CONFLICT"});
    assert.deepEqual(await readFile(f.configPath),before);
  }
});

test("migration retains read-only source permission bits in checkpoint and replacement", async t => {
  const f=await fixtureSetup(t), original=await readFile(f.configPath); await chmod(f.configPath,0o400);
  const p=await f.preview(), result=await f.commit(p,migration(p));
  assert.equal((await stat(result.checkpointPath)).mode&0o777,0o400);
  assert.equal((await stat(f.configPath)).mode&0o777,0o400);
  assert.deepEqual(await readFile(result.checkpointPath),original);
});

test("setup commit performs no helper credential or HTTP preflight operation", async t => {
  const f=await fixtureSetup(t), p=await f.preview();
  const http=(await import("node:http")).default, https=(await import("node:https")).default, cp=(await import("node:child_process")).default;
  let calls=0;
  for(const target of [http,https]) for(const method of ["get","request"]) t.mock.method(target,method,()=>{calls++; throw new Error("FORBIDDEN_PREFLIGHT");});
  for(const method of ["spawn","spawnSync","exec","execSync","execFile","execFileSync","fork"]) t.mock.method(cp,method,()=>{calls++;throw new Error("FORBIDDEN_SECRET_HELPER");});
  syncBuiltinESMExports();
  try { await f.commit(p,migration(p)); assert.equal(calls,0); }
  finally { t.mock.restoreAll();syncBuiltinESMExports(); }
});

test("empty enabled targets preserve missing bindings and reject unknown edits", async t => {
  const f=await fixtureSetup(t);f.config.credentialRouting.routeTargets={};await f.saveConfig();
  const p=await f.preview();assert.equal(p.accounts.length,1);assert.deepEqual(p.routeAccounts,{});
  const change=migration(p); change.projectRoutes={};
  await assert.rejects(f.commit(p,change),{code:"ACCOUNT_SETUP_INVALID"});
  assert.deepEqual(JSON.parse(await readFile(f.configPath)).projectRoutes,f.config.projectRoutes);
});

test("rename failure leaves exact checkpoint and provider untouched", async t => {
  const f=await fixtureSetup(t),p=await f.preview(),original=await readFile(f.configPath);
  let attempts=0;
  t.mock.method(fs,"rename",async (...args)=>{attempts++;throw Object.assign(new Error("DISK_FAILURE_SENTINEL"),{code:"EIO"});});syncBuiltinESMExports();
  try {await assert.rejects(f.commit(p,migration(p)),{code:"ACCOUNT_SETUP_CONFLICT"});}
  finally {t.mock.restoreAll();syncBuiltinESMExports();}
  assert.equal(attempts,1);assert.deepEqual(await readFile(f.configPath),original);assert.equal(await readFile(f.providerPath,"utf8"),f.original);
  const checkpoints=(await readdir(f.dir)).filter(n=>n.startsWith("account-setup-checkpoint-"));assert.equal(checkpoints.length,1);assert.deepEqual(await readFile(join(f.dir,checkpoints[0])),original);
});

test("checkpoint directory durability failure occurs before configuration replacement", async t => {
  const f=await fixtureSetup(t),p=await f.preview(),before=await readFile(f.configPath),originalOpen=fs.open;
  t.mock.method(fs,"open",async (path,...args)=> {
    const handle=await originalOpen(path,...args);
    if(path===f.dir) return {sync:async()=>{throw new Error("FSYNC_FAILURE_SENTINEL");},close:()=>handle.close()};
    return handle;
  });syncBuiltinESMExports();
  try {await assert.rejects(f.commit(p,migration(p)),{code:"ACCOUNT_SETUP_CONFLICT"});}
  finally {t.mock.restoreAll();syncBuiltinESMExports();}
  assert.deepEqual(await readFile(f.configPath),before);
});

test("a verified complete receipt permits later metadata-only default changes", async t => {
  const f=await fixtureSetup(t,"accounts"),p=await f.preview(),a=p.accounts[0];
  const {sourceAlias,...account}=a;
  const prior={schemaVersion:1,operationId:randomUUID(),accountId:account.id,reference:account.credential,account,context:p.context,phase:"complete"};
  await writeFile(join(f.dir,"account-setup.json"),JSON.stringify(prior),{mode:0o600});
  await f.commit(p,{kind:"set_default",defaultAccountId:account.id});
  assert.deepEqual(JSON.parse(await readFile(join(f.dir,"account-setup.json"))),prior);
});

for (const url of [
  "https://gateway.example.invalid/api/v1/",
  "https://GATEWAY.Example.Invalid:443/api/v1",
]) {
  test(`migration accepts equivalent normalized direct URL ${url}`, async t => {
    const f=await fixtureSetup(t,"legacy");
    f.original=f.original.replace(f.config.upstreamBaseUrl,url);
    f.config.upstreamBaseUrl=url;await f.saveConfig();
    await writeFile(f.providerPath,f.original);
    const before=await readFile(f.configPath),p=await f.preview();
    const result=await f.commit(p,migration(p));
    assert.equal(result.setupState,"required");
    assert.equal(JSON.parse(await readFile(f.configPath)).upstreamBaseUrl,url);
    assert.deepEqual(await readFile(result.checkpointPath),before);
    assert.equal(await readFile(f.providerPath,"utf8"),f.original);
  });
}
