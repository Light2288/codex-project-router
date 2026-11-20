# Keychain lookup fix validation

Created: 2026-11-20

Updated: 2026-11-21

Scope: `keychain-lookup-fix`; approved specification and matching plan dated
2026-11-20. Stage 4 complete: implementation, rebuilt-app interaction, sequential
review, documentation and local verification are complete, subject to the explicit
parallel-run GUI verification limitation below. No push or merge is authorized.

## Evidence boundary

The earlier user-Keychain diagnosis used metadata only and established that
unusable unrelated rows could abort discovery despite a supported exact match.
That diagnosis is historical defect evidence, not acceptance of the changed app.

Current automated tests inject only the native Security boundary and retain real
KeychainStore, controller and SwiftUI behavior. All fixture references and state
are synthetic. No real user credential was read, created or changed by these
focused tests, and no real router/configuration was started or modified.

## Checks actually run

| Command | Observed result |
|---|---|
| `npm run companion:test` before implementation | Exit 0; 268 core + 111 app tests; zero failures |
| `swift test --package-path companion --filter KeychainStoreTests` RED | Exit 1; expected missing `browseMetadata` API before implementation |
| Same core command GREEN and task completion rerun | Exit 0; 16 tests; zero failures |
| `swift test --package-path companion --filter AccountSetupControllerTests` RED | Exit 1; new listing/count contract absent |
| `swift test --package-path companion --filter AccountSetupPresentationTests` RED | Exit 1; completed state did not accept omission count |
| `swift test --package-path companion --filter AccountSetupActionTests` RED | Exit 1; integration contract absent before implementation |
| The three preceding focused commands GREEN | Exit 0; 23 controller, 16 presentation and 5 action tests; zero failures |
| Action suite after adding viewport reachability checks | Exit 0; 5 tests; zero failures |
| `npm run companion:test` after integration | Exit 0; 279 core + 115 app = 394 tests; zero failures |
| `npm run companion:build` | Exit 0; rebuilt and ad-hoc signed the canonical dist app |
| `npm test` | Exit 0; 1,095 passed; zero failures, cancellations or skips |
| `npm run companion:package-test` | Exit 0; all 3 passed; zero failures, cancellations or skips |

SwiftPM compiles the test targets before filtering, so the initial integration
RED runs can report a missing interface in another selected test target. The
failure reasons were the planned not-yet-implemented listing/completion contracts.
The durable results and boundaries are recorded here. This plan's temporary
execution workspace is removed at local closeout; build outputs and synthetic
fixture PNGs remain outside Git.

## Native fixture inspection

The real AccountSetupView was hosted at its existing 650×690 logical size using
the existing NativeProjectHost. Tests scroll to the metadata selector and assert
that its explanation and Use action are inside the visible scroll viewport.
The initial unscrolled captures did not show the result area; only the subsequent
scrolled captures support the observations below.

Four synthetic PNGs under ignored `companion/.build/project-list-qa/` were inspected:
`keychain-mixed-results`, `keychain-omitted-only`, `keychain-failed` and
`keychain-pending`. Match counts, omitted counts/explanation, captured scope,
picker and disabled Use action were readable without observed overlap. The
pending view retained “any service” after the service field was edited. Failed
and pending states had zero picker results and no stale omission explanation.
The scroll view preserved access to other form fields and fixed Close/Save actions.

Native interaction assertions cover a user-entered draft name surviving repeated
lookups, no automatic item application, no save/start/activation, and no receipt
or lease creation. Successful popup selection in the rebuilt production app was subsequently
confirmed by the user, separately from these hosted-view assertions: the selected
reference populated the form, which was then closed without saving.

## Acceptance coverage

| Criteria | Evidence / current status |
|---|---|
| AC-01, AC-02 | Mixed/missing/type/empty/control/limit/Unicode rows, row order, once-per-row omission, empty and all-omitted tests pass; UI counts inspected |
| AC-03 | Secret-bearing and contradictory fields take precedence over omission, including mixed-invalid rows and either order; fixed safe errors |
| AC-04, AC-05 | Later-Keychain/native/search-list/path failures reject entire results; filter/path scope and duplicate search paths tested; native decoding/open guards unchanged |
| AC-06 | Strict listing/exact lookup rejects omitted rows; existing duplicate/cross-Keychain ambiguity and exact validity tests pass; incoming/recovery strictness tested |
| AC-07 | Attribute-only/file-backed queries, serial execution and zero focused-test mutations asserted; creation/native adapter unchanged; full package regression passed |
| AC-08 | Presentation states, captured scope, clearing, disabled Use and draft preservation pass; actual rendered result area inspected; user confirmed production listing, explicit application and unsaved dismissal |
| AC-09 | Controller preview/default/bindings preserved; no saved configuration/receipt/lock writes in browse fixtures; malformed recovery evidence retains receipt/lock and blocks creation; full regressions passed |
| AC-10, AC-11 | Focused RED/GREEN and fixture visual evidence complete; full chain passed; production listing/application/dismissal confirmed; sequential reviews passed; final results and verification limitation recorded below |

## Production metadata-only probe and remaining search-list limitation

A supplementary, temporary count-only harness was compiled from the actual
production sources using the same `xcrun swiftc -parse-as-library -target
arm64-apple-macos14.0` source list as the existing package probe. It called only
`KeychainStore.browseMetadata` and emitted fixed outcomes/counts, never item
identities or values. The initial unrestricted invocation exited 1 with a fixed
failure marker; a bounded diagnostic then established:

| Scope | Actual production result |
|---|---|
| Native search list | Unsupported; no partial result published |
| Exact supported login Keychain | 59 selectable references, 10 omitted items |
| Exact second supported user Keychain | 0 references, 0 omissions |

The cause was isolated without changing product code: `SecKeychainCopySearchList`
returned three paths, including the system-owned System Keychain. Its file was
regular but not owned by the user, so existing native opening validation rejects
it. The command-line user-domain list exposed only two user-owned paths; that
command is not equivalent to the native API used by the product. A separate
metadata-only shape probe confirmed native list success/count 3 and ownership
false for the system path, without opening items or retrieving credentials.

This is the approved whole-Keychain failure boundary, not a reason to silently
skip an unsupported Keychain or broaden the reader. The row-handling fix is
verified by the successful production login result, which previously failed on
unusable unrelated rows. Exact path selection remains necessary for this user's
full native search-list environment. Any automatic exclusion/partial-success
policy would require separately confirmed scope. No additional product change
was made during this investigation.

## Remaining checks

The full changed native suite, signed app build, Node suite and three package
checks passed. The package harness exercises owned disposable native items,
reader comparison and bounded failure cleanup; it does not read or modify the
user's existing credential values. File-backed Security API deprecation warnings
remain an intentional compatibility limitation, without global suppression.

Before rebuilding, the prior app was asked to Quit through its normal application
event. The initial event returned cancellation because its delegate initially
cancels termination; subsequent process inspection confirmed the old process had
exited. No force quit or router Stop was used. The rebuilt canonical app was then
opened and observed running at its exact dist executable path (PID 10738 in this
session). System Events again reported zero accessible companion windows. No
accessibility-enhancement loop was repeated.

The user was initially asked for an unrestricted listing. After isolating the
unsupported-system-Keychain failure, the live check was corrected to an exact
supported login path with empty service/account filters, explicit reference
application in an unsaved Add account form, then Close without Save. That
production listing was subsequently confirmed by the user: “i worked, found 59 matching results”. The response establishes 59 visible matches; it does not separately confirm the omission count, explicit application or Close without Save. The subsequent answer “Yes, it populated the form; closed without saving” confirms explicit application and unsaved dismissal. Human observation of the production omission count remains unreported; omission rendering was inspected in the documented native fixtures. The final specification review initially identified missing live interaction evidence. The subsequent human confirmation closed that gap in a targeted follow-up; specification and quality reviews then passed. Final verification and local documentation closeout are recorded below.

Real Keychain query failures still reject a whole listing. Metadata compatibility
never proves credential readability, provider acceptance or billing attribution.

## Idle-time router timeout investigation

During the pending rebuilt-app check, the user reported “The router command
timed out” after leaving the screen idle for a long time; the triggering action
and exact time were unknown. This wording originates in ProcessBackend, not
KeychainStore. Controls poll RouterController every two seconds while visible
and five seconds otherwise. Account setup also invokes the read-only setup
preview when opened.

Read-only packaged-CLI probes using the configured Node 24 and its production
child-environment allowlist succeeded: Node validation 0.027 seconds, inspection
0.105 seconds (valid configuration, direct provider, ready catalog), and setup
preview 0.066 seconds (ready). A temporary harness compiled from all actual
CompanionCore sources additionally exercised ProcessBackend itself, including
runtime discovery, bounded stdin/stdout handling and its five-second deadlines.
Inspection succeeded in 0.300 seconds and setup preview in 0.112 seconds.
No credential values were read and no routing/configuration operation was invoked.
These are fresh probe observations, not an observation of the open app's state.

Source tracing established that inspectionFailed sets RouterController.error,
while a subsequent successful inspection/reconcile does not clear that property.
Consequently the timeout text can remain visible after fresh evidence succeeds.
This is existing behavior outside this increment's changed files. The original
timeout was not reproduced and its cause remains unestablished; idling or sleep
is not claimed as its cause. No timeout, error-lifecycle or routing code was
changed. Production listing subsequently returned 59 matches according to the user, who also confirmed explicit application and Close without Save.

## Final review — resolved acceptance gap

The sole integrated gate's specification stage returned **MISSING**, limited to
AC-10's live explicit-selection check. Package identity was verified and no extra
product scope was found. Gate `cfc11991-46f6-404d-8678-53fec6f7f98f`, reviewed state
`9eb5f253-4d6e-4eb7-a793-75b8f0db1835`, package SHA-256
`30dac010c08ec8b85df071f6eb8564ce0f68a7cd2c9f4d454d0c8fc7bf74b2ab`.

The reviewer requires evidence that the rebuilt selector shows its omission
explanation where present, explicitly applies a chosen result through Use this
reference, and closes without saving. The user's 59-match report establishes
listing success only. Quality review was correctly withheld at that initial stage. The subsequent user
answer, “Yes, it populated the form; closed without saving”, resolved explicit
application and dismissal. The same specification reviewer verified only the
missing evidence and returned **SPEC REVIEW: PASS** on the unchanged package and
identities. Its report explicitly distinguishes the human 59-match/application/
dismissal observation from the production probe 59/10 counts and fixture-only
omission rendering. The quality reviewer then verified the identical package
against the fresh PASS report and returned **QUALITY REVIEW: PASS**, findings
**NONE**. No product/test change or quality fix pass was needed, and no Minor
findings were deferred. Final verification results are recorded below.

A subsequent integrity check actually run was
`codesign --verify --deep --strict 'dist/Codex Project Router.app'` (exit 0).
Process inspection still showed the same canonical executable at PID 10738;
`git diff --check` also exited 0. These checks do not imply live form interaction.

## Final regression reruns

The first final `npm test` exited 1 with 1,093 passes, zero assertion failures
and two timeout cancellations. Its elapsed time was 3,385.152 seconds. Read-only
power-log evidence shows idle sleep starting at 17:53:31 Europe/Rome, followed
by repeated maintenance sleeps until full wake at 18:49:39. The two timed-out
package checks reported 554.929 and 225.325 seconds across approximately 554-
and 220-second sleep intervals. This establishes suspension during that run;
it does not identify the trigger of the earlier user-facing timeout.

The unchanged `npm test` rerun under temporary `caffeinate -i` completed in
63.488 seconds: 1,094 passes, one failure, zero cancellations. The first formerly
timed-out package check passed. The remaining failure was the native test
app's on-screen-window observation: regular application registered and running,
but no on-screen window observed within its 20-second budget. No assertion about
Keychain browsing failed. A read-only subsequent observation also found the
canonical app running with windows but none on screen; that does not establish
the cause of the separate test app's visibility failure.

The exact isolated `npm run companion:package-test` under the same temporary
assertion subsequently passed all three checks in 39.058 seconds, including the
on-screen-window check (13.261 seconds), while the canonical app remained open.
The visibility observation failure's precise cause remains unestablished. No test deadline,
assertion, product code or system preference was changed. A further unchanged default-parallel `npm test` confirmation again exited 1
with 1,094 passes, one on-screen-window observation failure and zero cancellations
(63.426 seconds). The native app was registered, regular and running but not
observed on screen within the existing deadline. This failed default-parallel
result remains a verification limitation; it is not recorded as a green run. Every sleep assertion lasts only for its test
command; test-owned processes and synthetic Keychains retain existing cleanup.

## Rulings and evidence limits

- Credential readability/provider acceptance remains unverified: the approved
  metadata-only scope excludes these probes. Cost if wrong: a selectable
  reference can still fail when later used.
- The original user-facing router timeout cause remains unknown: its time and
  trigger were unobserved, current backend probes pass, and its unchanged error
  lifecycle is outside this fix. Cost if wrong: an unrelated timeout or lingering
  message may recur.
- Independent human observation of the production omission count is not inferred:
  the actual production probe returned 59/10, native fixture omission states were
  visually inspected, and the human confirmed 59 matches/application/dismissal.
  The specification reviewer accepted that AC-10 evidence boundary. Cost if wrong:
  a production-only omission-copy rendering issue could escape these checks.

## Final results and local delivery

| Final command | Actual result |
|---|---|
| `caffeinate -i node --test --test-concurrency=1 test/*.test.js` | Exit 0; all 1,095 tests passed, zero failures/cancellations/skips; 131.833 seconds |
| `caffeinate -i npm run companion:package-test` | Exit 0; all 3 passed, zero failures/cancellations/skips; 39.058 seconds |
| `npm run companion:test` through the required task-done script, under temporary `caffeinate -i` | Exit 0; 279 core + 115 app = 394 tests, zero failures; core 124.523 seconds and app 24.641 seconds |
| Default-parallel `npm test`, last two awake runs | Exit 1 each; 1,094 passes and one native on-screen-window observation failure; no assertion/deadline was changed |

The final native task script's tail reports zero tests for the additional Swift
Testing runner. The complete XCTest output proves the 279 core and 115 app tests
above; that empty runner is not the test count. Both plan tasks are complete.
The initial default-parallel Node run before the live-app check passed all 1,095
checks; the later observed failures and the passing sequential comparison are
reported separately rather than replacing that history.

Sequential execution uses the same entire test-file glob and every assertion
and deadline. The isolated and sequential native-window checks passed while
the canonical app remained open. Full-suite concurrency is therefore an observed
difference; its precise scheduling/WindowServer cause was not established, and
no claim is made that serial execution repairs it. Default-parallel local/CI
runs may still fail this existing observation check. No script or product change
was introduced to hide that limitation; fixing the unrelated window-test behavior
would be separate work.

One coordinated normal guarded Quit was attempted during the comparison.
Immediately beforehand the production backend again reported valid/direct
inspection (0.392 seconds) and ready setup preview (0.110 seconds). The Apple
event returned cancellation and PID 10738 remained running after a subsequent
check. The guard was respected: no force quit or automatic alert response was
used. The proposed comparison with the canonical app closed was not performed,
so duplicate-app interference is not asserted as a cause.

The canonical app remains `dist/Codex Project Router.app`; it was built and
ad-hoc signed from the reviewed production code. The user confirmed 59 visible
matches, successful Use this reference application, and Close without Save.
The production omission count/explanation is not independently attributed to
the user: the production probe and inspected native fixtures remain the stated
sources. The supported exact login path is still required in this user's native
search-list environment; the preserved system-Keychain failure is not relaxed.

The sole final review gate returned SPEC REVIEW PASS followed by QUALITY REVIEW
PASS, findings NONE. No code fix pass or deferred Minor findings were needed.
Only lifecycle/evidence documentation changed after that reviewed product state.
The local branch is `fix/keychain-lookup`, based on `6612e45`, with implementation
commits `90d1ab0` and `5c628b1`, artifact approval commit `47ee58a`, earlier
verification commit `b7111d1`, and the documentation closeout commit containing
this report. No push, merge, new worktree or subsequent increment was performed.

- Final verification ruling: use the full sequential Node result alongside the
  isolated package and full native results, while retaining the failed default
  parallel runs as a limitation. Cost if wrong: default parallel local/CI runs
  may still fail the window observation. The production code and all test
  assertions/deadlines remain unchanged.
