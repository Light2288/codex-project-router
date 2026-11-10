# Unassigned title-request policy validation

Date: 2026-11-10. Status: **desktop validation and recovery complete — final review pending**.

The implemented default-off policy admits only the approved initial-title pattern with fresh proof of absent saved identity. It forwards the caller's existing credential without project attribution. It does not select project credentials or establish trustworthy project origin.

## Environment and synthetic evidence

- Desktop: 26.1103.60933, build 25894 (installed in `ChatGPT.app`); engine: 0.167.0-alpha.3.2; Node: 24.21.0.
- Baseline: 136 passing tests before implementation; implementation suite: 259 passing tests before desktop validation.
- Covered: exact/escaped/duplicate metadata, four policy/observation combinations, mapped priority, positive absence, failed final reads, file replacement, SQLite WAL changes, missing schema, cancellation, overlapping distinct credentials, transport parity and sanitized diagnostics.
- Both private options were absent/default-off before this increment. Direct provider operation, proxy shutdown and disposable/controller mappings were verified read-only before activation.
- Live proxy mode: `allowUnassignedThreadTitles: true`, `observeRequestMetadata: true`. All four combinations are covered synthetically; other combinations were not exercised live in this increment.
- `npm ci` succeeded with zero reported vulnerabilities. `npm test` passed 259/259; `node --check src/cli.js` and `git diff --check` succeeded before live activation. Sequential final review remains pending the completed desktop evidence.

## Desktop cases

| Case | Classification | Evidence |
|---|---|---|
| Direct fresh Project A response and automatic title | Observed pass | User confirmed both response and automatic title; content not retained |
| Direct fresh Project B response and automatic title | Observed pass | User confirmed both response and automatic title; content not retained |
| Initial controller connection after activation/restart | Observed failure | User reported request-send/reconnection failures; initial foreground capture stopped |
| Current proxied controller connection | Observed pass | Current listener records mapped controller requests and completed upstream HTTP 200 responses |
| Controlled app quit/reopen with independent proxy | Observed pass | Engine disappeared and returned with a new PID; the same listener passed all 135 sampled health/readiness checks; reopened app request reached the proxy with correct controller attribution |
| Full app/background quit and reopen | Observed pass with monitoring limitation | Old main app and engine exited; new main app and engine appeared, and the reopened controller request completed upstream HTTP 200. Two helpers remained at the last pre-reopen sample; a zero-process interval was not observed |
| Proxied fresh Project A response and automatic title | Observed pass | Main request A1 retained Project A attribution and completed HTTP 200; user confirmed a complete response and visible automatic title |
| Proxied fresh Project B response and automatic title | Observed pass with cancellation recorded | Main request B1 retained Project B attribution; user confirmed a complete response and visible automatic title; the stream recorded client cancellation (499) |
| Overlapping mapped and title request intervals | Observed pass | Main A/B requests overlapped for 2.593 seconds; both also overlapped unattributed title work |
| Same-chat follow-up | Observed pass | Follow-up retained B1's identity and Project B attribution and completed HTTP 200; user confirmed receipt |
| Unattributed title forwarding and saved-state absence | Observed pass with cancellation recorded | U1 completed HTTP 200; U2 recorded client cancellation (499). Both used `unassigned_title`, omitted ownership, and had no saved membership/relationships in read-only analysis |
| Final restoration, restart, direct response and stopped listener | Observed pass | Original URL and exact prior flag omission restored; user confirmed restart/direct response; status direct, proxy not ready, no recovery required; no listener remained |

The user confirmed responses and automatic titles in both fresh chats, independently of the diagnostic labels. The router does not inspect titles or responses. U1 and U2 remain unattributed: proximity to A1/B1 does not prove which project caused either title request. Client cancellation is retained as an observed transport outcome, not rewritten as upstream HTTP 200.

## Controlled request intervals

All times below are UTC on 2026-11-10 (Europe/Rome was UTC+1). Labels are symbolic; actual identifiers remain private. Intervals cover diagnostic start to completion and include local lookup time.

| Request | Identity / source | Started | Completed | Router outcome |
|---|---|---|---|---|
| V001 | A1 / direct Project A | 21:15:17.328 | 21:15:24.663 | 200 |
| V002 | U1 / unassigned_title | 21:15:17.829 | 21:15:19.991 | 200 |
| V003 | U2 / unassigned_title | 21:15:21.658 | 21:15:25.411 | 499 / CANCELLED |
| V004 | B1 / direct Project B | 21:15:22.070 | 21:15:28.635 | 499 / CANCELLED |
| V005 | B1 follow-up / direct Project B | 21:16:33.149 | 21:16:36.526 | 200 |

A1/B1 overlap was 2.593 seconds. A1/U1 overlap was 2.162 seconds; A1/U2 was 3.005 seconds; U2/B1 was 3.341 seconds. Each request retained its own diagnostic snapshot and attribution. The controlled window contained two admitted title requests and no blocked title retries; the router introduces no upstream retry.

For U1/U2, observations had `thread_source=thread_title` and `turn_trigger=thread_title`, all four normalized UUID claims agreed, and all origin fields were absent. `request_kind` was classified `other`; its raw value was not captured and did not authorize the exception. U1/U2 diagnostics omitted `projectId`, `ownerThreadId` and `routeAlias`. Read-only post-run analysis independently found no assignment, projectless marker, saved thread or incoming/outgoing spawn edge for either temporary identity. Runtime admission required its own fresh absence proof. These facts establish unassigned title eligibility, not project origin or billing attribution.

## Restart investigation

The initial foreground log stopped recording after activation. Investigation found a later listener writing a different private log, which contains successful controller traffic. An initial assessment of zero model traffic used the stale log and was corrected. The exact cause of the earlier launcher interruption remains unproven; it is not evidence that the title exception is incompatible. No admission or identity requirement was relaxed.

At the user's request, paired title validation was paused for a controlled restart. A finite independent monitor observed an approximately 15-second interval without the app engine, followed by a new engine process, while the proxy process remained unchanged and healthy. The user returned the requested restart marker. That controller stream recorded client cancellation (499), so no upstream-200 claim is made for that specific stream. The original app-owned launcher stopping is a plausible explanation of the earlier outage, not a confirmed cause. No startup service or automatic restart was added.

The user then repeated the test while explicitly quitting the background app component. All 76 sampled health/readiness checks passed with the same proxy process. The old main app and engine disappeared before reopening. Two helper processes remained at the final sample, and the monitor received a stop signal before reopening; its sender is unverified. Continuous monitoring through the entire shutdown/reopen interval and a zero-app-process interval are therefore not claimed. After reopening, none of the original app PIDs remained, new main/engine processes were present, and the controller request completed upstream HTTP 200 with correct attribution. The earlier request-send failure was not reproduced; its cause remains unproven.

## Recovery

Rollback restored the checkpointed direct provider URL. Both optional properties were restored to their original absence, preserving unrelated current router settings. The user fully restarted the app and confirmed a successful direct response. The known proxy process was then stopped. Final status was `state=direct`, `proxyReady=false`, `recoveryRequired=false`; an independent listener check confirmed no listener on the configured port. Private checkpoints, activation backups and evidence remain available outside Git. Both finite monitors had stopped; no automatic startup was installed.

## Boundaries

Only symbolic chat/request labels and sanitized intervals/outcomes belong in this report. Actual IDs, endpoints, mappings, checkpoints and raw evidence remain private outside Git. Prompts, responses, title text and credentials are excluded from diagnostics and this report.

The policy accepts spoofable local title markers and provides no project cost attribution. Absence checks detect observed changes without providing cross-file atomicity. Per-project credential selection and additional auxiliary policies remain deferred.
