# Project credential routing validation

Date: 2026-11-11. Status: **live project-key validation failed — recovery complete; design amendment and final review pending**.

The optional mode verifies each admitted caller against a fresh global Keychain credential, then selects the resolved route's credential for model requests. Catalog requests and qualifying unassigned titles retain the verified caller authorization. This establishes local credential selection and transport behavior; it does not independently establish gateway account or billing attribution.

## Synthetic evidence

- Baseline: `cd58067`, 259 passing tests. Tasks 1–4: 584 passing tests at `04fe73d`; each task passed its specification and quality review.
- Configuration coverage includes strict references, own-property alias lookup, deep freezing, canonical enabled fingerprints and unchanged historical legacy fingerprints.
- Reader coverage includes exact process arguments, byte validation, five-second timeout, independent 16 KiB output limits, failed process outcomes, cancellation and real synthetic-child termination/reaping.
- HTTPS integration covers exact authorization for Responses and compaction, ancestry, shared references, fresh rotation/deletion, project movement, overlapping streams, title/catalog exceptions and all credential/observation/title mode combinations.
- Transport coverage includes streaming, slow consumers, TLS verification, cancellation, inactivity, upstream failure, redirects without retries and authorization named by `Connection`.
- Tests use synthetic credentials and local HTTPS only. They never retrieve actual Keychain credentials or contact the external gateway.
- Task 5 automated checks: `npm test` exit 0, 586/586 passing, no failed/cancelled/skipped/todo tests; `node --test test/activation.test.js test/cli.test.js` exit 0, 42/42 passing. `node --check src/cli.js` and `git diff --check` exited 0. Control tests verify no credential retrieval for startup, health, status, activation and rollback, including offline recovery and preserved unrelated settings. Final branch checks remain pending.

## Desktop cases

Actual references, mappings, identifiers, endpoints, settings checkpoints and runtime diagnostics remain outside Git in owner-only storage. Only symbolic labels and sanitized outcomes are recorded here.

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
| Same-chat follow-up | Not run after gateway rejection | Successful credential lifecycle remains unvalidated live |
| Reassignment and subsequent credential selection | Not run after gateway rejection | Synthetic snapshot/reassignment coverage remains; live capability is not established |
| Live fork, saved subagent and dedicated compaction | Not run | Opportunistic live cases; synthetic credential coverage required and retained |
| Exact settings restoration | Observed pass | Rollback restored the direct URL; router/provider files match the initial checkpoint byte for byte, including omitted options |
| Recovery restart, direct response and stopped listener | Observed pass | User confirmed a working direct response after restart; exact router/provider bytes verified, recorded validation process stopped, and independent listener check found none. Status direct, proxy not ready, no recovery required |

Diagnostic start/completion timestamp intervals exclude preceding lookup work; `elapsedMs` includes it. Visible responses do not prove complete stream delivery: cancellation and upstream failures must retain their observed outcomes. An unassigned title's timing does not establish its originating project.

## Recovery and final review

Recovery is complete: exact prior settings, direct URL and omitted properties were restored, the user confirmed a direct response after restart, and the recorded validation listener was stopped. An independent listener check found none; status reports direct operation and no recovery required. Keychain items remain unchanged.

Both selected project credentials were rejected by the existing gateway. Local key retrieval and route selection succeeded. The user subsequently identified a separate gateway instance and API prefix for the project keys. The approved single-upstream implementation sent them to the global instance; acceptance by their intended instance remains untested. Actual endpoints remain private. Supporting per-route destinations requires a material design/specification/plan amendment. No endpoint change, credential fallback, payload repair or automatic router retry was introduced. Gateway error-body fragments are excluded from this report.

AC-09 is failed/incomplete. Successful live project responses, follow-up and reassignment cannot be represented as supported. The increment is incomplete, and the sole integrated sequential specification/quality gate has not been invoked. Push and merge remain unauthorized.
