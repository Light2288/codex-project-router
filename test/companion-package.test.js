import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, readdir, rm, cp, stat, realpath, symlink } from 'node:fs/promises';
import { tmpdir, homedir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { execFile, spawn } from 'node:child_process';
import net from 'node:net';
import https from 'node:https';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
const run = promisify(execFile);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const builtApp = join(root, 'dist/Codex Project Router.app');
const sourceNames = ['activation.js','admission.js','cli.js','companion-cli.js','companion.js','config.js','credentials.js','diagnostics.js','errors.js','identity.js','managed-serve.js','proxy.js','request-metadata.js','title-policy.js','title-state.js'];
async function temporary(t) {
  const path = await mkdtemp(join(tmpdir(), 'companion package '));
  t.after(() => rm(path, {recursive:true,force:true}));
  return await realpath(path);
}
async function tree(path, prefix = '') {
  const result = [];
  for (const e of await readdir(path, {withFileTypes:true})) {
    assert.equal(e.isSymbolicLink(), false, 'bundle must not refer to checkout resources');
    const name = prefix + e.name;
    if (e.isDirectory()) result.push(...await tree(join(path,e.name), name+'/'));
    else result.push(name);
  }
  return result.sort();
}

function processes(t) {
  const children = [], ports = [], upstreams = [];
  async function stop(tracked) {
    if (tracked.child.exitCode === null && tracked.child.signalCode === null) tracked.child.kill('SIGTERM');
    const deadline = setTimeout(() => tracked.child.kill('SIGKILL'), 2000);
    try { await tracked.closed; } finally { clearTimeout(deadline); }
    assert.throws(() => process.kill(tracked.child.pid, 0), {code:'ESRCH'});
  }
  t.after(async () => {
    // Complete every cleanup/check even if an earlier child or port fails.
    const outcomes = await Promise.allSettled(children.toReversed().map(stop));
    outcomes.push(...await Promise.allSettled(upstreams.map(async upstream => {
      upstream.closeAllConnections();
      await new Promise(resolve => upstream.close(resolve));
    })));
    outcomes.push(...await Promise.allSettled(ports.map(reusablePort)));
    const errors = outcomes.filter(result => result.status === 'rejected').map(result => result.reason);
    if (errors.length) throw new AggregateError(errors,'Synthetic lifecycle cleanup failed');
  });
  return {
    stop,
    async port() {
      const free = net.createServer(); free.listen(0,'127.0.0.1'); await once(free,'listening');
      const port = free.address().port; await new Promise(resolve => free.close(resolve));
      ports.push(port); return port;
    },
    start(executable, args, options) {
      const child = spawn(executable,args,{...options,stdio:['pipe','pipe','pipe']});
      const tracked = {child,closed:once(child,'close'),stdout:'',stderr:'',offset:0};
      child.stdout.on('data',data => tracked.stdout += data);
      child.stderr.on('data',data => tracked.stderr += data);
      children.push(tracked); return tracked;
    },
    async upstream() {
      let connections = 0;
      const server = https.createServer({
        key: await readFile(join(root,'test/fixtures/tls/test-only-key.pem')),
        cert: await readFile(join(root,'test/fixtures/tls/test-only-cert.pem')),
      }, (_request,response) => response.end('{}'));
      server.on('connection', () => connections++);
      server.listen(0,'127.0.0.1'); await once(server,'listening'); upstreams.push(server);
      ports.push(server.address().port);
      return {url:`https://127.0.0.1:${server.address().port}/v1`,connections:() => connections};
    },
  };
}
async function reusablePort(port) {
  const empty = net.createServer(); empty.listen(port,'127.0.0.1'); await once(empty,'listening');
  await new Promise(resolve => empty.close(resolve));
}
async function nextFrame(tracked) {
  for (let i=0;i<200;i++) {
    const newline = tracked.stdout.indexOf('\n',tracked.offset);
    if (newline >= 0) {
      const frame = JSON.parse(tracked.stdout.slice(tracked.offset,newline));
      tracked.offset = newline + 1; return frame;
    }
    assert.equal(tracked.child.exitCode,null,tracked.stderr);
    assert.equal(tracked.child.signalCode,null,tracked.stderr);
    await new Promise(resolve => setTimeout(resolve,25));
  }
  assert.fail('Managed reply deadline exceeded: '+tracked.stderr);
}
async function managedModes(tracked, context, sessionId, unchanged, {ready=true} = {}) {
  if (ready) assert.deepEqual(await nextFrame(tracked), {schemaVersion:1,type:'ready',sessionId,context,mode:'off'});
  const pid = tracked.child.pid;
  async function listener() {
    const response = await fetch(`http://127.0.0.1:${context.listenPort}/healthz`);
    assert.equal(response.status,200);
    const health = await response.json();
    const {stdout} = await run('/usr/sbin/lsof',['-a','-p',String(pid),'-iTCP:'+context.listenPort,'-sTCP:LISTEN','-Fp'],{timeout:5000});
    assert.ok(stdout.split('\n').includes('p'+pid),'the same retained child must own the listener');
    return health;
  }
  const initialHealth = await listener();
  for (const [action,mode] of [['get_mode','off'],['set_mode','on'],['get_mode','on'],['set_mode','off'],['get_mode','off']]) {
    const requestId = randomUUID();
    assert.equal(tracked.child.stdin.writableEnded,false,'managed stdin must remain open');
    tracked.child.stdin.write(JSON.stringify({schemaVersion:1,sessionId,requestId,action,...(action === 'set_mode' ? {mode} : {})})+'\n');
    assert.deepEqual(await nextFrame(tracked),{schemaVersion:1,type:'mode',sessionId,requestId,mode});
    assert.deepEqual(await listener(),initialHealth,'mode changes must preserve listener fingerprint');
    await unchanged();
  }
}

async function requireBuiltApp(t) {
  try { await stat(builtApp); return true; } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    if (process.env.npm_lifecycle_event === 'companion:package-test') assert.fail('Build the app with npm run companion:build before package verification.');
    t.skip('App not built yet; companion:package-test requires the artifact.'); return false;
  }
}

test('assembly copies the explicit production allowlist and rejects dependency drift', async t => {
  const {assembleCompanion} = await import('../scripts/build-companion.mjs');
  const dir = await temporary(t), router = join(dir,'synthetic checkout');
  await mkdir(join(router,'src'),{recursive:true});
  await mkdir(join(router,'node_modules/smol-toml/dist'),{recursive:true});
  await writeFile(join(router,'package.json'), JSON.stringify({type:'module',dependencies:{'smol-toml':'1.9.1'}}));
  for (const name of sourceNames) await writeFile(join(router,'src',name), '// synthetic module\n');
  for (const extra of ['config.json','.git','test.js']) await writeFile(join(router,extra),'PRIVATE_SENTINEL');
  await writeFile(join(router,'src/private.json'),'PRIVATE_SENTINEL');
  const dep = join(router,'node_modules/smol-toml');
  await writeFile(join(dep,'package.json'),JSON.stringify({name:'smol-toml',version:'1.9.1',type:'module'}));
  await writeFile(join(dep,'LICENSE'),'synthetic license');
  await writeFile(join(dep,'README.md'),'PRIVATE_SENTINEL');
  await writeFile(join(dep,'dist/index.js'),'export default {};');
  const binary = join(dir,'binary'); await writeFile(binary,'synthetic binary',{mode:0o755});
  const output = join(dir,'Result App.app');
  await assembleCompanion({binaryPath:binary,routerRoot:router,outputPath:output});
  const resources = join(output,'Contents/Resources/router');
  assert.deepEqual(await tree(resources), ['node_modules/smol-toml/LICENSE','node_modules/smol-toml/dist/index.js','node_modules/smol-toml/package.json','package.json',...sourceNames.map(n=>'src/'+n)].sort());
  assert.equal((await stat(join(output,'Contents/MacOS/CodexProjectRouter'))).mode & 0o111,0o111);
  assert.equal(JSON.parse(await readFile(join(resources,'package.json'))).type,'module');
  await writeFile(join(dep,'package.json'),JSON.stringify({name:'smol-toml',version:'9.9.9'}));
  await assert.rejects(assembleCompanion({binaryPath:binary,routerRoot:router,outputPath:join(dir,'Bad.app')}), /pinned/);
});

test('relocated signed app runs bundled inspection and synthetic lifecycle without GUI PATH', {timeout:60_000}, async t => {
  if (!await requireBuiltApp(t)) return;
  const lifecycle = processes(t);
  const dir = await temporary(t), app = join(dir,'Relocated App With Spaces.app');
  await cp(builtApp,app,{recursive:true});
  const router = join(app,'Contents/Resources/router');
  const files = await tree(router);
  assert.deepEqual(await tree(app), ['Contents/Info.plist','Contents/MacOS/CodexProjectRouter','Contents/_CodeSignature/CodeResources',...files.map(p=>'Contents/Resources/router/'+p)].sort());
  const executable = await readFile(join(app,'Contents/MacOS/CodexProjectRouter'));
  assert.equal(executable.includes(Buffer.from(root)),false,'release binary must not embed a checkout path');
  assert.equal(executable.includes(Buffer.from(process.execPath)),false,'release binary must not embed a selected Node path');
  assert.deepEqual(files.filter(p=>!p.startsWith('node_modules/smol-toml/dist/')), ['node_modules/smol-toml/LICENSE','node_modules/smol-toml/package.json','package.json',...sourceNames.map(n=>'src/'+n)].sort());
  assert.ok(files.some(p=>p==='node_modules/smol-toml/dist/index.js'));
  assert.equal(JSON.parse(await readFile(join(router,'node_modules/smol-toml/package.json'))).version,'1.9.1');
  const {stdout:plist} = await run('/usr/bin/plutil',['-convert','json','-o','-',join(app,'Contents/Info.plist')]);
  const info=JSON.parse(plist);
  assert.equal(info.LSUIElement,true); assert.equal(info.CFBundleExecutable,'CodexProjectRouter'); assert.equal(info.LSMinimumSystemVersion,'14.0');
  await run('/usr/bin/codesign',['--verify','--deep','--strict',app]);
  const {stdout:architecture}=await run('/usr/bin/lipo',['-archs',join(app,'Contents/MacOS/CodexProjectRouter')]);
  assert.equal(architecture.trim(),'arm64');
  const node=await realpath(process.execPath);
  assert.match((await run(node,['--version'])).stdout,/^v24\./);
  // Exercise the CLI's process boundary with a fixture toolchain; signing and assembly stay real.
  const buildRoot=join(dir,'synthetic builder');
  await mkdir(join(buildRoot,'scripts'),{recursive:true});
  await mkdir(join(buildRoot,'companion/Resources'),{recursive:true});
  await mkdir(join(buildRoot,'fixture bin'),{recursive:true});
  await cp(join(root,'scripts/build-companion.mjs'),join(buildRoot,'scripts/build-companion.mjs'));
  await cp(join(app,'Contents/Info.plist'),join(buildRoot,'companion/Resources/Info.plist'));
  for (const name of ['package.json','src','node_modules']) await cp(join(router,name),join(buildRoot,name),{recursive:true});
  const commandLog=join(buildRoot,'swift-arguments.jsonl');
  const fixtureSwift=join(buildRoot,'fixture bin/swift');
  await writeFile(fixtureSwift, '#!'+node+'\n'+
    'import {appendFileSync} from "node:fs";\n'+
    'appendFileSync('+JSON.stringify(commandLog)+', JSON.stringify(process.argv.slice(2))+"\\n");\n'+
    'if(process.argv.includes("--show-bin-path")) console.log('+JSON.stringify(join(app,'Contents/MacOS'))+');\n', {mode:0o755});
  await run(node,[join(buildRoot,'scripts/build-companion.mjs')],{cwd:dir,env:{PATH:join(buildRoot,'fixture bin')+':/usr/bin:/bin',HOME:dir,TMPDIR:tmpdir()}});
  assert.deepEqual((await readFile(commandLog,'utf8')).trim().split('\n').map(line=>JSON.parse(line)),[
    ['build','--package-path','companion','-c','release','--product','CodexProjectRouter'],
    ['build','--package-path','companion','-c','release','--show-bin-path'],
  ]);
  await run('/usr/bin/codesign',['--verify','--deep','--strict',join(buildRoot,'dist/Codex Project Router.app')]);
  const home=join(dir,'private codex'); await mkdir(home,{mode:0o700});
  const env={HOME:home,CFFIXED_USER_HOME:home,PATH:'/usr/bin:/bin',TMPDIR:tmpdir(),LANG:'en_US.UTF-8'};
  const cli=join(router,'src/companion-cli.js');
  async function bridge(request) {
    const tracked=lifecycle.start(node,['--use-system-ca',cli],{cwd:dir,env});
    tracked.child.stdin.end(JSON.stringify({schemaVersion:1,...request}));
    const [code]=await tracked.closed; const response=JSON.parse(tracked.stdout);
    assert.equal(response.ok,true,tracked.stderr); assert.equal(code,0); return response.result;
  }
  const id='11111111-1111-4111-8111-111111111111';
  await writeFile(join(home,'.codex-global-state.json'),JSON.stringify({'local-projects':{[id]:{id,name:'Synthetic project'}}}));
  const port=await lifecycle.port(), upstream=await lifecycle.upstream();
  const config={schemaVersion:1,codexHome:home,providerId:'synthetic',upstreamBaseUrl:upstream.url,listenPort:port,projectRoutes:{[id]:'synthetic-route'}};
  const configPath=join(dir,'private router.json');await writeFile(configPath,JSON.stringify(config),{mode:0o600});
  const providerPath=join(home,'config.toml');const original='model_provider = "synthetic"\n[model_providers.synthetic]\nbase_url = "https://synthetic.invalid/v1"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.synthetic.auth]\ncommand = "/synthetic/auth-must-not-run"\nargs = []\n'.replace('https://synthetic.invalid/v1',upstream.url);
  await writeFile(providerPath,original,{mode:0o600});
  const before=await bridge({action:'inspect',configPath});assert.equal(before.provider.state,'direct');assert.equal(before.catalog.entries[0].name,'Synthetic project');
  const configBytes=await readFile(configPath), sessionId=randomUUID();
  const child=lifecycle.start(node,['--use-system-ca',join(router,'src/managed-serve.js'),'--config',configPath,'--session',sessionId],{cwd:dir,env});
  await managedModes(child,before.context,sessionId,async()=>{
    assert.deepEqual(await readFile(configPath),configBytes);
    assert.equal(await readFile(providerPath,'utf8'),original);
    assert.equal(upstream.connections(),0,'control-time upstream connections are forbidden');
  });
  let ready;
  for(let i=0;i<100;i++) {ready=await bridge({action:'inspect',configPath});if(ready.provider.proxyReady)break;await new Promise(r=>setTimeout(r,25));}
  assert.equal(ready.provider.proxyReady,true);
  await bridge({action:'activate',configPath,expectedContext:ready.context});
  const active=await bridge({action:'inspect',configPath}); assert.equal(active.provider.state,'router');
  const activeProviderBytes=await readFile(providerPath), activationPath=join(dirname(configPath),'activation.json');
  const activationBytes=await readFile(activationPath);
  await managedModes(child,ready.context,sessionId,async()=>{
    assert.deepEqual(await readFile(providerPath),activeProviderBytes);
    assert.deepEqual(await readFile(activationPath),activationBytes);
    assert.deepEqual(await readFile(configPath),configBytes);
    assert.equal((await bridge({action:'inspect',configPath})).revision,active.revision,'mode alone must preserve activation identity');
    assert.equal(upstream.connections(),0);
  },{ready:false});
  await bridge({action:'rollback',configPath,expectedContext:ready.context});
  assert.equal(await readFile(providerPath,'utf8'),original);
  await lifecycle.stop(child);
  assert.equal((await bridge({action:'inspect',configPath})).provider.proxyReady,false);
  // The historical standalone entry still starts independently with its existing contract.
  const standalone=lifecycle.start(node,['--use-system-ca',join(router,'src/cli.js'),'serve','--config',configPath],{cwd:dir,env});
  standalone.child.stdin.end();
  assert.deepEqual(await nextFrame(standalone),{state:'listening',host:'127.0.0.1',port});
  assert.equal((await bridge({action:'inspect',configPath})).provider.proxyReady,true);
  await lifecycle.stop(standalone);
  assert.equal((await bridge({action:'inspect',configPath})).provider.proxyReady,false);
  assert.equal(upstream.connections(),0);
  await reusablePort(port);
  for(const location of [join(dir,'Git checkout'),join(app,'Contents/Resources')]) {
    await mkdir(location,{recursive:true});if(location.includes('Git checkout'))await mkdir(join(location,'.git'));
    const forbidden=join(location,'private-config.json');await writeFile(forbidden,JSON.stringify(config),{mode:0o600});
    assert.equal((await bridge({action:'inspect',configPath:forbidden})).configuration.state,'invalid');
  }
});

test('native relocated app and bundled controls work with checkout reads denied by macOS', {timeout:60_000}, async t => {
  if (!await requireBuiltApp(t)) return;
  const lifecycle = processes(t);
  const dir = await temporary(t), app = join(dir, 'Source Denied App.app');
  await cp(builtApp, app, {recursive:true});
  await run('/usr/bin/codesign', ['--verify','--deep','--strict',app]);
  const node = await realpath(process.execPath), checkout = await realpath(root);
  const home = join(dir,'synthetic home'), codexHome = join(home,'.codex');
  const store = join(home,'.codex-project-router/companion');
  await mkdir(codexHome,{recursive:true,mode:0o700});
  await mkdir(store,{recursive:true,mode:0o700});
  const env = {HOME:home,CFFIXED_USER_HOME:home,PATH:'/usr/bin:/bin',TMPDIR:tmpdir(),LANG:'en_US.UTF-8'};
  const profile = join(dir,'deny-checkout.sb');
  // Seatbelt resolves symlinks. Deny both spellings and guard the user's private
  // stores even if a future native-home regression bypasses the synthetic home.
  const denied = [...new Set([root,checkout,join(homedir(),'.codex'),join(homedir(),'.codex-project-router')])];
  await writeFile(profile, '(version 1)\n(allow default)\n'+denied.map(path=>`(deny file-read* file-write* (subpath ${JSON.stringify(path)}))\n`).join('')+
    '(deny network-outbound)\n(allow network-outbound (remote ip "localhost:*"))\n');
  const options = {cwd:dir,env,timeout:10_000};
  const confined = (executable,args,extra={}) => run('/usr/bin/sandbox-exec',['-f',profile,executable,...args],{...options,...extra});
  const leak = join(dir,'checkout symlink'); await symlink(checkout,leak);
  for (const path of [...new Set([join(root,'package.json'),join(checkout,'package.json'),join(leak,'package.json')])]) {
    await assert.rejects(confined('/bin/cat',[path]), error => error.code === 1 && /Operation not permitted/.test(error.stderr));
  }
  // Node masks denied stat calls as module-not-found; independently assert the
  // underlying read error so a missing fixture cannot satisfy this control.
  const leakedSource = join(leak,'src/companion.js'); await stat(leakedSource);
  await assert.rejects(confined(node,['-e',`require('node:fs').readFileSync(${JSON.stringify(leakedSource)})`]),
    error => error.code === 1 && /EPERM/.test(error.stderr));
  await assert.rejects(confined(node,['--input-type=module','-e',`await import(${JSON.stringify(leakedSource)})`]),
    error => error.code === 1 && /ERR_MODULE_NOT_FOUND/.test(error.stderr));
  t.diagnostic('Seatbelt denied checkout package reads (lexical/resolved and symlink); Node source read returned EPERM and source import returned ERR_MODULE_NOT_FOUND.');

  const port = await lifecycle.port(), upstream = await lifecycle.upstream();
  const id = '22222222-2222-4222-8222-222222222222';
  const configPath = join(home,'.codex-project-router/config.json');
  await writeFile(configPath,JSON.stringify({schemaVersion:1,codexHome,providerId:'synthetic',upstreamBaseUrl:upstream.url,listenPort:port,projectRoutes:{[id]:'source-denied'}}),{mode:0o600});
  await writeFile(join(codexHome,'.codex-global-state.json'),JSON.stringify({'local-projects':{[id]:{id,name:'Source denied synthetic project'}}}),{mode:0o600});
  const providerPath = join(codexHome,'config.toml');
  const original = 'model_provider = "synthetic"\n[model_providers.synthetic]\nbase_url = "https://synthetic.invalid/v1"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.synthetic.auth]\ncommand = "/synthetic/auth-must-not-run"\nargs = []\n'.replace('https://synthetic.invalid/v1',upstream.url);
  await writeFile(providerPath,original,{mode:0o600});
  await writeFile(join(store,'state.json'),JSON.stringify({schemaVersion:1,selectedConfigurationPath:configPath,nodeExecutablePath:node}),{mode:0o600});
  const configBytes = await readFile(configPath);
  const start = (executable,args) => lifecycle.start('/usr/bin/sandbox-exec',['-f',profile,executable,...args],{cwd:dir,env});
  const native = start(join(app,'Contents/MacOS/CodexProjectRouter'),[]);
  native.child.stdin.end();
  let lockObserved = false;
  for (let i=0;i<50;i++) {
    assert.equal(native.child.exitCode,null,native.stderr);
    const {stdout} = await run('/usr/sbin/lsof',['-a','-p',String(native.child.pid),'-Fn'],{cwd:dir,env,timeout:5000});
    lockObserved = stdout.split('\n').includes('n'+join(store,'instance.lock'));
    if (lockObserved) break;
    await new Promise(r=>setTimeout(r,100));
  }
  assert.equal(lockObserved,true,'native process must hold the synthetic store lock; HOME overrides alone are insufficient');
  const windowProbe = 'import CoreGraphics; import Foundation; let pid = Int(CommandLine.arguments[1])!; let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String:Any]] ?? []; let found = windows.contains { ($0[kCGWindowOwnerPID as String] as? Int) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }; print(found ? "visible-native-window" : "missing"); exit(found ? 0 : 1)';
  await run('/usr/bin/swift',['-e',windowProbe,String(native.child.pid)],{cwd:dir,env,timeout:20_000});
  assert.deepEqual(JSON.parse(await readFile(join(store,'state.json'),'utf8')),{schemaVersion:1,selectedConfigurationPath:configPath,nodeExecutablePath:node});
  assert.deepEqual(await readFile(configPath),configBytes);
  assert.equal(await readFile(providerPath,'utf8'),original);
  t.diagnostic('Relocated signed native executable displayed its own on-screen window and held the synthetic companion instance.lock under source-denial confinement.');

  const router = join(app,'Contents/Resources/router');
  async function bridge(request) {
    const execution = confined(node,['--use-system-ca',join(router,'src/companion-cli.js')]);
    execution.child.stdin.end(JSON.stringify({schemaVersion:1,...request}));
    const {stdout} = await execution;
    const response = JSON.parse(stdout); assert.equal(response.ok,true); return response.result;
  }
  const before = await bridge({action:'inspect',configPath});
  assert.equal(before.provider.state,'direct'); assert.equal(before.provider.proxyReady,false);
  assert.equal(before.catalog.entries[0].name,'Source denied synthetic project');
  const sessionId = randomUUID();
  const server = start(node,['--use-system-ca',join(router,'src/managed-serve.js'),'--config',configPath,'--session',sessionId]);
  await managedModes(server,before.context,sessionId,async()=>{
    assert.deepEqual(await readFile(configPath),configBytes);
    assert.equal(await readFile(providerPath,'utf8'),original);
    assert.equal(upstream.connections(),0,'control-time upstream connections are forbidden');
  });
  let ready;
  for (let i=0;i<100;i++) {
    ready = await bridge({action:'inspect',configPath}); if (ready.provider.proxyReady) break;
    await new Promise(r=>setTimeout(r,25));
  }
  assert.equal(ready.provider.proxyReady,true,server.stderr);
  await bridge({action:'activate',configPath,expectedContext:ready.context});
  const active=await bridge({action:'inspect',configPath}); assert.equal(active.provider.state,'router');
  const activeProviderBytes=await readFile(providerPath), activationPath=join(dirname(configPath),'activation.json');
  const activationBytes=await readFile(activationPath);
  await managedModes(server,ready.context,sessionId,async()=>{
    assert.deepEqual(await readFile(providerPath),activeProviderBytes);
    assert.deepEqual(await readFile(activationPath),activationBytes);
    assert.deepEqual(await readFile(configPath),configBytes);
    assert.equal((await bridge({action:'inspect',configPath})).revision,active.revision,'mode alone must preserve activation identity');
    assert.equal(upstream.connections(),0);
  },{ready:false});
  await bridge({action:'rollback',configPath,expectedContext:ready.context});
  assert.equal(await readFile(providerPath,'utf8'),original);
  assert.deepEqual(await readFile(configPath),configBytes);
  await lifecycle.stop(server);
  assert.equal((await bridge({action:'inspect',configPath})).provider.proxyReady,false);
  await lifecycle.stop(native);
  assert.equal(upstream.connections(),0);
  await reusablePort(port);
  t.diagnostic('Under the same Seatbelt policy: bundled inspection/catalog, managed Ready Off and persistent get/set On/Off, stable listener/fingerprint/provider/router bytes, zero upstream connections, activation and byte-exact rollback passed; both tracked children exited and the selected synthetic port was reusable. No GUI control action is inferred.');
});
