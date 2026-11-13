import { readFile, open, lstat, realpath, readdir, rename, unlink } from "node:fs/promises";
import { dirname, join, isAbsolute, resolve } from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import net from "node:net";
import { parse } from "smol-toml";
import { inspectRouterConfiguration, UUID } from "./config.js";
import { inspectProviderConfiguration, inspectActivation } from "./activation.js";
import { RouterError } from "./errors.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const exact = (value, fields) => object(value) && Object.keys(value).length === fields.length && fields.every(field => Object.hasOwn(value, field));
const conflict = () => new RouterError("ACCOUNT_SETUP_CONFLICT");
const invalid = () => new RouterError("ACCOUNT_SETUP_INVALID");
const digest = value => createHash("sha256").update(value).digest("hex");
const accountFields = ["id", "displayName", "upstreamBaseUrl", "credential"];
const contextFor = (configPath, cfg) => ({configPath, codexHome:cfg.codexHome, providerId:cfg.providerId, listenPort:cfg.listenPort});
const sameFile = (a,b) => a.dev === b.dev && a.ino === b.ino && a.mode === b.mode && a.uid === b.uid;
async function privateDirectory(path) {
  const info = await lstat(path);
  if (!info.isDirectory() || info.uid !== process.getuid() || info.mode & 0o077 || await realpath(path) !== path) throw conflict();
}
async function ownedFile(path, privateOnly = true) {
  const info = await lstat(path);
  if (!info.isFile() || info.uid !== process.getuid() || info.nlink !== 1 || privateOnly && info.mode & 0o077) throw conflict();
  const bytes = await readFile(path);
  if (!sameFile(info, await lstat(path))) throw conflict();
  return {info, bytes};
}
function safeUrl(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) throw invalid();
    return url.href.replace(/\/$/, "");
  } catch { throw invalid(); }
}
function reference(value) {
  if (!exact(value,["keychainPath","service","account"]) || !isAbsolute(value.keychainPath ?? "") ||
    Object.values(value).some(v => typeof v !== "string" || !v.length || v.length > 1024 || /[\u0000-\u001f\u007f-\u009f]/.test(v))) throw invalid();
  return value;
}
function account(value) {
  if (!exact(value,accountFields) || !UUID.test(value.id) || typeof value.displayName !== "string" ||
    !value.displayName.length || value.displayName.trim() !== value.displayName || [...value.displayName].length > 80 ||
    /[\u0000-\u001f\u007f-\u009f]/.test(value.displayName)) throw invalid();
  return {id:value.id, displayName:value.displayName, upstreamBaseUrl:safeUrl(value.upstreamBaseUrl), credential:reference(value.credential)};
}
function incomingHint(auth) {
  if (auth.command !== "/usr/bin/security" || Object.keys(auth).some(k => !["command","args"].includes(k)) || !Array.isArray(auth.args)) return null;
  const args = auth.args;
  if (args[0] !== "find-generic-password" || args.some(v => typeof v !== "string")) return null;
  const result = {}, seen = new Set(); let password = false;
  for (let i = 1; i < args.length; i++) {
    const arg = args[i];
    if (arg === "-w" && !password) { password = true; continue; }
    if (["-s","-a"].includes(arg) && !seen.has(arg) && i + 1 < args.length) {
      if (args[i + 1].startsWith("-")) return null;
      seen.add(arg); result[arg === "-s" ? "service" : "account"] = args[++i]; continue;
    }
    if (i === args.length - 1 && isAbsolute(arg) && result.keychainPath === undefined) { result.keychainPath = arg; continue; }
    return null;
  }
  if (!password || !seen.has("-s") || !seen.has("-a") || Object.values(result).some(v => !v.length || v.length > 1024 || /[\u0000-\u001f\u007f-\u009f]/.test(v))) return null;
  return result;
}
function stableId(revision, slot) {
  const hex = digest(JSON.stringify([revision,slot]));
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-4${hex.slice(13,16)}-8${hex.slice(17,20)}-${hex.slice(20,32)}`;
}
function candidates(cfg, revision) {
  const accounts = [], usedNames = new Set();
  function add(slot, name, upstreamBaseUrl, credential, sourceAlias) {
    let displayName = name, n = 2;
    while (usedNames.has(displayName.toLowerCase())) displayName = `${name.slice(0,70)} (${n++})`;
    usedNames.add(displayName.toLowerCase());
    const value = {id:stableId(revision,slot),displayName,upstreamBaseUrl,credential,sourceAlias}; accounts.push(value); return value;
  }
  const originalDirect = add("original-direct","Default",cfg.upstreamBaseUrl,cfg.credentialRouting?.globalCredential ?? null,null);
  const routeAccounts = Object.fromEntries(Object.values(cfg.projectRoutes).map(alias=>[alias,null]));
  if (cfg.credentialRouting) {
    for (const alias of Object.keys(routeAccounts)) delete routeAccounts[alias];
    for (const [alias,target] of Object.entries(cfg.credentialRouting.routeTargets)) {
      const candidate = add(["route",alias],alias,target.upstreamBaseUrl,target.credential,alias); routeAccounts[alias] = candidate.id;
    }
  }
  return {accounts,routeAccounts,originalDirect};
}
async function receipt(path, operation, savedAccounts) {
  let file;
  try { file = await ownedFile(path); } catch (e) { if (e.code === "ENOENT") return null; throw e; }
  let r; try { r = JSON.parse(file.bytes); } catch { throw conflict(); }
  if (!operation || !exact(r,["schemaVersion","operationId","accountId","reference","account","context","phase"]) || r.schemaVersion !== 1 ||
    !UUID.test(r.operationId) || !UUID.test(r.accountId) || r.account?.id !== r.accountId ||
    !isDeepStrictEqual(r.context,operation.expectedContext) || !["prepared","item_created","committing","complete"].includes(r.phase)) throw conflict();
  try { account(r.account); reference(r.reference); } catch { throw conflict(); }
  if (!isDeepStrictEqual(r.reference,r.account.credential)) throw conflict();
  if (r.operationId !== operation.operationId) {
    const {id,...metadata}=r.account;
    if (r.phase !== "complete" || !savedAccounts || !Object.hasOwn(savedAccounts,id) || !isDeepStrictEqual(savedAccounts[id],metadata)) throw conflict();
  }
  return r;
}
async function source(configPath, browseHome, operation) {
  if (typeof configPath !== "string" || !isAbsolute(configPath) || resolve(configPath) !== configPath) throw invalid();
  const dir = dirname(configPath); await privateDirectory(dir);
  for (let ancestor=dir; ; ancestor=dirname(ancestor)) {
    if (ancestor.toLowerCase().endsWith(".app")) throw conflict();
    try { await lstat(join(ancestor,".git")); throw conflict(); }
    catch(e) { if(e.code!=="ENOENT") throw e; }
    if(dirname(ancestor)===ancestor) break;
  }
  let file;
  try { file = await ownedFile(configPath); } catch (e) { if (e.code !== "ENOENT") throw e; }
  let cfg, inspection, value;
  if (file) {
    if (await realpath(configPath) !== configPath) throw conflict();
    inspection = await inspectRouterConfiguration(configPath);
    if (inspection.setupState === "invalid") throw invalid();
    cfg = inspection.config; value = JSON.parse(file.bytes);
    if (digest(file.bytes) !== inspection.configurationRevision) throw conflict();
  } else {
    if (typeof browseHome !== "string" || !isAbsolute(browseHome) || await realpath(browseHome) !== browseHome) throw conflict();
    // Missing is a new destination only when no abandoned activation or setup
    // evidence could belong to a previously configured context.
    for (const name of await readdir(dir)) {
      if (name === "account-setup.json") { await receipt(join(dir,name),operation); continue; }
      if (name === "activation.json" || name === "companion-journal.json" || /^codex-config-.*\.toml$/.test(name) || /^account-setup-checkpoint-/.test(name)) throw conflict();
    }
    const provider = await ownedFile(join(browseHome,"config.toml"),false);
    let providerId; try { providerId = parse(provider.bytes.toString()).model_provider; } catch { throw new RouterError("CONFIG_UNSUPPORTED"); }
    if (typeof providerId !== "string" || !/^[a-zA-Z0-9_-]+$/.test(providerId)) throw new RouterError("CONFIG_UNSUPPORTED");
    const compatible = inspectProviderConfiguration(provider.bytes.toString(),{providerId});
    cfg = {schemaVersion:2,codexHome:browseHome,providerId,listenPort:8787,upstreamBaseUrl:safeUrl(compatible.url),projectRoutes:{}};
    value = {...cfg};
    // Only validated non-secret operational metadata contributes. Never hash
    // provider TOML: arbitrary authentication helper arguments may be secret.
    inspection = {setupState:"required",configurationRevision:digest(JSON.stringify(["new-configuration",contextFor(configPath,cfg),cfg.upstreamBaseUrl]))};
  }
  const provider = await ownedFile(join(cfg.codexHome,"config.toml"),false);
  const compatible = inspectProviderConfiguration(provider.bytes.toString(),cfg);
  return {file,cfg,value,inspection,provider,compatible,context:contextFor(configPath,cfg)};
}
function preview(s) {
  const {cfg,inspection,context,compatible} = s;
  const proposed = candidates(cfg,inspection.configurationRevision);
  return {context,configurationRevision:inspection.configurationRevision,setupState:inspection.setupState,
    sourceKind:!s.file?"missing":cfg.schemaVersion===2?"accounts":cfg.credentialRouting?"enabled":"legacy",
    accounts:cfg.accountRouting?Object.entries(cfg.accountRouting.accounts).map(([id,a])=>({id,...a,sourceAlias:null})):proposed.accounts,
    routeAccounts:cfg.accountRouting?.routeAccounts ?? proposed.routeAccounts,
    incomingCredential:cfg.accountRouting?.incomingCredential ?? null,defaultAccountId:cfg.accountRouting?.defaultAccountId ?? null,
    incomingHint:incomingHint(compatible.data.model_providers[cfg.providerId].auth),originalDirect:proposed.originalDirect};
}
export async function previewAccountSetup({configPath,browseHome} = {}) {
  try { return preview(await source(configPath,browseHome)); }
  catch(e) { throw e instanceof RouterError?e:conflict(); }
}
async function liveLease(dir, input, original) {
  const file = await ownedFile(join(dir,".activation.lock"));
  let value; try { value = JSON.parse(file.bytes); } catch { throw conflict(); }
  if (!exact(value,["pid","setupOperationId","configPath"]) || ![process.pid,process.ppid].includes(value.pid) ||
    value.setupOperationId !== input.operationId || value.configPath !== input.configPath ||
    original && (!sameFile(original.info,file.info) || !original.bytes.equals(file.bytes))) throw conflict();
  return file;
}
async function emptyPort(port) {
  const server = net.createServer();
  await new Promise((resolve,reject)=> {
    server.once("error",()=>reject(conflict()));
    server.listen({host:"127.0.0.1",port,exclusive:true},()=>server.close(error=>error?reject(conflict()):resolve()));
  });
}
function apply(s,p,change) {
  if (!object(change)) throw invalid();
  const value = structuredClone(s.value); value.schemaVersion = 2; delete value.credentialRouting;
  const routing = value.accountRouting ?? {incomingCredential:null,defaultAccountId:null,accounts:{},routeAccounts:{}};
  if (change.kind === "migrate") {
    if (!s.file || s.cfg.schemaVersion !== 1 || !exact(change,["kind","accounts","incomingCredential","defaultAccountId"]) || !Array.isArray(change.accounts) || change.accounts.length !== p.accounts.length) throw invalid();
    const accounts = change.accounts.map(account), names = new Set();
    if (new Set(accounts.map(a=>a.id)).size !== accounts.length) throw invalid();
    for (const candidate of p.accounts) {
      const chosen = accounts.find(a=>a.id===candidate.id);
      if (!chosen || chosen.upstreamBaseUrl!==candidate.upstreamBaseUrl || candidate.credential && !isDeepStrictEqual(chosen.credential,candidate.credential) || names.has(chosen.displayName.toLowerCase())) throw invalid();
      names.add(chosen.displayName.toLowerCase());
    }
    routing.accounts = Object.fromEntries(accounts.map(({id,...a})=>[id,a]));
    routing.routeAccounts = p.routeAccounts;
    routing.incomingCredential = change.incomingCredential === null ? null : reference(change.incomingCredential);
    routing.defaultAccountId = change.defaultAccountId;
  } else if (change.kind === "create_configuration") {
    if (s.file || !exact(change,["kind","account","incomingCredential","defaultAccountId"])) throw invalid();
    const {id,...a}=account(change.account); routing.accounts = {[id]:a};
    routing.incomingCredential=change.incomingCredential===null?null:reference(change.incomingCredential); routing.defaultAccountId=change.defaultAccountId;
  } else if (change.kind === "add_account") {
    const fields = Object.hasOwn(change,"incomingCredential") ? ["kind","account","incomingCredential"] : ["kind","account"];
    if (!s.file || s.cfg.schemaVersion!==2 || !exact(change,fields)) throw invalid();
    const {id,...a}=account(change.account);
    if (Object.keys(routing.accounts).some(old=>old.toLowerCase()===id.toLowerCase())) throw invalid();
    routing.accounts[id]=a;
  } else if (change.kind === "set_default") {
    const fields = Object.hasOwn(change,"incomingCredential") ? ["kind","defaultAccountId","incomingCredential"] : ["kind","defaultAccountId"];
    if (!s.file || s.cfg.schemaVersion!==2 || !exact(change,fields)) throw invalid();
    routing.defaultAccountId=change.defaultAccountId;
  } else throw invalid();
  if (["add_account","set_default"].includes(change.kind) && Object.hasOwn(change,"incomingCredential")) {
    const chosen=reference(change.incomingCredential);
    if(routing.incomingCredential!==null && !isDeepStrictEqual(chosen,routing.incomingCredential)) throw invalid();
    routing.incomingCredential=chosen;
  }
  if (routing.defaultAccountId!==null && (typeof routing.defaultAccountId!=="string" || !Object.hasOwn(routing.accounts,routing.defaultAccountId))) throw invalid();
  const names=new Set();
  for (const a of Object.values(routing.accounts)) { if(names.has(a.displayName.toLowerCase())) throw invalid(); names.add(a.displayName.toLowerCase()); }
  value.accountRouting=routing; return value;
}
export async function commitAccountSetup(input = {}) {
  let temp, tempCreated=false;
  try {
    if (!exact(input,["configPath","expectedContext","expectedRevision","operationId","change"]) || typeof input.configPath!=="string" || !isAbsolute(input.configPath) ||
      typeof input.operationId!=="string" || !UUID.test(input.operationId) || typeof input.expectedRevision!=="string" || !/^[a-f0-9]{64}$/.test(input.expectedRevision) ||
      Buffer.byteLength(JSON.stringify(input))>1024*1024) throw invalid();
    const dir=dirname(input.configPath); await privateDirectory(dir);
    const lease=await liveLease(dir,input);
    const load=()=>source(input.configPath,input.expectedContext?.codexHome,input);
    const initial=await load(), p=preview(initial);
    if (!isDeepStrictEqual(initial.context,input.expectedContext) || p.configurationRevision!==input.expectedRevision) throw conflict();
    const saved=apply(initial,p,input.change);
    const setupReceipt=await receipt(join(dir,"account-setup.json"),input,initial.cfg.accountRouting?.accounts);
    if(setupReceipt?.operationId===input.operationId && !isDeepStrictEqual(saved.accountRouting.accounts[setupReceipt.accountId],(({id,...a})=>a)(setupReceipt.account))) throw conflict();
    const fresh=async()=> {
      await liveLease(dir,input,lease);
      if (!isDeepStrictEqual(await receipt(join(dir,"account-setup.json"),input,initial.cfg.accountRouting?.accounts),setupReceipt)) throw conflict();
      const current=await load();
      if (!isDeepStrictEqual(current.context,input.expectedContext) || current.inspection.configurationRevision!==input.expectedRevision ||
        Boolean(current.file)!==Boolean(initial.file) || initial.file && (!sameFile(initial.file.info,current.file.info) || !initial.file.bytes.equals(current.file.bytes)) ||
        !sameFile(initial.provider.info,current.provider.info) || !initial.provider.bytes.equals(current.provider.bytes) || current.compatible.url.replace(/\/$/, "")!==current.cfg.upstreamBaseUrl) throw conflict();
      await emptyPort(current.cfg.listenPort);
      if(current.file) {
        const activation=await inspectActivation(input.configPath,{probeProxy:false});
        if(activation.status.state!=="direct" || activation.status.recoveryRequired || !["none","restored"].includes(activation.recordPhase)) throw conflict();
      }
    };
    await fresh();
    temp=join(dir,`.account-setup-${randomUUID()}.tmp`);
    const handle=await open(temp,"wx",initial.file ? initial.file.info.mode & 0o777 : 0o600); tempCreated=true;
    try { await handle.writeFile(JSON.stringify(saved,null,2)+"\n"); await handle.sync(); } finally { await handle.close(); }
    const validation=await inspectRouterConfiguration(temp);
    if(validation.setupState==="invalid") throw invalid();
    await fresh();
    let checkpointPath=null;
    if(initial.file) {
      checkpointPath=join(dir,`account-setup-checkpoint-${input.operationId}.json`);
      const checkpoint=await open(checkpointPath,"wx",initial.file.info.mode & 0o777);
      try { await checkpoint.writeFile(initial.file.bytes); await checkpoint.sync(); } finally { await checkpoint.close(); }
      const checkpointDirectory=await open(dir,"r");
      try { await checkpointDirectory.sync(); } finally { await checkpointDirectory.close(); }
    }
    await fresh();
    await rename(temp,input.configPath); tempCreated=false;
    const directory=await open(dir,"r"); try { await directory.sync(); } finally { await directory.close(); }
    return {context:input.expectedContext,operationId:input.operationId,setupState:validation.setupState,configurationRevision:validation.configurationRevision,checkpointPath,changed:true};
  } catch(e) { throw e instanceof RouterError?e:conflict(); }
  finally { if(tempCreated) await unlink(temp); }
}
