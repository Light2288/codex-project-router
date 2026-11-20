import assert from 'node:assert/strict';
import {readFile,writeFile,mkdir,readdir} from 'node:fs/promises';
import {join,isAbsolute} from 'node:path';
import {pathToFileURL} from 'node:url';
import {DatabaseSync} from 'node:sqlite';
import childProcess from 'node:child_process';
import https from 'node:https';
import {syncBuiltinESMExports} from 'node:module';

// Copied outside the checkout: only built-ins and explicit relocated production imports.
const args = process.argv.slice(2);
assert.equal(args.length,4); assert.equal(args[0],'--router-root'); assert.equal(args[2],'--fixture-root');
const routerRoot = args[1], fixtureRoot = args[3];
assert.ok(isAbsolute(routerRoot) && isAbsolute(fixtureRoot));
let credentialReads = 0, upstreamRequests = 0;
const originalSpawn = childProcess.spawn, originalRequest = https.request, originalGet = https.get, originalFetch = globalThis.fetch;
childProcess.spawn = () => { credentialReads++; throw new Error('credential read forbidden'); };
https.request = https.get = () => { upstreamRequests++; throw new Error('upstream request forbidden'); };
globalThis.fetch = (input,...options) => {
  const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url);
  if (url.hostname !== '127.0.0.1') { upstreamRequests++; throw new Error('upstream fetch forbidden'); }
  return originalFetch(input,...options);
};
syncBuiltinESMExports();

async function probe() {
  const {inspectCompanion} = await import(pathToFileURL(join(routerRoot,'src/companion.js')));
  const sourcePaths = (await readdir(join(routerRoot,'src'))).filter(name=>name.endsWith('.js')).map(name=>join(routerRoot,'src',name));
  const bytes = paths => Promise.all(paths.map(path=>readFile(path)));
  const sourceBytes = await bytes(sourcePaths);
  const home = join(fixtureRoot,'synthetic codex'); await mkdir(home,{mode:0o700});
  const statePath = join(home,'.codex-global-state.json'), dbPath = join(home,'state_5.sqlite');
  const providerPath = join(home,'config.toml'), configPath = join(fixtureRoot,'config.json');
  const projects = ['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
    '33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444'];
  const threads = ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc','dddddddd-dddd-4ddd-8ddd-dddddddddddd'];
  const account = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  const reference = name => ({keychainPath:'/synthetic-unavailable.keychain-db',service:'package-list-probe',account:name});
  const config = {schemaVersion:2,codexHome:home,providerId:'synthetic',listenPort:8787,
    upstreamBaseUrl:'https://synthetic.invalid/v1',projectRoutes:{[projects[2]]:'explicit-default'},
    accountRouting:{incomingCredential:reference('incoming'),defaultAccountId:account,
      accounts:{[account]:{displayName:'Synthetic default',upstreamBaseUrl:'https://synthetic.invalid/default/v1',credential:reference('outgoing')}},
      routeAccounts:{'explicit-default':account}}};
  const checkpoint = 'electron-owner-value:app-server-projects-migration-by-host:signed-out';
  const state = {'local-projects':Object.fromEntries(projects.map((id,i)=>[id,{id,name:['Empty','Archived','Mixed','Deleted reference'][i]}])),
    'thread-project-assignments':Object.fromEntries(threads.map((id,i)=>[id,{projectKind:'local',projectId:projects[i === 0 ? 1 : i === 3 ? 3 : 2]}])),
    'thread-project-membership-host-ids':Object.fromEntries(threads.map(id=>[id,'local'])), 'projectless-thread-ids':[],
    [checkpoint]:{[`local:${home}`]:{version:1,projectsMigrated:true,threadAssignmentsMigrated:false,pendingThreadAssignmentIds:threads}},
    'app-server-project-id-by-legacy-project-id-by-host':{[`local:${home}`]:Object.fromEntries(projects.map((id,i)=>[id,`99999999-9999-4999-8999-${String(i).padStart(12,'0')}`]))}};
  await writeFile(configPath,JSON.stringify(config),{mode:0o600});
  await writeFile(providerPath,'model_provider = "synthetic"\n[model_providers.synthetic]\nbase_url = "https://synthetic.invalid/v1"\nwire_api = "responses"\nsupports_websockets = false\n',{mode:0o600});
  const db = new DatabaseSync(dbPath);
  try {
    db.exec(`CREATE TABLE threads(id TEXT PRIMARY KEY,archived INTEGER,source TEXT,thread_source TEXT,
      project_id TEXT,attached_thread_parent_id TEXT,has_user_event INTEGER);
      CREATE TABLE thread_spawn_edges(parent_thread_id TEXT,child_thread_id TEXT PRIMARY KEY,status TEXT);
      CREATE TABLE backfill_state(status TEXT); INSERT INTO backfill_state VALUES('complete');`);
    const insert = db.prepare("INSERT INTO threads VALUES(?,?,'vscode','user',NULL,NULL,0)");
    insert.run(threads[0],1); insert.run(threads[1],1); insert.run(threads[2],0);
  } finally { db.close(); }
  let revision;
  for (const supported of [true,false]) {
    state[checkpoint][`local:${home}`].version = supported ? 1 : 99;
    await writeFile(statePath,JSON.stringify(state),{mode:0o600});
    const paths = [statePath,dbPath,providerPath,configPath], before = await bytes(paths);
    const result = await inspectCompanion({configPath});
    assert.equal(result.configuration.state,'valid'); assert.equal(result.catalog.state,'ready');
    assert.equal(result.catalog.entries.length,4);
    const byID = new Map(result.catalog.entries.map(entry=>[entry.id,entry]));
    for (const id of projects.slice(0,2)) assert.deepEqual(byID.get(id).chatActivity,
      supported ? {state:'no_active_chats',reason:null} : {state:'unknown',reason:'unsupported_metadata'});
    assert.deepEqual(byID.get(projects[2]).chatActivity,{state:'unarchived',reason:null});
    assert.deepEqual(byID.get(projects[3]).chatActivity,{state:'unknown',reason:'missing_record'});
    assert.equal(byID.get(projects[2]).assignmentKind,'override');
    if (revision) assert.equal(result.catalog.revision,revision); else revision = result.catalog.revision;
    assert.deepEqual(await bytes(paths),before,'inspection must preserve application stores/provider/config bytes');
  }
  assert.equal(credentialReads,0); assert.equal(upstreamRequests,0);
  assert.deepEqual(await bytes(sourcePaths),sourceBytes,'bundled sources must remain unchanged');
}
try {
  await probe();
  process.stdout.write('project-list-package-pass\n');
} catch {
  process.stderr.write('project-list-package-fail\n'); process.exitCode = 1;
} finally {
  childProcess.spawn = originalSpawn; https.request = originalRequest; https.get = originalGet; globalThis.fetch = originalFetch; syncBuiltinESMExports();
}
