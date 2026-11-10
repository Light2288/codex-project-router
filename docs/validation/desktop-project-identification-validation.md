# Desktop project-identification validation report

Date: 2026-11-10. Outcome: **incomplete — desktop actions pending**.

## Environment

- Node.js 24.21.0; macOS local checkout.
- Observed desktop version 26.1029.61003, build 24614; engine 0.166.0-alpha.6.
- Private request headers and desktop-state structures are observed interfaces, not guaranteed stable APIs.

## Automated evidence

At the implementation checkpoint, `npm test` passed 64 tests with zero failures. Tests ran against synthetic temporary files/SQLite state and a local HTTPS upstream; they did not contact ICA or retrieve real credentials.

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

The disposable projects have been verified by their scratch-folder paths and explicitly mapped in private configuration. A foreground proxy running in an independent Terminal passes its matching readiness check. On-disk Codex configuration remains direct; activation has not occurred.

## Actual desktop-to-ICA matrix

| Scenario | Result | Evidence |
|---|---|---|
| Direct baseline in disposable projects | Not run | Project setup verified; baseline responses pending |
| First routed requests in both projects | Not run | Desktop activation/restart pending |
| Concurrent routed requests | Not run | Desktop requests pending |
| Follow-up and resumed chats | Not run | Desktop requests pending |
| Forked chat | Not run | User action pending |
| Project move | Not run | User action pending |
| `/compact` | Not run | Composer action observed in bundle; live action pending |
| Subagent attribution | Not run | Live delegation pending |
| Restoration and direct response after rollback | Not run | Live activation has not occurred |

The current direct provider configuration has not been changed by the implementation. No real credential has been retrieved by the router.

## Completion boundary

Missing desktop actions do not establish incompatibility. AC-03 through AC-05 and AC-10 require live evidence; automated checks alone cannot complete this increment. The final result must distinguish compatible, conclusively incompatible, and incomplete outcomes. Per-project key selection remains outside this increment.
