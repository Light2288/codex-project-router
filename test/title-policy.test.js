import test from "node:test";
import assert from "node:assert/strict";
import { matchUnassignedTitle } from "../src/title-policy.js";
import { headers, CHILD, T1 } from "./helpers/fixtures.js";

const metadata = () => ({thread_source:"thread_title",turn_trigger:"thread_title",thread_id:CHILD,session_id:CHILD});
const raw = (meta = metadata()) => headers(CHILD,meta);
const withText = (text) => ["thread-id",CHILD,"session-id",CHILD,"x-codex-turn-metadata",text];

test("accepts only matching singleton title claims and normalizes UUID casing", () => {
  assert.equal(matchUnassignedTitle(raw()), CHILD);
  assert.equal(matchUnassignedTitle(raw().map((s,i) => i % 2 === 0 ? s.toUpperCase() : s.replaceAll(CHILD,CHILD.toUpperCase()))), CHILD);
  assert.equal(matchUnassignedTitle(raw({...metadata(),unknown:{prompt:"SECRET_SENTINEL"},request_kind:{anything:true}})), CHILD);
  assert.equal(matchUnassignedTitle(withText(JSON.stringify({...metadata(),nested:{thread_id:T1},text:'{"thread_id":"x"} [ ] \\"'}))),CHILD);
});
for (const member of ["thread_source","turn_trigger","thread_id","session_id"]) {
  test(`requires a valid singleton ${member}`, () => {
    for (const value of [null,0,true,[],{},"", "SECRET_SENTINEL"]) {
      const m={...metadata(),[member]:value};
      assert.equal(matchUnassignedTitle(withText(JSON.stringify(m))),undefined);
    }
    const m=metadata(); delete m[member];
    assert.equal(matchUnassignedTitle(withText(JSON.stringify(m))),undefined);
  });
}
for (const name of ["thread-id","session-id","x-codex-turn-metadata"]) {
  test(`requires exactly one ${name} header`, () => {
    assert.equal(matchUnassignedTitle([...raw(),name,raw()[raw().indexOf(name)+1]]),undefined);
    const missing=raw(); missing.splice(missing.indexOf(name),2);
    assert.equal(matchUnassignedTitle(missing),undefined);
  });
}
test("rejects inconsistent header/metadata identifiers and noninitial features", () => {
  for (const key of ["thread_id","session_id"])
    assert.equal(matchUnassignedTitle(raw({...metadata(),[key]:T1})),undefined);
  for (const key of ["thread_source","turn_trigger"])
    for (const label of ["thread_title_reconsideration","user","other","THREAD_TITLE","thread_title "])
      assert.equal(matchUnassignedTitle(raw({...metadata(),[key]:label})),undefined);
  const h=raw();h[1]=T1;
  assert.equal(matchUnassignedTitle(h),undefined);
});
for (const key of ["parent_thread_id","forked_from_thread_id"]) {
  test(`requires actual absence of ${key}`, () => {
    for (const value of [null,"",T1,0,[],{},"SECRET_SENTINEL"])
      assert.equal(matchUnassignedTitle(raw({...metadata(),[key]:value})),undefined);
  });
}
test("any parent header occurrence disqualifies, including empty and duplicate values", () => {
  for (const value of ["",T1,"SECRET_SENTINEL"])
    assert.equal(matchUnassignedTitle([...raw(),"X-Codex-Parent-Thread-Id",value]),undefined);
  assert.equal(matchUnassignedTitle([...raw(),"x-codex-parent-thread-id",T1,"X-Codex-Parent-Thread-Id",T1]),undefined);
});
for (const key of ["thread_source","turn_trigger","request_kind","thread_id","session_id","parent_thread_id","forked_from_thread_id"]) {
  test(`never picks an occurrence of duplicate ${key}, including escaped spellings`, () => {
    const value=metadata()[key]??"thread_title";
    for (const duplicate of [value,T1]) for (const escaped of [false,true]) {
      const spelling=escaped ? "\\u"+key.charCodeAt(0).toString(16).padStart(4,"0")+key.slice(1) : key;
      const text=JSON.stringify({...metadata(),[key]:value}).slice(0,-1)+',"'+spelling+'":'+JSON.stringify(duplicate)+'}';
      assert.equal(matchUnassignedTitle(withText(text)),undefined);
    }
  });
}
test("malformed, unsupported and throwing inputs fail closed without input leakage", () => {
  for (const input of [undefined,{},[],["odd"], ["thread-id",null],new Proxy([], {get(){throw new Error("SECRET_SENTINEL");}})])
    assert.equal(matchUnassignedTitle(input),undefined);
  for (const text of ["{SECRET_SENTINEL", "null","[]","true","1", '"thread_title"',JSON.stringify({nested:metadata()})])
    assert.equal(matchUnassignedTitle(withText(text)),undefined);
});
