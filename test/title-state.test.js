import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { readFile, writeFile, rename, unlink } from "node:fs/promises";
import { syncBuiltinESMExports } from "node:module";
import { DatabaseSync } from "node:sqlite";
import { proveUnassignedTitle } from "../src/title-state.js";
import { fixture, CHILD, T1 } from "./helpers/fixtures.js";

const options = () => ({deadline:Date.now()+1000});
const unavailable = e => e.code === "STATE_UNAVAILABLE" && !e.message.includes("SENTINEL");
function editDatabase(f, sql) {
  const db=new DatabaseSync(f.dbPath);
  try {db.exec(sql);} finally {db.close();}
}
function onStateRead(t, f, handler) {
  const original=fs.promises.readFile;
  let count=0;
  const mock=t.mock.method(fs.promises,"readFile",async (path,...args) => {
    if (path === f.statePath) await handler(++count);
    return original(path,...args);
  });
  syncBuiltinESMExports();
  t.after(() => {mock.mock.restore();syncBuiltinESMExports();});
}
test("healthy absence is read-only and requires no saved identity", async t => {
  const f=await fixture(t), before=await f.snapshot();
  assert.equal(await proveUnassignedTitle(CHILD,f.config,options()),true);
  assert.deepEqual(await f.snapshot(),before);
});
for (const [name,setup] of [
  ["malformed assignment", async f => {f.state["thread-project-assignments"][CHILD]=null;await f.saveState();}],
  ["case-equivalent assignment", async f => {f.state["thread-project-assignments"][CHILD.toUpperCase()]={};await f.saveState();}],
  ["projectless", async f => {f.state["projectless-thread-ids"].push(CHILD.toUpperCase());await f.saveState();}],
  ["saved thread", async f => f.thread(CHILD.toUpperCase())],
  ["incoming edge", async f => f.edge(T1,CHILD.toUpperCase())],
  ["outgoing edge", async f => f.edge(CHILD.toUpperCase(),T1)],
]) test(`known ${name} cannot be admitted as unassigned`,async t => {
  const f=await fixture(t);await setup(f);
  assert.equal(await proveUnassignedTitle(CHILD,f.config,options()),false);
});
for (const [name,setup] of [
  ["missing JSON", f => unlink(f.statePath)],
  ["partial JSON", f => writeFile(f.statePath,"{SECRET_SENTINEL")],
  ["unsupported assignments", async f => {f.state["thread-project-assignments"]=[];await f.saveState();}],
  ["unsupported catalog", async f => {f.state["local-projects"]=null;await f.saveState();}],
  ["missing projectless list", async f => {delete f.state["projectless-thread-ids"];await f.saveState();}],
  ["invalid projectless entry", async f => {f.state["projectless-thread-ids"]=[null];await f.saveState();}],
  ["missing database", f => unlink(f.dbPath)],
  ["missing threads", f => editDatabase(f,"DROP TABLE threads")],
  ["missing edge table", f => editDatabase(f,"DROP TABLE thread_spawn_edges")],
  ["missing thread column", f => editDatabase(f,"DROP TABLE threads;CREATE TABLE threads(other TEXT)")],
]) test(`${name} is not proof of absence`,async t => {
  const f=await fixture(t);await setup(f);
  await assert.rejects(proveUnassignedTitle(CHILD,f.config,options()),unavailable);
});
test("locked SQLite does not grant an exception or retain a lock",async t => {
  const f=await fixture(t), writer=new DatabaseSync(f.dbPath);
  writer.exec("BEGIN EXCLUSIVE");
  try {await assert.rejects(proveUnassignedTitle(CHILD,f.config,options()),unavailable);}
  finally {writer.exec("ROLLBACK");writer.close();}
  assert.equal(await proveUnassignedTitle(CHILD,f.config,options()),true);
});
for (const kind of ["failed final read","JSON mutation","JSON replacement","SQLite mutation","SQLite replacement"]) {
  test(`${kind} invalidates an earlier healthy absence`,async t => {
    const f=await fixture(t);
    onStateRead(t,f,async n => {
      if(n!==2)return;
      if(kind === "failed final read") throw new Error("SECRET_SENTINEL");
      if(kind === "JSON mutation") {f.state["thread-project-assignments"][CHILD]={};await f.saveState();}
      if(kind === "JSON replacement") {await writeFile(f.statePath+".new",JSON.stringify(f.state));await rename(f.statePath+".new",f.statePath);}
      if(kind === "SQLite mutation") f.thread(T1);
      if(kind === "SQLite replacement") {await writeFile(f.dbPath+".new",await readFile(f.dbPath));await rename(f.dbPath+".new",f.dbPath);}
    });
    await assert.rejects(proveUnassignedTitle(CHILD,f.config,options()),unavailable);
  });
}
test("WAL commits are detected even when the main SQLite file is unchanged",async t => {
  const f=await fixture(t), writer=new DatabaseSync(f.dbPath);
  writer.exec("PRAGMA journal_mode=WAL");
  t.after(()=>writer.close());
  onStateRead(t,f,async n => {if(n===2)writer.prepare("INSERT INTO threads VALUES(?)").run(T1);});
  await assert.rejects(proveUnassignedTitle(CHILD,f.config,options()),unavailable);
});
test("expired and cancelled proofs cannot authorize forwarding",async t => {
  const f=await fixture(t);
  await assert.rejects(proveUnassignedTitle(CHILD,f.config,{deadline:Date.now()-1}),unavailable);
  await assert.rejects(proveUnassignedTitle(CHILD,f.config,{...options(),signal:AbortSignal.abort()}),{code:"CANCELLED"});
  const controller=new AbortController();
  onStateRead(t,f,async n => {if(n===2)controller.abort();});
  await assert.rejects(proveUnassignedTitle(CHILD,f.config,{...options(),signal:controller.signal}),{code:"CANCELLED"});
});
