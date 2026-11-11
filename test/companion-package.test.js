import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, readdir, rm, cp, stat, realpath } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { execFile, spawn } from 'node:child_process';
import net from 'node:net';
import { once } from 'node:events';
const run = promisify(execFile);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const builtApp = join(root, 'dist/Codex Project Router.app');
const sourceNames = ['activation.js','admission.js','cli.js','companion-cli.js','companion.js','config.js','credentials.js','diagnostics.js','errors.js','identity.js','proxy.js','request-metadata.js','title-policy.js','title-state.js'];
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

test('relocated signed app runs bundled inspection and synthetic lifecycle without GUI PATH', async t => {
  try { await stat(builtApp); } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    if (process.env.npm_lifecycle_event === 'companion:package-test') assert.fail('Build the app with npm run companion:build before package verification.');
    t.skip('App not built yet; companion:package-test requires the artifact.'); return;
  }
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
  const env={HOME:home,PATH:'/usr/bin:/bin',TMPDIR:tmpdir(),LANG:'en_US.UTF-8'};
  const cli=join(router,'src/companion-cli.js');
  async function bridge(request) {
    const child=spawn(node,['--use-system-ca',cli],{cwd:dir,env,stdio:['pipe','pipe','pipe']});
    let stdout='',stderr='';child.stdout.on('data',c=>stdout+=c);child.stderr.on('data',c=>stderr+=c);
    child.stdin.end(JSON.stringify({schemaVersion:1,...request}));
    const [code]=await once(child,'exit'); const response=JSON.parse(stdout);
    assert.equal(response.ok,true,stderr); assert.equal(code,0); return response.result;
  }
  const id='11111111-1111-4111-8111-111111111111';
  await writeFile(join(home,'.codex-global-state.json'),JSON.stringify({'local-projects':{[id]:{id,name:'Synthetic project'}}}));
  const free=net.createServer(); free.listen(0,'127.0.0.1');await once(free,'listening');const port=free.address().port;await new Promise(r=>free.close(r));
  const config={schemaVersion:1,codexHome:home,providerId:'synthetic',upstreamBaseUrl:'https://synthetic.invalid/v1',listenPort:port,projectRoutes:{[id]:'synthetic-route'}};
  const configPath=join(dir,'private router.json');await writeFile(configPath,JSON.stringify(config),{mode:0o600});
  const providerPath=join(home,'config.toml');const original='model_provider = "synthetic"\n[model_providers.synthetic]\nbase_url = "https://synthetic.invalid/v1"\nwire_api = "responses"\nsupports_websockets = false\n[model_providers.synthetic.auth]\ncommand = "/synthetic/auth-must-not-run"\nargs = []\n';
  await writeFile(providerPath,original,{mode:0o600});
  const before=await bridge({action:'inspect',configPath});assert.equal(before.provider.state,'direct');assert.equal(before.catalog.entries[0].name,'Synthetic project');
  const child=spawn(node,['--use-system-ca',join(router,'src/cli.js'),'serve','--config',configPath],{cwd:dir,env,stdio:['ignore','pipe','pipe']});
  child.stdout.resume();child.stderr.resume();let exit=once(child,'exit');
  t.after(async()=>{if(child.exitCode===null&&child.signalCode===null){child.kill('SIGTERM');await exit;}});
  let ready;
  for(let i=0;i<100;i++) {ready=await bridge({action:'inspect',configPath});if(ready.provider.proxyReady)break;await new Promise(r=>setTimeout(r,25));}
  assert.equal(ready.provider.proxyReady,true);
  await bridge({action:'activate',configPath,expectedContext:ready.context});
  assert.equal((await bridge({action:'inspect',configPath})).provider.state,'router');
  await bridge({action:'rollback',configPath,expectedContext:ready.context});
  assert.equal(await readFile(providerPath,'utf8'),original);
  child.kill('SIGTERM');await exit;
  assert.equal((await bridge({action:'inspect',configPath})).provider.proxyReady,false);
  for(const location of [join(dir,'Git checkout'),join(app,'Contents/Resources')]) {
    await mkdir(location,{recursive:true});if(location.includes('Git checkout'))await mkdir(join(location,'.git'));
    const forbidden=join(location,'private-config.json');await writeFile(forbidden,JSON.stringify(config),{mode:0o600});
    assert.equal((await bridge({action:'inspect',configPath:forbidden})).configuration.state,'invalid');
  }
});
