# Companion project routing On/Off validation

Created: 2026-11-12
Updated: 2026-11-13

Status: complete for the approved increment, with qualified live transport
results and two accepted minor UI limitations. Automated/native acceptance,
exact direct recovery and the final sequential specification/quality gate are
complete. All synthetic fixtures are cleaned up and the original Keyboard
navigation setting is restored. Work remains local; no push, merge or later
increment has begun.

Scope: the approved `companion-routing-on-off` increment. The approved
[specification](../superpowers/specs/2026-11-12-companion-routing-on-off.md) and
separate [implementation plan](../superpowers/plans/2026-11-12-companion-routing-on-off.md)
govern the integrated capability. Earlier validation reports remain historical
records with their original limitations; their results are not fresh evidence.

## Capability and boundaries

Explicit Start creates an owned listener with project routing Off. After initial
provider activation to a stable loopback URL, manual Codex restart and independent
working-response confirmation, ordinary On/Off changes need no desktop restart.
On applies explicit project overrides; an identified project without an override
inherits the existing global provider pair. Off retains saved overrides and uses
the global pair without looking up project credentials. In credential mode the
incoming authorization must first match a fresh global-credential read. Legacy
aliases retain the caller's credential and cannot select separate accounts.

Requests capture mode at HTTP receipt before the first asynchronous lookup;
active requests keep their chosen destination/credential and are never migrated
or retried. Identity/admission checks still apply. Supplied malformed/incomplete
targets fail strict loading in either mode; a selected explicit override failure
never falls back. Mode commands do not fetch credentials or probe destinations.
No HTTP mutation endpoint or credential-bearing control message is introduced.

Mode, readiness, ownership, on-disk provider state and desktop confirmation remain
independent. Uncertain commands require fresh read reconciliation before another
write; commands are never retried automatically. A mode-only acknowledgement or
read does not change the configuration fingerprint, provider URL, activation
record or restart/response obligations. Off still requires the listener and does
not authorize Stop or Quit. Restore direct, manual restart, working-direct-response
confirmation and guarded owned-child stop remain a separate recovery flow, bound
to the selected/retained context. External listeners are never adopted or signalled.
No automatic startup, last-used On restoration, desktop restart, fallback or
account/assignment management is delivered.

## Task 7 test-first packaging evidence

`npm test` ran before the production allowlist change: exit 1, 718 tests,
715 passed, 3 failed, 0 skipped. The assembly fixture correctly detected omitted
`src/managed-serve.js`; the relocated case detected the previous artifact's
omission. The source-denied case also exposed a test-fixture provider/upstream URL
mismatch introduced while adding the local HTTPS observer. That fixture was fixed
before proceeding; this third failure is not evidence for the product omission.

A subsequent focused `npm run companion:package-test`, still before the allowlist
change, exited 1: 3 failed, 0 skipped. Assembly and relocated resource assertions
required the missing file; the source-denied managed launch failed with
`MODULE_NOT_FOUND` for the bundled managed entry. Its negative checkout-read,
visible native window and positively attributed synthetic instance-lock controls
passed first. Stale-artifact failures are not acceptance results.

The production change adds only `managed-serve.js` to the explicit source list.
The three existing package tests are extended, without adding a fourth. They keep
arm64/signature checks, pinned dependency drift rejection, sentinel/private-file
exclusion, no embedded checkout/runtime path and minimal GUI environment. Managed
Ready Off, persistent stdin and correlated get/set On/get/set Off are exercised
both before and after synthetic activation. Checks compare the same retained
listener PID, health fingerprint, provider/router bytes, activation bytes and
inspection revision while a local HTTPS observer requires zero TCP connections.
Standalone `serve` remains covered.

Source-denial uses synthetic HOME/CFFIXED_USER_HOME, denies real private paths and
checkout reads including symlinks, proves negative reads/imports, and attributes
the native instance lock to the exact launched process. Tracked children drain
both outputs, and cleanup checks child exit and synthetic-port reuse even after
assertion failure. This establishes automated fixture behavior; no GUI control
interaction or live account acceptance is inferred.

## Fresh automated acceptance

These commands ran in the order below on 2026-11-12. The current signed app was
built before both final Node/package runs, so neither used the earlier artifact.
Full outputs and actual command exits were inspected; the complete logs and
command/exit/time manifest were retained in the ignored task workspace during
execution and archived outside Git at closeout.

| Command | Exit | Fresh observed result |
| --- | --- | --- |
| `npm run companion:test` | 0 | 116 core + 44 app = 160 native tests, 0 failures |
| `npm run companion:build` | 0 | Current release app built and ad-hoc signed |
| `npm test` | 0 | 718 passed, 0 failed, 0 cancelled, 0 skipped |
| `npm run companion:package-test` | 0 | Exactly 3 passed, 0 failed, 0 cancelled, 0 skipped |
| `node --check src/cli.js` | 0 | No syntax diagnostics |
| `git diff --check` | 0 | No whitespace diagnostics |

Passing logs contained no compiler/runtime warnings or failure diagnostics. All
160 named native test starts had matching passing completions. The fresh package
run established the managed exchanges and unchanged synthetic bytes described
above, retained standalone compatibility, revalidated the negative source controls
and positively attributed native lock/window, and confirmed tracked child exit
plus reusable synthetic router/upstream ports. Local documentation links were
checked. Documentation-only evidence updates after this run do not change the
signed artifact or tested source.

## Isolated native observations — 2026-11-12–13

The parent used relocated copies of the same current signed app, owner-only
synthetic HOME/CFFIXED_USER_HOME and synthetic configuration/catalog state.
Seatbelt denied checkout and real Codex/router private paths and non-loopback
outbound traffic. Negative checkout/Node source reads, an actual on-screen native
window and the exact synthetic instance lock were independently established.
Accessibility automation was unavailable; the interactions below are explicit
human observations, combined with separate process/file checks. No model request,
real credential retrieval or real provider change occurred in these fixtures.

| Case | Recorded observation |
| --- | --- |
| Routing and assignments | The user performed Start and On, then confirmed On/action Off, the active `route-a` override and global inheritance. After switching Off, the user confirmed Off/action On, the saved inactive override and global routing-Off assignment. Initial Off was not separately reported before On. |
| Warnings and search | Missing-target and stale-mapping warnings remained visible through searches while Off. |
| Automatic discovery | The first attempt was unobserved because the user accidentally pressed Refresh. A distinct row added afterward appeared automatically without Refresh, with the expected global routing-Off assignment. The first attempt is not counted as an automatic-discovery pass. |
| Unavailable catalog | After only the fixture catalog was made invalid, explicit Refresh showed catalog unavailable, removed the previous row and retained known Off. The exact saved synthetic catalog was then restored. |
| Unavailable mode | Pausing only the positively attributed synthetic child produced Unavailable with no On/Off button while the restored catalog row remained visible with routing unconfirmed. Resuming the same child restored known Off automatically before manual Refresh was needed. This is paused-child/readiness evidence, not a native lost-set-acknowledgement test. |
| Direct-only Stop | The user explicitly stopped the never-activated synthetic router. The header became Router not running/action Start Off; independent checks found no tracked child or listener and unchanged provider/router/journal bytes. |
| Open/scrolled Quit guidance | In the corrected fixture described below, Quit showed an alert and its primary action revealed expanded Advanced/manual recovery and highlighted guidance from a scrolled project list with Advanced collapsed. |
| Polling and repeated requests | Waiting about six seconds after scrolling left the view in place. Another explicit Quit/primary request returned to the highlighted guidance. |
| Minimized and closed windows | With Advanced collapsed before each case, the user physically minimized or red-closed Controls, then used menu-bar Quit/primary. Both returned the window with expanded, highlighted recovery guidance. No parent UI inspection or activation occurred during this handoff. |
| Keyboard | A fresh guidance request followed by Return performed no visible operation and played the macOS alert sound. After Tab, typing without clicking a field populated Projects search, identifying its recipient; the initial focus indicator was not visible to the user. All-controls keyboard navigation was disabled and left unchanged. No separate VoiceOver observation is claimed. |
| Cancellation | Keep Running and Escape each preserved the genuinely minimized state; both also preserved the red-closed state. The user explicitly confirmed both cases without parent UI inspection/activation during the handoff. |
| Ordinary reopen and exit | Normal Open controls removed the previous Quit-guidance outline. After restoring only the original valid pending fixture journal, normal Quit exited without an alert. Independent checks observed native exit 0 with no signal, no child/listener, and exact original provider/router/pending-journal bytes. |

The initial blocked-Quit setup was incorrect: it had no pending recovery
obligation after direct-only Stop. Corrupting its saved journal therefore did not
exercise the pending-recovery exit guard, and the user observed ordinary idle
Quit with no alert. The exact synthetic app exit and unchanged provider/router
files were verified; that native exit code was not captured. This attempt is
retained as a fixture failure, not a passing navigation check or a product fix.

Read-only tracing identified the normal idle-permission branch. A fresh confined
fixture initialized a valid `direct_confirmation` pending context before its
journal was deliberately invalidated after initialization. The corrected
navigation/cancellation checks above then passed. Both fixtures' invalid evidence
was retained privately before restoring their original journals. All tracked
processes exited, the synthetic ports were independently empty, and both fixture
drivers completed cleanup. Product source and the signed build were unchanged.


### Lost mode replies and fresh reconciliation — earlier attempt, 2026-11-13

A separate relocated signed fixture retained the same source/private-path and
non-loopback confinement, negative source-read controls, visible native window
and attributed synthetic instance lock. Its temporary runtime intercepted only
the managed entry's outgoing On mode replies, including read replies; the HTTP
listener remained responsive throughout. No provider activation, response
confirmation, real account request or real configuration change occurred.

The ten-second instruction asked for Uncertain, but the user instead reported
Unavailable with the orange warning: “Routing control is unavailable. Keep the
router running and use direct recovery if needed”. The existing controller path
and regression test explicitly distinguish a lost-set acknowledgement from a
later failed read: the latter publishes Unavailable. In this earlier attempt the
transient Uncertain label was not observed and is not counted as a native pass. A later focused
remediation observation is recorded separately below. This was an overly
narrow observation instruction, not evidence of a known On/Off label or a
product correction.

After releasing only the fixture's withheld replies, the user confirmed automatic
On/action Off and the active route-a assignment without clicking a mode control
or Refresh. Independent checks proved the same native/managed-child identities,
the same child owning the responsive listener, and unchanged provider/router/
journal bytes across reconciliation. The observed recovery used fresh read
evidence; it does not imply an automatic mutation retry. The user then performed direct-only Stop and normal Quit. Independent checks
found the exact native/managed processes absent, the synthetic port empty and
provider/router/journal bytes unchanged. Only the positively attributed fixture
driver was terminated afterward; no application or listener was signalled.

### Final-review native evidence remediation — 2026-11-13

The first integrated specification review returned MISSING for the transient
Uncertain observation and native keyboard reachability beyond search. Quality
review did not start. One focused evidence-remediation wave prepared two serial
small-catalog fixtures, using the unchanged signed app and the established
source/real-private-path and non-loopback confinement. No product change was made.

The user reported Keyboard navigation initially Off and temporarily enabled it
through System Settings. A confined, windowless AppKit probe independently
reported native full keyboard access enabled. Fixture-local defaults had not
enabled actual AppKit navigation; those experiments changed no real preferences.
After both fixtures, the user restored the original checkbox state to Off. A
fresh confined AppKit probe reported full keyboard access disabled; this claims
restoration of that setting, not whole preference-file byte equality.

Using Tab/Shift-Tab and Space, the user expanded Advanced/Setup, opened the
configuration picker and the runtime picker, and cancelled each with Escape
without selecting a file. The first keyboard Start activated its button but
showed The router could not be started. Independent checks found no listener or
child and unchanged synthetic files. The new external launcher used the wrong
argument positions for the native Node CA flag. An exact-argv replay reproduced
the import failure on a separate synthetic port. Corrected external launcher
files then passed Ready Off, correlated read/set, withheld replies with responsive
HTTP, fresh reconciliation, same-child identity and exact teardown/port-absence
checks before the native retry. The evidence log's newline escape was verified
correct; an initial contrary suspicion was discarded without a log-format fix.
This is retained as a fixture failure and correction, not a product regression
or product fix.

The native keyboard Start retry showed Off/action On. The user then focused the
On action, pressed Space once and watched continuously. Both Uncertain — refresh
to check and The routing mode is uncertain. Refresh before switching again. were
explicitly observed. Timestamped withheld replies and separate checks confirmed
the same native app, exact owned child/sole responsive listener and unchanged
provider/router/journal bytes. Releasing only the withheld replies, without
replaying them, produced automatic On/action Off/active route-a assignment, which
the user confirmed without manual Refresh or another mode action. The user then
performed keyboard Off and Stop, observed Router not running, and used Command-Q
to quit the synthetic Router app normally. Independent cleanup observed native
exit 0 without a signal, no child/listener and original synthetic file bytes.

The second idle fixture retained a valid pending direct-confirmation context; no
router was started or provider activated. The user reported being able to focus
the recovery buttons, while observing that ordinary focus moving outside the
viewport did not scroll it into view. Source comparison found explicit scrolling
only for Quit-guidance requests in both the baseline and current view. The new
layout exposes more controls below Projects; no baseline native comparison was
performed, so runtime regression provenance is unproven. The user then explicitly
confirmed both focus outlines were clear after scrolling without clicking a
control, and Page Up/Page Down revealed the focused
button using the keyboard without pointer scrolling or activation. The manual
recovery disclosure also expanded with keyboard focus and Space. For the guarded
Quit check, the user collapsed Advanced and followed the Command-Q/Return
instructions. The user qualified the timing: the recovery area
was already revealed on the Quit request, before Show steps to quit. Source
inspection confirms a blocked-Quit error can expand Advanced before the alert;
the primary response separately issues targeted navigation. The user observed
the Click Refresh and review any recovery instructions guidance text focused;
one Tab moved focus to Start router (routing Off), with keyboard paging available
to reveal off-screen focus. This establishes the observed keyboard path, not
independent proof that the primary response caused the earlier expansion.

Only the synthetic journal had been invalidated to trigger the guard. It was
restored exactly before the user used Command-Q on the synthetic Router again;
the app exited without an alert. Independent cleanup observed native exit 0
without a signal, no child/listener and original configuration/provider/pending-
journal bytes. The pending synthetic response check was preserved; no response
button was pressed, no router started in this phase and no false working-response
confirmation was made. All fixture drivers finished normally.

Missing automatic reveal of ordinary off-screen focus remains an open usability
observation for final quality review. Keyboard paging success does not establish
an unperformed VoiceOver check or an automatic-scroll fix. A final fresh private
recovery recheck also passed: actual selected/normal contexts direct/restored,
no pending desktop check, real port empty and instance lock unheld, exact original
non-provider bytes/modes and selected provider table, and unchanged final restored
provider text with only the previously qualified project-settings difference
from the original checkpoint. The current signed app verified successfully.

## Live setup observations — 2026-11-13

The compatible existing private credential-routing configuration was selected
through the native file picker. The user confirmed Valid/Credential routing and
reported that selection moved the scroll position from Advanced/Setup into the
middle of the project list. This usability observation remains open for final
review; no product fix or claim of stable scroll during selection is made.
Independent private inspection confirmed the selected context, direct/restored
provider, no pending desktop check, no owned child or listener, unchanged router
and provider bytes, and the expected journal selection change. Original private
checkpoints remain preserved. The user then explicitly started the router and confirmed initial Off/action On.
Independent checks attributed one managed listener to the retained native child,
with matching readiness and unchanged router/provider bytes. The user activated through the provider-wide native notice and confirmed Router
on disk and routed-response confirmation pending, leaving routing Off. Private
checks verified the same sole owned listener, only the provider URL changed, the
activation record beside the selected configuration and an exact original-provider
backup. Router bytes are unchanged. Original and activated checkpoints are kept
separately outside Git. The first private semantic check falsely failed because
cloning parsed TOML discarded its table prototypes; a synthetic reproduction
confirmed that harness error. Fresh parsing and exact reverse-literal text
comparison passed without a settings or product change. The initial manual restart failed as described below; the later repeat supplied
the live observations.

### Interrupted first live restart

The user reported that closing Codex also closed the companion. Independent
inspection found the original companion absent and its instance lock free, while
the original, positively attributed managed router still owned the listener.
Provider settings remained active, with routed-response confirmation pending;
router configuration bytes were unchanged. No successful desktop restart or
working routed-response acceptance is recorded for this attempt.

The parent had launched the native app under its Codex command-session driver,
rather than through macOS LaunchServices. That setup did not establish an
independent application lifetime; the exact termination mechanism and native
exit status were unobserved. This is retained as failed acceptance/setup evidence,
without attributing a proven product defect. A signed recovery app was then
opened through macOS; it acquired its own private instance lock and retained the
pending journal. It does not own or adopt the surviving listener. The user then invoked Restore direct and confirmed Direct/direct-response
confirmation pending. Private inspection verified byte-exact original provider
and both router files, a restored activation record in the selected directory,
and the separate macOS-launched recovery app holding its instance lock. The
original validation child remains listening through the required recovery restart.
The user then reported the recovery restart and that the companion stayed open.
Independent process identity and lock checks confirmed that the same macOS-launched
app survived, with original provider/router bytes and direct/restored status.
The original validation child had exited during the second restart: its recorded
PIDs were absent and the selected port independently empty. No signal or adoption
was used. The user confirmed a working post-restart reply and used the native direct-response
confirmation; a fresh private check found no durable pending check. First-attempt
recovery is complete. The original failed startup attempt and unobserved
termination mechanism remain qualified.

### Diagnostic capture for the repeat

The native app normally drains/discards diagnostics. To obtain the approved live
per-request mode/selection/transport evidence, the parent prepared an owner-only
temporary launcher outside Git. It execs the same installed Node 24, preserving
arguments and protocol stdout, and redirects only this signed bundle's managed
stderr to a private file. Version checks and ordinary CLI helpers retain their
normal streams. This is acceptance instrumentation; product code is unchanged.
The runtime selection will be restored during final cleanup. The user selected
the launcher through native Setup and explicitly started; Off/action On/no error
were confirmed. Independent checks attributed the new listener to the same
macOS-launched companion, verified the exact installed Node executable and private
stderr descriptor, and found unchanged original provider/router bytes. A path
spelling check required canonical filesystem comparison; it did not require a
product or settings correction.

The synthetic launcher check passed exact Node/version, Ready Off, acknowledged
On/Off, health, child exit and port absence without model, credential or provider
operations. Draft checks exposed a wrong runtime version, a noncanonical synthetic
path and a wrong health path; their failed outputs are retained privately and
corrected by the final fixture. They are harness failures, not product fixes.

### Repeat activation and restart

The user activated and manually restarted Codex, reporting initial Off and that
the companion stayed open. Independent exact process/start/lock checks established
the same native app and same new owned listener across that restart. Narrow
provider-literal and semantic comparisons passed; the selected-directory activation
backup matches the original provider, both router files are unchanged, and a
separate active checkpoint was saved. Routed-response confirmation was initially pending and was separately completed
as recorded below.

The private diagnostics recorded this controller chat selecting Off/global and
an initiating `499/CANCELLED` outcome. That result is retained; restart/UI success
does not relabel it as HTTP 200 or establish complete stream delivery. It is not
the required mapped-project same-chat sequence, whose observations follow below.

### First disposable-chat request while Off

The user reported the exact visible reply `OFF-1`. Private identity evidence
uniquely attributed the new disposable chat to the selected mapped project, whose
explicit paired target differs from global. Its first request captured Off/global
and completed HTTP 200 without a diagnostic error. The same native app and owned
listener remained, and active non-journal checkpoint files were unchanged. That
private thread identity is retained for the On and return-Off follow-ups.

The user's two answer fields both described `OFF-1`; neither confirmed the
companion's separate routed-response label. A subsequent companion-only question was explicitly answered yes: the user
clicked/read User confirmed routed response. Initial integration and its separate
manual response confirmation are therefore observed.
The successful disposable request does not relabel the separate controller
`499/CANCELLED` events or establish independent billing attribution.

### Same-chat switch to On

Without a Codex restart, the user explicitly observed header On and the visible
reply `ON-2` in the same disposable chat. Private thread/request evidence confirms
On/override selection for its existing paired target, the same app/owned listener,
and unchanged active non-journal files. This request ended `499/CANCELLED` despite
the visible reply. HTTP 200 and complete stream delivery are not claimed for it;
no gateway rejection, repair, fallback or retry was observed/performed. The
return-Off and closed-Controls new-project observations follow below.

### New project while On

The user created the requested disposable project and reported `INHERITED-3`
without an error. Private before/after identity evidence established that the
project was absent from the prior catalog and had no saved override. Its request
captured On/global and completed HTTP 200 without a diagnostic error. The same
native app and owned listener remained. A non-activating CoreGraphics observation
afterward found no on-screen Controls for that exact app. The user subsequently confirmed Controls stayed red-closed until the reply, the
row appeared as Global (inherited) on normal reopen before manual Refresh, and
manual Refresh retained it under Current local project catalog. Normal reopen
itself triggers inspection; no hidden-poll timing claim is made.

Creating the project changed only the unrelated top-level project settings in
Codex TOML. The selected provider table/URL and all other active non-journal
checkpoint files remained unchanged; router configuration bytes are original.
Whole-file provider equality to the activation checkpoint is therefore false.
Recovery must preserve these project settings and qualify whole-file comparisons.
No account, mapping or provider rewrite was used to achieve inheritance. Background
polling may have inspected the catalog before the model request; this live check
does not prove absence of hidden inspection, which remains synthetic evidence.

### Same-chat return to Off

The user observed header Off and `OFF-4` in the original `OFF-1`/`ON-2` chat.
Its request captured Off/global and completed HTTP 200 without a diagnostic error.
The exact same native app, owned child and listener remained throughout the
recorded sequence. Provider bytes were unchanged by the Off switch; provider
URL/table, router files and activation files remained stable across mode changes,
with the separate unrelated project-settings addition preserved.

The observed sequence is Off/global/200 → On/override/499 with visible `ON-2` →
Off/global/200 in one chat. No gateway rejection, continuation repair, fallback or
router retry was observed. The user subsequently explicitly selected that Codex stayed open with no restart
during the switches.
A private pre-restore checkpoint
includes the newly added project settings, without replacing original snapshots.

### Final direct restoration and cleanup

The user explicitly confirmed no restart during the mode sequence, then invoked
Restore direct and observed Direct/direct-response confirmation pending. Exact
reverse-literal and semantic comparisons against the latest pre-restore bytes
prove only the provider URL changed. The original selected-provider table and
router files are restored; new project settings and all other unrelated settings
are preserved. Whole provider-file equality to the original checkpoint is not
claimed. The same owned listener remains live until the required final manual
restart and working-direct-response confirmation, followed by guarded Stop. The
user subsequently reported the final direct restart and that the companion
stayed open. Exact independent checks confirmed the same app and listener,
direct/restored context, unchanged restored provider/new project settings, original
router files and the still-pending direct-response check.

The user subsequently confirmed that the final post-restart reply arrived
normally, clicked the direct-response confirmation, used Stop owned router and
observed Router not running, then Quit exited normally. Independent checks found
the exact tracked child absent, the real selected port empty, the real companion
instance lock unheld and both selected/normal contexts direct/restored with no
pending desktop check. No external listener was adopted or signalled.

With the real app/listener absent and recovery confirmed, completed journal,
activation record and generated backups were archived privately before restoring
the exact original journal and selected-directory activation record. Original
optional-property presence, runtime selection, router configuration bytes, file
modes and pre-existing named backups were restored. The two new completed backup
files remain alongside the selected configuration as well as in the private
archive; recovery evidence was not discarded. A fresh independent recheck passed.
The original selected-provider table was restored exactly and the final provider
text equals the verified direct-restored text, preserving the new project settings
and all unrelated edits. Whole-file equality to the original provider checkpoint
is intentionally not claimed. The temporary diagnostic runtime is no longer
selected; private checkpoints, raw diagnostics and recovery evidence remain
outside Git. No actual credentials were printed or committed.

## Final sequential review and dispositions — 2026-11-13

The sole integrated final gate covered implementation base `3235363` through
reviewed HEAD `c98f4e5`. The original specification verdict was MISSING for two
native-evidence observations. One evidence-remediation wave and the permitted
scoped specification follow-up resolved both findings with SPEC REVIEW: PASS.
The quality stage then consumed the unchanged immutable package and the complete
fresh PASS report; identities and the package digest matched at both stages.
Its verdict was QUALITY REVIEW: PASS WITH MINOR FINDINGS, with zero Important
findings and two Minor findings. No second fix wave or duplicate final reviewer
was used. The original MISSING report, follow-up PASS, quality report, packages,
command logs and ledger are preserved in an owner-only archive outside Git.

| Item | Final disposition |
| --- | --- |
| Transient Uncertain and required keyboard reachability | Closed by the actual qualified native observations above and the scoped specification PASS. |
| Q1: configuration selection can move the viewport from Setup into Projects | Accepted as a Minor limitation for this increment. The selected context remains correct; scroll back to inspect Setup. A focused correction remains provisional follow-up work. |
| Q2: ordinary Tab focus can leave the visible viewport | Accepted as a Minor limitation. Page Up/Page Down is the observed keyboard-only way to reveal the focus outline; automatic reveal and VoiceOver behavior are unproven. A focused correction remains provisional. |
| Task 3 retained-byte evidence | The read counter is explicitly qualified below. Production guards and ordering/overflow tests were reviewed; direct peak-retention measurement is not claimed. The evidence-overstatement concern is closed; additional instrumentation is optional. |
| Early blocked-Quit expansion of Advanced | No separate quality finding. Error-driven panel expansion precedes the primary action; the separately targeted scroll/focus path and the human timing qualification remain distinct. |

No product/test source changed after the applicable signed build and full
acceptance run at `976b594`; fresh Git comparisons established that identity
through the final reviewed commit. Later closeout changes affect only this
report and the approved pair's lifecycle/checklists. Required recovery and
native cleanup are complete, with no required human check pending. The local
branch is `feat/companion-routing-on-off`; `main` remains at the implementation
base. Account/default setup, assignment editing and all other deferred increments
retain their own scope and approval stages. No push or merge is authorized or
performed.

## Evidence limits

The earlier lost-set attempt missed the transient Uncertain label. Both texts
were later observed during the focused remediation above. Native keyboard
reachability was exercised with Keyboard navigation temporarily enabled and
keyboard paging; ordinary focus does not automatically reveal off-screen
controls. Cleanup and restoration of the original setting are verified.
The native observations do not establish VoiceOver behavior or every
sizing/runtime/error combination. The keyboard observation is qualified above.
The live run establishes the specific visible same-chat sequence and symbolic
request selections recorded here, including the On request's 499/CANCELLED
transport outcome. It does not establish complete delivery for that request,
independent gateway account/billing attribution or a general guarantee of
cross-account/instance continuation. No broader compatibility, credit-exhaustion
or live stress matrix is claimed. Synthetic barriers supply the in-flight timing
and exact credential-selection evidence.

The Task 3 blocked-output test counts reads rather than measuring actual retained
input bytes. Its passing result must not be described as a direct retained-byte
measurement; production retention guards have task and final quality review,
with the qualification-based disposition recorded above. Synthetic routing and transport
evidence does not establish gateway account/billing attribution or complete live
stream delivery. No real private-state read, credential lookup, provider mutation,
Codex restart or live model request was performed for Task 7.
