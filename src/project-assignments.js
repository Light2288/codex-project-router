import * as defaultFS from "node:fs/promises";
import { constants } from "node:fs";
import { dirname, join, isAbsolute, resolve } from "node:path";
import net from "node:net";
import { createHash } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import { inspectRouterConfigurationValue, readRouterConfigurationSource, configurationIdentityFor, configFingerprint, UUID } from "./config.js";
import { RouterError } from "./errors.js";
import { inspectProjectCatalog } from "./project-catalog.js";
import { inspectProviderConfiguration, inspectActivation } from "./activation.js";
import { withConfigurationLock } from "./configuration-lock.js";

const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const digest = source => createHash("sha256").update(source).digest("hex");
const conflict = () => new RouterError("ACTIVATION_CONFLICT");
const invalid = () => new RouterError("CONFIG_INVALID");
function assignmentSummary(config, projectId) {
  const routing = config.accountRouting;
  const hasMapping = Object.hasOwn(config.projectRoutes, projectId);
  const routeAlias = hasMapping ? config.projectRoutes[projectId] : undefined;
  const hasBinding = hasMapping && Object.hasOwn(routing.routeAccounts, routeAlias);
  const kind = !hasMapping ? "inherited" : !hasBinding
    ? "target_missing" : routing.routeAccounts[routeAlias] === null ? "legacy_inherited" : "override";
  const accountId = kind === "target_missing" ? undefined : kind === "override"
    ? routing.routeAccounts[routeAlias] : routing.defaultAccountId;
  return { kind, ...(accountId === undefined ? {} : { account: { id: accountId, displayName: routing.accounts[accountId].displayName } }),
    ...(hasMapping ? { routeAlias } : {}) };
}
function validatedSource(source) {
  if (!object(source) || typeof source.source !== "string" ||
    typeof source.configurationRevision !== "string" || digest(source.source) !== source.configurationRevision) throw conflict();
  let parsed;
  try { parsed = JSON.parse(source.source); } catch { throw conflict(); }
  if (!isDeepStrictEqual(parsed, source.value)) throw conflict();
  const inspection = inspectRouterConfigurationValue(parsed);
  if (inspection.config.schemaVersion !== 2 || inspection.setupState !== "ready") throw invalid();
  if (!isDeepStrictEqual(inspection.config, source.config)) throw conflict();
  const catalog = source.catalog;
  if (!object(catalog) || catalog.state !== "ready" || !/^[a-f0-9]{64}$/.test(catalog.revision ?? "") || !Array.isArray(catalog.entries)) throw conflict();
  const identities = new Set();
  for (const entry of catalog.entries) {
    if (!object(entry) || typeof entry.id !== "string" || !UUID.test(entry.id) || identities.has(entry.id.toLowerCase())) throw conflict();
    identities.add(entry.id.toLowerCase());
  }
  return inspection.config;
}
export function prepareProjectAssignment(source, { projectId, accountId, operationId } = {}) {
  const config = validatedSource(source);
  if (typeof projectId !== "string" || !UUID.test(projectId) || typeof operationId !== "string" || !UUID.test(operationId) ||
    accountId !== null && (typeof accountId !== "string" || !Object.hasOwn(config.accountRouting.accounts, accountId))) throw invalid();
  if (!source.catalog.entries.some(entry => entry.id === projectId)) throw conflict();
  const value = structuredClone(source.value), routing = value.accountRouting;
  const before = assignmentSummary(config, projectId);
  if (accountId === null) delete value.projectRoutes[projectId];
  else {
    const current = Object.hasOwn(value.projectRoutes, projectId) ? value.projectRoutes[projectId] : null;
    let alias = current !== null && Object.hasOwn(routing.routeAccounts, current) && routing.routeAccounts[current] === accountId
      ? current : Object.keys(routing.routeAccounts).sort().find(key => routing.routeAccounts[key] === accountId);
    if (alias === undefined) {
      alias = `assignment-${operationId.toLowerCase().replaceAll("-", "")}`;
      // Unresolved project labels reserve aliases too: creating that binding
      // would otherwise repair a different project's missing target implicitly.
      if (Object.hasOwn(routing.routeAccounts, alias) || Object.values(value.projectRoutes).includes(alias)) throw conflict();
      routing.routeAccounts[alias] = accountId;
    }
    value.projectRoutes[projectId] = alias;
  }
  const changed = !isDeepStrictEqual(value, source.value);
  const nextSource = changed ? JSON.stringify(value, null, 2) + "\n" : source.source;
  const candidate = inspectRouterConfigurationValue(value);
  if (candidate.setupState !== "ready" || candidate.config.schemaVersion !== 2) throw invalid();
  return { value, config: candidate.config, source: nextSource,
    configurationRevision: changed ? digest(nextSource) : source.configurationRevision,
    changed, operationId, projectId, before, after: assignmentSummary(candidate.config, projectId) };
}

const token = value => typeof value === "string" && /^[a-f0-9]{64}$/.test(value);
const exact = (value, fields) => object(value) && Object.keys(value).length === fields.length && fields.every(field=>Object.hasOwn(value,field));
const assignmentError = code => new RouterError(`ASSIGNMENT_${code}`);
const contextFor = (configPath, config) => ({configPath,codexHome:config.codexHome,providerId:config.providerId,listenPort:config.listenPort});
const contextValid = c => exact(c,["configPath","codexHome","providerId","listenPort"]) &&
  typeof c.configPath === "string" && isAbsolute(c.configPath) && typeof c.codexHome === "string" && isAbsolute(c.codexHome) &&
  typeof c.providerId === "string" && /^[a-zA-Z0-9_-]+$/.test(c.providerId) && Number.isInteger(c.listenPort) && c.listenPort>=1 && c.listenPort<=65535;
const sameFile = (a,b, contents = true) => ["dev","ino","uid","mode","nlink",...(contents ? ["size","mtimeMs","ctimeMs"] : [])].every(key=>a[key]===b[key]);
function validateRead(input) {
  if(!exact(input,["configPath","expectedContext","projectId","operationId"]) || typeof input.configPath!=="string" ||
    !isAbsolute(input.configPath) || resolve(input.configPath)!==input.configPath || !contextValid(input.expectedContext) ||
    input.expectedContext.configPath!==input.configPath || input.projectId!==null && (typeof input.projectId!=="string" || !UUID.test(input.projectId)) ||
    input.operationId!==null && (typeof input.operationId!=="string" || !UUID.test(input.operationId))) throw assignmentError("INVALID");
}
async function privateFile(path, fs = defaultFS, privateOnly = true) {
  const before=await fs.lstat(path);
  const safe=info=>info.isFile() && info.uid===process.getuid() && info.nlink===1 && !(info.mode & (privateOnly ? 0o077 : 0o022));
  if(!safe(before)) throw assignmentError("CONFLICT");
  const handle=await fs.open(path,constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const descriptor=await handle.stat();
    if(!safe(descriptor) || !sameFile(before,descriptor)) throw assignmentError("CONFLICT");
    const bytes=await handle.readFile(), after=await handle.stat();
    if(!sameFile(descriptor,after) || !sameFile(after,await fs.lstat(path)) || !(await fs.readFile(path)).equals(bytes) ||
      !sameFile(after,await handle.stat())) throw assignmentError("CONFLICT");
    return {bytes,info:after};
  } finally {await handle.close();}
}
async function healthySource(configPath, fs) {
  const source=await readRouterConfigurationSource(configPath,{fs});
  if(source.config.schemaVersion!==2 || source.setupState!=="ready") throw assignmentError("INVALID");
  return {...source,catalog:await inspectProjectCatalog(source.config.codexHome,source.config)};
}
function snapshotValid(running) {
  return object(running) && object(running.config) && running.config.schemaVersion===2 && object(running.config.accountRouting) &&
    token(running.configurationRevision) && token(running.configurationIdentity) && ["on","off"].includes(running.mode);
}
function checkStaticConfiguration(source, running) {
  const staticValue = cfg => {
    const {projectRoutes,accountRouting,...rest}=cfg;
    const {routeAccounts,...routing}=accountRouting;
    return {...rest,accountRouting:routing};
  };
  if(!isDeepStrictEqual(staticValue(source.config),staticValue(running.config)) ||
    Object.entries(running.config.accountRouting.routeAccounts).some(([alias,id])=>
      !Object.hasOwn(source.config.accountRouting.routeAccounts,alias) || source.config.accountRouting.routeAccounts[alias]!==id))
    throw assignmentError("CONFLICT");
}
async function emptyPort(port) {
  const server=net.createServer();
  await new Promise((resolvePort,reject)=>{
    server.once("error",()=>reject(assignmentError("CONFLICT")));
    server.listen({host:"127.0.0.1",port,exclusive:true},()=>server.close(error=>error ? reject(assignmentError("CONFLICT")) : resolvePort()));
  });
}
async function stoppedEvidence(configPath, source, fs) {
  const home=source.config.codexHome, homeInfo=await fs.lstat(home);
  if(!homeInfo.isDirectory() || homeInfo.uid!==process.getuid() || homeInfo.mode & 0o022 || await fs.realpath(home)!==home) throw assignmentError("CONFLICT");
  const providerPath=join(home,"config.toml"), provider=await privateFile(providerPath,fs,false);
  const compatible=inspectProviderConfiguration(provider.bytes.toString("utf8"),source.config);
  if(new URL(compatible.url).href.replace(/\/$/,"")!==source.config.upstreamBaseUrl) throw assignmentError("CONFLICT");
  const recordPath=join(dirname(configPath),"activation.json");
  let record=null, backup=null;
  try {record=await privateFile(recordPath,fs);} catch(error) {if(error.code!=="ENOENT") throw error;}
  if(record) {
    let value;try {value=JSON.parse(record.bytes);} catch {throw assignmentError("CONFLICT");}
    if(typeof value.backupFile!=="string" || !/^codex-config-[0-9a-f-]{36}\.toml$/.test(value.backupFile)) throw assignmentError("CONFLICT");
    backup=await privateFile(join(dirname(configPath),value.backupFile),fs);
  }
  const activation=await inspectActivation(configPath,{probeProxy:false});
  if(!isDeepStrictEqual(activation.context,contextFor(configPath,source.config)) || activation.status.state!=="direct" ||
    activation.status.recoveryRequired || !["none","restored"].includes(activation.recordPhase) ||
    Boolean(record)!==(activation.recordPhase!=="none")) throw assignmentError("CONFLICT");
  if(record) {
    const latest=await privateFile(recordPath,fs);
    if(!sameFile(record.info,latest.info) || !record.bytes.equals(latest.bytes)) throw assignmentError("CONFLICT");
  } else {
    try {await fs.lstat(recordPath);throw assignmentError("CONFLICT");} catch(error) {if(error.code!=="ENOENT") throw error;}
  }
  await emptyPort(source.config.listenPort);
  const latestHome=await fs.lstat(home);
  if(homeInfo.dev!==latestHome.dev || homeInfo.ino!==latestHome.ino || homeInfo.uid!==latestHome.uid || homeInfo.mode!==latestHome.mode) throw assignmentError("CONFLICT");
  return {provider,activation,record,backup,homeInfo};
}
function mapAssignmentError(error) {
  if(error.code === "EEXIST") return assignmentError("CONFLICT");
  if(error instanceof RouterError) {
    if(error.code.startsWith("ASSIGNMENT_")) return error;
    if(["CONFIG_INVALID","ACCOUNT_SETUP_INVALID","ACCOUNT_SETUP_REQUIRED"].includes(error.code)) return assignmentError("INVALID");
    if(["ACTIVATION_CONFLICT","CONFIG_UNSUPPORTED"].includes(error.code)) return assignmentError("CONFLICT");
  }
  return assignmentError("UNAVAILABLE");
}
const checkpointName = operationId => `assignment-checkpoint-${operationId.toLowerCase()}.json`;
const intentName = operationId => `assignment-intent-${operationId.toLowerCase()}.json`;
async function readIntent(input, source, fs = defaultFS) {
  if(input.operationId===null) return null;
  const directory=dirname(input.configPath), path=join(directory,intentName(input.operationId));
  let file;
  try {file=await privateFile(path,fs);} catch(error) {if(error.code==="ENOENT") return null;throw error;}
  let intent;
  try {intent=JSON.parse(file.bytes);} catch {throw assignmentError("CONFLICT");}
  if(!exact(intent,["schemaVersion","operationId","context","projectId","accountId","checkpointName","beforeRevision","beforeIdentity","candidateRevision","candidateIdentity"]) ||
    intent.schemaVersion!==1 || intent.operationId!==input.operationId || !isDeepStrictEqual(intent.context,input.expectedContext) ||
    !UUID.test(intent.projectId ?? "") || input.projectId!==null && intent.projectId!==input.projectId ||
    intent.accountId!==null && !UUID.test(intent.accountId ?? "") || intent.checkpointName!==checkpointName(input.operationId) ||
    ![intent.beforeRevision,intent.beforeIdentity,intent.candidateRevision,intent.candidateIdentity].every(token)) throw assignmentError("CONFLICT");
  const checkpoint=await privateFile(join(directory,intent.checkpointName),fs);
  if(digest(checkpoint.bytes)!==intent.beforeRevision) throw assignmentError("CONFLICT");
  const parsed=inspectRouterConfigurationValue(JSON.parse(new TextDecoder("utf-8",{fatal:true}).decode(checkpoint.bytes)));
  if(parsed.config.schemaVersion!==2 || parsed.setupState!=="ready" || !isDeepStrictEqual(contextFor(input.configPath,parsed.config),input.expectedContext)) throw assignmentError("CONFLICT");
  if(source && (source.directoryInfo.dev!==(await fs.lstat(directory)).dev || source.directoryInfo.ino!==(await fs.lstat(directory)).ino)) throw assignmentError("CONFLICT");
  return intent;
}
export async function readProjectAssignmentState(input, running) {
  validateRead(input);
  if(running!==undefined && !snapshotValid(running)) throw assignmentError("INVALID");
  const state={context:input.expectedContext,savedState:"unavailable",savedRevision:null,savedIdentity:null,savedFingerprint:null,catalogRevision:null,
    runningRevision:running?.configurationRevision ?? null,runningIdentity:running?.configurationIdentity ?? null,
    runningFingerprint:running ? configFingerprint(running.config) : null,mode:running?.mode ?? null,projectId:input.projectId,
    savedAssignment:null,runningAssignment:running && input.projectId!==null ? assignmentSummary(running.config,input.projectId) : null,intent:null,lastAttempt:null};
  try {
    const source=await healthySource(input.configPath,defaultFS);
    if(!isDeepStrictEqual(contextFor(input.configPath,source.config),input.expectedContext)) throw assignmentError("CONFLICT");
    const intent=await readIntent(input,source);
    // Read intent and selected summaries only in a single unchanged saved view.
    const after=await readRouterConfigurationSource(input.configPath);
    if(after.configurationRevision!==source.configurationRevision || after.configurationIdentity!==source.configurationIdentity || !sameFile(after.fileInfo,source.fileInfo)) throw assignmentError("CONFLICT");
    state.savedState="ready";state.savedRevision=source.configurationRevision;state.savedIdentity=source.configurationIdentity;
    state.savedFingerprint=configFingerprint(source.config);state.catalogRevision=source.catalog.state==="ready" ? source.catalog.revision : null;
    state.savedAssignment=input.projectId!==null ? assignmentSummary(source.config,input.projectId) : null;state.intent=intent;
  } catch(error) {
    state.savedState=["ASSIGNMENT_CONFLICT","ACTIVATION_CONFLICT","CONFIG_INVALID","ACCOUNT_SETUP_INVALID"].includes(error.code) ? "conflict" : "unavailable";
  }
  return state;
}

export async function commitProjectAssignment(input = {}, {running, publish, fs = defaultFS} = {}) {
  const live=running!==undefined;
  const fields=["configPath","expectedContext","expectedSavedRevision","expectedConfigurationIdentity","expectedCatalogRevision","operationId","projectId","accountId",...(live ? ["expectedRunningRevision"] : [])];
  if(!exact(input,fields) || typeof input.configPath!=="string" || !isAbsolute(input.configPath) || resolve(input.configPath)!==input.configPath ||
    !contextValid(input.expectedContext) || input.expectedContext.configPath!==input.configPath || ![input.expectedSavedRevision,input.expectedConfigurationIdentity,input.expectedCatalogRevision].every(token) ||
    typeof input.operationId!=="string" || !UUID.test(input.operationId) || typeof input.projectId!=="string" || !UUID.test(input.projectId) ||
    input.accountId!==null && (typeof input.accountId!=="string" || !UUID.test(input.accountId)) ||
    live && (!snapshotValid(running) || typeof publish!=="function" || !token(input.expectedRunningRevision)) || !live && publish!==undefined)
    throw assignmentError("INVALID");
  let replacementAttempted=false, replaced=false, publicationAttempted=false, initial;
  let tempPath, tempInfo, tempCreated=false, result, failure;
  const directory=dirname(input.configPath);
  try {
    result=await withConfigurationLock(input.configPath,async(_config,lease)=>{
      initial=await healthySource(input.configPath,fs);
      if(!isDeepStrictEqual(contextFor(input.configPath,initial.config),input.expectedContext) || initial.configurationRevision!==input.expectedSavedRevision ||
        initial.configurationIdentity!==input.expectedConfigurationIdentity || initial.catalog.state!=="ready" || initial.catalog.revision!==input.expectedCatalogRevision ||
        live && running.configurationRevision!==input.expectedRunningRevision) throw assignmentError("CONFLICT");
      if(live) checkStaticConfiguration(initial,running);
      for(const path of [join(directory,`.assignment-${input.operationId.toLowerCase()}.tmp`),join(directory,checkpointName(input.operationId)),join(directory,intentName(input.operationId))]) {
        try {await fs.lstat(path);throw assignmentError("CONFLICT");} catch(error) {if(error.code!=="ENOENT") throw error;}
      }
      const prepared=prepareProjectAssignment(initial,input);
      const evidence=live ? null : await stoppedEvidence(input.configPath,initial,fs);
      const fresh=async()=>{
        await lease.assertUnchanged();
        const current=await healthySource(input.configPath,fs);
        if(current.configurationRevision!==initial.configurationRevision || current.configurationIdentity!==initial.configurationIdentity ||
          !sameFile(current.fileInfo,initial.fileInfo) || current.catalog.state!=="ready" || current.catalog.revision!==input.expectedCatalogRevision)
          throw assignmentError("CONFLICT");
        if(!live) {
          const latest=await stoppedEvidence(input.configPath,current,fs);
          if(!sameFile(evidence.provider.info,latest.provider.info) || !evidence.provider.bytes.equals(latest.provider.bytes) ||
            !isDeepStrictEqual(evidence.activation,latest.activation) ||
            evidence.homeInfo.dev!==latest.homeInfo.dev || evidence.homeInfo.ino!==latest.homeInfo.ino ||
            ["record","backup"].some(key=>Boolean(evidence[key])!==Boolean(latest[key]) || evidence[key] &&
              (!sameFile(evidence[key].info,latest[key].info) || !evidence[key].bytes.equals(latest[key].bytes)))) throw assignmentError("CONFLICT");
        }
        await lease.assertUnchanged();
        // The port/provider inspection above awaits I/O. Recheck source bytes and
        // descriptor metadata as the final filesystem authority before rename.
        const final=await readRouterConfigurationSource(input.configPath,{fs});
        const catalog=await inspectProjectCatalog(final.config.codexHome,final.config);
        if(final.configurationRevision!==initial.configurationRevision || final.configurationIdentity!==initial.configurationIdentity ||
          !sameFile(final.fileInfo,initial.fileInfo) || catalog.state!=="ready" || catalog.revision!==input.expectedCatalogRevision) throw assignmentError("CONFLICT");
        await lease.assertUnchanged();
      };
      const commit={context:input.expectedContext,operationId:input.operationId,projectId:input.projectId,changed:prepared.changed,
        beforeRevision:initial.configurationRevision,candidateRevision:prepared.configurationRevision,savedRevision:prepared.configurationRevision,
        beforeIdentity:initial.configurationIdentity,candidateIdentity:initial.configurationIdentity,savedIdentity:initial.configurationIdentity,
        before:prepared.before,after:prepared.after,checkpointPath:null,intent:null,runningRevision:null,runningIdentity:null,runningFingerprint:null};
      if(prepared.changed) {
        tempPath=join(directory,`.assignment-${input.operationId.toLowerCase()}.tmp`);
        const handle=await fs.open(tempPath,"wx",initial.fileInfo.mode & 0o777);tempCreated=true;
        tempInfo=await handle.stat();
        try {await handle.writeFile(prepared.source);await handle.sync();tempInfo=await handle.stat();} finally {await handle.close();}
        const candidate=await readRouterConfigurationSource(tempPath,{fs});
        if(candidate.configurationRevision!==prepared.configurationRevision || !isDeepStrictEqual(candidate.config,prepared.config)) throw assignmentError("CONFLICT");
        commit.candidateIdentity=configurationIdentityFor(input.configPath,prepared.config,initial.directoryInfo,candidate.fileInfo);
        commit.savedIdentity=commit.candidateIdentity;
        commit.checkpointPath=join(directory,checkpointName(input.operationId));
        const writeExclusive=async(path,bytes)=>{
          const file=await fs.open(path,"wx",0o600);
          try {await file.writeFile(bytes);await file.sync();return await file.stat();} finally {await file.close();}
        };
        const checkpointInfo=await writeExclusive(commit.checkpointPath,Buffer.from(initial.source));
        commit.intent={schemaVersion:1,operationId:input.operationId,context:input.expectedContext,projectId:input.projectId,accountId:input.accountId,
          checkpointName:checkpointName(input.operationId),beforeRevision:initial.configurationRevision,beforeIdentity:initial.configurationIdentity,
          candidateRevision:prepared.configurationRevision,candidateIdentity:commit.candidateIdentity};
        const intentPath=join(directory,intentName(input.operationId));
        const intentInfo=await writeExclusive(intentPath,JSON.stringify(commit.intent)+"\n");
        const syncDirectory=async()=>{const dir=await fs.open(directory,"r");try {await dir.sync();} finally {await dir.close();}};
        await syncDirectory();
        const candidateNow=await privateFile(tempPath,fs);
        if(!sameFile(candidateNow.info,tempInfo) || !candidateNow.bytes.equals(Buffer.from(prepared.source))) throw assignmentError("CONFLICT");
        const checkpointNow=await privateFile(commit.checkpointPath,fs), intentNow=await privateFile(intentPath,fs);
        if(!sameFile(checkpointInfo,checkpointNow.info) || !checkpointNow.bytes.equals(Buffer.from(initial.source)) ||
          !sameFile(intentInfo,intentNow.info) || !intentNow.bytes.equals(Buffer.from(JSON.stringify(commit.intent)+"\n"))) throw assignmentError("CONFLICT");
        await fresh();
        replacementAttempted=true;
        await fs.rename(tempPath,input.configPath);replaced=true;tempCreated=false;
        await syncDirectory();
        const persisted=await readRouterConfigurationSource(input.configPath,{fs});
        if(persisted.configurationRevision!==commit.savedRevision || persisted.configurationIdentity!==commit.savedIdentity) throw assignmentError("UNCERTAIN");
      } else await fresh();
      if(live) {
        publicationAttempted=true;
        const next=Object.freeze({config:prepared.config,configurationRevision:commit.savedRevision,configurationIdentity:commit.savedIdentity,mode:running.mode});
        const publication=publish(next);
        if(publication!==undefined && publication!==null && typeof publication.then==="function") {
          // A broken synchronous publisher is already reported as uncertain.
          // Observe rejection without waiting or exposing its exception payload.
          Promise.resolve(publication).catch(()=>{});
          throw assignmentError("UNCERTAIN");
        }
        commit.runningRevision=commit.savedRevision;commit.runningIdentity=commit.savedIdentity;commit.runningFingerprint=configFingerprint(prepared.config);
      }
      return commit;
    },{fs});
  } catch(error) {failure=error;}
  // Cleanup cannot remove evidence in a replaced directory or another owner's inode.
  if(tempCreated) {
    try {
      const parent=await fs.lstat(directory);
      if(!initial || parent.dev!==initial.directoryInfo.dev || parent.ino!==initial.directoryInfo.ino) throw assignmentError("CONFLICT");
      const current=await fs.lstat(tempPath);
      if(!sameFile(tempInfo,current,false)) throw assignmentError("CONFLICT");
      await fs.unlink(tempPath);
    } catch(error) {failure=error;}
  }
  if(failure) {
    if(replaced || publicationAttempted) throw assignmentError("UNCERTAIN");
    if(replacementAttempted) {
      try {
        const current=await readRouterConfigurationSource(input.configPath,{fs});
        if(current.configurationRevision!==initial.configurationRevision || current.configurationIdentity!==initial.configurationIdentity || !sameFile(current.fileInfo,initial.fileInfo)) throw assignmentError("UNCERTAIN");
      } catch {throw assignmentError("UNCERTAIN");}
    }
    throw mapAssignmentError(failure);
  }
  return result;
}
