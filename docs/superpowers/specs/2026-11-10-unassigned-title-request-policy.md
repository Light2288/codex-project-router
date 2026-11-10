# Unassigned title-request policy — specification

**Slug:** `unassigned-title-request-policy`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-10

**Updated:** 2026-11-10

**Provenance:** User selected the global-account approach through native clarification, then explicitly confirmed the proposed scope and design. The user separately approved the presented DRAFT specification in the message beginning “PLEASE IMPLEMENT THIS PLAN” and reproducing this specification. Saved after leaving Plan Mode; approval authorizes implementation planning only.

## 1. Problem and current behavior

The wider goal is selecting API credentials according to each Codex chat’s assigned project.

The proxy correctly identifies normal project chats and saved subagents. However, actual desktop validation revealed initial-title requests using temporary identifiers without saved project membership or ancestry. These requests are blocked.

Observed metadata for two such request families included:

- `thread_source` and `turn_trigger` both equal to `thread_title`.
- Matching header and metadata thread/session identifiers.
- No parent or fork-source claims.
- No saved assignment, projectless marker, thread row, or incoming or outgoing spawn relationship.

Each family produced 18 blocked attempts. This evidence supports a narrow exception for the observed pattern; it does not establish trustworthy project attribution.

The verified baseline is clean `main` at `f5621e2`, with 136 passing tests, direct provider operation restored, and the proxy stopped.

## 2. Desired outcome and selected approach

Allow qualifying unassigned initial-title requests through the existing upstream using the caller’s existing credential, without attributing them to a project.

The selected increment includes configuration, admission safeguards, private diagnostics, tests, documentation, controlled desktop validation, recovery, and sequential review.

Three approaches were considered:

| Approach | Tradeoff |
|---|---|
| Keep all unresolved requests blocked | Preserves current behavior but prevents the observed automatic-title requests from completing. |
| **Selected: narrow opt-in title exception** | Supports the observed pattern while explicitly accepting unattributed use of the existing credential. |
| General unresolved-request fallback | Would admit unrelated request families and weaken the project boundary; excluded. |

“Global account” means forwarding the credential already supplied by the caller. The router does not verify account identity or calculate billing attribution.

Client-supplied title markers can be imitated by a local caller possessing an accepted credential. Enabling this policy accepts that limitation. The router does not prove that the request body generates a title, and it must not inspect content to attempt that proof.

## 3. Configuration and compatibility

Add one optional private configuration property:

```json
{
  "allowUnassignedThreadTitles": true
}
```

- Accept only a strict boolean; default to `false`.
- Retain `schemaVersion: 1` and compatibility with existing configuration files.
- Omitted and explicit `false` are equivalent.
- Preserve the existing disabled-policy readiness fingerprint; enabling the policy changes it.
- Readiness must distinguish both this policy and the existing observation mode.
- Restart the foreground proxy after changing the setting.
- Add no dependency or CLI command.

The policy is independent of `observeRequestMetadata`. It works when observation is disabled and does not enable additional metadata logging.

Existing activation records remain usable. Status, interrupted-activation recovery, and offline rollback retain their current interfaces. Rollback requires neither a running proxy nor matching policy or observation modes.

## 4. Eligibility and decision precedence

Existing route and authentication admission remains first and authoritative. Normal successful project resolution takes priority.

The exception applies only to admitted `POST /v1/responses` requests, including query strings already permitted by admission. It never applies to compaction, catalog, health, other routes or methods, upgrades, or initial admission failures.

A request qualifies only when **all** conditions below hold.

### Exact request pattern

1. Exactly one `x-codex-turn-metadata` header contains a valid JSON object.
2. Its top-level singleton string members satisfy:
   - `thread_source === "thread_title"`
   - `turn_trigger === "thread_title"`
3. All four claims are present, singleton, syntactically valid UUIDs, and equal after normalization:
   - Header `thread-id`
   - Header `session-id`
   - Metadata `thread_id`
   - Metadata `session_id`
4. These origin fields are absent:
   - Header `x-codex-parent-thread-id`
   - Metadata `parent_thread_id`
   - Metadata `forked_from_thread_id`

A present null, empty, malformed, or unsupported origin value does not count as absence.

Duplicate occurrences of any of the seven existing allowlisted metadata members disqualify the exception, including equivalent escaped key spellings. Duplicate parent headers also disqualify it. No occurrence may win arbitrarily.

Nested lookalikes and field-like string contents cannot satisfy these requirements. Unknown properties are ignored and remain uncaptured. `request_kind` remains observation-only and cannot authorize or broaden the exception.

Failure to match this pattern denies the exception only. It introduces no additional rejection for an otherwise ordinarily resolvable request.

### Positive evidence of unassigned identity

Fresh, successful read-only access to the required desktop JSON and SQLite state must establish that the temporary identifier has none of the following:

- An assignment entry, including a malformed entry.
- A projectless marker.
- A saved `threads` row.
- An incoming or outgoing `thread_spawn_edges` row.

Required structures and database schema must be usable. A known assignment, unmapped project, projectless identity, saved thread, or relationship cannot be converted into unattributed forwarding.

`STATE_UNAVAILABLE` alone is insufficient: it currently covers both missing relationships and failed state reads. The implementation must distinguish proven absence from inability to establish membership.

Missing, partial, unreadable, unsupported, or conflicting state; detected changes during checking; and cancellation cannot authorize the exception. Transient failures may recover within the existing one-second lookup budget and 50 ms retry cadence. Ordinary resolution and exception checks share that budget; there is no additional lookup window.

Authorization requires a final successful absence check. A prior healthy result cannot authorize forwarding after a later failed check.

State is reread per request, and a successful decision is frozen for that request. Subsequent requests reflect later assignments or relationships. These are checks against current readable snapshots, not an atomic transaction across JSON and SQLite.

With the policy disabled, existing admission, resolution, forwarding decisions, and diagnostics remain unchanged.

## 5. Forwarding and diagnostics

Qualifying requests use the existing forwarding path:

- Same configured upstream and caller credential.
- Unchanged body bytes and permitted forwarded headers and queries.
- Existing response status, content, streaming, backpressure, concurrency, cancellation, and inactivity handling.
- Normal TLS verification and system CA support.
- No new upstream retries or redirect following.

The router must not invoke Keychain, retrieve another credential, replace authentication, or persist credentials.

Requests actually admitted through the exception receive the fixed diagnostic source:

```text
source: unassigned_title
```

They retain existing request correlation, temporary thread identity, operation, status, timing, and fixed error diagnostics. They omit `projectId`, `ownerThreadId`, and `routeAlias`. No synthetic project or global route alias is introduced.

Rejected candidates must not be recorded as admitted titles.

Existing optional `requestMetadata` observations retain their current schema and sanitization. They remain absent when observation is disabled.

Prompts, responses, credentials, complete headers, raw metadata, raw desktop state, and parser exception text remain excluded. Actual identifiers, endpoints, mappings, backups, and raw validation evidence stay outside Git.

## 6. Acceptance criteria

| ID | Criterion |
|---|---|
| **AC-01** | The optional setting defaults off, accepts only booleans, preserves disabled compatibility, works independently of observation, changes readiness when enabled, and preserves activation and offline recovery compatibility. |
| **AC-02** | Only the exact initial-title pattern qualifies. Missing, malformed, unsupported, duplicate, escaped-duplicate, conflicting, or origin-bearing claims cannot bypass the requirements. Ordinary mapped resolution has priority. |
| **AC-03** | Fresh healthy state positively establishes absence. Known records, unusable schema, unavailable state, conflicts, and cancellation fail closed. Transient recovery and between-request changes are handled within the existing budget without desktop-state writes. |
| **AC-04** | Forwarding preserves destination, caller authentication, bytes, streaming, concurrency, and cancellation. Rejected requests make zero upstream model calls. No credential retrieval, new retry behavior, or redirect following is introduced. |
| **AC-05** | Admitted exceptions have distinct, sanitized unattributed diagnostics with no fabricated ownership. Observation remains independently optional. Sentinel tests exclude prohibited content, and disabled behavior retains parity. |
| **AC-06** | Actual desktop validation covers fresh chats in both disposable projects, visible automatic titles, overlapping request intervals, and a same-chat follow-up. Main requests remain project-attributed; exception requests remain unattributed. Recognizing a label alone does not establish successful title generation. |
| **AC-07** | A sanitized report records versions, modes, symbolic request families, intervals, outcomes, visible-title confirmation, failures, and limitations. Cases are classified as observed pass, observed failure, or not run. Missing user actions leave validation incomplete. |
| **AC-08** | Restore the original provider URL and exact prior presence/value of both policy and observation settings, preserving unrelated edits and private recovery evidence. Complete the required desktop restart, verify a direct response, stop the proxy, and confirm no listener remains. |
| **AC-09** | Documentation and a synthetic example explain operation, unattributed credential use, trust limitations, blocking, and recovery. Installation, tests, syntax and whitespace checks pass, followed by sequential specification and quality review and resolution of actionable findings. |

## 7. Verification and desktop validation

Synthetic verification must include:

- Exact eligible requests across policy on/off and observation on/off.
- Duplicate and escaped metadata keys, nested lookalikes, invalid types, missing claims, and conflicting UUIDs.
- Forged title markers on mapped, unmapped, projectless, saved-thread, and orphan-edge identities.
- Missing required schema, partial state, cancellation, transient recovery, and a healthy probe followed by an unavailable final check.
- Assignment or relationship changes between requests.
- Overlapping requests with distinct authentication sentinels, streaming and disconnects.
- Zero upstream calls for rejected candidates and sanitized diagnostics throughout.

Synthetic SQLite fixtures may gain the required `threads` table. Production desktop state must not be migrated or modified.

Live validation will use the existing disposable Project A, Project B, and controller mappings after read-only verification:

1. Confirm direct operation and establish fresh direct baselines, including automatic titles.
2. Preserve the original URL and exact prior settings in restrictive private recovery evidence.
3. Enable the policy, start and activate the proxy through existing safeguards, and obtain the required desktop restart.
4. Have the user send fresh requests in different projects close together, confirm visible automatic titles, and send a follow-up in one of those chats.
5. Correlate main and title request families using sanitized intervals and diagnostics. Observation may temporarily be enabled for evidence.
6. Restore direct operation and prior settings, obtain the required restart and successful direct response, then stop the proxy.

Do not create or message other chats through coordination tools without explicit authorization.

An observed incompatibility may conclude validation as a failed capability after in-scope fixes and review. Missing user actions do not establish incompatibility. No failed test may be resolved by guessing project membership or broadening the exception.

Required checks are `npm ci`, `npm test`, `node --check src/cli.js`, and `git diff --check`, followed by `personal-workflows:code-review` in specification-then-quality order.

## 8. Constraints, deferred work, and handoff

Retain the current macOS/Node.js 24 target, loopback binding, normal TLS verification, system CA support, read-only desktop-state access, and existing activation and rollback safeguards.

Work in the existing checkout. No main update, implementation branch, or product changes occur before separate specification and plan approvals. Push and merge remain unauthorized.

Deferred capabilities include per-project credentials, billing attribution, title reconsideration, other auxiliary families, general unresolved fallbacks, new origin-based project resolution, content inspection, engine changes, relationship registries, GUI, and automatic startup.

The setting name, exact eligibility rules, absence requirements, and diagnostic source are proposed design choices. Internal module organization, helper interfaces, and the mechanism for establishing fresh absence belong to implementation planning.

**Execution endpoint:** Deliver and review the narrow opt-in title policy, complete desktop validation and its sanitized report, restore direct operation and prior settings, stop the proxy, and stop before credential selection or additional background-request policies.

**Approval record:** Scope/design was confirmed by the user’s “confirmed” message before the DRAFT presentation. The user separately approved this specification by reproducing it in the subsequent “PLEASE IMPLEMENT THIS PLAN” message. The separate implementation plan was subsequently presented and approved by the user’s “approved” message. Current workflow stage: Stage 4 — implementation authorized.
