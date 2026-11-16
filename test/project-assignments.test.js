import test from "node:test";
import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { inspectRouterConfiguration } from "../src/config.js";
import { inspectProjectCatalog } from "../src/project-catalog.js";
import { prepareProjectAssignment } from "../src/project-assignments.js";
import { fixture, P1, P2, A1, A2, accountRouting } from "./helpers/fixtures.js";

const P3 = "33333333-3333-4333-8333-333333333333";
const OP = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const NEW_ALIAS = "assignment-aaaaaaaabbbb4ccc8dddeeeeeeeeeeee";
const digest = source => createHash("sha256").update(source).digest("hex");
const change = (accountId, projectId = P1) => ({ projectId, accountId, operationId: OP });
async function setup(t) {
  const f = await fixture(t);
  f.config.schemaVersion = 2;
  f.config.accountRouting = accountRouting();
  f.state["local-projects"][P1].name = "Alpha";
  f.state["local-projects"][P2].name = "Beta";
  await f.saveState();
  const source = async () => {
    await f.saveConfig();
    const bytes = await readFile(f.configPath, "utf8");
    const inspection = await inspectRouterConfiguration(f.configPath);
    return { value: JSON.parse(bytes), config: inspection.config, source: bytes,
      configurationRevision: inspection.configurationRevision,
      catalog: await inspectProjectCatalog(f.dir, inspection.config) };
  };
  return { ...f, source };
}

// A broad configuration reconstruction would lose raw values or optional-property presence.
test("assign switch and inherit preserve exact unrelated data", async t => {
  for (const present of [false, true]) await t.test(`optional property present ${present}`, async t => {
    const f = await setup(t);
    if (present) { f.config.allowUnassignedThreadTitles = false; f.config.observeRequestMetadata = true; }
    f.config.upstreamBaseUrl = "https://GATEWAY.example.invalid:443/api/./v1/";
    f.config.accountRouting.accounts[A1].upstreamBaseUrl = "https://DEFAULT.example.invalid:443/api/./region/v1/";
    const s = await f.source(), before = structuredClone(s.value);
    const assigned = prepareProjectAssignment(s, change(A1));
    assert.equal(assigned.changed, true);
    assert.equal(assigned.operationId, OP);
    assert.equal(assigned.projectId, P1);
    assert.deepEqual(assigned.before, { kind: "override", account: { id: A2, displayName: "Project account" }, routeAlias: "route-a" });
    assert.deepEqual(assigned.after, { kind: "override", account: { id: A1, displayName: "Default account" }, routeAlias: NEW_ALIAS });
    assert.equal(assigned.value.projectRoutes[P1], NEW_ALIAS);
    assert.equal(assigned.value.accountRouting.routeAccounts[NEW_ALIAS], A1);
    assert.deepEqual(assigned.value.projectRoutes[P2], before.projectRoutes[P2]);
    assert.deepEqual(assigned.value.accountRouting.accounts, before.accountRouting.accounts);
    assert.deepEqual(assigned.value.accountRouting.incomingCredential, before.accountRouting.incomingCredential);
    assert.equal(Object.hasOwn(assigned.value, "allowUnassignedThreadTitles"), present);
    const expected = structuredClone(before);
    expected.projectRoutes[P1] = NEW_ALIAS; expected.accountRouting.routeAccounts[NEW_ALIAS] = A1;
    assert.deepEqual(assigned.value, expected);
    assert.equal(assigned.configurationRevision, digest(assigned.source));
    assert.deepEqual(JSON.parse(assigned.source), expected);
    assert.ok(Object.isFrozen(assigned.config.accountRouting.accounts[A1]));
    const removed = prepareProjectAssignment({ ...assigned, catalog: await inspectProjectCatalog(f.dir, assigned.config) }, change(null));
    assert.equal(Object.hasOwn(removed.value.projectRoutes, P1), false);
    assert.deepEqual(removed.value.accountRouting, assigned.value.accountRouting);
    assert.deepEqual(removed.after, { kind: "inherited", account: { id: A1, displayName: "Default account" } });
    assert.deepEqual(s.value, before);
    assert.deepEqual(await readFile(f.configPath, "utf8"), s.source);
  });
});

// Retargeting even an exclusive current binding would break retained runtime snapshots.
test("shared alias never retargets", async t => {
  const f = await setup(t);
  f.config.projectRoutes[P2] = "route-a";
  const s = await f.source(), before = structuredClone(s.value);
  const assigned = prepareProjectAssignment(s, change(A1));
  assert.equal(assigned.value.projectRoutes[P2], "route-a");
  assert.equal(assigned.value.accountRouting.routeAccounts["route-a"], A2);
  assert.equal(assigned.value.projectRoutes[P1], NEW_ALIAS);
  assert.deepEqual(assigned.value.accountRouting.accounts, before.accountRouting.accounts);
  assert.deepEqual(prepareProjectAssignment(s, change(null)).value.accountRouting, before.accountRouting);
});

// Allocating an alias already used by an unresolved mapping would silently repair another project.
test("new alias avoids unresolved labels and own constructor binding", async t => {
  const f = await setup(t);
  f.config.projectRoutes[P2] = NEW_ALIAS;
  let s = await f.source();
  assert.throws(() => prepareProjectAssignment(s, change(A1)), { code: "ACTIVATION_CONFLICT" });
  f.config.projectRoutes[P2] = "route-b";
  f.config.accountRouting.routeAccounts[NEW_ALIAS] = null;
  s = await f.source();
  assert.throws(() => prepareProjectAssignment(s, change(A1)), { code: "ACTIVATION_CONFLICT" });
  delete f.config.accountRouting.routeAccounts[NEW_ALIAS];
  f.config.accountRouting.routeAccounts.constructor = A1;
  s = await f.source();
  const assigned = prepareProjectAssignment(s, change(A1));
  assert.equal(assigned.value.projectRoutes[P1], "constructor");
  assert.equal(Object.hasOwn(assigned.value.accountRouting.routeAccounts, "constructor"), true);
  assert.deepEqual(assigned.value.accountRouting.routeAccounts, s.value.accountRouting.routeAccounts);
});

// Null binding, missing binding, and an explicit override to the default are different saved choices.
test("legacy inheritance and missing target repair remain distinct", async t => {
  const f = await setup(t);
  let s = await f.source();
  const explicit = prepareProjectAssignment(s, change(A1, P2));
  assert.deepEqual(explicit.before, { kind: "legacy_inherited", routeAlias: "route-b", account: { id: A1, displayName: "Default account" } });
  assert.equal(explicit.after.kind, "override");
  assert.equal(explicit.value.accountRouting.routeAccounts["route-b"], null);
  const inherited = prepareProjectAssignment(s, change(null, P2));
  assert.equal(inherited.before.kind, "legacy_inherited");
  assert.equal(inherited.after.kind, "inherited");
  assert.equal(Object.hasOwn(inherited.value.projectRoutes, P2), false);
  delete f.config.accountRouting.routeAccounts["route-b"];
  s = await f.source();
  const repaired = prepareProjectAssignment(s, change(A2, P2));
  assert.deepEqual(repaired.before, { kind: "target_missing", routeAlias: "route-b" });
  assert.equal(repaired.value.projectRoutes[P2], "route-a");
  assert.equal(Object.hasOwn(repaired.value.accountRouting.routeAccounts, "route-b"), false);
});

// Treating an unavailable desktop catalog as an empty catalog could grant writes to stale identities.
test("configured-only row requires a healthy catalog", async t => {
  const f = await setup(t);
  delete f.state["local-projects"][P2];
  await f.saveState();
  const s = await f.source();
  assert.equal(s.catalog.entries.find(e => e.id === P2).routeState, "catalog_missing");
  assert.equal(prepareProjectAssignment(s, change(A2, P2)).value.projectRoutes[P2], "route-a");
  await writeFile(f.statePath, "{");
  const catalog = await inspectProjectCatalog(f.dir, s.config);
  assert.deepEqual(catalog, { state: "unavailable", entries: [] });
  assert.throws(() => prepareProjectAssignment({ ...s, catalog }, change(A2, P2)), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment(s, change(A2, P3)), { code: "ACTIVATION_CONFLICT" });
});

// Case-folded lookups or detached revisions would allow stale or ambiguous assignment edits.
test("catalog identity or revision conflict rejects", async t => {
  const f = await setup(t), id = "abcdefab-abcd-4abc-8abc-abcdefabcdef";
  f.state["local-projects"] = { [id]: { id, name: "Case project" }, [id.toUpperCase()]: { id, name: "Duplicate" } };
  await f.saveState();
  let s = await f.source();
  assert.equal(s.catalog.state, "unavailable");
  assert.throws(() => prepareProjectAssignment(s, change(A1)), { code: "ACTIVATION_CONFLICT" });
  delete f.state["local-projects"][id.toUpperCase()];
  f.config.projectRoutes = { [id.toUpperCase()]: "route-a" };
  await f.saveState(); s = await f.source();
  assert.equal(s.catalog.state, "unavailable");
  assert.throws(() => prepareProjectAssignment(s, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
  f.config.projectRoutes = { [id]: "route-a" };
  s = await f.source();
  assert.throws(() => prepareProjectAssignment(s, change(A1, id.toUpperCase())), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment({ ...s, configurationRevision: "0".repeat(64) }, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment({ ...s, source: s.source + " " }, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
  assert.throws(() => prepareProjectAssignment({ ...s, value: { ...s.value, listenPort: 1234 } }, change(A1, id)), { code: "ACTIVATION_CONFLICT" });
});

// Canonicalizing an unchanged mapping would create a spurious save and discard exact source bytes.
test("current alias and inherited no-ops preserve exact source", async t => {
  const f = await setup(t);
  f.config.accountRouting.routeAccounts["a-compatible"] = A2;
  let s = await f.source();
  s.source = " \n" + s.source + "\n\t"; s.configurationRevision = digest(s.source);
  const same = prepareProjectAssignment(s, change(A2));
  assert.equal(same.changed, false);
  assert.equal(same.value.projectRoutes[P1], "route-a");
  assert.equal(same.source, s.source);
  assert.equal(same.configurationRevision, s.configurationRevision);
  const removed = prepareProjectAssignment(s, change(null));
  s = { ...removed, catalog: await inspectProjectCatalog(f.dir, removed.config) };
  const inherited = prepareProjectAssignment(s, change(null));
  assert.equal(inherited.changed, false);
  assert.equal(inherited.source, removed.source);
  assert.deepEqual(inherited.value.accountRouting.routeAccounts, f.config.accountRouting.routeAccounts);
});

// Reusing the first insertion rather than lexical binding would make choices depend on file key order.
test("switch reuses lexicographically first compatible own binding", async t => {
  const f = await setup(t);
  Object.assign(f.config.accountRouting.routeAccounts, { "z-match": A1, "a-match": A1 });
  const s = await f.source(), assigned = prepareProjectAssignment(s, change(A1));
  assert.equal(assigned.value.projectRoutes[P1], "a-match");
  assert.deepEqual(assigned.value.accountRouting.routeAccounts, s.value.accountRouting.routeAccounts);
});

// A missing/null account choice must not be mistaken for an exact existing account ID.
test("assignment choices require exact accounts, UUID operations and ready schema 2", async t => {
  const f = await setup(t), s = await f.source();
  for (const accountId of [undefined, false, "", A1.toUpperCase(), P3])
    assert.throws(() => prepareProjectAssignment(s, change(accountId)), { code: "CONFIG_INVALID" });
  for (const operationId of [null, "invalid"])
    assert.throws(() => prepareProjectAssignment(s, { ...change(A1), operationId }), { code: "CONFIG_INVALID" });
  f.config.accountRouting.defaultAccountId = null;
  let notReady = await f.source();
  assert.throws(() => prepareProjectAssignment(notReady, change(A1)), { code: "CONFIG_INVALID" });
  f.config.schemaVersion = 1; delete f.config.accountRouting;
  notReady = await f.source();
  assert.throws(() => prepareProjectAssignment(notReady, change(null)), { code: "CONFIG_INVALID" });
});

// Object.prototype aliases are unresolved unless the binding is an own property.
test("missing own prototype-named binding can be repaired or inherited safely", async t => {
  const f = await setup(t);
  f.config.projectRoutes[P1] = "constructor";
  let s = await f.source();
  const inherited = prepareProjectAssignment(s, change(null));
  assert.deepEqual(inherited.before, { kind: "target_missing", routeAlias: "constructor" });
  assert.equal(inherited.after.kind, "inherited");
  assert.equal(Object.hasOwn(inherited.value.accountRouting.routeAccounts, "constructor"), false);
  assert.equal(prepareProjectAssignment(s, change(A2)).value.projectRoutes[P1], "route-a");
  f.config.projectRoutes[P1] = "toString";
  s = await f.source();
  assert.deepEqual(prepareProjectAssignment(s, change(null)).before, { kind: "target_missing", routeAlias: "toString" });
});
