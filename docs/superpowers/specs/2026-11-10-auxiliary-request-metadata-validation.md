# Auxiliary request metadata validation

**Slug:** `auxiliary-request-metadata-validation`  
**Type:** feature  
**Status:** APPROVED  
**Created:** 2026-11-10  
**Updated:** 2026-11-10  
**Provenance:** Confirmed diagnostic-increment scope; subsequent interactive selection of an explicit validation mode, disabled by default. DRAFT specification approved by the user's “PLEASE IMPLEMENT THIS PLAN” message reproducing this specification after its presentation. That approval advanced the specification gate only. A later message reproducing the separately presented implementation plan approved that plan.

## 1. Problem and desired outcome

The wider goal is selecting API credentials according to each Codex chat’s assigned project.

The existing proxy identifies normal chats and saved subagents successfully. Some additional desktop requests use temporary identifiers with no saved project or parent relationship and are blocked.

Investigation strongly suggests automatic chat-title generation:

- Two title-generation timeouts closely follow the two rejected request sequences.
- Initial title generation creates temporary chats without passing the original chat ID.
- The engine contains additional feature and origin metadata fields that the current diagnostics do not capture.

The existing evidence cannot conclusively identify those requests or establish whether they carry usable origin information.

**This increment will collect narrowly limited metadata and repeat desktop validation to establish what is actually available.** It will produce working observation support, tests, documentation, and a sanitized findings report. Routing and credential selection remain unchanged.

Current baseline: clean `main` at `7305e09`, matching the remote; 68 tests passing; direct connection restored and proxy stopped.

## 2. Selected approach and configuration

Extend the existing Node.js 24 proxy with optional private configuration:

```json
{
  "observeRequestMetadata": true
}
```

- The setting is a strict boolean, defaulting to `false`.
- Existing configuration files remain valid under `schemaVersion: 1`.
- No new command or dependency is required.
- Restart the foreground proxy after changing the setting.
- Readiness checks distinguish enabled and disabled modes.
- Existing activation records and rollback remain usable; rollback does not require a matching observation mode or running proxy.

The user selected explicit observation over always collecting these additional fields. This preserves current logging behavior by default.

When enabled, observations are collected after the existing route/authentication admission check and before project resolution. They accompany diagnostics for both successful resolution and subsequent identity failures.

Requests rejected during initial admission—including duplicate identity headers already rejected there—retain their existing diagnostics without added observations. Health and catalog requests receive no additional identity observations.

## 3. Observation and privacy contract

Only the following inputs may supply new observations:

| Input | Allowed fields |
|---|---|
| Top-level `x-codex-turn-metadata` members | `thread_source`, `turn_trigger`, `request_kind`, `thread_id`, `session_id`, `parent_thread_id`, `forked_from_thread_id` |
| Individual request headers | `thread-id`, `session-id`, `x-codex-parent-thread-id` |

Feature values may be emitted only as these fixed labels:

`user`, `desktop_app`, `thread_title`, `thread_title_reconsideration`, `thread_description`, `thread_summary`, `compact`, `compaction`, `subagent`.

Unrecognized values produce a fixed `other` classification. Their original values must never be echoed, truncated, or hashed.

For each allowlisted field, fixed diagnostic states distinguish presence, JSON type, validity, duplication, conflict, unsupported shape, and collection failure. Only syntactically valid UUID identifier claims may be emitted. Each claim remains associated with its original field.

Important boundaries:

- **A claimed parent or fork source is not proof of project membership.** It must never become a routing fallback in this increment.
- Preserve separate fields when claims disagree; do not silently select one.
- Handle duplicate members, including escaped key spellings, without emitting an arbitrarily selected value.
- Unsupported structures produce a fixed diagnostic state; do not expand capture to inspect unknown nested fields.
- Malformed observation-only fields do not introduce new admission errors. Existing identity validation remains authoritative.
- Observation collection failures produce sanitized unavailable states and confer no routing authority.
- With observation disabled, none of the additional fields appear.

Prompts, responses, credentials, complete headers, raw metadata, arbitrary metadata keys, raw desktop state, and parser exception text remain excluded. Observations use the existing diagnostic stream and request correlation IDs.

## 4. Validation and acceptance criteria

Synthetic tests will verify the observation contract and compare enabled/disabled behavior. Live validation will use the existing disposable projects and controller mapping, verified before use.

The live run will establish a direct baseline, activate the observation-enabled proxy using existing safeguards, restart the desktop when required, and exercise new chats in both projects plus a follow-up control. Requests will be sent close enough together to distinguish concurrent request families.

Admitted requests retain the caller’s existing global credential. Previously unresolved requests remain blocked. Claimed source identifiers may be checked against saved desktop relationships read-only during evidence analysis.

A feature is confirmed only by observed supported metadata. Timing and matching title warnings alone remain supporting evidence, labelled as inference.

| ID | Acceptance criterion |
|---|---|
| **AC-01** | Existing configurations default observation off; explicit booleans are validated; readiness distinguishes modes; activation and recovery compatibility are preserved. |
| **AC-02** | Enabled diagnostics expose only allowlisted labels, fixed field states/types, and valid UUID claims, correlated with requests that passed initial admission—including later identity failures. Disabled mode omits these observations. |
| **AC-03** | Malformed, duplicate, escaped-key, conflicting, unknown, and unsupported inputs produce sanitized observations. Sentinel tests establish that prohibited content never reaches diagnostics or helper errors. |
| **AC-04** | Enabled/disabled integration tests preserve admission decisions, destination, status, authentication, body bytes, streaming, concurrency, and cancellation. Rejected requests make zero upstream model calls. New origin claims never select a project. |
| **AC-05** | Actual desktop validation covers fresh chats in both mapped projects and a follow-up control, distinguishing observed classifications, origin claims, absent fields, unsupported structures, and remaining uncertainty. |
| **AC-06** | A sanitized report records versions, observation mode, request intervals, classifications, and relationship evidence. Actual IDs, endpoints, mappings, and raw evidence remain outside Git. |
| **AC-07** | Restore the prior observation setting and original direct provider URL, perform the required desktop restart, verify a successful direct response, and stop the proxy. Preserve private recovery evidence. |
| **AC-08** | Documentation and a synthetic configuration example explain operation, privacy, blocking, and recovery. The full test suite and relevant checks pass, followed by sequential specification and quality review. |

An observed absence or unsupported metadata format is a valid diagnostic result. Missing user actions leave live validation incomplete.

## 5. Constraints, boundaries, and approval

Retain the current local macOS/Node.js 24 target, loopback binding, normal TLS verification, system CA support, and read-only desktop-state access.

The router must not infer projects from prompts, folders, foreground UI, nearby requests, or feature labels. Desktop assignments, SQLite state, and authentication helpers must remain untouched.

Deferred work includes:

- Background-request admission exceptions or a shared/global fallback.
- New parent/fork resolution rules.
- Desktop or engine modifications and new relationship registries.
- Project-based credentials, billing policy, GUI, and automatic startup.

The report will explain what the observed evidence permits and which decisions a later handling increment still requires. Later implementation remains provisional.

Design choices made by the author are the setting name, the explicit observation allowlist, and retaining existing diagnostics for early admission failures. Internal module names and output-field layout are left to implementation planning within this contract.

At DRAFT presentation, the specification and plan for this new slug were both **MISSING**. Both approved artifacts are now saved. The previous increment's approved artifacts remain unchanged. A fresh builder check identified the early-admission wording conflict, which this specification resolves.

**Execution endpoint:** deliver and review the opt-in diagnostics, complete controlled desktop evidence and its sanitized report, restore direct operation and the prior observation setting, and stop before admission exceptions or credential selection.

**Current stage:** Stage 4 — implementation.  
**Approval evidence:** Specification approval authorized planning only. The user subsequently approved the separately presented implementation plan in a later “PLEASE IMPLEMENT THIS PLAN” message reproducing that plan. Both approved artifacts are saved before product-code changes.
