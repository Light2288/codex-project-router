# Companion blocked-Quit alert validation

Date: 2026-11-12

Status: initial alert and revised idle-Quit implementation passed automated verification and isolated native idle exit/relaunch checks. Independent task reviews passed; final sequential review is pending. Prior denied-alert visibility qualifications remain below.

Scope: the approved `companion-quit-alert` increment, stacked on the completed,
unmerged companion operational-controls prerequisite (`c2887a5`). The approved
specification and plan are `docs/superpowers/specs/2026-11-11-companion-quit-alert.md`
and `docs/superpowers/plans/2026-11-11-companion-quit-alert.md`.

## Behavior and boundaries

The controller's existing Quit authorization remains authoritative. Task 1
(`9ce48b8`) adds the read-only blocking-reason projection. The app now presents a
fixed native **Cannot quit yet** warning only after an unsuccessful existing Quit
attempt. **Open Controls** (Return) reveals the existing window; **Keep Running**
(Escape/cancel) dismisses without retry or window action. A synchronous delegate
guard covers the entire attempt, modal response and action. Successful authorized
Quit, including initialization-failure and second-instance safe exceptions,
terminates without a blocked-Quit alert.

In the initial Task 1/2 alert implementation, no changes were made to backend/wire
behavior, `canQuit`, controller Quit/stop permissions, recovery/confirmation rules,
journal schema, Controls refresh, or prior validation reports. This increment
does not diagnose confirmation reopening.

## Automated evidence

Task 2 commands ran from the repository root. Every command's full output and
exit status are retained in the ignored plan workspace
`.superpowers/sdd/2026-11-11-companion-quit-alert/task-2-*.log`.

| Command | Exit | Observed result |
| --- | --- | --- |
| `swift test --package-path companion --filter QuitAlertTests` before production edits | 1 | Expected RED: `cannot find 'QuitAlert' in scope`; missing injected delegate initializer and returned-task API diagnostics |
| `swift test --package-path companion --filter QuitAlertTests` after implementation | 0 | 7 tests passed, 0 failures |
| `swift test --package-path companion --filter ControlsPresentationTests` | 0 | 4 tests passed, including unchanged window-close behavior |
| `npm run companion:test` | 0 | 85 native tests passed: 74 core and 11 app tests; 0 failures |
| `npm test` | 0 | 664 tests passed, 0 failures, 0 skips |
| `npm run companion:build` | 0 | Release app built and ad-hoc signed |
| `npm run companion:package-test` | 0 | 3 tests passed against fresh app, 0 failures, 0 skips |
| `node --check src/cli.js` | 0 | Syntax check passed |
| `git diff --check` | 0 | No whitespace errors |

Fresh package checks verified relocated metadata/resources/signature, synthetic
inspection/lifecycle, source-denial confinement, a visible native window and its
synthetic instance lock. The package test also observed byte-exact rollback,
tracked-child exits and a reusable synthetic port. It explicitly does not infer
GUI control actions; the blocked-Quit interaction observations below remain
pending. No warnings or failures appeared in the passing verification logs.

The seven new tests exercise the real controller with temporary private journals
and a synthetic backend, constructing `NSAlert` without presenting modal UI:

- Four exact fixed messages, warning style, button order and Return/Escape
  bindings, with a private sentinel in context/revision/error fixtures absent
  from all alert text.
- First, second, abort and cancel responses; only the first reveals Controls.
  Journal, confirmation, recovery context and inspect/control/stop counts are
  captured after the denied attempt and remain unchanged by the response.
- Synchronous rejection before the first Task runs, plus reentrant common
  termination requests during held inspection, stop and alert response. One
  inspection/stop/alert occurs, with no queued duplicate cleanup.
- State becoming safe during an alert through existing explicit confirmation;
  dismissal does not retry Quit or terminate.
- Successful normal and safe-exception exits without alerts; common termination
  callback returns `terminateNow` only after the existing fresh authorization.

Task 1's five projection regressions and the existing lifecycle/authorization
suite are covered by the full native run. Its independent task review is recorded
in the local plan workspace; final whole-increment review is still required.

## Isolated native observation — partial

The parent launched a fresh relocated signed app in an owner-only temporary
synthetic HOME and CFFIXED_USER_HOME with an empty project catalog, a Direct
provider and a retained direct-confirmation journal. Seatbelt denied reads/writes
of the real Codex/router private locations and checkout, and denied outbound
network except loopback. A negative checkout-read control failed as required.
The exact tracked native PID held the synthetic instance lock before UI use.
No listener was started and the synthetic auth command was a nonexistent
placeholder that was never invoked.

Agent-operated native observations established:

- Application-menu Quit and Cmd-Q presented the native alert with the exact
  direct-confirmation title, message and two actions; native screenshot text was
  readable.
- Repeated Cmd-Q while the alert was open left one alert. Keep Running dismissed
  it without a queued alert; Open Controls dismissed it and revealed Controls.
- Quit after a close or minimize action presented the same alert; Escape
  dismissed it. These sequences do not independently prove the window stayed
  closed/minimized, because the automation activates/restores windows while
  reading their accessibility state.
- A tracked-PID CoreGraphics probe observed zero on-screen native windows after
  native minimize, then one after an accessibility read. This directly identifies
  the observation tool's window-restoration effect, rather than attributing it
  to the companion's Keep Running behavior.
- A fixture verification command confirmed synthetic router configuration,
  provider bytes and pending journal unchanged, and the selected port reusable.

The first fixture omitted the auth-command metadata required by the existing
provider parser and correctly displayed Unavailable. Comparison with the existing
package fixture identified the omission. That tracked synthetic process was
stopped and removed, and only the one-off fixture was corrected. Product code
and real private state were untouched.

The user requested a repeat of Escape. The earlier native PID was absent; its
remaining temporary fixture was cleaned. A new signed isolated fixture was
launched with the same protections and positive synthetic instance-lock proof.
The user explicitly reported: **Alert closes; window stays minimized** after
minimizing Controls, choosing menu-bar Quit and pressing Escape. This establishes
the human-observed Escape/minimized result. Closed-window preservation has not
been separately confirmed by an explicit user report and remains qualified.
The repeated fixture's router/provider/journal verification passed unchanged,
its port was empty, and its exact tracked process exited during cleanup; its
temporary directory was removed.

The user also reported three usability problems: the alert does not clearly
explain how to become able to quit; Open Controls does not explain the next
action; and that label is confusing when Controls is already open. These are
feedback on the approved copy/flow, not a claimed failure of Escape or the
safety rules. A targeted revision was then proposed through the existing
scope/specification/plan gates. At that observation stage, revised
wording/navigation had not been implemented or approved, and the final integrated
review had not been opened.
Raw fixture paths/checkpoints stay outside Git. No whole-increment completion
is claimed.

## Approved idle-Quit revision — automated evidence

Revision 2 of the specification and its separately approved revised plan authorize
Tasks 3–5. The behavioral correction allows a fresh Quit check to authorize exit
for an idle app with verified matching Direct settings and valid durable pending
recovery information. Successful idle exit preserves that pending journal; it
does not record desktop confirmation. Owned-listener shutdown and all remaining
guarded alerts retain their existing safeguards and exact native copy/actions.
The accepted **Show steps to quit** preference and general alert/button/navigation
refinement remain deferred.

Task 5 adds conditional Controls guidance using existing controller evidence.
Clean Direct with retained pending recovery and no owned child explains that
Quit must verify saved recovery information before idle exit. It separately
states that closing the idle app does not confirm Codex has reloaded settings.
An owned child retains the working-direct-response requirement before Stop or
Quit; uncertain/other retained recovery keeps the existing recovery guidance.
Absent or confirmed recovery omits the orange warning. Presentation neither
reads the private store nor grants exit authority.

The focused presentation command first exited 1 for the missing
`ControlsPresentation.recoveryGuidance` API before production edits, then exited
0 with 8 tests passing after implementation. The four existing setup, catalog,
window-close and polling tests are unchanged. New tests cover idle and owned
pending guidance, live backend uncertainty, and absent/confirmed recovery. Idle
presentation leaves journal bytes and modification time, recovery context,
unknown confirmation, Quit state and backend operation/inspection counts unchanged.
The owned fixture uses a synthetic process handle without launching a listener.

Task 5 ran the following fresh acceptance commands sequentially from the repository
root, once after the presentation change. Complete output and exits were inspected;
full logs remain in the ignored plan workspace under `task-5-*.log`.

| Command | Exit | Observed result |
| --- | --- | --- |
| `swift test --package-path companion --filter ControlsPresentationTests` before production edits | 1 | Expected RED: missing `ControlsPresentation.recoveryGuidance` API |
| `swift test --package-path companion --filter ControlsPresentationTests` after implementation | 0 | 8 tests passed, 0 failures |
| `npm run companion:test` | 0 | 102 native tests passed: 86 core and 16 app tests; 0 failures |
| `npm test` | 0 | 664 tests passed, 0 failures, 0 skips |
| `npm run companion:build` | 0 | Fresh release app built and ad-hoc signed |
| `npm run companion:package-test` | 0 | 3 tests passed against the fresh app, 0 failures, 0 skips |
| `node --check src/cli.js` | 0 | Syntax check passed |
| `git diff --check` | 0 | No whitespace errors |

Self-review then made the new fixture's cleanup failures explicit test failures;
the affected presentation suite reran with exit 0, 8 tests and no failures
(`task-5-presentation-cleanup.log`). Product source and the signed app were unchanged.

Passing logs contained no warnings or failures. The package run re-established
relocated signing/resources, synthetic inspection/lifecycle and source-denial
confinement. It observed a native window and synthetic instance lock, byte-exact
rollback, tracked child exits and a reusable synthetic port. This package coverage
does not establish menu/Cmd-Q interaction or idle exit/relaunch.

### Isolated native idle Quit and relaunch

The parent tested the fresh signed release app in an owner-only temporary HOME
and CFFIXED_USER_HOME. The fixture used literal pending direct-confirmation
information and a Direct provider, with no listener started. Seatbelt denied
real Codex/router private paths, checkout access and non-loopback outbound
network; the negative checkout-read control failed as required. Every launch
positively established that its tracked native process held its own synthetic
instance lock.

Three attempts exited normally: application-menu Quit with Controls open,
Cmd-Q after minimizing Controls, and application-menu Quit after closing Controls.
Each tracked process exited with code 0 and no termination signal. No blocked
alert, acknowledgement, Codex restart, model prompt or response-confirmation
input was needed. Process exit established success; accessibility attachment
was not used after Quit, since it can relaunch an app. Close/minimize sequences
establish exit after those actions, without claiming separate window-visibility
preservation against the automation's activation effects.

The same journal was retained across the three launches. Before each repeated
Quit, native state showed Direct, no matching listener ready, no owned router,
Not confirmed and pending direct-check guidance. No automatic routing occurred.
Byte comparisons after each natural exit and before relaunch confirmed that
router configuration, provider settings and pending journal were unchanged.
The selected synthetic port was empty each time. Cleanup required no process
signal, repeated those checks, and removed only the tracked temporary fixture.
No actual private operational configuration, credential or Keychain access,
Codex restart or model request was used.

Prior denied-alert observations remain separate and qualified; idle success
does not establish desktop-loaded settings, alter owned-listener safeguards or
resolve why an earlier confirmation reopened.

## Operational-state safeguards

Unit tests use temporary owner-only stores, sentinel context/error values and
synthetic `Process` handles. Existing native/Node/package fixtures use their own
controlled temporary state and processes. No real private router/provider
configuration or Keychain was selected or changed by Task 2; no real routing
activation, provider credential lookup, Codex restart or model prompt was used.
The app tests inject native presentation/window/termination boundaries, so they
neither show a modal dialog nor exit the test process.

## Review dispositions and final gate — pending

Independent task reviews approved Tasks 1–5 code and automated evidence with no findings. Parent-owned native idle verification is recorded above; the prior denied-alert qualifications remain. The sole final specification/quality gate remains pending.

Specification review must pass before quality review of the whole increment from
`c2887a5` through the final implementation and evidence. Both dispositions and any
follow-up checks remain pending. No whole-increment completion is claimed here.
