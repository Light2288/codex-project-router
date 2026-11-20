# Keychain Lookup Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The personal adapter, separate approval gates and repository Git rules take precedence over generic handoffs.

**Goal:** List usable existing Keychain references despite unrelated unusable item metadata, explain omissions, and preserve strict exact lookup and recovery.

**Architecture:** Retain `KeychainStore.listMetadata` and both `lookup` overloads as strict operations. Add a browsing method returning references and an omitted-item count through the same native query/serial-execution boundary, then carry that result through `AccountSetupController` into the existing Advanced selector. Tolerance applies only to service/account metadata on individual rows; native failures, invalid paths, filter contradictions and unexpected secret data still fail the whole lookup.

**Tech Stack:** Existing Swift/Security/SwiftUI/AppKit and XCTest; Swift tools 6.0, Swift language mode 5, macOS 14 minimum; existing Node 24 scripts and signed local app assembly. No new dependency or configuration schema.

**Spec:** `docs/superpowers/specs/2026-11-20-keychain-lookup-fix.md`  
**Slug:** `keychain-lookup-fix`  
**Status:** APPROVED  
**Created:** 2026-11-20  
**Updated:** 2026-11-21\
**Execution tier:** full  
**Implementation model role:** full  
**Execution method:** Native, explicitly selected through the execution-method control for this fix. Independent final specification and quality review remain required. Full tier is selected; inline execution does not switch the parent model. The managed full-role lookup is `gpt-6.1-sol`.

**Provenance and approvals:** The user confirmed this fix's scope/design with “i confirm scope/design”, then approved the presented, saved specification with “approved”. This plan was presented separately at Stage 3 and subsequently approved after presentation; the actual approval is recorded in Current stage below. A subsequent “plan approved” message arrived during drafting, before this artifact had been presented, and does not authorize implementation under the supplied approval rules. Keep both artifacts uncommitted until the implementation branch is authorized and created.

## Global Constraints

- “Omission applies only to unusable service/account metadata on a returned item.” Keep reference limits unchanged: absolute Keychain path, nonempty fields, at most 1,024 UTF-16 units per field and no control characters. Do not repair or trim returned fields.
- “These failures take precedence over omission.” Unexpected `kSecValueData`, string filter contradictions, unsafe/unsupported paths and native failures cannot become omissions or successful partial results.
- Exact lookup retains malformed-row rejection and ambiguity, including multiple Keychains. Incoming suggestions and receipt reconciliation never use tolerant browsing.
- Queries remain generic-password/file-backed and attributes-only, with data and item references disabled. Preserve serial execution, native ownership/canonicalization checks, creation ACLs, consent and secret disposal.
- “Do not automatically select or apply a discovered item.” Searching alone preserves existing form choices, saved configuration, assignments, routing, receipts and locks; selection still leaves password access/provider acceptance unverified.
- Counts describe the captured successful query, with zero matches plus positive omissions distinguishable from empty success and failure. No rejected-row content or secret values enter errors, logs or durable reports.
- No credential-reader, authentication-helper, schema, routing, recovery-flow or broader navigation changes. No new dependencies, generic policy framework or persistent listing state.
- Existing checkout only. No main update, implementation branch, product change or commit before separate plan approval. No worktree, push or merge. Do not replace an in-use app bundle without coordinating guarded Quit.

## Review Focus

1. A row combines missing account metadata with a mismatching string service or unexpected secret data: the hard failure must win, in either row order — Task 1 mixed-invalid-row tests.
2. A successful first Keychain is followed by a failing second Keychain: neither references nor an omission summary may appear as successful partial evidence — Tasks 1 and 2 failure-after-success tests.
3. A filtered native query returns a malformed row during recovery: strict lookup must error rather than manufacture absence or permit a repeated creation — Task 1 exact-lookup and Task 2 recovery-controller tests.
4. New lookup starts after an omitted-only result or selected picker item: pending/failure must clear stale evidence without changing already applied form choices — Task 2 native interaction tests.
5. A user edits filters during a held lookup: completion must retain captured scope and counts, with no automatic item selection — Task 2 held-query native test and presentation tests.

## Repository evidence and artifact resolution

Planning baseline is `6612e457ac6d9b384483626b5964b22a7a617d63` on `main`, matching local `origin/main`. The preceding cleanup fetched/pruned and removed only the merged local feature branch. At planning, only this increment's artifacts are uncommitted. Recheck state after approval; do not assume the remote remains unchanged.

Specification resolution is `NEW_ONLY` at the exact path above. Plan resolution was `MISSING`, including `plans/keychain-lookup-fix.md`; this new plan reuses the specification's exact basename. No legacy source is changed. The only specification edit during planning records its actual approval and current workflow stage; requirements remain unchanged.

No `docs/architecture/map.md` or decision-document candidates under `docs` were found. Architecture-map HEAD/freshness and applicable ADR statuses are therefore unavailable, not assumed current. No map is generated. Key-path inspection at the baseline covered KeychainStore, CredentialReference, AccountSetupController, AccountSetupView, their tests, package compilation of production KeychainStore sources, and build assembly. Native decoding/path checks can remain unchanged; the change belongs in row classification above them.

Verification commands come from `package.json` and `companion/README.md`'s “Build and run the native app” section: `npm run companion:test`, `npm run companion:build`, `npm test`, `npm run companion:package-test`, and `open "dist/Codex Project Router.app"`. Focused `swift test --package-path companion --filter <TestClass>` follows the established invocations in `docs/superpowers/plans/2026-11-19-project-list-organization-and-compact-presentation.md` and current test class names. `git diff --check` follows the prior setup plan. The package tests compile the actual KeychainStore and test a disposable owned Keychain; they already exercise secret/ACL/reader behavior, so do not add a new user-Keychain mutation experiment.

No tests, build, native Keychain query or operational mutation ran during planning. Previous increment results are historical, not acceptance of this fix. No material product decisions remain; execution-method choice was pending at the Stage 3 handoff and is now recorded above.

## File responsibilities and interfaces

| Files | Planned responsibility |
|---|---|
| `companion/Sources/CompanionCore/KeychainStore.swift` | Listing value, tolerant browsing entry point and narrowly ordered row validation; retain strict APIs |
| `companion/Tests/CompanionCoreTests/KeychainStoreTests.swift` | Mixed-metadata, precedence, strict-lookup, multi-Keychain and query-safety tests; extend the existing fake only as needed |
| `companion/Sources/CompanionCore/AccountSetupController.swift` | Return the listing value from browsing only; leave suggestion/recovery call sites strict |
| `companion/Sources/CodexProjectRouter/AccountSetupView.swift` | Display omitted counts in completed state, propagate results, retain clearing and selection rules; narrowly scoped accessibility identifiers |
| `companion/Tests/CompanionCoreTests/AccountSetupControllerTests.swift` | Listing propagation, no-write evidence, strict incoming/recovery regressions |
| `companion/Tests/CompanionAppTests/AccountSetupPresentationTests.swift` | Completed/empty/omitted/failed copy and captured scope |
| `companion/Tests/CompanionAppTests/AccountSetupActionTests.swift` | Host the real setup view with synthetic metadata; test lookup lifecycle and preserve form choices |
| `docs/operating-guide.md`, `companion/README.md` | User-facing browsing behavior and remaining failure/access limitations |
| New `docs/validation/keychain-lookup-fix.md` | Actual verification, visual evidence, acceptance mapping and review outcomes |

No production files beyond the four Swift files above are expected to change. Keep the listing value in KeychainStore.swift so the existing package harness compiles it without changing its source allowlist.

Contracts for both tasks:

- `public struct KeychainMetadataListing: Equatable` exposes read-only `references: [CredentialReference]` and `omittedItemCount: Int`. Counts originate from row handling, never a UI estimate. Keep construction local to the module; app tests may use `@testable import CompanionCore`.
- `KeychainStore.browseMetadata(service: String? = nil, account: String? = nil, keychainPath: String? = nil) async throws -> KeychainMetadataListing` provides tolerant browsing through `execute`.
- Preserve `listMetadata(...) async throws -> [CredentialReference]`, `lookup(reference:)` and `lookup(service:account:keychainPath:)`. Change only the private collector to `metadata(service: String?, account: String?, keychainPath: String?, allowsItemOmissions: Bool) throws -> KeychainMetadataListing`; strict callers pass false and return its references, while browsing passes true. Do not introduce a public policy hierarchy.
- `AccountSetupController.listCredentials(service:account:keychainPath:) async throws -> KeychainMetadataListing` calls `browseMetadata`; no other caller changes to tolerant behavior.
- `AccountMetadataLookupPresentation.State.completed(matches: Int, omittedItems: Int)` carries both counts together. Non-completed cases have no omission count to retain. Keep captured `exactKeychain`, `serviceFiltered` and `accountFiltered` properties and existing initial/pending/failure wording. Add the omission explanation only for a positive omitted count.

## Execution preflight — only after this plan is presented and approved

- [x] Identify the approved specification and this plan and quote their separate approval messages. Record the execution method actually selected for this fix. Load `personal-workflows:spec-implement` and the chosen execution base; resolve the managed `full` model role then. Full tier is required because a row-classification error could weaken credential/recovery checks.
- [x] Recheck `git status --short --branch`, the artifact pair and `HEAD`/`main`/`origin/main`. Safely fetch `origin main`, fast-forward main only if safe, and inspect any intervening relevant changes. Preserve all local artifacts and unrelated changes; never reset/force away conflicts.
- [x] Create `fix/keychain-lookup` from safely updated main in this checkout, after confirming the name is unused. Record actual plan approval and commit only the approved pair with `docs: approve keychain lookup fix`. No worktree, push or merge.

### Task 1: Isolate tolerant metadata browsing from strict lookup [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07

**Files:** Modify `companion/Sources/CompanionCore/KeychainStore.swift` and `companion/Tests/CompanionCoreTests/KeychainStoreTests.swift` only. Risk: omission handling must not hide contradictory or secret-bearing evidence or change recovery's strict lookup semantics.

**Interfaces:** Produce `KeychainMetadataListing` and `browseMetadata` as defined above. Preserve the existing strict public APIs and native Security protocol. Extend `FakeKeychainSecurity` with per-path rows/failures and a search-list failure/count when tests need them; retain current global rows/failure behavior for existing tests.

- [x] **Step 1 — write failing browsing and error-precedence tests.** Add `testBrowsingOmitsOnlyUnusableServiceAccountRows`, `testBrowsingDistinguishesEmptyAndAllOmitted`, `testBrowsingHardFailuresTakePrecedenceOverOmission`, and `testBrowsingFailsWholeListingWhenLaterKeychainFails`. Table-test missing/wrong-type/empty/control/1,025-unit fields, the 1,024-unit boundary, both row orders, and two invalid fields counted once. Include valid Unicode fields within limits, without trimming. For mixed errors use a mismatching string service with a missing account, and a secret-bearing row with missing fields; test service and account filter contradictions independently.

```swift
let listing = try await store.browseMetadata()
XCTAssertEqual(listing.references, [reference])
XCTAssertEqual(listing.omittedItemCount, invalidRows.count)
XCTAssertTrue(fake.added.isEmpty)
```

- [x] **Step 2 — pin strict and scope regressions.** Add `testStrictLookupRejectsRowsThatBrowsingOmits`, `testBrowsingPreservesFilteredAndExactPathScope`, and `testBrowsingQueriesNeverRequestSecretsAndRemainSerial`. Assert `.unsupported` from malformed strict results, valid/genuinely absent exact outcomes, `.invalidReference` for invalid supplied references, existing `.ambiguous` within/across Keychains, and no deduplication/fallback. Assert service/account filter keys, generic-password/file-backed query keys, attributes true, data/ref false, duplicate search-path handling, off-main execution and zero creates. Cover native errors, `.unsupported` decoding-boundary failure, search-list failure and invalid paths; preserve `NativeKeychainSecurity`'s actual decoding/opening guards by inspection. Extend the existing held-creation serial test to include browsing.
- [x] **Step 3 — run RED.** Run `swift test --package-path companion --filter KeychainStoreTests`. Expected: new browsing API/result assertions fail before implementation; retain the exact failure reason. Do not execute live user-Keychain queries.
- [x] **Step 4 — implement the narrow collector change.** Add the listing value and browsing entry point. Keep query construction/native opening/serial execution shared. Check path validity independently of item fields so path failures cannot be counted as item omissions. For each row, reject secret data and every available string/filter contradiction before considering omission; omit only unusable service/account metadata when browsing is enabled. Strict collection throws on those same rows. Accumulate a result locally and publish only after all selected queries succeed. Preserve the native adapter and all creation code.
- [x] **Step 5 — run GREEN and inspect the boundary.** Repeat Step 3; expected all KeychainStore tests pass. Run `git diff --check`; expected no whitespace errors. Inspect that both lookup overloads still use strict collection and that no native query, reader, creation or recovery code was broadened.
- [x] **Step 6 — commit Task 1 paths only.** Stage the two owned paths and commit with `fix: tolerate unusable metadata only when browsing keychain items`. Record tests and commit identity for the eventual validation report.

### Task 2: Integrate omission reporting and verify the complete fix [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10, AC-11

**Files:** Modify the controller, setup view, core controller tests, app presentation/action tests and two guides listed above; create `docs/validation/keychain-lookup-fix.md`. Consume Task 1's listing contract. Risk: the UI/controller must use tolerance solely for browsing and must not turn incomplete results into selection or recovery authority.

**Interfaces:** Change only controller `listCredentials` to return `KeychainMetadataListing`; incoming suggestions/reconciliation remain on strict `lookup`. Update the existing completed presentation case to the named two-count case. The view assigns `listing.references` to its picker and both counts to completion together. Existing start/failure clearing, captured scope and explicit `useMetadata` behavior remain the source of truth; no new state manager is needed.

- [x] **Step 1 — write failing propagation/presentation tests.** Add controller `testCredentialBrowsingReturnsOmissionsWithoutMutation`, `testIncomingSuggestionRejectsMalformedExactEvidence`, and `testRecoveryMalformedMetadataRetainsReceiptAndBlocksRetry`. Assert listing/count propagation; no native add/backend commit/start; unchanged preview/default/bindings; absent receipts/locks remain absent after browsing; and existing recovery evidence remains when strict lookup fails. In presentation tests add `testMetadataLookupReportsOmissionsIncludingZeroMatches` and `testMetadataLookupDoesNotCarryOmissionsIntoPendingOrFailure`, updating old completion constructors. Pin 0/1/plural matches/omissions and captured filter scope, with no rejected-row identifiers in message/error text.

```swift
let listing = try await setup.listCredentials()
XCTAssertEqual(listing.omittedItemCount, 1)
XCTAssertEqual(backend.commits, 0)
let status = AccountMetadataLookupPresentation(
    state: .completed(matches: 0, omittedItems: 2))
XCTAssertTrue(status.message.contains("0 matches"))
XCTAssertTrue(status.message.contains("2 unsupported items omitted"))
```

- [x] **Step 2 — add failing real-view interaction cases.** In AccountSetupActionTests.swift add a small metadata-only `KeychainSecurity` fake using `@testable import CompanionCore`; reuse that file's private `AppAccountBackend` and the existing generic `NativeProjectHost` from ProjectListLayoutTests.swift. Host production `AccountSetupView` against temporary synthetic state. Add `testMetadataBrowserClearsStaleEvidenceWithoutApplyingReferences` and `testMetadataBrowserCapturesScopeWhileFiltersChange`. Exercise valid-plus-omitted, omitted-only, empty, held pending, and failure after prior success, checking disabled Use without selection and unchanged form values/default/no commits. Change a filter while metadata is held and assert the completed scope still describes the original query. Release gates and close owned windows in cleanup; no unbounded waits or real Keychain calls.
- [x] **Step 3 — run RED.** Run `swift test --package-path companion --filter AccountSetupControllerTests`, `swift test --package-path companion --filter AccountSetupPresentationTests`, and `swift test --package-path companion --filter AccountSetupActionTests`. Expected: the new listing/count interfaces and native interaction expectations fail before integration. Existing import/default/recovery assertions retain their meaning.
- [x] **Step 4 — implement propagation and display.** Make the controller browse only in `listCredentials`. Update completed state/message and view result propagation, including zero-match omission explanations. Keep error sanitization and explicit selection unchanged. Add only the accessibility identifiers needed by the real-view tests to the existing lookup/status/filter/picker/Use controls. Reuse existing native test-host interactions; place prefixed `keychain-*` screenshots in its existing ignored `companion/.build/project-list-qa/` output rather than introducing a product fixture mode or screenshot framework. If popup selection cannot be exercised by the harness, retain its disabled/no-auto-selection assertions and cover successful selection in the coordinated human check; report the distinction.
- [x] **Step 5 — run GREEN and inspect synthetic images.** Repeat the three Step 3 commands; expected all pass. Inspect actual rendered screenshots of mixed results, omitted-only, pending/failed and wrapped omission copy at the setup view's existing size. Verify counts/explanation/actions fit and remain reachable through scrolling. Record hosted-fixture observations separately from rebuilt-app observations. Keep screenshot contents synthetic and out of Git.
- [x] **Step 6 — document the shipped behavior and commit integration.** Update operating guide and companion README with bounded row omissions, visible count, whole-lookup failures, optional exact filters and unverified credential access. Create the validation report with actual evidence so far, acceptance-criterion mapping and pending full/native checks explicitly marked unobserved. Run `git diff --check`; expected clean. Commit these owned product/test/documentation paths with `fix: report omitted keychain items in account setup`.
- [x] **Step 7 — run the complete verification chain.** Run `npm run companion:test` (all native tests pass). Before `npm run companion:build`, check whether the canonical dist app is in use and coordinate the user's normal guarded Quit if necessary; its build script deletes/reassembles that fixed output. Run `npm run companion:build` (exit 0 and signed app at `dist/Codex Project Router.app`), `npm test` (all Node regressions pass), then `npm run companion:package-test` (all three existing package cases pass). Preserve known intentional deprecation diagnostics and record actual totals/exits, not predecessor counts. Package checks already use owned disposable native Keychains; do not edit real user items.
- [x] **Step 8 — complete focused rebuilt-app inspection.** Coordinate opening the newly built app using the documented `open "dist/Codex Project Router.app"`, verify the launched path/build, and browse from an unsaved account form with the user's current supported Keychain scope. Observe valid results and omission reporting where present, select a result explicitly to check the form interaction, then dismiss without Save. Do not retrieve secrets, start routing, change private configuration or repeat migration. If controls cannot be inspected directly, request the user's observation; distinguish it from synthetic-image evidence. Do not describe unobserved production conditions as verified.
- [x] **Step 9 — perform the required final review and close out.** Use `personal-workflows:code-review` as the sole final whole-branch gate, with approved spec/plan, full diff/changed-file list and fresh evidence. Its specification review must pass before its quality reviewer runs on the unchanged package; follow the enclosing execution workflow's bounded fix/follow-up policy. Fix within-scope findings and rerun affected checks; broader verification repeats only when changes justify it. After a passing gate, preserve verdict identities/evidence and limitations in the validation report, update artifact lifecycle metadata, and commit documentation closeout with `docs: record keychain lookup validation and review`. Any subsequent product change invalidates the reviewed state and requires the permitted follow-up. Check final status and report exact commits, working app path, evidence, remaining limitations and the reached endpoint; do not push, merge or start another increment.

## Criterion traceability

| Specification | Task and primary evidence |
|---|---|
| AC-01 | Task 1 mixed-row/boundary/count tests |
| AC-02 | Task 1 empty/all-omitted tests; Task 2 presentation/native view |
| AC-03 | Task 1 mixed-error precedence; Task 2 sanitized display and full tests |
| AC-04 | Task 1 native/per-path failures; Task 2 clearing after failure |
| AC-05 | Task 1 filter/path/search-list tests; Task 2 captured scope |
| AC-06 | Task 1 strict exact/ambiguity regressions; Task 2 strict suggestion/recovery tests |
| AC-07 | Task 1 query/serial/no-create assertions; Task 2 no-write tests and existing native package checks |
| AC-08 | Task 2 presentation, hosted interactions, inspected images and rebuilt-app observation |
| AC-09 | Task 2 unchanged form/preview/default/bindings, no-write and recovery regressions; full native/Node/package suites |
| AC-10 | Both tasks' RED/GREEN evidence; Task 2 full chain and labeled fixture/app visual evidence |
| AC-11 | Task 2 guides, validation report, sequential final review and local commits |

## Self-review and handoff

Self-review checked every specification section/AC against the tasks, method/result/case names across task boundaries, error-before-omission ordering, strict recovery callers, native interaction coverage and preservation of form choices. The five Review Focus conditions each have owning tests above. No additional product choice or scope change is proposed. The plan adds no implementation code to this document and no new generalized framework.

**Current stage:** Stage 4 complete — both tasks, rebuilt-app interaction and the sole sequential final review are complete. Full native tests, the full sequential Node suite and isolated package suite passed; the repeated default-parallel native-window observation failure remains explicitly recorded in `docs/validation/keychain-lookup-fix.md`. No assertion/deadline or product scope changed. After the saved plan was presented, the user selected Native execution; after the explicit reminder that plan approval was still pending, the user replied “approved”. This is the separate plan approval. The earlier premature approval is not used as authorization.

**Execution endpoint:** Deliver only the approved Keychain lookup fix with integration, tests, rebuilt app, focused visual inspection, required sequential review, documentation and authorized local commits; report the result, actual evidence and limitations, then stop before broader UI or distribution work. Leave push and merge to a separate user request.

**Completion evidence:** `docs/validation/keychain-lookup-fix.md` records the user's 59 matches, explicit application and unsaved dismissal; native 394/394, sequential Node 1,095/1,095 and isolated package 3/3; original and final default-parallel outcomes; review identities/verdicts, rulings and remaining limitations. Only the approved Keychain increment was implemented. Local commits remain on `fix/keychain-lookup`; push and merge are not authorized.
