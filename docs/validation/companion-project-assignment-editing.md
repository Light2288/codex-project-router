# Companion project assignment editing validation

Created: 2026-11-17
Updated: 2026-11-18

Status: Stage 4 implementation and the sole final gate are complete. Bounded
human native/live observations, exact recovery and private cleanup remain recorded
with their limits. Original whole-branch specification review passed; original
quality requested one Important stopped-helper rejection-boundary correction. The
combined fix at `f842b509064c3269659f541d965452c4ff6fd757` passed focused backend
40/controller 111 and ordered 314 native → matching signed build → 958 Node →
exactly 3 package checks, all exit 0. Its one scoped sequential follow-up actually
returned specification PASS then quality PASS—Approved: original Important
ADDRESSED, residual findings NONE. Historical 310 verification and the separate
post-OS supplement remain below. The verified local endpoint and final controller
report are prepared for delivery. No already-sent chat message is claimed.
Work remains local; no push, merge or later increment.

Scope: the approved `companion-project-assignment-editing` increment, governed by
the [specification](../superpowers/specs/2026-11-16-companion-project-assignment-editing.md)
and separate [implementation plan](../superpowers/plans/2026-11-16-companion-project-assignment-editing.md).
Wider account editing/deletion, hiding, UI redesign, startup automation and
distribution remain deferred. Execution stops after this guarded assignment flow,
verification, exact recovery, documentation and final review; no later increment
is authorized.

## Delivered behavior and boundaries

In valid ready schema 2, one project can select an existing named account, switch
to another, or choose Use default to remove its exact override. Choosing the named
default remains explicit. Legacy inheritance labels and unresolved targets remain
distinct; missing targets require an explicit repair choice. A configured-only
project is editable with a warning when discovery is otherwise healthy. Failed,
duplicate, conflicting or unavailable project identity cannot grant authority.

Save and apply requires the exact owned supported child, functioning control
channel and fresh coherent source/catalog/runtime evidence. It durably saves and
publishes an immutable assignment snapshot, preserving On/Off and the listener.
Save while stopped requires safe Direct state, an independently empty selected
port and resolved recovery. The next explicit Start loads actual saved settings
in Off. Account/default changes retain their existing safe Direct/stopped boundary.

Saved and running state are separate. Off suspends overrides. On or saved data
alone cannot prove application. Runtime account names come from the retained
snapshot; unavailable reads show unconfirmed state. Explicit opening/Refresh loads
the editor baseline; background updates do not silently rebase unsaved intent.
Save deliberately leaves the editor open for inspection. Controller ownership
survives sheet dismissal. No mutation is retried automatically.

Requests synchronously capture mode and configured assignment at receipt, before
incoming authentication or other awaits. Existing requests keep their selection;
no credential fallback, alternate-account retry, redirect, model/body/continuation
rewrite or account/default/provider reload is introduced. Shared bindings are
neither retargeted nor garbage-collected, including removal. Fresh source identity,
catalog, artifact and owned-lock checks guard persistence. Ambiguous outcomes are
neither success nor rollback; serialized reads observe exact saved/running evidence.
Assignment uncertainty retains guarded original Direct recovery and explicit
manual restart/response confirmation before Stop/Quit where required.

## Automated verification

Test/build commands used process-scoped `caffeinate -i`; approved product deadlines
remain unchanged. Detailed reports, logs and exact byte/signature proofs remain
in ignored evidence. No private actual configuration, credential, mapping,
endpoint, comparison token or checkpoint is reproduced here.

### Historical Task 8 and acceptance correction evidence

Task 8 added package assertions against already-landed production. The initial
build and package run passed, exactly 3/3 with zero failures/cancellations/skips.
This is positive integration coverage. Under the recorded dependency-order ruling,
production allowlists landed in Tasks 1/3 and the ready-schema-2 capability
expectation in Task 4; no missing-module RED was manufactured.

The original Task 8 chain was 298 native (224 core + 74 app) → signed build →
958 Node → 3 package, all exit 0. Subsequent causal editor-stability corrections
included an initial scoped review requiring changes and an approved negative-state
follow-up; the amended chain was 304 native (225 core + 79 app) → signed build →
958 Node → 3 package, all exit 0. These counts are historical, superseded by the
310-test native evidence below.

The later unavailable-state regression had meaningful RED: six tests and 16
expected classification/guidance assertion failures, followed by focused 122/122
and full native 310/310 passing. Authoritative unavailable evidence now displays
setup guidance without a false saved/running conflict; genuine conflicts, read
failures, pending uncertainty and retained runtime evidence remain distinct.

The first full Node 958 run passed, then two explicit package runs each failed
2/3, one failure and zero skips. Their single window samples reported, respectively,
regular native app with missing on-screen window, then missing regular policy and
window. Later assignment/lifecycle checks in that third case were not reached.
A separate instrumented same-binary diagnostic reproduced a failed sample while
the app remained alive: its on-screen window was present, temporarily absent,
then returned within the original 20-second budget. That observation establishes
the captured diagnostic's transient visibility failure; the exact internals of
the earlier uninstrumented failures, especially the second, remain unobserved.

The authorized package probe correction waits for the same regular-activation,
exact-PID, on-screen layer-0 predicate within the same absolute 20-second budget,
including Swift startup, and fails promptly on owned-child exit. It adds no case,
skip, off-screen fallback, fixed readiness delay or product launch/window change.
The two historical failures and diagnostic remain retained as separate evidence.

### Earlier affected ordered verification

The native and matching build inputs stayed unchanged through the package-probe
correction. The original ordered evidence is native 310 → matching signed build →
final Node 958 → explicit package 3; affected Node/package checks were repeated after
the test correction, while the unchanged native/build evidence was retained.

| Command, each under `caffeinate -i` | Actual result |
| --- | --- |
| `npm run companion:test` | Exit 0; 310/310 (230 core + 80 app), zero failures; no native warning/error diagnostics |
| `npm run companion:build` | Exit 0; matching app built and ad-hoc signed; strict signature verification exit 0 |
| `npm test` | Exit 0; 958/958, zero failures/cancellations/skips/todo; 58151.69975 ms |
| `npm run companion:package-test` | Exit 0; exactly 3/3, zero failures/cancellations/skips/todo; 26662.765208 ms |

Earlier acceptance executable source endpoint: `1a1fc687002d6e4df338945e6933555a9cb296f1`.
The matching `dist/Codex Project Router.app` is arm64, ad-hoc signed, with 19
explicit production modules and Node 24.21.0. Original build host: macOS 27.0.1.
Ignored private proofs bind source inputs, packaged modules, executable bytes and
signature.

The original release build emits seven existing KeychainStore Security API
deprecation warnings, each repeated in source annotations, with no new assignment
warning/error. Node/package harnesses emit 13 intentional file-backed Security API
deprecation diagnostics and no other warnings. The bounded synthetic unresponsive
probe requires SIGKILL and verifies reaping/process-group absence; deliberate
stalled-reader cleanup and Seatbelt EPERM/ERR_MODULE_NOT_FOUND source denial are
expected passing observations. No warning suppression or deadline relaxation was
introduced.

### Post-OS supplement on unchanged source and signed app

After the OS-update reboot, a separate once-only sequence ran on macOS 27.2.1,
build 26B131. This supplements OS-dependent evidence; it is not a rebuild or a
new human live run.

| Command, each under `caffeinate -i` | Actual result |
| --- | --- |
| `npm run companion:test` | Exit 0; 310/310 (230 core + 80 app), zero failures; core 98.952 s, app 0.834 s; no native warning/error diagnostics |
| `npm test` | Exit 0; 958/958, zero failures/cancellations/skips/todo; 57851.554458 ms |
| `npm run companion:package-test` | Exit 0; exactly 3/3, zero failures/cancellations/skips/todo; 27045.762792 ms |

Before and after, all native/build/test inputs, all 19 bundled modules and signed
executable bytes matched the final correction proof; fresh deep/strict signature
verification exited 0. Fresh current filesystem identity was recorded privately.
The reboot changed the filesystem device number: unchanged source bytes do not
imply an unchanged pre-reboot physical identity token. Fresh context reads supplied
current authority. The seven original build warnings remain historical because
this supplement ran no build; the 13 intentional harness diagnostics and expected
synthetic cleanup/source-denial observations were retained. No unexpected failure
or retry occurred.

### Sole final fix: stopped rejection boundary

The sole final quality review found that the real stopped assignment CLI emits a
complete safe failure envelope and exits 1, while native wait classified that exit
as uncertain before its strict parser ran. The fixture exited 0 and masked the
mismatch. A proven prewrite rejection could therefore retain a phantom pending
operation and block normal controls. The original quality finding remains recorded;
the one scoped sequential follow-up subsequently confirmed it addressed, with
specification PASS and quality PASS—Approved.

The regression first corrected the fixture to production exit 1. A separate real
CLI regression uses bounded private synthetic ready-schema-2 files outside the
checkout and stale source/identity expectations. Before the product edit, the real
CLI's exact conflict envelope/normal exit 1 and no-intent checks passed, while
ProcessBackend incorrectly returned uncertainty and blocked a later explicit Save.
A test-only noncanonical temporary-path setup issue was separately diagnosed and
corrected before that causal RED; original diagnostic/failure logs are retained.

The native correction lets only a normally exited, fully drained assignment
mutation status 1 reach the existing exact failure parser. Known conflict is a
certain conflict; invalid/unavailable are certain unavailability. Success still
requires normal exit 0. Uncertain/unknown codes, malformed or contradictory data,
extra keys, invalid schema/message/boolean shapes, success with nonzero exit,
signal 1, unexpected statuses, incomplete drain, overflow, timeout, cancellation
and incomplete input retain uncertainty. No retry, signal, credential read,
preflight or other setup/provider behavior is added.

| Command, each under `caffeinate -i` | Actual result |
| --- | --- |
| `swift test --package-path companion --filter ProcessBackendTests` | Exit 0; 40/40, zero failures; 90.581 s |
| `swift test --package-path companion --filter RouterControllerTests` | Exit 0; 111/111, zero failures; 0.216 s |
| `npm run companion:test` | Exit 0; 314/314 (234 core + 80 app), zero failures; core 109.670 s, app 0.862 s; no warning/error diagnostics |
| `npm run companion:build` | Exit 0; rebuilt and ad-hoc signed after the controller's fresh absence/state check and explicit build release; seven existing Security deprecations |
| `npm test` | Exit 0; 958/958, zero failures/cancellations/skips/todo; 58188.932459 ms |
| `npm run companion:package-test` | Exit 0; exactly 3/3, zero failures/cancellations/skips/todo; 27059.980834 ms |

The production regression verifies unchanged synthetic configuration/provider,
no intent/checkpoint/temp/lock, neither backend uncertainty flag, readable fresh
state and a later explicit no-op Save. Fixture invocation counts prove no retry.
The stopped-controller source-change regression verifies pending cleared and
Start, Quit, configuration selection and assignment editing remain available.
Existing helper lifetime, setup, ownership and Direct recovery cases also passed.
The native input snapshot remained unchanged through build/Node/package checks.
Fresh deep/strict signature verification and all 19 bundled module comparisons
passed; the current exact commit/executable/stat/input proof remains private. The
single scoped follow-up actually passed specification first, then quality—Approved,
with the original Important finding addressed and no residual findings. Exact
reviewed/current source commit: `f842b509064c3269659f541d965452c4ff6fd757`. The
controller independently verified all 101 current build/test inputs, executable
bytes/stat, 19 bundled modules, strict signature, recorded logs and clean HEAD.
This later literal lifecycle update changes no reviewed executable input.

No human/live run was repeated. Prior ready/live/UI acceptance remains historical
against its identified native source; this correction changes only the stopped
error path, covered by current deterministic regressions. The original frozen
review package and reports remain immutable. Seven existing build and 13 harness
Security diagnostics, earlier package/window failures, partial transport/drain
limits and cancelled B initiation remain disclosed in their original sections.

### Package coverage and limits

Exactly three package cases cover explicit resource allowlists, dependency drift,
relocated `codesign --verify --deep --strict`, arm64 metadata, branding decoding,
minimal GUI PATH and source equality. Both relocated fixtures exercise bundled
stopped Save/checkpoint/readback, next Start Off, owned live assign/switch/remove,
listener ownership, saved/running coherence, applied health fingerprints,
retained account/default/incoming settings and bindings, unchanged provider/recovery,
zero upstream connections and byte-exact Direct rollback. The source-denied native
case retains lexical/resolved/symlink checkout denial, synthetic private-store
confinement and all downstream assignment/lifecycle/recovery assertions.

An owned disposable Keychain contains only a public fixture. Production
metadata/create and bundled-reader comparisons run without printing secret values;
cleanup verifies owned files/search-list entry and default-handle preservation.
The harness identity differs from the packaged app ACL identity. Automated window
proof is separate from the human observations below.

## Bounded human native and private live observations

The human independently launched the signed app and selected a freshly validated
isolated ready-schema-2 copy with two available existing named accounts. The
normal configuration remained legacy and was not migrated. Stopped Save assigned
the alternate account; independent reads proved the exact selected mapping change,
all other mappings/prior bindings/accounts/default/incoming/optional fields
preserved, Direct state and independently empty port. Save stayed open. After the
causal stability correction and matching rebuild, the human reopened the amended
app and confirmed no repeated editor resizing. Existing accepted selection-scroll
and off-screen Tab limitations remain.

### Original partial run

Start was human-observed Off with the saved override suspended. Exact owned
native/Node child/session/listener/health/recorder attribution passed. The Off
initiator recorded `499/CANCELLED`; a separate ancillary 200 is not its result.
The human then saved the named default explicitly, observed correct saved/running
labels and a fresh phase-A reply. Its initiating transport is **UNOBSERVED**:
the controller-selected 20-minute private retention had expired. That partial run
is retained without an inferred HTTP result.

Original Direct recovery was byte-exact; exact owned child/logger exit and an
independently empty port were verified. The original logger had no closing footer,
so its forwarding/drain outcome remains unobserved. The retry fixture extended
private retention to two hours with the same 2 MiB bound and added managed-group
SIGTERM/EOF drain handling. Synthetic fixture PID/control/output/bound/truncation/
drain/exit checks passed. Product deadlines did not change.

### Completed retry on one exact owned child/session

Native stopped Use default first removed the exact selected mapping, preserving
other configuration and all bindings. The next explicit Start was human-observed
Off with inheritance. The human activated/restarted Codex once before the sequence;
no per-assignment Codex restart occurred. The initial Off/global initiator again
recorded `499/CANCELLED`, separate from visible response.

| Phase | Human native/visible observation | Independent saved/runtime and initiating evidence |
| --- | --- | --- |
| A | On; select named default explicitly; Save and apply; correct saved/running labels; fresh A reply visible | Explicit named-default override, matching saved/running health, same owned child/session; one unique fresh project thread; On/override initiator **200**, no error |
| B | On; switch to alternate; Save and apply; correct saved/running labels; fresh B reply visible; then Off | Expected alternate override, matching saved/running health, same child/session; one unique fresh project thread; On/override initiator **499/CANCELLED** |
| B Off | Human turned Off after fresh B finished | Alternate still saved; a distinct later controller request correlated after B used Off/global and recorded **200**; it does not replace B's cancelled initiator |
| C | Return On; Use default; Save and apply; correct inheritance/default labels; fresh C reply visible | Exact selected mapping removed, matching saved/running health, same child/session; one unique fresh project thread; On/global/no override initiator **200**, no error |

Every save preserved other mappings, all prior bindings, accounts/default/incoming
settings and optional fields. The unrelated phase-A prompt in the controller chat
was excluded; the fresh sample was independently identified. An earlier mistaken
B-Off correlation to an older On event was corrected and both observations were
retained privately, without a product retry. The final capture was 798 seconds and
124,885 bytes with zero malformed lines, within the two-hour/2-MiB fixture bound.

Visible replies and initiating transport remain separate facts. These observations
do not establish independent billing attribution, general cross-account
continuation or a live request held across an assignment change. Deterministic
automated authentication/identity/credential/stream barriers establish request
snapshot invariants.

### Configured-only and unavailable presentation

In an isolated ready-schema-2 configured-only fixture, the human opened the absent
project, saw the absent-current-discovery warning and closed without Save.
Independent reads showed unchanged source revision/identity, pending nil,
Direct/no recovery/no activation record, empty port and unchanged normal settings.

The original unavailable fixture exposed a false conflict while Save was disabled;
that observation led to the scoped correction, not a retroactive pass. After the
OS reboot the human reopened the exact corrected signed app and confirmed account
setup guidance, no false conflict and Save disabled. The main section showed no
designated default, setup actions and an explicit incomplete-setup warning before
Start. Setup gates Start by presenting those actions rather than a disabled Start
button. No Save, Start or activation occurred. Independent reads established the
correct setup-required context, healthy catalog, pending nil, Direct/no recovery,
no runtime/readiness, empty port and original normal configuration/provider bytes.

## Exact recovery and private cleanup

After the retry, the human set Off, restored Direct and manually restarted Codex.
Independent inspection verified the entire provider file and context-local backup
byte-exact against both original and retry checkpoints, correctly bound restored
record, no recovery required, unchanged normal router configuration and removed
selected mapping. The same exact child/logger remained alive for response
confirmation. After a working Direct reply, the human confirmed and guarded-Stopped.
Independent inspection verified exact owned Node/logger exit, empty port, absent
health and original provider/backup bytes. The retry logger's actual closing
footer confirmed successful forwarding/capture with no exceeded duration.

A later pending Direct obligation was investigated rather than weakened. A bounded
100-ms trace observed a settled confirmation, 66 seconds stable, then an equal-content
provider mtime/ctime change followed about one second later by context-bound Direct
confirmation reopening. Provider content and the other checked record/configuration
bytes and metadata were unchanged. External writer identity remains unobserved;
a coincident Codex reply does not identify the writer. The conservative
recovery-metadata guard remains in place. The human confirmed again and selected
an isolated presentation context, where normal-provider activity did not disturb
its stable checks.

Finally, the human selected the original normal configuration and guarded-Quit.
Independent inspection verified no native companion, pending nil, empty actual
validation port, original normal configuration/provider bytes and the actual
activation context Direct/restored with no recovery. Under the companion instance
flock and secure descriptor/identity/byte guards, the controller restored only the
original absence of the temporary runtime-path field, preserving other journal
fields and a private exact prewrite backup. Original selection and automatic
runtime are restored. A fresh post-OS operational check again verified native and
owned-context process absence, the empty port, whole-provider equality against
both initial/retry snapshots, exact context-local backup and correctly bound
Direct/restored recovery record, with no recovery required.

The positively owned private launcher was disabled with unchanged bytes. The exact
inactive presentation-fixture tree was archived after ownership, expected-tree,
source, no-activation-record and no-lock checks. The actual activation context,
configuration, backup and recovery record remain in place for their binding;
raw captures and original partial-run history are retained privately. Normal
legacy configuration and the desktop catalog/new human chats are preserved.
All recorded private cleanup checks passed. The controller performed no real-app
Start/activation, authentication-helper action or normal configuration migration.

## Acceptance traceability

These observations support the approved criteria with the qualifications below.
The sole final gate passed after its one scoped correction and sequential follow-up;
original review outcomes and all bounded acceptance limits remain recorded.

| Criteria | Recorded evidence | Qualification / final gate |
| --- | --- | --- |
| AC-01 assignment actions | Pure/native actions, both package flows and human A/B/C sequence | Final gate passed |
| AC-02 durable application | Persistence, exact-child publication, package health and live saved/runtime matches | B initiator cancelled; visible result separate; final gate passed |
| AC-03 stopped Save/Start Off | Guarded helper/controller/package checks and human stopped Save/next Start Off | Final gate passed |
| AC-04 truthful state | Saved/runtime/Off/unconfirmed tests; human labels, stable editor and unavailable retest | Human observed bounded states; automated dismissal/Refresh coverage; final gate passed |
| AC-05 identity/catalog/repair | Catalog/unresolved tests and human configured-only warning/unavailable guidance | No unsafe editing authority; final gate passed |
| AC-06 isolation/presence | Exact-key/optional-presence tests, package and independent live preservation reads | All prior bindings retained; final gate passed |
| AC-07 request consistency | Deterministic auth/identity/credential/stream/reused-connection barriers | No live in-flight/billing/general continuation claim; final gate passed |
| AC-08 stale authority | Source/catalog/lease, generation/exact-child/editor-baseline tests | Fresh authority after reboot; final gate passed |
| AC-09 ambiguity | Injected writer phases, ordered/lost-ack/helper/no-retry tests | B cancellation is transport evidence, not an inferred assignment rollback; final gate passed |
| AC-10 reconciliation/recovery | Serialized reads, retained runtime, guarded Direct and exact human recovery | Metadata invalidation caveat retained; final gate passed |
| AC-11 confirmation continuity | Exact-transition versus recovery-drift tests and observed conservative invalidation | Account/default boundary unchanged; final gate passed |
| AC-12 process lifetime | Helper/child/drain/relaunch/ownership tests; exact live child/logger exit and final Quit | Original partial drain unobserved; retry drain verified; final gate passed |
| AC-13 routing safeguards | Auth/pairing/no fallback, Stop/Quit, zero control-time upstream package checks and exact Direct restoration | Final gate passed |
| AC-14 package/live/docs | Final native/build/Node/package chain, post-OS supplement, bounded human evidence and recovery | Original specification PASS; one scoped follow-up specification PASS then quality PASS—Approved |

## Task reviews and implementation rulings

Tasks 1, 2, 4, 5 and 7 received approved task specification/quality reviews.
Task 3's artifact/source-authority findings were corrected through two scoped
rounds and approved. Task 6's queued live-to-stopped child-capture finding was
corrected and approved; its deferred divergence presentation finding was fixed
and reviewed in Task 7.

Task 8's automated partition was specification-compliant, quality Approved with a
minor ready-frame schema wording correction. That correction subsequently received
scoped specification PASS and quality Approved. The initial editor-stability review
requested changes for returned negative saved evidence; the follow-up received
scoped specification/quality PASS. The unavailable-state and bounded package-probe
correction at `1a1fc68` received scoped specification PASS and task quality Approved,
with no Critical/Important findings. Seven existing build and 13 intentional
harness Security diagnostics remain disclosed warning debt. None of those task
reviews is the sole final whole-branch gate. The actual sole whole-branch
specification review subsequently passed; quality requested the one
Important stopped-helper rejection-boundary correction above. Original reports
remain immutable. After the one combined fix at `f842b50`, the single scoped
sequential follow-up actually returned specification PASS then quality PASS—Approved.
The original Important finding is ADDRESSED; residual findings NONE. This closes
the sole final gate without reopening completed predecessor reviews.

Recorded rulings include earlier synchronized source allowlists/matching builds,
process-scoped idle-sleep assertions, pure transformation/source-identity separation,
exact flat wire evidence with explicit nulls, narrow internal filesystem fault
seams and a no-yield final authority guard. Editor baselines advance only on
explicit load or verified save. Negative evidence revokes authority before a later
await; positive authority requires the complete fresh proof. The queued-save fix
retains the intended child before waiting for the shared slot.

One bounded lastAttempt and immutable changed-operation artifacts are retained;
no unbounded replay history or exactly-once service is claimed. No-op operations
create no artifact. A stopped read after exact helper/child exit settles persistence
only. Shared locks and fresh checks do not provide atomic multi-file snapshots or
filesystem compare-and-swap against external writers ignoring the shared lease.

## Local branch and completion boundary

Branch: `feat/companion-project-assignment-editing`. Implementation base remains
`c0a5a53d8c41a6c394f28497fa39133d68a79683`. The separate branding closeout remains
on its own branch at `2f6c4ea09f7ec61e8ded355464acf7f68dc8ca73` and is not merged
here. Original human acceptance executable source is `1a1fc68`. The sole final fix
changes only the stopped assignment rejection boundary and regression tests. Exact
reviewed and current executable source is `f842b509064c3269659f541d965452c4ff6fd757`;
its matching signed build, full ordered checks and one scoped sequential final
follow-up passed as recorded above. This later documentation commit is literal
lifecycle bookkeeping; it does not change reviewed executable inputs or claim
that the reviewers reviewed later product changes. Exact code/package proof
remains private. The controller freshly verified original operational restoration
and cleanup, unchanged local/origin/actual-remote main, and separate branding
closeout. The verified local endpoint and final delivery report are prepared; no
already-sent chat message or unknown documentation commit ID is claimed.

Evidence sources are the retained Task 1–8 reports/reviews, scoped editor-stability
and unavailable-correction reports/reviews, sanitized controller live summary and
latest progress, completed post-OS verification report, actual final-fix report
and original/follow-up final review reports. Their historical pending statements
describe their original observation time; this record adds actual later results
without rewriting that history. No suite or rebuild accompanies this literal
lifecycle update. Stage 4 implementation, verification, acceptance record and final
gate are complete. The controller will deliver the prepared final report after
local bookkeeping verification, then stop before any later increment, push or merge.
