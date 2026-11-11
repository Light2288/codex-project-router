# Project credential routing validation

Date: 2026-11-11. Status: **renewed user-visible cases observed; exact recovery complete; transport limitations and final review pending**.

The optional mode verifies each admitted caller against a fresh global Keychain credential, then selects the resolved route's explicit credential and full HTTPS API base URL together for model requests. Catalog requests and qualifying unassigned titles retain the verified caller authorization and global destination. Synthetic evidence establishes exact local credential/destination selection and transport behavior. Live observations do not independently establish gateway account or billing attribution.

## Synthetic evidence

- Baseline: `cd58067`, 259 passing tests. Tasks 1–4: 584 passing tests at `04fe73d`; each task passed its specification and quality review.
- Configuration coverage includes strict references, own-property alias lookup, deep freezing, canonical enabled fingerprints and unchanged historical legacy fingerprints.
- Reader coverage includes exact process arguments, byte validation, five-second timeout, independent 16 KiB output limits, failed process outcomes, cancellation and real synthetic-child termination/reaping.
- HTTPS integration covers exact authorization for Responses and compaction, ancestry, shared references, fresh rotation/deletion, project movement, overlapping streams, title/catalog exceptions and all credential/observation/title mode combinations.
- Transport coverage includes streaming, slow consumers, TLS verification, cancellation, inactivity, upstream failure, redirects without retries and authorization named by `Connection`.
- Tests use synthetic credentials and local HTTPS only. They never retrieve actual Keychain credentials or contact the external gateway.
- Task 5 automated checks: `npm test` exit 0, 586/586 passing, no failed/cancelled/skipped/todo tests; `node --test test/activation.test.js test/cli.test.js` exit 0, 42/42 passing. `node --check src/cli.js` and `git diff --check` exited 0. Control tests verify no credential retrieval for startup, health, status, activation and rollback, including offline recovery and preserved unrelated settings.
- Task 6 replaced the unmerged key-only format with explicit credential/URL targets, including complete API prefixes, Host selection, schema rejection, legacy fingerprint compatibility and zero credential/destination preflight for controls. Task 6 review passed and included the original Task 5 automation/documentation obligation.
- Task 7 review passed at `23eb915`: 643/643 tests, no failed/cancelled/skipped/todo tests. Separate HTTPS origins verify exact URL/key/body/Host selection, pending-lookup and active-stream snapshots across reassignment, simultaneous A/B/controller/title streams, independent target failures and no fallback or redirect following. Rotation, deletion and real synthetic-child cancellation/reaping remain covered. No production change was required for Task 7.

## Historical failed desktop run

Actual references, mappings, identifiers, endpoints, settings checkpoints and runtime diagnostics remain outside Git in owner-only storage. Only symbolic labels and sanitized outcomes are recorded here. This first run used the earlier single-upstream design; its failures and recovery remain historical evidence and are not reclassified by the renewed run.

| Case | Classification | Evidence |
|---|---|---|
| Direct fresh Project A response and automatic title | Observed pass | User confirmed both; no content retained |
| Direct fresh Project B response and automatic title | Observed pass | User confirmed both; no content retained |
| Private checkpoint and explicit A/B/controller references | Prepared | Exact prior router/provider files and optional-property presence retained privately; all mapped aliases have references |
| Separate-Terminal startup and readiness while direct | Observed pass | Proxy alive; status direct, matching readiness, no recovery required; no model traffic before activation |
| Activation preserving provider settings | Observed pass | Existing CLI reports active, matching readiness and restart required; parsed settings match both preactivation backup and initial checkpoint except for the intended base URL |
| Proxied controller after restart | Observed pass with cancellation retained | User returned controller-ready confirmation; request selected controller route and reached forwarding, then recorded 499/CANCELLED. Complete upstream delivery is not claimed |
| Initial A/B credential-access attempts | Observed failure | User reported permission difficulties; A/B lookups repeatedly failed with 503/CREDENTIAL_UNAVAILABLE after approximately five seconds before forwarding. Global/controller and eligible-title requests succeeded |
| Subsequent bounded project-item access check | Observed pass | One private lookup per project returned a valid credential in 28/25 ms; no values, hashes, prefixes or references retained. This verifies local access, not gateway acceptance. Earlier failures remain recorded |
| Proxied fresh A/B responses and automatic titles | Observed failure for responses; title visibility unconfirmed | Both routes reached forwarding; 12 attempts per route returned upstream HTTP 401. User reported gateway token rejection for both keys. Eligible-title transport separately returned HTTP 200 using global authorization; visible title success is not claimed |
| Overlapping A/B requests | Rejected requests overlapped; successful overlap not established | A/B forwarding intervals overlap, but gateway rejection prevents successful concurrent credential validation |
| Same-chat follow-up | Not run after gateway rejection | Successful credential lifecycle remains unvalidated live in this run |
| Reassignment and subsequent credential selection | Not run after gateway rejection | Synthetic snapshot/reassignment coverage remains; live capability is not established in this run |
| Live fork, saved subagent and dedicated compaction | Not run | Opportunistic live cases; synthetic credential coverage required and retained |
| Exact settings restoration | Observed pass | Rollback restored the direct URL; router/provider files match the initial checkpoint byte for byte, including omitted options |
| Recovery restart, direct response and stopped listener | Observed pass | User confirmed a working direct response after restart; exact router/provider bytes verified, recorded validation process stopped, and independent listener check found none. Status direct, proxy not ready, no recovery required |

Both selected project credentials were rejected by the gateway used for that run. Local key retrieval and route selection succeeded. The user subsequently identified a separate gateway instance and API prefix for the project keys; the original implementation had sent them to the global instance. At that point, acceptance by the intended instance was untested and AC-09 was failed/incomplete. The separately approved amendment added explicit credential/destination pairs; Tasks 6–7 implemented and reviewed it before the renewed run below. No credential fallback, payload repair or automatic router retry was introduced. Gateway error-body fragments remain excluded.

## Renewed desktop run — 2026-11-11

The controller prepared a new owner-only checkpoint with exact prior provider/router bytes and optional-property presence, separate from the failed run. Existing Keychain items were reused without changing their values. Private configuration selected explicit A/B targets at the project gateway and the controller's target at the global gateway, using the supplied full API prefixes. A/B use distinct project keys at the same project gateway. No credential preflight was performed; the bounded reader's timeout was unchanged.

### Required preactivation checks

These checks ran at `23eb915` before renewed activation. The controller retained and inspected their logs; no warning/error markers were found.

| Command | Exit | Decisive result |
|---|---|---|
| `npm test` | 0 | 643 tests, 643 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo; `duration_ms 45551.922333` |
| `node --check src/cli.js` | 0 | Empty output |
| `git diff --check` | 0 | Empty output |

These are preactivation checks, not the later fresh final-branch checks required after task review.

### User-visible cases and activation

| Case | Classification | Evidence |
|---|---|---|
| Fresh direct A/B baselines | User-confirmed pass | Both projects produced a response and automatic title before activation |
| Separate-Terminal serve/status/activate | Observed pass | Matching readiness verified before and after activation; only the intended provider URL changed; user restarted the desktop |
| Controller on the global target | User-confirmed pass; transport 200 | Controller operation confirmed after restart; interval recorded below |
| Catalog on the global target | Transport 200 | Catalog traffic completed successfully |
| Fresh proxied A/B responses | User-confirmed pass; transport cancelled | User confirmed both complete visible responses, counts reaching 200 and no visible errors; both model requests recorded 499/CANCELLED |
| Automatic titles | User-confirmed pass; mixed transport | User confirmed both titles visible; one eligible title completed 200 and another recorded 499/CANCELLED. Timing does not identify either title's originating project |
| A/B overlap | User-confirmed overlap; forwarding overlap observed | Forwarding intervals overlap for 3781 ms (3.781 s); both model requests retain 499/CANCELLED outcomes |
| Same-chat follow-up in A | User-confirmed pass; transport cancelled | Private identity matching verified the same thread and route `validation-a`; request recorded 499/CANCELLED |
| Move A → B and subsequent response | User-confirmed pass; transport cancelled | User confirmed the move and response; private identity matching verified the same thread, new project and route sequence `validation-a` → `validation-a` → `validation-b`; moved request recorded 499/CANCELLED |
| Live fork, saved subagent and dedicated compaction | Not run live | Required synthetic coverage retained |
| Real key rotation, deletion and failure cases | Synthetic only | Existing real keys were unchanged |

### Sanitized transport intervals

Diagnostic start/completion timestamp intervals exclude preceding lookup work; `elapsedMs` includes it. Timestamps are UTC. These are the actual initiating outcomes, including client cancellations; a visible response is not evidence of complete HTTP stream delivery.

| Request | Route / source | Started | Completed | Status | elapsedMs |
|---|---|---|---|---|---|
| Controller | Explicit controller/global target | `2026-11-11T01:48:04.708Z` | `2026-11-11T01:48:11.909Z` | 200 | 7260.420457999993 |
| Fresh A | `validation-a` / `direct` | `2026-11-11T01:48:39.118Z` | `2026-11-11T01:48:45.831Z` | 499/CANCELLED | 6778.064459000001 |
| Eligible title 1 | `unassigned_title` / `unassigned_title` | `2026-11-11T01:48:39.775Z` | `2026-11-11T01:48:42.237Z` | 200 | 2510.639500000005 |
| Fresh B | `validation-b` / `direct` | `2026-11-11T01:48:42.050Z` | `2026-11-11T01:48:47.078Z` | 499/CANCELLED | 5103.366834 |
| Eligible title 2 | `unassigned_title` / `unassigned_title` | `2026-11-11T01:48:42.640Z` | `2026-11-11T01:48:46.050Z` | 499/CANCELLED | 3448.129958000005 |
| Follow-up in A | `validation-a` / `direct` | `2026-11-11T01:49:47.710Z` | `2026-11-11T01:49:49.204Z` | 499/CANCELLED | 1557.0069580000127 |
| Same chat after move to B | `validation-b` / `direct` | `2026-11-11T01:51:15.666Z` | `2026-11-11T01:51:18.028Z` | 499/CANCELLED | 2445.0941250000033 |

The A/B forwarding overlap runs from `2026-11-11T01:48:42.050Z` to `2026-11-11T01:48:45.831Z`. All four mapped A/B model requests ended with initiating client 499/CANCELLED despite the confirmed complete visible responses. The evidence does not establish why the desktop closed the streams, complete HTTP stream delivery, independent gateway billing/account attribution or accepted cross-instance continuation behavior. A/B share the project gateway, so the successful moved-chat observation does not test continuation across gateway instances. Client-close classification alone demonstrated no new code defect or compatibility failure; no fix, fallback, retry or payload rewrite was applied.

### Exact recovery

Rollback exited 0 with `state: direct`, `changed: true` and `restartRequired: true`. The controller verified exact initial provider/router bytes and optional-property absence were restored while preserving unrelated settings. The user restarted and confirmed direct readiness and a working direct response. Only after that confirmation, the positively identified recorded proxy was stopped with SIGTERM. Independent `lsof` found no listener. Postrecovery status was `state: direct`, `proxyReady: false`, `recoveryRequired: false`. No restart, direct-response or listener-stop action remains pending. Private checkpoints and evidence remain outside Git; Keychain items remain unchanged.

## Acceptance and remaining review

The renewed evidence records every required user-visible AC-09 action and exact recovery, with cancelled model transport outcomes and unproven complete stream delivery retained for acceptance review. It does not relabel the historical failed run or claim an unqualified transport pass. Live fork, saved-subagent and dedicated-compaction cases remain explicitly unrun; their required synthetic coverage is retained.

Task 8 documentation review, fresh final `npm test`, `node --check src/cli.js`, `git diff --check` and the sole integrated sequential specification/quality whole-branch gate remain pending. AC-08 and overall increment completion cannot be claimed before those gates and their actionable dispositions. AC-09 acceptance remains subject to review of the qualified live evidence above. Push and merge remain unauthorized.
