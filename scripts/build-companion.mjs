import { copyFile, mkdir, readFile, writeFile, lstat, readdir, chmod, rm, realpath } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { execFile } from 'node:child_process';
const run = promisify(execFile);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sources = ['activation.js','admission.js','cli.js','companion-cli.js','companion.js','config.js','credentials.js','diagnostics.js','errors.js','identity.js','managed-serve.js','proxy.js','request-metadata.js','title-policy.js','title-state.js'];
async function copyRegular(source, destination) {
  const info = await lstat(source);
  if (!info.isFile() || info.isSymbolicLink()) throw new Error('Bundle input must be a regular file.');
  await copyFile(source, destination);
}
async function copyDirectory(source, destination) {
  const info = await lstat(source);
  if (!info.isDirectory() || info.isSymbolicLink()) throw new Error('Bundle dependency must be a real directory.');
  await mkdir(destination,{recursive:true});
  for (const entry of await readdir(source,{withFileTypes:true})) {
    if (entry.isDirectory()) await copyDirectory(join(source,entry.name),join(destination,entry.name));
    else await copyRegular(join(source,entry.name),join(destination,entry.name));
  }
}
export async function assembleCompanion({binaryPath,routerRoot,outputPath}) {
  const manifest = JSON.parse(await readFile(join(routerRoot,'package.json'),'utf8'));
  const dependencyRoot = join(routerRoot,'node_modules/smol-toml');
  const dependency = JSON.parse(await readFile(join(dependencyRoot,'package.json'),'utf8'));
  if (manifest.dependencies?.['smol-toml'] !== '1.9.1' || dependency.name !== 'smol-toml' || dependency.version !== '1.9.1') {
    throw new Error('Install the pinned smol-toml 1.9.1 dependency with npm ci.');
  }
  // Refuse replacement here: the CLI removes only its fixed, ignored output first.
  await mkdir(outputPath);
  const contents = join(outputPath,'Contents'), router = join(contents,'Resources/router');
  await mkdir(join(contents,'MacOS'),{recursive:true});
  await mkdir(join(router,'src'),{recursive:true});
  await copyRegular(binaryPath,join(contents,'MacOS/CodexProjectRouter'));
  await chmod(join(contents,'MacOS/CodexProjectRouter'),0o755);
  await copyRegular(join(root,'companion/Resources/Info.plist'),join(contents,'Info.plist'));
  await writeFile(join(router,'package.json'),JSON.stringify({name:'codex-project-router',version:'0.1.0',private:true,type:'module',engines:{node:'>=24 <25'},dependencies:{'smol-toml':'1.9.1'}},null,2)+'\n');
  for (const name of sources) await copyRegular(join(routerRoot,'src',name),join(router,'src',name));
  const installed = join(router,'node_modules/smol-toml');
  await mkdir(installed,{recursive:true});
  for (const name of ['package.json','LICENSE']) await copyRegular(join(dependencyRoot,name),join(installed,name));
  await copyDirectory(join(dependencyRoot,'dist'),join(installed,'dist'));
}
async function main() {
  if (process.platform !== 'darwin' || process.arch !== 'arm64') throw new Error('Build requires an Apple silicon Mac.');
  const built = await run('swift',['build','--package-path','companion','-c','release','--product','CodexProjectRouter'],{cwd:root,maxBuffer:8*1024*1024});
  process.stdout.write(built.stdout);process.stderr.write(built.stderr);
  const {stdout} = await run('swift',['build','--package-path','companion','-c','release','--show-bin-path'],{cwd:root});
  const outputPath = join(root,'dist/Codex Project Router.app');
  await mkdir(dirname(outputPath),{recursive:true});
  await rm(outputPath,{recursive:true,force:true});
  await assembleCompanion({binaryPath:join(stdout.trim(),'CodexProjectRouter'),routerRoot:root,outputPath});
  await run('/usr/bin/strip',['-S',join(outputPath,'Contents/MacOS/CodexProjectRouter')]);
  await run('/usr/bin/codesign',['--force','--sign','-',outputPath]);
  process.stdout.write('Built and ad-hoc signed dist/Codex Project Router.app\n');
}
if (process.argv[1] && await realpath(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    process.stderr.write('Companion build failed. Check the Swift toolchain and installed pinned dependency.\n');
    process.stderr.write(String(error.stderr || error.message) + '\n');
    process.exitCode=1;
  });
}
