# Companion blocked-Quit alert validation

Date: 2026-11-12

Status: completed. Automated checks, isolated native idle exit/relaunch, attributed human closed-window cancellation and final sequential specification/quality reviews passed. Original evidence and its historical qualifications are preserved below.

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

## Original alert automated evidence

Task 2 commands ran from the repository root. Full outputs and exit statuses were
inspected and held in the ignored task workspace during execution. Sanitized
results and final dispositions are preserved here; temporary workflow files are
removed after the clean final gate.

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
GUI control actions; those observations are recorded separately below. No warnings or failures appeared in the passing verification logs.

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
suite are covered by the full native run. Its independent task review passed;
final whole-increment dispositions are recorded below.

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
the human-observed Escape/minimized result. At that stage, closed-window
preservation had not been separately confirmed by an explicit user report. The final observation below
now supplies that evidence.
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
Raw fixture paths/checkpoints stayed outside Git. At that stage no whole-increment
completion was claimed; the final outcome is recorded below.

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
raw logs were held in the ignored plan workspace during execution. Sanitized
results are retained here after temporary-workspace cleanup.

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

Idle success does not establish desktop-loaded settings, alter owned-listener
safeguards or resolve why an earlier confirmation reopened. The separate
denied-alert closed-window observation follows.

### Final native closed-window cancellation evidence

Final specification review identified the missing AC-04 evidence: Keep Running
and Escape after denied Quit must preserve closed Controls. A fresh copy of the
same signed release app ran under the isolated synthetic HOME/CFFIXED_USER_HOME
and Seatbelt procedure above. The exact tracked native process held the synthetic
instance lock. Initial native CUA state showed open, readable Controls with Valid
configuration, Direct settings, no owned router and Not confirmed. No listener,
routing, confirmation or authentication action was invoked.

After initialization, the fixture saved the original journal bytes and replaced
only its synthetic journal with invalid literal bytes. This makes the fresh idle
Quit permission fail without starting a listener or changing real settings.
Router configuration and provider bytes remained unchanged, and the synthetic
port was empty.

The automation could not provide a reliable nonactivating observation: with
Controls visibly open as a positive control, both CUA app/state inventories
omitted the fixture and returned no window lists. Inventory absence therefore
was not used as proof. The user instead performed and observed the final case:
closed Controls, chose Quit from the companion menu icon, clicked Keep Running,
then chose Quit again and pressed Escape. The user explicitly reported:
**“Both left the window closed.”** No target-app accessibility read or other
automated UI inspection occurred after the user closed Controls. This is
attributed human evidence for both native cancellation paths, alongside the
earlier human-observed minimized Escape result.

After that report, the harness verified that the exact tracked process still
held its synthetic lock, the deliberately invalid journal bytes had not changed,
router/provider bytes were unchanged and the port remained empty. Cleanup
restored the original pending journal bytes before signalling only the tracked
synthetic process. It observed that process exit, repeated the original-byte and
empty-port checks, and removed only the temporary fixture. No product source
changed after the fresh build; no full suite was rerun for this evidence-only
update. Raw fixture details stayed in the ignored workspace during execution;
independent final review dispositions follow.

## Operational-state safeguards

Unit tests use temporary owner-only stores, sentinel context/error values and
synthetic `Process` handles. Existing native/Node/package fixtures use their own
controlled temporary state and processes. No real private router/provider
configuration or Keychain was selected or changed by this increment; no real routing
activation, provider credential lookup, Codex restart or model prompt was used.
The app tests inject native presentation/window/termination boundaries, so they
neither show a modal dialog nor exit the test process.

## Review dispositions and final gate — passed

Independent task reviews approved Tasks 1–5 code and automated evidence with no
findings. Parent-owned native idle verification and the final attributed human
closed-window cancellation evidence are recorded above.

The sole integrated sequential gate reviewed the full increment from prerequisite
`c2887a5` through `cc2efff`, including the original alert and revised idle Quit.
Initial specification review reported one missing AC-04 native observation. The
single evidence-only corrective wave obtained the user's closed-window result,
verified fixture cleanup and changed only this validation report. Scoped
specification follow-up passed, with the finding addressed and no new issues.
Quality review then passed with no findings on the same frozen package; current,
expected and echoed review identities and the package hash matched.

The delivered source is unchanged from the fresh signed build. Final closeout
changes only artifact lifecycle/checklist metadata and this sanitized report.
The existing branch and checkout are preserved; no push or merge is performed.
General alert wording/navigation remains deferred. Real provider operation and
Codex-loaded settings were not revalidated by these isolated tests.

## Recorded workflow rulings

1. The coordinator owned manual native verification, evidence consolidation and
   final review after worker implementation. Missing manual coverage would have
   blocked completion; the final observations above now resolve it.
2. Fixed native-copy tests and real controller/delegate boundary assertions were
   treated as product behavior checks. Wrong fixtures could miss integration
   defects; isolated native observations supplemented those assertions.
3. Prior clean task reviews and the user's minimized-Escape observation were
   retained without replaying completed tasks. Earlier closed-window limits
   stayed explicit to avoid overstating evidence; the final human check now
   supplies the previously missing observation.
