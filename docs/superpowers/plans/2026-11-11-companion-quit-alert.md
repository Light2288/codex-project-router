# Companion Blocked-Quit Alert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Explain a denied Quit with a native alert and a clear route to existing Controls, preserving the controller's exit safeguards.

**Architecture:** Add a read-only blocking-reason projection to the existing controller. Present fixed native alert content from the common application Quit path and retain one synchronous request guard through the entire attempt and alert response. Use small defaulted presentation/action closures for deterministic app tests, without adding a new service or changing routing authorization.

**Tech Stack:** Swift 6 toolchain, Swift language mode v5, SwiftUI/AppKit, XCTest, macOS 14+, installed Node 24, existing Node test/build/package scripts.

**Spec:** `docs/superpowers/specs/2026-11-11-companion-quit-alert.md`

**Slug:** `companion-quit-alert`

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-12

**Provenance:** Implements only the alert increment confirmed by the user's `confirmed` and the subsequently presented specification approved by `approved`, both on 2026-11-11. The completed companion specification/plan and `docs/validation/companion-operational-controls.md` remain prerequisite evidence, not tasks to repeat. No plan approval or implementation authorization is inferred from those messages.

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Preserve the user's explicitly selected Subagent-driven method: a fresh implementer and independent task review, followed by the required sequential final review. The user approved the separately presented plan on 2026-11-12.

## Global Constraints

- Native title **Cannot quit yet**; actions **Open Controls** and **Keep Running**. No **Quit Anyway**.
- Observed-case message: **Direct-response confirmation is pending. Open Controls to complete the check.**
- Preserve controller reconciliation, authorized child-stop behavior, ownership checks, confirmation rules and initialization-failure/second-instance safe exits. Do not change `canQuit`, `requestQuit()` authorization, journal schema, or normal window refresh semantics.
- Fixed sanitized messages only; no private paths, project IDs/mappings, endpoints, credentials, references, raw exceptions or subprocess output.
- Use synthetic private state and positively tracked test processes. No real proxy activation, gateway calls, credential access, Codex restart or model prompt is needed for this increment.
- Existing checkout only. Preserve the completed companion branch; no worktree, force update, push or merge. Gate-required fast-forward maintenance of local main is permitted only after this plan is approved.
- Defer diagnosis of reopened confirmation, relaxing Quit guards, account/default/assignment editing, notification redesign and startup integration.

## Review Focus

1. Two Quit calls before the first Task begins must claim only one request synchronously — `testQuitClaimsSynchronouslyAndIgnoresRepeatedRequests`.
2. A held backend attempt or modal alert must not allow nested termination requests to queue more operations — `testHeldQuitAndAlertRejectReentrantTermination`.
3. Live backend uncertainty can precede the copied controller flag; feedback must prefer reconciliation — `testQuitBlockReasonUsesLiveBackendUncertainty`.
4. State becoming safe while an alert is open must not cause an automatic retry or exit — `testStateChangeDuringAlertDoesNotRetryOrTerminate`.
5. Missing/conflicting context or a failed child stop must not falsely prescribe direct confirmation — `testQuitBlockReasonUnavailableAndFailedStop` and `testFixedAlertCopyAndCancelBinding`.

---

## Evidence, boundaries and file responsibilities

Inspection baseline: `feat/companion-operational-controls`, HEAD `c2887a5bcb4248b81f769be8fe7fc4485ecdf7e8`; local main and origin/main both `66cc1c9e24361ea3dd807e4ade2c8a2f37317220`. Only this specification was untracked before planning. These are inspected local refs, not a fresh remote synchronization.

Artifact resolution: specification NEW_ONLY at the explicit Spec path; plan MISSING before creation, using its exact basename. No legacy candidates or conflicting same-slug artifacts were found. Architecture map `docs/architecture/map.md` and ADR documents are absent; no map freshness claim or regeneration applies. Current controller, delegate, test targets and package scripts supply the architecture evidence.

| File | Responsibility |
|---|---|
| `companion/Sources/CompanionCore/RouterController.swift` | Read-only reason projection using existing private evidence |
| `companion/Tests/CompanionCoreTests/RouterControllerTests.swift` | Reason/precedence/no-side-effect regressions with existing controlled backend/barriers |
| `companion/Sources/CodexProjectRouter/QuitAlert.swift` (new) | Native alert factory containing fixed messages/buttons |
| `companion/Sources/CodexProjectRouter/RouterApp.swift` | Common Quit coordination and small injectable native actions |
| `companion/Tests/CompanionAppTests/QuitAlertTests.swift` (new) | App coordination, copy and action tests with private synthetic fixtures |
| `companion/Tests/CompanionAppTests/ControlsPresentationTests.swift` | Existing last-window-close regression retained |
| `companion/README.md` | Explain blocked Quit and its two actions |
| `docs/validation/companion-quit-alert.md` (new) | Sanitized fresh evidence, review dispositions and limits |

Commands below are grounded in `package.json`, `companion/Package.swift`, `companion/README.md` and `docs/validation/companion-operational-controls.md`. The Swift `--filter` pattern is already used for `RouterControllerTests`; `QuitAlertTests` will be a new class in the existing app test target. No new script, dependency or production test mode is needed.

## Execution preflight — only after explicit plan approval

- [ ] Record both approved artifact paths and their separate approval messages; update plan lifecycle metadata only after approval. Recheck branch, diff, HEAD and dependencies. Preserve unrelated edits.
- [ ] Safely refresh main using `git fetch origin`, `git switch main`, then `git merge --ff-only origin/main`. Stop on divergence or checkout conflicts without discarding work. Do not merge the companion into main.
- [ ] Create the stacked implementation branch with `git switch -c fix/companion-quit-alert c2887a5bcb4248b81f769be8fe7fc4485ecdf7e8`. This explicit prerequisite contains the unmerged companion that main lacks. If upstream changes invalidate that dependency or require material plan changes, report the conflict before proceeding; do not silently rebase or change scope.
- [ ] Commit the approved specification and plan on that branch with `git add docs/superpowers/specs/2026-11-11-companion-quit-alert.md docs/superpowers/plans/2026-11-11-companion-quit-alert.md` and `git commit -m "docs: approve companion quit alert specification and plan"`. Expected: artifact-only commit; prerequisite branch remains intact.

### Task 1: Project the existing Quit blocking condition [size: S | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-02, AC-03, AC-05, AC-06

**Files:** Modify controller and its core test file listed above.

**Interfaces:** Produces nested `public enum RouterController.QuitBlockReason: Equatable` with cases `operationInProgress`, `directConfirmationPending`, `directRecoveryRequired`, `contextUnavailable`, and `public var quitBlockReason: QuitBlockReason? { get }`. Consumes current controller/backend evidence only; no helper calls or persistence.

- [ ] **Step 1: Write focused failing reason tests.** Reuse `makeController()`, `activated()`, `ControlledBackend` and `Barrier` in `RouterControllerTests`. Seed a temporary journal before controller creation for pending/no-child cases. Named tests and required assertions:

```swift
// testQuitBlockReasonDirectPendingIsReadOnly: clean Direct, pending journal, no child
XCTAssertEqual(controller.quitBlockReason, .directConfirmationPending)
XCTAssertFalse(controller.canQuit)
XCTAssertEqual(try store.load(), journalBefore)
XCTAssertEqual(backend.inspectedPaths.count, inspectionsBefore)
XCTAssertEqual(backend.controls.count, controlsBefore)
XCTAssertEqual(backend.stopCount, stopsBefore)
// testQuitBlockReasonRecoveryAndBusyPriority: active/recovery evidence, then held action
XCTAssertEqual(controller.quitBlockReason, .directRecoveryRequired)
// while the controlled action is held:
XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
// testQuitBlockReasonUsesLiveBackendUncertainty: flip backend flag without refresh
XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
// testQuitBlockReasonUnavailableAndFailedStop: each unavailable/conflicting context,
// missing revision, and denied child-stop fixture uses the generic fallback
XCTAssertEqual(controller.quitBlockReason, .contextUnavailable)
// testQuitBlockReasonPermittedExceptions: normal permitted, failed init, second instance
XCTAssertNil(controller.quitBlockReason)
```

Also compare desktop confirmation, recovery context and `quitRequested` before/after repeated getter reads; projection must leave them unchanged. Retain existing authorization assertions in all fixtures. Set live backend uncertainty in a retained-recovery fixture as well to prove precedence over confirmation/recovery advice.

- [ ] **Step 2: Run RED.** `swift test --package-path companion --filter RouterControllerTests`. Expected: compilation fails specifically for the missing reason API; record this before adding product code.
- [ ] **Step 3: Implement the projection.** Priority: safe initialization/second-instance exits → nil; busy or copied/live backend uncertainty → operation; otherwise `canQuit` → nil; unusable/unmatched/unreadable context or missing revision → unavailable; `cleanDirect(context)` with retained pending/recovery → direct confirmation; readable router/prepared/active/recovery-required evidence → direct recovery; remaining denial, including failed stop → unavailable. Keep this a computed read-only property; never derive exit permission from it.
- [ ] **Step 4: Run GREEN.** Repeat the focused Swift command. Expected: all controller tests pass, including unchanged stop/Quit guards and all new reason/no-side-effect assertions.
- [ ] **Step 5: Commit and independently review this task.** `git add companion/Sources/CompanionCore/RouterController.swift companion/Tests/CompanionCoreTests/RouterControllerTests.swift` then `git commit -m "feat: expose sanitized companion quit blocking reasons"`. Expected: task-only commit. Apply the selected task review workflow before Task 2, without an extra user approval gate.

### Task 2: Present one native alert and verify the complete increment [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08

**Risk:** AppKit modal run loops, asynchronous controller operations and application termination callbacks can reenter Quit. Hold one synchronous guard through presentation and response handling; prove that behavior with held boundaries.

**Files:** Create `QuitAlert.swift`, `QuitAlertTests.swift` and validation report; modify `RouterApp.swift` and companion README. Retain the existing window-close test. Do not change `ControlsView.swift`, backend/wire code, operational state or prior validation reports.

**Interfaces:** Consumes Task 1's reason API. Produce `@MainActor enum QuitAlert` with `static func make(reason: RouterController.QuitBlockReason) -> NSAlert`. Extend the internal delegate initializer with defaulted closures:

```swift
init(controller: RouterController,
     presentQuitAlert: @escaping @MainActor (NSAlert) async -> NSApplication.ModalResponse = {
         NSApp.activate(ignoringOtherApps: true)
         return $0.runModal()
     },
     showControls: (@MainActor () -> Void)? = nil,
     terminate: @escaping @MainActor () -> Void = { NSApp.terminate(nil) })
@discardableResult func requestQuit() -> Task<Void, Never>?
```

Nil `showControls` invokes existing `openControls()`. Default paths remain native; tests inject closures and await the returned task. Add only private per-test fixture/barrier support in the new test file, following the existing temporary store/backend patterns; no production protocol or generalized coordinator.

- [ ] **Step 1: Write failing app tests.** `QuitAlertTests` constructs alerts without presenting real modal UI; delegate tests use injected presentation/window/termination spies and a synthetic `CompanionBackend`. Assert named cases:

```swift
// testFixedAlertCopyAndCancelBinding (all four reasons; exact direct case below)
XCTAssertEqual(alert.messageText, "Cannot quit yet")
XCTAssertEqual(alert.informativeText,
    "Direct-response confirmation is pending. Open Controls to complete the check.")
XCTAssertEqual(alert.buttons.map(\.title), ["Open Controls", "Keep Running"])
XCTAssertEqual(alert.buttons[1].keyEquivalent, "\u{1b}")
// testOpenControlsAndKeepRunningActions: separately first, second and abort responses
XCTAssertEqual(showControlsCount, expectedOpenCount) // 1 for first button; otherwise 0
XCTAssertEqual(terminateCount, 0)
XCTAssertEqual(try store.load(), journalAfterDeniedAttempt)
XCTAssertEqual(backend.controls.count, controlsAfterDeniedAttempt)
// testQuitClaimsSynchronouslyAndIgnoresRepeatedRequests
let first = delegate.requestQuit()
XCTAssertNotNil(first)
XCTAssertNil(delegate.requestQuit()) // before the first task gets actor time
// testHeldQuitAndAlertRejectReentrantTermination: repeat at held inspect and held alert
XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
XCTAssertNil(delegate.requestQuit())
// after releasing each held boundary: one attempt/stop and one alert, no queued work
XCTAssertEqual(presentCount, 1)
// testStateChangeDuringAlertDoesNotRetryOrTerminate: make state safe while held;
// release Keep Running, await returned task, assert no second attempt and no exit
XCTAssertEqual(terminateCount, 0)
// testSuccessfulAndSafeExceptionQuitsSkipAlert: normal, failed init, second instance
XCTAssertEqual(presentCount, 0)
XCTAssertEqual(terminateCount, 1)
```

For each alert reason assert its fixed message below and absence of a synthetic private sentinel. Inject that sentinel into backend error/context fixtures to show alert content is independent of raw state. Verify actions leave confirmation/recovery untouched; counters are captured after the existing denied attempt so its authorized inspect/stop behavior is not mistaken for an alert side effect. Hold stop as well as inspection in the reentrancy test, and check exactly one stop. Preserve `testClosingLastWindowDoesNotRequestQuit` and test the common termination callback's success path returns `.terminateNow` only after existing authorization.

- [ ] **Step 2: Run RED.** `swift test --package-path companion --filter QuitAlertTests`. Expected: compilation fails for the new alert/initializer/request return API before product changes.
- [ ] **Step 3: Implement fixed native content.** Use `NSAlert`, warning style, specified title and button order, Return for Open Controls and Escape for Keep Running. The other messages are exactly:
  - operation: “A router operation is still running or needs reconciliation. Open Controls to review its status.”
  - recovery: “Direct recovery is incomplete. Open Controls to restore the direct connection, then complete the manual restart and response check.”
  - unavailable: “Quit could not be completed safely. Open Controls to review the current status and recovery guidance.”
- [ ] **Step 4: Coordinate the common Quit path.** Claim `quitInProgress` synchronously before creating the returned Task; repeated requests return nil. Clear it with `defer` after the controller attempt and any alert response/action. Await unchanged `controller.requestQuit()`. If `quitRequested && canQuit`, set existing `terminationApproved` and call injected terminate without alert. Otherwise capture current reason (fallback unavailable), await one alert, reveal Controls only for `.alertFirstButtonReturn`, and return without retry or rechecking for automatic exit. All other/cancel responses keep running. Preserve menu/keyboard/common termination routing and existing window behavior.
- [ ] **Step 5: Run focused GREEN.** `swift test --package-path companion --filter QuitAlertTests`, then `swift test --package-path companion --filter ControlsPresentationTests`. Expected: all new app cases and existing four presentation cases pass; no real modal window or process exit in unit tests.
- [ ] **Step 6: Document user behavior.** Update companion README with the title/actions, unchanged guards, successful-exit behavior, and the requirement to complete existing recovery/confirmation in Controls. Do not claim the reopened-confirmation cause was fixed.
- [ ] **Step 7: Run fresh acceptance checks.** Run sequentially: `npm run companion:test`, `npm test`, `npm run companion:build`, `npm run companion:package-test`, `node --check src/cli.js`, `git diff --check`. Expected: all native/Node tests pass; fresh app builds and is ad-hoc signed; all three package tests pass with zero skips; syntax/whitespace exit 0. Earlier recorded counts are context, not this run's results. No broader repeat is needed absent changes/failures.
- [ ] **Step 8: Observe isolated native behavior.** Reuse the synthetic relocation/Seatbelt procedure in `test/companion-package.test.js` (native source-denial test) for a private one-off fixture runner. Use temporary `HOME` plus `CFFIXED_USER_HOME`, owner-only config/catalog/provider/journal, a matching pending `direct_confirmation` and Direct provider, installed Node, no listener start, denied real Codex/router private paths and checkout access, outbound denied except loopback. Prove the exact tracked native PID holds the synthetic instance lock before interacting. Select the exact running app path for UI automation; retain only sanitized observations, not raw accessibility state. Check menu Quit and Cmd-Q with Controls open, closed and minimized; exact observed-case alert; Open Controls reveals it; Keep Running/Escape preserve window visibility; repeated Quit produces one alert. Assert synthetic provider/config bytes unchanged and no child listener. Clean up only the tracked synthetic process (bounded termination if pending state prevents ordinary exit). No real operational file changes, provider activation, credentials, desktop restart or gateway/model check. If a platform interaction cannot be established, keep it explicitly unverified rather than substituting automated claims.
- [ ] **Step 9: Record evidence and commit.** Create `docs/validation/companion-quit-alert.md` with actual commands/results, RED/GREEN, native observations, untouched-operational-state safeguards and limitations. Keep raw fixture paths/checkpoints outside Git. `git add companion/Sources/CodexProjectRouter/RouterApp.swift companion/Sources/CodexProjectRouter/QuitAlert.swift companion/Tests/CompanionAppTests/QuitAlertTests.swift companion/README.md docs/validation/companion-quit-alert.md` then `git commit -m "fix: explain blocked companion quit with a native alert"`. Expected: increment-only changes, with no private fixture or unrelated product edits. Independently review the task using the selected workflow.
- [ ] **Step 10: Complete the final sequential review.** Use `personal-workflows:code-review`: specification review first, quality review only after its passing disposition. Review the entire alert increment from prerequisite `c2887a5` through current HEAD with both approved artifacts and fresh evidence; disclose the unmerged prerequisite and reference its completed report rather than repeating its review. Resolve findings within this scope, rerun affected checks after fixes, and preserve reviewer dispositions in the new validation report with a final documentation commit. No additional user gate between ordinary tasks; material scope/spec/plan changes retain their required approval gates.

## Criterion traceability

| Criterion | Task / evidence |
|---|---|
| AC-01 | Task 2 common Quit tests plus native menu/Cmd-Q and window-state observations |
| AC-02 | Task 1 direct-pending projection; Task 2 exact copy and native fixture |
| AC-03 | Task 1 priority/unavailable cases; Task 2 fixed sanitized message assertions |
| AC-04 | Task 2 action/cancel counters, journal/confirmation invariants and native window observations |
| AC-05 | Task 1 permitted-exception/no-mutation cases; Task 2 success/exception/common callback and existing close test; full native regressions |
| AC-06 | Task 1 projection invariants; Task 2 pre-task, held inspect/stop/alert and state-change regressions |
| AC-07 | Task 2 focused/full checks, fresh build/package, isolated native check and README/report |
| AC-08 | Task 2 sequential final specification/quality dispositions and final delivery report |

## Self-review and execution endpoint

Self-review completed against AC-01–AC-08: all covered; signatures agree across tasks; five Review Focus cases have named tests; commands follow current repository scripts/test targets; tests/fixtures and docs stay within alert scope. No material product decision remains unresolved. Native modal visibility remains a verification obligation, not a planning claim.

Deliver the reviewed alert, tests, fresh build/package/native evidence and documentation; commit on the stacked fix branch, report the working result and honest limits, and stop. Do not publish, merge, investigate confirmation recurrence or begin a later increment. The companion prerequisite remains a separate unmerged branch.

**Current stage:** Stage 4 — after this plan was separately presented, the user replied `approved` on 2026-11-12. This authorizes implementation of the approved specification/plan pair using the preserved Subagent-driven method and Git constraints. No push or merge is authorized.
