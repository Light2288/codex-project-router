# Project list organization validation

Created: 2026-11-19

Updated: 2026-11-19
Scope: approved project-list increment only. Stage 4 implementation; integrated correction review/follow-up and local closeout pending.

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
| AC-01 | Policy/placement tables; configured-only and legacy fallback; editor default cases | PASS — native policy/editor suites, missing-binding attention precedence, unavailable explicit-account distinction, flat On/Off/unknown/pending-mode and missing-target/search regressions, and Node catalog/assignment regressions |
| AC-02 | Explicit-current-default retention and On/Off invariance | PASS — native policy/default regression cases |
| AC-03 | Empty/archived/mixed/unarchived classifier and relocated inspection fixtures | PASS — full Node + both relocated/source-denied probes |
| AC-04 | Missing/malformed/locked/unsupported/racing data and activity-failure isolation | PASS — full Node + native observation-failure regressions |
| AC-05 | Settled archive/unarchive/move/deletion refresh and packaged deleted reference | PASS — full Node refresh cases + both bundled deleted-reference probes |
| AC-06 | Direct source/parent membership, completed edges and zero user-event flags | PASS — full Node source/parent classifier cases |
| AC-07 | Migration/bridge conflicts and incomplete-source conservative unknown | PASS — full Node conservative-profile cases + bundled unsupported checkpoint |
| AC-08 | Unique section rows, order, empty-section omission | PASS — full native presentation and hosted view assertions |
| AC-09 | Exact compact copy, Details and neutral unknown native fixture | PASS — full native presentation/layout assertions; nine Task 6 images inspected |
| AC-10 | All-ID runtime paging, coherent defaults/names, shared/per-row differences | PASS — full native runtime/controller suites, running missing-target warnings independent of identity comparison, distinct saved/running issue identities + bundled 8+1+empty pages |
| AC-11 | Collapsed problem previews, expansion replacement and unique counts | PASS — full native preview/expansion/count assertions, including named running-target failure previews |
| AC-12 | Search fields, matches/total, temporary reveal/clear and hidden warnings | PASS — full native search/count/disclosure assertions, including hidden flat/running missing-target warnings |
| AC-13 | Sheet refresh/save pinning, no rebase, discovery loss and stale guards | PASS — full native sheet/save/stale-authority regressions |
| AC-14 | 200 rows, Unicode, native focus/actions, disclosures and batching/deadline | PASS — full native 200-entry/layout/focus/action/batching tests; manual limits below |
| AC-15 | JSON/main DB/WAL/config/provider/source byte checks; zero credential/upstream/mutator reads | PASS — real committed-WAL test, bundled immutable-byte and zero-read assertions |
| AC-16 | Ordered full native/build/Node/package chain; routing/setup/assignment/recovery/projectless regressions | PASS — all four ordered commands; 379 native / 1095 Node / 3 package tests, zero failures/skips |
| AC-17 | Operating guide/README and this evidence record | Documented — guide/README/profile/deletion/SHM and evidence boundaries reviewed |

## Current-source execution

The quality-fix chain ran in this exact order on current source after the bounded
three-finding quality correction below. Product and test sources stayed unchanged
throughout this final chain. This supersedes the initial specification-correction
chain (375 native tests) and earlier Task 7 chain (373 native tests); their raw
evidence remains in the scratch workspace and earlier reports:

| Command | Exit | Result | Log in scratch evidence workspace |
|---|---:|---|---|
| `npm run companion:test` | 0 | 268 core + 111 app tests, 0 failures/skips | `quality-fix-companion-test.log` |
| `npm run companion:build` | 0 | Built and ad-hoc signed current app | `quality-fix-companion-build.log` |
| `npm test` | 0 | 1095 tests passed, 0 failures/cancellations/skips | `quality-fix-node-test.log` |
| `npm run companion:package-test` | 0 | All 3 top-level tests passed, 0 failures/cancellations/skips | `quality-fix-package-test.log` |

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

Current native tests emitted 5 expected activation-policy rejection messages from
existing error-path cases and no compiler warnings. The current release build emitted
7 intentional deprecated Security API source-location diagnostics. Current package
output reports the native Keychain harness emitted the existing 13 intentional
Security API deprecation diagnostics with no other warnings. The deliberately
unresponsive synthetic probes required forced termination under their deadlines;
the package output confirms their process groups and owned scratch state were absent.
This output is qualified; it is not warning-free.

The earlier Task 7 additional strict/deep codesign verification returned 0 and
reported `Signature=adhoc`, identifier `local.codex-project-router.companion` and
historical CDHash `de83ba6ee543a70635c3e7af99798de1581f4fd5`
(`task7-signature.log`). That hash predates this correction; the current package
tests repeated strict/deep signature verification against the newly built app.

The first chain stopped at `npm test`: 1094/1095 passed, with the sole failure a
standalone native package-probe source list missing `AssignmentTypes.swift` now
required by `ProjectListTypes.swift`. Direct RED/typecheck, the minimal source-list
fix, direct GREEN and the affected relocated acceptance pass preceded the entire
final chain above. Initial logs and RED/GREEN evidence remain in `task-7-report.md`.
The failed compile created no native process or Keychain item; its empty owned
scratch directory was verified and removed. No product source or safety assertion
changed for the fix.

The initial integrated specification review identified one preservation gap: flat
legacy/credential/absent-configuration rows no longer reflected known routing mode.
The bounded correction restores the prior global/inherited and inactive-while-Off
labels, adds mode-aware Details and forwards the actual parent pending-mode state.
It leaves flat running assignments unconfirmed and aliases in technical Details;
no named account, routing or write authority is inferred.

Two new native tests first failed with 38 expected assertions before product edits,
then passed after the three-file display correction. The focused covering run passed
26 core + 45 app tests. The native matrix covers legacy, credential and absent
configuration, aliases/no alias, On/Off/uncertain/unavailable/not-running, no account
name inference, and both real ControlsView pending-mode transitions. The missing
configuration fixture also preserves its disabled Start and reachable flat rows.
Exact commands, exits, raw logs, the initial test-only actor-annotation compile
correction and RED/GREEN summaries are in `final-fix-report.md` in the scratch
workspace. No required full-chain command failed or was repeated for this correction.

The initial specification correction subsequently passed its targeted specification
follow-up. The initial quality review identified three further display gaps: a flat
credential missing target had no immediate warning, a known running missing target
had no project warning/collapsed preview, and saved missing bindings were treated as
established custom policy. This bounded correction restores the flat warning, adds
a running-target warning independently of account comparison, and places missing
saved bindings in Needs attention before inactivity while retaining their target
warning. Established explicit policy with an unavailable account remains custom.
Saved and running target warnings have distinct row issue identities.

Three new native regression cases and corrected missing-binding expectations first
failed with 31 expected assertions. A fourth combined saved/running failure case
then exposed duplicate SwiftUI issue identities (one expected assertion failure)
and passed after the dedicated running-target kind. The final focused covering run
passed 63 app tests, including 23 presentation tests and existing controls, native
layout/disclosure/Edit/search and editor safeguards. Preview/pin fixtures that need
established custom policy now use an explicit override with an unavailable account;
all original preview/count/pin assertions remain. An earlier native-only pass on the
pre-identity source is retained as superseded evidence. Exact commands, exits,
RED/GREEN details and the test-only initial RED array-index correction are in
`quality-fix-report.md`; raw logs remain beside it. The final four-command chain
above had no failures or retries. No new image inspection or live production
behavior is inferred from the new presentation-model assertions.

The controller owns integrated correction review/follow-up and local closeout.
Those stages remain pending; this evidence does not declare the overall increment
closed.

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
