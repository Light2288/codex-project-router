# Projectless chat compatibility — specification

**Slug:** `projectless-chat-compatibility`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-18

**Updated:** 2026-11-18

**Current stage:** 4 — specification and separate implementation plan approved; subagent-driven implementation authorized.

**Storage:** Saved after leaving Plan mode at `docs/superpowers/specs/2026-11-18-projectless-chat-compatibility.md`. The complete unsaved DRAFT was previously presented in chat; its requirements below are unchanged.

**Artifact resolution:** Specification and implementation plan were both MISSING before this specification was saved. No matching legacy artifact or conflicting candidate was found. The separate plan must use this specification's exact basename and shared slug.

**Provenance:** The user selected preservation of the original Codex connection, selected **Original Codex** for shared requests and **Companion only** for operating-mode coverage through native clarification, then approved the presented scope/design with **“scope/design confirmed.”** That confirmation authorized the DRAFT only. The complete DRAFT was then presented in chat while Plan mode prohibited saving. The user's subsequent **“Please implement the plan.”** approves that specification under the mandatory separate-gate workflow: no implementation plan had yet been presented. That specification approval authorized Stage 3 planning only. After the separate plan was presented, the user explicitly approved it and its execution method with **“plan approved, subagent driven execution approved.”** Both saved artifacts are now approved for Stage 4 implementation.

## 1. Problem, outcome and delivery boundary

The companion currently blocks model requests from chats explicitly identified as projectless. Routing Off does not bypass that restriction. Its account-based mode also sends model-list requests and qualifying unassigned titles through the companion default.

This increment makes projectless chats usable through the running proxy while preserving their original Codex connection. Projectless traffic remains independent of project assignments, the companion default and project-routing On/Off.

The selected approach uses the preserved original destination and the credential Codex currently sends, after incoming authentication. It does not capture or cache a secret during activation.

Two alternatives were considered:

- **Companion default:** fewer routing categories, but default changes also affect projectless chats.
- **Separate “Outside projects” account:** independent account selection, but requires additional configuration and UI.

The user selected preservation of the original connection.

The increment covers companion-managed, ready schema-2 account routing, together with necessary classification, diagnostics, documentation, packaging, tests and bounded native/live validation. Standalone serving—including schema-2 standalone—and legacy/schema-1 behavior remain unchanged.

The main uncertainty is whether the desktop exposes sufficient supported identity evidence for a fresh projectless chat's first request. First-message compatibility is a required outcome, not an assumption.

## 2. Request behavior and safeguards

### Connection selection

“Original connection” means the existing configuration's preserved original-direct destination, including its full API prefix, paired with the accepted incoming credential. The currently activated loopback provider URL must never become the upstream destination.

| Request in companion-managed account mode | Routing Off | Routing On |
|---|---|---|
| Confirmed projectless model request | Original connection | Original connection |
| Identified project with an override | Companion default | Assigned account |
| Identified project without an override, including imported inheritance | Companion default | Companion default |
| Shared model-list request | Original connection | Original connection |
| Eligible unassigned initial-title request | Original connection | Original connection |
| Unknown, malformed, unsupported or conflicting model identity | Existing bounded rejection | Existing bounded rejection |
| Local health request | Existing local behavior | Existing local behavior |

The shared-request change applies across all chats.

Ordinary supported identity resolution takes priority over the title exception. A title-marked request with proven project membership follows project routing; one with proven projectless membership follows projectless routing.

Temporary unassigned titles retain the existing opt-in, strict metadata matching and fresh absence proof. This increment does not enable the option automatically, broaden eligible auxiliary families or treat known projectless identities as unassigned-title exceptions.

### Positive proof of projectless identity

Projectless routing requires positive supported saved-state evidence. Missing project assignments, saved-thread existence alone and client-provided identity claims are insufficient.

Resolution must:

- Validate the saved projectless marker and relevant saved ancestry/session relationships.
- Complete the relevant ancestry consistency checks before granting projectless routing.
- Allow a descendant to inherit proven projectless membership through supported saved parent edges.
- Reject contradictory project/projectless evidence, ambiguous normalized identities, malformed required state, cycles and unsupported relationships.
- Preserve existing bounded lookup, ancestry and cancellation limits.

No project is inferred from prompts, folders, foreground windows or nearby activity. The router must not manufacture markers or write desktop membership state.

A fresh request may wait within the existing bounded local lookup window for supported state to become visible. It must not forward while its identity remains unproven.

**If first-message compatibility cannot be established using the supported evidence, the capability remains incomplete. Complete recovery and return to scope/design rather than adding an unknown-request fallback or an unapproved evidence source.**

### Authentication and isolation

Every admitted non-health request retains incoming credential verification before identity resolution or forwarding.

Projectless, model-list and eligible unassigned-title requests preserve the accepted incoming Authorization value. They do not retrieve an outgoing default or project key. Inaccessibility of those outgoing secrets alone must not break the original-connection paths.

Existing configuration validity and setup-ready startup requirements remain authoritative.

Project requests retain their complete selected URL/key pair. Missing targets, credential failures, exhausted credit and upstream failures must not cause fallback to the original connection. Failures on the original connection likewise receive no alternate-account fallback, automatic retry or redirect following.

Preserve model, body, continuation identifiers, query, streaming, backpressure and cancellation behavior. Host must match the selected destination. No account or continuation translation is introduced.

### Request timing and membership changes

Continue capturing configuration and routing mode together at HTTP request receipt, before asynchronous authentication.

Membership is resolved from fresh supported saved evidence. This does not promise membership at request receipt or an atomic snapshot across JSON and SQLite.

Once selected, retain the request's classification and connection for its lifetime, including its stream. Later mode or assignment changes cannot reroute it.

Subsequent requests resolve membership again, including movement between project and projectless states. Contradictory transition evidence remains blocked. Existing limitations around continuing a chat across different upstream accounts remain visible.

## 3. Integration, compatibility and exclusions

Use the existing companion controls and account/assignment flows. No projectless pseudo-project, account selector, configuration schema, migration, policy switch, HTTP endpoint or CLI command is added.

Necessary explanatory text must distinguish:

- Original-connection traffic for projectless and shared requests.
- Companion-default traffic for projects.
- The fact that Routing Off remains proxied.

Diagnostics must identify projectless attribution and original-connection selection accurately. They must not fabricate project, alias or account attribution, or expose endpoints, credential references, secrets, prompts or bodies. Exact internal representation belongs to implementation planning.

Preserve diagnostic behavior outside the selected operating mode. Synchronize affected producers, sanitizers and consumers.

The updated behavior takes effect when an updated bundled router starts. A predecessor child must not be represented as having acquired the new behavior. No general reload, listener replacement or additional provider rewrite is introduced.

Preserve explicit startup in Off, ownership, account/default save boundaries, activation records, original-direct recovery, response confirmation and guarded Stop/Quit. This increment adds no production Keychain writes.

Defer:

- Standalone and legacy routing changes.
- A separate projectless account selector.
- General unidentified-request forwarding or expanded title admission.
- New desktop relationship sources.
- Account editing/deletion, project visibility, broad UI redesign and startup/distribution.
- Continuation translation and independent billing proof.

Historical approved specifications and validation retain their original meaning. Update current usage documentation and create a new sanitized validation record.

## 4. Acceptance criteria

| ID | Verifiable outcome |
|---|---|
| **AC-01** | Fresh and existing projectless chats, follow-ups, resumed requests and compaction use the complete original destination and accepted incoming credential in On and Off. A distinct companion default demonstrates independence; no outgoing default/project key is retrieved. |
| **AC-02** | Projectless markers and supported saved ancestry grant authority only after relevant consistency checks. Conflicts, ambiguous identity, malformed/unavailable state, cycles, incompatible sessions and forged parent claims cannot grant forwarding. Unknown requests retain bounded rejection and zero upstream model calls. |
| **AC-03** | Model-list requests and already-eligible unassigned titles use the original connection across all chats in On and Off. Existing title opt-in, absence proof and ordinary identity precedence remain intact. No additional endpoint or auxiliary family becomes eligible. |
| **AC-04** | Project override, default and inheritance behavior remains correct. Missing-target, authentication, credential and upstream failures retain their failure behavior without fallback. Existing native mode and assignment operations retain listener ownership and recovery safeguards. |
| **AC-05** | Deterministic authentication, lookup and stream barriers verify request consistency across mode changes, assignment changes, membership transitions, reused connections and cancellation. Requests are not rerouted or retried; bodies, models and continuation identifiers remain unchanged. |
| **AC-06** | Behavior changes only in companion-managed schema-2 account routing. Managed schema-1 and standalone schema-1/schema-2 retain historical behavior. Existing configurations require no migration; setup, strict validation and credential-free control operations remain intact. |
| **AC-07** | Diagnostics and current documentation distinguish projectless/shared original routing from companion-default routing without prohibited data or fabricated attribution. The signed app works relocated and with checkout access denied. |
| **AC-08** | Appropriate focused and full Node/native checks, a matching signed build, exactly three package cases with zero skips, syntax and whitespace checks pass. Existing intentional Security SDK warnings remain disclosed and are not suppressed. |
| **AC-09** | Bounded native/live validation observes a genuinely fresh projectless first message, follow-ups through On/Off without routine restart, reopened projectless continuation, selection independent of a distinct companion default, and unchanged control-project routing. At least one actual projectless response is observed in each mode. |
| **AC-10** | Native/live evidence records visible replies separately from initiating transport outcomes. Eligible temporary titles are observed when the controlled configuration enables the existing option; otherwise that live case is recorded unrun. Dedicated compaction, ancestry and in-flight interleavings require deterministic automated coverage; unperformed live cases are not claimed. |
| **AC-11** | Live work ends with exact restoration of prior owned settings and optional-property presence, preserving unrelated edits and private evidence. Required manual restart/direct-response confirmation precedes guarded Stop. Independently verify owned process/listener absence and recovery state. |
| **AC-12** | Sequential final specification then quality review completes with actionable dispositions and a truthful result/evidence/limitations report. Failed required compatibility observations remain incomplete after recovery. Execution stops before another increment. |

## 5. Verification, approval and execution endpoint

Automated verification uses disposable synthetic desktop state and distinguishable local original/default/override destinations and credentials. It must establish wrong-token rejection, connection isolation and exact request preservation without real credential retrieval.

Native/live validation is user-assisted and bounded. Actual identifiers, destinations, credentials, checkpoints and raw traces remain outside Git. Chat creation, messages and restarts require user interaction or separate authorization.

The earlier investigation established current rejection behavior; it does not establish acceptance of this increment. Synthetic results alone cannot establish fresh desktop first-message compatibility, complete live transport delivery, general cross-account continuation or billing attribution.

**Builder completeness check:** A fresh reviewer returned **“nothing important left.”** This is not specification approval or final implementation review.

**Historical Stage 2 handoff:** The complete DRAFT was presented in chat. Explicit approval authorized Stage 3 implementation planning only. The user supplied that approval with **“Please implement the plan.”** A separate implementation plan must now be presented and explicitly approved. Both artifacts must be saved before product changes; leaving Plan mode does not supply missing approvals.

After those approvals, follow the existing-checkout Git workflow: safely update main, create a conventional implementation branch, commit both approved artifacts there, then implement and verify. Do not create a worktree, push or merge without a user request.

**Execution endpoint:** Deliver only this compatibility increment, complete automated/native/package verification, bounded live validation, exact recovery and final review, commit locally and report the working result and limitations, then stop before project visibility or any other increment.
