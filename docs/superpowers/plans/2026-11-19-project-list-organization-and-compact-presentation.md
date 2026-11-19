# Project List Organization and Compact Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved increment-4 project list with compact saved-account grouping, conservative chat-state organization, reliable running-assignment warnings, editing, search, and disclosures.

**Architecture:** Keep catalog identity/assignment authority separate from optional chat-activity presentation. A read-only Node observer joins the supported legacy membership profile to SQLite snapshots; bounded owned-channel pages supply runtime summaries from the retained immutable configuration. Native presentation combines those independent observations while preserving editor authority and stable row/disclosure state.

**Tech Stack:** Existing Node 24 (`>=24 <25`), built-in `node:sqlite`, smol-toml 1.9.1, Swift 6 package using Swift language mode 5, SwiftUI/AppKit/XCTest, macOS 14+ on Apple silicon. No new dependency.

**Spec:** `docs/superpowers/specs/2026-11-19-project-list-organization-and-compact-presentation.md`

**Slug:** `project-list-organization-and-compact-presentation`

**Status:** APPROVED

**Created:** 2026-11-19

**Updated:** 2026-11-19

**Provenance:** The approved specification, its recorded discovery evidence, and read-only planning at `b735f37825d527f937bba85093fd37b96cd7361c`. The user's “Please implement the plan.” approved the preceding Stage 2 specification; this implementation plan had not yet been presented.

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Subagent-driven, explicitly selected by the user after separate plan approval. Full-tier implementers use the managed `gpt-6.1-sol` model. Preserve per-task reviews and the sole integrated final review.

## Global Constraints

- Work only on the approved increment. All discovered/configured catalog entries remain accessible; manual hiding and later roadmap work remain deferred.
- “Active” means **unarchived**. Missing referenced rows, including deletion leftovers, remain visible as unknown. No age, name, root-path, timestamp or foreground inference.
- Section order: **Needs attention**, **Custom account**, **Default account**, **No active chats**. Unclassifiable policy takes precedence over inactive status. Empty sections are omitted.
- Exact copy: **Uses default**; **Accounts selected for individual projects.**; **No active chats (N)**; **Projects with no chats or only archived chats.**
- Explicit selection of the current default remains custom. Off does not change grouping or assignments. Legacy inheritance stays inherited; missing bindings never become inheritance silently.
- Activity/list observation grants no assignment-write or routing authority. Preserve existing source/catalog guards, reconciliation, account/default setup, Direct recovery and projectless request behavior.
- Keep catalog identity/name revisions unchanged by activity. Preserve the existing visible/hidden 2/5-second polling cadence, 16 KiB channel frames, 32 KiB retained buffers, and existing five-second operation deadlines.
- The observer adds no state writes, transcript scanning, visibility database, metadata repair, second membership backend, or new production dependency.
- Work in the existing checkout. Do not update main, create a branch or commit until separate plan approval. No worktree, push or merge.

## Review Focus

1. A deleted chat leaves a global membership behind: Task 1/2 tests keep it unknown even when index health says complete; disappearance must not be mistaken for archival.
2. A running-account label comes from another saved table, child or page generation: Tasks 3/4 reject mixed observations and retain the runtime's own account names and default.
3. A project changes policy/activity while its editor is open: Tasks 5/6 pin placement without pinning authority, rebasing drafts or weakening save checks.
4. Filtering/collapse hides actionable projects or double-counts previews: Tasks 5/6 test hidden-warning summaries, matches/total, temporary expansion and one full-row identity.
5. A large list or worst-case Unicode label exhausts the channel or blocks controls: Tasks 3/4 test eight-entry frames and a single observation deadline; Tasks 5/6 test at least 200 projects.

---

## Evidence, artifact resolution, and planning decisions

The specification is NEW_ONLY at the explicit Spec path, saved with approved requirements unchanged. Plan resolution was MISSING; this new plan uses the specification's exact basename and date. The exact legacy paths are absent and no competing Slug/Spec reference was found. Both files remain uncommitted.

Planning HEAD is `b735f37825d527f937bba85093fd37b96cd7361c` on clean main before saving the specification; local origin/main matched. No fetch, main update, implementation branch, product change, test/build, operational mutation or commit occurred in planning.

Architecture map `docs/architecture/map.md` is absent, so its recorded HEAD/freshness are unavailable. No ADR/architecture decision artifacts were found in docs or conventional `docs/adr`, `docs/adrs`, `docs/decisions` locations. There is no discovered accepted ADR constraint. Do not generate a map. Key paths checked at the planning HEAD: catalog/config/companion inspection; identity and assignment persistence; managed channel/parser; native channel/backend/controller/wire validation; controls/editor; shared fixtures; package source allowlists and verification guidance.

Command evidence: `package.json` defines `npm test`, `npm run companion:test`, `npm run companion:build`, and `npm run companion:package-test`. Focused Node commands below use that existing `node --test` runner and test directory; focused Swift commands use the existing Swift package/XCTest targets and the same `--filter` form used by earlier approved plans. `companion/README.md:278–308` documents native → build → Node → package verification. The package file currently has three top-level tests and explicit source lists; preserve their lifecycle/cleanup checks and require no skipped package acceptance tests.

No material product decision remains unresolved. Engineering choices within the approved scope:

- Initial negative classification supports exactly the profile recorded in the specification; unknown/newer profiles stay visible. Fixed reason codes distinguish missing, conflicting, unsupported, changing and unavailable data.
- Use two observation attempts within a 250 ms retry budget, yielding once between attempts. This bounds retries, not synchronous SQLite execution; the existing five-second inspect-helper deadline remains the outer bound. Set SQLite busy timeout to 0. No retry of a mutating operation is introduced.
- Compare two minimal SQLite projections around the relevant JSON read, not whole-database modification counters alone. Unrelated tokens/title/recency writes must not invalidate activity. Detect database path replacement using the opened database file's identity before/after the observation.
- Runtime pages contain at most **8** requested project IDs, with one **1-second aggregate deadline** per list read. Do not extend it per page. Preserve the existing five-second maximum for each channel operation; observation calls use the earlier aggregate deadline. Unknown on exhaustion is preferable to blocking controls.
- Read all catalog IDs, not only search matches or expanded rows. Reuse existing `AssignmentSummary` validation/shape and pure summary logic; alias-only differences are technical detail. Keep runtime tokens private to evidence binding and out of view models/logging.
- Render real shared native views against synthetic controllers for UI inspection. This requires no production Codex/router mutation. Label fixture inspection separately from live production observations.

## File responsibilities and interface contracts

| Files | Responsibility |
|---|---|
| New `src/project-activity.js`; new `test/project-activity.test.js`, `test/helpers/project-activity.js` | Pure supported-profile classification, read-only consistent observation and isolated synthetic fixtures |
| `src/project-catalog.js`, `src/companion.js`; companion inspection tests | Optional activity enrichment without changing pure catalog/revision or assignment authority |
| `src/project-assignments.js`, `src/managed-serve.js`; managed-server tests | Reuse the existing pure assignment summary; add bounded runtime-only observation pages |
| New `companion/Sources/CompanionCore/ProjectListTypes.swift`; `WireTypes.swift`, `RouterModeChannel.swift`, `ProcessBackend.swift`, `RouterController.swift`; core tests | Activity decoding, strict runtime page validation, owned-child aggregation, private evidence binding and public display state |
| New `companion/Sources/CodexProjectRouter/ProjectListPresentation.swift`, `ProjectListView.swift`; `ControlsView.swift`; app tests | Pure grouping/search/issues, transient layout state, compact rows and disclosure/editor integration |
| `scripts/build-companion.mjs`, `test/companion-package.test.js`; new package probe helper | Bundle the new observer and exercise relocated/source-denied observation without production data |
| `docs/operating-guide.md`, `companion/README.md`; new validation report | User behavior, support limitations, actual verification evidence and closeout |

### Activity contract

`ChatActivity = {state: 'unarchived' | 'no_active_chats' | 'unknown', reason: null | 'metadata_unavailable' | 'incomplete_metadata' | 'missing_record' | 'conflicting_membership' | 'unsupported_metadata' | 'changed_during_read' | 'project_unresolved'}`. Known states require null reason; unknown requires a listed reason. No raw chat IDs, paths, SQL errors or state fragments are included in this wire value.

- `classifyProjectActivitySnapshot({state, codexHome, threads, spawnEdges, backfillStatus}) -> Map<normalizedProjectUUID, ChatActivity>` is pure and implements the specification's full evidence table.
- `readProjectActivitySnapshot(codexHome, {fs, openDatabase, now, yieldOnce} = {}) -> Promise<{state, activityByProject}>` supplies fresh raw global state in memory plus classified activity; dependencies default to existing platform APIs and permit deterministic race tests. These hooks are local evidence boundaries, not a general storage abstraction.
- `inspectProjectCatalog(codexHome, cfg, {includeActivity = false} = {})` preserves its current default and pure `inspectProjectCatalogValue`. With enrichment enabled, project from the observer's same state snapshot and attach `entry.chatActivity`; configured-only entries get unknown/project_unresolved. Existing catalog revision computation is unchanged.
- `inspectCompanion` enables enrichment only for schema-2 account-mode browsing, including its browseable incomplete/invalid setup states. Legacy/no-selected-config inspection retains its existing payload and setup flow. The read-only activity path is never called by assignment authority helpers or the request resolver.
- Native `Inspection.Entry.chatActivity: ChatActivity?` is optional. Omission, unknown extension values or malformed observation-only data maps to unknown rather than breaking independently valid browsing. Validate legal combinations strictly before accepting a known state; do not relax other inspection validation.

Relevant JSON projection: normalized discovered project identities; direct assignments; host map; projectless IDs; the configured home's identity bridge and every owner-scoped migration checkpoint for that home. Project names remain catalog evidence but do not establish activity; roots/recency/read-state are irrelevant. Require the recorded signed-out legacy checkpoint; incompatible additional owner checkpoints are unsupported. Validate duplicate normalized identities and contradictory claims. Non-local/missing host evidence affects its project. Unlocalizable malformed/alternative membership evidence is a global negative-classification barrier.

SQLite projection: required `threads` fields from the specification, complete spawn edges regardless of status, and `backfill_state.status`. A nonnull canonical `project_id` localizes unsupported membership through the validated bridge; mark both known sides unknown on disagreement, or all negative candidates unknown if localization is impossible. Known internal records require consistent source/role/parent evidence; every missing directly referenced row is unknown. CLI/exec/other old or new source forms are not silently treated as supported desktop records. Valid unambiguous unarchived evidence may establish the positive state; a conflict involving that membership cannot. A candidate with no positive evidence may collapse only after all relevant negative-proof checks pass.

Read JSON → SQLite transaction/projection A → JSON → fresh SQLite transaction/projection B → final relevant JSON comparison; compare normalized projections and file identities. Return the newest valid global snapshot only with appropriate activity evidence. Missing/unreadable activity schema degrades activity; loss of readable/valid project discovery retains catalog-unavailable behavior. After two changing observations return unknown/changed_during_read. No cached absence survives a refresh.

### Runtime read-only channel contract

Add ready capability `project_list_v1` only alongside existing `project_assignments_v1` for ready account routing. New native code accepts exactly the original no-capability frame, the existing v1-only list, or the ordered current two-capability list; reject unknown/duplicate capability forms. Unsupported children remain browseable with list-wide runtime confirmation unavailable. This does not authorize adoption of an external listener.

Request: existing schema/session/request envelope with `action: 'get_project_list'`, `expectedContext`, `projectIds` (0–8 distinct valid UUIDs), and explicit nullable `expectedSnapshot`.

`expectedSnapshot` is null on the first page; later pages require exact `{runningRevision, runningIdentity, runningFingerprint, mode}` from page one. The response type is `project_list_state`, with `state` containing exactly `{context, runningRevision, runningIdentity, runningFingerprint, mode, defaultAccount, entries}`. Each entry is exactly `{projectId, assignment}` using existing `AssignmentSummary`. Return requested IDs in request order, once each; all names/defaults come from the retained running configuration. No full account table, endpoint, credential reference, chat evidence or source bytes cross this channel.

A valid but stale/wrong-context request returns type `project_list_unavailable` with fixed code `PROJECT_LIST_CHANGED` or `PROJECT_LIST_UNAVAILABLE` and no state. Malformed protocol closes control as before. Handle every new read explicitly before the existing mutation branch: it must not call persistence, publication, incoming/outgoing credentials, change last-attempt state, or reconcile an uncertain save.

Native types: `ProjectListSnapshotToken`, `RunningProjectListPage`, and `RunningProjectListObservation` carry validated evidence inside CompanionCore. Public view state is `ProjectListRuntimeState.unconfirmed | .notRunning | .observed(ProjectListRunningAssignments)`; `ProjectListRunningAssignments` contains only mode, default account and the project-summary dictionary, without comparison tokens.

New `ProjectListBackend.readRunningProjectList(_ child: OwnedRouter, projectIDs: [String], deadline: Date) async throws -> RunningProjectListObservation` is separate from the existing backend protocols. ProcessBackend deduplicates IDs, pages by eight, validates exact coverage/one token across pages, checks exact owned child before and after every await, and publishes no partial collection. Empty catalogs can use one empty page when metadata is needed. Channel cancellation/timeout is observational only and cannot mark assignment or mode mutations uncertain.

Controller collection shares the existing inspection slot and generation/sequence checks. Collect after ordinary authoritative assignment/mode reconciliation when not busy; skip extra list I/O during mutation/preflight. Retain prior list evidence only while its child/context/saved baseline and runtime tokens still match; otherwise expose unconfirmed until a fresh read. Read divergence even when saved-vs-running readiness fingerprints differ. A list failure never calls `inspectionFailed`, erases healthy editor evidence, clears pending operations, or blocks guarded recovery. After a save, stale list evidence becomes unconfirmed until the next normal refresh; the editor retains its existing immediate save-result presentation.

## Execution preflight — only after separate plan approval

- [ ] Identify this saved specification and plan, quote their separate approval messages, and record the selected execution method. Mark this plan APPROVED only from actual approval evidence.
- [ ] Load `personal-workflows:spec-implement` and its selected bases then. Full tier is required by metadata/concurrency/protocol work; resolve the managed `full` role at execution. Inline execution cannot switch the parent model.
- [ ] Recheck `git status --short --branch`, `git rev-parse HEAD main origin/main` and the baseline's relevant paths. Preserve both artifacts and unrelated changes. Only now fetch with `git fetch origin main`; on main, use `git merge --ff-only origin/main` if safe. On divergence or conflicting local edits preserve evidence and resolve rather than reset/force/stash destructively.
- [ ] Review any new base changes for plan impact. Ensure `feat/project-list-organization` is unused, then `git switch -c feat/project-list-organization main`. Do not create a worktree.
- [ ] Stage only the approved pair and commit with `git commit -m "docs: approve project list organization increment"` before product changes. No push or merge of the implementation branch.

### Task 1: Define conservative activity classification [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data,migrations]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-06, AC-07, AC-15

**Files:** Create `src/project-activity.js`, `test/project-activity.test.js`, `test/helpers/project-activity.js`. Consume `src/config.js` UUID validation and `test/helpers/fixtures.js` without changing request-identity fixtures globally. Risk: incomplete or incorrectly attributed metadata could conceal a project.

**Interfaces:** Produce the pure classifier/ChatActivity contract above. Test helper `projectActivityFixture(t)` extends a private fixture with the recorded full schema, host/checkpoint/bridge shape and methods to save state and replace chat rows; it never reads the real Codex home.

- [ ] **Step 1 — write failing classification cases.** Name cases `supported empty archived and mixed projects`, `deleted referenced chat remains unknown`, `explicit direct membership never expands ancestry`, `unsupported source and owner checkpoint stay visible`, and `canonical conflicts cannot establish absence`. Pin regular user/agent-created roots, `has_user_event = 0`, case duplicates, malformed archive values, projectless conflicts, remote/missing hosts, configured-only identity and complete-backfill-with-missing-row behavior.

```js
assert.deepEqual(result.get(P1.toLowerCase()), {state: 'no_active_chats', reason: null});
assert.deepEqual(deleted.get(P2.toLowerCase()), {state: 'unknown', reason: 'missing_record'});
assert.equal(mixed.get(P1.toLowerCase()).state, 'unarchived');
assert.equal(unsupported.get(P1.toLowerCase()).state, 'unknown');
```

- [ ] **Step 2 — run RED.** `node --test test/project-activity.test.js`. Expected: the new classifier import/assertions fail before implementation; no production state touched.
- [ ] **Step 3 — implement the pure classifier.** Implement the exact supported profile and reason codes; scope uncertainty by stable identity when possible and apply a global negative barrier otherwise. Keep source/internal-role checks explicit; never use names, paths, age, `has_user_event`, missing rows or completed edges as shortcuts.
- [ ] **Step 4 — run GREEN.** Repeat Step 2. Expected: every table case passes, including a positive unarchived case with unrelated incomplete evidence and a conflicting-membership case that cannot claim that positive state.
- [ ] **Step 5 — commit Task 1 paths only.** `git commit -m "feat: classify project chat activity conservatively"`.

### Task 2: Integrate coherent read-only activity observation [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,data]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-07, AC-13, AC-15, AC-16

**Files:** Extend `src/project-activity.js`; modify `src/project-catalog.js`, `src/companion.js`, `scripts/build-companion.mjs`, `test/companion-package.test.js`; extend `test/project-activity.test.js`, `test/companion.test.js`, `test/companion-cli.test.js`, `test/project-assignments.test.js`; create `companion/Sources/CompanionCore/ProjectListTypes.swift`, modify `WireTypes.swift` and `ProcessBackend.swift`, and create `companion/Tests/CompanionCoreTests/ProjectListTypesTests.swift`. Risk: combining changing stores or coupling display reads to editing guards.

**Interfaces:** Produce the snapshot reader and optional enriched entry/native ChatActivity contracts; preserve pure catalog and all revision contracts. Add `project-activity.js` to both explicit production source allowlists in this task, before bundled code depends on it.

- [ ] **Step 1 — write RED integration/race tests.** Add `activity snapshots detect membership archive and file replacement races`, `unrelated token and read-state changes preserve activity`, `settled archive unarchive move and deletion converge on refresh`, `activity failure preserves catalog and editing revision`, and `legacy payload and missing observation remain browseable`. In the lifecycle fixture, keep saved configuration bytes fixed: a sole unarchived chat in A makes A unarchived/B empty; archive makes both no-active; unarchive restores A; move makes A empty/B unarchived; delete its row while retaining membership makes B unknown/missing_record. Check a fresh catalog after each settled change, unchanged catalog revision and unchanged assignments. Use injected read/clock/database boundaries instead of timing sleeps. Assert two-attempt/250 ms retry limits, close/rollback on every path, old-schema unknown, changed global discovery unavailable, and no file-byte mutation. Update schema-2 exact payload expectations to include activity; do not add activity to legacy/no-config payloads.
- [ ] **Step 2 — run RED.** `node --test test/project-activity.test.js test/companion.test.js test/companion-cli.test.js test/project-assignments.test.js`; `swift test --package-path companion --filter ProjectListTypesTests`. Expected: new observation/decode assertions fail, while existing catalog authority assertions retain their meaning.
- [ ] **Step 3 — implement observation and enrichment.** Use read-only SQLite with busy timeout zero, the stated bookended projections/file identity checks and bounded attempts. Never create the database on a read. Keep Node authority callers on default un-enriched catalog reads. In Swift, accept only validated known states; absent/unsupported activity is unknown without making valid browsing unavailable.
- [ ] **Step 4 — run GREEN.** Repeat Step 2. Expected: race/degradation/immutability checks pass; activity-only refresh leaves catalog identity tokens and editing eligibility unchanged.
- [ ] **Step 5 — commit explicit Task 2 paths.** `git commit -m "feat: observe project chat status without changing catalog authority"`. Defer full package verification until a matching app is rebuilt in Task 7; do not misreport stale-package failures as product regressions.

### Task 3: Add bounded runtime-only assignment pages [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,concurrency]

**Acceptance criteria:** AC-02, AC-09, AC-10, AC-14, AC-15, AC-16

**Files:** Modify `src/project-assignments.js`, `src/managed-serve.js`, `test/managed-serve.test.js`; extend `ProjectListTypes.swift` and `RouterModeChannel.swift`; extend `ProjectListTypesTests.swift` and `RouterModeChannelTests.swift`. Risk: malformed observation frames entering the mutation branch or weakening bounded ownership/session validation.

**Interfaces:** Export the existing pure `assignmentSummary(config, projectId)` for reuse. Produce `get_project_list`, the capability/page/token shapes above, and channel `readProjectList(projectIDs: [String], expectedSnapshot: ProjectListSnapshotToken?, deadline: Date) async throws -> RunningProjectListPage`. Preserve every existing command/result shape.

- [ ] **Step 1 — write RED protocol tests.** Add `runtime list reads retained accounts without editor selection`, `observation cannot mutate or settle pending assignment`, `list frames reject duplicate unknown and oversized selections`, and `old capabilities retain existing operations`. Test 0/8/9 IDs, maximum-length Unicode account names and 64-character aliases, stale snapshot/wrong context/session, reordered/missing/extra reply IDs, late retired replies, unknown capabilities, Off with explicit-current-default policy, and missing targets. Byte-check worst-case frames against 16 KiB and retained buffers against 32 KiB. Assert zero commit/publication/credential/upstream calls from observation.
- [ ] **Step 2 — run RED.** `node --test test/managed-serve.test.js`; `swift test --package-path companion --filter RouterModeChannelTests`; `swift test --package-path companion --filter ProjectListTypesTests`. Expected: new capability/read tests fail before handlers exist.
- [ ] **Step 3 — implement explicit bounded read handling.** Project only the retained immutable runtime configuration. Validate the optional expected token before responding; reject stale reads without mutation bookkeeping. Reuse exact AssignmentSummary/context/name/token validation and add a separate native observation operation/value/capability path. Honor the earlier supplied deadline; do not mark observational cancellation as mutation uncertainty.
- [ ] **Step 4 — run GREEN.** Repeat Step 2. Expected: old mode/assignment tests and all new bounded-read tests pass, with strict malformed-frame behavior unchanged.
- [ ] **Step 5 — commit explicit Task 3 paths.** `git commit -m "feat: expose bounded owned-runtime project summaries"`.

### Task 4: Bind list-wide runtime evidence to controller refresh [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,performance]

**Acceptance criteria:** AC-04, AC-09, AC-10, AC-13, AC-14, AC-15, AC-16

**Files:** Modify `ProcessBackend.swift`, `RouterController.swift`, `ProjectListTypes.swift`; create `companion/Tests/CompanionCoreTests/ProjectListObservationTests.swift`; extend `ProcessBackendTests.swift`, `RouterControllerTests.swift`, and the controlled `Fixtures/node-fixture` only for the new declared protocol behavior. Risk: stale pages/children or observation failures corrupting editor authority and reconciliation.

**Interfaces:** Produce `ProjectListBackend.readRunningProjectList` and the public token-free `projectListRuntimeState` property; retain raw observation tokens privately. Consume Task 3 pages and existing assignment evidence, inspection slot and generation/sequence guards.

- [ ] **Step 1 — write RED controller/backend cases.** Add `200 projects use bounded pages on one owned channel`, `changed token child context or sequence discards whole observation`, `list timeout does not revoke assignment or recovery evidence`, `external saved edit remains observable while readiness differs`, and `save refreshes warnings without rebasing editor`. Assert one aggregate 1-second deadline, 25 pages for 200 distinct IDs, no process per row, no partial publication, unsupported capability fallback, no extra list reads during busy preflight, and stale evidence removal after save/exit/context change. Verify running labels/default come from running data, including unchanged account IDs with differing saved names.
- [ ] **Step 2 — run RED.** `swift test --package-path companion --filter ProjectListObservationTests`; `swift test --package-path companion --filter ProcessBackendTests`; `swift test --package-path companion --filter RouterControllerTests`. Expected: missing backend/property assertions fail; preserve existing test semantics for mutation/recovery.
- [ ] **Step 3 — implement the separate read backend and controller binding.** Aggregate eight-ID pages on the exact owned channel with one deadline and token. Collect only in ordinary refresh, without fingerprint-match readiness as observation authority. Install only complete current-generation evidence. Use existing safe stopped/port proof for not-running; external/unknown ownership is unconfirmed. List failures change list display state only; no persistence, adoption, helper replay, second reader or new polling loop.
- [ ] **Step 4 — run GREEN.** Repeat Step 2. Expected: old safety tests and new generation/deadline tests pass; a list error cannot settle an uncertain assignment or create editing eligibility.
- [ ] **Step 5 — commit explicit Task 4 paths.** `git commit -m "feat: reconcile project-list runtime observations safely"`.

### Task 5: Define grouping, issues, search and transient placement [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-08, AC-09, AC-10, AC-11, AC-12, AC-13, AC-14

**Files:** Create `companion/Sources/CodexProjectRouter/ProjectListPresentation.swift` and `companion/Tests/CompanionAppTests/ProjectListPresentationTests.swift`. Consume existing entry/account summaries, optional ChatActivity and Task 4 token-free runtime state. No controller authority logic belongs in this file.

**Interfaces:** `ProjectListSectionKind` has attention/custom/default/noActive. `ProjectListPresentation` is a value initialized with `init(inspection: Inspection?, runtimeState: ProjectListRuntimeState, selectedAssignment: AssignmentState?, assignmentStatus: RouterController.AssignmentStatus, assignmentError: String?, pendingProjectID: String?)`. It exposes `sections(state: ProjectListViewState) -> [ProjectListSection]` and `hiddenActionableProjectCount(state: ProjectListViewState) -> Int`. Each `ProjectListSection` has `kind`, `rows`, `problemPreviews`, `countText` and `notices`; row IDs are stable project IDs. `ProjectListViewState` holds query, inactive expansion, disclosed project IDs and optional `ProjectListPin(projectID: String, section: ProjectListSectionKind, index: Int)`, with mutating `beginEditing(projectID: String, displayedSections: [ProjectListSection])` and `endEditing()`. Keep row issues, shared section notices and neutral unknown-activity indications distinct; these values confer no editing authority.

- [ ] **Step 1 — write RED table tests.** Add `policy precedence and named-default grouping`, `missing policy and unresolved projects remain recognizable`, `runtime policy differs even when effective account matches`, `collapsed previews count once`, `search matches all fields and restores expansion`, and `pinned editor uses fresh values at old placement`. Assert explicit selection of today's default stays custom and retains its selected account after the default changes; inherited rows follow the new default. Assert exact copy, all four section positions, legacy flat browse fallback, default name once, alias-only detail, unknown status, all-empty/no-results/unavailable distinctions, localized tie behavior, 200 entries, duplicate/long names, and a hidden-warning clear-search action. Assert each catalog identity appears once before filtering and preview identity is not counted twice.

```swift
XCTAssertEqual(sections.map(\.kind), [.attention, .custom, .default, .noActive])
XCTAssertEqual(filteredInactive.countText, "2 of 8")
XCTAssertEqual(collapsedInactive.problemPreviews.map(\.id), [problemID])
XCTAssertEqual(pinnedRow.section, originalSection)
XCTAssertEqual(afterDismissalRow.section, latestSection)
```

- [ ] **Step 2 — run RED.** `swift test --package-path companion --filter ProjectListPresentationTests`. Expected: missing projection/types fail.
- [ ] **Step 3 — implement the pure presentation/state transforms.** Follow saved policy precedence and stable sorting, then apply pin placement before search/counts. Use exact policy/account IDs and running default for semantic comparison; keep normal Off/stopped and shared read failure at section/global level. Only per-project actionable issues produce collapsed previews. Keep “Chat status unknown” neutral and explain its fixed reason on demand. Pinning never freezes fresh saved policy/warnings; flag pending movement with “List position updates when editing closes.”
- [ ] **Step 4 — run GREEN.** Repeat Step 2. Expected: classification, runtime difference, filtered warning and editor pin cases pass deterministically without a live backend.
- [ ] **Step 5 — commit Task 5 paths only.** `git commit -m "feat: project compact account sections and searchable warnings"`.

### Task 6: Integrate compact native rows without disrupting editing [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-08, AC-09, AC-10, AC-11, AC-12, AC-13, AC-14, AC-15, AC-16

**Files:** Create `companion/Sources/CodexProjectRouter/ProjectListView.swift`; modify `ControlsView.swift`; extend `ControlsPresentationTests.swift`, `ProjectAssignmentPresentationTests.swift`; create `companion/Tests/CompanionAppTests/ProjectListLayoutTests.swift`. Leave the existing editor's save/selection semantics intact. Risk: SwiftUI identity changes dismissing/resetting an editor or repeating its save task.

**Interfaces:** `ProjectListView(controller:editingProjectID:canOpenEditor:onEdit:)` owns transient list state. ControlsView keeps ownership of `assignmentProject` and the existing sheet; the child's Edit callback pins the row before opening it, and observing dismissal releases the pin. Shared layout/row components serve both full rows and issue previews; their accessibility identifiers use stable project IDs.

- [ ] **Step 1 — write RED interaction/layout tests.** Add `sheet survives refresh save movement and discovery failure`, `collapse previews retain edit and disclosure access`, `search expansion clears without losing chosen disclosure`, and `long names and 200 project rows preserve actions`. Use controlled backend barriers and host the real ProjectListView/ControlsView in native NSHostingView fixtures. Assert existing editor selection/save count and stale guards; exercise keyboard focus/accessible names for search, section toggle, Edit and details. Render representative 720×640 minimum-window fixtures into ignored `companion/.build/project-list-qa/` with synthetic names only, including collapsed problems, expanded inactive rows, search counts, runtime/default discrepancies and a long-name list.
- [ ] **Step 2 — run RED.** `swift test --package-path companion --filter ProjectListLayoutTests`; `swift test --package-path companion --filter ControlsPresentationTests`; `swift test --package-path companion --filter ProjectAssignmentPresentationTests`. Expected: new integrated view/layout assertions fail before replacement.
- [ ] **Step 3 — integrate the view.** Replace only the flat project-list block and its obsolete list-only helpers/state. Preserve routing/setup/recovery sections, navigation, sheet ownership, refresh and app lifecycle. Keep collapsed previews and shared notices outside hidden disclosure content; expanded rows replace previews. Key disclosure state by UUID, wrap long names, and avoid clipped/fixed-height warning rows. Remove dead flat-list helpers/tests rather than adding compatibility wrappers used only by tests.
- [ ] **Step 4 — run GREEN and inspect native artifacts.** Repeat Step 2; inspect every generated fixture image with the available local-image viewer, correcting truncation/overlap and verifying controls remain usable. Record fixture-native observations separately from packaged/live app evidence. Expected: all targeted tests pass, one explicit save occurs, and the rendered result satisfies compactness/visibility at minimum and larger sizes.
- [ ] **Step 5 — commit explicit Task 6 paths.** `git commit -m "feat: integrate compact project list and stable editing"`.

### Task 7: Verify packaged behavior, document and close the increment [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-10, AC-14, AC-15, AC-16, AC-17

**Files:** Extend `test/companion-package.test.js`; create `test/helpers/project-list-package-probe.mjs`; update `docs/operating-guide.md`, `companion/README.md`; create `docs/validation/project-list-organization.md`; update lifecycle/evidence metadata on this approved pair after actual results. No production fixture/credential/provider changes.

**Interfaces:** The package probe accepts explicit relocated router-root and temporary fixture-root arguments like the existing projectless probe. It imports only the relocated production modules plus Node built-ins. Extend the existing relocated/source-denied top-level package scenarios rather than adding a second unbounded lifecycle harness.

- [ ] **Step 1 — add package assertions before final acceptance.** Exercise supported empty/archived/mixed/deleted-reference fixtures through bundled inspection, plus runtime pages from the bundled managed child. Compare source/provider/config bytes, assert no incoming/outgoing credential or upstream calls from reads, and retain existing projectless original/default/override checks. Prove all new source modules are in the explicit bundle allowlist and work when checkout reads are denied. Use existing owned-process/port cleanup, deadlines and source-denial helpers.
- [ ] **Step 2 — write user documentation and the validation matrix.** Explain all section/unknown/default/search/count/disclosure behavior and the deletion exception; record the exact narrow checkpoint/source compatibility boundary. Include AC-01–AC-17 evidence slots marked unobserved until run, the sanitized experiment outcomes, synthetic/native/package distinctions and any limitations. Do not repeat a real experiment or imply routing acceptance from labels.
- [ ] **Step 3 — run the required final chain in order.** `npm run companion:test` → `npm run companion:build` → `npm test` → `npm run companion:package-test`. Expected: every command exits 0; a current matching app is ad-hoc signed; all three top-level package acceptance tests run without skips; existing routing/assignment/recovery/projectless regressions pass. Capture exact commands, exit statuses and decisive lines. Do not reuse historical counts. If new fixes are required, rerun the affected checks and the final current-source chain before reporting success.
- [ ] **Step 4 — finish evidence and commits.** Record actual native image inspection, supported/unknown cases, immutable file checks, tests and any unobserved live behavior. Confirm source/package correspondence and clean owned synthetic processes/ports. Stage only task changes and commit with `git commit -m "test: verify and document project list organization"`.
- [ ] **Step 5 — perform the sole integrated final review.** Invoke `personal-workflows:code-review` exactly once as the selected implementation base's final whole-branch seat: specification reviewer first, quality reviewer only after specification PASS, one immutable review package and current verification evidence. Apply the enclosing base's fix-loop/follow-up policy; do not add a generic equivalent final reviewer. Commit required fixes and documentation updates and retain review evidence.
- [ ] **Step 6 — reach the authorized endpoint.** Only after required review, use the selected branch-finishing workflow with the user's existing ruling: retain local commits; no push/merge/worktree. Report the working list, how it was verified, deletion/unsupported-profile limitations, actual test/UI evidence, local branch/commits and provisional later-work implications. Stop before the next increment.

## Acceptance traceability

| Criteria | Owning task/test evidence |
|---|---|
| AC-01, AC-02 | Tasks 3/5 policy and runtime comparison tables; Task 6 editor/default regression |
| AC-03, AC-05 | Tasks 1/2 activity/lifecycle fixtures; Task 7 relocated equivalent; discovery experiment remains separately labeled |
| AC-04, AC-07 | Tasks 1/2 malformed/missing/racing/unsupported input tests; Task 4 observation-failure isolation |
| AC-06 | Task 1 direct-membership/source/parent tables, including completed edges and zero user-event flags |
| AC-08, AC-09 | Tasks 5/6 section/copy/unique-row/layout checks |
| AC-10 | Tasks 3/4 all-project runtime reads; Task 5 semantic differences and inherited-default coverage |
| AC-11, AC-12 | Tasks 5/6 preview/search/count/hidden-warning and disclosure-state cases |
| AC-13 | Tasks 2/4 authority isolation; Tasks 5/6 pin/draft/save/discovery-failure tests |
| AC-14 | Task 3 frame bounds, Task 4 200-ID batching/deadline, Tasks 5/6 long-list/native interaction |
| AC-15 | Tasks 1/2 file immutability, Task 3 zero-mutator reads, Task 4 no authority changes, Task 7 package byte checks |
| AC-16, AC-17 | Task 7 current-source ordered checks, required final review and documentation; targeted regressions in Tasks 2–6 |

## Self-review and approval handoff

Self-review completed against the approved specification: all AC-01–AC-17 and the five Review Focus cases map to task assertions; commands match the current runners and package guidance; shared interfaces and task dependencies agree. Review made the presentation/channel signatures explicit and added direct archive/unarchive/move/delete refresh assertions and explicit-current-default retention coverage. Seven bounded deliverables carry RED/GREEN checks and local commits; the plan contains contracts and assertions rather than implementation bodies. No planning subagent was dispatched. Task risk domains explain full-tier routing; no lite eligibility is claimed.

Current evidence: read-only repository inspection and the saved approved specification only. Tests, builds, product changes, implementation commits and new live observations are UNRUN. This describes the planning baseline; subsequent execution evidence belongs in the validation report and execution ledger.

**Execution endpoint:** Deliver only this increment, verification, documentation, required review and authorized local commits; report evidence and limitations, then stop. Do not push, merge or start later roadmap work.

**Approval evidence:** After this separate plan was linked and presented at Stage 3, the user replied **“approve”**. The user then explicitly selected **“Subagent-driven (recommended): independent implementation and review per task; higher context cost.”** Stage 4 is authorized for this saved specification/plan pair. No push or merge is authorized.
