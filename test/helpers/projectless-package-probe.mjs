import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join, isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { once } from 'node:events';
import { Writable } from 'node:stream';
import http from 'node:http';
import https from 'node:https';
import net from 'node:net';

// This executable is copied outside the checkout before confinement. Its only
// non-built-in import is the relocated production proxy selected by the caller.
const args = process.argv.slice(2);
assert.equal(args.length, 4);
assert.equal(args[0], '--router-root');
assert.equal(args[2], '--fixture-root');
const routerRoot = args[1], fixtureRoot = args[3];
assert.ok(isAbsolute(routerRoot) && isAbsolute(fixtureRoot));
const servers = [], ports = [], events = [];
let agent;

async function listen(server) {
  servers.push(server);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  ports.push(server.address().port);
  // The owning test can verify every port after a deadline kills this process.
  await writeFile(join(fixtureRoot, 'ports.json'), JSON.stringify(ports), {mode:0o600});
  return server.address().port;
}
async function closeServers() {
  agent?.destroy();
  const outcomes = await Promise.allSettled(servers.toReversed().map(async server => {
    server.closeAllConnections();
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }));
  const errors = outcomes.filter(result => result.status === 'rejected').map(result => result.reason);
  const portChecks = await Promise.allSettled(ports.map(async port => {
    const server = net.createServer();
    server.listen(port, '127.0.0.1');
    await once(server, 'listening');
    await new Promise(resolve => server.close(resolve));
  }));
  errors.push(...portChecks.filter(result => result.status === 'rejected').map(result => result.reason));
  if (errors.length) throw new AggregateError(errors, 'Probe cleanup failed');
}
function headers(id, title = false) {
  return ['thread-id', id, 'session-id', id, 'x-codex-turn-metadata', JSON.stringify({
    thread_id:id, session_id:id, ...(title ? {thread_source:'thread_title',turn_trigger:'thread_title'} : {}),
  })];
}
function request(port, {path='/v1/responses', method='POST', raw, authorization='bEaReR PUBLIC_INCOMING', body}) {
  return new Promise((resolve, reject) => {
    const req = http.request({host:'127.0.0.1',port,path,method,agent:false,
      headers:['Host','127.0.0.1','Authorization',authorization,...raw]}, res => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('error', reject);
      res.on('end', () => resolve({status:res.statusCode,body:Buffer.concat(chunks).toString()}));
    });
    req.on('error', reject);
    req.setTimeout(4000, () => req.destroy(new Error('Probe request deadline exceeded')));
    req.end(body);
  });
}

async function probe() {
  const {createProxy} = await import(pathToFileURL(join(routerRoot, 'src/proxy.js')));
  const {inspectRouterConfigurationValue} = await import(pathToFileURL(join(routerRoot, 'src/config.js')));
  const key = await readFile(join(fixtureRoot, 'test-only-key.pem'));
  const cert = await readFile(join(fixtureRoot, 'test-only-cert.pem'));
  const observers = {};
  for (const name of ['original','default','override']) {
    const calls = [];
    const server = https.createServer({key,cert}, async (req, res) => {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      calls.push({path:req.url,host:req.headers.host,authorization:req.headers.authorization,body:Buffer.concat(chunks)});
      res.end(name);
    });
    const port = await listen(server);
    observers[name] = {calls,url:`https://127.0.0.1:${port}/${name}/v1`};
  }
  const project = '11111111-1111-4111-8111-111111111111';
  const mapped = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const projectless = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const child = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const unknown = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  const conflict = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  const title = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  const defaultAccount = '12345678-1234-4234-8234-123456789001';
  const overrideAccount = '12345678-1234-4234-8234-123456789002';
  const home = join(fixtureRoot, 'synthetic codex');
  await mkdir(home, {mode:0o700});
  await writeFile(join(home, '.codex-global-state.json'), JSON.stringify({
    'local-projects':{[project]:{id:project}},
    'thread-project-assignments':{[mapped]:{projectKind:'local',projectId:project}},
    'projectless-thread-ids':[projectless,conflict],
  }), {mode:0o600});
  const db = new DatabaseSync(join(home, 'state_5.sqlite'));
  try {
    db.exec('CREATE TABLE thread_spawn_edges(parent_thread_id TEXT NOT NULL, child_thread_id TEXT NOT NULL PRIMARY KEY, status TEXT NOT NULL)');
    db.exec('CREATE TABLE threads(id TEXT PRIMARY KEY)');
    const edge = db.prepare('INSERT INTO thread_spawn_edges VALUES(?,?,?)');
    edge.run(projectless, child, 'completed');
    edge.run(mapped.toUpperCase(), conflict, 'completed');
  } finally { db.close(); }
  const reference = name => ({keychainPath:'/synthetic-unavailable.keychain-db',service:'package-request-probe',account:name});
  const refs = {incoming:reference('incoming'),default:reference('default'),override:reference('override')};
  const reads = [];
  const config = {schemaVersion:2,codexHome:home,providerId:'synthetic',listenPort:8787,
    upstreamBaseUrl:observers.original.url,projectRoutes:{[project]:'mapped'},allowUnassignedThreadTitles:true,
    accountRouting:{incomingCredential:refs.incoming,defaultAccountId:defaultAccount,accounts:{
      [defaultAccount]:{displayName:'Default',upstreamBaseUrl:observers.default.url,credential:refs.default},
      [overrideAccount]:{displayName:'Override',upstreamBaseUrl:observers.override.url,credential:refs.override},
    },routeAccounts:{mapped:overrideAccount}}};
  assert.equal(inspectRouterConfigurationValue(config).setupState, 'ready');
  let mode = 'off';
  agent = new https.Agent({ca:cert});
  const proxy = createProxy(config, {
    getRequestRoutingSnapshot:() => ({config,mode}), upstreamAgent:agent,
    diagnostics:new Writable({write(chunk, _encoding, done) { events.push(JSON.parse(chunk)); done(); }}),
    credentialReader:async (ref, {signal}) => {
      assert.equal(signal.aborted, false);
      const name = Object.keys(refs).find(name => ref === refs[name]);
      assert.ok(name);
      reads.push(name);
      return {incoming:'PUBLIC_INCOMING',default:'PUBLIC_DEFAULT',override:'PUBLIC_OVERRIDE'}[name];
    },
  });
  const proxyPort = await listen(proxy);
  const body = Buffer.from(' {"model":"public-model","previous_response_id":"public-continuation","input":"π"} \n');
  const total = () => Object.values(observers).reduce((sum, value) => sum + value.calls.length, 0);
  for (mode of ['on','off']) {
    for (const [options,path,bytes,source] of [
      [{raw:headers(projectless),path:'/v1/responses?x=a%2Fb&x=2',body},'/original/v1/responses?x=a%2Fb&x=2',body,'projectless'],
      [{raw:headers(child),path:'/v1/responses/compact?resume=a%2Fb',body},'/original/v1/responses/compact?resume=a%2Fb',body,'projectless'],
      [{raw:[],method:'GET',path:'/v1/models?x=a%2Fb',body:''},'/original/v1/models?x=a%2Fb',Buffer.alloc(0),'catalog'],
      [{raw:headers(title,true),path:'/v1/responses?title=a%2Fb',body},'/original/v1/responses?title=a%2Fb',body,'unassigned_title'],
    ]) {
      const before = reads.length;
      assert.deepEqual(await request(proxyPort,options), {status:200,body:'original'});
      assert.deepEqual(reads.slice(before), ['incoming']);
      assert.deepEqual(observers.original.calls.at(-1), {path,host:new URL(observers.original.url).host,
        authorization:'bEaReR PUBLIC_INCOMING',body:bytes});
      const event = events.filter(event => event.event === 'started').at(-1);
      assert.equal(event.source, source); assert.equal(event.routeSelection, 'original'); assert.equal(event.routingMode, mode);
      for (const field of ['projectId','routeAlias']) assert.equal(Object.hasOwn(event,field), false);
    }
    const selected = mode === 'on' ? 'override' : 'default', before = reads.length;
    assert.deepEqual(await request(proxyPort,{raw:headers(mapped),body}), {status:200,body:selected});
    assert.deepEqual(reads.slice(before), ['incoming',selected]);
    assert.deepEqual(observers[selected].calls.at(-1), {path:`/${selected}/v1/responses`,
      host:new URL(observers[selected].url).host,authorization:mode === 'on' ? 'Bearer PUBLIC_OVERRIDE' : 'Bearer PUBLIC_DEFAULT',body});
    for (const [options,status] of [
      [{raw:headers(unknown),body},503],
      [{raw:headers(conflict),body},409],
      [{raw:['thread-id',projectless,'x-codex-turn-metadata',JSON.stringify({thread_id:mapped})],body},409],
      [{raw:headers(projectless),body,authorization:'Bearer PUBLIC_WRONG'},401],
    ]) {
      const count = total();
      assert.equal((await request(proxyPort,options)).status, status);
      assert.equal(total(), count, 'denied requests must make no model call');
    }
  }
  assert.deepEqual(Object.fromEntries(Object.entries(observers).map(([name,value]) => [name,value.calls.length])),
    {original:8,default:1,override:1});
  assert.doesNotMatch(JSON.stringify(events), /PUBLIC_|public-model|public-continuation|https:/);
}

try {
  try { await probe(); }
  finally { await closeServers(); }
  process.stdout.write('projectless-package-pass\n');
} catch {
  // Keep credentials, requests, paths and configuration out of subprocess output.
  process.stderr.write('projectless-package-fail\n');
  process.exitCode = 1;
}
