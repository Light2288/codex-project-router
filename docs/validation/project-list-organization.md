# Project list organization validation

Created: 2026-11-19

Updated: 2026-11-19
Scope: approved project-list increment only. Stage 4 implementation; final integrated review and local closeout pending.

## Evidence boundaries

The earlier user-operated discovery experiment observed creation in A, archive,
unarchive, move to B, and permanent deletion without archiving. Membership remained
through archive/unarchive and changed on move; deletion removed the SQLite row and
transcripts but retained global membership/host references. Both projects stayed
discoverable; independent fresh Node/Python reads agreed and integrity check passed.
These are settled observations, not proof of every intermediate write, and the
experiment was not repeated for this increment. Deletion leftovers intentionally
remain visible with unknown chat status.

Tasks 1–5 use synthetic JSON/SQLite, channel and controller/presentation fixtures.
Task 6 hosts real production SwiftUI views in synthetic NSHostingView/NSWindow
controllers. Nine native images were inspected by the Task 6 implementer and parent at
720×640 logical minimum size (the final-ID search also uses 960×720). Collapsed
problems, expanded inactive rows, search counts, long Unicode names, the 200th-ID
search, saved/running default discrepancies, no results/shared notices, full controls
and unknown policy/chat states fit without observed text/action overlap or clipping.
The initial same-name default discrepancy was corrected to an explicit warning and
re-inspected. Images remain ignored under `companion/.build/project-list-qa/`.

Native interaction assertions exercise real text editing, accessible actions,
focus/first-responder access, one explicit save, sheet survival, no draft rebasing,
discovery-loss guards and repaired pinned previews. Full physical OS Tab/Space,
VoiceOver and successful popup-menu selection were not observed in the unbundled
xctest harness. Two owned hung test hosts were terminated and verified absent;
Task 6's synthetic backend launched no child/listener. These observations are
hosted native fixtures, not packaged production data or live routing acceptance.

Task 7 package checks are separately recorded below after execution. Existing
package native-window observations use disposable synthetic homes under macOS
source-read denial. No new production companion/Codex settings or real chat state
were changed. No new live account/gateway/billing or cross-account continuation
acceptance is claimed by list labels.

## Acceptance matrix

The matrix began with all current-source slots marked unobserved. The completed
current-source chain below now supplies their results. Prior task reports are retained in the ignored `.superpowers/sdd/2026-11-19-project-list-organization-and-compact-presentation/`
workspace. Each result below refers to the completed current-source commands, with
fixture-native observations distinguished from new live behavior.

| Criterion | Evidence | Current-source final result |
|---|---|---|
| AC-01 | Policy/placement tables; configured-only and legacy fallback; editor default cases | PASS — native policy/editor suites and Node catalog/assignment regressions |
| AC-02 | Explicit-current-default retention and On/Off invariance | PASS — native policy/default regression cases |
| AC-03 | Empty/archived/mixed/unarchived classifier and relocated inspection fixtures | PASS — full Node + both relocated/source-denied probes |
| AC-04 | Missing/malformed/locked/unsupported/racing data and activity-failure isolation | PASS — full Node + native observation-failure regressions |
| AC-05 | Settled archive/unarchive/move/deletion refresh and packaged deleted reference | PASS — full Node refresh cases + both bundled deleted-reference probes |
| AC-06 | Direct source/parent membership, completed edges and zero user-event flags | PASS — full Node source/parent classifier cases |
| AC-07 | Migration/bridge conflicts and incomplete-source conservative unknown | PASS — full Node conservative-profile cases + bundled unsupported checkpoint |
| AC-08 | Unique section rows, order, empty-section omission | PASS — full native presentation and hosted view assertions |
| AC-09 | Exact compact copy, Details and neutral unknown native fixture | PASS — full native presentation/layout assertions; nine Task 6 images inspected |
| AC-10 | All-ID runtime paging, coherent defaults/names, shared/per-row differences | PASS — full native runtime/controller suites + bundled 8+1+empty pages |
| AC-11 | Collapsed problem previews, expansion replacement and unique counts | PASS — full native preview/expansion/count assertions |
| AC-12 | Search fields, matches/total, temporary reveal/clear and hidden warnings | PASS — full native search/count/disclosure assertions |
| AC-13 | Sheet refresh/save pinning, no rebase, discovery loss and stale guards | PASS — full native sheet/save/stale-authority regressions |
| AC-14 | 200 rows, Unicode, native focus/actions, disclosures and batching/deadline | PASS — full native 200-entry/layout/focus/action/batching tests; manual limits below |
| AC-15 | JSON/main DB/WAL/config/provider/source byte checks; zero credential/upstream/mutator reads | PASS — real committed-WAL test, bundled immutable-byte and zero-read assertions |
| AC-16 | Ordered full native/build/Node/package chain; routing/setup/assignment/recovery/projectless regressions | PASS — all four ordered commands; 373 native / 1095 Node / 3 package tests, zero failures/skips |
| AC-17 | Operating guide/README and this evidence record | Documented — guide/README/profile/deletion/SHM and evidence boundaries reviewed |

## Current-source execution

Final chain ran in this exact order on current source after the test-harness fix:

| Command | Exit | Result | Log in scratch evidence workspace |
|---|---:|---|---|
| `npm run companion:test` | 0 | 268 core + 105 app tests, 0 failures | `task7-final-companion-test.log` |
| `npm run companion:build` | 0 | Built and ad-hoc signed current app | `task7-final-companion-build.log` |
| `npm test` | 0 | 1095 tests passed, 0 failures/cancellations/skips | `task7-final-node-test.log` |
| `npm run companion:package-test` | 0 | All 3 top-level tests passed, 0 failures/cancellations/skips | `task7-final-package-test.log` |

The package tests check the explicit source/dependency allowlist, compare every
bundled production Node module byte-for-byte with the current checkout, verify
strict/deep signing, reject checkout paths in the release binary and execute
relocated modules with lexical/resolved/symlink checkout reads denied. The bundled
inspection probe checks supported empty/archived/mixed/deleted-reference cases and
an unsupported checkpoint, stable catalog identity revision, immutable JSON/main
DB/provider/config/source bytes, zero credential processes and upstream requests.
The retained owned managed child supplies 8+1+empty runtime pages after On/Off
reads/changes; context/session/request, snapshot/default/name, override/inherited
semantics, frame bounds, immutable provider/config and zero credential/upstream
calls are asserted. Existing synthetic original-connection checks retain 8 original
calls, one default and one override call; identity/auth failures make no model call.

Native source-denial automation observed the relocated executable's on-screen
window and synthetic instance lock, plus native branding decoding. Existing stopped
and live assignment, activation/byte-exact rollback, retained listener/mode and
recovery assertions pass. Owned process/group absence, probe deadlines, native
scratch Keychain/sidecar cleanup and synthetic-port reuse pass in lifecycle hooks.
These are synthetic packaged observations; no GUI control action or new live
production routing acceptance is inferred.

An additional strict/deep codesign verification returned 0; display reports
`Signature=adhoc`, identifier `local.codex-project-router.companion`, CDHash
`de83ba6ee543a70635c3e7af99798de1581f4fd5` (`task7-signature.log`). Native tests emit
5 expected activation-policy rejection messages from existing error-path cases and
no compiler warnings. The release build emits 7 intentional deprecated Security
API source-location diagnostics. The standalone native Keychain harness emits the
existing 13 intentional Security API deprecation diagnostics, with no other
warnings. This output is qualified; it is not warning-free.

The first chain stopped at `npm test`: 1094/1095 passed, with the sole failure a
standalone native package-probe source list missing `AssignmentTypes.swift` now
required by `ProjectListTypes.swift`. Direct RED/typecheck, the minimal source-list
fix, direct GREEN and the affected relocated acceptance pass preceded the entire
final chain above. Initial logs and RED/GREEN evidence remain in `task-7-report.md`.
The failed compile created no native process or Keychain item; its empty owned
scratch directory was verified and removed. No product source or safety assertion
changed for the fix.

Final integrated review is controller-owned after Task 7 task review; its result
and local closeout remain pending. The overall increment is not yet declared closed.

## Compatibility and limitations

The exact checkpoint/source profile and conservative unknown behavior are documented
in the [operating guide](../operating-guide.md#project-list-organization). The observer
uses relevant SQLite/JSON projection comparisons and a bounded retry; no atomic
cross-file snapshot is promised. Healthy catalog/editor authority remains separate.
Read-only SQLite observes committed WAL data without changing global JSON, main DB,
WAL, router config or provider bytes. SQLite may create/update its SHM coordination
sidecar; directory immutability is not claimed. Missing-record deletion and newer
canonical/migrated representations can keep projects visible indefinitely as unknown.
No manual hiding, second backend, automatic metadata repair or later roadmap work
is included. New live production interaction/routing behavior remains unobserved.
