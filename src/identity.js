import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { setTimeout as delay } from 'node:timers/promises';
import { UUID } from './config.js';
import { RouterError } from './errors.js';
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
function identity(raw) {
  if (!Array.isArray(raw) || raw.length % 2) throw new RouterError('IDENTITY_INVALID');
  const fields = new Map();
  for (let i=0; i<raw.length; i+=2) {
    const key = String(raw[i]).toLowerCase();
    if (!['thread-id','session-id','x-codex-turn-metadata'].includes(key)) continue;
    if (fields.has(key) || typeof raw[i+1] !== 'string') throw new RouterError('IDENTITY_INVALID');
    fields.set(key,raw[i+1]);
  }
  let meta = {};
  if (fields.has('x-codex-turn-metadata')) {
    try { meta = JSON.parse(fields.get('x-codex-turn-metadata')); } catch { throw new RouterError('IDENTITY_INVALID'); }
    if (!object(meta)) throw new RouterError('IDENTITY_INVALID');
  }
  const id = value => { if (value === undefined || value === null) return undefined; if (typeof value !== 'string' || !UUID.test(value)) throw new RouterError('IDENTITY_INVALID'); return value.toLowerCase(); };
  const agree = values => { const present = values.map(id).filter(Boolean); if (new Set(present).size > 1) throw new RouterError('IDENTITY_CONFLICT'); return present[0]; };
  const thread = agree([fields.get('thread-id'),meta.thread_id]);
  const session = agree([fields.get('session-id'),meta.session_id]);
  if (!thread && !session) throw new RouterError('IDENTITY_INVALID');
  return { threadId: thread ?? session, sessionId: session, parentId: id(meta.parent_thread_id) };
}
async function resolveOnce(ids, config) {
  let db;
  try {
    const state = JSON.parse(await readFile(join(config.codexHome,'.codex-global-state.json'),'utf8'));
    const assignments = state['thread-project-assignments'], projects = state['local-projects'], projectless = state['projectless-thread-ids'];
    if (!object(assignments) || !object(projects) || !Array.isArray(projectless)) throw new RouterError('STATE_UNAVAILABLE');
    db = new DatabaseSync(join(config.codexHome,'state_5.sqlite'),{readOnly:true});
    const parent = db.prepare('SELECT parent_thread_id FROM thread_spawn_edges WHERE child_thread_id = ?');
    const seen = new Set(), memberships = [];
    let current = ids.threadId;
    for (let depth=0; current; depth++) {
      if (depth >= 32 || seen.has(current)) throw new RouterError('IDENTITY_CONFLICT');
      seen.add(current);
      const assignment = assignments[current];
      if (projectless.includes(current)) throw new RouterError(assignment ? 'IDENTITY_CONFLICT' : 'PROJECT_UNRESOLVED');
      if (assignment !== undefined) {
        if (!object(assignment) || assignment.projectKind !== 'local' || typeof assignment.projectId !== 'string' || !UUID.test(assignment.projectId) || !object(projects[assignment.projectId])) throw new RouterError('PROJECT_UNRESOLVED');
        memberships.push({ownerThreadId:current,projectId:assignment.projectId});
      }
      const parents = parent.all(current);
      if (parents.length > 1) throw new RouterError('IDENTITY_CONFLICT');
      const next = parents[0]?.parent_thread_id;
      if (next !== undefined && (typeof next !== 'string' || !UUID.test(next))) throw new RouterError('STATE_UNAVAILABLE');
      if (depth === 0 && ids.parentId && ids.parentId !== next?.toLowerCase()) throw new RouterError('STATE_UNAVAILABLE');
      current = next?.toLowerCase();
    }
    if (ids.sessionId && !seen.has(ids.sessionId)) throw new RouterError('IDENTITY_CONFLICT');
    if (!memberships.length) throw new RouterError('STATE_UNAVAILABLE');
    if (new Set(memberships.map(m => m.projectId)).size > 1) throw new RouterError('IDENTITY_CONFLICT');
    const {ownerThreadId,projectId} = memberships[0], routeAlias = config.projectRoutes[projectId];
    if (!routeAlias) throw new RouterError('ROUTE_UNMAPPED');
    return Object.freeze({threadId:ids.threadId,ownerThreadId,projectId,routeAlias,source:ownerThreadId === ids.threadId ? 'direct' : 'ancestor'});
  } catch (e) { throw e instanceof RouterError ? e : new RouterError('STATE_UNAVAILABLE'); }
  finally { db?.close(); }
}
export async function identifyProject(rawHeaders, config, {signal} = {}) {
  if (signal?.aborted) throw new RouterError('CANCELLED');
  const ids = identity(rawHeaders), deadline = Date.now()+1000;
  for (;;) {
    if (signal?.aborted) throw new RouterError('CANCELLED');
    try { return await resolveOnce(ids,config); }
    catch(e) {
      if (!(e instanceof RouterError) || e.code !== 'STATE_UNAVAILABLE' || Date.now() >= deadline) throw e;
      try { await delay(Math.min(50,deadline-Date.now()),undefined,{signal}); } catch { throw new RouterError('CANCELLED'); }
    }
  }
}
