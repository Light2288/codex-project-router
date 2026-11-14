# Companion Dock Presence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `personal-workflows:spec-implement` with `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Native execution preserves the user's explicit selection earlier in this conversation; no implementer subagents.

**Goal:** Show the companion's navy Dock icon and Command-Tab presence while controls are open, returning to menu-bar background operation after an allowed close.

**Architecture:** Keep `LSUIElement = true` and change AppKit activation policy in the existing controls-window lifecycle. All opening paths use the existing delegate method; only that delegate's controls-window close may demote the app. Retain the existing controller, polling, account-save dismissal, and guarded termination paths.

**Tech Stack:** Existing SwiftUI/AppKit, Swift 6 toolchain in Swift 5 language mode, XCTest, Node.js 24, and signed macOS package tests. No new runtime dependencies.

**Spec:** [Approved specification](../specs/2026-11-14-companion-dock-presence.md)

**Slug:** `companion-dock-presence`

**Status:** APPROVED

**Created:** 2026-11-14

**Updated:** 2026-11-14

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Native; retain the user's earlier explicit selection. Inline execution does not switch the current session model.

**Provenance:** The user confirmed the proposed conditional Dock behavior with “ok, implement this,” then separately approved the presented specification with “approved.” The plan was then saved and separately presented. The user's second “approved” explicitly approves this plan and authorizes implementation; the earlier “approved” applied to the specification only.

## Global constraints

- Implement only conditional running-app Dock presence, its tests, documentation, verification, and final review. Keep the navy app icon and persistent black menu-bar item.
- Retain `LSUIElement = true`. Open controls means regular presence, including minimized or hidden states; an allowed controls close means accessory presence. Respect user-pinned/recent Dock items.
- Preserve account-save closure refusal, window reuse and dimensions, navigation invalidation, refresh cadence, keyboard/accessibility behavior, and fresh guarded Quit. Window events cannot mutate routing or saved configuration.
- All policy/window operations remain on the existing `@MainActor` delegate. Handle a rejected native policy change with a contextual diagnostic; do not cache it as a success or suppress later retries.
- Use isolated temporary state and only owned windows/processes in verification. Do not replace or quit the user's running companion, change real configuration/credentials, request new system permissions, install, push, or merge.
- Preserve the existing local branding commits and historical artifacts, including their pending review. This increment's explicit Dock behavior supersedes the earlier menu-bar-only constraint for the new work without rewriting that artifact.
- After plan approval, safely update local `main` under the user's Git rules, preserving all changes. Create `feat/companion-dock-presence` from the preserved branding head `2c209656821a1017bf38f87880cce1c8bd600c69`, or its verified descendant if the user adds work. This base retains the required icons. Do not merge the branding branch into `main`. Work in the existing checkout; no worktree.
- Save both approved artifacts before product edits. Keep them uncommitted until that implementation branch exists, then commit them there. Update their current-stage metadata together before final review so the package has consistent approval evidence.

## Repository evidence and assumptions

- Specification resolution: **NEW_ONLY** at the linked path. Plan resolution before creation: **MISSING**; no matching legacy `specs/companion-dock-presence.md` or `plans/companion-dock-presence.md` exists.
- Planning HEAD: `2c209656821a1017bf38f87880cce1c8bd600c69` on `chore/companion-branding-readme`; only this increment's specification was untracked. No product changes or acceptance tests ran during planning.
- No architecture map or ADR directory was found under `docs/`; map HEAD/freshness and applicable ADR statuses are unavailable. Directly inspected the app delegate, plist, package manifest, build script, lifecycle/account/quit tests, native package isolation, and companion reference.
- `RouterApp.swift`: launch, menu-bar opening, application reopen, and ordinary recovery opening converge on `showControlsWindow()`. Its retained `NSWindow` is currently private. `windowWillClose` currently accepts any notification object; two existing Quit tests send objectless notifications and must become real controls-close regressions.
- `AccountSetupActionTests.swift` already holds account-save completion to verify refused dismissal. `ControlsPresentationTests.swift` supplies synthetic running-router counters and journal fixtures. `QuitAlertTests.swift` covers denied, allowed, repeated, and reentrant native termination.
- Verification commands below are existing `package.json` scripts and the root README development-check sequence. Native package verification already uses `codesign --verify --deep --strict`, a logged-in GUI, a PID-specific Swift window probe, synthetic native home, source-denial confinement, and owned-process cleanup.
- No material product decisions remain open. Minimization/hiding and close-versus-Quit semantics were fixed in the approved specification. OS-level focus/Dock behavior remains an implementation verification question.

## Review focus

1. Refused close during an account save must keep controls and Dock presence; only a successful controls close demotes the app.
2. Unrelated windows, sheets, or malformed close notifications must not clear controls guidance, change polling, or demote the app.
3. Repeated reopen/minimize/hide cycles must retain one usable controls window and menu item, with correct foreground focus and no routing mutation.
4. Failed promotion/demotion must be diagnosed and retried on the next relevant event; no cached success may strand controls outside Command-Tab.
5. Dock/native Quit during an operation or pending recovery must retain the existing alert/authorization, including a controls close while recovery guidance is awaiting refresh.

## Files and responsibilities

| File | Responsibility |
| --- | --- |
| `companion/Sources/CodexProjectRouter/RouterApp.swift` | Native activation policy and ownership-aware window-close integration |
| `companion/Tests/CompanionAppTests/ControlsPresentationTests.swift` | Open/close/reopen, minimized/hidden callback behavior, unrelated notifications, policy failure retries, and unchanged routing/journal |
| `companion/Tests/CompanionAppTests/AccountSetupActionTests.swift` | Actual refused-close/allowed-close transition using the held-save fixture |
| `companion/Tests/CompanionAppTests/QuitAlertTests.swift` | Native termination and guidance-close regressions against the owned controls window |
| `test/companion-package.test.js` | Native running-app regular-policy assertion in the existing isolated relocated-app test |
| `companion/README.md`, `README.md` | Dock/window/minimize/close/Quit behavior |
| `docs/validation/companion-dock-presence.md` | Observed RED/GREEN, acceptance, native observations, limitations, and final review identity/results |

No changes to `CompanionCore`, plist values, artwork, CLI, or build allowlists are planned.

## Task 1: Integrate and regress conditional Dock presence [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01–AC-06; contributes to AC-07.

**Risk:** AppKit lifecycle changes can impair focus or access to an open window. Native verification in Task 2 supplements delegate tests; operational authorization remains in the existing controller.

**Files:** Modify the delegate, the three existing app-test files, and `test/companion-package.test.js` listed above.

**Interfaces:**
- Preserve `openControls()`, `showControlsWindow()`, the window delegate callbacks, and native termination signatures.
- Add an initializer dependency `setActivationPolicy: @escaping @MainActor (NSApplication.ActivationPolicy) -> Bool`, defaulting to `NSApp.setActivationPolicy`. Keep existing call sites source-compatible through its default.
- Expose the retained window to the module as `private(set) var controlsWindow: NSWindow?` for actual ownership/reuse assertions; no public interface is added.
- A private `applyActivationPolicy(_ policy: NSApplication.ActivationPolicy)` performs the call and logs rejection with the requested policy. It does not maintain a second policy cache.
- Task 2 consumes the resulting native delegate behavior and the unchanged app bundle/build interfaces.

- [ ] **Write lifecycle regressions using the existing fixtures.** Add `testControlsOpenCloseAndReopenPreserveBackgroundRouting` and `testUnrelatedCloseDoesNotDemoteControls` to `ControlsPresentationTests`. Capture policy requests through the new dependency. The key assertions are:

```swift
delegate.openControls()
let window = try XCTUnwrap(delegate.controlsWindow)
XCTAssertEqual(policies.last, .regular)
delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: NSWindow()))
XCTAssertEqual(policies.last, .regular)
window.performClose(nil)
XCTAssertEqual(policies.last, .accessory)
delegate.openControls()
XCTAssertTrue(delegate.controlsWindow === window)
XCTAssertEqual(policies.last, .regular)
XCTAssertFalse(controller.quitRequested)
```

  Also assert malformed notifications do nothing; an unrelated close retains the current navigation token. With the synthetic owned router, compare its ID, routing mode, journal bytes, and backend start/control/stop/mode-set counters before and after cycles. Read-only refresh is allowed. Always close owned windows and invalidate delegate polling before releasing fixtures.

- [ ] **Write minimized/hidden and failure regressions.** Add `testMinimizingControlsPreservesRegularPresence` and `testRejectedActivationPolicyIsRetried` in the same file. Minimize/deminiaturize callbacks must never request accessory presence; opening restores the same window. Returning `false` from the injected setter must not prevent window reuse or a fresh request on the next open/close. Do not hide the shared test runner; actual hide/unhide is observed on the isolated app in Task 2.

- [ ] **Extend the held-save regression.** In `testSavingKeepsControlsAndSheetAvailableUntilOutcome`, open actual controls with the synthetic setup, attempt `performClose(nil)` while the commit is held, and assert controls remain visible and policy remains regular. Release/await the commit, close again, and assert accessory policy. Preserve the existing no-start/no-activation assertions and clean up the owned window/timer.

- [ ] **Adapt and extend Quit regressions.** `testWindowCloseCancelsPendingGuidance` and `testWindowCloseClearsDisplayedGuidance` must close the delegate's actual controls window, replacing objectless close notifications. Establish the window and drain its initial read-only refresh before inspection-count baselines. Retain the delayed-refresh invalidation and journal/no-stop assertions. Add `testNativeQuitDenialKeepsRegularPresenceAndGuidanceReopensControls`: native termination returns `.terminateCancel`; Keep Running cannot close/demote controls or stop the listener; Show steps to quit after a prior close promotes and reuses controls. Keep the existing fresh-authorization, safe exception, and reentrant-Quit tests.

- [ ] **Extend native packaging regression before behavior changes.** In the existing source-denied relocated native-app test, extend the PID-specific Swift window probe to import AppKit and require `NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular` alongside the existing visible-window check. Keep the native-home lock assertion, signatures, image checks, Seatbelt denials, and cleanup unchanged.

- [ ] **Observe RED.** Run `npm run companion:build`, then `npm run companion:package-test` against current behavior. Expected: build succeeds and the new regular-policy assertion fails. Run `npm run companion:test`; the new tests may initially fail to compile because the planned test seam is absent. Add only the declared initializer/property seam without policy behavior and rerun `npm run companion:test` to observe failing policy assertions. Distinguish these intended failures from toolchain, GUI, or fixture failures.

- [ ] **Implement the minimal delegate change.** Call `applyActivationPolicy(.regular)` before raising/de-miniaturizing/activating controls in the shared opening method. In `windowWillClose`, require `notification.object` to be exactly the retained controls window before clearing navigation, switching to hidden polling, and requesting `.accessory`. Preserve the existing `windowShouldClose` decision so a refused close never reaches demotion. Minimize/hide do not demote. Preserve native termination and alert serialization; a rejected policy request produces a contextual diagnostic and remains retryable.

- [ ] **Observe GREEN.** Run `npm run companion:test`, `npm run companion:build`, and `npm run companion:package-test`. Expected: all native tests pass, a freshly signed app is built, all three package cases pass with zero skips, and the isolated native process reports regular activation policy. Inspect any new diagnostic; existing Security API deprecations remain separate evidence.

- [ ] **Commit the integrated behavior and tests.** Commit only this task's files with `feat(companion): show Dock icon while controls are open`. Retain exact commands, exits, decisive proof, and initial RED in this increment's execution ledger.

## Task 2: Document, observe, verify, and review [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-07, AC-08; confirms AC-01–AC-06.

**Files:** Modify the root/companion README, create the validation record, and update only this increment's spec/plan lifecycle metadata.

**Interfaces:** Consume Task 1's unchanged bundle and controls-opening/termination paths. Reuse the package test's isolated native-home, PID ownership, and source-denial setup for native observation. No diagnostic command or test-only behavior is added to the production app.

- [ ] **Document the delivered behavior.** Update the companion lifecycle paragraph and the README everyday-use paragraph: Dock/Command-Tab while controls are open or minimized/hidden; successful close returns to the menu bar and leaves routing running; Open controls restores it; Dock Quit uses guarded Quit. Mention that pinned/recent Dock items follow user settings. Keep recovery/setup instructions and live-compatibility qualifications intact.

- [ ] **Observe native transitions safely.** Launch an isolated freshly built copy by executable path with the same synthetic native home and ownership checks used by package tests. Check launch, minimize/restore, hide/unhide, close, menu-bar reopening, repeated cycles, focus, navy Dock icon, Command-Tab presence, persistent menu item, and native Quit handling. Target only the retained PID/window; avoid bundle-ID/open-app targeting that could activate the user's existing instance. Use available native observation or existing authorized accessibility control; do not request new permissions. If any action cannot be observed safely, name it as unobserved and distinguish automated policy/window checks from a visual Dock/Command-Tab claim. Tear down only owned processes and confirm synthetic-state cleanup.

- [ ] **Run combined acceptance.** Run, in order, `npm run companion:test`, `npm run companion:build`, `npm test`, `npm run companion:package-test`, `node --check src/cli.js`, and `git diff --check`. These are the existing package scripts/README checks. Expected: every exit is 0, all tests pass, all three package cases run without skips, signatures/relocation/source-denial and owned cleanup pass, and syntax/whitespace commands produce no errors. Record actual counts rather than assuming the previous increment's totals.

- [ ] **Write the concise validation record.** Include approval references, baseline/implementation commits, RED-to-GREEN proof, commands/exits/counts, rejected-policy diagnostic behavior, native matrix observations, unchanged configuration/listener evidence, signing/relocation, and limitations. Verify documentation link targets and inspect the focused documentation diff. Do not claim live gateway/billing or installed-app validation.

- [ ] **Run the sole final integrated review.** Invoke `personal-workflows:code-review` exactly once: one immutable package with this approved spec/plan, the complete increment diff from the preserved branding baseline, observed evidence, relevant unchanged lifecycle context, unique identities/hash, and ledger rulings. Confirm both artifacts record Stage 4 and their separate approvals before package creation. Dispatch specification review first and quality review only after fresh specification PASS; the adapter owns routing and stop rules. Follow the enclosing native-execution fix-loop limit for findings and retain the package on a blocked review. Do not silently include resolution of the older branding review in this scope.

- [ ] **Commit and close out after the review outcome permits it.** Record final review results/identities, complete this increment's task checklist and current-stage metadata consistently, and locally commit documentation/evidence. Run `git diff --check` and inspect `git status --short --branch`; expected: no whitespace errors and a clean implementation branch. Preserve the branch and checkout without pushing, merging, installing, or opening the real companion. Report observed results/limits and stop.

## Criterion coverage and self-review

| Criteria | Implementation and evidence |
| --- | --- |
| AC-01 | Task 1 regular-policy regression and native package assertion; Task 2 Dock/Command-Tab observation |
| AC-02 | Task 1 real controls close with synthetic listener, mode, journal, and counters preserved |
| AC-03 | Task 1 held-save refusal and unrelated/malformed close regressions |
| AC-04 | Task 1 minimize/reopen reuse checks; Task 2 isolated minimize/hide observation |
| AC-05 | Task 1 shared opening path and recovery-guidance/reopen regression; Task 2 native cycles/menu observation |
| AC-06 | Task 1 native termination/alert/save/reentrancy coverage; Task 2 combined acceptance |
| AC-07 | Task 1 native RED/GREEN; Task 2 acceptance, native observation matrix, and sequential final review |
| AC-08 | Task 2 focused README/reference updates and validation record |

Self-review: all specification IDs and five review-focus conditions have task
coverage. The policy injection and read-only window property have one definition
and consistent uses. No new core layer, runtime dependency, extra window,
artwork-generation step, or unrelated review remediation is required. Full tier
is selected because runtime UI integration is non-mechanical and requires native
observation; this is one coherent delivery increment.

**Execution endpoint:** Locally commit verified conditional Dock presence,
documentation, evidence, and permitted final-review resolutions; report the
result and limits, then stop before installation, push/merge, or later work.

**Current stage:** Stage 4 — implementation authorized by the second “approved,”
following separate presentation and approval of the specification and this plan.
Both artifacts are saved. Preserve their basenames and approved scope.
