import * as defaultFS from "node:fs/promises";
import { dirname, join, isAbsolute, resolve } from "node:path";
import { loadRouterConfig } from "./config.js";
import { RouterError } from "./errors.js";

const conflict = () => new RouterError("ACTIVATION_CONFLICT");
const sameIdentity = (a,b) => ["dev","ino","uid","mode","nlink"].every(key=>a[key]===b[key]);
// Setup, activation, startup and assignment writes share this exclusive lease.
// Never reclaim an existing lock: only its owner can decide when it is safe.
export async function withConfigurationLock(configPath, action, {fs = defaultFS} = {}) {
  if(typeof configPath!=="string" || !isAbsolute(configPath) || resolve(configPath)!==configPath) throw conflict();
  let actualPath;
  try { actualPath=await fs.realpath(configPath); } catch { throw new RouterError("CONFIG_UNAVAILABLE"); }
  const configInfo=await fs.lstat(configPath);
  if(!configInfo.isFile() || configInfo.uid!==process.getuid() || configInfo.nlink!==1 || configInfo.mode & 0o077) throw conflict();
  configPath=actualPath;
  const directory=dirname(configPath), lockPath=join(directory,".activation.lock");
  const parent=await fs.lstat(directory);
  if(!parent.isDirectory() || parent.uid!==process.getuid() || parent.mode & 0o077 || await fs.realpath(directory)!==directory) throw conflict();
  let handle;
  try { handle=await fs.open(lockPath,"wx",0o600); }
  catch(error) { throw new RouterError(error.code==="EEXIST" ? "ACTIVATION_CONFLICT" : "STORAGE_FAILED"); }
  let owned, ownedBytes, result, failure;
  const assertUnchanged=async()=> {
    const current=await fs.lstat(lockPath), latestParent=await fs.lstat(directory), descriptor=await handle.stat();
    if(!current.isFile() || current.uid!==process.getuid() || current.mode & 0o077 || current.nlink!==1 ||
      !sameIdentity(owned,current) || !sameIdentity(owned,descriptor) ||
      parent.dev!==latestParent.dev || parent.ino!==latestParent.ino || parent.uid!==latestParent.uid || parent.mode!==latestParent.mode ||
      !latestParent.isDirectory() || await fs.realpath(directory)!==directory ||
      ownedBytes && !(await fs.readFile(lockPath)).equals(ownedBytes)) throw conflict();
  };
  try {
    owned=await handle.stat();
    ownedBytes=Buffer.from(JSON.stringify({pid:process.pid}));
    await handle.writeFile(ownedBytes);
    await assertUnchanged();
    result=await action(await loadRouterConfig(configPath),{assertUnchanged});
  } catch(error) { failure=error; }
  try {
    if(owned) { await assertUnchanged(); await fs.unlink(lockPath); }
  } catch(error) { failure=error instanceof RouterError ? error : new RouterError(error.code==="ENOENT" ? "ACTIVATION_CONFLICT" : "STORAGE_FAILED"); }
  try { await handle.close(); } catch(error) { failure=error; }
  if(failure) throw failure instanceof RouterError ? failure : new RouterError("STORAGE_FAILED");
  return result;
}
