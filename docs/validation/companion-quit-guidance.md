# Companion Quit guidance validation

Date: 2026-11-12

Status: completed. Native and automated acceptance, independent task reviews and
the sole final sequential specification/quality gate passed. No final findings
remain. The existing checkout and local branch are preserved.

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

The parent used a fresh relocated copy of the signed release app in an owner-only
synthetic HOME and CFFIXED_USER_HOME, with 60 synthetic projects. Seatbelt denied
real Codex/router private paths, checkout reads/writes and non-loopback outbound
traffic. A negative checkout-read control failed as required, and each tracked
native launch positively held its synthetic instance lock. Initial on-screen
window presence was independently established. The Mac was initially locked; UI
interaction resumed only after the user unlocked it.

### Unavailable evidence, navigation and focus

Only after initialization, the harness replaced its synthetic pending journal
with invalid bytes to force a fresh denied Quit. Cmd-Q displayed the exact
unavailable-evidence description with **Show steps to quit** and **Keep Running**.
Return on the primary action revealed the existing window, expanded its manual
recovery disclosure and brought the target into view. AX and screenshots showed
the fixed inline guidance, semibold text and black outline. The focused element
was the non-actionable guidance text. Tab moved to project search without
invoking an operation.

After scrolling to synthetic project rows 35–44, multiple ordinary two-second
polls left the visible rows and scroll placement unchanged. A new Quit/primary
request for the identical destination returned to the expanded recovery target,
with guidance focus and emphasis. This was an explicit new request, not polling.

The automation also invoked minimize, then Quit/primary, and separately red close,
then Quit/primary. Final screenshots in both sequences showed the one existing
window and readable targeted recovery guidance. These are action/result sequences;
automation activation prevents an independent claim about hidden/minimized
visibility between those calls. Red close followed by ordinary Cmd-O reopen
removed guidance and outline, without replaying navigation. Existing disclosure
expansion remained ordinary view state.

Task 3 review identified that those initial automated sequences did not establish
genuinely closed/minimized starting states. The parent obtained independent human
observation in a second owner-only confined fixture of the unchanged signed build.
Fresh signed relocation, negative checkout-read and positive synthetic native
instance-lock controls passed. After initialization, only that fixture's synthetic
journal was made invalid. No target-app inspection occurred during the handoff.
The user minimized Controls and chose menu-bar Quit → **Show steps to quit**, then
closed Controls with the red button and repeated the same path. Asked whether
both brought the window forward with expanded, highlighted recovery guidance, the
user reported **“Both revealed the highlighted recovery step.”** This establishes
primary reveal/deminimize/navigation from the actual minimized and closed starting
states, resolving the missing visibility evidence. It does not strengthen the
earlier automated sequences beyond their original qualification. No routing or
response-confirmation button was used.

After this follow-up, the harness verified unchanged original synthetic
router/provider bytes and the deliberately invalid journal. It restored only the
original synthetic journal, verified exact tracked native-process exit and an
empty selected port, and removed only the follow-up fixture. Its process and
cleanup checks passed; no product code, real private state or signed build changed.

For cancellation visibility, no target-app inspection occurred during the human
handoff. The user performed menu-bar Quit → Keep Running and repeat Quit → Escape
with the window minimized and reported **“Both left it minimized.”** The user then
closed the window and repeated both paths, reporting **“Both left it closed.”**
These are attributed human observations rather than inferred automation results.
The harness subsequently verified the exact native process remained alive and
that router/provider bytes and the deliberately invalid journal were unchanged.

### Idle Quit, retained recovery and owned-router guidance

The harness restored only its original synthetic journal. Explicit Cmd-Q exited
naturally with code 0 and no signal, without a manual response check, Codex restart
or model request. Router configuration, provider settings and pending journal
bytes were unchanged, and the selected port was empty. No post-Quit target-app
inspection was made before process-exit verification, avoiding accidental relaunch.

Fresh relaunch retained pending recovery and showed Direct, no matching listener,
no owned router and Not confirmed. The parent clicked **Start router** only in this
confined fixture. The app showed matching readiness and ownership; the harness
positively tracked the exact Node child by parent PID and bundled CLI/config
identity. No activation or upstream request occurred.

Application-menu Quit displayed the exact owned-router description. The primary
action focused the approved owned-confirmation guidance and visibly outlined the
existing direct-response button. Return while guidance text was focused invoked
nothing; Tab moved to search, desktop confirmation stayed Not confirmed and all
synthetic router/provider/journal bytes remained unchanged. The response-confirmation
button was never pressed.

The parent then sent SIGTERM only to that positively tracked synthetic router,
leaving the native app running. AX and screenshots showed the obsolete restart
instruction removed and the exact idle retry guidance at operational facts.
Search retained keyboard focus; there was no new explicit navigation request,
automatic Quit or confirmation. Explicit Cmd-Q subsequently exited naturally with
code 0 and no signal, preserving the pending journal and unchanged provider/router
bytes, with the port empty.

### Cleanup and limits

The harness restored the original synthetic journal, verified all exact tracked
native/router processes had exited and the selected port was empty, then removed
only its temporary fixture. Raw fixture paths, process identities, checkpoints
and runtime evidence stayed outside Git. No product code changed after the fresh
build, so automated acceptance was not repeated for this evidence-only update.

Accessibility evidence covers exposed AX text/buttons, explicit guidance focus,
Tab movement and Return invoking no default operation. A full VoiceOver audit is
not claimed. Hidden/minimized cancellation relies on the attributed human result;
the initial automated primary-reveal sequences retain their activation
qualification. The separate attributed human follow-up above resolves the
closed/minimized primary starting-state evidence gap.
No real operational configuration, Keychain, gateway/model call or Codex restart
was used. These tests establish neither desktop-loaded settings nor live billing
or complete stream delivery. Predecessor history and its qualifications remain
unchanged.

## Review and completion

Independent Tasks 1 and 2 specification/quality task reviews passed with no
findings. The initial Task 3 review identified one Important evidence gap: the
automated primary-reveal sequences did not independently establish hidden/minimized
starting states, so the native-completion claim was premature. One evidence-only
correction obtained the attributed user result above and retained the original
automation qualification. Scoped re-review marked the finding addressed with no
new breakage; the Task 3 deliverable is approved.

The sole integrated final gate reviewed the complete 13-file follow-up diff from
`f1e00832a000510043a02e6abce442a4d8ee473d` through
`18189380d0fcd2239d5426f119f3ab4430ca20c5`, with the approved pair, full production
context, task dispositions and actual automated/native evidence. Specification
review passed with no findings before quality review opened. Quality review then
passed with findings NONE. Current, expected and echoed package identities and
exact-byte hash matched; the package stayed unchanged across the two stages.
No final corrective wave was needed.

Closeout changes only lifecycle/checklist metadata and this sanitized record.
Product/test sources and the signed build remain the versions covered by fresh
acceptance; no redundant full suite was rerun for those documentation-only changes.
Whitespace and clean-Git checks complete the closeout. Full VoiceOver and live
operational validation remain unproven as documented. No push, merge or further
increment is performed.
