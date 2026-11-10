# Auxiliary request metadata validation

**Date:** 2026-11-10  
**Status:** Desktop validation complete  
**Observation mode:** Enabled only for the controlled run; the prior setting was restored afterward.  
**Credential behavior:** Every admitted request used the caller's existing global credential. No credential selection or admission exception was added.

## Result

Two previously unresolved request families explicitly reported `thread_source=thread_title` and `turn_trigger=thread_title`. This confirms title-generation traffic in this run. Both families used temporary identifiers with no saved project assignment or incoming parent relationship. None of the observed parent or fork-source fields supplied an origin claim.

All 36 title requests remained blocked before forwarding with `STATE_UNAVAILABLE` (HTTP 503). The desktop made 18 attempts for each temporary identifier; the router introduced no upstream retries. The feature label does not establish project membership, and neither title family can be assigned to a particular test chat from this evidence.

The title-generation explanation for the previous run remains a historical inference because that run did not capture these classifications. The current run directly demonstrates the same unresolved-request pattern with supported title labels.

## Environment and synthetic checks

| Component | Observed version |
|---|---|
| Node.js | `24.21.0` |
| Desktop | `26.1103.60933`, build `25894` |
| Bundled engine | `0.167.0-alpha.3.2` |

The desktop and engine versions differ from the previous validation run. Before activation, `npm ci` succeeded, `npm test` passed 136 tests, and `node --check src/cli.js` and `git diff --check` succeeded. Tests cover privacy sentinels, escaped duplicates, unsupported values, readiness and offline recovery, and admission/forwarding/streaming/concurrency/cancellation with observation enabled and disabled.

## Live validation

The configured aliases `validation-a`, `validation-b`, and `controller` were verified against the saved project catalog before activation. The user confirmed direct responses in fresh chats in both disposable projects. After activation and the required desktop restart, this controller chat reached the observation-enabled proxy.

| Case | Result | Evidence |
|---|---|---|
| Direct baseline in both projects | Observed pass | User confirmed both responses before activation |
| Fresh Project A chat | Observed pass for identity, observation, and displayed response | Correct `validation-a` assignment; user confirmed the full numbered response; transport cancellation noted below |
| Fresh Project B chat | Observed pass | Correct `validation-b` assignment; HTTP 200; user confirmed the full numbered response |
| Concurrent first requests | Observed pass | A and B intervals overlapped by 2.578 seconds |
| Follow-up in the same Project A chat | Observed pass | Correct unchanged assignment, HTTP 200, and user-confirmed response |
| Auxiliary classification | Observed pass | Both temporary families reported supported `thread_title` source and trigger labels |
| Origin-information assessment | Observed pass; no usable origin found | Parent/fork fields absent; saved relationships absent for the temporary identifiers |
| Recovery | Observed pass | Original direct URL and prior observation omission restored; user restarted and confirmed a direct response; proxy stopped |

All intervals below are UTC on 2026-11-10. Labels are symbolic and contain no actual identifiers. Main-request intervals use correlated start/completion events; rejected-family bounds use completion timestamps and elapsed durations.

| Request/family | Start | End | Transport outcome |
|---|---|---|---|
| A first request | 17:51:58.927Z | 17:52:05.464Z | 499 `CANCELLED` after a user-confirmed full displayed response |
| B first request | 17:52:02.886Z | 17:52:09.411Z | 200 |
| A follow-up | 17:53:35.846Z | 17:53:38.428Z | 200 |
| Title 1: 18 requests | 17:51:59.408Z | 17:52:28.168Z | 18 × 503 `STATE_UNAVAILABLE` |
| Title 2: 18 requests | 17:52:03.269Z | 17:52:32.444Z | 18 × 503 `STATE_UNAVAILABLE` |

Project A's first stream closed on the client side, so the existing transport diagnostic recorded 499 rather than a normal completed status. The user explicitly confirmed that both lists completed fully. This report preserves both observations; the precise reason for that stream closure was not established, and no transport behavior was changed.

## Observed fields and relationship evidence

| Input | Main chats and follow-up | Title families |
|---|---|---|
| Metadata container | Present object | Present object |
| `thread_source` | `user` | `thread_title` |
| `turn_trigger` | `other` | `thread_title` |
| `request_kind` | `other` | `other` |
| Header and metadata thread/session claims | Valid UUIDs; corresponding fields agree on the saved chat | Valid UUIDs; corresponding fields agree on that family's temporary identifier |
| `x-codex-parent-thread-id` | Absent | Absent |
| Metadata `parent_thread_id` | Absent | Absent |
| Metadata `forked_from_thread_id` | Absent | Absent |

`other` is a fixed classification; its underlying value was not recorded or recovered. No malformed, duplicate, conflicting, unavailable, or unsupported allowlisted structures were observed in these test families. Such cases are covered by synthetic tests. Unknown keys and nested structures were not expanded or captured.

Read-only desktop-state and SQLite checks found the expected explicit assignments and saved thread rows for both main chats. For neither temporary title identifier was there a saved thread row, explicit project assignment, projectless marker, or incoming `thread_spawn_edges` parent edge. The observed claims therefore provide no proven link from a title request to a mapped project. Timing proximity is insufficient to create that link.

## Recovery and privacy

Rollback restored the exact original provider URL. The observation property was originally absent and was removed again, preserving default-off behavior and unrelated configuration. The user fully restarted the desktop and confirmed a direct response in the same Project A test chat. That recovery request did not appear in the proxy's disposable-project request records.

After direct verification, the saved proxy process was stopped. The final checks returned `state=direct`, `proxyReady=false`, `recoveryRequired=false`, and no listener on the proxy port. Private checkpoints, configuration backups, activation recovery records, sanitized diagnostic events containing permitted IDs, and relationship evidence remain outside Git with restrictive permissions.

No prompts, responses, credentials, complete headers, raw metadata, parser exception text, or raw desktop state were captured in router diagnostics. This report contains no actual IDs, endpoints, or private mappings.

## Implications

The increment resolves the feature-identification uncertainty for the observed title requests. It does not establish project attribution for them. A later approved increment must decide how unassigned title traffic should be handled; the observed feature label alone cannot safely select a project's credential.

Unresolved requests remain blocked. Background-request exceptions, new identity fallbacks, shared/global routing policy, and project-based credentials remain deferred. These findings are limited to the recorded versions, allowed fields, and inspected saved relationships.
