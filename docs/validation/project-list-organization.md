# Project list organization validation

Created: 2026-11-19

Updated: 2026-11-19
Scope: approved project-list increment only. Stage 4 COMPLETE — verified and reviewed; local commits retained.

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
current-source chain below now supplies their results. Per-task reports and raw logs were inspected during execution. This record preserves decisive results, review verdicts and rulings after cleanup of that temporary review workspace. Each result below refers to the completed current-source commands, with
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
results are superseded by the current-source results below:

| Command | Exit | Result | Execution log name (temporary workspace) |
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
final chain above. The initial RED/GREEN diagnosis was recorded in the temporary Task 7 report; the decisive outcome is retained here.
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
`swift test --package-path companion --filter 'ControlsPresentationTests.testFlat'` exited 1 with 38 expected assertion failures before the fix, then 0 afterward. The covering `--filter 'ProjectList|ControlsPresentationTests'` run passed 26 core + 45 app tests. A test-only actor annotation was corrected before behavioral RED. No required full-chain command failed or was repeated for this correction.

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
pre-identity source was superseded. `swift test --package-path companion --filter ProjectListPresentationTests` first exited 1 (22 tests, 31 expected failures). The combined-failure identity case then exited 1 with one expected failure before the distinct issue kind. The covering `--filter 'ProjectListPresentationTests|ControlsPresentationTests|ProjectListLayoutTests|ProjectAssignmentPresentationTests'` run passed all 63 app tests after the fixes. A test-only array index was replaced with XCTUnwrap before behavioral RED was rerun. The final four-command chain
above had no failures or retries. No new image inspection or live production
behavior is inferred from the new presentation-model assertions.

The corrected state passed the scoped specification and quality follow-ups below. The parent also re-inspected the regenerated collapsed-problems image at 720×640 logical size: named warning, Edit and Details fit without clipping, overlap or duplicate rows. Local delivery is complete.

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

## Final integrated review and local delivery

The gate was one logical sequential specification → quality review. Initial findings were corrected in local commits c5cc3e1 (flat mode preservation) and ed3754e (missing-target warnings, policy placement and distinct warning identities). The final reviewed production/test state is `ed3754e0b108d166d745a6d2b435cc9601645828`. Only documentation/evidence changed during closeout; the verified sources remain unchanged.

All task gates passed. The final gate checked one immutable current-state package; both reviewers matched its gate ID, state ID and SHA-256. Complete final reports follow. Historical failures remain described above; no unresolved review finding is parked.

The existing normal checkout and local commits are retained on `feat/project-list-organization`, based on `b735f37825d527f937bba85093fd37b96cd7361c`. No worktree, push or merge was performed. The temporary plan-specific review workspace was removed after preserving this evidence. Nine synthetic native PNGs remain ignored under `companion/.build/project-list-qa/`. Raw temporary log names above identify the executed checks rather than durable file links.

This completes only increment 4. Broader UI simplification, startup and distribution remain provisional and unstarted.

### Specification verdict

```text
GATE_RUN_ID: gate-3c8feb4f-c5b4-4642-a6f5-e657039c47ee
REVIEWED_STATE_ID: state-19e02627-99f0-400a-88ad-4c96bc874895-ed3754e0b108d166d745a6d2b435cc9601645828
PACKAGE_SHA256: c8def5eb15a2a9a6269de7d8b278a4904f36a8a1c467719a1976cda6726cce13

SPEC REVIEW: PASS

All three quality findings are addressed:

- Flat credential routes with missing targets show an actionable warning in On and Off, including filtered search.
- Missing running targets show a distinct actionable warning, appear in collapsed inactive previews, and remain counted in hidden-search summaries.
- Missing saved bindings enter Needs attention before inactive placement. Established overrides with unavailable account summaries remain Custom account with a warning.

Saved and running target warnings use distinct issue identities, preventing SwiftUI from dropping either. Regression tests cover that combination, and the updated fixtures preserve prior pin, search, count, and preview assertions. The prior flat-row mode-preservation fix remains intact; the scoped changes do not alter routing or authority.

The package records behavioral RED/GREEN, focused tests, and a fresh ordered chain: 379 native tests, signed build, 1095 Node tests, and 3 package tests, all successful with zero failures or skips. Its 37-file boundary matches the 37 complete branch diff sections. The recorded bounded-correction ruling and unchanged approved scope are included. No new specification gap or out-of-scope behavior was found.
```

### Quality verdict

```text
GATE_RUN_ID: gate-3c8feb4f-c5b4-4642-a6f5-e657039c47ee
REVIEWED_STATE_ID: state-19e02627-99f0-400a-88ad-4c96bc874895-ed3754e0b108d166d745a6d2b435cc9601645828
PACKAGE_SHA256: c8def5eb15a2a9a6269de7d8b278a4904f36a8a1c467719a1976cda6726cce13

Current, expected and fresh SPEC REVIEW: PASS identity values all match. The package remained unchanged.

QUALITY REVIEW: APPROVED

Findings: NONE. All three previous findings are addressed.

- Flat credential rows restore immediate missing-target warnings in On/Off and search.
- Running missing targets now produce actionable warnings, collapsed previews and hidden-search summaries. Saved and running warnings use distinct .targetMissing and .runningTargetMissing identities.
- Missing saved bindings enter Needs attention before inactivity; established explicit policy with an unavailable account retains its custom classification and warning.

The scoped correction preserves identity comparisons, prior flat-mode behavior, pinning, search, counts and editor safeguards. No fix-introduced defect was supported by the reviewed evidence. Prior untouched whole-branch coverage is retained.

Recorded current-source verification passed: 379 native tests, signed build, 1095 Node tests and 3 package tests, with zero failures/skips. Existing qualified diagnostics and manual/live limitations remain documented. No files were changed or suites rerun during this review.
```

## Rulings I made

Ruling: Follow approved ordered final verification in Task 7; baseline uses current sources before edits — packaged artifacts are rebuilt before final acceptance, and any stale-bundle baseline failure is recorded — cost if wrong: delay, never weaker acceptance.

Ruling: Synthetic schema contains all supported projection fields, not unrelated database columns — avoids invented schema dependency — cost if wrong: fixture adjustment. Spawned internal exclusion requires parsed source parent matching saved incoming edge; optional attached parent must agree. Guardian source/role requires no contradictory parent evidence — conservative supported evidence — cost if wrong: unknown status remains visible rather than hiding a project.

Ruling: Additional owner checkpoints for this home must share the signed-out checkpoint normalized pendingThreadAssignmentIds set to permit negative classification — divergent owner queues are unsupported completeness evidence — cost if wrong: conservative unknown visibility. Positive supported unambiguous membership remains usable absent a membership conflict. Task 1 adds direct regression.

Ruling: Task 2 raw relevant-branch duplicate JSON keys are guarded locally (including escaped names); unlocalizable contradictory claims yield unknown activity, independent catalog path retains existing parsing/authority. Exhausted changing activity retains newest valid state with unknown/changed_during_read; continued project identity/name changes yield unavailable catalog, matching Task 2 explicit test. Cost if wrong: temporary conservative unknown/unavailable until next successful refresh.

Ruling: Fold WAL fixture and documentation into Task 7 verification (test/project-activity.test.js additional ownership), with no product behavior change — fills concrete validation gap in approved WAL-aware observer requirement — cost if wrong: test/wording adjustment.

Ruling: Task 5 adds usesAccountSections: Bool and flatRows(state:) -> [ProjectListRow]; sections returns empty outside accounts mode — minimal presentation-only API supports explicitly approved flat legacy/no-config fallback while preserving four section kinds — cost if wrong: small view/model adjustment. Legacy route aliases remain detail and unavailable named policy never becomes Uses default.

Ruling: Task 5 pinQuery/pinVisibleIndex transient state preserves displayed position under unchanged search when new nonmatching rows appear — full collection index alone is insufficient — cost if wrong: small transient-state fix.

Ruling: A pinned inactive editing row remains temporarily visible among collapsed previews even if its final issue is repaired; keep fresh isActionable false and exclude it from issue counts, retain captured preview index and placement notice until dismissal. Do not auto-expand all inactive rows — preserves approved editor placement and user collapse state — cost if wrong: presentation-only rework. Task 6 must honor this editing exception without duplicate full rows/counts.

Ruling: Correct all three concrete quality findings in one additional bounded wave within the existing approved increment, overriding the skill default of one final fix wave — the user explicitly requires autonomous completion, no new approval gates between ordinary implementation tasks, and preserved actionable warnings; higher-priority developer instructions require carrying the authorized task to completion. The first wave resolved a specification-stage preservation gap before quality could run. Preserve the same logical review seat, perform only scoped followups, and change no approved requirement — cost if wrong: one additional focused fix/review cycle and full verification chain.
