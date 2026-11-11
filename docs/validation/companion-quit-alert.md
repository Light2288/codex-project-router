# Companion blocked-Quit alert validation

Date: 2026-11-12

Status: implementation and automated verification passed; native visibility observations partially complete; two human observations and final sequential review pending.

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

No changes were made to backend/wire behavior, `canQuit`, controller Quit/stop
permissions, recovery/confirmation rules, journal schema, Controls refresh, or
prior validation reports. This increment does not diagnose confirmation reopening.

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

A native interactive request asks the user to check that Keep Running preserves
closed Controls and Escape preserves minimized Controls using the synthetic
companion's menu-bar Quit. Those two observations and final tracked-process
cleanup remain pending. Raw fixture paths/checkpoints stay outside Git. No
human report has yet been inferred from elapsed time, and no whole-increment
completion is claimed.

## Operational-state safeguards

Unit tests use temporary owner-only stores, sentinel context/error values and
synthetic `Process` handles. Existing native/Node/package fixtures use their own
controlled temporary state and processes. No real private router/provider
configuration or Keychain was selected or changed by Task 2; no real routing
activation, provider credential lookup, Codex restart or model prompt was used.
The app tests inject native presentation/window/termination boundaries, so they
neither show a modal dialog nor exit the test process.

## Review dispositions and final gate — pending

Independent task reviews approved Task 1 and Task 2 code and automated evidence
with no findings. Task 2 correctly leaves native observations and the final gate
for parent resolution.

Specification review must pass before quality review of the whole increment from
`c2887a5` through the final implementation and evidence. Both dispositions and any
follow-up checks remain pending. No whole-increment completion is claimed here.
