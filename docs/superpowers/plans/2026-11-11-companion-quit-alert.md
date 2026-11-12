# Companion Quit Behavior and Blocked-Quit Alert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow verified idle direct-state Quit without a desktop restart or response check, preserving pending recovery and existing owned-listener protection.

**Architecture:** Extend the private store with a non-creating read of existing recovery evidence. Add a narrowly scoped controller authorization acquired only by a fresh explicit Quit attempt; reuse the existing application termination flow. Update only conditional Controls guidance that would otherwise falsely require confirmation before an eligible idle exit; retain the existing blocked alert and its coordination.

**Tech Stack:** Swift 6 toolchain, Swift language mode v5, SwiftUI/AppKit, XCTest, macOS 14+, installed Node 24, existing Node test/build/package scripts.

**Spec:** `docs/superpowers/specs/2026-11-11-companion-quit-alert.md`

**Slug:** `companion-quit-alert`

**Status:** APPROVED — revision 2 approved 2026-11-12

**Created:** 2026-11-11

**Updated:** 2026-11-12

**Provenance:** Revision of the existing same-path plan for specification revision 2, explicitly approved by the user's `approved` after its presentation on 2026-11-12. Original alert-only specification/plan approvals and implementation remain in Git history. The user's `ok, resolve that Quit behavior before refining the alert` confirmed the revised scope. Approval of the original plan does not authorize these additional tasks; this revised plan requires its own approval.

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Preserve the user's explicitly selected Subagent-driven method: fresh implementer and independent review per task, then the sole final sequential specification/quality gate. No new execution-method selection is needed.

## Global Constraints

- No owned router remains; a retained process handle whose exit has not been established does not count as absence.
- No controller mutation or child-stop operation is in progress; live or copied backend uncertainty cannot be bypassed.
- Fresh matching configuration/context, direct provider settings, recovery-required false, record absent/restored and usable revision are required for the added exit.
- Any pending recovery information to retain has a valid durable private journal consistent with that context. A memory-only obligation does not qualify.
- Successful idle Quit does not clear the pending journal, mark desktop confirmation complete, or report that Codex has loaded direct settings.
- Preserve owned-listener shutdown, direct-only start, normal exit, initialization-failure and second-instance exceptions. No external listener adoption or termination.
- Retain native title **Cannot quit yet**, actions **Open Controls** and **Keep Running**, and current fixed descriptions for remaining guarded states. No **Quit Anyway**, label change or step navigation in this revision.
- Use synthetic private state and positively tracked processes. No real activation/configuration change, gateway call, Keychain access, Codex restart or model prompt is required.
- Existing checkout and `fix/companion-quit-alert` branch; preserve work. No worktree, push or merge. Do not repeat initial branch creation or update main merely to resume this approved increment.

## Review Focus

1. A journal deleted, replaced, linked or corrupted after controller initialization must not qualify from its in-memory copy — Task 3 `testReadExistingNeverCreatesOrRepairsEvidence`, Task 4 `testIdleQuitRejectsChangedDurableJournal`.
2. A prior eligible-looking snapshot or successful authorization must not survive a changed revision/context or failed fresh inspection — Task 4 `testIdleQuitRequiresFreshMatchingEvidence`.
3. Live backend uncertainty newer than the copied controller flag must deny exit — Task 4 `testIdleQuitCannotBypassBusyOrLiveMutation`.
4. Child death plus failed journal persistence must not lose an obligation that exists only in memory — Task 4 `testIdleQuitRejectsMemoryOnlyRecovery`.
5. Eligibility becoming true while an existing alert is held must not cause an automatic retry or termination — Task 4 `testStateChangeDuringAlertDoesNotRetryOrTerminate`.

---

## Resolution, baseline and completed work

Artifact pair: NEW_ONLY specification and NEW_ONLY plan at the paths above, exact shared slug and Spec reference; no legacy/conflicting candidates. Preserve both basenames and Created dates. Architecture map `docs/architecture/map.md` and ADR documents are absent; no freshness claim/regeneration applies. Inspected key paths are the controller/store, native delegate/Controls, XCTest targets, package scripts and validation report.

Baseline: HEAD `54b6018e2c4dbca4f5d78dac72adb86abae14e3c`, branch `fix/companion-quit-alert`. Only the revised specification was modified before planning. This stacked branch retains the unmerged companion prerequisite `c2887a5`; main is not assumed to contain it.

| Original task | Established implementation and task review | Resume instruction |
|---|---|---|
| 1 — reason projection | `9ce48b8`, independent task review passed | Preserve; adjust affected assertions only for the newly approved permission |
| 2 — native alert | `dd16096`, independent task review passed; evidence updates `39f3a72`, `54b6018` | Preserve implementation; carry remaining verification/final gate into Task 5 |

Do not redispatch or recreate those tasks. Previously observed verification: 85 native, 664 Node and three package tests passed, with a signed build. User confirmed Escape dismisses the alert and leaves Controls minimized. Closed-window preservation is not separately human-confirmed. Why confirmation reopened is unproven. Fresh revised-behavior evidence is still required.

## File responsibilities

| File | Change |
|---|---|
| `companion/Sources/CompanionCore/PrivateStore.swift` | Non-creating read of existing safe journal |
| `companion/Tests/CompanionCoreTests/PrivateStoreTests.swift` | Read-only/durability/privacy boundary tests |
| `companion/Sources/CompanionCore/RouterController.swift` | Fresh idle Quit authorization, invalidation and unavailable-evidence reason |
| `companion/Tests/CompanionCoreTests/RouterControllerTests.swift` | Permission, retention, denied cases and relaunch regressions |
| `companion/Tests/CompanionAppTests/QuitAlertTests.swift` | New idle success; preserve denied-alert tests using genuinely guarded fixtures |
| `companion/Sources/CodexProjectRouter/ControlsView.swift` | Conditional guidance only, including its existing presentation model |
| `companion/Tests/CompanionAppTests/ControlsPresentationTests.swift` | Guidance and truthful pending-state regression |
| `companion/README.md`, `docs/validation/companion-quit-alert.md` | Operational explanation, new evidence and final dispositions |

The delegate, alert factory, backend, wire schema and router/provider implementation need no production change. No new dependency or journal schema is planned. Any concrete need to change these boundaries must be explained before broadening edits.

Commands below are grounded in `package.json`, `companion/Package.swift`, companion README and the prior validation report. Focused commands use the existing Swift `--filter` convention with classes already in configured test targets. Record full commands, actual exits and decisive proof lines; do not substitute prior counts for new runs.

## Resume preflight — after revised plan approval

- [ ] Record revision 2 spec approval and the separate revised-plan approval; update lifecycle metadata. Recheck HEAD/status and preserve changes. Original main refresh/stacked branch creation are already complete; continue this branch without repeating them.
- [ ] Resume this plan's existing SDD workspace/ledger, preserving original task reports/reviews. Add Tasks 3–5 and their baselines; do not overwrite or replay Tasks 1/2. Commit only the approved revised pair with `git add docs/superpowers/specs/2026-11-11-companion-quit-alert.md docs/superpowers/plans/2026-11-11-companion-quit-alert.md` and `git commit -m "docs: approve idle companion quit correction"`. Expected: artifact-only commit, other work intact.

### Task 3: Read existing recovery evidence without creating state [size: S | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,data]

**Acceptance criteria:** AC-03, AC-09, AC-10

**Risk:** This method supplies private-file authority; creating missing evidence or bypassing no-follow/owner/mode checks could incorrectly authorize exit. Keep existing validation and writer semantics intact.

**Files:** Modify `PrivateStore.swift`; test `PrivateStoreTests.swift`.

**Interfaces:** Produce module-internal `func readExisting() throws -> CompanionJournal`. It returns the existing validated journal or throws `CompanionError.privateState`; never creates a directory, journal or lock. Reuse `readJournal` and validation. Give private `openDirectory` a `createIfMissing: Bool = true` parameter; false omits mkdir/create-directory behavior while retaining owned, mode-0700, no-follow checks. Existing callers keep their default creating behavior.

- [ ] **Step 1: Add failing store tests**, with literal temporary fixtures and these named assertions:

```swift
// testReadExistingReturnsPendingJournalWithoutWriting
XCTAssertEqual(try store.readExisting(), expectedPendingJournal)
XCTAssertEqual(try Data(contentsOf: state), originalBytes)
XCTAssertEqual(try entries(directory), originalEntries)
// testReadExistingNeverCreatesOrRepairsEvidence: missing directory, then missing state
XCTAssertThrowsError(try store.readExisting())
XCTAssertFalse(FileManager.default.fileExists(atPath: missingPath.path))
// testReadExistingRejectsUnsafeEvidence: corrupt, symlinked, multiply linked,
// non-private mode and over-64-KiB state; each remains byte/directory unchanged
XCTAssertThrowsError(try store.readExisting()) { XCTAssertEqual($0 as? CompanionError, .privateState) }
```

Use a local test directory-listing helper `entries(_ directory: URL) throws -> [String]` with sorted names. Reuse current corruption/link fixtures; no foreign-UID claim without direct evidence. Include unsafe/symlinked directory rejection and assert that invalid input is not replaced. Expected values come from fixture literals, not store serialization under test.

- [ ] **Step 2: Run RED:** `swift test --package-path companion --filter PrivateStoreTests`. Expected: missing `readExisting` API diagnostic before implementation.
- [ ] **Step 3: Implement the interface** in `PrivateStore.swift`, reusing safe bounded read/decode checks. Missing evidence throws; existing `load`, `save`, locking, atomic replacement and schema remain unchanged.
- [ ] **Step 4: Run GREEN:** repeat the focused command, then `npm run companion:test`. Expected: new and existing store/native tests pass without warnings; no journal creation by `readExisting`.
- [ ] **Step 5: Commit and task-review:** `git add companion/Sources/CompanionCore/PrivateStore.swift companion/Tests/CompanionCoreTests/PrivateStoreTests.swift`, then `git commit -m "feat: inspect existing companion recovery without writes"`. Require independent task spec/quality dispositions before Task 4; no extra user gate.

### Task 4: Authorize the narrow idle direct exit and preserve guarded alerts [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,data]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-09, AC-10

**Risk:** Permission must bind fresh inspection and durable evidence across actor suspension, background refresh and termination callbacks. Journal matching is part of this same permission boundary; filesystem safety is owned by Task 3.

**Files:** Modify controller, `RouterControllerTests.swift` and `QuitAlertTests.swift`. No production delegate or alert factory change.

**Interfaces:** Consume Task 3 `PrivateStore.readExisting()`. Preserve public `canQuit`, `quitRequested`, `quitBlockReason`, `requestQuit() async` and delegate `requestQuit() -> Task<Void, Never>?`. Add private `idleQuitAuthorized` and `idleQuitJournalUnavailable` flags, private computed `hasIdleDirectQuitContext: Bool`, and private `authorizeIdleDirectQuit() -> Bool`. These are controller implementation details, not new user APIs.

- [ ] **Step 1: Add failing behavioral controller/app regressions.** Seed owner-only valid pending journals before controller creation. Required names and decisive assertions:

```swift
// testIdleQuitPreservesPendingRecovery: all journal phases; matching Direct none/restored
let bytesBefore = try Data(contentsOf: state)
await controller.requestQuit()
XCTAssertTrue(controller.quitRequested)
XCTAssertTrue(controller.canQuit)
XCTAssertNil(controller.quitBlockReason)
XCTAssertEqual(try Data(contentsOf: state), bytesBefore)
XCTAssertNotEqual(controller.desktopConfirmation, .confirmedDirect)
XCTAssertTrue(backend.controls.isEmpty)
XCTAssertEqual(backend.stopCount, 0)
// testIdleQuitRequiresFreshMatchingEvidence: old display Direct, new snapshot
// routed/prepared/conflicting/unavailable, changed config/home/provider/port,
// missing revision, or inspection failure; each must deny without clearing evidence
XCTAssertFalse(controller.quitRequested)
// testIdleQuitRejectsChangedDurableJournal: delete, corrupt or valid-but-different
// journal AFTER initialization; no recreation/repair, generic unavailable reason
XCTAssertEqual(controller.quitBlockReason, .contextUnavailable)
// testIdleQuitCannotBypassBusyOrLiveMutation: held action, then live/copied flags
XCTAssertFalse(controller.quitRequested)
XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
// testIdleQuitRejectsMemoryOnlyRecovery: failed pending save + unexpected child exit
XCTAssertFalse(controller.quitRequested)
// testIdleQuitRelaunchRetainsPending: release first instance, recreate from same store
XCTAssertNotEqual(relaunched.desktopConfirmation, .confirmedDirect)
XCTAssertEqual(try store.readExisting().pending, expectedPending)
XCTAssertTrue(backend.controls.isEmpty)
// testIdlePendingQuitTerminatesWithoutAlert (real delegate/controller, injected exit)
XCTAssertEqual(terminateCount, 1)
XCTAssertEqual(presentCount, 0)
```

Also verify a second fresh explicit Quit succeeds, journal bytes stay unchanged across relaunch, and no automatic start/stop/confirmation occurs. Include external listener readiness with no owned child: it is never adopted/signalled. Existing never-activated start-only and owned activated/restored pending tests must keep their stop permissions. Update the old projection-only test's post-Quit expectation to the new eligible success while preserving all getter no-side-effect assertions.

In app tests, move denied direct-pending fixtures to a real guarded synthetic owned child: create the pending controller, then call its existing `start()` using `QuitBackend`. Capture counters after fixture setup; do not weaken presentation assertions or fake controller permission. For the reason-copy table use separate controlled fixtures so one case's state cannot authorize another.

Revise `testStateChangeDuringAlertDoesNotRetryOrTerminate`: start pending with backend mutation uncertainty, hold the real denied alert, then clear uncertainty and refresh. Dismissal must neither terminate nor inspect/retry again; a subsequent explicit Quit obtains fresh evidence and succeeds without another alert. Retain held inspection/stop/reentrant request, safe-exception and last-window-close coverage.

- [ ] **Step 2: Run RED:** `swift test --package-path companion --filter RouterControllerTests`, then `swift test --package-path companion --filter QuitAlertTests`. Expected: new eligible-exit assertions fail under the old blanket pending guard; record those behavioral failures before controller edits. Fix test setup errors before proceeding.
- [ ] **Step 3: Implement permission acquisition.** `hasIdleDirectQuitContext` checks usable state, no owned child, matching retained/durable journal context, `cleanDirect`, usable revision and no copied/live uncertainty; it must not depend on `busy` being false while executing the current Quit action. `authorizeIdleDirectQuit()` additionally compares `try store.readExisting()` with the full current in-memory journal and records authorization only on an exact match. Catch failures as fixed private-state/unavailable feedback; never rewrite evidence. Require a successful fresh action-time inspection before invoking this method. A missing durable pending obligation cannot qualify.
- [ ] **Step 4: Integrate and invalidate authorization.** Preserve the existing normal exit path; add the new alternative to `canQuit` only while idle, with matching current direct evidence and live backend certainty. Reset the private authorization/failure flags when `begin()` starts another explicit operation. Invalidate authorization on failed inspection, relevant revision/context/provider change, changed recovery evidence or child ownership/exit change. An unchanged/coalesced poll alone must not revoke a just-completed valid attempt. `requestQuit()` sets `quitRequested` only after either established normal permission or the fresh new authorization. `quitBlockReason` remains read-only; unavailable journal evidence precedes direct-confirmation advice. Preserve existing owned stop, confirmation and journal mutation logic.
- [ ] **Step 5: Run GREEN:** repeat both focused Swift commands, then `npm run companion:test`. Expected: all old and new native tests pass, including adjusted guarded-alert fixtures; no pending evidence or confirmation consumed by idle Quit. Review the complete native output for failures, not only the focused counts.
- [ ] **Step 6: Commit and task-review:** `git add companion/Sources/CompanionCore/RouterController.swift companion/Tests/CompanionCoreTests/RouterControllerTests.swift companion/Tests/CompanionAppTests/QuitAlertTests.swift`, then `git commit -m "fix: permit verified idle companion quit with pending recovery"`. Require independent spec/quality task review before Task 5.

### Task 5: Present truthful conditional guidance and verify the whole increment [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-03, AC-04, AC-05, AC-07, AC-08, AC-09, AC-10

**Files:** Modify `ControlsView.swift`, `ControlsPresentationTests.swift`, companion README and existing validation report. Parent owns isolated native orchestration and final integrated review after implementer report.

**Interfaces:** Add `ControlsPresentation.recoveryGuidance: String?` and `ControlsPresentation.quitGuidance: String`. Use existing controller public evidence; do not add a permission API or perform storage I/O from presentation. Replace the existing unconditional orange recovery text and confirmation-section footer with these properties.

- [ ] **Step 1: Add failing presentation tests.** Add a localized private fixture `withPendingDirectController(_ body: (RouterController, DisplayBackend, PrivateStore) async throws -> Void) async throws` that seeds matching pending Direct state; use literal synthetic context. `testIdlePendingGuidanceDoesNotDemandConfirmationToQuit` asserts the two idle messages below, pending/unknown confirmation, and no native action, confirmation or store mutation from presentation. `testOwnedPendingGuidanceRetainsShutdownCheck` uses a synthetic owned-child backend fixture to assert that the guarded messages still require a direct-response check. Existing setup, catalog, window-close and polling tests remain unchanged.
- [ ] **Step 2: Run RED:** `swift test --package-path companion --filter ControlsPresentationTests`. Expected: missing guidance property API, before view implementation.
- [ ] **Step 3: Implement conditional guidance.** When recovery context exists, direct confirmation is not recorded, no child is owned and `canConfirmDirectResponse` establishes clean matching Direct evidence, use recovery text **The direct response check is still pending. You can close this idle app after Quit verifies the saved recovery information.** and footer **Closing this idle app does not confirm that Codex has reloaded its settings.** These describe a conditional check, not cached exit authority. For clean Direct with an owned child use recovery text **Direct settings are saved. Confirm a working direct response before Stop or Quit.** Retain the existing guarded footer. For other retained recovery keep existing recovery guidance; for absent/confirmed recovery omit the orange text. Leave alert descriptions, labels, navigation, confirmation buttons and normal window refresh untouched.
- [ ] **Step 4: Run focused GREEN:** repeat the presentation command. Expected: new idle/owned guidance cases and existing presentation tests pass without performing an operation.
- [ ] **Step 5: Document the behavior.** Update companion README: eligible idle Quit needs no restart/model prompt; pending evidence survives and is not a direct-response confirmation; owned-listener shutdown still retains the existing restart/check safeguards; uncertainty/context/storage failures deny the new permission. Preserve prior validation results/limits and accepted-but-deferred Show steps to quit preference.
- [ ] **Step 6: Run fresh acceptance, sequentially:** `npm run companion:test`, `npm test`, `npm run companion:build`, `npm run companion:package-test`, `node --check src/cli.js`, `git diff --check`. Expected: all native/Node tests pass; fresh signed release app; all three package tests pass with zero skips; syntax/whitespace exit 0. Do not repeat full checks without a subsequent change, failure or unresolved concern.
- [ ] **Step 7: Observe isolated native idle Quit and relaunch.** Reuse the prior private relocated-app/Seatbelt fixture procedure from `test/companion-package.test.js` and retained plan workspace. Temporary HOME plus CFFIXED_USER_HOME, owner-only matching pending Direct state, synthetic nonexistent auth command, no listener start, denied real private/checkout paths and non-loopback outbound access. Prove each tracked native PID holds its synthetic lock. Exercise menu and Cmd-Q entry, including closed/minimized Controls. Observe process exit rather than calling getApp/getAX after Quit (that tool can relaunch/restore a window). Verify no blocked alert, provider/config/journal bytes unchanged, no listener, no confirmation input. Relaunch the same fixture journal and observe pending/unknown desktop state with no automatic routing; Quit again. Preserve prior denied-alert/native evidence and its remaining limits; do not infer them from this success case. Clean up only tracked synthetic processes and fixture files. No real operational changes or user Codex restart/prompt.
- [ ] **Step 8: Record and commit evidence.** Update `docs/validation/companion-quit-alert.md` with actual revised RED/GREEN, full commands/exits/results, native idle exit/relaunch and durable-state proof; retain original observations and feedback history. Raw fixture paths/checkpoints stay outside Git. `git add companion/Sources/CodexProjectRouter/ControlsView.swift companion/Tests/CompanionAppTests/ControlsPresentationTests.swift companion/README.md docs/validation/companion-quit-alert.md`, then `git commit -m "fix: distinguish idle quit from confirmed direct recovery"`. Complete the independent task review; resolve any native verification items before marking the deliverable complete.
- [ ] **Step 9: Complete final sequential review.** Invoke `personal-workflows:code-review` once in integrated mode as the sole final whole-increment seat. Package the full `c2887a5..HEAD` alert-plus-behavior diff, approved revised pair, prior task dispositions and fresh evidence. Specification review must pass before quality opens. Resolve findings under the selected execution workflow, rerun affected checks after fixes and commit dispositions to the existing report. Do not repeat prerequisite companion review or dispatch a generic final reviewer. No new user gate between ordinary tasks.

## Criterion traceability

| Criterion | Task / evidence |
|---|---|
| AC-01 | Task 4 delegate success/guarded entry tests; Task 5 isolated native entry/exit observations plus preserved alert evidence |
| AC-02 | Task 4 fresh idle permission and no prompt/confirmation regression |
| AC-03 | Tasks 3/4 unsafe durable evidence and fixed unavailable reason; Task 5 truthful conditional guidance |
| AC-04 | Task 4 retained denied-action/reentry tests; Task 5 unchanged alert factory/labels and window-close regression |
| AC-05 | Task 4 full native normal/exception/owned-child/direct-only guard coverage |
| AC-06 | Task 4 synchronous/held-state/no-auto-retry and later explicit fresh Quit |
| AC-07 | Task 5 full suites, fresh build/package, isolated native observation and docs |
| AC-08 | Task 5 sole sequential final gate, dispositions and delivery report |
| AC-09 | Task 3 non-creating safe read; Task 4 journal equality/bytes/relaunch/memory-only tests; Task 5 native retained-state proof |
| AC-10 | Task 4 failure/context/helper/owned-child matrix; Task 5 conditional guidance |

## Self-review and execution endpoint

Self-review completed: AC-01–AC-10 map to tasks; five Review Focus conditions have named regressions; API names agree across consumers; security file validation is separated from controller concurrency; affected app fixtures are updated in Task 4 so each task can finish with a passing suite. Commands follow existing scripts/targets. Original completed implementation and approval history are preserved without replay. No material product question remains unresolved.

Deliver the defined idle direct exit with durable pending-state retention, preserved listener/alert safeguards, conditional guidance, documentation, fresh checks/native evidence and the final whole-increment sequential review. Report the result and honest limitations; stop before general alert refinement, publication, push, merge or another increment.

**Current stage:** Stage 4 — the revised plan was presented with its path and scope; the user separately replied `approved` on 2026-11-12. This authorizes Tasks 3–5 using the preserved Subagent-driven method on the existing fix branch. The revision 2 specification received its own earlier explicit approval.
