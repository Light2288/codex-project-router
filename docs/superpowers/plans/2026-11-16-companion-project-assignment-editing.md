# Companion Project Assignment Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Assign, switch or remove one project's explicit account override through the companion, safely saving and applying it to the exact owned running router without an ordinary Codex restart.

**Architecture:** The owned child serializes an assignment-only durable configuration write and publishes an immutable request snapshot. The companion tracks saved and running revisions independently, reconciles uncertain outcomes through reads, and preserves original Direct recovery. A stopped/Direct helper uses the same assignment transformation and persistence safeguards without introducing general reload or live account/default changes.

**Tech Stack:** Existing Node 24 (`>=24 <25`), smol-toml 1.9.1, built-in HTTP/HTTPS/filesystem/SQLite, Swift/SwiftUI/AppKit and XCTest on macOS 14+, existing Apple silicon ad-hoc-signed package. No new dependency.

**Spec:** `docs/superpowers/specs/2026-11-16-companion-project-assignment-editing.md`

**Slug:** `companion-project-assignment-editing`

**Status:** APPROVED — implementation in progress

**Created:** 2026-11-16

**Updated:** 2026-11-16

**Provenance:** The separately presented Stage 2 specification, approved by the user's subsequent `Please implement the plan.` message. At that approval no assignment implementation plan existed. Stage 1 had separately been confirmed with `confirmed`. This separate plan was then saved and presented; the user's subsequent `approved` explicitly approves it. The execution-method question was not answered by that message; the user subsequently selected Subagent-driven through the native interactive control. This plan is grounded in the existing checkout at `2f6c4ea09f7ec61e8ded355464acf7f68dc8ca73`; artifact lookup alone does not establish approval.

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Subagent-driven, explicitly selected through the native interactive control after separate plan approval. Full implementers use the active managed full role `gpt-6.1-sol` with explicit high reasoning effort. Per-task reviews and the sole sequential final specification/quality gate remain required.

## Global Constraints

- “Capture routing mode and the immutable configured assignment snapshot synchronously at HTTP request receipt, before the first await, including incoming authentication.”
- “Assignment application never changes On/Off.” New explicit Start loads actual saved assignments and starts Off.
- “Never retarget a shared binding or garbage-collect existing bindings, including when removing an override.” Preserve exact mapping keys, unrelated configuration and optional-property presence.
- “Selecting the current default account by name remains an explicit override.” Use default removes the exact project mapping.
- “Account/default saves retain their existing safe Direct/stopped boundary.” No account/default/credential/provider reload is introduced.
- “Never retry a mutation automatically.” Post-write ambiguity is neither success nor rollback; no second live finish-applying command.
- Preserve incoming authentication, complete endpoint/key pairing, explicit unavailable-target failure, fresh desktop identity checks, no fallback/alternate-account retry/redirect, request bodies/models/continuation and cancellation semantics.
- Preserve process ownership, context-local recovery, original Direct destination and guarded Stop/Quit. Assignment uncertainty must not disable the existing Direct recovery route.
- Keep actual credentials, references, endpoints, mappings, checkpoints and raw evidence outside Git; do not print credential values, hashes or prefixes. Comparison tokens remain private and are not rendered or logged.
- Existing checkout only; no worktree. No assignment implementation branch/main update before plan approval. No push or branch/PR merge. Keep branding closeout separate.
- Defer account editing/deletion, hiding/reveal, comprehensive UI simplification, startup automation and distribution. Preserve the accepted viewport and off-screen Tab observations.

## Review Focus

1. A generated binding alias colliding with a shared unresolved label, or an own key named `constructor`, must not repair/retarget another project; Task 1 tests the complete alias namespace and own-property handling.
2. A reconciliation read arriving while a timed-out filesystem operation is still running must not report an earlier snapshot as its final outcome; Tasks 4/5 test serial ordering and retired replies.
3. A legitimate assignment transition must preserve desktop confirmation, while a provider/recovery-record change during the same interval must invalidate it; Task 6 tests both with identical project choices.
4. After an external account-table edit, an old running account must not be labelled from the newly saved account table; Tasks 4/7 test running summaries originating from the retained snapshot.
5. Closing the editor during a save must not cancel authority tracking, retry the mutation, or mark it complete from a late view task; Tasks 6/7 keep mutation ownership in the controller and test dismissal.

---

## Evidence, resolution and planning decisions

Specification resolution after saving: NEW_ONLY at the explicit Spec path; plan resolution before this write: MISSING. The exact legacy paths are absent, with no conflicting slug/reference. This plan reuses the specification's original basename/date. The specification was saved with approved requirements unchanged and approval/lifecycle metadata updated.

Read-only Git verification during planning: branch `docs/companion-branding-closeout`, HEAD `2f6c4ea09f7ec61e8ded355464acf7f68dc8ca73`; local main, origin/main and actual remote main still match `c0a5a53d8c41a6c394f28497fa39133d68a79683`. The separate branding closeout is that branch's one local documentation commit. No fetch, main update, assignment branch, commit, product edit, test/build or operational mutation occurred during planning. Recheck these facts at execution.

Architecture map `docs/architecture/map.md` is absent; map HEAD/freshness are unavailable. No architecture/ADR/decision artifact was found under docs, including conventional `docs/adr`, `docs/adrs` and `docs/decisions` locations. There is no discovered accepted ADR constraint. Do not regenerate a map. Key paths inspected at the stated HEAD: config/catalog/identity, proxy/admission/credentials, managed startup/channel, account-setup persistence, activation inspection/recovery, native wire/backend/channel/controller/view, synthetic fixtures and package allowlists.

Important evidence: `config.js` distinguishes exact project keys, missing explicit bindings and null legacy inheritance, freezes loaded data, and exposes private source-byte revisions. `proxy.js` captures mode before its first await but uses startup configuration thereafter. `managed-serve.js` has a synchronous mode-only parser with 16 KiB frames and 32 KiB retained buffers. `RouterModeChannel` has one pending operation and an absolute five-second deadline. `RouterController.reconcile` currently invalidates confirmation on any activation revision change and gates channel reads on matching readiness. `account-setup.js` contains stopped/Direct compare-before-replace safeguards; its authorization must not be widened.

Command evidence: root `package.json` supplies `npm test`, `npm run companion:test`, `npm run companion:build` and `npm run companion:package-test`. Focused Node commands below expand the same `node --test test/*.test.js` runner to the listed files; new tests live in that existing glob. Focused `swift test --package-path companion --filter <Class>` follows the existing Swift test targets and the saved routing On/Off plan. `companion/README.md` documents native → build → Node → package final verification, and package tests execute strict codesign verification. Git commands follow the user's Git workflow. No historical test count is a new acceptance result.

No material product decision remains unresolved. The following are implementation decisions within the approved specification:

- Use exact own-property lookups. Keep an already-compatible current alias; otherwise reuse the lexicographically first existing binding to the selected account. If none exists, allocate `assignment-` plus the lowercase operation UUID without hyphens. Reject collision with **any** existing binding key or project mapping value, including an unresolved label. Never fill another label's missing binding.
- Preserve source bytes on a semantic no-op. Use default on a legacy label is a real removal; selecting the named default remains an override. Do not rewrite existing bindings or normalize project keys.
- Keep private immutable `assignment-checkpoint-<operationId>.json` preimages and `assignment-change-<operationId>.json` intent records beside the selected configuration. Intent records describe baseline/candidate revisions, exact context, selected project/account and checkpoint filename; they are evidence, not proof of application or replay instructions. No new mutable completion journal or automatic cleanup/replay framework.
- Maintain one bounded last-attempt record in the live child. A fresh ordered read plus actual saved bytes/current running snapshot establishes outcomes. For a stopped helper, reconcile only after that exact helper has exited/drained, using its immutable intent and fresh stopped/Direct evidence.
- Successful live application changes only the current immutable assignment/configuration snapshot. Publish synchronously after durable write; configuration accounts/default/static data must equal the retained baseline. Reads may describe divergence; writes require a coherent baseline.

## File responsibilities and interfaces

| Files | Responsibility |
|---|---|
| New `src/project-catalog.js`; `src/companion.js` | Shared validated discovery/mapping-only catalog and private catalog comparison token |
| New `src/project-assignments.js`, `src/configuration-lock.js`; `src/config.js`, `src/errors.js` | Assignment transformation, private source/intent/checkpoint validation, shared guarded lock and durable assignment-only write |
| `src/proxy.js`, `src/managed-serve.js` | Request snapshot capture, applied health fingerprint and bounded serialized assignment protocol |
| `src/companion-cli.js`, `src/activation.js` | Stopped assignment read/commit bridge; inspection-only revision evidence, retaining activation/rollback mutation behavior |
| New `companion/Sources/CompanionCore/AssignmentTypes.swift`; `WireTypes.swift`, `RouterModeChannel.swift`, `ProcessBackend.swift` | Exact non-secret wire types, bounded owned-child operations and stopped-helper reconciliation |
| `companion/Sources/CompanionCore/RouterController.swift` | Serialized editing authority, saved/running state and narrowly verified confirmation continuity |
| New `companion/Sources/CodexProjectRouter/ProjectAssignmentView.swift`; `ControlsView.swift` | One-project editor, saved/effective presentation and errors; no unrelated navigation changes |
| Node/native/app tests and existing `Fixtures/node-fixture` | Deterministic data, timing, protocol, ownership, recovery and presentation evidence |
| `scripts/build-companion.mjs`, `test/companion-package.test.js` | Production source allowlists and relocated signed-package coverage |
| Both READMEs, operating guide, new validation report | Delivered workflow, limitations and observed acceptance |

### Shared Node contracts

- `inspectProjectCatalog(codexHome, cfg) -> Promise<{state, revision?, entries}>` in `project-catalog.js`. Extract the current catalog validation unchanged; a healthy result adds a private revision of its validated, sorted project identity/name projection, not arbitrary desktop state bytes. Mapping changes are bound separately by saved revision.
- `withConfigurationLock(configPath, action) -> Promise<T>` in `configuration-lock.js`: extract startup's exclusive `.activation.lock` ownership/inode guard, strengthen canonical directory/file identity checks needed by writes, hold through callback and unlink only this invocation's unchanged lock. Preserve the existing `withRouterStartupLock` export as an alias for compatibility. Setup/activation continue to coordinate through the same lock path without broad refactoring.
- `prepareProjectAssignment(source, {projectId, accountId, operationId}) -> PreparedAssignment` in `project-assignments.js`. `accountId: null` means Use default. Source carries validated raw value/configuration, source bytes/revision and fresh healthy catalog. Prepared output carries prospective source/configuration/revision and `changed`; only projectRoutes and necessary new routeAccounts binding differ.
- `commitProjectAssignment(input, {running, publish} = {}) -> Promise<AssignmentCommit>` in the same file. Input is `{configPath, expectedContext, expectedSavedRevision, expectedConfigurationIdentity, expectedCatalogRevision, operationId, projectId, accountId}`; live input additionally carries `expectedRunningRevision`. `running` is the exact current immutable child snapshot; its presence is supplied internally by managed-serve, never accepted from one-shot JSON. `publish(next)` is synchronous. Without running/publish this is the stopped/Direct path. Result includes context, operationId, projectId, changed, before/candidate/saved revisions and identities, and applied running evidence only for the live path. Failures throw the fixed RouterError codes from Task 3; the managed protocol maps them to rejected/uncertain results.
- `readProjectAssignmentState({configPath, expectedContext, projectId, operationId}, running?) -> Promise<AssignmentState>` reads actual saved state and any specifically requested immutable intent; it never replays or writes. `projectId` and `operationId` may be null. Saved state is `ready`, `unavailable` or `conflict`; unavailable reads never erase known runtime evidence.
- `AssignmentSummary` is `{kind, account?, routeAlias?}` with kind exactly `inherited | legacy_inherited | override | target_missing` and account an existing `{id, displayName}` summary. Running summaries come from the retained running snapshot, never a newly saved account table.

Configuration identity is separate from source-byte revision: a private token binds canonical context, directory dev/inode and file dev/inode/uid/mode/nlink/size, excluding timestamps that rename or unrelated directory activity can change. Return it only from an unchanged, descriptor-validated source read; retain it at startup/publication and require it on edits, so same-byte file replacement cannot masquerade as the UI's earlier source. Compare bytes and file stat/ctime as well during each read and immediately before replacement to detect an in-progress rewrite. Intent records include before/candidate identity; the candidate identity is derived from the synced temporary inode destined for the canonical configuration path. Neither identities nor revisions are displayed/logged.

### Private channel contract

Keep schemaVersion 1 and the existing get_mode/set_mode shapes. New ready frames add the single optional capability `capabilities: ["project_assignments_v1"]`. New native code accepts original ready frames for existing mode control but never grants assignment writes without this capability. Retain exact-key/type/session validation.

- `get_assignment`: `{schemaVersion, sessionId, requestId, action, expectedContext, projectId, operationId}`; nullable selected project/operation; ordered behind previous commands.
- `set_assignment`: `{schemaVersion, sessionId, requestId, action, expectedContext, expectedSavedRevision, expectedConfigurationIdentity, expectedRunningRevision, expectedCatalogRevision, projectId, accountId}`; requestId is operationId. accountId is present and either an existing exact account ID or null.
- `assignment_state`: envelope `{schemaVersion, type, sessionId, requestId, state}`. State contains context, actual saved read state/revision/identity/fingerprint, current running revision/identity/fingerprint, current mode, selected saved/running summaries when requested, and matching intent/last-attempt evidence when available. It contains no full maps, account tables, endpoints, Keychain references or raw source.
- `assignment_result`: same envelope identity plus `outcome: applied | rejected | uncertain`, fixed safe code on failures, and state when available. An applied result binds both before and candidate revisions; a rejected result asserts no replacement occurred. Malformed frames close control; semantic invalid/stale/unsafe selections reject before replacement.

All comparison tokens stay private, with strict bounded hexadecimal validation; do not render them in Advanced or logs. Preserve 16 KiB frames, 32 KiB retained input/output, nonblocking native I/O, one pending native operation and five-second absolute deadline. One async Node command runs at a time; input parsing pauses during it, queued bytes remain bounded and overflow/control loss does not cancel an accepted persistence operation or HTTP service. No whole-catalog response crosses this channel.

### Native contracts

In `AssignmentTypes.swift`, add Codable/Equatable `AssignmentSummary`, `AssignmentState`, `AssignmentChange` (exact Node fields), `AssignmentCommit` and `AssignmentIntent` matching the contracts above. Null choice fields must encode as explicit JSON null, not be omitted. Validate UUIDs, kinds, exact context, bounded names and comparison tokens before granting authority.

Extend `Inspection.Configuration` with optional `accounts: [AccountSummary]`, and root Inspection with optional `configurationRevision`, `configurationIdentity`, `routingFingerprint`, `recoveryRevision`; add optional `Catalog.revision`. Missing new fields permit existing browsing, not new editing. In `inspectActivation`, expose configurationRevision/configurationIdentity/routingFingerprint and a recoveryRevision derived from existing validated context/provider-state/record identity/phase, never raw provider authentication. `inspectCompanion` must reject mixed source observations: the configuration revision and identity used for catalog/account summaries must match activation inspection before presenting coherent provider/assignment evidence.

Add separate `ProjectAssignmentBackend` (implemented by ProcessBackend) rather than expanding every unrelated CompanionBackend test double:

- `readAssignment(_ child: OwnedRouter, projectID: String?, operationID: String?) async throws -> AssignmentState`
- `applyAssignment(_ change: AssignmentChange, to child: OwnedRouter) async throws -> AssignmentCommit`
- `readStoppedAssignment(context: ActivationContext, projectID: String, operationID: String?) async throws -> AssignmentState`
- `saveStoppedAssignment(_ change: AssignmentChange) async throws -> AssignmentCommit`
- `probeAssignmentPort(_ context: ActivationContext) async -> StopOutcome.PortState`

Add channel `readAssignment(projectID:operationID:)` and `applyAssignment(_:)`; retain existing mode methods. Use typed pending results in the same channel/queue, not a second stdout reader. Assignment uncertainty is separate from mode and provider-helper uncertainty. A get_mode reply cannot reconcile assignment persistence. Never signal/retry a child because of channel failure.

Controller API: `canEditAssignment(_ project: Inspection.Entry) -> Bool`, `loadAssignment(projectID: String) async -> AssignmentState?`, `saveAssignment(projectID: String, accountID: String?) async`, plus read-only selected/pending assignment state and assignment-specific error/status. Save owns its operation through completion independently of sheet lifetime. Reserve the existing action/inspection slot for fresh preflight → mutation → compound reconciliation, without adding another polling framework.

## Execution ruling: package verification ordering

After execution preflight, the controller moved mechanical production source-allowlist maintenance forward to Tasks 1/3 and requires rebuilding the ignored app before per-task full Node checks when executable resources change. The existing package checks compare bundled sources against the checkout, so deferring those additions until Task 8 would manufacture stale-package failures during TDD verification. Task 8 still owns final package feature coverage, live acceptance, documentation and closeout. This changes dependency ordering only; requirements and execution endpoint are unchanged. The ignored SDD ledger records the ruling and evidence.

## Execution preflight — only after separate plan approval

- [x] Identify this approved pair and quote the separate specification and plan approval messages. Preserve the selected execution method; load `personal-workflows:spec-implement` and its selected base then, not while planning. Mark the plan approved only from actual approval evidence.
- [x] Run `git status --short --branch`, `git rev-parse HEAD main origin/main`, `git ls-remote --heads origin main`; preserve the two uncommitted artifacts and any unrelated work. Verify `2f6c4ea` remains reachable from `docs/companion-branding-closeout`. Do not cherry-pick or merge that closeout into the assignment branch.
- [x] After approval only, `git fetch origin main`. With main still unselected in this checkout, fast-forward its ref using `git fetch . refs/remotes/origin/main:refs/heads/main` (no force); stop on divergence rather than reset or merge. If the checkout/base changed, preserve work and re-establish the same safe conditions first. Review new baseline changes before implementation.
- [x] Confirm `feat/companion-project-assignment-editing` is absent, then `git switch -c feat/companion-project-assignment-editing main`. Record actual base; preserve approved artifacts and all unrelated edits. Commit only this approved spec/plan pair with `git commit -m "docs: approve companion project assignment editing"` after explicit path staging. No worktree/push/merge.

Execution preflight observed: implementation base `c0a5a53d8c41a6c394f28497fa39133d68a79683`; `main` needed no content update. Separate branding closeout remains `2f6c4ea09f7ec61e8ded355464acf7f68dc8ca73` on its own branch. Subagent-driven/full selected; this approved pair is committed before product changes.

### Task 1: Define exact assignment transformation and catalog evidence [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-01, AC-05, AC-06, AC-08

**Files:** Create `src/project-catalog.js`, `src/project-assignments.js`, `test/project-assignments.test.js`; modify `src/companion.js`; extend `test/companion.test.js`, `test/config-identity.test.js` and shared synthetic fixtures only as needed. Risk: alias or identity mistakes could alter another project's account.

**Interfaces:** Produce inspectProjectCatalog, prepareProjectAssignment and the source/summary structures defined above; persistence functions arrive in Task 3. Consume existing UUID/configuration validators. Re-exporting the extracted catalog is unnecessary.

- [ ] **Step 1 — write RED tests.** Add `assign switch and inherit preserve exact unrelated data`, `shared alias never retargets`, `new alias avoids unresolved labels and own constructor binding`, `legacy inheritance and missing target repair remain distinct`, `configured-only row requires a healthy catalog`, and `catalog identity or revision conflict rejects`. Start with fixture/accountRouting synthetic data, add required project names, clone raw source before transformation, and assert unrelated object equality plus optional own-property presence. Pin the selected alias algorithm and no-op source preservation.

```js
assert.deepEqual(saved.projectRoutes[P2], before.projectRoutes[P2]);
assert.deepEqual(saved.accountRouting.routeAccounts[sharedAlias], before.accountRouting.routeAccounts[sharedAlias]);
assert.equal(Object.hasOwn(removed.projectRoutes, P1), false);
assert.equal(Object.hasOwn(saved, "allowUnassignedThreadTitles"), Object.hasOwn(before, "allowUnassignedThreadTitles"));
```

- [ ] **Step 2 — run RED.** `node --test test/project-assignments.test.js test/companion.test.js test/config-identity.test.js`. Expected: new import/function/assignment assertions fail before product edits; preserve pre-existing passes.
- [ ] **Step 3 — implement the catalog extraction and pure transformation.** Preserve existing catalog collision behavior and healthy configured-only rows. Clone raw configuration, change only the selected exact key/necessary new binding, validate a ready schema-2 result, and retain missing-target/null/explicit-default distinctions.
- [ ] **Step 4 — run GREEN.** Repeat Step 2. Expected: all listed cases pass, no private operational reads, schema-1 browsing unchanged and no unrelated changes.
- [ ] **Step 5 — commit.** Stage Task 1 paths only; `git commit -m "feat: define isolated project assignment changes"`. Follow the selected workflow's ordinary task gate.

### Task 2: Capture immutable request configuration and mode together [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,auth]

**Acceptance criteria:** AC-02, AC-07, AC-13

**Files:** Modify `src/proxy.js`, `test/proxy.test.js`; extend `test/helpers/fixtures.js` only for reusable synthetic barriers. Risk: reading current configuration after an await could mix accounts within a request.

**Interfaces:** Add optional `createProxy(startupConfig, {getRequestRoutingSnapshot, ...existingOptions})`; getter synchronously returns immutable `{config, mode}`. Capture once at callback entry before async work. Preserve getProjectRoutingMode compatibility for existing callers, but reject supplying both getters. Absence retains standalone behavior. Health uses the captured applied configFingerprint.

- [ ] **Step 1 — write RED tests.** Add `assignment snapshot precedes incoming authentication`, `assignment snapshot survives identity retry and outgoing credential wait`, `stream and reused connection capture independent snapshots`, and `compact background and failure never reroute`. Use existing synthetic origins/credential reader and explicit barriers; replace the current snapshot while an earlier request waits. Assert exactly the old pair for that request and new pair for the next, unchanged bodies/prefixes/continuation, Off inheritance and zero fallback after denied credentials/402/429/5xx/3xx. Retain fresh desktop membership checks.

```js
assert.equal(oldRequest.headers.authorization, "Bearer synthetic-project");
assert.equal(nextRequest.headers.authorization, "Bearer synthetic-default");
assert.deepEqual(oldRequest.bodyBytes, originalBodyBytes);
assert.equal(alternateAccountCalls.length, 0);
```

- [ ] **Step 2 — run RED.** `node --test test/proxy.test.js test/config-identity.test.js`. Expected: new snapshot/boundary cases fail, rather than depending on sleeps.
- [ ] **Step 3 — implement the snapshot getter contract.** Use the captured config throughout auth, identity/retry, selection, credential reads and response lifecycle. Never mutate earlier frozen maps or account pairs. Keep mode-only and standalone callers compatible.
- [ ] **Step 4 — run GREEN.** Repeat Step 2. Expected: all boundary/auth/transport cases pass without abandoned barriers or duplicate attempts/completions.
- [ ] **Step 5 — commit.** `git add src/proxy.js test/proxy.test.js` plus any explicitly changed fixture; `git commit -m "feat: snapshot assignments at request receipt"`.

### Task 3: Persist assignment changes under the existing safety boundary [size: L | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data,concurrency]

**Acceptance criteria:** AC-03, AC-06, AC-08, AC-09, AC-10, AC-12

**Files:** Create `src/configuration-lock.js`; complete `src/project-assignments.js`; modify `src/config.js`, `src/errors.js`, `src/companion-cli.js`, `src/companion.js`, startup lock import/export in `src/managed-serve.js`; test in `test/project-assignments.test.js`, `test/companion-cli.test.js`, `test/managed-serve.test.js`. Risk: durable replacement and interruption must preserve exact configuration and evidence. Lock coordination is inseparable from this writer's data safety; it is not a general storage refactor.

**Interfaces:** Produce withConfigurationLock, commitProjectAssignment and readProjectAssignmentState. Add one-shot `assignment_state` and `assignment_commit` actions with exact input keys; stopped commits cannot contain live running authority. Add fixed safe `ASSIGNMENT_INVALID`, `ASSIGNMENT_CONFLICT`, `ASSIGNMENT_UNAVAILABLE`, `ASSIGNMENT_UNCERTAIN` errors. Source reading binds validated raw bytes/revision to unchanged file and directory identities; no arbitrary provider TOML/authentication hashing.

- [ ] **Step 1 — write RED cases.** Add `stopped Direct save checkpoints and preserves provider`, `Off or occupied unknown port never authorizes stopped write`, `stale source catalog replacement or setup lease rejects`, `live writer rejects changed static accounts default verifier or optional flags`, and `fault phase determines rejection versus uncertainty`. Cover checkpoint/temp/intent creation, file and directory sync, rename, synchronous publication and lock-release boundaries using injected filesystem/publish functions passed as internal test dependencies, never environment/production fault switches. Test symlinks, hard links, unsafe ownership/modes, replaced directory/lock and stale lock preservation.

```js
assert.deepEqual(await readFile(checkpointPath), beforeBytes);
assert.deepEqual(await readFile(providerPath), providerBeforeBytes);
assert.equal(result.changed, true);
assert.equal(intent.candidateRevision, persistedRevision);
// A failure before replacement preserves bytes; a post-rename fault reports uncertainty.
assert.equal(preWriteConflict.code, "ASSIGNMENT_CONFLICT");
assert.equal(postRenameFailure.code, "ASSIGNMENT_UNCERTAIN");
```

- [ ] **Step 2 — run RED.** `node --test test/project-assignments.test.js test/companion-cli.test.js test/managed-serve.test.js`. Expected: missing writer/bridge or fault-safety assertions fail.
- [ ] **Step 3 — implement persistence and stopped bridge.** Acquire the exclusive shared lock; read/validate source/catalog/context and expected revisions; reject unready schema/static drift. Stopped path freshly requires compatible Direct provider, settled activation evidence and an independent exclusive empty-port check; native also supplies no-owned-child authority. Validate prospective temp, fsync temp and exact checkpoint/immutable intent plus directory, recheck source/provider/catalog/file identities immediately before rename, rename and fsync directory. Live publication follows durable persistence synchronously; retain the previous snapshot on pre-publication failure. Release only owned unchanged lock. Return certain rejection only when replacement is known not to have occurred; cleanup/release failures never fabricate success or remove unsafe evidence. No-op skips replacement and preserves source bytes.
- [ ] **Step 4 — implement read reconciliation.** Read actual saved revision/identity and requested intent with containment/identity checks. A stopped outcome can settle only after its helper has exited: matching candidate revision and identity confirm saved, unchanged baseline revision and identity confirm no effect, any other state remains conflicting/unconfirmed. Never replay, restore a checkpoint or infer runtime application from intent. Start/relaunch still use actual saved state and preserve stale locks.
- [ ] **Step 5 — run GREEN.** Repeat Step 2, then `node --test test/account-setup.test.js test/activation.test.js`. Expected: writer/fault and existing setup/recovery tests pass; no broadened account/default save guard, no credential retrieval or provider change.
- [ ] **Step 6 — commit.** Stage Task 3 paths only; `git commit -m "feat: persist guarded project assignment changes"`.

### Task 4: Apply and reconcile through the bounded owned-child protocol [size: L | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,concurrency]

**Acceptance criteria:** AC-02, AC-04, AC-08, AC-09, AC-10, AC-12, AC-13

**Files:** Modify `src/managed-serve.js`, `test/managed-serve.test.js`; extend `test/proxy.test.js` only for end-to-end managed snapshot assertions. Risk: only the correct child/context may mutate and attest running state; parser serialization is required to preserve that authority.

**Interfaces:** Consume Tasks 2/3. Hold one immutable current snapshot `{config, configurationRevision, configurationIdentity, mode}` initialized under startup lock in Off. Mode commands replace only mode; assignment publication replaces config/revision/identity without changing mode. Implement the private channel contract above and one bounded last-attempt record; no general reload API or HTTP mutation endpoint.

- [ ] **Step 1 — write RED tests.** Add `owned assignment command acknowledges durable published snapshot`, `queued read waits for uncertain write to settle`, `stale revisions context account or catalog reject unchanged`, `control loss does not cancel accepted write or listener`, `saved static drift never reloads`, and `runtime summary retains running account name after disk edit`. Include get_mode/set_mode ordering, capability absence, wrong/excess fields, null encoding, UTF-8, split/coalesced/flooded input, blocked output and repeated operation IDs. Read health after publication and assert it matches the applied configuration, not startup or an unapplied saved candidate.

```js
assert.equal(reply.outcome, "applied");
assert.equal(reply.state.savedRevision, reply.state.runningRevision);
assert.equal(reply.state.mode, "on");
assert.equal(health.configFingerprint, reply.state.runningFingerprint);
assert.equal(reconciliationWasReturnedBeforeWriteSettled, false);
```

- [ ] **Step 2 — run RED.** `node --test test/managed-serve.test.js test/proxy.test.js`. Expected: new assignment protocol/application assertions fail.
- [ ] **Step 3 — implement serialized commands and authoritative reads.** Pause parsing during each async command while preserving existing retained-byte/output bounds; close/drain invalid channels safely. Mutation requires expected saved and running baseline coherence, exact static baseline and fresh catalog. A fresh get_assignment runs after preceding attempts settle and describes actual saved versus current runtime state, even on mismatch; unavailable saved reads leave runtime evidence intact. Lost channel/reply never rolls back, resets mode or retries. Applied acknowledgment follows durable write, publication and safe lock completion; uncertain cleanup remains uncertain.
- [ ] **Step 4 — run GREEN.** Repeat Step 2 and `node --test test/project-assignments.test.js test/companion-cli.test.js`. Expected: all cases pass, bounded memory retained, zero secret/preflight access and listener continues after control loss.
- [ ] **Step 5 — commit.** Stage Task 4 paths only; `git commit -m "feat: apply assignments on the owned router"`.

### Task 5: Extend the native capability and uncertainty handling [size: L | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,concurrency]

**Acceptance criteria:** AC-02, AC-03, AC-08, AC-09, AC-10, AC-12

**Files:** Create `companion/Sources/CompanionCore/AssignmentTypes.swift`, `companion/Tests/CompanionCoreTests/AssignmentTypesTests.swift`; modify `WireTypes.swift`, `RouterModeChannel.swift`, `ProcessBackend.swift`, corresponding channel/backend tests and `Fixtures/node-fixture`. Risk: a stale or unrelated Process/reply must not grant assignment authority.

**Interfaces:** Produce the native contracts above and fixed CompanionError assignmentUnavailable/assignmentUncertain/assignmentConflict messages. Retain exact Process object/session/context lookup both before and after awaited child operations. Keep one reader/writer/pending request on the existing channel queue. Provider/setup reconciliation remains distinct.

- [ ] **Step 1 — write RED tests.** Add `testAssignmentTypesEncodeExplicitInheritanceNull`, `testAssignmentRequiresCapabilityAndExactChild`, `testAssignmentTimeoutNeedsFreshAssignmentRead`, `testModeReadCannotReconcileAssignment`, `testQueuedFreshReadIgnoresRetiredMutationReply`, `testPartialFrameDisablesChannelWithoutSignalling`, and `testStoppedHelperMustExitBeforeReconciliation`. Extend the synthetic process fixture to exchange actual compact assignment frames, delayed/failed outcomes and unsupported capability; retain all earlier flood/stall/port-reuse/environment/ownership cases.

```swift
XCTAssertEqual(command["action"] as? String, "set_assignment")
XCTAssertTrue(command.keys.contains("accountId"))
XCTAssertTrue(command["accountId"] is NSNull)
XCTAssertEqual(peer.commands.filter { $0["action"] as? String == "set_assignment" }.count, 1)
```

- [ ] **Step 2 — run RED.** `swift test --package-path companion --filter AssignmentTypesTests`, then the existing `RouterModeChannelTests` and `ProcessBackendTests` filters. Expected: missing types/APIs or new capability/outcome tests fail before implementation.
- [ ] **Step 3 — implement channel/backend changes.** Validate exact protocol variants, context/revisions/selected project/operation and attested before/candidate pairs. Preserve five-second absolute deadlines and bounded nonblocking I/O. Timeout/cancellation/loss retires observation, never the accepted child mutation; no mode read or late reply clears assignment uncertainty. Fresh ordered assignment read can settle only matching evidence. Stopped helpers use the existing retained mutating-process mechanism, never terminate a possibly writing helper, and read intent/state only after exit/drain; do not let generic provider inspect clear assignment uncertainty accidentally.
- [ ] **Step 4 — run GREEN.** Repeat all Step 2 commands. Expected: all focused tests pass with no signal/adoption/retry or protocol payload leakage; old mode-only ready remains usable for mode but not assignment editing.
- [ ] **Step 5 — commit.** Stage Task 5 paths only; `git commit -m "feat: bind native assignment control to owned child"`.

### Task 6: Reconcile assignment transitions without weakening recovery [size: L | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,auth]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-08, AC-09, AC-10, AC-11, AC-12, AC-13

**Files:** Modify `src/activation.js` (inspection projection only), `src/companion.js`, `WireTypes.swift`, `ProcessBackend.swift`, `RouterController.swift`; extend `test/activation.test.js`, `test/companion.test.js`, `RouterControllerTests.swift`, `ProcessBackendTests.swift`. Risk: racing evidence must neither invalidate a legitimate assignment-only confirmation nor bless unrelated drift.

**Interfaces:** Produce the Inspection evidence fields and controller API above. Introduce assignment-specific uncertainty/write-block state, distinct from provider/setup mutation authority. Compare compound observations in the existing serialized slot before applying generic reconcile. Only the exact expected assignment transition may preserve the prior DesktopConfirmation enum and existing journal obligation; it never grants a new confirmation.

- [ ] **Step 1 — write RED cases.** Add `testVerifiedAssignmentPreservesConfirmedRoutedAndDirectAuthority`, `testSameChoiceWithChangedRecoveryRevisionInvalidates`, `testUncertainAssignmentRetainsRestoreDirectAndGuardedStop`, `testAssignmentReadDoesNotRequireMatchingReadiness`, `testStaleInspectionGenerationOrReplacedChildCannotApply`, `testDismissedEditorRetainsPendingOperation`, and `testStoppedSaveAndAccountSetupBoundariesRemainIndependent`. Test active legitimate recovery obligations versus prepared/conflicting evidence, pending initial response confirmation, repeated edits, mode transitions, shutdown/relaunch, external listener and normal legacy setup.

```swift
XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
XCTAssertFalse(controller.canEditAssignment(project)) // unresolved assignment mutation
XCTAssertTrue(controller.canRestoreDirect) // recovery remains available
XCTAssertFalse(controller.canBeginAccountSetup) // live account/default save remains blocked
```

- [ ] **Step 2 — run RED.** `node --test test/activation.test.js test/companion.test.js`, `swift test --package-path companion --filter RouterControllerTests`, and `swift test --package-path companion --filter ProcessBackendTests`. Expected: new compound-evidence/controller assertions fail.
- [ ] **Step 3 — implement inspection and action reconciliation.** Obtain consistent source/catalog/account/provider evidence and reject mixed revisions. Before editing/save, freshly validate identity, selected configuration, exact child/capability, lock/setup safety and saved/running baseline. Live provider evidence may be healthy Direct or active Router with its legitimate existing recovery obligation; prepared/conflicting/unavailable evidence blocks. Preserve pending/confirmed desktop state rather than invent a new confirmation requirement. Stopped save additionally requires no owned child, no recovery obligation/pending journal, fresh Direct and independently empty port.
- [ ] **Step 4 — implement verified continuity and recovery.** Capture before source/activation/recovery evidence, exact child and requested operation. Gather after disk and ordered runtime evidence before generic reconcile; suppress revision/readiness invalidation only when exact attested candidate, applied fingerprint, same context/child and unchanged recoveryRevision agree. Any unexpected revision/provider/recovery change invalidates conservatively. Use exact-child lookup independent of matching health for reads; require coherent readiness for writes. On confirmed divergence block further edits and retain Restore direct/manual confirmation/guarded Stop/Start Off. Assignment uncertainty alone must not reuse the provider mutation flag that would block those recovery actions. Child exit, relaunch, unsafe lock or an unowned survivor retains conservative recovery; no replay.
- [ ] **Step 5 — run GREEN.** Repeat Step 2, then `swift test --package-path companion --filter AccountSetupControllerTests`. Expected: new reconciliation tests and existing account/default/recovery guards pass, including no gratuitous restart for verified success.
- [ ] **Step 6 — commit.** Stage Task 6 paths only; `git commit -m "feat: reconcile assignments with guarded recovery"`.

### Task 7: Deliver the one-project native editor and truthful state [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-04, AC-05, AC-09, AC-10, AC-14

**Files:** Create `companion/Sources/CodexProjectRouter/ProjectAssignmentView.swift`, `companion/Tests/CompanionAppTests/ProjectAssignmentPresentationTests.swift`; modify `ControlsView.swift` and existing controls presentation/action tests. Risk: saved selections must not be misrepresented as effective routing.

**Interfaces:** `ProjectAssignmentView(controller: RouterController, project: Inspection.Entry)` uses the controller-owned load/save APIs; local state holds only the unsaved selection. Add focused `AssignmentPresentation` projection in that file with `savedText`, `runningText`, `actionTitle`, `canSave` and `warning`. Controls rows open one sheet and use runtime summaries only when verified; otherwise show saved state with unconfirmed/not-running explanation.

- [ ] **Step 1 — write RED presentation/action cases.** Add `testAssignSwitchAndUseDefaultUseStableIDs`, `testNamedDefaultRemainsExplicitOverride`, `testSavedAndRunningDivergenceNeverLooksApplied`, `testConfiguredOnlyWarningAndMissingTargetRepair`, `testOffSuspensionAndUnavailableControlRemainClear`, and `testDismissalDoesNotRetryOrOwnMutation`. Assert button labels Save and apply versus Save, explicit pending state, preserved unsaved selection on rejection, account names from the correct snapshot, no key/billing claims and technical alias details only in Advanced.

```swift
XCTAssertEqual(presentation.actionTitle, "Save and apply")
XCTAssertEqual(stoppedPresentation.actionTitle, "Save")
XCTAssertEqual(unconfirmedPresentation.runningText, "Running assignment unconfirmed")
```

- [ ] **Step 2 — run RED.** `swift test --package-path companion --filter ProjectAssignmentPresentationTests` and `swift test --package-path companion --filter ControlsPresentationTests`. Expected: new presentation/action assertions fail.
- [ ] **Step 3 — implement the focused UI.** Provide existing account picker plus Use default, saved/running explanations, absent-discovery warning, pending/error guidance and appropriate disabled reasons. Keep operation ownership in the controller so sheet dismissal never cancels tracking or repeats saves. Keep routing/default controls prominent; do not fix the accepted selection-scroll/Tab issues or redesign unrelated setup/recovery navigation.
- [ ] **Step 4 — run GREEN.** Repeat Step 2, then `npm run companion:test`. Expected: focused and complete native tests pass, including account setup, Quit guidance, Dock/window lifetime and existing presentation regressions.
- [ ] **Step 5 — commit.** Stage Task 7 paths only; `git commit -m "feat: add companion project assignment editor"`.

### Task 8: Package, validate and close the increment [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10, AC-11, AC-12, AC-13, AC-14

**Files:** Modify `scripts/build-companion.mjs`, `test/companion-package.test.js`, `README.md`, `companion/README.md`, `docs/operating-guide.md`; create `docs/validation/companion-project-assignment-editing.md`. Update only lifecycle/checklists on this approved pair as evidence accrues. Risk: packaging or claims could conceal an untested production path.

**Interfaces:** Add the three new production modules (project-catalog.js, project-assignments.js, configuration-lock.js) to both explicit allowlists. Extend existing package cases to use bundled assignment state/commit and owned managed capability in relocated/source-denied fixtures without adding authentication helpers or production fault switches. Preserve three package cases; do not weaken source/signature/resource confinement checks.

- [ ] **Step 1 — add package RED assertions.** Extend resource manifests and relocated fixture flow: packaged stopped save, managed assign/switch/remove, applied health fingerprint, no checkout access and unchanged provider/recovery. Assert only synthetic pairs; retain current native Keychain/branding and exact cleanup checks. Run `npm run companion:build`, then `npm run companion:package-test`. Expected: missing new bundled modules or new integration assertion fails before updating allowlists; distinguish an unrelated baseline failure and never accept a skip as success.
- [ ] **Step 2 — implement package integration and documentation.** Update both source allowlists and any sandbox fixture resource list. Document eligibility, saved versus applied, inherited/default distinction, Off suspension, configured-only warning, safe stopped saves, ambiguity/reconciliation and guarded recovery; retain account/default boundary, privacy and external-editor limitation. Create the report with pending evidence explicitly pending, not invented counts.
- [ ] **Step 3 — complete final automated verification.** Run `npm run companion:test`, `npm run companion:build`, `npm test`, then `npm run companion:package-test` in that order. Expected: complete native and Node suites pass; fresh signed package passes all three cases with zero failures/cancellations/skips. Existing package tests invoke `/usr/bin/codesign --verify --deep --strict` and compare resources. Record actual counts/commands/build identity. Rebuild/retest only when subsequent changes affect those results.
- [ ] **Step 4 — bounded native and private live acceptance.** Freshly inspect selected context, actual saved setup, ownership, provider, listener, package and exact recovery records before live work. Use bounded private ready-schema-2 fixtures and already configured named accounts whose availability is freshly established; do not silently migrate normal legacy configuration. Coordinate explicit human launch/activation/restart/response confirmations where the existing workflow requires them. With On, assign → switch → remove on one identified project and show saved/running state plus initiating request evidence for each; successful assignment changes themselves require no Codex restart. Verify Off suspension, stopped Save/next Start Off, configured-only warning and unavailable-control presentation. Keep original recovery context and perform exact Direct restoration/manual response confirmation/guarded Stop and private fixture cleanup. Record human observations separately from automated transport evidence; qualify cancelled initiating requests and do not claim independent billing or general cross-account continuation. If a required live prerequisite/observation is unavailable, report it as incomplete and do not claim full acceptance.
- [ ] **Step 5 — finish documentation and commit.** Record only performed checks, actual outcomes, exact recovery and limitations. Verify artifact/local Markdown references and `git diff --check`; stage Task 8 paths only and commit with `git commit -m "feat: verify companion assignment editing"`. Preserve private raw evidence outside Git, completed branding branch and historical reports. No push/merge.
- [ ] **Step 6 — sole sequential final gate.** Use `personal-workflows:code-review` on the complete assignment branch against its recorded implementation base and the approved pair. Dispatch specification review first; dispatch quality only after specification PASS. Follow the current workflow for findings/re-review and archive only actual reviews/results. Do not reopen completed predecessor reviews or count task checks/builder completeness as final approval. Commit required fixes/documentation locally, run affected checks and finalize the current gate against the actual resulting branch/package.
- [ ] **Step 7 — report and stop.** Verify final local commits/status, main unchanged since execution preflight, the separate branding branch, actual package/evidence match and exact recovered operational state. Report delivered behavior, commands/results, human observations, incomplete evidence/limitations and local commit IDs. Stop before another increment, push or merge.

## Criterion traceability

| Specification | Tasks and principal evidence |
|---|---|
| AC-01 | 1, 7, 8 — transformation, stable-ID editor actions and native/live assign/switch/remove |
| AC-02 | 2–6, 8 — request barriers, durable publication, owned protocol and live application |
| AC-03 | 3, 5, 6, 8 — stopped helper, Direct/port guards and next Start Off |
| AC-04 | 4, 6–8 — authoritative state, independent controller facts and presentation |
| AC-05 | 1, 6–8 — healthy configured-only catalog, identity rejection and selected-row repair |
| AC-06 | 1, 3, 8 — exact-key/shared-binding/optional-presence and persistence tests |
| AC-07 | 2, 8 — deterministic auth/identity/credential/stream and reused-connection barriers |
| AC-08 | 1, 3–6 — source/catalog revisions, locking, session/generation and stale reply tests |
| AC-09 | 3–8 — injected persistence phases, lost acknowledgment, no retry and truthful UI |
| AC-10 | 3–7 — settled read reconciliation, readiness mismatch and Direct recovery access |
| AC-11 | 6, 8 — exact transition continuity versus recovery drift and account/default regressions |
| AC-12 | 3–6, 8 — locks, helper/child exit, relaunch, unowned survivor and explicit startup |
| AC-13 | 2, 4, 6, 8 — authentication/pairing/no fallback and ownership/Stop/Quit regressions |
| AC-14 | 7, 8 — native presentation, signed confined package, private live evidence and docs |

## Self-review and approval handoff

Planning self-review checks: all AC IDs map to tasks/tests; all five Review Focus cases have owners; shared contracts use consistent names/null semantics; fault outcomes distinguish replacement from certainty; no task reloads accounts/defaults or changes predecessor approval scope. Full execution tier follows material data/security/concurrency risks; lite is ineligible. No extra plan-review agent or implementation gate is introduced.

**Current stage:** 4 — specification and plan separately approved; Subagent-driven selected explicitly through the native interactive control. The user's `approved` after this plan's presentation establishes plan approval. Both artifacts are to be committed together on the assignment implementation branch before product changes. No further artifact approval is needed within the approved scope; push and merge remain unauthorized.

**Execution endpoint:** Deliver this one assignment-editing flow with safeguards, documentation, fresh verification, the sole sequential final specification/quality review and local commits; report results/limitations and exact recovery, then stop before later work, push or merge.
