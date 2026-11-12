# Companion Quit guidance validation

Date: 2026-11-12

Status: in progress. Tasks 1 and 2 have independent task approval, and fresh
automated acceptance passed. Isolated native observations, Task 3 review and the
final sequential specification/quality gate remain pending. This record does not
yet claim completion of the increment.

Scope: the approved `companion-quit-guidance` increment, based on
`f1e00832a000510043a02e6abce442a4d8ee473d`. The approved specification and separate
plan are `docs/superpowers/specs/2026-11-12-companion-quit-guidance.md` and
`docs/superpowers/plans/2026-11-12-companion-quit-guidance.md`. The predecessor
`docs/validation/companion-quit-alert.md` remains an unchanged historical record;
its results are not fresh evidence for this follow-up.

## Implemented behavior and boundaries

Task 1 (`25da186`) supplies the five fixed, blocker-specific descriptions,
**Cannot quit yet**, **Show steps to quit** (Return) and **Keep Running**
(Escape/cancel). Its read-only guidance projection distinguishes current operation,
normal Quit, safe Stop, unavailable evidence, restoration and owned/idle response
states. Private context, paths, credentials and raw errors are not interpolated
into new messages. The existing controller remains the authority for Quit.

Task 2 (`f8f9ff4`) connects the primary response to the one existing controls window:
reveal/raise/deminimize, await the existing serialized refresh path, then publish
a transient request. Existing controls receive inline semibold guidance and an
outline; manual recovery expands when selected. Explicit request identity drives
scrolling and focus to non-actionable text, including repeated requests for the
same destination. Current evidence updates the guidance without repeating that
navigation during routine polling. Closing Controls clears guidance and pending
requests; cancelling the alert does not reveal/navigate, retry Quit or mutate
recovery. No routing/confirmation button becomes a default action.

No backend, private schema, authentication, routing policy or Quit-permission
change is part of this increment. Eligible idle Direct Quit still requires a fresh
action-time durable-evidence check, retains pending recovery and needs no Codex
restart or response merely to close the idle app. An owned router can retain the
existing restart/working-direct-response safeguard. Showing guidance performs no
routing, listener, confirmation or recovery operation and never retries Quit.

## Recorded Task 1 and Task 2 evidence

These are recorded task-run results, read from the task reports and independent
reviews. They were not rerun to recreate RED. Full raw logs remain in the ignored
task workspace during execution; this document retains sanitized results.

| Recorded command / phase | Exit | Observed result |
| --- | --- | --- |
| `swift test --package-path companion --filter QuitAlertTests` — Task 1 copy RED before product edits | 1 | 8 tests, 12 failures: old descriptions and Open Controls differ from approved copy/label |
| `swift test --package-path companion --filter QuitGuidanceTests` — Task 1 interface RED | 1 | `cannot find type 'QuitGuidance' in scope` |
| Same guidance filter — Task 1 GREEN | 0 | 12 tests, 0 failures |
| `swift test --package-path companion --filter QuitAlertTests/testDelegateUsesOwnershipAfterDeniedAttempt` — Task 1 deliberate ownership mutation | 1 | 1 test, 1 failure: stale owned copy differs from required no-owned description; mutation restored |
| `swift test --package-path companion --filter QuitAlertTests` — Task 1 final GREEN | 0 | 10 tests, 0 failures |
| `npm run companion:test` — Task 1 final GREEN | 0 | 86 core + 30 app = 116 tests, 0 failures |
| `swift test --package-path companion --filter RouterControllerTests` and `swift test --package-path companion --filter QuitAlertTests` — Task 2 API RED, each command | 1 each | Missing QuitGuidanceNavigation API stops compilation |
| Same controller and alert filters — Task 2 fixture correction runs, each command | 1 each | Internal `readExisting()` access rejected; no product-behavior claim |
| Same controller filter — Task 2 behavioral RED | 1 | 66 tests, 10 assertion failures across 3 new refresh tests with temporary no-work refresh scaffold |
| Same alert filter — Task 2 behavioral RED | 1 | 16 tests, 15 failures, including a thrown missing-boundary error; missing lifecycle/publication/current refresh exposed |
| Same controller filter — Task 2 GREEN | 0 | 66 tests, 0 failures |
| Same alert filter — Task 2 GREEN | 0 | 16 tests, 0 failures |
| `swift test --package-path companion --filter QuitGuidanceTests` — Task 2 GREEN | 0 | 12 tests, 0 failures |
| `swift test --package-path companion --filter ControlsPresentationTests` — Task 2 GREEN | 0 | 11 tests, 0 failures |
| `npm run companion:test` — Task 2 final GREEN | 0 | 89 core + 39 app = 128 tests, 0 failures |

Task 1 tests use real controller/delegate boundaries with synthetic private stores
and backend dependencies. They cover every guidance row, ownership loss before
alert presentation, unavailable journal/context, live uncertainty, safe Stop and
cleared blockers, fixed-copy sentinels and effect-free projection reads. Task 2
tests cover awaited serialization, inspection failure/generation changes, held
modal/refresh transitions, repeated/superseded request IDs, close cancellation,
unchanged alert cancellation/reentrancy, and byte-exact synthetic journal retention.
Passing task logs report no compiler warnings or error diagnostics.

Independent Task 1 specification/quality review approved the task. Independent
Task 2 specification then quality review approved the task. Both dispositions
retain native presentation and whole-increment review as later obligations.
These tests establish projection and controller/delegate behavior, not observed
SwiftUI scrolling, focus, accessibility or cancellation visibility.

## Fresh automated acceptance

These commands ran sequentially from the repository root on 2026-11-12 against
the reviewed Task 1/2 product commits and this documentation update. Complete
outputs and actual process exit statuses were inspected; full logs and a command/
exit/time manifest remain in the ignored task workspace during execution.

| Command | Exit | Fresh observed result |
| --- | --- | --- |
| `npm run companion:test` | 0 | 89 core + 39 app = 128 native tests, 0 failures |
| `npm test` | 0 | 664 tests passed, 0 failures, 0 cancelled, 0 skips |
| `npm run companion:build` | 0 | Release build completed; `Built and ad-hoc signed dist/Codex Project Router.app` |
| `npm run companion:package-test` | 0 | 3 tests passed against the fresh app, 0 failures, 0 cancelled, 0 skips |
| `node --check src/cli.js` | 0 | No syntax diagnostics |
| `git diff --check` | 0 | No whitespace diagnostics |

Passing logs contained no compiler/runtime warnings or failure diagnostics. The
package run established relocated resources/signature and synthetic inspection/
lifecycle under a minimal GUI-like environment. Seatbelt denied lexical/resolved
and symlink checkout reads; the source-read negative controls returned EPERM and
ERR_MODULE_NOT_FOUND. The relocated signed native process displayed its own
on-screen window and held the synthetic companion instance lock. Under the same
policy, synthetic listener/readiness, activation, byte-exact rollback and unchanged
router bytes passed; both tracked children exited and the selected synthetic port
was reusable. This is automated fixture evidence only: it does not establish Quit
interaction, scrolling, emphasis, focus, accessibility or cancellation visibility.

## Isolated native observation

Pending; parent-owned. Automated package checks do not establish the following
interaction or usability observations:

- Primary guidance from open, closed, minimized and project-scrolled Controls;
  recovery expansion, visible emphasis and repeat navigation to the same target.
- Ordinary polls preserving user scroll/focus, close/reopen clearing guidance,
  keyboard/accessibility reachability and no highlighted operation invocation.
- Current unavailable-journal and owned-confirmation destinations/text with
  unchanged synthetic provider/router/journal bytes after showing guidance.
- Keep Running/Escape/cancel visibility preservation, with attributed human
  observation if a UI inspection tool activates/restores the window.
- Clean idle Direct exit without a dialog and retained pending recovery on
  relaunch, using the fresh signed build.

Native verification must use only a confined, relocated signed synthetic fixture
with owner-only HOME/CFFIXED_USER_HOME, denial of real private/checkout access and
non-loopback outbound traffic, a negative checkout-read control, positive native
instance-lock/process proof and exact tracked-process/port cleanup. Raw fixture
paths, PIDs and checkpoints stay outside Git. No real operational/private changes,
credential access, Codex restart or model response is required or claimed.

## Review and completion

Pending: parent native evidence and privacy/process cleanup, independent Task 3
review, then the sole integrated final specification review followed by quality
review for the follow-up range starting at
`f1e00832a000510043a02e6abce442a4d8ee473d`. No final disposition or completed
native acceptance is claimed. Lifecycle/checklists stay open until those items
have actual evidence and review dispositions.
