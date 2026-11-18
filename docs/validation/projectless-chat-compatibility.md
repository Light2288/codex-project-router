# Projectless chat compatibility validation

Created: 2026-11-18
Updated: 2026-11-19

Status: Stage 4 local delivery is **COMPLETE**. Ordered automated checks and
bounded native/live acceptance passed with the explicit limits below. The initial
fixture failure and earlier specification **MISSING** verdict remain historical;
a separate authorized confirmation-only continuation directly proved the missing
guarded action/state. All three runs ended with verified exact Direct recovery.
The fresh sequential specification and quality reviews both **PASS**, with no
findings. This closes only the approved compatibility increment; no later
increment, push or merge is authorized.

Scope: the approved [specification](../superpowers/specs/2026-11-18-projectless-chat-compatibility.md)
and separate [implementation plan](../superpowers/plans/2026-11-18-projectless-chat-compatibility.md).
Only companion-managed, ready schema-2 account routing changes. Standalone
schema-1/schema-2 and managed schema-1 retain historical behavior. No worktree,
push, merge or next increment is part of this delivery.

## Behavior under acceptance

Positively proven projectless requests, model lists and already-eligible
unassigned automatic titles use the complete preserved original destination and
the accepted incoming Authorization value in On and Off. They retrieve no
outgoing project/default key. Project requests retain their complete override
pair in On and companion-default pair in Off. Original selection is never
failure fallback. Unknown/conflicting identity remains rejected; title opt-in,
absence proof and ordinary identity precedence remain required.

Configuration and routing mode are captured together at request receipt before
asynchronous authentication. Supported membership is resolved afterward; selected
streams keep their destination and bytes. This adds no continuation translation,
new identity source, endpoint, configuration schema, key write or general reload.
A predecessor child does not acquire this behavior without starting the updated
bundled router.

## Current-source automated acceptance

The final chain ran once, in the following exact order, on 2026-11-18 from
13:10:40Z through 13:14:18Z. Every effective command ran under process-scoped
`/usr/bin/caffeinate -i`; the outer command bound was 600 seconds and no product
or test deadline was relaxed. Every child exited 0 with no signal.

| Order | Command | Actual result |
| --- | --- | --- |
| 1 | `npm run companion:test` | 316/316 XCTest cases: 234 core + 82 app; zero failures; no warning/error diagnostics |
| 2 | `npm run companion:build` | Current app built and ad-hoc signed; 7 intentional existing file-backed Security SDK deprecation diagnostics |
| 3 | `npm test` | 1034/1034; zero failures/cancellations/skips/todo; 63492.659834 ms |
| 4 | `npm run companion:package-test` | Exactly 3/3; zero failures/cancellations/skips/todo; 31231.155792 ms |
| 5 | `node --check src/cli.js` | Exit 0; empty output |
| 6 | `node --check src/identity.js` | Exit 0; empty output |
| 7 | `node --check src/proxy.js` | Exit 0; empty output |
| 8 | `node --check src/diagnostics.js` | Exit 0; empty output |
| 9 | `node --check test/helpers/projectless-package-probe.mjs` | Exit 0; empty output |
| 10 | `git diff --check` | Exit 0; empty output |

The separate Swift Testing runner reports zero tests because these suites use
XCTest; the 316 total comes from the completed XCTest suites. Both full Node and
explicit package logs report the native harness's 13 intentional file-backed
Security API deprecation diagnostics and no other warnings. Build source
annotations repeat the seven diagnostic messages; they are not additional
warnings. No warning was suppressed.

Both package executions include the distinct relocated and source-denied request
probes: original response/compact/catalog/eligible-title requests in both modes,
project override/default pairs and denied unknown/conflicting/bad-auth requests.
The separate control-only observer still records zero upstream connections.
Owned probe processes are absent and all four synthetic request ports reusable;
retained lifecycle/assignment/activation/recovery assertions passed. The existing
native harness reports owned scratch Keychain/sidecar/search-list cleanup and
unchanged opaque default handle. Its deliberate stalled reader required kill/reap
and verified cleanup, as expected. That harness has a different ACL identity
from the packaged app; synthetic credential seams prove no live gateway or
production Keychain claim.

Independent `/bin/ps` checks of the exact target app executable and bundled-router
path found zero matches before the chain, immediately before the build and after
the chain. A separate post-test scan of both lexical/resolved owned synthetic
package path prefixes also found zero matches. No active target was replaced or
unverified process signalled.

### Tested source and app identity

The tested checkout endpoint is
`3005d4ef59ba319cf8c264078fc0de886daaf0bd` on
`feat/projectless-chat-compatibility`. Source, native, resources, build and test
input SHA-256 manifests were identical before and after the chain. A separate
recheck at 13:14:25Z confirmed those inputs, all 45 regular bundle files, executable
bytes and retained app/executable physical identity still matched. Documentation
lifecycle/report edits do not alter these executable inputs.

The exact tested app is `dist/Codex Project Router.app`, arm64, ad-hoc signed,
with all 19 explicitly packaged production modules. Deep/strict signature
verification exited 0 after the chain and again on recheck. The host was macOS
27.2.1 (26B131), Node v24.21.0.

| Public identity proof | SHA-256 / code identity |
| --- | --- |
| Frozen source/build/test manifest | `9e8ee267d532d5a1ceb326fc33a56eecaf9dbade57d08df538741703dd108050` |
| Signed executable bytes | `1b9f21809a6005fb682cd298feb77f1f4c6e26e18e80293dcc1f564dfde9cdf6` |
| Sorted bundle file-hash manifest | `77a4886189eb97c91f09357defd0542f7ec6605da586c4bc9265e582557b95bb` |
| Ad-hoc CDHash | `cd3fd3ad311d2718bd62f96142c0d224bb42fb27` |

The controller reports matching post-first-run source/bundle/signature checks
and private native-launch/app/listener attribution for the first two runs. The
separate confirmation-only run used the same tested app and explicitly selected
the tested real Node runtime, with fresh exact app/managed-parent attribution.
After its final recovery at 23:04:55Z on 2026-11-18 UTC (2026-11-19 Europe/Rome),
source, bundle, executable bytes, physical identities and strict signature still
matched. A file/signature match alone is not used to attribute a running app or
listener.

Private raw command logs, exact source/bundle manifests and final review reports
are retained in the private acceptance archive outside the checkout. No actual
configuration, endpoint, mapping, credential reference/value, chat identifier,
checkpoint or raw live trace is reproduced here.

## Native/live selection and transport matrix

The symbols ORIGINAL, DEFAULT and OVERRIDE represent complete destination and
credential selections. They contain no endpoint or credential value. The first
run below is preserved as its own evidence. A visible reply, an initiating HTTP
status and complete stream delivery are separate observations; HTTP 200 alone
does not establish every byte of delivery.

| First-run observation | Selection | Visible reply | Initiating transport | Disposition |
| --- | --- | --- | --- | --- |
| Exact tested app and owned listener | N/A | N/A | N/A | Controller's native-launch proof, exact private live app/listener attribution and post-run source/bundle/signature match recorded |
| Native account-mode guidance legible without promoting readiness/control authority | N/A | UNOBSERVED in this run | N/A | Observed separately in corrected run below |
| Explicit startup Off and initial guarded activation/restart confirmation | N/A | Fresh Off reply observed below | HTTP 200 below | Started-Off and actual reply evidence retained; guarded confirmation was unproven here and is proven in the separate confirmation-only run below |
| Genuinely fresh chat outside every project, first message in Off | ORIGINAL | Human confirmed reply | HTTP 200 | Positive supported marker; target thread absent from preactivation DB IDs; first-message evidence observed |
| Same-chat follow-up after switching On | ORIGINAL | Human confirmed reply | HTTP 200 | Observed; first-run owned listener attributed |
| Extra same-chat On follow-up | ORIGINAL | Human confirmed reply | HTTP 200 | Observed separately |
| Return to Off and same-chat follow-up | ORIGINAL | UNOBSERVED in this run | UNOBSERVED in this run | Observed in corrected run below; ancillary Off 499 remains separate |
| Reopened/resumed projectless continuation | ORIGINAL | UNOBSERVED in this run | UNOBSERVED in this run | Observed in corrected run below |
| Controller project in On, without an explicit override in the first fixture | DEFAULT (inherited) | Human reported repeated failure | Gateway HTTP 401 across 12 observed HTTP attempts | Failed validation case; human reported 5 retries; counts describe different evidence and do not establish product-generated retries |
| Control project in On using an explicit override | OVERRIDE | UNOBSERVED in this run | UNOBSERVED in this run | Selection observed in corrected run; initiating stream cancelled |
| Control project in Off with unchanged assignment | DEFAULT | UNOBSERVED in this run | UNOBSERVED in this run | Selection observed in corrected run; initiating stream cancelled |
| Shared live model-list request | ORIGINAL | N/A | HTTP 200 | Observed |
| Separate ancillary Off request | As privately attributed; not substituted for the required first response | No separate visible-reply claim | HTTP 499 | Retained separately from the successful fresh first-Off HTTP 200 |
| Another unknown temporary identity in Off | No proven identity/forwarding authority | UNOBSERVED | Local HTTP 503 rejection | Remained unproven/denied; its request family is unestablished and is not labelled a title |
| Existing title option disabled in the controlled configuration | ORIGINAL only if eligible under an enabled policy | UNRUN | UNRUN | Disabled; live title case UNRUN; automated disabled-policy coverage retained |
| Live compaction, saved ancestry and in-flight transitions | ORIGINAL where applicable | UNOBSERVED | UNOBSERVED | UNRUN; deterministic automated coverage remains separate |

The controller correlated the human's privately identified fresh projectless
thread with preactivation saved-thread IDs and a positive supported projectless
marker. The observed first Off, On and extra On requests selected ORIGINAL,
independent of the initially distinct DEFAULT. Actual identifiers, destinations,
credential evidence and correlation receipts stay private. No absence-only proof,
new desktop-state source or unknown-request forwarding was used.

### Failed controller check and validation setup correction

For the initial controlled copy, the controller changed DEFAULT to an existing
alternate outgoing account without first verifying its gateway acceptance and
without retaining the controller project's explicit working override. The known
project's On request therefore inherited DEFAULT; the selected alternate gateway
returned HTTP 401. Private diagnosis attributes the validation setup mistake to
the controller. The evidence establishes neither incorrect product selection nor
an automatic retry behavior: 12 HTTP attempts were observed, while the human
reported 5 retries. Both facts remain recorded without equating them.

This failed run is retained. It does not erase the successful projectless
ORIGINAL selections with a distinct DEFAULT, and it cannot pass the intended
On-override/Off-default control-project comparison. The controller prepared
a second controlled fixture using the already-working original URL and existing
incoming credential reference for DEFAULT and an explicit controller-project
override. Preparation retrieved no secret and created/rotated no key; no product
change was made. The original run's distinct-default evidence remains separate;
the corrected fixture cannot supply that distinction when its default equals
ORIGINAL.

### Corrected run: reopened continuation and selection observations

The human reopened the proven projectless chat and confirmed replies in Off,
then On, then Off. Private inspection attributes all three initiating requests
to `projectless` / `original` with HTTP 200. The exact native app, managed child,
bounded diagnostic logger and listener remained the same throughout. There was
one Start, no configuration revision change and no assignment change during
this sequence; no routine restart was needed for the mode switches.

| Corrected-run observation | Selection | Visible outcome | Initiating transport | Limit |
| --- | --- | --- | --- | --- |
| Reopened projectless reply in Off | ORIGINAL | Human confirmed reply | HTTP 200 | Existing proven chat; fresh first message remains initial-run evidence |
| Same-chat On reply | ORIGINAL | Human confirmed reply | HTTP 200 | Same exact retained app/child/logger/listener |
| Same-chat return-Off reply | ORIGINAL | Human confirmed reply | HTTP 200 | Same configuration revision and assignments |
| Controller project in Off | DEFAULT; diagnostic `global` | User interaction retained separately | HTTP 499 / CANCELLED | Selection observed; no clean initiating-stream delivery claim |
| Controller project in On | OVERRIDE | User interaction retained separately | HTTP 499 / CANCELLED | Selection observed; no clean initiating-stream delivery claim |
| Shared catalog request | ORIGINAL | N/A | HTTP 200 | Bounded shared-request evidence |

DEFAULT and the explicit OVERRIDE in this corrected fixture deliberately use the
same known-working complete destination/reference pair. The observations therefore
distinguish selection categories, not different live gateway keys or general
cross-account continuation. The first run alone supplies distinct-default
independence: ORIGINAL projectless HTTP 200 versus inherited alternate DEFAULT
HTTP 401. The two runs are not represented as one uninterrupted listener session.

The human saw the guidance, and read-only native computer-use observation
confirmed the exact text:

> Chats outside projects use the original Codex connection in On and Off. Model lists and permitted automatic titles use it too.

The same observation showed On, matching/ready owned runtime, pending routed
confirmation, Restore Direct enabled and Stop disabled. No UI action was taken
by that observation. Whether the human clicked a confirmation earlier or later,
or whether intervening metadata invalidated an earlier confirmation, was not
observed. Journal phase `routed_confirmation` alone does not prove a pending
confirmation: in-memory confirmation can leave that journal phase unchanged.
The actual observed UI state and the later Direct-pending state below are kept
separate from journal-phase inference.

### Historical missing-confirmation finding

At the earlier final specification review, direct evidence of the guarded routed
confirmation action and resulting state was absent. That review returned
**MISSING**, Task 6 Step 3 was correctly left unmet, and quality review did not
run. Visible replies, journal phase and exact Direct recovery did not supply the
missing action. The user subsequently authorized finishing this same confirmation
test; the separate observed continuation below resolves that gap. The historical
MISSING result is retained and is not rewritten as a pass.

Disabled live titles and unperformed live compaction/ancestry/in-flight cases
remain UNRUN; deterministic automated coverage is unchanged. General stream
completeness, clean control HTTP 200 delivery, cross-account continuation and
billing attribution are not claimed.

### Separate confirmation-only continuation: guarded action now observed

The user explicitly requested finishing the confirmation test. This bounded third
run used a fresh byte-copy of the known-working configuration, unchanged existing
keys, the exact tested app launched through LaunchServices and the explicitly
selected tested real Node runtime. It used no logger or custom instrumentation.
This used the existing controller/project chat, not a new projectless chat. It
supplies the missing confirmation action/state; it does not repeat or replace
the first two runs' fresh-first-message, On/Off, distinct-default or control
selection/transport evidence. No model-request initiating HTTP status was captured
in this run. Any `/healthz` HTTP 200 was readiness evidence only; no new model
HTTP 200, transport-completion or cross-account claim is added.

The human started Off, activated, manually restarted Codex, received a routed
reply and reported clicking routed-response confirmation. Initial read-only
accessibility inspection still showed confirmation pending. Configuration/mode
source identities were unchanged while the recovery revision changed; the exact
cause and first-click/invalidation timing are **UNOBSERVED**. No first-click bug
or specific metadata invalidation is claimed.

The human repeated the confirmation button while the controller inspected and
without sending another chat message. Read-only native screenshot evidence then
directly displayed **User confirmed routed response**, with **Account routing**,
**Router**, **Matching listener ready** and **Owned by this app session**.
Restore Direct was enabled and Stop disabled. Fresh private inspection bound this
state to the same exact native app and managed child/parent attribution. This is
direct evidence of the guarded action and resulting state: Task 6 Step 3's
previously missing confirmation obligation is **PROVEN**. No agent UI action
performed the confirmation.

The retained-context warning remained expected until Direct recovery, including
after confirmed routed state. This observation establishes no product bug or
product fix. Original control HTTP 499/CANCELLED, same-pair selection categories,
distinct-default evidence from the first run, disabled live titles and unperformed
live compaction/ancestry/in-flight cases keep their original limits. No general
cross-account continuation, distinct live gateway-key or billing claim is added.

## Recovery and private-state disposition

The automated-check worker performed no actual configuration, credential, app,
chat or live recovery operation. The following live observations and private
proofs were supplied by the controller.

Before the first run, private checkpoints preserved normal/selected settings,
journal/provider/source bytes, optional-property presence and activation context.
The initial controlled copy was valid/ready, Direct, with no recovery and an empty
selected port. Title policy was disabled. The bounded private diagnostic launcher
was checked separately with synthetic passthrough/byte/duration/group-signal/drain
cases; correcting a fake-script readiness race changed no launcher or product.

After controller-project failures, the human restored Direct, manually restarted,
received a working direct reply, confirmed Direct, then used guarded Stop and
Quit. Independent controller inspection establishes the following first-run
endpoint; it does not pre-approve recovery for the subsequent corrected run.

| First-run recovery obligation | Actual observation |
| --- | --- |
| Retained-context Restore direct, human manual restart and working direct response | Human confirmed restore/restart, direct reply and Direct confirmation before Stop/Quit |
| Correctly bound Direct/restored records and no pending confirmation | Verified Direct/restored, no recovery, pending confirmation absent |
| Exact owned app/router/diagnostic logger exit and listener absence | Independently verified absent; selected port empty |
| Normal settings and provider restoration | Byte-exact against private checkpoints |
| Journal restoration and original optional runtime property | Byte-exact private journal restoration under `flock`, including original runtime-property absence |
| Diagnostic-launcher restoration | Original launcher disabled; owned logger absent; closing footer untruncated, 169809 bytes over 1463 seconds, no recorded errors |
| Source, bundle and signature after first live run | Controller reports matching frozen source/bundle identity and valid signature |
| Private backups, receipts and raw evidence | Retained outside Git; no values or private paths reproduced here |

These equality claims apply only to the named first-run normal/provider/journal
artifacts actually compared. No equality is inferred for unrelated whole files,
user chat history or future validation state. The failed controller check and its
receipts remain preserved. The corrected run's completed recovery is recorded
separately below.

### Corrected-run recovery and final operational restoration

The human switched Off, chose Restore Direct, manually restarted, received and
read a working direct reply, explicitly confirmed Direct, then used guarded Stop
and Quit and reported stopped. This confirmation is observed human action; it is
not inferred from the journal phase or from receiving a reply alone.

| Corrected-run and final restoration obligation | Actual observation |
| --- | --- |
| Retained-context recovery and response guard | Human Restore Direct → manual restart → read direct reply → confirmed Direct → guarded Stop/Quit |
| Exact owned native app, managed child and logger | Independently verified exact PIDs absent and no native app remaining |
| Selected listener | Independently empty selected port |
| Context state and confirmation | Direct/restored, no recovery, pending confirmation absent |
| Normal settings/provider | Byte-exact against original private checkpoints |
| Private journal and runtime optional-property presence | Restored byte-exact under guarded instance `flock`, after owner/mode/link/source/stat checks; original runtime-property absence restored |
| Retry diagnostic launcher | Exact private launcher disabled; its bytes/hash unchanged |
| Retry logger closure | Untruncated closing footer; 75667 bytes over 575.4556 seconds; duration bound not exceeded; forward/capture errors absent |
| Both retained activation contexts | Independently Direct/restored with no recovery; context-bound TOML backups byte-exact to their originals |
| Original selected configuration and optional runtime selection | Original value/presence restored; normal/provider/journal byte-exact |
| Both diagnostic launchers and activation locks | Both launchers disabled; activation locks absent |
| Frozen executable identity | Post-final-restoration source/bundle/binary/physical identity/signature match at 21:40:36Z |
| Receipts/backups/raw evidence | Retained privately outside Git for both runs |

These are the comparisons actually performed for the named operational artifacts
and both retained contexts. No equality is inferred for unrelated user files or
chat history. Earlier in this run, the child/logger/listener were deliberately
still alive while Direct response confirmation was pending; that historical
inspection is retained privately and is superseded by the final verified stopped
endpoint above. The initial failed fixture and all 401/499/503 observations remain
part of the evidence.

### Confirmation-only recovery and all-context restoration

The human restored Direct, manually restarted and received a direct reply. The
first stopped inspection found the router absent and port empty while the same
native app remained alive with Direct confirmation pending. This was a partial
boundary, not final cleanup. The human repeated Direct confirmation and Quit,
without another message. Independent reinspection then verified exact owned
native/child PIDs absent, zero native/router matches, empty port, pending
confirmation absent and correctly bound Direct/restored state with no recovery.
Normal settings and provider bytes matched the original checkpoints exactly.

Under the owned instance `flock`, owner/mode/no-follow/link-count/stat/source-byte
guards restored the original journal byte-exactly, including its original selected
configuration and optional Node-property absence; unrelated fields were preserved.
The final independent comparison covers **all three retained contexts**:
Direct/restored, no recovery, correctly bound named TOML backups byte-exact with
matching hashes, no activation locks, and normal/provider/journal all byte-exact.
Pending confirmation is absent and the original runtime-property absence is
restored. This third run had no diagnostic logger to close. Private receipts and
backups remain outside Git.

The final source/bundle/binary/physical identity comparison and strict signature
verification passed at 23:04:55Z on 2026-11-18 UTC, which is 2026-11-19 Europe/Rome.
These restoration claims concern the named compared operational artifacts and
retained contexts; no equality is inferred for unrelated user files or chat
history. The earlier partial stopped boundary remains preserved as history.

## Criterion disposition and review

| Criterion | Current decisive evidence and remaining obligation |
| --- | --- |
| AC-01 | Automated coverage; initial fresh projectless Off/On/extra-On ORIGINAL replies with distinct DEFAULT; corrected reopened Off→On→Off ORIGINAL replies/HTTP 200 on one retained listener. Separate-run and control transport limits retained |
| AC-02 | Positive supported identity, complete normalized ancestry/conflicts, bounded unknown rejection and zero-upstream denials covered by Tasks 1–3/5; final current-source chain PASS |
| AC-03 | Automated shared-routing/title-policy coverage plus live catalog ORIGINAL HTTP 200; live title case UNRUN because controlled policy is disabled |
| AC-04 | Automated pairing/guards pass; failed initial fixture retained. Corrected control Off `global` / On `override` selections observed without assignment changes; initiating streams 499/CANCELLED, no clean control delivery claim |
| AC-05 | Deterministic auth/lookup/stream/reuse/membership/cancellation barriers covered by Task 3; unperformed live interleavings remain UNRUN |
| AC-06 | Scoped managed schema-2 policy, unchanged legacy/standalone behavior and setup/control boundaries covered by Tasks 1–5; final current-source chain PASS |
| AC-07 | Diagnostic privacy/current guidance and relocated source-denied package coverage pass; read-only native observation confirms exact guidance and guarded On/owned-ready presentation |
| AC-08 | Required ordered current-source checks PASS with disclosed intentional warnings |
| AC-09 | Original fresh/reopened projectless replies, distinct-default and control selection evidence retain their limits. Separate confirmation-only run directly proves the guarded routed-response confirmation action/state; Task 6 Step 3 observation is complete and accepted by the final gate |
| AC-10 | Human projectless replies separated from initiating HTTP 200, control/ancillary 499, unknown-identity 503 and initial controller 401. Disabled titles and unperformed live compaction/ancestry/in-flight cases UNRUN |
| AC-11 | All three runs recovered with required human restart/direct confirmation and guarded Stop/Quit; final independent owned-process/listener absence, all three Direct/restored contexts, byte-exact owned settings/journal/backups and original optional-property absence verified |
| AC-12 | All task reviews Approved. Earlier specification MISSING retained as history and resolved by direct evidence. Fresh SPEC REVIEW: PASS followed by QUALITY REVIEW: PASS, no findings; local lifecycle closeout complete |

The sole integrated final gate reviewed the complete branch from `5d2e44b` to
`c4575414e3f9ec1d905b8819a3ed4f5f6e0c72cd`, including implementation base
`91b53e0`, against the approved pair. It returned **SPEC REVIEW: PASS**, then
**QUALITY REVIEW: PASS**, with **no findings** on 2026-11-19 (Europe/Rome).
Both reviewers verified the same immutable package and echoed matching identity:

| Review identity | Value |
| --- | --- |
| Gate run | `projectless-final-resumed-934c4f2d-d32b-49a4-8b89-86280f398953` |
| Reviewed state | `c4575414e3f9ec1d905b8819a3ed4f5f6e0c72cd-bc08d8e9-5d35-4320-9b8d-ce40701b260f` |
| Package SHA-256 | `6062c86e1c5d68c5890996ef0022e0fd86fd18884df503366a4d759cb2e03efc` |

The earlier MISSING finding remains historical and is resolved by the separately
observed guarded confirmation. Review approval retains every failed, limited and
UNRUN observation above; it does not establish complete control-stream delivery,
a single uninterrupted three-run scenario, general cross-account continuation,
billing attribution or production Keychain acceptance from synthetic seams.

Local closeout changes only lifecycle/checklist/evidence metadata after the
reviewed endpoint. The tested executable inputs and signed bundle remain unchanged;
whitespace, identity and exact stopped/restored-state checks cover closeout.
The branch is retained locally without push or merge. Account editing/deletion,
project visibility, broader UI and distribution remain deferred. This increment
adds no further product fix or scope.
