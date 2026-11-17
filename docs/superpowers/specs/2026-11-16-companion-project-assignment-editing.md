# Companion project assignment editing — specification

**Slug:** `companion-project-assignment-editing`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-16

**Updated:** 2026-11-17

**Stage:** 4 — specification and plan separately approved; Subagent-driven implementation selected

**Execution evidence:** Tasks 1–7 implemented and task-reviewed, including scoped fixes. Task 8 automated native/build/Node/package verification passed (298 native, 958 Node, exactly 3 package cases, zero failures/skips); human native/live acceptance and the sole final sequential whole-branch specification/quality gate remain pending. See [assignment validation](../../validation/companion-project-assignment-editing.md).

**Storage:** Saved in the existing checkout on `feat/companion-project-assignment-editing`; the approved pair was committed together before product changes. Current lifecycle updates remain local to this branch.

**Provenance:** The next companion increment request, repository and operational inspection, native clarification answers, and the complete Stage 1 scope/design proposal accepted by the subsequent `confirmed` message. That confirmation authorized the DRAFT only. The complete DRAFT was then presented in chat while Plan mode prohibited saving. The user's subsequent `Please implement the plan.` approves the specification just presented under the mandatory separate-gate workflow; no assignment implementation plan had yet been presented. Specification approval authorizes separate planning only. The approved requirements below are unchanged; status, storage and approval metadata now reflect that approval.

Artifact resolution before saving was **MISSING** for both specification and plan. This specification is now saved at `docs/superpowers/specs/2026-11-16-companion-project-assignment-editing.md`. The matching plan was subsequently saved and separately presented; the user's following `approved` approves that plan. Both artifact gates are complete. The user then explicitly selected Subagent-driven through the native interactive control.

## 1. Problem and desired outcome

The wider direction is understandable native management of routing, named accounts and project assignments.

The router currently loads configuration at startup. Its owned runtime channel changes routing mode only. The companion displays discovered and configured projects but cannot edit their assignments.

This increment lets a user:

- Assign an existing named account to one project.
- Switch that assignment to another existing account.
- Choose **Use default** to remove the explicit override.
- Understand the saved assignment separately from its effective running state.

A successful live change uses **Save and apply** without an ordinary Codex restart. When safely stopped and Direct, **Save** persists the change for the next explicit Start, which starts routing Off.

The uncertainty this increment resolves is whether assignment changes can be persisted and applied through a narrow owned-child operation while preserving request consistency, ownership and recovery. Persistence, application, acknowledgment, presentation and recovery belong together because each is necessary for a usable outcome.

## 2. User flow and eligibility

Editing operates on one project per action in a valid, ready schema-2 configuration. Readiness establishes complete setup; it does not establish credential accessibility.

The editor offers existing named accounts and **Use default**:

- Selecting an account creates or changes an explicit override using its stable account identity.
- Selecting the current default account by name remains an explicit override.
- **Use default** removes the project's exact mapping entry.
- An already-unassigned project does not acquire an unnecessary mapping.

Imported legacy inheritance labels retain inheritance semantics until explicitly changed. Unresolved explicit targets remain visible failures. The user may repair the selected project by choosing an existing account or removing its override; an unresolved target never silently becomes inheritance.

Configured projects absent from otherwise healthy discovery remain editable through their exact saved UUID and mapping key, with a visible warning. No manual project-ID entry or bulk editing is added.

Unreadable, conflicting, duplicate or case-conflicting identity prevents unsafe editing. Failed discovery must not turn stale rows into current evidence. Schema-1 and incomplete configurations retain browsing and the existing setup/import flow; this increment does not migrate them automatically.

### Operational eligibility

| State | Assignment behavior |
|---|---|
| Exact supported owned child, functioning channel, coherent saved/running baseline | Save and apply |
| Safely stopped and Direct, independently empty selected port, no unresolved recovery or mutation | Save |
| External/unowned listener, unsupported or unavailable channel, uncertain mutation, conflicting context or unsafe recovery evidence | Browse saved state; block writes and explain why |

Routing Off alone does not authorize a stopped save. Account/default saves retain their existing safe Direct/stopped boundary.

### Everyday presentation

Show routing state/action, default account, project assignment and relevant errors. Distinguish:

- Saved assignment and any unsaved selection.
- Active explicit override or inherited default.
- Overrides suspended while routing Off.
- Not running.
- Unconfirmed state or confirmed saved/running divergence.

Saved configuration must never appear applied merely because persistence succeeded. Account labels do not prove credential accessibility, gateway success or billing attribution. Put aliases, revisions and process/protocol diagnostics in Advanced.

## 3. Selected approach and interfaces

Extend the existing private owned-child channel with assignment mutation and authoritative assignment-state reconciliation. The exact owned child validates, persists and publishes the immutable assignment snapshot under the existing context mutation/startup lock.

The alternative considered was a helper saving configuration before requesting child application. It introduces another authority and a larger coordination gap. The selected child-owned operation keeps the live transition under one authority.

This is an assignment-only capability, not a general reload framework. It cannot change accounts, defaults, credentials, providers or desktop authentication. Safely stopped saves use the same assignment transformation with the existing stopped persistence safeguards.

The operation binds:

- Canonical configuration context and exact owned child/session.
- Unique request identity.
- Expected saved and running revisions.
- Selected project identity and existing account identity, or inheritance.

Fresh validation rejects stale observations, wrong contexts, replaced files and observed concurrent changes. Cooperating context mutations serialize, including conflicting setup/startup operations.

Stale controller generations, retired requests and responses from another child cannot establish success. Reading the exact owned child must remain possible when saved and running fingerprints differ; reconciliation cannot require already-matching readiness.

Exact message encoding, module boundaries, revision representation and bounded storage mechanics belong to the separate implementation plan.

### Mapping isolation

Change only the selected project's exact mapping key and any necessary compatible binding.

Reuse a compatible binding or create one. Never retarget a shared binding or garbage-collect existing bindings, including when removing an override.

Preserve other projects, existing aliases, account identities, complete endpoint/key pairings, incoming verification, original direct destination, unrelated configuration and optional-property presence.

## 4. Persistence, acknowledgment and recovery

Before persistence, freshly validate the source, expected revisions, context safety, selected identity/account and complete prospective configuration. Confirm that the result changes only authorized assignment data.

Retain the existing private checkpoint, ownership/containment checks, secure temporary file, validation, synchronization and compare-before-replace protections. Checkpoints and recovery evidence belong beside the selected configuration.

Preserve unsafe, corrupt or conflicting records and locks. Do not remove stale locks automatically or overwrite observed external changes. Coordinating writers does not guarantee atomicity against an external editor that ignores the lock; document that limitation.

### Outcome contract

| Outcome | Meaning and behavior |
|---|---|
| Positive acknowledgment | Persistence is durable and the corresponding snapshot is published on the same child |
| Proven rejection before replacement | Saved and running state remain unchanged |
| Failure after a write may have occurred | Outcome is uncertain; never presume success or rollback |
| Fresh authoritative reconciliation after the attempt settles | May establish the actual saved and running outcome |
| Confirmed saved/running divergence | Show both states and require existing guarded recovery |

Timeout, cancellation, synchronization failure, publication failure, pipe loss and lost acknowledgment are uncertain whenever persistence may have occurred. Never retry a mutation automatically. Block further assignment writes while its outcome remains unconfirmed.

A confirmed matching saved/running result may be shown as successful. A stale reply cannot clear uncertainty.

Confirmed divergence follows the existing guarded path: Restore direct, manual Codex restart and working-direct-response confirmation where required, guarded Stop, then explicit Start in Off. Do not add a second live “finish applying” command, automatically restart applications, or restore an old checkpoint over newer configuration.

Already-settled Direct recovery does not require gratuitous repeated confirmation.

## 5. Request consistency and routing safeguards

Capture **routing mode and the immutable configured assignment snapshot synchronously at HTTP request receipt, before the first await**, including incoming authentication.

That captured state governs the request through authentication, identity lookup and bounded retries, account selection, credential retrieval and streaming:

- Requests received before publication retain the previous snapshot.
- Requests received after publication capture the new snapshot.
- Requests on the same connection capture state independently.
- Long streams, background requests and compaction requests do not change accounts mid-request.

Desktop membership still resolves freshly through existing identity checks. This does not promise an atomic snapshot across desktop files.

Incoming authentication remains mandatory before project metadata observation, identity resolution or outgoing selection. Complete destination/credential pairing remains request-local.

Explicitly unavailable accounts, unreadable/conflicting identity and credential, credit or upstream failures remain failures. Preserve no fallback, alternate-account retries or redirects. Preserve request bodies, models, continuation identifiers and existing streaming/cancellation behavior.

Off continues to suspend overrides while retaining them and using the default. Assignment application never changes On/Off.

Assignment editing introduces no credential retrieval or destination preflight.

## 6. Readiness, startup and ownership

Runtime readiness and fingerprints must reflect the applied assignment snapshot.

A verified assignment-only transition must narrowly reconcile its exact context/revision change while preserving desktop response-confirmation and original recovery obligations. Successful assignment editing must not create a gratuitous Codex restart requirement.

Unrelated or unexpected configuration changes retain conservative invalidation. Do not weaken operational fingerprints or replace original direct-recovery facts.

On relaunch or inspection, read actual saved configuration and reconcile only with an exact still-owned child. Never replay an interrupted mutation.

The next explicit Start loads actual saved assignments and starts Off. It does not incidentally reload account/default changes into an existing child.

Preserve process ownership, startup locking, guarded Stop/Quit, context-local activation records and original Direct restoration. A surviving child from an earlier companion process remains unowned. Do not adopt it, signal a port occupant or remove unsafe recovery evidence.

## 7. Acceptance criteria

| ID | Verifiable outcome |
|---|---|
| **AC-01** | Ready schema-2 projects support assign, switch and Use default, one project at a time. Explicit selection of the default account remains distinguishable from inheritance. |
| **AC-02** | Live Save and apply durably persists and publishes through the exact owned child without routine Codex restart or routing-mode change. |
| **AC-03** | Stopped Save passes fresh Direct/stopped guards, does not start or activate anything, and is loaded by the next explicit Start in Off. Unsafe/unowned/unavailable states block writes visibly. |
| **AC-04** | Saved, running, suspended, not-running, divergent and unconfirmed states are presented truthfully, without credential-access or billing claims. |
| **AC-05** | Healthy configured-only rows use exact saved keys with a warning. Identity conflicts block safely. Legacy inheritance and unresolved-target semantics survive selected-project repair. |
| **AC-06** | Shared aliases/bindings remain isolated. Other mappings, account identities, endpoint/key pairs and optional-property presence are preserved without binding cleanup. |
| **AC-07** | Deterministic checks prove request snapshots survive changes during authentication, identity retries, credential reads and streams; subsequent requests capture the new state. |
| **AC-08** | Context/session/request and saved/running revision checks reject stale edits, observed replacement/concurrency and stale UI/replies. Cooperating mutations serialize. |
| **AC-09** | Proven pre-write rejection preserves both states. Persistence faults retain evidence. Post-write ambiguity never becomes presumed success/rollback or an automatic retry. |
| **AC-10** | Authoritative reconciliation works despite readiness mismatch. Confirmed divergence and unavailable reconciliation follow the specified guarded recovery behavior. |
| **AC-11** | Verified assignment transitions preserve desktop-confirmation and original recovery authority. Unrelated changes invalidate conservatively. Account/default save guards remain intact. |
| **AC-12** | Interrupted operations and relaunches use actual saved state without replay, adoption, unsafe signalling or incorrect-context recovery. New Start remains Off. |
| **AC-13** | Incoming authentication, complete pairing, unavailable-target failure, no fallback/retry/redirect, On/Off and Stop/Quit regressions pass. |
| **AC-14** | Native/package checks and bounded private live assign/switch/remove validation cover the user flow and exact recovery. Documentation reports observed evidence and limitations accurately. |

## 8. Verification obligations

Use deterministic fixtures and barriers around authentication, identity retries, credential reads and streams. Verify actual selected pairs and request boundaries rather than relying on timing.

Cover shared bindings, exact mapping keys, legacy/unresolved/configured-only projects, stale revisions and replies, lock contention, file replacement, persistence interruption, timeout/channel loss, shutdown/relaunch and context-local recovery. Include same-connection, background/compaction and routing-mode interactions.

Run the appropriate Node, native and package checks, including final signed-package/resource verification. Exercise native saved/running presentation and blocked operations.

Perform a bounded, user-assisted private live assign/switch/remove sequence using freshly established operational context and available accounts. Successful changes require no ordinary Codex restart. Use explicit human actions where required and restore the exact original operational state.

The normal configuration was legacy at inspection; do not silently migrate it or treat historical validation configurations as current operational truth.

Keep actual credentials, references, endpoints, project mappings, checkpoints and raw runtime evidence outside Git. Keep secrets out of arguments, logs and JSON configuration.

Record only checks and reviews actually performed. Preserve the qualification of historical visible replies whose initiating requests recorded `499/CANCELLED`; they do not establish complete transport delivery, independent billing attribution or general cross-account continuation.

## 9. Constraints, exclusions and endpoint

Defer account editing/deletion, project hiding/reveal, comprehensive UI simplification, general reload, startup automation and distribution improvements.

Preserve the accepted viewport displacement after configuration selection and ordinary Tab focus moving off-screen.

Preserve completed account/default, branding, Dock and icon behavior. The inherited branding closeout remains separate in local commit `2f6c4ea`.

Use the existing checkout without a worktree. Do not update main or create the assignment implementation branch before separate specification and plan approvals. Both artifacts must be saved before product-code changes. No push or merge is authorized.

**Execution endpoint:** Deliver only this approved increment with safeguards, documentation, verification and the sole sequential final specification/quality review; commit locally on its separate appropriate branch, report results, limitations and exact recovery, then stop before another increment, push or merge.

**Completeness check:** The fresh builder reviewer reported “nothing important left.” This is not specification approval or the final implementation review.

**Approval history:** The complete unsaved DRAFT was presented at Stage 2, with explicit notice that specification approval authorizes a separate implementation plan only. The subsequent `Please implement the plan.` is that specification approval. The matching saved plan was then separately presented, and the following `approved` is plan approval. The native interactive response explicitly selects Subagent-driven execution. Push and merge remain unauthorized.
