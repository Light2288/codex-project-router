# Desktop project-identification validation report

Date: 2026-11-10. Outcome: **incomplete — desktop actions pending**.

## Environment

- Node.js 24.21.0; macOS local checkout.
- Observed desktop version 26.1029.61003, build 24614; engine 0.166.0-alpha.6.
- Private request headers and desktop-state structures are observed interfaces, not guaranteed stable APIs.

## Automated evidence

At the implementation checkpoint, `npm test` passed 65 tests with zero failures. Tests ran against synthetic temporary files/SQLite state and a local HTTPS upstream; they did not contact ICA or retrieve real credentials.

| Area | Observed result |
|---|---|
| Private configuration, assignment lookup, completed-agent ancestry | Pass |
| Changed assignments and bounded transient lookup recovery | Pass |
| Malformed/conflicting identity and unmapped/projectless admission | Pass |
| HTTP route/catalog boundary and diagnostic sentinel filtering | Pass |
| Concurrent requests, unchanged body/authentication, streamed content | Pass |
| TLS verification, disconnects, timeout, redirects without retries | Pass |
| Slow consumers and cancellation | Pass |
| Temporary-file activation, rollback, conflicts and interrupted state | Pass |
| CLI error privacy and loopback listener lifecycle | Pass |

The test-only certificate/key are synthetic localhost fixtures. Actual endpoint details, project mappings, and raw private run evidence are intentionally absent from this report.

A separate read-only check of the actual local desktop state resolved the controller chat to its configured alias. This used a locally constructed identity header; it did not capture an outgoing desktop request or contact ICA. A real configuration status check reported direct configuration with no proxy active.

The disposable projects have been verified by their scratch-folder paths and explicitly mapped in private configuration. A foreground proxy running in an independent Terminal passes its matching readiness check. At preflight, on-disk Codex configuration remained direct. The user subsequently confirmed both baseline responses and the activation helper changed only the provider base URL after matching readiness. The user restarted the desktop app. The resumed controller chat was explicitly identified and completed an actual proxy-to-ICA request with HTTP 200. Provider-wide catalog requests also completed with HTTP 200. The user then confirmed complete numbered responses from new chats in both disposable projects. Both requests resolved to the correct aliases and their intervals overlapped by 1.728 seconds. Initial completion diagnostics incorrectly labeled client stream closure as an upstream failure; a local HTTPS regression reproduced that classification bug and passed after cancellation was recorded before upstream teardown. The repeated new-chat test used 300 lines per chat. Both resolved correctly and overlapped by 5.427 seconds; the user confirmed completion. Both transport intervals ended with client cancellation (499), rather than an upstream failure. Two other request IDs were each rejected 17 times. Neither ID exists in saved chats, assignments, projectless markers, attached-parent relationships, or spawn edges. They cannot be safely attributed using the approved evidence sources. The desktop bundle implements auxiliary generation using ephemeral threads; that is a plausible origin, not a proven correlation for these requests.

## Actual desktop-to-ICA matrix

| Scenario | Result | Evidence |
|---|---|---|
| Direct baseline in disposable projects | Pass | User confirmed both direct baseline responses |
| Resumed controller chat after restart | Pass | Explicit controller alias; proxy completion HTTP 200 |
| Provider-wide model discovery | Pass | Catalog requests completed with HTTP 200 |
| First routed requests in both projects | Observed pass | Repeated with 300-line outputs; correct aliases and user-confirmed completion; client close classified 499 |
| Concurrent routed requests | Observed pass | Repeated intervals overlapped by 5.427 seconds; correct distinct aliases and user-confirmed completion |
| Follow-up and resumed chats | Observed pass | User confirmed both in the same Project A chat; same validated chat ID and `validation-a`; HTTP 200 for both |
| Forked chat | Observed pass | User confirmed branching; new chat ID directly assigned to `validation-a`; HTTP 200 |
| Project move | Observed pass | Same fork chat ID changed from `validation-a` to `validation-b` on its next request; HTTP 200; user confirmed output |
| `/compact` | Not run | Composer action observed in bundle; live action pending |
| Subagent attribution | Not run | Live delegation pending |
| Restoration and direct response after rollback | Not run | Proxy remains active; rollback and restart pending |

The provider base URL is currently set to the loopback proxy, with the original authentication helper preserved. A private rollback record and backup exist. The router does not independently retrieve credentials. End-to-end forwarding is observed for the controller chat; disposable-project lifecycle coverage and restoration remain unverified. Actual run diagnostics were checked for the fixed field allowlist, with no header or body fields.

## Sanitized concurrency intervals

The repeated run on 2026-11-10 recorded these UTC intervals. IDs and upstream details remain private.

| Alias | Started | Completed | Transport outcome |
|---|---|---|---|
| `validation-a` | 15:04:34.695 | 15:04:44.671 | Client close, 499; user confirmed complete output |
| `validation-b` | 15:04:39.244 | 15:04:50.745 | Client close, 499; user confirmed complete output |

Overlap: **5.427 seconds**. The initial run overlapped by 1.728 seconds.

## Live debugging checkpoint

The cancellation regression initially failed with `502` where a client cancellation required `499`. Upstream teardown synchronously emitted an abort before the cancellation outcome was recorded. Recording cancellation first corrected the result; the full suite then passed 65 tests. Rejected requests now retain a validated chat identifier in diagnostics, without raw headers or metadata, so missing desktop relationships can be investigated. The repeated run correlated 34 `STATE_UNAVAILABLE` rejections with two request IDs absent from every supported saved identity relationship. Blocking these requests is required; auxiliary generation remains unsupported where no durable relationship exists. Their exact originating desktop feature is unverified. The router itself introduced no retries; repeated rejected attempts came from the caller.

## Completion boundary

Missing desktop actions do not establish incompatibility. AC-03 through AC-05 and AC-10 require live evidence; automated checks alone cannot complete this increment. The final result must distinguish compatible, conclusively incompatible, and incomplete outcomes. Per-project key selection remains outside this increment.
