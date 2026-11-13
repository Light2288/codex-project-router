# Companion account/default setup — specification

**Slug:** `companion-account-default-setup`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-13

**Updated:** 2026-11-13

**Storage:** Saved in the existing checkout; commit with the separately approved plan on the implementation branch.

**Provenance:** The next-companion-increment request, read-only repository and operational inspection, four native clarification answers, and the Stage 1 proposal explicitly confirmed by the subsequent `approved` message. That approval authorized the DRAFT only. Sources include both READMEs, validation reports, and the five specification/plan pairs identified in the request. The DRAFT was subsequently presented in chat while Plan mode prohibited saving. The user's later `PLEASE IMPLEMENT THIS PLAN` message reproduced that specification and is acceptance of the artifact just presented: specification approval only under the user's mandatory separate-gate workflow. It does not approve an unseen implementation plan or authorize implementation. The approved content is preserved below; only lifecycle/storage/approval metadata changed when saved.

Artifact resolution before saving was **MISSING** for this specification and its matching future plan. No conflicting or legacy candidate was found. No implementation plan had been created at specification approval. The selected specification is now `docs/superpowers/specs/2026-11-13-companion-account-default-setup.md`; its separate plan must use the same basename.

## 1. Problem, current behavior and outcome

The wider direction is a companion with understandable accounts, defaults and project assignments. This increment delivers **account addition/import and explicit default selection**, building on existing inheritance. Project assignment editing remains a later increment.

The current router loads configuration at startup. Its managed channel changes only routing On/Off. In credential-routing mode, `globalCredential` verifies incoming Codex authentication, while default traffic retains that incoming credential. The global URL also participates in activation and direct recovery.

The current companion cannot create router configuration, provision Keychain items or designate another default.

Inspection verified clean `main` at `5acdcaf212e6bc3df3a75e9c554f55191f27a393`, matching actual remote `main`; merged PR #6 includes the completed increment. The selected normal configuration was Direct/restored, with no pending recovery or listener. These observations do not establish desktop-loaded settings.

**Desired outcome:** A user can create or import named accounts, explicitly designate a default, and start the router using that default. Saves occur after safe Stop; the next explicit Start applies them in routing Off.

This resolves whether native account creation works with the packaged credential reader, outgoing defaults can change independently of incoming authentication, and migration preserves routing and recovery.

## 2. Desired account and routing behavior

### Accounts and Keychain

Each account contains:

- A stable opaque identifier.
- A display name.
- A complete HTTPS API base prefix.
- An exact Keychain generic-password reference.

Bindings use account identifiers rather than display names. Names are trimmed, contain 1–80 characters without controls, and are unique case-insensitively within the selected configuration. Resolve import naming collisions in the preview. Separate accounts may deliberately share a pair; do not deduplicate automatically.

Retain existing URL validation: absolute HTTPS, no user information/query/fragment, and full API-prefix preservation. Retain existing credential-reference and token limits.

The account form offers concealed key entry or selection of an existing compatible item:

- Native Security APIs create new uniquely identified items compatible with the existing router reader.
- Existing-item selection reads metadata without revealing secrets and requires an exact, unambiguous supported reference.
- Do not overwrite, edit, delete or explicitly unlock existing items, bypass macOS consent, or grant access to all applications.
- Creation/access failures, duplicate matches and unsupported items remain visible.
- Item selection does not prove credential accessibility or gateway acceptance.

Entered keys remain in native memory, never command arguments, logs, JSON configuration or child-control messages. Discard form-held values on completion/cancellation; secure memory erasure is not promised.

Configuration loading, startup, health, status, activation and recovery retrieve no credentials, execute no desktop authentication helper and perform no destination preflight. Explicit metadata inspection and native item creation are setup operations. Routed requests retain bounded fresh credential reads without cross-request caching or automatic retries.

**Default designation is explicit**, including for the first account. Adding/importing an account never silently changes it. Choosing another default never changes explicit project assignments.

### Authentication and selection

Persist three independent facts: incoming verifier, outgoing default account and original direct destination.

- Credential-enabled migration retains the existing global credential as the incoming verifier.
- Legacy/fresh setup requires explicit confirmation of an item matching the unchanged desktop authentication source.
- Recognized helper metadata may suggest an unambiguous candidate. Never execute the helper or assume the outgoing default authenticates Codex.
- When helper output cannot be inferred, permit explicit matching-item selection/provision with honest unverified status. A mismatch rejects requests.

Every admitted non-health request verifies incoming authentication before metadata observation, identity resolution or outgoing-account selection.

| Request | Selected outgoing account |
|---|---|
| Routing Off | Default |
| Routing On, identified project without override | Default |
| Routing On, imported legacy inheritance label | Default |
| Routing On, explicit account override | Assigned account |
| Catalog or qualifying unassigned title | Default |

Outgoing authorization, destination, Host and complete prefix belong to the selected account. Do not accidentally forward the preserved desktop credential to a different default destination.

Missing explicit targets, unreadable/conflicting identity, inaccessible credentials and upstream failures remain failures. They never trigger inheritance, account fallback, model retries or redirects. Off deliberately suspends overrides without reading their credentials.

Retain existing request-mode capture before asynchronous work, immutable startup configuration, request-local pair selection, streaming/cancellation behavior and unchanged models, bodies and continuation identifiers.

**Restore direct returns to the preserved desktop connection**, which may differ from the router default. Default selection must not repurpose the original direct URL or rewrite desktop authentication.

The alternative coordinated design—changing desktop authentication and its direct destination with each default—was excluded by the native clarification answer.

## 3. Setup, migration, persistence and recovery

### First setup and incomplete setup

Without a complete explicit default or incoming verifier, show **Setup required**. Keep browsing and setup available; block new managed Start and activation.

A configured reference does not establish secret accessibility. Runtime credential failures remain distinct from incomplete setup.

When configuration is absent, setup may create it from an existing compatible active Codex provider under the existing provider-compatibility rules. Preserve its direct HTTPS prefix, Codex home, provider and authentication. Use empty project mappings, the existing default port and optional policies absent/default-off.

If the original direct connection cannot be established—for example, a loopback provider without valid recovery evidence—block creation visibly. Never guess, overwrite an existing/unavailable file or repair desktop authentication implicitly. Retain existing runtime selection; do not install Node.

Existing configurations remain readable for browsing and recovery. The companion requires explicit migration/default confirmation before a new managed start. Historical configuration/CLI serving behavior remains compatible.

### Import and migration

Import one explicitly selected configuration at a time; multi-source merging is excluded.

Show a preview of account names, the proposed default, preserved assignments and unresolved entries. Preserve:

- Existing aliases and exact mapping keys.
- Complete endpoint/key-reference pairs, including unused valid targets.
- Explicit overrides that happen to equal the old global pair.
- Optional-property presence/value and operational context.

Credential-enabled targets become named account bindings through their existing aliases. The old global pair becomes an account candidate; default confirmation remains explicit.

Legacy aliases remain labels with explicit inheritance semantics. They do not become manufactured account overrides.

An enabled alias without a target remains visibly unresolved and fails when selected On. It must never become legacy inheritance. Malformed, obsolete or conflicting sources reject without changes.

Create an exact private checkpoint before in-place migration. Keep activation records beside the configuration used for that activation. Discovery, selection and refresh never migrate automatically.

The new private representation must distinguish account identities, incoming verification, default selection, original direct destination, explicit bindings and imported legacy inheritance. Exact encoding and internal layout belong to the separately approved implementation plan.

### Save and apply

Before account/default/configuration writes or native credential creation, obtain fresh same-context evidence of:

- No owned child and an independently empty selected port.
- Direct provider settings.
- No unresolved recovery, unfinished/uncertain mutation or unsafe activation evidence.

First configuration creation must also respect saved conflicting contexts and existing recovery evidence. Routing Off is insufficient.

Where desktop dependency exists, complete the existing Restore direct, manual restart, working-direct-response confirmation and guarded Stop sequence first. Already-settled recovery does not require another gratuitous response check.

Forms may be browsed while routing runs, but this increment does not save pending configurations. The next explicit Start loads changes in Off. There is no general reload or control-channel expansion.

Use private owner-only storage, canonical containment, mutation coordination and atomic synced compare-before-replace writes. Preserve unsafe, corrupt or concurrently edited evidence rather than overwrite it. Do not promise atomicity against external editors.

Keychain creation and configuration persistence are separate operations. Retain private non-secret creation evidence sufficient to reconcile a created-but-unlinked item after failure or relaunch. Preserve prior configuration; offer explicit reconciliation/existing-item selection without blind creation retries or deletion.

### Recovery and presentation

Validated operational context and recovery records must remain usable independently of incomplete/invalid account setup. This must not weaken validation of operational evidence.

Preserve context binding, backups, pending journals, ownership, Stop/Quit authority, unknown/external-listener handling and manual recovery. No adoption, automatic restart, automatic activation or signalling a port occupant is added.

Everyday presentation leads with routing state/action, default account and understandable assignments. Keep setup and failures visible; put authentication references and technical details in Settings/Advanced.

## 4. Acceptance criteria

| ID | Verifiable outcome |
|---|---|
| **AC-01** | Add named accounts using a complete validated prefix and concealed key or existing-item selection. Stable identities, explicit first/different default selection and preserved assignments work without implicit designation. |
| **AC-02** | Native creation works with the packaged reader using a disposable private Keychain. Ambiguity, denial, collisions and cancellation remain visible; no existing-item modification, broad access grant or secret leakage occurs. |
| **AC-03** | Distinct synthetic incoming and outgoing credentials work across Off, On inheritance, catalog, qualifying titles and compaction. Invalid incoming authentication rejects before downstream work; explicit overrides retain their pairs. |
| **AC-04** | Migration preserves enabled pairs/mappings, unused targets, legacy inheritance labels and unresolved explicit targets. Malformed/obsolete sources reject without mutation or automatic default selection. |
| **AC-05** | First configuration creation works from a compatible provider. Incomplete setup permits browsing and recovery while blocking new Start/activation. Unsupported/conflicting sources remain unchanged. |
| **AC-06** | Fresh safe-save guards reject active listeners, pending recovery, uncertain operations and conflicting edits. No running configuration is changed/reloaded; the next explicit Start uses saved settings in Off. |
| **AC-07** | Keychain-success/configuration-failure and interruption/relaunch cases preserve old configuration and reconcile without duplicate creation, secret persistence or existing-item deletion. Private storage protections remain intact. |
| **AC-08** | Original direct recovery and custom activation contexts survive changed defaults, invalid/incomplete account setup and unavailable Keychain access. Preserve unrelated settings and existing Stop/Quit safeguards. |
| **AC-09** | Identity, missing-account, credential, credit/upstream, concurrency, transport and cancellation regressions retain failure/no-fallback behavior. Existing CLI compatibility remains. Configuration identity reflects routing configuration without credentials or credential hashes; mode-only changes remain independent. |
| **AC-10** | Native routing/default/assignment/setup/error/recovery controls are usable. Health and metadata selection do not imply gateway success. Preserve the accepted viewport/focus observations without silently implementing their fixes. |
| **AC-11** | Fresh Node/native/syntax/whitespace checks, signed build and three package tests with zero skips pass. Native setup observations and a bounded live check establish a different outgoing default with unchanged incoming authentication, preserved overrides, inheritance and exact operational recovery. |
| **AC-12** | Deliver documentation and sanitized validation evidence, complete the sole sequential specification then quality review, commit locally under the approved Git workflow, report results/limitations and stop before later increments, push or merge. |

Tests use synthetic credentials, controlled local destinations and disposable Keychain resources. The bounded live check uses user-sent prompts and manual restarts where required. Preserve checkpoints and unrelated changes, then verify direct recovery and stopped-listener state. Missing required observations remain pending.

## 5. Constraints, deferred work and approval handoff

Actual credentials, references, endpoints, mappings, checkpoints and raw runtime evidence remain outside Git. No operational credential retrieval is required for this specification.

Preserve historical evidence accurately: the predecessor’s visible same-chat sequence included an On request ending `499/CANCELLED`. Do not claim complete delivery for it, independent billing attribution or general cross-account/instance continuation.

Deferred work remains account editing/deletion, live assignment editing, hiding/reveal, multi-source merge, general reload, pending running changes, startup/supervision/adoption, distribution improvements, automatic desktop restart/prompts, comprehensive redesign and the two accepted viewport/focus follow-ups.

**Builder completeness check:** A fresh read-only reviewer returned **“nothing important left.”** This is neither specification approval nor the final implementation review.

**Execution endpoint:** Deliver only this account/default increment, complete verification/review and operational recovery, commit locally, report evidence and limitations, then stop before subsequent increments, push or merge.

**Current stage: Stage 4 — implementation authorized.** The specification was approved by the message reproducing it; the separately presented implementation plan was subsequently approved with `plan approved`. The user then selected Subagent-driven execution. Both artifacts are saved; push and merge remain unauthorized.
