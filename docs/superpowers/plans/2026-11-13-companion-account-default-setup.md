# Companion Account/Default Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use `personal-workflows:spec-implement` after this plan receives its own explicit approval.

**Goal:** Add native account creation/import and explicit router-default selection, preserving incoming Codex authentication, existing overrides and original direct recovery.

**Architecture:** Introduce a versioned account configuration with separate incoming verification, outgoing default and original direct destination. Node retains parsing, forwarding, provider recovery and guarded configuration commits; Swift owns native Keychain operations and coordinates a durable setup receipt under the existing recovery/mutation authority. Settings apply only at the next explicit managed Start, initially Off.

**Tech Stack:** Node.js 24 ES modules, existing smol-toml 1.9.1 and built-in filesystem/HTTP/HTTPS/crypto/test APIs; Swift/SwiftUI/AppKit, Foundation/Darwin/Network and macOS Security framework; existing arm64 ad-hoc-signed app packaging and XCTest. No new external dependency or service.

**Spec:** [Approved specification](../specs/2026-11-13-companion-account-default-setup.md)

**Slug:** `companion-account-default-setup`

**Status:** APPROVED

**Created:** 2026-11-13

**Updated:** 2026-11-13

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Subagent-driven, explicitly selected by the user through the native interactive execution-method control after separate plan approval. Full-tier implementers use `gpt-6.1-sol` with high reasoning.

**Provenance:** The approved specification was first presented unsaved in Plan mode. The user's subsequent `PLEASE IMPLEMENT THIS PLAN` message reproduced that specification and accepts the artifact just presented, advancing only its pending specification gate. It does not approve this previously unseen implementation plan. Stage 1 was separately confirmed by the earlier `approved` message. Both approval messages belong to this increment; predecessor approvals are historical inputs only. Save this plan uncommitted in the existing checkout.

## Global Constraints

- "Default designation is explicit, including for the first account." Adding/importing never silently changes the default or a project assignment.
- "Restore direct returns to the preserved desktop connection, which may differ from the router default." Do not rewrite desktop authentication or repurpose the original direct URL.
- "Forms may be browsed while routing runs, but this increment does not save pending configurations. The next explicit Start loads changes in Off. There is no general reload or control-channel expansion."
- "Entered keys remain in native memory, never command arguments, logs, JSON configuration or child-control messages." Keep actual references, endpoints, mappings, checkpoints and raw runtime evidence outside Git.
- "Configuration loading, startup, health, status, activation and recovery retrieve no credentials, execute no desktop authentication helper and perform no destination preflight."
- "Missing explicit targets, unreadable/conflicting identity, inaccessible credentials and upstream failures remain failures." No fallback, alternate-account retry, redirect following or continuation repair.
- Preserve existing On/Off receipt-time capture, endpoint/key pairing, process ownership, context binding, backups, pending confirmation, Stop/Quit and recovery safeguards. Off does not authorize saving or stopping.
- Account editing/deletion, live assignment editing, hiding/reveal, multi-source merge, startup/supervision, general reload, pending running changes and comprehensive redesign remain deferred. Preserve the two accepted viewport/focus observations and live `499/CANCELLED` qualifications.
- Use the existing checkout; no worktree. Before implementation, require separate approval of this plan, safely update `main`, create `feat/companion-account-default-setup`, and commit the approved pair there. Preserve all unrelated changes. No push or merge.

## Review Focus

1. A default at a different HTTPS origin must never receive the original incoming desktop token; authentication and selected outgoing credential substitution are separate even for catalog/title requests — Task 2.
2. An enabled alias whose target is missing must remain an error, while an imported legacy label intentionally inherits; equal-to-global explicit targets must remain explicit after a later default change — Tasks 1–3.
3. A native Keychain write may succeed immediately before cancellation, crash, configuration failure or lost helper acknowledgement; reconciliation must use the predetermined item identity and actual committed state, never repeat creation or infer rollback — Tasks 4–5.
4. Default/account corruption must not destroy original direct recovery or make an active context look like a fresh setup destination; unsafe core/record evidence must still block — Tasks 1, 3 and 5.
5. A listener, changed file or outstanding helper can appear between preview, Keychain consent and commit; freshness, shared locking and generation checks must reject the write without discarding recovery or adopting another process — Tasks 3 and 5.

## Repository evidence and artifact resolution

Planning baseline is `5acdcaf212e6bc3df3a75e9c554f55191f27a393` on `main`, clean before saving the approved specification. The previously inspected actual remote `main` matched and PR #6 was merged. Recheck at execution; do not fetch, update main or create a branch while this plan awaits approval.

Specification resolution is `NEW_ONLY` at the linked path after saving its approved chat content. Plan resolution was `MISSING`, including the exact legacy path; this new plan uses the specification's exact basename and shared slug. Both documents were created on 2026-11-13. No legacy artifact is changed.

No `docs/architecture/map.md` or applicable ADR was found. Architecture-map freshness, recorded HEAD and ADR status are unavailable, rather than assumed current. Key-path inspection covered `src/config.js`, `src/proxy.js`, `src/activation.js`, `src/companion.js`, `src/companion-cli.js`, both serving entries, native wire/backend/controller/private-store/UI files, existing fixtures and package assembly/tests. Do not generate an architecture map during planning.

`package.json`, README and companion/README supply the acceptance commands: `npm test`, `npm run companion:test`, `npm run companion:build`, `npm run companion:package-test`, `node --check src/cli.js` and `git diff --check`. The package script builds release Swift products and signs the app; the existing package suite contains exactly three tests. Focused file/filter invocations already appear in predecessor plans and test sources; this plan uses the existing full script commands for task gates so new files are included automatically.

No tests, builds, Keychain queries or operational mutations ran during planning. The 160 native/718 Node/three package results belong to the predecessor and are not this increment's acceptance.

## Data and interface decisions

These are implementation choices within the approved behavior, not additional product scope. Later tasks consume these contracts exactly.

### Account configuration and recovery projection

Keep schema 1 parsing, CLI serving and fingerprints unchanged. New/migrated files use `schemaVersion: 2`, retain existing operational top-level fields and optional-property absence semantics, and replace `credentialRouting` with:

```text
accountRouting: {
  incomingCredential: CredentialReference | null,
  defaultAccountId: UUID | null,
  accounts: { [UUID]: { displayName, upstreamBaseUrl, credential: CredentialReference } },
  routeAccounts: { [existingAlias]: UUID | null }
}
```

`upstreamBaseUrl` at the top remains the original direct destination. A null route-account value means explicit imported legacy inheritance; an absent entry for a saved enabled alias means missing target, never inheritance. An account ID that is present must resolve to a complete account. New writers create no dangling account references. Empty accounts and null verifier/default are structurally valid incomplete setup; malformed account structures are invalid setup. Unknown fields and obsolete enabled formats reject for serving/writing. Use existing UUID/alias/reference/URL rules and the specification's name rules; deep-freeze loaded routing data.

`loadRouterConfig(configPath)` remains the strict serving loader. Add `inspectRouterConfiguration(configPath) -> {config, setupState, configurationRevision}` for companion/writer inspection and `loadRecoveryConfig(configPath)` for validated operational fields only. `setupState` is `ready | required | migration_required | invalid`; a schema-1 file is `migration_required` for new companion starts only. The recovery loader accepts only supported versions, safe files, valid operational fields and mappings; it must not reinterpret unknown versions or malformed JSON. Invalid accounts may disable routing while validated core and activation records still permit restoration.

`configFingerprint` preserves historical schema-1 bytes. Schema-2 fingerprints include operational fields, canonical account/reference/default/binding configuration and optional policies, never secret values or their hashes. Invalid-account recovery uses a separate operational revision and cannot publish matching routing readiness. Configuration-write revision checks compare exact validated non-secret source bytes through a private token; never hash raw provider authentication or malformed account content to manufacture a usable revision.

Schema-2 standalone `serve` uses the new account selection but retains its historical mapped-project admission requirement when no managed mode getter is supplied. The companion-managed path retains inheritance. Both serving entries reject incomplete/invalid schema-2 setup before listening. Do not change schema-1 standalone behavior.

### Setup bridge, guarding and durable receipt

Extend the one-shot companion bridge, not the managed mode protocol. Add `setup_preview` and `setup_commit` actions. Existing inspect/activate/rollback inputs keep their 16 KiB cap; setup requests use a separate 1 MiB input cap and the existing 1 MiB output cap, with fixed safe errors and no partial output. Swift uses the same bounds and sanitized environment; no key value enters either action.

`previewAccountSetup({configPath, browseHome}) -> SetupPreview` returns validated prospective/selected `context`, private `configurationRevision`, `setupState`, source kind, account/alias preview, safe helper metadata and an original-direct candidate. Missing-file preview is allowed only at an explicit private destination with a compatible direct provider and no conflicting saved recovery context. Unsupported helper forms receive no inferred item; explicit matching-item confirmation remains available. Provider parsing is shared with activation's existing compatibility rules rather than reimplemented permissively.

Safe helper metadata means only `incomingHint: {service, account, keychainPath?}` from an exact recognized `/usr/bin/security` generic-password query with single service/account flags and password-only output. Reject duplicated/unknown/transforming arguments as inference sources; never return raw helper commands/arguments. With no explicit keychain path, native metadata must establish an unambiguous item before suggesting it. Every suggestion still requires user confirmation; an opaque helper uses manual matching-item selection.

`commitAccountSetup({configPath, expectedContext, expectedRevision, operationId, change}) -> SetupCommitResult` applies exactly one `create_configuration | migrate | add_account | set_default` change. `change` contains account metadata/references, naming choices and explicit default/verifier decisions only. Existing mappings and paired references are loaded/preserved in Node, not reconstructed from project rows. Every result returns saved setup state/revision without claiming credential/gateway success.

For setup writes, Swift's `SetupTransactionStore` exclusively creates the existing per-configuration `.activation.lock` with `{pid, setupOperationId, configPath}` and owner-only protections. This holds the same exclusion across native consent and the final Node commit. Commit validates that exact live setup lease instead of acquiring a second lock; ordinary activation/rollback retain exclusive-create behavior. Both serving entries reject a setup lease before startup. Acquire the lease before the authoritative direct/port/revision check, then recheck before each irreversible step. Never delete a replaced/unsafe lock or auto-remove a stale one. After interruption, show receipt/context plus the existing manual lock-resolution guidance; do not adopt or signal the recorded PID.

`SetupTransactionStore` keeps one owner-only `account-setup.json` receipt beside the selected configuration, separate from the existing companion journal. Before native creation it durably records operation/account UUIDs, exact planned item reference, candidate non-secret account metadata, context and phase `prepared`. Phases advance to `item_created`, `committing`, then `complete` only from observed outcomes. A creation crash with a prepared receipt is reconciled by exact metadata lookup, without reading the secret or creating another item. A helper timeout/nonzero exit may follow a committed rename: retain the lease/receipt, await helper exit and inspect the saved account/reference before declaring success/failure. Proven pre-commit failures leave the old file unchanged; the old private checkpoint remains available even after an uncertain operation proves committed. Never automatically roll back or replay a mutation.

### Native contracts and presentation

Create `AccountTypes.swift` with `CredentialReference`, `AccountRecord`, `SetupPreview`, `SetupChange`, `SetupCommitResult` and `SetupReceipt` matching the Node contracts. Extend `Inspection.Configuration` with optional `setupState` and `defaultAccount: AccountSummary?`, where `AccountSummary` has `id` and `displayName`; add mode `accounts`. Extend entries with optional `account: AccountSummary?` and `assignmentKind: override | inherited | legacy_inherited | target_missing`. Schema-1 wire fields remain decodable and keep their meanings. Full references/prefixes are returned only for explicit setup, not routine project rows.

Add `AccountSetupBackend` for `previewSetup(configPath:browseHome:)`, `commitSetup(_:context:revision:operationID:)` and `probeSetupPort(_:)`, implemented by `ProcessBackend`. Keep `CompanionBackend` and its test doubles focused on existing routing/recovery, except for the new setup-readiness checks needed at Start/activation. Expose setup helper uncertainty through the same authoritative mutation guard so Stop/Quit cannot bypass it.

`KeychainStore` offers async metadata listing/exact lookup and `createGenericPassword(reference:secret:)` through a serial native execution queue. Production uses file-backed keychains in the user's search list/default selection, explicit paths, native generic-password APIs and a narrow ACL for the companion plus fixed `/usr/bin/security` reader. Do not grant all-applications access or persist secrets. Unsupported Data Protection/iCloud-only items cannot be passed to the existing path-based reader. File-backed/ACL API deprecation diagnostics are a documented compatibility tradeoff; do not hide them through global compiler-warning suppression. Fake Security dependencies drive ordinary automated tests.

`AccountSetupController` coordinates preview/form state, native metadata/creation, receipt and configuration commit. It consumes fresh `RouterController` setup authorization, locks conflicting routing/configuration actions during a mutation, and drops stale async results by context generation and operation ID. No public form getter grants save permission. `RouterController` remains authority for ownership, pending recovery, direct confirmation and Quit; add `canBeginAccountSetup`, `beginAccountSetup() async throws -> SetupPreview` and `finishAccountSetup()` to reserve/release its existing serialized action/inspection boundary. Revalidate port/direct state under the setup lease rather than trusting the preview or a cached enabled button.

Read-only form preview may run while routing is active. Call `beginAccountSetup` only for an explicit save/create action, not merely opening the form. A setup-helper timeout retains an `uncertainSetupOperationID`; ordinary direct provider inspection alone cannot clear it. Reconciliation also requires the receipt and saved account/default result for that operation, or a proven pre-commit failure, after the exact helper exits.

Use one `AccountSetupView` sheet for add/create/import preview and explicit choices; add a default picker and relevant Add/import actions beside the everyday default display. Adding retains the current default; initial setup requires a separate explicit designation. Incoming credential and reference details stay in Settings/Advanced. The sheet does not edit project assignments. Once native creation begins, dismissal/cancellation cannot pretend it was undone; show progress, cancellation outcome or created-but-unlinked reconciliation. Closing Controls retains current router behavior and cannot discard a pending mutation/receipt.

## File responsibilities

| Area | Owned paths |
|---|---|
| Versioned configuration/recovery | Modify `src/config.js`, `src/activation.js`, `src/errors.js`, `src/companion.js`; extend their existing tests |
| Request selection | Modify `src/proxy.js`, `src/managed-serve.js`, `src/cli.js`; extend proxy/managed/CLI tests |
| Setup validation/migration/commit | Create `src/account-setup.js`, `test/account-setup.test.js`; extend `src/companion-cli.js` and bridge tests |
| Native credential and transaction boundary | Create `companion/Sources/CompanionCore/AccountTypes.swift`, `KeychainStore.swift`, `SetupTransactionStore.swift` and corresponding CoreTests |
| Native coordination | Create `AccountSetupController.swift` and tests; modify `WireTypes.swift`, `ProcessBackend.swift`, `RouterController.swift`, their fixtures/tests and app construction |
| Native UI | Create `companion/Sources/CodexProjectRouter/AccountSetupView.swift`; modify `ControlsView.swift`, `RouterApp.swift` and app tests |
| Delivery | Modify build allowlists, three existing package tests and both READMEs; create `test/helpers/keychain-package-probe.swift`, a synthetic schema-2 example and `docs/validation/companion-account-default-setup.md` |

## Execution preflight — only after separate plan approval

- [ ] Identify the Stage 1 `approved`, the later specification-accepting message and the separate future plan-approval message. Both artifacts must be saved and the execution method selected before implementation. Resolve the managed full model role at execution time.
- [ ] Check current checkout/status/HEAD, actual remote `main` and refs without discarding local work. After approval only, fetch/update `main` safely; preserve the two expected uncommitted artifacts and all unrelated changes. Stop on diverged/conflicting evidence rather than reset or force.
- [ ] Create `feat/companion-account-default-setup` in the existing checkout, then commit the approved pair with `docs: approve companion account default setup`. Do not create a worktree, push or merge.

### Task 1: Add account configuration and independent recovery inspection [size: L | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-01, AC-04, AC-05, AC-08, AC-09

**Files:** Modify configuration/activation/error/inspection modules and `test/config-identity.test.js`, `test/activation.test.js`, `test/companion.test.js`, `test/helpers/fixtures.js`.

**Interfaces:** Produce the schema-2 configuration, three loader/projection contracts, fingerprint rules and additive inspection summaries above. Preserve schema-1 loader/CLI semantics. Add fixed `ACCOUNT_SETUP_REQUIRED`, `ACCOUNT_SETUP_INVALID` and `ACCOUNT_SETUP_CONFLICT` errors; no private values in messages.

**Risk:** Routing data may be invalid while original direct recovery is still required; a permissive operational projection must not weaken core/record validation.

- [ ] **Step 1: Write configuration/recovery tests.** Add `account schema separates incoming default and direct identities`, `legacy inheritance differs from missing override`, `account fingerprints preserve historical compatibility`, and `invalid account setup retains validated offline recovery`. Assert null/missing/default/reference/name validation, exact own-property lookup, deep freeze, full prefixes, account/name case collisions, malformed JSON/unknown-version rejection, unchanged schema-1 fingerprints, and no credential-reader/helper/destination calls. In custom activation directories corrupt only accounts/default after synthetic activation; rollback must preserve auth/models/unrelated later edits and restore the original URL. Corrupt core/context/record evidence separately and require conflict, not recovery permission.
- [ ] **Step 2: Run RED.** Run `npm test`. Expect missing schema/projection/error behavior to fail before implementation; distinguish stale package artifact failures/skips from the new decisive failures.
- [ ] **Step 3: Implement loaders and inspection.** Share existing operational/provider validation, add strict account validation and setup states, and use the recovery projection only for status/rollback. Activation/new serving still require complete valid routing data. Browsing uses independently validated catalog/core data without fabricating fresh entries. Never hash/read authentication material for revision identity.
- [ ] **Step 4: Run GREEN.** Run `npm test` and `node --check src/cli.js`; expect new behavior and existing non-package regressions to pass. Record package artifact status honestly until Task 7 rebuilds it.
- [ ] **Step 5: Commit/review.** Commit only Task 1 changes as `feat: separate account setup from direct recovery`. Complete the selected execution method's task gate before Task 2.

### Task 2: Route default traffic with independent incoming authentication [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-03, AC-04, AC-08, AC-09

**Files:** Modify `src/proxy.js`, both serving entries and their existing tests; reuse Task 1 fixtures and the existing bounded credential reader.

**Interfaces:** Consume Task 1 schema. Preserve `createProxy(config, options)` and receipt-time mode getter. Schema-2 selection verifies `incomingCredential`, then retrieves the chosen account credential separately. Both entries reject incomplete setup/setup leases before binding; managed mode remains initially Off.

**Risk:** Retaining caller authorization on a newly selected default origin would leak the wrong token and break authentication isolation.

- [ ] **Step 1: Write exact-origin selection tests.** Add `independent incoming token never reaches selected default origin`, `explicit old-global override survives default change`, `legacy inherited label is not a missing override`, and `account mode capture survives pending authentication and streaming`. Use synthetic INCOMING/DEFAULT/OVERRIDE sentinels and separate HTTPS origins/prefixes; assert exact Authorization, Host, body/query bytes and per-origin call counts for Off, On inheritance/override, catalog, qualifying titles and compaction. Bad incoming authentication must precede broken identity/account work. Cover missing/inaccessible account, credits/upstream 401/402/429/5xx, redirects/TLS/disconnects, cancelled lookups, key rotation, active streams and reused sockets with zero alternate-origin calls/retries. Preserve schema-1 zero-Keychain/CLI cases.
- [ ] **Step 2: Run RED.** Run `npm test`; expect wrong-default forwarding/missing schema-2 selection assertions before product edits.
- [ ] **Step 3: Implement account selection.** Resolve complete account pairs through own-property membership; preserve Off suspension, explicit legacy inheritance and missing-target errors. Substitute selected authorization after hop filtering for every forwarded schema-2 operation. Keep incoming verification before metadata/identity, ordinary request cancellation and unmanaged mapped-project admission. Do not alter the reader/control protocol.
- [ ] **Step 4: Run GREEN.** Run `npm test` and `node --check src/cli.js`. Require exact isolated-origin assertions and existing mode/transport tests to pass; retain genuine artifact qualifications until rebuild.
- [ ] **Step 5: Commit/review.** Commit as `feat: select outgoing defaults independently of desktop auth`; complete the selected task gate.

### Task 3: Implement deterministic migration and guarded configuration commits [size: L | risk: migrations | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: migrations,data,security]

**Acceptance criteria:** AC-01, AC-04, AC-05, AC-06, AC-07, AC-08

**Files:** Create `src/account-setup.js` and its tests; modify activation's shared provider-inspection seam, companion bridge/CLI, error definitions and bridge/activation tests.

**Interfaces:** Produce `previewAccountSetup` and `commitAccountSetup` plus the exact one-shot requests, limits and setup-lease validation above. Preview proposes one account for each complete source target plus an original-global candidate, with stable generated IDs carried through commit; preserve distinct aliases/pairs without deduplication. An existing legacy label serializes as a null route binding; an unresolved enabled alias has no binding. No account/default edit is reconstructed from the catalog.

**Risk:** Migration must preserve meanings and bytes/evidence while first creation must not overwrite a missing-but-unavailable or previously active context.

- [ ] **Step 1: Write migration/save tests.** Add `enabled migration preserves explicit old-global and unused pairs`, `legacy migration preserves labels as inheritance`, `default requires explicit confirmation`, `first setup preserves compatible desktop configuration`, `commit rejects changed context revision lock or listener`, and `failed commit preserves original and checkpoint`. Cover aliases such as own `constructor`, case-sensitive mapping keys, duplicate display names resolved in preview, empty/missing targets, optional-property absence, arbitrary unsupported auth helpers with no inferred reference, existing/missing/unsafe destination files, lock replacement, stale previews and a listener arriving after preview. Assert exact source checkpoint bytes/modes, preserved context/activation files and zero secret/helper/preflight operations.
- [ ] **Step 2: Run RED.** Run `npm test`; expect missing setup actions/exports and preservation assertions to fail for the intended reasons.
- [ ] **Step 3: Implement setup operations.** Read valid source or compatible direct-provider metadata, return explicit preview, then under the validated native setup lease recheck context/direct state/empty port/exact source revision. Make a private exclusive checkpoint before atomic configuration replacement. Keep user naming/default/verifier choices explicit; reject unsafe/oversize/obsolete input without partial writes. Unknown/unresolved recovery evidence blocks first creation rather than redirecting it to the normal directory.
- [ ] **Step 4: Run GREEN.** Run `npm test` and `node --check src/cli.js`; require bridge bounds, no secret output and existing activation/recovery regressions to pass. Test conflicting activation cannot acquire the setup-held `.activation.lock`; status inspection must remain read-only/available.
- [ ] **Step 5: Commit/review.** Commit as `feat: migrate account configurations through guarded saves`; complete the selected task gate.

### Task 4: Add native Keychain metadata, creation and durable setup receipts [size: L | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security,data]

**Acceptance criteria:** AC-01, AC-02, AC-06, AC-07

**Files:** Create `AccountTypes.swift`, `KeychainStore.swift`, `SetupTransactionStore.swift` and corresponding tests under the existing CompanionCore targets. Modify `Package.swift` only if explicit Security framework linking is required; retain platform/toolchain/dependency policy.

**Interfaces:** Produce the native contracts and receipt/lease phases above. `SetupTransactionStore.begin(context:operationID:receipt:)` creates and durably validates the exact lease/receipt; `advance(_:)`, `load()` and `finishVerified()` preserve ownership, mode and inode checks. Only observed completed reconciliation permits releasing this instance's lease; stale/replaced evidence is not auto-deleted.

**Risk:** A secret must never cross process/storage boundaries, and an uncertain native return cannot authorize duplicate item creation or discarded evidence.

- [ ] **Step 1: Write fake-native and storage tests.** Add `testMetadataQueriesNeverRequestSecretData`, `testCreateUsesExactPrivateItemAndNarrowReaderACL`, `testDuplicateDeniedLockedAndCancelledItemsStayVisible`, `testReceiptPrecedesCreationAndSurvivesRelaunch`, and `testReplacedUnsafeLeaseIsPreserved`. Assert zero native delete/update/unlock calls, exact token bounds/no trimming, default/search-list selection without changing the user's choice, no secret in encoded requests/receipts/errors, and regular/single-link/current-owner/0600/0700 storage. Simulate creation succeeding before receipt advancement; exact metadata reconciliation must find the planned identity without another add.
- [ ] **Step 2: Run RED.** Run `npm run companion:test`; expect missing types/native seams before implementation, without actual user Keychain access.
- [ ] **Step 3: Implement native operations and storage.** Use explicit file-backed keychains and native APIs with attributes-only queries. Restrict newly created item access to companion/fixed reader; unsupported APIs/items fail visibly. Run potentially interactive native calls serially away from the main actor, retain the operation through consent/cancellation and discard secret buffers when the native result is known. Persist intent before invoking creation and keep completed/unlinked outcomes distinct. Reuse PrivateStore's proven descriptor validation/atomic-write style without broad refactoring.
- [ ] **Step 4: Run GREEN.** Run `npm run companion:test`; fake tests must prove native query/ACL/storage calls and crash boundaries. Reserve actual disposable-Keychain/packaged-reader acceptance for Task 7/8; do not claim it from mocks or add real credential reads to ordinary unit tests.
- [ ] **Step 5: Commit/review.** Commit as `feat: create native account credentials with durable receipts`; complete the selected task gate.

### Task 5: Coordinate setup saves with native ownership and recovery [size: L | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,security]

**Acceptance criteria:** AC-01, AC-05, AC-06, AC-07, AC-08, AC-09

**Files:** Create `AccountSetupController.swift`/tests; modify wire/backend/controller/private-store integration only where required, their fixtures/tests and app dependency construction.

**Interfaces:** Consume Tasks 1–4 contracts. Produce `AccountSetupBackend`, RouterController setup reservation and setup state/actions described above. Additive wire fields/enum values must be validated by `ProcessBackend.valid`; schema-1 fixtures remain valid. No default backend implementation may silently report safe mutation reconciliation.

**Risk:** Stale previews, OS consent, helper timeouts and window/Quit reentry must not permit routing/configuration mutations against a different context or lose created-item evidence.

- [ ] **Step 1: Write held-boundary tests.** Add `testSetupRequiresFreshStoppedDirectSettledContext`, `testPreviewCannotAuthorizeLaterSave`, `testHelperTimeoutRetainsLeaseAndReconcilesCommittedAccount`, `testPreparedReceiptNeverRetriesKeychainCreation`, and `testIncompleteAccountsKeepBrowsingAndOriginalRecovery`. Hold initial inspection, lease acquisition, native completion, helper exit and a newer refresh independently. Inject new listeners, file/context changes, pending recovery, background reentry, initialization failure, app close/reopen and lost replies. Assert current generations win, setup disables conflicting writes/Start/Quit while uncertain, existing recovery authority remains intact and no mutation is retried or external process signalled.
- [ ] **Step 2: Run RED.** Run `npm run companion:test`; expect missing setup integration/authority before edits.
- [ ] **Step 3: Implement coordination.** Reserve RouterController's serialized action boundary, acquire the setup lease, perform fresh authoritative checks and persist intent before native work. Recheck under lease before commit; pass only metadata to Node. Reconcile native/helper uncertainty from actual item/configuration evidence after completion; distinguish proven failure from lost acknowledgement. On relaunch, show pending receipt and existing manual stale-lock guidance, never auto-create, auto-commit or clear unsafe evidence. Legacy/new incomplete configuration disables new managed Start/activation in both controller action and backend, not merely button presentation.
- [ ] **Step 4: Run GREEN.** Run `npm run companion:test` and `npm test`. Require unchanged existing mode/Stop/Quit/pending-journal/uncertain-helper behavior plus new setup contracts. No synthetic success grants desktop response confirmation.
- [ ] **Step 5: Commit/review.** Commit as `feat: guard account setup with router recovery authority`; complete the selected task gate.

### Task 6: Present account addition, import and explicit default designation [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-01, AC-04, AC-05, AC-07, AC-10

**Files:** Create `AccountSetupView.swift`; modify `ControlsView.swift`, `RouterApp.swift`, existing presentation/guidance tests and add focused account-setup app tests.

**Interfaces:** Consume Task 5 setup controller and additive inspection summaries. Preserve existing six Quit-guidance destination identities and controls-window lifecycle. Present display names as accounts and legacy aliases as inherited labels, not invented overrides.

**Risk:** Unit projections cannot prove actual native concealed entry, consent, keyboard reachability or visual guidance; Task 8 owns that evidence.

- [ ] **Step 1: Write presentation/action tests.** Add `testFirstAccountNeedsExplicitDefault`, `testAddingAccountPreservesDefaultAndAssignments`, `testImportShowsPreservedAndUnresolvedBindings`, `testSetupRequiredKeepsCatalogAndRecovery`, `testCreatedButUnlinkedStateDoesNotOfferBlindRetry`, and `testAccountPresentationPreservesQuitGuidance`. Assert concealed entry is the only key-entry UI, selected incoming item/default are separately confirmed, errors never echo secret sentinels, and disabled save explains required recovery/Stop. Account forms never expose project-assignment editing or automatically activate.
- [ ] **Step 2: Run RED.** Run `npm run companion:test`; expect missing account presentation/actions before implementing views.
- [ ] **Step 3: Implement focused native presentation.** Add everyday default display/selection and Add/import entry points; use one setup sheet with existing-item and concealed-entry branches, import preview and explicit final choices. Keep incoming credential, complete prefixes/reference details and technical facts secondary while setup/failures remain visible. Display configured/unverified status honestly. Preserve ordinary close/reopen, mode actions, search/discovery and targeted Quit guidance; do not absorb the accepted viewport/focus fixes.
- [ ] **Step 4: Run GREEN.** Run `npm run companion:test`; require focused account projections and all existing app/core lifecycle tests to pass. Leave actual native observations explicitly pending.
- [ ] **Step 5: Commit/review.** Commit as `feat: add native account and default setup controls`; complete the selected task gate.

### Task 7: Package and verify the complete setup flow [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-02, AC-05, AC-06, AC-08, AC-09, AC-10, AC-11

**Files:** Modify `scripts/build-companion.mjs`, `test/companion-package.test.js`, both READMEs; create `examples/router.accounts.example.json` with synthetic values and start `docs/validation/companion-account-default-setup.md`.

**Interfaces:** Add `account-setup.js` to both explicit production source allowlists. Extend the existing three package tests, not their number. Keep current minimal environment, signed relocation and source-denial native launch checks. Ordinary package fixtures use existing references without secret retrieval; a separately confined owned disposable-Keychain subcase exercises actual creation and the bundled reader with a synthetic secret retained in memory.

**Risk:** File-backed Keychain behavior and packaged reader access cannot be established by mocks or a source-checkout-only flow.

- [ ] **Step 1: Add packaging/native integration assertions.** Extend assembly allowlists and relocated/source-denied schema-2 inspect/create-or-migrate/Start-Off/activate/rollback cases. Retain schema-1 standalone compatibility and browsing fixtures; fixtures that exercise new companion Start must use ready schema 2. Create `test/helpers/keychain-package-probe.swift` as a test-only `@main` harness, compiled into a temporary executable with the production `WireTypes.swift`, `AccountTypes.swift` and `KeychainStore.swift` by the installed Swift compiler. It creates a positively owned temporary keychain/item using public synthetic fixture values held in native memory, then invokes the bundled credential reader via installed Node; the child compares the same public synthetic fixture in memory and returns only a fixed pass/fail marker. Pass only paths/references, never key/password values, through argv/stdin/output. Observe exact metadata, no duplicate/update/delete on user items, and cleanup only the owned scratch keychain. If native creation changes the search list, remove only its owned temporary entry and preserve concurrent unrelated changes; never restore an old whole list or change the default keychain. Do not weaken source-denial/privacy checks or add a product test-mode CLI.
- [ ] **Step 2: Run RED.** Run `npm test` before resource allowlist changes. Require decisive missing-resource/assertion failures rather than count a stale artifact as new behavior. Keep actual native-Keychain subcase pending until its current harness/app are built.
- [ ] **Step 3: Update resources and documentation.** Document first setup, explicit incoming/default roles, migration rules, add-only lifecycle, configured versus accessible status, safe save/restart boundary, created-but-unlinked receipts/stale locks, preserved direct recovery and deferred assignment editing. Exclude real configuration and private metadata from the bundle. Describe any unavoidable file-backed Security API diagnostics honestly.
- [ ] **Step 4: Run fresh acceptance.** Run `npm run companion:test`, `npm run companion:build`, `npm test`, `npm run companion:package-test`, `node --check src/cli.js`, and `git diff --check` in that order. Require current signed app, full passing suites and exactly three package tests with zero skips, including the actual native-create/bundled-reader subcase. Record counts, exits, diagnostic dispositions, bounded output, negative source controls, unchanged original settings and exact child/keychain/port cleanup. A blocked native subcase remains incomplete; do not replace it with mocks.
- [ ] **Step 5: Commit/review.** Commit as `feat: package and document account default setup`; complete the selected task gate, retaining native/live items not yet observed as pending.

### Task 8: Observe native setup, validate the default and close the increment [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: security]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-06, AC-07, AC-08, AC-10, AC-11, AC-12

**Files:** Complete `docs/validation/companion-account-default-setup.md`; update only actual lifecycle/checklist metadata in the approved pair. Product defects return through the selected execution/fix policy; material changes need renewed approval.

**Interfaces:** Consume current signed app, completed task evidence and `personal-workflows:code-review` integrated sequential final gate. The parent owns human-assisted native/live validation and recovery, irrespective of execution method.

**Risk:** Native access consent, actual gateway outcomes and settings loaded by Codex require bounded attributed observations; passing local tests alone cannot close them.

- [ ] **Step 1: Observe isolated native setup.** Use a relocated signed app with synthetic private homes/configuration/catalog and the established source/real-private-path/non-loopback confinement. Observe missing-default browsing, first setup, legacy/enabled preview, duplicate/name/prefix errors, concealed input/existing-item selection, explicit first default, default changes blocked while running, unlinked receipt/relaunch guidance, ordinary cancellation and existing Quit navigation. Use owned disposable Keychain state for actual native creation/consent; never select or modify real items for fixture checks. Record keyboard/visual observations separately from projection tests and preserve the two accepted predecessor UI limitations. Clean tracked resources and independently verify absence.
- [ ] **Step 2: Establish live prerequisites privately.** Reinspect actual selected configuration, direct/recovery state and all bound contexts; privately checkpoint owned router/provider/optional fields and records, preserving unrelated edits. Use existing compatible references and disposable chats/projects, with an explicit original incoming verifier and a distinct outgoing-default pair. Show the intended private import/default choices locally; the user confirms them through native UI. If the user cannot provide a distinct usable pair or recovery cannot be guaranteed, record live acceptance incomplete and do not improvise another account or activation.
- [ ] **Step 3: Run the bounded live flow.** From settled Direct/stopped state, migrate/setup and designate default explicitly; Start Off, integrate through unchanged auth and existing URL-only/manual-restart/response safeguards. Observe a default request, On inheritance and preserved explicit override using a fresh disposable chat where appropriate. With a real dependency, perform normal direct recovery/confirmation/owned Stop before saving another default; restart the listener explicitly in Off and observe that change while incoming auth remains unchanged. Capture symbolic selection/initiating transport outcomes and user-visible reports separately. No assignment editing, load/billing test, key rotation or continuation repair is added.
- [ ] **Step 4: Finish exact recovery.** Restore original owned router/provider settings and optional-property presence, preserving unrelated new settings and the correct configuration's own records. Obtain required manual restart/working-direct-response confirmation before stopping the exact owned listener; independently verify final direct/restored state, no unresolved pending operation, listener absence and native fixture cleanup. Preserve new completed private evidence; never remove user Keychain items. Missing/failed recovery remains pending and visible.
- [ ] **Step 5: Consolidate and review.** Record actual native/setup/Keychain/live outcomes, commands/exits, failures/unrun cases, warnings, exact restoration and limitations. Commit evidence as `docs: record account default setup acceptance`; complete the selected task gate. Run the sole final sequential specification review then quality review with immutable whole-branch evidence under `personal-workflows:code-review`; quality starts only after specification PASS. Apply only the permitted fix/evidence wave and rerun affected checks. Do not dispatch a duplicate final gate.
- [ ] **Step 6: Close out locally.** Mark criteria/checklists complete only when required evidence actually exists, commit documentation-only closeout if needed, run `git diff --check` and `git status --short --branch`, and report actual branch/commits, working behavior, validation, limitations and recovery. Stop before the next increment, push or merge.

## Criterion traceability

| Criterion | Owning tasks and decisive evidence |
|---|---|
| AC-01 | 1 schema/names/identity; 3 explicit migration/default; 4 native metadata/create; 5 guarded action; 6 UI; 8 observed setup |
| AC-02 | 4 fake Security call/ACL/privacy cases; 7 actual owned Keychain plus bundled reader; 8 native consent/selection observation |
| AC-03 | 2 distinct incoming/default/override origins across operations; 8 bounded live different-default evidence |
| AC-04 | 1 typed inheritance/missing state; 3 exact migration/checkpoints; 6 preview; 8 observed preserved bindings |
| AC-05 | 1 incomplete recovery projection; 3 first creation; 5 controller/backend start checks; 6 browsing; 7 relocated fixtures |
| AC-06 | 3 under-lease rechecks/conflicts; 4 durable lease; 5 held boundaries/reentry; 7 startup resources; 8 safe-stop save sequence |
| AC-07 | 3 atomic write/checkpoint failures; 4 predetermined receipt identity; 5 crash/late acknowledgement/relaunch; 8 native reconciliation |
| AC-08 | 1 custom-context/corrupt-account rollback; 3 preserved operational identity; 5 existing recovery authority; 7/8 actual cleanup |
| AC-09 | 1 canonical fingerprints/schema-1 compatibility; 2 exact request/failure/stream evidence; 5 uncertainty; 7 integrated regressions |
| AC-10 | 5 setup/error state; 6 focused native interface; 7 usage docs; 8 actual keyboard/visual observations |
| AC-11 | 7 fresh full acceptance/current signed artifact/three zero-skip package cases; 8 native/live outcomes and exact recovery |
| AC-12 | 7 documentation skeleton; 8 complete evidence, sole sequential final gate, local closeout and stop |

## Self-review and approval handoff

Self-review: all AC-01–AC-12 have owning tests/observations; all five Review Focus cases have explicit task coverage. The schema/typed inheritance, incoming/default/direct identities, preview/commit actions, native DTOs, setup lease/receipt and controller method names are consistent across producers and consumers. The receipt precedes native side effects; pre-commit failure and post-commit uncertainty are distinguished. Tests do not prove native observations, and configuration validity does not prove secret/gateway availability. Later roadmap capabilities and accepted predecessor UI fixes have no implementation tasks here.

No unresolved product clarification remains after the four native answers and scope/specification approvals. Private encoding, native ownership and module choices above are planner decisions within that scope. The user separately approved this plan with `plan approved` and then explicitly selected Subagent-driven execution. Both approvals precede product implementation.

**Execution endpoint:** Only this account/default setup increment, with verification/review, exact operational recovery, local commits and a truthful result/limitations report. Stop before subsequent increments, push or merge.

**Current stage:** Stage 4 — implementation authorized. The user separately approved the specification through the message reproducing it, approved this separate plan with `plan approved`, and selected Subagent-driven execution through the native control. Both approved artifacts are saved. Execution follows the existing-checkout Git workflow; push and merge remain unauthorized.
