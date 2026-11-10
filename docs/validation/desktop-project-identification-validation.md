# Desktop project-identification validation report

Date: 2026-11-10. Outcome: **primary desktop matrix passed; additional requests without durable identity are unsupported and blocked**. Direct configuration has been restored and verified. Sequential final review completed; its one important finding was corrected and verified.

## Environment

- Node.js 24.21.0; macOS local checkout.
- Observed desktop version 26.1029.61003, build 24614; engine 0.166.0-alpha.6.
- Private request headers and desktop-state structures are observed interfaces, not guaranteed stable APIs.

## Automated evidence

At the implementation checkpoint, `npm test` passed 68 tests with zero failures. Tests ran against synthetic temporary files/SQLite state and a local HTTPS upstream; they did not contact ICA or retrieve real credentials.

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

The user created two disposable desktop projects with separate scratch roots, confirmed direct baseline responses, and restarted the app after explicit proxy activation. The original authentication helper remained in place throughout. Actual desktop requests traversed the proxy to ICA; lifecycle checks combined sanitized diagnostics, required saved identity relationships, and user confirmation of visible completion. The router never independently retrieved credentials.

## Actual desktop-to-ICA matrix

| Scenario | Result | Evidence |
|---|---|---|
| Direct baseline in disposable projects | Observed pass | User confirmed both direct baseline responses |
| Resumed controller chat after restart | Observed pass | Explicit controller alias; proxy completion HTTP 200 |
| Provider-wide model discovery | Observed pass | Catalog requests completed with HTTP 200 |
| First routed requests in both projects | Observed pass | Repeated with 300-line outputs; correct aliases and user-confirmed completion; client close classified 499 |
| Concurrent routed requests | Observed pass | Repeated intervals overlapped by 5.427 seconds; correct distinct aliases and user-confirmed completion |
| Follow-up and resumed chats | Observed pass | User confirmed both in the same Project A chat; same validated chat ID and `validation-a`; HTTP 200 for both |
| Forked chat | Observed pass | User confirmed branching; new chat ID directly assigned to `validation-a`; HTTP 200 |
| Project move | Observed pass | Same fork chat ID changed from `validation-a` to `validation-b` on its next request; HTTP 200; user confirmed output |
| `/compact` | Observed pass | Desktop used regular Responses operation; HTTP 200 at 15:32:00.227 UTC, saved compaction marker 6 ms later; follow-up HTTP 200 and user confirmation |
| Subagent attribution | Observed pass | Child request used saved spawn edge to the moved fork, `source=ancestor`, `validation-b`; HTTP 200 and user confirmation |
| Restoration and direct response after rollback | Observed pass | Helper restored original URL; user restarted and confirmed direct response; no proxy request from the test chat after rollback |
| Additional requests without saved identity relationships | Observed failure / unsupported | Two IDs, 17 rejected attempts each; no saved thread, project assignment, projectless marker, attached parent, or spawn edge; zero admitted upstream calls |

Final status: `state=direct`, `proxyReady=false`, `recoveryRequired=false`. The test proxy was stopped after the successful direct-response check. Protected backup/recovery records remain private. The disposable projects and their chats remain available for inspection; moving the fork granted Project B access to the original disposable scratch root as well as its own.

All 420 actual diagnostic records parsed as JSON and contained only allowed fields; no header or body fields were present. Actual endpoints, identifiers, configuration, and raw run evidence remain outside Git.

## Sanitized concurrency intervals

The repeated run on 2026-11-10 recorded these UTC intervals. IDs and upstream details remain private.

| Alias | Started | Completed | Transport outcome |
|---|---|---|---|
| `validation-a` | 15:04:34.695 | 15:04:44.671 | Client close, 499; user confirmed complete output |
| `validation-b` | 15:04:39.244 | 15:04:50.745 | Client close, 499; user confirmed complete output |

Overlap: **5.427 seconds**. The initial run overlapped by 1.728 seconds.

## Findings and limits

The cancellation regression initially failed with `502` where a client cancellation required `499`. Upstream teardown synchronously emitted an abort before the cancellation outcome was recorded. Recording cancellation first corrected the result; the full suite then passed 68 tests. Rejected requests now retain a validated chat identifier in diagnostics, without raw headers or metadata, so missing desktop relationships can be investigated. The repeated run correlated 34 `STATE_UNAVAILABLE` rejections with two request IDs absent from every supported saved identity relationship. Blocking these requests is required; auxiliary generation remains unsupported where no durable relationship exists. Their exact originating desktop feature is unverified. The router itself introduced no retries; repeated rejected attempts came from the caller.

The two unresolvable request IDs remained absent from all supported saved relationships after the lookup deadline. The installed desktop bundle uses ephemeral threads for auxiliary title/description/summary generation, which is a plausible explanation; the exact originating feature is unverified. The approved architecture cannot safely route such requests. No project was guessed from folders, prompts, or nearby activity.

The live `/compact` action used regular Responses. The dedicated `/responses/compact` endpoint is covered by synthetic integration tests but was not observed from this desktop. Client-close status 499 describes the transport outcome; complete content was established by user confirmation, not by inspecting response bodies in the router.

## Final review

The specification review passed on the complete branch snapshot. The subsequent quality review found one important issue: duplicate identity members in metadata JSON could conceal an earlier conflicting identifier. Resolver and HTTP regressions reproduced acceptance before the fix; the corrected parser rejects literal and escaped duplicate key spellings, including parent hints, before project selection. HTTP regressions confirm zero upstream model calls. Nested metadata and key-like string contents remain accepted when valid. The final suite passed **68/68**.

The Native review policy permits one verified fix pass and no re-review. That pass addressed the only quality finding; no minor findings were deferred. Private raw runtime evidence was outside the independent reviewers' boundary; their assessment used the sanitized report and recorded verification. The original reviewed commit was `fa22c59`; subsequent changes implement and verify this finding.

## Completion boundary

All required primary desktop scenarios were exercised. The increment establishes support for mapped durable chats and saved subagents on the observed installation, alongside a demonstrated inability to attribute some additional requests using the approved sources. That limitation blocks progression to credential switching until addressed through a later approved design. Per-project key selection, billing attribution, GUI, and automatic startup remain outside this increment. No push or merge is authorized.
