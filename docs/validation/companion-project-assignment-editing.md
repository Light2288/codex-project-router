# Companion project assignment editing validation

Created: 2026-11-17
Updated: 2026-11-17

Status: implementation and task reviews through Task 7 recorded; Task 8 automated
verification passed. Human native/live acceptance and the sole final
whole-branch sequential specification/quality review remain **PENDING**. This
record does not close the increment or approve the final branch. Work remains
local; no push or merge.

Scope: the approved `companion-project-assignment-editing` increment, governed by
the [specification](../superpowers/specs/2026-11-16-companion-project-assignment-editing.md)
and separate [implementation plan](../superpowers/plans/2026-11-16-companion-project-assignment-editing.md).
Wider account editing/deletion, hiding, UI redesign, startup automation and
distribution remain deferred. The endpoint is this single guarded assignment flow
with its verification, native/live observations, exact recovery and final review;
no later increment is authorized by this record.

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
Controller ownership survives sheet dismissal. No mutation is retried automatically.

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

All Task 8 test/build commands run with process-scoped `caffeinate -i`; the
underlying approved commands and deadlines are unchanged. Logs stay outside
tracked documentation in the ignored task evidence directory. No private actual
configuration, credential, mapping, endpoint, comparison token or checkpoint is
included here.

The new package assertions initially passed against already-landed production:
`npm run companion:build`, exit 0, followed by `npm run companion:package-test`,
exit 0, **3 tests / 3 pass / 0 fail / 0 cancelled / 0 skipped / 0 todo**,
27081.981459 ms. This is positive integration coverage, not a manufactured RED.
The source allowlists already included project-catalog.js, project-assignments.js
and configuration-lock.js under the dependency-order ruling, and the schema-2
ready capability expectation already landed in Task 4.

Final required order, with each command wrapped in `caffeinate -i`:

| Command | Fresh result |
| --- | --- |
| `npm run companion:test` | Exit 0; 298/298 (224 core + 74 app), zero failures; core 99.987 s, app 0.699 s |
| `npm run companion:build` | Exit 0; built and ad-hoc signed current app |
| `npm test` | Exit 0; 958/958, zero failures/cancellations/skips/todo; 58201.244959 ms |
| `npm run companion:package-test` | Exit 0; exactly 3/3, zero failures/cancellations/skips/todo; 27487.636708 ms |

The native log has no warning/error diagnostics. The release build emits seven
pre-existing KeychainStore Security API deprecation warnings (each repeated in
source annotation), with no assignment warning/error. The Node package harness
emits 13 intentional file-backed Security API deprecation diagnostics and no
other warnings. Its synthetic unresponsive probe requires SIGKILL and verifies
reaping; EPERM/ERR_MODULE_NOT_FOUND are intentional source-denial checks.

Build identity: `dist/Codex Project Router.app`, ad-hoc signature, 19 production
source modules, arm64, Node 24.21.0, macOS 27.0.1. Native executable SHA-256:
`59442082c13e2bfd28fafc26041248212a1875b1a205a8a26a9b40a4f74ac146`.
Code-signature CDHash: `efb0f01b0401a87b6bdfb9a1da82bed1aca4c11f`.
These identify build code; configuration comparison tokens remain private.

Exactly three package cases are retained. They cover explicit resource allowlists,
dependency drift, relocated ad-hoc signature verification using
`codesign --verify --deep --strict`, arm64 metadata, branding decoding, minimal GUI
PATH and source equality. Both relocated fixtures exercise real bundled stopped
Save/checkpoint/readback, next Start Off, owned live assign/switch/remove, exact
listener ownership, saved/running coherence, applied health fingerprints, retained
account/default/incoming settings and bindings, unchanged provider/recovery,
zero upstream connections and byte-exact Direct rollback. The third case runs
under macOS Seatbelt checkout/source denial, checks lexical/resolved/symlink denial,
and confines synthetic native stores. Its automated visible-window proof does not
establish human interaction with the assignment editor.

Existing native Keychain/branding checks and exact synthetic cleanup remain.
An owned disposable Keychain contains a public fixture; production metadata/create
and bundled reader comparison run without printing secret values. Cleanup checks
owned files/search-list entry/default-handle preservation. The harness identity
differs from the packaged app ACL identity. The deliberately unresponsive synthetic
probe reaches its hard deadline and verifies reaping/process-group absence.
Security API deprecation diagnostics and intentional source-denial errors are
disclosed above; no warning suppression or weakened deadline is introduced.

## Acceptance traceability

These automated observations support the criteria; pending human/final gates
remain required before full acceptance.

| Criteria | Current automated evidence | Remaining observation |
| --- | --- | --- |
| AC-01 assignment actions | Pure transforms, native editor actions, both bundled assign/switch/remove flows | Human native/live request/UI sequence |
| AC-02 durable application | Guarded persistence, request snapshot barriers, owned command publication and package health coherence | Live initiating transport and UI |
| AC-03 stopped Save/Start Off | Stopped helper/controller and both package fixtures | Human stopped Save/Start Off |
| AC-04 truthful state | Native saved/running/Off/unconfirmed/divergence presentation and authoritative package reads | Human presentation |
| AC-05 identity/catalog/repair | Catalog exact/conflicting identity, configured-only baseline and native unresolved selection tests | Configured-only/unavailable-control human display |
| AC-06 isolation/presence | Pure/persistence exact-key and optional-presence tests; package binding/account preservation | Final review |
| AC-07 request consistency | Full Node auth, identity, credential, stream and reused-connection snapshot barriers | Final review; no billing/general continuation inference |
| AC-08 stale authority | Source identity/catalog/lease and native generation/exact-child/editor-baseline tests | Final review |
| AC-09 ambiguity | Injected writer phases, ordered control, lost-ack/helper and native no-retry presentation tests | Final review |
| AC-10 reconciliation/recovery | Serialized observations, retained runtime and guarded Direct/native uncertainty tests | Human recovery/response confirmation |
| AC-11 confirmation continuity | Native exact transition versus provider/recovery drift and account/default regressions | Final review and human integration |
| AC-12 process lifetime | Helper exit/drain, owned child, queued preflight/relaunch/start authority tests | Human package lifetime observations |
| AC-13 routing safeguards | Incoming auth/paired destinations/no fallback; ownership/Stop/Quit; package zero control-time destination contact | Human exact Direct restoration and guarded Stop |
| AC-14 package/live/docs | Fresh native/build/Node/package chain, package confinement and docs | Human live and sole final review |

## Task reviews and implementation rulings

Tasks 1, 2, 4, 5 and 7 received approved task specification/quality reviews.
Task 3's artifact/source authority findings were addressed in two scoped rounds;
the final scoped review approved both specification compliance and quality.
Task 6's queued live-to-stopped child-capture finding was addressed and approved
in scoped review; its deferred delayed-divergence presentation finding was fixed
and reviewed in Task 7. Existing unchanged Security API warnings remain a separate
cleanup concern. These are task reviews, not the sole final whole-branch gate.

Recorded implementation rulings preserve the existing checkout/no-worktree
preference, earlier synchronized source allowlists and matching builds, temporary
idle-sleep assertions, pure transformation/source-identity separation, exact flat
wire evidence with explicit nulls, narrow internal filesystem fault seams and a
no-yield final authority guard. Native editing authority uses validated exact-child
reads and an explicit-load baseline; stopped initial eligibility may use a real
configured-only catalog entry without inventing selection. The queued-save fix
retains the intended child before waiting for the shared slot. Delayed divergence
classification reuses existing authority without granting new writes.

One bounded lastAttempt and immutable changed-operation artifacts are retained;
there is no unbounded replay history or exactly-once mutation service. No-op
operations create no artifact. A stopped read after the exact helper/child exits
can settle persistence only; it cannot attest prior live application. Locks and
fresh source checks cannot provide an atomic multi-file snapshot or filesystem
compare-and-swap against external writers ignoring the shared lease.

## Native and private live acceptance — PENDING

No human assignment-editor launch/interaction, live account request or operational
recovery sequence has been performed for this increment in this record. A
preliminary controller read-only check found normal setup legacy/migration-required,
Direct/restored and no named accounts or companion process. That is not empty-port
proof or evidence about another context. Normal setup is not silently migrated.
An existing private ready-schema-2 context with freshly verified available named
accounts remains a live prerequisite.

| Required observation | Current evidence |
| --- | --- |
| Human native layout, selection, Save labels and dismissal/refresh behavior | PENDING; synthetic native/presentation tests are separate |
| On: assign → switch → remove on one project, saved/running UI and initiating request for each, no per-change restart | PENDING |
| Off suspension, safely stopped Save and next Start Off | Automated fixture coverage; human/private live observation PENDING |
| Configured-only warning and unavailable-control presentation | Synthetic presentation/controller coverage; human observation PENDING |
| Exact original Direct restoration, manual restart and confirmed direct response, guarded owned Stop and private cleanup | PENDING; no operational change made by this automated phase |
| Sole sequential final specification then quality review against resulting complete branch/package | PENDING; not dispatched by this task worker |

Before live work, freshly establish selected context, actual saved setup, exact
ownership, provider, listener, tested package and recovery records. Keep original
private context and exact recovery data outside Git. Required human launch,
activation/restart/response confirmations remain explicit. Record initiating
transport separately from visible replies: 499/CANCELLED is cancelled transport.
No independent billing attribution or general cross-account continuation claim
follows from configured account labels, readiness, a visible reply or synthetic
tests. Existing accepted viewport/off-screen Tab limitations remain.

## Local branch and completion boundary

Branch: `feat/companion-project-assignment-editing`. Task 8 starts at
`ac627cdc5b87b3e0ecf94fb8c2bb496e63ea8732`. The implementation branch was created
from local main `c0a5a53d8c41a6c394f28497fa39133d68a79683`; the separate branding
closeout branch remains at `2f6c4ea09f7ec61e8ded355464acf7f68dc8ca73` and is not
merged here. The Task 8 package/docs commit containing this record changes no
production source; executable source remains at the Task 7 endpoint above. The
final reviewed commit/package endpoint remains pending. The controller owns human
live follow-through, supplied observations, final sole review and closeout. This report must be updated from actual outcomes before any
claim of full increment acceptance.
