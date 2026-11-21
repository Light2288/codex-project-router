# Keychain lookup fix — specification

**Slug:** `keychain-lookup-fix`  
**Type:** bug  
**Status:** APPROVED  
**Created:** 2026-11-20  
**Updated:** 2026-11-21\
**Provenance:** The user's request to clean the merged checkout and move to the Keychain lookup fix; the preceding metadata-only diagnosis; repository inspection at `6612e45`; the scope/design proposal and the user's subsequent “i confirm scope/design”. Preservation requirements come from `docs/superpowers/specs/2026-11-13-companion-account-default-setup.md` and its implementation evidence in `docs/validation/companion-account-default-setup.md`.

**Current stage:** Stage 4 complete — Native implementation, rebuilt-app acceptance, sequential specification/quality review and local verification are complete, with the default-parallel GUI-check limitation recorded in `docs/validation/keychain-lookup-fix.md`. Requirements and prior approvals remain unchanged. The user replied “approved” after the saved Stage 2 DRAFT and its path were presented. That message authorized planning only. The saved plan was later presented, Native execution selected, and the user separately replied “approved” after the plan-approval reminder; that later approval authorizes implementation.

## Problem and current behavior

The existing-item selector can report **Metadata lookup failed** even when the user's Keychain contains a usable credential. `KeychainStore.metadata` currently rejects the entire result when any returned generic-password item lacks service/account strings or cannot form a valid `CredentialReference`. Ordinary unrelated items with unusable metadata therefore prevent valid items from reaching **Matching item**.

The earlier read-only diagnosis reproduced this failure using production sources. The unfiltered metadata lookup failed with `unsupported`; a query restricted to the intended service, account and supported Keychain path returned one reference. No credential value was retrieved and no Keychain item or private configuration was changed. This establishes the reported row-validation failure; it does not prove that every user's unrestricted search list is accessible.

Relevant repository boundaries are:

- `companion/Sources/CompanionCore/KeychainStore.swift`: metadata queries, exact lookup, native error handling and creation.
- `companion/Sources/CompanionCore/AccountTypes.swift`: existing reference validation.
- `companion/Sources/CompanionCore/AccountSetupController.swift`: browsing, incoming-credential suggestions and recovery checks.
- `companion/Sources/CodexProjectRouter/AccountSetupView.swift`: lookup state, counts, picker and explicit reference selection.

Exact lookup currently calls the same listing path. Incoming suggestions and recovery reconciliation depend on exact lookup and its rejection of malformed or ambiguous evidence. Relaxing that shared behavior would affect more than browsing.

## Delivery boundary and desired outcome

**Wider direction:** The project-list increment is complete and merged. Consolidated UI simplification and startup/distribution remain provisional. This is a separate, focused setup fix.

**Selected increment:** Make existing-item metadata browsing return usable references despite unrelated unselectable item metadata, while visibly reporting omitted items and preserving strict exact lookup. Include the necessary core/controller/UI integration, regression tests, documentation, rebuilt app and focused visual verification.

**Uncertainty:** The cause is established. Verification must demonstrate the corrected production browsing path and its UI reporting. Other native failures, such as an inaccessible Keychain in the search list, may still prevent an unrestricted lookup and remain visible failures.

**Boundary rationale:** Row handling and omission reporting form one usable outcome. A core-only change would conceal the incomplete listing; changing credential access or recovery would expand the fix unnecessarily.

## Approaches

The confirmed approach separates the semantics of metadata browsing and exact lookup, without prescribing a new abstraction or public method name. Browsing tolerates only the item-metadata omissions defined below and reports their count. Exact lookup retains its existing strict behavior.

Exact service/account/path filters remain a useful workaround and discovery control, but requiring them would leave the reported broad-listing failure unresolved. Applying tolerant row handling to the shared exact-lookup behavior is excluded because malformed evidence must not become a false absence during suggestions or recovery.

## Browsing behavior

The following rules apply to the explicit **List matching item metadata** operation, whether its optional filters are supplied or omitted.

| Observation | Required outcome |
|---|---|
| Service and account are strings, the reference meets existing validation, and supplied filters agree | Include the reference. |
| Service or account is absent, has the wrong type, is empty, exceeds existing limits, or contains prohibited control characters | Omit the item and increment the omitted-item count once. |
| A returned string service or account disagrees with its supplied filter | Fail the lookup, even if another field would otherwise make the item omittable. |
| Unexpected `kSecValueData` is present | Fail the lookup, even if the item also has unusable metadata. Never display or log its value. |
| Search-list discovery, Keychain opening/path validation, result decoding or native query fails | Fail the lookup; do not publish successful results from other Keychains as a completed listing. |
| A successful native query reports no items | Contribute zero selectable and zero omitted items. |

Omission applies only to unusable service/account metadata on a returned item. It must not hide an invalid Keychain path, unsupported Keychain, native error, filter contradiction or unexpected secret data. These failures take precedence over omission. Existing reference limits and file-backed Keychain validation remain authoritative; do not trim, repair, synthesize or infer missing reference fields.

The selected search scope remains unchanged: an explicit path queries that file-backed Keychain; otherwise query the current user search list with existing duplicate-path handling. Service/account filters keep their existing meaning. Do not broaden a failed filtered lookup or fall back to another scope.

Counts describe rows returned by successful queries in that lookup, not all items in every Keychain or proof of credential accessibility. Count a row with multiple unusable fields only once. Do not use display-level deduplication to change exact-lookup ambiguity decisions.

## Exact lookup and safety preservation

Exact lookup by reference, and service/account lookup used for incoming suggestions, retain the existing strict contract:

- Valid exact matches are returned; a genuinely empty successful query returns absence.
- Unsupported/malformed returned rows, filter contradictions and unexpected secret data remain errors rather than omitted evidence or absence.
- Multiple matches, including matches across different Keychains when no path was supplied, remain ambiguous. Never choose the first match or deduplicate away ambiguity.
- Supplied reference validation, exact path/service/account agreement and existing native failures remain enforced.

Recovery checks keep using this strict contract. The fix confers no new authority to create, retry, reconcile, delete, clear a receipt or resolve an activation lock.

All browsing and exact lookup remain metadata-only, requesting attributes with secret data and item references disabled, using the existing serial native execution boundary. Preserve generic-password/file-backed scope and existing path ownership/canonicalization checks. Do not retrieve a password to determine whether an entry is selectable. Selecting an item continues to mean access and provider acceptance are unverified.

## UI behavior

Keep the existing Advanced selector and explicit **Use this reference** interaction. Do not automatically select or apply a discovered item.

For a completed lookup, retain the selectable match count and captured query scope. When the omitted count is positive, display a nearby visible explanation, for example:

> 3 matches. 2 unsupported items omitted because their service/account metadata cannot form a usable reference.

The final wording may follow existing singular/plural conventions, but must distinguish selectable matches from omitted items. A completed lookup with zero selectable references and positive omissions must report both facts; it must not resemble a pristine empty result or a native failure. Do not display raw rejected metadata or enumerate rejected item identities.

Preserve distinct states for not started, in progress, completed and failed. Beginning a lookup clears the previous picker selection/results and omission count. A failure leaves no selectable results or stale omission summary. Previously assigned form references remain governed by the existing form behavior; searching alone must not alter them. **Use this reference** remains disabled while searching and whenever no result is selected.

Changing filters does not relabel an in-flight or completed lookup: results, counts and scope describe the captured lookup inputs. A subsequent lookup replaces that evidence. These changes must not reset other account/default/import choices or alter the form's existing save, dismissal and recovery rules.

## Acceptance criteria

- **AC-01:** A successful browsing query containing valid references and items with absent, mistyped, empty, overlong or control-containing service/account metadata returns the valid references and the correct omitted-row count, independent of row order. A row with multiple unusable fields counts once.
- **AC-02:** Browsing distinguishes an empty successful query from a successful query in which every returned item was omitted. Both have zero selectable matches; only the latter has a positive omitted count and visible explanation.
- **AC-03:** Unexpected secret data or a returned string contradicting a supplied filter fails browsing, including when the same row also has omittable metadata. No row content or secret value enters UI errors, logs or persisted evidence.
- **AC-04:** Search-list, path-validation, result-decoding and native query failures remain failures. A later Keychain failure cannot expose an earlier Keychain's results as a completed listing. Successful empty queries remain nonfatal.
- **AC-05:** Unfiltered, partially filtered and fully filtered browsing preserve the selected scope. Valid results and omission counts combine across successfully queried Keychains; an explicit path does not query other Keychains or modify the user's search list/default.
- **AC-06:** Strict exact lookup preserves valid match, genuine absence, invalid reference, malformed-row rejection, native failure and duplicate-match ambiguity behavior, including ambiguity across search-list Keychains. Tolerant browsing cannot convert unsupported exact evidence into absence or a chosen match.
- **AC-07:** Browsing and exact lookup request attributes only, with secret data and item references disabled, and perform no Keychain create/update/delete, explicit unlock, authentication-helper execution or credential read. Existing serial execution and creation safeguards remain intact.
- **AC-08:** The selector presents distinct initial, pending, completed-empty, completed-with-matches, completed-with-omissions and failed states. It reports selectable and omitted counts accurately with the captured scope, clears stale picker evidence on a new lookup/failure, and requires explicit selection before applying a reference.
- **AC-09:** Browsing does not change existing account/default/import choices, saved credential references, assignments, routing state, setup receipts or activation locks. Incoming suggestions and recovery continue through strict lookup; existing setup/recovery regression checks pass.
- **AC-10:** Focused automated tests cover the row/error precedence, count propagation and UI presentation above. Relevant native regressions, app build, existing Node suite and package checks pass. Focused visual verification checks the rebuilt selector's counts, omission explanation and explicit-selection behavior; record any state that could only be inspected through a synthetic fixture.
- **AC-11:** Operating guidance explains tolerated item omissions, remaining whole-lookup failures, optional exact filters and unverified credential access. Validation evidence records actual commands/results, visual observations and remaining limitations separately from assumptions. Required final review and authorized local commits complete before delivery.

## Edge cases and limitations

- A locked, inaccessible, unsafe or unsupported Keychain can still fail the whole browsing operation. This increment does not introduce partial success across failed Keychains.
- Metadata compatible with a reference does not establish password readability, token validity, endpoint acceptance or billing attribution.
- Positive omission counts explain incomplete item coverage without exposing rejected metadata. They are not a diagnosis of every item or assurance that omitted items are usable through another reader.
- Exact lookup remains deliberately stricter than browsing, including for malformed results supplied by a native adapter. Tests must exercise both paths independently.
- The previous metadata-only diagnosis is evidence of the defect, not verification of this future implementation. No implementation tests or rebuilt UI checks have been run for this fix at specification time.
- macOS did not expose the open companion's controls through accessibility inspection during the preceding increment. Any renewed visual check must report the actual inspection method and may require the user's observation; do not claim visual verification from model/presentation tests alone.

## Constraints and out of scope

Use the existing Swift/Security and setup boundaries. Prefer the smallest direct change; do not add a generic policy framework, dependency, schema or persistent omission database. Preserve the existing Node credential reader and all routing behavior.

Excluded work includes credential storage redesign; editing/deleting existing Keychain items; authentication-helper parsing changes; account editing/deletion; automatic credential retrieval or selection; partial success across failed Keychain queries; broader setup/navigation/UI simplification; and startup, installation, packaging or distribution improvements. Rebuilding and checking the existing app bundle is necessary verification, not a distribution redesign. Do not quit or replace the user's running app without coordinating the visual check.

## Approval and execution handoff

Artifact resolution before the Stage 2 presentation found no existing specification or plan for `keychain-lookup-fix`, including its exact legacy paths. At that presentation this was the newly created specification and no implementation plan had been created. The confirmed approach had no remaining material product decision requiring clarification before the draft. After the user's separate specification approval, the DRAFT plan was saved at `docs/superpowers/plans/2026-11-20-keychain-lookup-fix.md`; it subsequently received separate approval after presentation, as recorded above.

Specification approval authorizes a separate implementation plan only. That plan must use this specification's exact basename and receive its own explicit approval. Until then, keep this draft uncommitted and make no product-code changes, implementation branch or main update. Later execution follows the repository's existing-checkout Git rules, with no worktree, push or merge unless requested.

**Execution endpoint:** Deliver only the approved Keychain lookup fix, including integration, verification, focused visual inspection, required review, documentation and authorized local commits; report the working result, observed evidence and limitations, then stop before broader UI or distribution work.
