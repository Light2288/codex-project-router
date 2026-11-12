# Companion Quit Dialog and Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Explain denied Quit plainly and take the user to the relevant existing controls without changing Quit authorization.

**Architecture:** Add a read-only app presentation model for fixed guidance and destinations. The existing native alert passes its primary response into transient window-navigation state after a completed inspection. SwiftUI reveals the current target and guidance once per explicit request; the controller retains all operation and permission authority.

**Tech Stack:** Swift 6 toolchain, Swift language mode v5, SwiftUI/AppKit/Observation, XCTest, macOS 14+, installed Node 24 and existing package scripts. No new dependency.

**Spec:** `docs/superpowers/specs/2026-11-12-companion-quit-guidance.md`

**Slug:** `companion-quit-guidance`

**Status:** APPROVED

**Created:** 2026-11-12

**Updated:** 2026-11-12

**Provenance:** Implements the follow-up specification separately presented and explicitly approved by the user's `approved` after scope/design confirmation. The completed `companion-quit-alert` pair and validation remain predecessor evidence. After the separate Stage 3 plan presentation, the user explicitly replied `approved`, authorizing Stage 4 implementation.

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Preserve the user's explicitly selected Subagent-driven method from this continuous workflow: fresh implementer and independent task review, followed by the sole final sequential specification/quality gate. No new method selection is pending.

## Global Constraints

- Keep the warning title **Cannot quit yet**. Use **Show steps to quit** as the first action and Return default, and **Keep Running** as the second action and Escape/cancel binding. No additional alert action is introduced.
- Implement this choice without a separate steps panel, wizard, or duplicate recovery controls.
- A permitted Quit continues to exit without showing this alert.
- The no-owned-router Direct guidance requests another explicit Quit check; it does not authorize exit or promise that durable recovery information is valid.
- Guidance does not retry Quit, grant permission, restore settings, start/stop/adopt a listener, record response confirmation, or clear recovery.
- Retain existing refresh/reconciliation behavior; do not add a new permission check or private-store read to presentation getters.
- Keep Running, Escape, abort and cancellation dismiss without navigation, window reveal, recovery mutation or Quit retry. Preserve closed and minimized windows.
- Only an explicit guidance request initiates that navigation. Routine polling must not repeatedly steal focus or scroll the window.
- No backend, private schema, authentication, routing policy or Quit-permission change is authorized by this specification.
- Keep the main menu-bar **Open controls…** action and ordinary navigation behavior. No broader UI work, operational configuration changes, worktree, push or merge.

## Review Focus

1. Live uncertainty is newer than the displayed snapshot: operation guidance must beat a cached normal-exit or idle-looking state — Task 1 `testLiveUncertaintyPrecedesCachedPermission`.
2. An owned router becomes safely stoppable while the alert is held: guide to Stop rather than generic unavailable recovery or another response check — Tasks 1/2 `testSafeStopPrecedesFallbackReason`, `testPrimaryGuidanceUsesStateAfterHeldAlert`.
3. A coalesced refresh returns early: guidance must wait for its own serialized inspection attempt — Task 2 `testRefreshAndWaitWaitsForExistingInspection`.
4. Controls closes while guidance refresh is suspended: completion must not revive guidance or replay it on ordinary reopen — Task 2 `testWindowCloseCancelsPendingGuidance`.
5. Two requests select the same destination, separated by ordinary polls: each explicit request navigates once, polls never repeat navigation — Task 2 `testRepeatedGuidanceRequestsHaveDistinctIdentity` and Task 3 native scroll observation.

---

## Resolution and repository evidence

Specification NEW_ONLY at the referenced path; plan MISSING before this document. Exact shared slug, canonical basename and Created date retained; no legacy/conflicting candidate. The specification approval is recorded separately from this pending plan approval.

Inspected HEAD `f1e00832a000510043a02e6abce442a4d8ee473d`, branch `fix/companion-quit-alert`. Only the new specification was untracked before planning. Local main and the locally recorded origin/main are `66cc1c9`; actual remote state has not been refreshed in this stage. This baseline includes unmerged prerequisite work and must not be replaced by main.

Architecture map `docs/architecture/map.md` and ADR/decision documents were not found. No map freshness claim, accepted ADR constraint or regeneration applies. Key paths checked at this HEAD: native delegate/alert/view, controller refresh and permission methods, native test targets/fixtures, package manifest, package scripts and predecessor validation.

`RouterController.refresh()` intentionally returns early when another refresh is running. `inspectNow()` already serializes inspections, handles failure, rejects stale generations and performs normal reconciliation. Task 2 adds a narrow awaitable inspection entry point without changing existing polling/coalescing or permission logic; this is required for the new navigation to use completed evidence.

Commands derive from `package.json`, `companion/Package.swift`, `companion/README.md:201` and `docs/validation/companion-quit-alert.md`. Focused Swift filters select existing configured XCTest targets. Baseline counts (102 native, 664 Node, three package) are recorded prior results, not fresh acceptance for this increment.

## File responsibilities and interfaces

| File | Responsibility |
|---|---|
| Create `companion/Sources/CodexProjectRouter/QuitGuidance.swift` | Fixed read-only destination/text projection; transient navigation identity added in Task 2 |
| Modify `companion/Sources/CodexProjectRouter/QuitAlert.swift` | Exact approved alert copy, including ownership variant |
| Modify `companion/Sources/CodexProjectRouter/RouterApp.swift` | Snapshot alert input, reveal/refresh/navigation integration and close cancellation |
| Modify `companion/Sources/CodexProjectRouter/ControlsView.swift` | Existing target IDs, inline guidance/emphasis, scrolling and safe text focus |
| Modify `companion/Sources/CompanionCore/RouterController.swift` | Completed-refresh entry point only; no permission change |
| Create `companion/Tests/CompanionAppTests/QuitGuidanceTests.swift` | Guidance matrix, fixed copy and read-only behavior |
| Modify `companion/Tests/CompanionAppTests/QuitAlertTests.swift` | Alert copy, primary action, refresh/close/reentrant lifecycle |
| Modify `companion/Tests/CompanionAppTests/ControlsPresentationTests.swift` | Existing guidance/presentation regressions retained |
| Modify `companion/Tests/CompanionCoreTests/RouterControllerTests.swift` | Completed refresh serialization/failure regressions |
| Modify `companion/README.md`; create `docs/validation/companion-quit-guidance.md` | User explanation and sanitized new verification/review record |

Do not modify predecessor specification/plan/report, Package.swift, backend, store or private schemas. No new product fixture flags or test-only production modes.

## Execution preflight — only after plan approval

- [x] Record the separate specification and plan approval messages and preserve the selected method/tier. Recheck HEAD, branch, work and artifact identities. If intervening work changes the baseline materially, reconcile it before editing; do not reset or discard it.
- [x] Safely fetch and fast-forward main after approval, then create `fix/companion-quit-guidance` from the inspected predecessor tip `f1e00832a000510043a02e6abce442a4d8ee473d`, preserving the stack and uncommitted pair. Use `git fetch origin`, `git switch main`, `git merge --ff-only origin/main`, then `git switch -c fix/companion-quit-guidance f1e00832a000510043a02e6abce442a4d8ee473d`. If an update/checkout would overwrite work or cannot fast-forward, preserve state and report the conflict; never force or silently change the implementation base. The new branch does not currently exist. No worktree.
- [x] Commit only the approved pair on that branch: `git add docs/superpowers/specs/2026-11-12-companion-quit-guidance.md docs/superpowers/plans/2026-11-12-companion-quit-guidance.md`, then `git commit -m "docs: approve companion quit guidance"`. Start the selected workflow's own ignored workspace/ledger, record task baselines, and leave sibling/predecessor artifacts alone.

### Task 1: Define truthful guidance and update the dialog [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-03, AC-07, AC-08

**Files:** Create `QuitGuidance.swift` and `QuitGuidanceTests.swift`; modify `QuitAlert.swift`, its one `RouterApp.swift` factory call and `QuitAlertTests.swift`. Paths are in the responsibility table above.

**Interfaces:** Produce app-internal `@MainActor struct QuitGuidance: Equatable`, nested `enum Destination: Hashable { case status, restoreDirect, directResponse, manualRecovery, stopRouter, setup }`, stored `destination: Destination`, `text: String`, and `static func current(for controller: RouterController) -> QuitGuidance`. Change factory to `QuitAlert.make(reason: RouterController.QuitBlockReason, ownsRouter: Bool) -> NSAlert`, with no ownership default. The delegate passes the actual post-denial ownership snapshot before presentation. No new controller API is consumed here.

- [x] **Step 1: Write and observe dialog-copy RED.** Update the existing owned-fixture expectations for title, owned direct-check description, primary/secondary labels and bindings while retaining the current factory call. Run `swift test --package-path companion --filter QuitAlertTests`. Expected: behavioral failures on the old description/primary label, before production edits; existing guard tests otherwise retain their assertions.
- [x] **Step 2: Add projection and ownership-variant tests.** Use real temporary RouterController/PrivateStore instances with a small local synthetic backend, following the current app-test fixtures. Cover every row in the approved specification's **Dialog content** and **Guidance at existing controls** tables with literal expected values. Add `testLiveUncertaintyPrecedesCachedPermission`, `testSafeStopPrecedesFallbackReason`, `testUnavailableJournalNeverSuggestsConfirmation`, `testRestorationGuidanceDistinguishesOwnership`, `testMissingContextUsesExistingFallback` and `testGuidanceReadsHaveNoEffects`. Add the no-owned pending alert factory case with its required argument. Run `swift test --package-path companion --filter QuitGuidanceTests`. Expected: missing guidance type/ownership-argument API diagnostics, before production edits.

```swift
// Exact fixed content comes from the approved specification, never the formatter under test.
XCTAssertEqual(alert.messageText, "Cannot quit yet")
XCTAssertEqual(alert.buttons.map(\.title), ["Show steps to quit", "Keep Running"])
XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
XCTAssertEqual(alert.buttons[1].keyEquivalent, "\u{1b}")
XCTAssertEqual(QuitGuidance.current(for: idlePending).destination, .status)
XCTAssertEqual(QuitGuidance.current(for: idlePending).text,
    "Choose Quit again to check the saved recovery information. A pending response check can stay saved while this idle app is closed.")
XCTAssertEqual(QuitGuidance.current(for: safelyStoppable).destination, .stopRouter)
```

In the read-only case capture state bytes/mtime, confirmation, quitRequested, inspection/control/start/stop counts after fixture setup; repeated projection reads leave them unchanged. Inject a private sentinel in error/context/revision fixtures and assert it is absent from all newly produced text. For unavailable journal, corrupt/delete only the synthetic file after initialization and obtain the real denied attempt before testing guidance. Do not manufacture permission or use production serialization as the expected copy.

- [x] **Step 3: Implement the interfaces.** Use the exact approved text tables without shortening or paraphrasing them. Projection priority: current operation reason first; existing canQuit, then canStop; remaining contextUnavailable before confirmation/idle suggestions; guarded restoration only if canRestoreDirect; owned confirmation only if canConfirmDirectResponse; then no-owned clean Direct candidate; otherwise existing recovery fallback. Fallback destination is manualRecovery when the existing disclosure context exists, else setup for non-valid/missing configuration, else status. This accounts for a safe Stop whose generic reason would otherwise be contextUnavailable. Read getters only; do not cache permission or inspect storage. Update the delegate's factory call and existing tests to supply ownership explicitly.
- [x] **Step 4: Run GREEN.** Run `swift test --package-path companion --filter QuitGuidanceTests`, `swift test --package-path companion --filter QuitAlertTests`, then `npm run companion:test`. Expected: all new and existing native cases pass without warnings, baseline idle/owned/cancel guards intact. Record exact commands/exits and decisive RED/GREEN lines.
- [x] **Step 5: Commit and task-review.** Stage only Task 1's five files and `git commit -m "feat: explain blocked quit with current guidance"`. Require independent spec-compliance and quality dispositions before Task 2. Do not skip guard assertions to accommodate the new copy.

### Task 2: Reveal current controls once and cancel stale navigation [size: L | risk: concurrency | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08

**Risk:** Modal completion, timer refresh, actor suspension and window close can race with a navigation request. This task owns that one lifecycle domain, including the completed-refresh interface it needs.

**Files:** Modify `RouterController.swift`, `RouterControllerTests.swift`, `QuitGuidance.swift`, `RouterApp.swift`, `ControlsView.swift`, `QuitAlertTests.swift` and `ControlsPresentationTests.swift`.

**Interfaces:** Add `public func RouterController.refreshAndWait() async`: when usable, await an inspection attempt through existing inspectNow serialization/failure/reconciliation; do not return early through refreshRunning. Existing refresh() and permission logic stay unchanged. In `QuitGuidance.swift` add app-internal `@MainActor @Observable final class QuitGuidanceNavigation` with read-only `requestID: UUID?`, `beginRequest() -> UUID`, `present(_ token: UUID)`, and `clear()`. beginRequest reserves a fresh pending token; present publishes it only if still pending; clear invalidates pending and displayed tokens. Inject this object through optional `navigation: QuitGuidanceNavigation? = nil` in the existing delegate initializer, construct the default inside its MainActor body, and pass the same instance to `ControlsView(controller:navigation:)`. Keep existing presentation/window/termination test closures.

- [x] **Step 1: Add failing lifecycle regressions.** Reuse the real controller/delegate and current ControlledBackend/Barrier and QuitBackend/QuitBarrier fixtures. Add the named tests below; capture operation/journal counters after setup and after the denied attempt. Assert exactly the authorized extra inspection on the primary path, with no routing/confirmation or retry. Preserve secondary/cancel/abort zero-navigation and zero-extra-inspection assertions.

```swift
// testRefreshAndWaitWaitsForExistingInspection: hold background inspect, enqueue refreshAndWait.
XCTAssertFalse(completed) // until its own serialized attempt finishes; no overlapping backend inspect
// testPrimaryGuidanceUsesStateAfterHeldAlert: change uncertainty to clean idle/safe Stop before primary response.
XCTAssertNotNil(navigation.requestID)
XCTAssertEqual(QuitGuidance.current(for: controller).destination, expectedCurrentDestination)
XCTAssertEqual(terminateCount, 0)
// testWindowCloseCancelsPendingGuidance: hold primary refresh, call real windowWillClose, release refresh.
XCTAssertNil(navigation.requestID)
XCTAssertEqual(terminateCount, 0)
// testRepeatedGuidanceRequestsHaveDistinctIdentity: explicit requests differ; unchanged refresh preserves ID.
XCTAssertNotEqual(firstRequestID, secondRequestID)
XCTAssertEqual(navigation.requestID, secondRequestID)
```

Also cover inspection failure → recovery fallback, a stale generation during inspection, displayed guidance cleared by window close, cancellation preserving an existing navigation token, and request rejection while primary refresh is held. A cancelled pending token cannot be presented later. The extra primary refresh is intentional; update only that old inspect-count expectation, preserving all no-control/no-stop/no-confirmation checks. Clean up test timers explicitly.

- [x] **Step 2: Run RED.** Run `swift test --package-path companion --filter RouterControllerTests` and `swift test --package-path companion --filter QuitAlertTests`. Expected: missing refresh/navigation APIs first; preserve the intended lifecycle assertions for the subsequent behavioral RED if compilation reveals fixture errors. Record failures before production changes.
- [x] **Step 3: Implement completed refresh and delegate/navigation lifecycle.** Add the narrow awaited method using inspectNow, preserving its stale-result/failure handling and all permission methods. Split the existing window reveal into private `showControlsWindow()` plus the ordinary public openControls() refresh path. On the primary response only, reserve a navigation token, reveal via the existing test closure or window helper, await refreshAndWait(), then publish the reserved token if not cancelled. Hold the existing quitInProgress guard through that work. windowWillClose clears navigation before ordinary hidden polling. The normal menu-bar/open/reopen path retains its current refresh behavior and does not request guidance. No automatic Quit retry.
- [x] **Step 4: Wire the existing SwiftUI destinations.** Wrap the current scroll content in ScrollViewReader and assign the six stable Destination IDs to the corresponding existing groups/buttons. Add inline fixed guidance adjacent to the active target, a two-point outline and semibold guidance text so emphasis does not depend only on color. Bind the existing recovery disclosure to local expanded state. Once per new published request, expand it if targeted, navigate after layout to the current target, and move keyboard/accessibility focus to the non-actionable guidance text. Never give a routing/confirmation button default-action status. Guard delayed layout work against changed/cleared request IDs. Track the last navigated ID so normal renders/minimize/reopen cannot replay it. Derive visible text/target from current projection; evidence changes update/withdraw old guidance without scrolling or moving focus. A fresh identical-target request still navigates. A cleared token removes guidance/emphasis; ordinary reopen stays ordinary. Keep existing layout, project list and confirmation controls.
- [x] **Step 5: Run GREEN.** Repeat the two focused RED commands, then `swift test --package-path companion --filter QuitGuidanceTests`, `swift test --package-path companion --filter ControlsPresentationTests`, and `npm run companion:test`. Expected: all native tests pass without warnings, including predecessor idle durable-evidence and owned-listener protection, window-close/cancel, held-modal/reentrant and polling tests. Unit tests prove selection and lifecycle; actual SwiftUI scrolling/focus remains Task 3 native evidence, not a mock-based visual claim.
- [x] **Step 6: Commit and task-review.** Stage only Task 2's seven files and `git commit -m "feat: navigate to current quit recovery controls"`. Independent spec/quality task review must pass before Task 3. No further user gate between tasks.

### Task 3: Verify native guidance and record the completed increment [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10

**Files:** Modify `companion/README.md`; create `docs/validation/companion-quit-guidance.md`. Parent owns native orchestration and final integrated review after the worker's code/docs/automated report. Do not rewrite the predecessor report.

**Interfaces:** Consume Tasks 1/2 as reviewed. No further product API or behavior is planned.

- [x] **Step 1: Document the user path.** Explain the primary label, short reason-specific text, emphasis at existing controls, current-state refresh, explicit subsequent Quit and cancellation. State that idle Quit still has no restart/response prerequisite, while an owned router may retain that prerequisite. Update the predecessor-deferred sentence in the current README to point to the new delivered behavior; predecessor reports remain historical. Start the new sanitized validation record with actual RED/GREEN, counts/exits and pending native/review items clearly marked.
- [x] **Step 2: Run fresh automated acceptance sequentially.** Run `npm run companion:test`, `npm test`, `npm run companion:build`, `npm run companion:package-test`, `node --check src/cli.js`, `git diff --check`. Expected: native and Node suites pass; release app built and ad-hoc signed; all three package tests pass with zero skips; syntax/whitespace exit 0. Record full commands, exits and decisive proof lines; inspect complete output. Repeat only after an affected change, failure or unresolved concern.
- [x] **Step 3: Observe the fresh isolated native app.** Reconstruct the ignored temporary native harness from `test/companion-package.test.js` and the predecessor report's procedure; its old scratch workspace was cleaned. Use relocated signed resources, owner-only synthetic HOME plus CFFIXED_USER_HOME, Seatbelt denial of real private/checkout paths and non-loopback outbound traffic, negative checkout-read control and positive tracked native instance-lock proof. Keep raw paths/PIDs/checkpoints outside Git. Never change real provider/router files or request credentials/model responses.

Exercise an unavailable-journal blocker by altering only the synthetic journal after initialization. With Controls open, closed, minimized and scrolled to synthetic project rows, primary action must reveal the one existing window, expand/bring the recovery target into view, emphasize it and show correct text. Repeat the same target after scrolling elsewhere. Observe that ordinary polls leave user scroll/focus alone and normal close/reopen has no stale guidance. Use CUA for UI interaction. Explicitly observe keyboard/accessibility reachability and that showing guidance invokes no control action.

For the owned confirmation destination, seed valid pending recovery and use only the confined app's Start router if necessary; never activate real routing or perform the displayed Codex restart/response check. Positively track the synthetic owned Node process as well as the native process. Check the confirmation destination/text and unchanged fixture provider/router/journal bytes after guidance; close/cancel observations must not be inferred from activating target reads. Use attributed human observation if tooling cannot establish window preservation. Verify a clean no-owned idle fixture still exits without the dialog and retains pending recovery on relaunch. Restore synthetic changes and clean only exact tracked fixture processes/files, proving the port empty afterward.

- [x] **Step 4: Consolidate actual evidence and commit.** Record native observations, privacy/process cleanup, tooling limitations, actual checks and any user usability feedback in the new report. Do not claim native scrolling or accessibility from projection spies alone. Stage only the documentation with `git add companion/README.md docs/validation/companion-quit-guidance.md`, then `git commit -m "docs: validate companion quit guidance"`; complete independent task review. A parent-owned native item remains open until observed, even if the code/automated portion is approved.
- [x] **Step 5: Complete the sole final gate.** Invoke `personal-workflows:code-review` once in integrated mode for `f1e00832a000510043a02e6abce442a4d8ee473d..HEAD`, excluding already completed prerequisite implementation from the new diff. Use the immutable identity/hash package, approved pair, full changed-file diff, task dispositions, actual automated/native evidence and limits. Specification must pass before quality opens. Follow the enclosing execution workflow's fix-loop policy; no generic duplicate final reviewer. Record both dispositions and necessary affected rechecks in the new report.
- [x] **Step 6: Close out and stop.** Mark lifecycle/checklists complete only after evidence and reviews, commit artifact-only closeout, verify clean status and preserve the existing checkout/branches. Follow the selected workflow's own scratch cleanup. Report working result, verification and limits; do not push, merge or begin broader UI work.

## Criterion traceability

| Criterion | Tasks / proof |
|---|---|
| AC-01 | Task 1 native-alert content and real delegate regressions; Task 3 native entry points |
| AC-02 | Task 2 target IDs/request lifecycle; Task 3 open/closed/minimized/scrolled navigation |
| AC-03 | Task 1 exact matrix, ownership/fallback precedence; Task 2 current post-refresh projection |
| AC-04 | Task 2 held modal/refresh/close/repeated-request tests; Task 3 polling/scroll observations |
| AC-05 | Task 2 unchanged cancellation/reentrancy/window-close behavior; Task 3 native visibility |
| AC-06 | Task 2 transient state and text focus; Task 3 readable emphasis/keyboard/accessibility/close-reopen |
| AC-07 | Task 1 no-effect reads; Task 2 completed-refresh and full native lifecycle regressions; Task 3 idle native exit |
| AC-08 | Task 1 fixed-copy sentinel checks; Task 2 fixed inline projection; Task 3 sanitized evidence |
| AC-09 | Task 3 complete fresh automated/build/package/native acceptance |
| AC-10 | Task 3 documentation, sole sequential final gate and delivery endpoint |

## Self-review and handoff

Parent self-review: AC-01–AC-10 covered; each Review Focus has a named owner/test; producer/consumer signatures match. UI copy is pinned to the approved specification, not decided by workers. The awaited-refresh addition preserves existing polling and authorization. Native scroll/visibility/accessibility evidence is explicitly separate from unit projections. The plan retains a narrow end-to-end delivery and no unresolved product decision or material assumption requiring clarification.

**Execution endpoint:** Deliver and verify the clearer blocked-Quit dialog and targeted existing-control guidance, preserve permission/cancellation safeguards, document actual evidence and pass final sequential review; report results/limits and stop before broader UI work or integration.

**Current stage:** Stage 4 complete — implemented after separate scope/design, specification and plan approvals. Fresh automated acceptance, isolated native observations (including attributed human visibility checks), independent task reviews and the sole final sequential specification/quality gate passed. See `docs/validation/companion-quit-guidance.md`. Stop before broader companion work or integration; keep the existing branch and checkout.
