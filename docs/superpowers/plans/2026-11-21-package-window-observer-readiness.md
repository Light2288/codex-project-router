# Package Window Observer Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement`. Execute the checkbox steps using the user-selected **Native** method. Repository approval and Git rules take precedence.

**Goal:** Eliminate the demonstrated observer startup race while preserving the native package test's window condition, deadline and safeguards.

**Architecture:** Move the existing Swift observer into a small test helper that coordinates readiness, app launch and exact-PID observation. The package test uses that helper before checking the synthetic instance lock. Regression cases exercise the same coordination with controlled process events and the same Swift predicate with synthetic window metadata.

**Tech Stack:** Existing Node 24 test runner, child-process lifecycle utilities, Swift/AppKit/CoreGraphics and macOS sandbox tooling. No dependencies or public API changes.

**Spec:** `docs/superpowers/specs/2026-11-21-package-window-observer-readiness.md`

**Slug:** `package-window-observer-readiness`

**Status:** APPROVED

**Created:** 2026-11-21

**Updated:** 2026-11-21

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Native, selected through the clarification control for this increment.

**Provenance:** Approved specification and repository inspection at `d905867c7dcfac99b0a0188962fd274f2c689fe4`. This plan was presented separately in Plan mode, after explicit specification approval. The user's subsequent “Please implement the plan” approves this presented implementation plan. It is now saved in Default mode before implementation.

## Global Constraints

- Preserve the exact child PID, regular activation policy and actual on-screen layer-0 window predicate.
- Keep one absolute **20-second observation deadline**, starting before observer startup, and the existing **60-second overall test timeout**.
- Preserve signature verification, source-denial controls, synthetic state isolation, instance-lock proof, downstream assertions and owned-process cleanup.
- Add no fixed readiness sleeps, relaxed predicates, timeout extensions, skips or production changes.
- Use the existing signed bundle. Do not rebuild, replace or quit the canonical companion, or change desktop settings.
- Relevant evidence: `package.json` supplies the test commands; `test/companion-package.test.js` supplies the lifecycle, sandbox and window checks. Existing fake-child patterns appear in the credential tests.
- No architecture map or ADR candidates were found. Map HEAD/freshness and applicable ADR statuses are unavailable. Key paths were inspected directly; no map will be generated.

After separate plan approval, save this exact plan and record both approval messages before changing code. Preserve the completed Keychain commits. Safely update local main using a fast-forward-only update, then create `test/package-window-observer-readiness` from the preserved Keychain tip `d905867c7dcfac99b0a0188962fd274f2c689fe4`. This deliberately stacks the test fix on that work and keeps its existing bundle aligned. Stop on conflicting repository changes without discarding work. No worktree, push or merge is authorized.

## Review Focus

Each condition receives regression coverage in Task 1:

1. Buffered or fragmented readiness output cannot cause launch before readiness or lose the first observation.
2. Readiness near expiry cannot obtain a renewed observation budget.
3. Native or observer exit between coordination steps cannot produce success.
4. Wrong PID, wrong layer, off-screen metadata and nonregular activation cannot satisfy the predicate.
5. Cleanup failures cannot conceal the original observation failure or leave owned observers running.

## Task 1: Correct observer ordering and integrate regression coverage [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-01–AC-06.

**Risk:** Process events, stream delivery and deadline expiry can occur between coordination steps. Controlled event-order tests must cover these boundaries.

**Files:**

- Create: `test/helpers/native-window-observer.mjs`
- Modify/test: `test/companion-package.test.js`

**Interfaces:**

- Consume the existing lifecycle's `start(...)`, `stop(tracked)` and tracked-child shape.
- Export `launchObservedNative({lifecycle, launch, cwd, env, deadline})`, returning the tracked native child after successful observation and observer cleanup. `launch()` synchronously starts and returns that child.
- Export the Swift predicate source used by the real observer so regression checks compile and execute that exact function: `hasRegularOnScreenWindow(pid: Int, regular: Bool, windows: (CGWindowListOption) -> [[String: Any]]) -> Bool`.

- [x] **Step 1 — Establish the approved execution state.** Save the approved plan, record the specification and plan approvals, perform the Git preflight above, and commit only the two approved artifacts with `docs: approve package window observer readiness`.
- [x] **Step 2 — Write failing regression cases.** Add cases prefixed `native window observer` using controlled child events, streams and mocked time. Assert:
  - No launch occurs before readiness; startup error, premature exit or readiness expiry leaves the launch count at zero.
  - Fragmented readiness is recognized; malformed, duplicate or oversized protocol output fails.
  - The exact launched PID is sent immediately. A transient observation delivered during handoff is retained before lock verification begins.
  - Readiness at 19,500 milliseconds leaves only 500 milliseconds; expiry does not renew the deadline.
  - Native exit, observer failure, success without an observation marker and an observation marker naming another PID all fail.
  - Cleanup runs on success and failure, listeners/timers detach, and primary plus cleanup errors remain recognizable.
  - The actual Swift predicate rejects wrong/missing PID or layer, nonregular activation and off-screen-only evidence. The injected window source verifies that the predicate requests `.optionOnScreenOnly`.
- [x] **Step 3 — Verify RED.** Run `node --test --test-name-pattern='^native window observer' test/companion-package.test.js`. Expected: failure because the helper/interface is absent. Record the actual failure.
- [x] **Step 4 — Implement the helper.** Start the observer through the existing lifecycle, with an owned process group, and arm the single deadline before startup. Initialize the Swift window/application query APIs before emitting `native-window-ready`. After readiness, launch the native child and immediately send its decimal PID followed by a newline. Retain the existing 25-millisecond polling cadence. Emit `native-window-observed:<pid>` only when the unchanged predicate succeeds, then exit zero. Require both the matching marker and successful observer completion before returning. Check deadline and child-exit state at coordination boundaries. Keep stdout protocol parsing bounded to 8 KiB and error excerpts bounded to 4 KiB per captured stream. Handle stream, spawn and exit failures. Always reap the observer through `lifecycle.stop`; preserve both errors if observation and cleanup fail.
- [x] **Step 5 — Integrate the real package case.** Replace its late inline observer with `launchObservedNative`, passing `Date.now() + 20_000` immediately before the call. Keep the existing sandboxed native-launch callback. Perform the existing exact-PID instance-lock check after window observation, followed by the unchanged downstream assertions. Remove the superseded observer/abort code.
- [x] **Step 6 — Verify GREEN.** Repeat the regression command, then run `node --test --test-name-pattern='^native relocated app and bundled controls' test/companion-package.test.js`. Expected: regression cases pass; the real native case observes the window, proves lock ownership and completes its downstream checks. Inspect cleanup evidence and run `git diff --check`.
- [x] **Step 7 — Commit the correction.** Commit only the helper and package-test changes with `test: ready native window observer before app launch`.

## Task 2: Verify, document and review the increment [size: S | risk: none | mechanical: true | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-07, AC-08; integrated evidence for AC-01–AC-06.

**Files:**

- Create: `docs/validation/package-window-observer-readiness.md`
- Update: approved artifact lifecycle/completion evidence only.

**Interfaces:** Consume Task 1's integrated package test and regression cases. Produce a traceable validation report and final review record.

- [x] **Step 1 — Run isolated package verification.** Run `npm run companion:package-test`. Expect all existing package cases and new regressions to pass, with no failures, cancellations or skips. The native case must execute against the existing signed bundle.
- [x] **Step 2 — Run standard parallel verification.** Run `npm test` without reducing concurrency. Expect all tests to pass. Record actual totals and exits. Serial results cannot replace this check. Investigate failures within the approved boundary; do not weaken assertions or deadlines.
- [x] **Step 3 — Write the validation report.** Separate historical diagnosis from current verification. Record RED/GREEN results, commands, totals, desktop conditions actually observed, cleanup evidence and limitations. Map AC-01–AC-06 to Task 1's regressions and real native case, AC-07 to both integration commands, and AC-08 to documentation/review/commits. Preserve the earlier Keychain report as historical evidence.
- [x] **Step 4 — Complete the sole final review gate.** Use `personal-workflows:code-review` with the approved artifacts, complete increment diff from `d905867`, changed-file list and current evidence. Run specification review first; quality review follows only after PASS on the unchanged review package. Address findings under the execution workflow's bounded follow-up policy and rerun affected checks.
- [x] **Step 5 — Commit and report completion.** After passing review, preserve review identities/verdicts, update lifecycle evidence, run `git diff --check`, and commit documentation with `docs: record window observer readiness validation`. Report commits, observed results, limitations and final working-tree status.

## Approval Handoff

**Current stage: Stage 4 complete — implementation, verification and final review passed.** The saved specification was explicitly approved with “approved”. This separate plan was subsequently presented in full, Native execution selected, and the user's following “Please implement the plan” approves it. Both artifacts are saved before test implementation.

All eight acceptance criteria have task/test coverage; no material decision remains unresolved. Task 1 produces the helper/integrated case consumed by Task 2; no interface conflict was found in the pre-flight review.

**Execution endpoint:** Deliver only the test-observer correction, regression coverage, integration verification, documentation, required sequential review and authorized local commits; report the working result and limitations, then stop.

**Completion evidence:** `docs/validation/package-window-observer-readiness.md` records the focused 28/28, isolated package 31/31, final standard parallel 1,123/1,123 and sole specification/quality PASS gate with no findings. No scope/plan rulings or deferred minors were required. The diagnostic-byte bound received its own RED/GREEN correction before review. Only lifecycle/result documentation changed after review; tested code remains `79ba868`. Local commits and plan-owned scratch closeout complete this increment; no push, merge or later increment follows.
