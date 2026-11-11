# Companion blocked-Quit alert validation

Date: 2026-11-12

Status: automated verification passed; isolated native observations and final sequential review pending.

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

## Isolated native observation — pending

No manual blocked-Quit fixture or UI interaction has been performed for this
report yet. Required observations remain menu Quit and Cmd-Q with Controls open,
closed and minimized; exact direct-pending alert; Open Controls visibility;
Keep Running/Escape visibility preservation; and repeated Quit producing one
alert. Automated injected presentation tests do not establish native visibility.

The pending check must use the approved synthetic relocated-app/Seatbelt
procedure, temporary `HOME` and `CFFIXED_USER_HOME`, a positively tracked native
PID holding its synthetic instance lock, denied real private/check-out paths and
non-loopback outbound access, and unchanged synthetic provider/config bytes with
no child listener. Raw fixture paths/checkpoints stay outside Git.

## Operational-state safeguards

Unit tests use temporary owner-only stores, sentinel context/error values and
synthetic `Process` handles. Existing native/Node/package fixtures use their own
controlled temporary state and processes. No real private router/provider
configuration or Keychain was selected or changed by Task 2; no real routing
activation, provider credential lookup, Codex restart or model prompt was used.
The app tests inject native presentation/window/termination boundaries, so they
neither show a modal dialog nor exit the test process.

## Final sequential review — pending

Specification review must pass before quality review of the whole increment from
`c2887a5` through the final implementation and evidence. Both dispositions and any
follow-up checks remain pending. No whole-increment completion is claimed here.
