import { readFile, writeFile, open, lstat, rename, unlink, realpath } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { randomUUID, createHash } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import http from 'node:http';
import { parse } from 'smol-toml';
import { loadRouterConfig, configFingerprint } from './config.js';
import { RouterError } from './errors.js';
const digest=text=>createHash('sha256').update(text).digest('hex');
const proxyUrl=cfg=>`http://127.0.0.1:${cfg.listenPort}/v1`;
const normalize=url=>new URL(url).href.replace(/\/$/,'');
async function privateDirectory(path) {
  const info=await lstat(path);
  if(!info.isDirectory()||info.uid!==process.getuid()||(info.mode&0o077))throw new RouterError('STORAGE_FAILED');
}
async function ownedFile(path) {
  const info=await lstat(path);
  if(!info.isFile()||info.uid!==process.getuid())throw new RouterError('ACTIVATION_CONFLICT');
  return {text:await readFile(path,'utf8'),mode:info.mode&0o777};
}
function provider(source,cfg) {
  try {
    const data=parse(source),p=data.model_providers?.[cfg.providerId];
    if(data.model_provider!==cfg.providerId||data.profile!==undefined||data.config_server!==undefined||!p||p.wire_api!=='responses'||p.supports_websockets!==false||p.requires_openai_auth===true||typeof p.auth?.command!=='string'||!p.auth.command||p.env_key!==undefined||p.env_http_headers!==undefined||p.http_headers!==undefined||typeof p.base_url!=='string')throw new Error();
    const header=new RegExp('^[ \\t]*\\[model_providers\\.'+cfg.providerId+'\\][ \\t]*(?:#.*)?$','m');
    const match=header.exec(source);if(!match)throw new Error();
    const start=match.index+match[0].length,rest=source.slice(start),next=/^[ \t]*\[/m.exec(rest),section=rest.slice(0,next?.index??rest.length);
    const matches=[...section.matchAll(/^[ \t]*base_url[ \t]*=[ \t]*("(?:[^"\\\r\n]|\\.)*")[ \t]*(?:#.*)?$/gm)];
    if(matches.length!==1)throw new Error();
    const line=matches[0],literal=line[1],offset=start+line.index+line[0].indexOf(literal);
    if(parse('value = '+literal).value!==p.base_url)throw new Error();
    return {data,url:p.base_url,offset,length:literal.length};
  }catch{throw new RouterError('CONFIG_UNSUPPORTED');}
}
function replacement(source,cfg,expectedUrl,newUrl) {
  const current=provider(source,cfg);if(current.url!==expectedUrl)throw new RouterError('ACTIVATION_CONFLICT');
  const updated=source.slice(0,current.offset)+JSON.stringify(newUrl)+source.slice(current.offset+current.length);
  current.data.model_providers[cfg.providerId].base_url=newUrl;
  if(!isDeepStrictEqual(parse(updated),current.data))throw new RouterError('CONFIG_UNSUPPORTED');
  return updated;
}
async function atomicWrite(path,text,mode,expected) {
  const temp=path+'.'+randomUUID()+'.tmp';let created=false;
  try {
    const handle=await open(temp,'wx',mode);created=true;
    try {await handle.writeFile(text);await handle.sync();}finally{await handle.close();}
    let actual=null;
    try{actual=(await ownedFile(path)).text;}catch(e){if(e.code!=='ENOENT')throw e;}
    if(actual!==expected)throw new RouterError('ACTIVATION_CONFLICT');
    await rename(temp,path);created=false;
  }finally{if(created)await unlink(temp);}
}
async function readRecord(path,context) {
  let text;
  try{const file=await ownedFile(path);if(file.mode&0o077)throw new Error();text=file.text;}
  catch(e){if(e.code==='ENOENT')return null;throw new RouterError('ACTIVATION_CONFLICT');}
  try{
    const r=JSON.parse(text);
    if(r.schemaVersion!==1||r.routerConfigPath!==context.configPath||r.codexConfigPath!==context.codexPath||r.providerId!==context.cfg.providerId||r.proxyBaseUrl!==proxyUrl(context.cfg)||!['prepared','active','restored'].includes(r.phase)||typeof r.backupFile!=='string'||!/^codex-config-[0-9a-f-]{36}\.toml$/.test(r.backupFile)||!/^https:\/\//.test(r.originalBaseUrl)||typeof r.backupHash!=='string')throw new Error();
    const backup=await ownedFile(join(context.dir,r.backupFile));
    if((backup.mode&0o077)||digest(backup.text)!==r.backupHash||provider(backup.text,context.cfg).url!==r.originalBaseUrl)throw new Error();
    return {record:r,text};
  }catch{throw new RouterError('ACTIVATION_CONFLICT');}
}
async function context(configPath) {
  const cfg=await loadRouterConfig(configPath),path=await realpath(configPath),dir=dirname(path);
  await privateDirectory(dir);
  return {cfg,configPath:path,dir,codexPath:join(cfg.codexHome,'config.toml'),recordPath:join(dir,'activation.json')};
}
function ready(cfg) {
  return new Promise((resolve,reject)=>{
    const fail=()=>reject(new RouterError('PROXY_NOT_READY'));
    const request=http.get({host:'127.0.0.1',port:cfg.listenPort,path:'/healthz',timeout:1000},res=>{
      let body='',bytes=0;res.on('error',fail);
      res.on('data',chunk=>{bytes+=chunk.length;if(bytes>4096){request.destroy();fail();}else body+=chunk;});
      res.on('end',()=>{try{const h=JSON.parse(body);if(res.statusCode!==200||h.service!=='codex-project-router'||h.schemaVersion!==1||h.configFingerprint!==configFingerprint(cfg))throw new Error();resolve();}catch{fail();}});
    });request.on('timeout',()=>{request.destroy();fail();});request.on('error',fail);
  });
}
async function locked(c,fn) {
  const path=join(c.dir,'.activation.lock');let handle;
  try{handle=await open(path,'wx',0o600);}catch(e){throw new RouterError(e.code==='EEXIST'?'ACTIVATION_CONFLICT':'STORAGE_FAILED');}
  try{await handle.writeFile(JSON.stringify({pid:process.pid}));return await fn();}
  finally{await handle.close();await unlink(path);}
}
async function operation(configPath,fn) {
  try{const c=await context(configPath);return await locked(c,()=>fn(c));}
  catch(e){throw e instanceof RouterError?e:new RouterError('STORAGE_FAILED');}
}
export async function activate(configPath) {
  return operation(configPath,async(c)=>{
    const file=await ownedFile(c.codexPath),p=provider(file.text,c.cfg),existing=await readRecord(c.recordPath,c);
    await ready(c.cfg);
    if(existing&&existing.record.phase!=='restored'){
      if(p.url!==existing.record.proxyBaseUrl||normalize(existing.record.originalBaseUrl)!==c.cfg.upstreamBaseUrl)throw new RouterError('ACTIVATION_CONFLICT');
      if(existing.record.phase==='prepared')await atomicWrite(c.recordPath,JSON.stringify({...existing.record,phase:'active'})+'\n',0o600,existing.text);
      return {state:'active',changed:false,restartRequired:true};
    }
    if(normalize(p.url)!==c.cfg.upstreamBaseUrl)throw new RouterError('ACTIVATION_CONFLICT');
    const backupFile='codex-config-'+randomUUID()+'.toml';
    await writeFile(join(c.dir,backupFile),file.text,{flag:'wx',mode:0o600});
    const record={schemaVersion:1,routerConfigPath:c.configPath,codexConfigPath:c.codexPath,providerId:c.cfg.providerId,originalBaseUrl:p.url,proxyBaseUrl:proxyUrl(c.cfg),backupFile,backupHash:digest(file.text),phase:'prepared'};
    const prepared=JSON.stringify(record)+'\n';
    await atomicWrite(c.recordPath,prepared,0o600,existing?.text??null);
    await atomicWrite(c.codexPath,replacement(file.text,c.cfg,p.url,record.proxyBaseUrl),file.mode,file.text);
    await atomicWrite(c.recordPath,JSON.stringify({...record,phase:'active'})+'\n',0o600,prepared);
    return {state:'active',changed:true,restartRequired:true};
  });
}
export async function rollback(configPath) {
  return operation(configPath,async(c)=>{
    const file=await ownedFile(c.codexPath),p=provider(file.text,c.cfg),existing=await readRecord(c.recordPath,c);
    if(!existing){if(normalize(p.url)!==c.cfg.upstreamBaseUrl)throw new RouterError('ACTIVATION_CONFLICT');return {state:'direct',changed:false,restartRequired:false};}
    const r=existing.record;
    if(p.url!==r.originalBaseUrl&&p.url!==r.proxyBaseUrl)throw new RouterError('ACTIVATION_CONFLICT');
    const changed=p.url!==r.originalBaseUrl;
    if(changed)await atomicWrite(c.codexPath,replacement(file.text,c.cfg,r.proxyBaseUrl,r.originalBaseUrl),file.mode,file.text);
    if(r.phase!=='restored')await atomicWrite(c.recordPath,JSON.stringify({...r,phase:'restored'})+'\n',0o600,existing.text);
    return {state:'direct',changed,restartRequired:changed};
  });
}
export async function status(configPath) {
  try{
    const c=await context(configPath),file=await ownedFile(c.codexPath),p=provider(file.text,c.cfg),existing=await readRecord(c.recordPath,c);
    let proxyReady=true;try{await ready(c.cfg);}catch(e){if(e.code!=='PROXY_NOT_READY')throw e;proxyReady=false;}
    const state=existing&&p.url===existing.record.proxyBaseUrl?'active':p.url===(existing?.record.originalBaseUrl??c.cfg.upstreamBaseUrl)?'direct':'conflict';
    return {state,proxyReady,recoveryRequired:existing?.record.phase==='prepared'};
  }catch(e){throw e instanceof RouterError?e:new RouterError('STORAGE_FAILED');}
}
