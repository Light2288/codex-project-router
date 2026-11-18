# Projectless Chat Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use `personal-workflows:spec-implement` after this separate plan receives explicit approval.

**Goal:** Make confirmed projectless chats work through companion-managed account routing using the original Codex connection, independently of project overrides and the companion default.

**Architecture:** Extend the existing identity resolver with a narrowly enabled projectless result after complete supported ancestry validation. The existing proxy selects the original connection for that result, catalog requests and already-eligible unassigned titles only in managed schema-2 account mode. Preserve the current request snapshot, control protocol, configuration representation, account/assignment authority and Direct recovery.

**Tech Stack:** Existing Node 24 (`>=24 <25`), smol-toml 1.9.1, built-in HTTP/HTTPS/filesystem/SQLite, Swift/SwiftUI/AppKit and XCTest on macOS 14+, Apple silicon ad-hoc-signed companion. No new dependency.

**Spec:** `docs/superpowers/specs/2026-11-18-projectless-chat-compatibility.md`

**Slug:** `projectless-chat-compatibility`

**Status:** APPROVED — implementation in progress

**Created:** 2026-11-18

**Updated:** 2026-11-18

**Provenance:** The user chose the original Codex connection, selected Original Codex for shared requests and Companion only for mode coverage through native clarification, and confirmed scope/design with `scope/design confirmed`. The complete specification was presented in chat while Plan mode prevented saving. The subsequent `Please implement the plan.` approves that specification only; no implementation plan had been presented. The approved specification is now saved with its requirements unchanged. This plan is based on the current checkout at `5d2e44b1dd626d58cb0c4c060263b8fd8943febd` and received separate explicit approval with `plan approved, subagent driven execution approved`.

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Subagent-driven, explicitly approved by the user with `plan approved, subagent driven execution approved`. Managed full role: `gpt-6.1-sol`; implementation dispatches use explicit high reasoning effort.

## Global Constraints

- “The increment covers companion-managed, ready schema-2 account routing.” Standalone schema-1/schema-2 and managed schema-1 behavior remain historical.
- “Projectless routing requires positive supported saved-state evidence.” Unknown identity is not original-connection authority; inspect the complete relevant ancestry/session relationship before granting it.
- “Projectless, model-list and eligible unassigned-title requests preserve the accepted incoming Authorization value.” Retrieve no outgoing default/project key for those paths; authenticate the caller first.
- “Project requests retain their complete selected URL/key pair.” Original routing is never failure fallback. No retries, redirects, credential caching, body/model/continuation translation or new endpoint admission.
- “Continue capturing configuration and routing mode together at HTTP request receipt, before asynchronous authentication.” Membership remains fresh resolution, not a promise of membership at receipt or an atomic multi-file snapshot.
- Preserve current title opt-in and absence proof; no automatic enabling, no fabricated project attribution and no new desktop-state source.
- No config schema, migration, policy switch, HTTP endpoint, CLI command, control protocol, projectless account selector, production Keychain write or general reload is added.
- Existing account/default save boundaries, exact-child ownership, startup Off, original Direct recovery, response confirmation, guarded Stop/Quit and optional-property presence remain authoritative.
- Actual identifiers, endpoints, mappings, credentials, comparison evidence, checkpoints and raw traces stay private outside Git. No private operational mutation while planning.
- Work in the existing checkout. Do not update main, create the implementation branch or commit this pair until plan approval. No worktree, push or merge without a user request.
- If fresh projectless first-message proof is unavailable under the approved identity rules, recover and report incomplete compatibility; return to scope/design rather than broadening authority.
- Stop after this increment's verification, recovery, review and local delivery. Visibility, broader UI work, account editing/deletion and distribution remain deferred.

## Review Focus

1. A projectless marker must not hide an uppercase saved project assignment or parent edge; Task 1 tests normalized relevant keys, whole-chain conflicts and a marker encountered before a conflicting ancestor.
2. Original routing must preserve the accepted incoming credential while never sending it to a selected default/override destination; Task 2 uses three distinct origins/keys, equal-URL/different-key controls and inaccessible outgoing secrets.
3. An unassigned title can lack a project temporarily without being an ordinary projectless chat; Tasks 1/2 preserve title absence proof, mapped/projectless precedence, opt-in Off and unsupported auxiliary denial.
4. A membership update during authentication is not the same as a reroute after selection; Task 3 separately pins fresh resolution, immutable selected streams, contradictory transition denial and the next request on a reused connection.
5. Package control operations must still make zero upstream connections even when new package assertions deliberately send model requests; Task 5 confines the request probe to a separate synthetic fixture and retains the existing zero-connection controls and owned cleanup.

---

## Evidence, resolution and planning decisions

Specification resolution before saving was MISSING; after saving it is NEW_ONLY at the explicit Spec path. Plan resolution before this write is MISSING; the exact legacy candidates are absent. The pair uses the specification's original 2026-11-18 basename/date and identical slug. Approval comes from the quoted chat messages, not artifact discovery.

Planning started on clean `main` at `5d2e44b1dd626d58cb0c4c060263b8fd8943febd`, tracking `origin/main`. The earlier read-only audit also matched actual remote main; execution must recheck remote state after plan approval. Planning saves only this plan and the approved specification. No fetch, main update, implementation branch, commit, product/test/helper edit, build, test run, app launch, credential retrieval or live operation is part of this stage.

Architecture map `docs/architecture/map.md` is absent, so its recorded HEAD and freshness are unavailable. No ADR/decision artifact was found under conventional `docs/architecture`, `docs/adr`, `docs/adrs` or `docs/decisions` paths or the docs file listing. There is no discovered accepted ADR constraint; do not generate a map during planning. Key paths were inspected at the stated HEAD: identity/title proof, proxy/admission/diagnostics, managed serving/snapshot publication, activation/account setup, native controls presentation, Node/native fixtures and package assembly/source denial.

Repository facts grounding this plan:

- `identity.js` already validates request identity, reads `projectless-thread-ids` and follows `thread_spawn_edges`; it currently rejects markers before completing ancestry. Its lookup window is one second with 50 ms retry cadence and a 32-node ancestry bound.
- `proxy.js` already captures the configuration/mode snapshot before its first await. Incoming verification precedes identity; schema-2 selection then always starts with the companion default, including catalog/title traffic. Original URL and incoming Authorization are already retained locally before that selection.
- `managed-serve.js` supplies `getRequestRoutingSnapshot: () => current`. No new control capability or mutation message is needed.
- `diagnostics.js` currently accepts only direct/ancestor/catalog/unassigned_title sources and global/override selection. Its allowlists must be updated with the producer.
- Existing `test/proxy.test.js` has three-origin account fixtures, request barriers and exact byte/header assertions. Existing helpers supply synthetic JSON/SQLite; production settings and secrets are unnecessary.
- Existing package cases assert all current bundled modules, signed relocated execution, source denial and guarded account/assignment lifecycle. Their synthetic control-only upstream must remain untouched by new request assertions.

Command evidence: root `package.json` supplies `npm test`, `npm run companion:test`, `npm run companion:build` and `npm run companion:package-test`. Focused Node invocations below select files from that existing `node --test test/*.test.js` runner; no new runner is introduced. Swift filters select existing targets/classes as established in the preceding approved plan. `docs/operating-guide.md` Development checks supplies native → build → Node → explicit package ordering, `node --check src/cli.js`, `git diff --check` and optional process-scoped `caffeinate -i`; syntax checks on other modified JS files use that same Node option. Git operations follow the supplied AGENTS.md workflow. Historical investigation/acceptance counts are not fresh results for this plan.

### File responsibilities and exact contracts

| Files | Responsibility |
|---|---|
| `src/identity.js`; `test/config-identity.test.js` | Opt-in positive projectless classification with complete supported ancestry validation |
| `src/proxy.js`, `src/diagnostics.js`; `test/proxy.test.js`, `test/admission-diagnostics.test.js` | Scoped original selection, credential isolation, truthful diagnostics and request timing |
| `test/managed-serve.test.js` | Retained managed startup/control/snapshot and no-secret control regression evidence |
| `companion/Sources/CodexProjectRouter/ControlsView.swift`; `companion/Tests/CompanionAppTests/ControlsPresentationTests.swift` | Focused explanatory copy without new controls or lifecycle authority |
| New `test/helpers/projectless-package-probe.mjs`; `test/companion-package.test.js` | Reusable self-contained synthetic bundled-proxy probe inside both relocated fixtures |
| `README.md`, `companion/README.md`, `docs/operating-guide.md`; new `docs/validation/projectless-chat-compatibility.md` | Current routing policy and actual sanitized acceptance/recovery evidence |

Production changes are limited to existing modules; no new module requires an allowlist entry. Preserve `scripts/build-companion.mjs`'s explicit list and package source-equality checks. Other production/native files are not planned change targets; a discovered need must remain within the approved scope and receive affected review.

- Extend `identifyProject(rawHeaders, config, {signal, allowUnassignedTitle = false, requireRoute = true, allowProjectless = false} = {})`. Effective projectless permission requires explicit `allowProjectless === true`, schemaVersion 2 and account routing. Default/legacy calls retain the existing path.
- New successful projectless result: frozen `{threadId, ownerThreadId, source: "projectless"}` with no `projectId` or `routeAlias`. `ownerThreadId` is the nearest validated projectless marker on the fully checked ancestry. Existing direct/ancestor project result shapes remain.
- The proxy passes `allowProjectless` only when `config.schemaVersion === 2`, account routing exists and its received routing mode is defined. Both existing managed snapshot/mode getters are supported; no getter means standalone semantics.
- Diagnostic `source` adds `"projectless"`; managed `routeSelection` adds `"original"`. Preserve `"global"` for the companion default and existing schema-1 global semantics; do not rename historical values.
- Add `ControlsPresentation.originalConnectionGuidance: String?`, present only for inspected account mode. Exact text: `Chats outside projects use the original Codex connection in On and Off. Model lists and permitted automatic titles use it too.` This is policy guidance, not proof of readiness, updated child identity or an upstream response.
- The package-only runner accepts `--router-root <absolute relocated router root> --fixture-root <absolute owned temporary directory>`. It imports only that router's production modules plus Node built-ins, reads copied public TLS fixtures from its scratch directory, and prints exactly `projectless-package-pass\n` on success. It does not import checkout test helpers or real configuration. It creates/closes its own local observers/proxy and uses the existing credential-reader seam with public synthetic values; this is component/package evidence, not a native keychain or live-gateway claim.

## Execution preflight — only after separate plan approval

- [x] Identify both saved artifacts and their separate approval messages. Update only their lifecycle/approval metadata to record actual plan approval and selected execution method; do not infer either from this DRAFT.
- [x] Use `personal-workflows:spec-implement`, resolving its managed full model role and chosen execution workflow. Preserve task/final review requirements from that workflow; do not run duplicate final gates.
- [x] Recheck `git status --short --branch` and the branch/HEAD. Preserve unrelated edits and staging. Run `git fetch origin`, safely select `main` and `git merge --ff-only origin/main`; never discard changes, force-update or overwrite the approved pair. If the update conflicts with local artifacts/edits, resolve preservation before proceeding.
- [x] Create `feat/projectless-chat-compatibility` in this checkout only. Stage both exact artifact paths and `git commit -m "docs: approve projectless chat compatibility"` before changing product code. Record the resulting implementation base; no worktree, push or merge.
- [x] Read the selected workflow's review requirements and capture a synthetic baseline. Run `node --test test/config-identity.test.js test/proxy.test.js test/admission-diagnostics.test.js test/title-policy.test.js test/title-state.test.js test/managed-serve.test.js`. Expected: all pass at the actual new base; preserve and investigate any failure before editing. Do not claim the earlier 754-test audit as this baseline.
- [x] Before any build overwrites the target app, check whether that exact app/owned router is active. If so, settle its existing guarded Direct recovery with required human confirmation and Stop/Quit first; never replace a live bundle, signal an unowned listener or manufacture ownership. Planning has not inspected private runtime state.

### Task 1: Recognize positively proven projectless membership [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-06

**Files:** Modify `src/identity.js`, `test/config-identity.test.js`. Security risk: a prematurely accepted marker could hide a project assignment and forward its credential to the wrong routing category.

**Interfaces:** Consume existing saved assignment/catalog/marker structures and SQLite parent edges. Produce the extended `identifyProject` option and frozen result above. Existing project result/error contracts and title proof helpers remain unchanged outside explicit scoped permission.

- [x] **Step 1 — write failing classification tests.** Add `managed accounts resolve explicit projectless identity`, `projectless ancestry is checked through conflicting ancestors`, `projectless proof rejects case-shadowed membership and edges`, `projectless proof preserves session cycle and state guards`, `fresh projectless marker may appear within the existing lookup window`, and `projectless permission leaves legacy and title admission unchanged`. Assert a direct marker and a supported descendant return exactly the new result; a marker before a project ancestor and an own project assignment plus marker reject with `IDENTITY_CONFLICT`. Include uppercase marker/key/edge variants, duplicate normalized relevant assignment keys, multiple normalized parents, malformed markers, absent/locked DB, 32-node boundary, cancellation, forged parent, incompatible session and unknown saved-thread-only identity. With permission absent/false or schema 1, retain historical denial. A known projectless title is ordinary projectless; an unidentified title still needs the unchanged opt-in/proof.
- [x] **Step 2 — run RED.** Run `node --test test/config-identity.test.js test/title-policy.test.js test/title-state.test.js`. Expected: new positive projectless results fail against the existing rejection path; existing title/legacy checks remain green. Correct fixture mistakes separately from a causal failure.
- [x] **Step 3 — implement scoped classification.** Extend the existing resolver rather than adding a second identity pipeline. In the enabled path normalize valid marker UUIDs for membership, inspect all case-equivalent relevant assignment keys and query relevant saved child edges without case sensitivity; multiple normalized assignment keys/parent rows are conflicts. Equivalent repeated marker values may coalesce, but malformed marker values make state unavailable. Accumulate project and projectless evidence through the complete bounded chain, validate existing session/parent rules, then reject mixed membership or return the nearest marker's owner. No marker and no project remains the existing retryable unresolved-state path. Preserve the existing default/legacy branch, route/catalog consistency checks, cancellation and final database close. Do not return early or convert any exception to original routing.
- [x] **Step 4 — run GREEN.** Repeat Step 2. Expected: all classification, old project/legacy and title proof tests pass; fixture snapshots prove no desktop/config writes.
- [x] **Step 5 — commit.** Stage Task 1 files only; `git commit -m "feat: resolve proven projectless chat membership"`. Complete the selected execution method's task gate before advancing.

### Task 2: Select and report the original connection without credential crossover [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-06, AC-07

**Files:** Modify `src/proxy.js`, `src/diagnostics.js`, `test/proxy.test.js`, `test/admission-diagnostics.test.js`. Security/auth risk: preserving the incoming credential is permitted only for the preserved original destination, never as an outgoing-account fallback.

**Interfaces:** Consume Task 1's opt-in/result. Retain `createProxy(startupConfig, options)` and both existing snapshot/mode seams. Produce `source: "projectless"` and `routeSelection: "original"` only for the scoped producer paths; no control-wire/config shape changes.

- [x] **Step 1 — write failing routing/privacy tests.** Add `managed projectless requests preserve original endpoint and authorization`, `managed shared requests use original while identified projects retain account selection`, `original routing requires incoming auth but no outgoing credential`, `project failures never fall back to original`, and `original policy is confined to managed accounts`. Use existing three-origin account fixtures; verify full prefix, query, Host, accepted mixed-case bearer scheme, exact body/model/continuation and incoming-only reader calls for projectless/model-list/eligible unassigned-title traffic in both modes. Make outgoing default/project readers fail without breaking original traffic; incorrect incoming auth must reject first with zero upstream calls. Cover equal URL but different incoming/outgoing credentials. Extend diagnostic tests so projectless may retain its validated owner but never project/alias fields; original selection suppresses any alias/project fabrication. Retain legacy diagnostic records. Test title opt-in off, unsupported paths/auxiliary families and ordinary project/title precedence.
- [x] **Step 2 — run RED.** Run `node --test test/proxy.test.js test/admission-diagnostics.test.js`. Expected: scoped projectless is still unwired and catalog/title still select default; new selection/allowlist assertions fail for those causes.
- [x] **Step 3 — implement one scoped selection branch and sanitizer updates.** Compute managed-account eligibility from received snapshot/mode and schema/account presence; pass its boolean to Task 1. After successful incoming verification/resolution, select original for projectless, catalog or unassigned_title in that mode. Leave the original URL/Authorization variables intact, skip outgoing-account lookup and record original selection. Otherwise retain existing account/default/override selection and failures. Add only the agreed diagnostic enum values and scoped attribution exclusions. Preserve local health, exact destination Host, forwarding/cancellation, title helpers and standalone behavior. Do not introduce a helper framework, schema or flag.
- [x] **Step 4 — run GREEN and update affected expectations narrowly.** Repeat Step 2 and run `node --test test/config-identity.test.js test/title-policy.test.js test/title-state.test.js test/account-setup.test.js test/managed-serve.test.js`. Expected: all pass. In existing `independent incoming token never reaches selected default origin` and `explicit old-global override survives default change`, change only scoped catalog/eligible-title origin/count/key expectations; preserve and strengthen project credential isolation, including a project account sharing the original URL. Do not weaken assertions to hide changed counts.
- [x] **Step 5 — commit.** Stage Task 2 files only; `git commit -m "feat: preserve original routing for projectless and shared requests"`. Complete its task gate.

### Task 3: Prove request timing and membership transitions [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-01, AC-02, AC-04, AC-05, AC-06, AC-10

**Files:** Extend `test/proxy.test.js` and, only for existing startup/control assertions, `test/managed-serve.test.js`. Concurrency risk: a held request could be reclassified after selection or a later request could reuse stale membership. Production ownership remains Tasks 1/2; any causally necessary correction returns to that task's affected review.

**Interfaces:** Use existing `getRequestRoutingSnapshot`, three-origin HTTP fixtures, credential barriers and managed get/set-mode/publication fixtures. No new startup injection, runtime channel, test endpoint or production hook is planned.

- [x] **Step 1 — add deterministic regressions.** Add `projectless selection survives mode and assignment snapshot changes`, `membership resolves after held incoming authentication`, `selected stream survives projectless to project movement`, `reused connection resolves coherent membership in both directions`, and `projectless cancellation and original failures never reroute`. Hold incoming authentication, then publish coherent state before release to prove fresh resolution; separately hold an already-selected original stream while publishing a project assignment and changing mode. Verify that stream stays original and the next request selects the new project/default; repeat the reverse transition. An overlapping marker/project state rejects rather than selecting either destination. Test compact/background requests, cancellation/late readers, original 401/402/429/5xx, TLS/connection/stream failures and redirects with zero alternate-origin calls. Existing startup/channel tests still assert Ready Off, same session/child and credential-free control operations.
- [x] **Step 2 — run the evidence checks.** Run `node --test test/proxy.test.js test/managed-serve.test.js`. Expected: all new behavioral tests pass with Tasks 1/2; this test-only task need not fabricate RED. If one fails, record the smallest actual failure and diagnose its owner before a causal production fix; rerun that task's affected checks/review as well.
- [x] **Step 3 — inspect the barriers.** Confirm each timing test awaits a real causal barrier, not a sleep; timeout is only a bound. Distinguish request-receipt config/mode capture from subsequent membership resolution and post-selection immutability. Verify fixture JSON/SQLite changes occur only in private temporary directories.
- [x] **Step 4 — verify the complete affected Node surface.** Run `node --test test/config-identity.test.js test/proxy.test.js test/admission-diagnostics.test.js test/title-policy.test.js test/title-state.test.js test/managed-serve.test.js test/account-setup.test.js test/project-assignments.test.js test/activation.test.js test/companion.test.js test/companion-cli.test.js`. Expected: all pass, with no feature-driven relaxation of legacy, auth, assignment or recovery assertions.
- [x] **Step 5 — commit.** Stage only Task 3 test changes and any separately reviewed causal fix; `git commit -m "test: verify projectless request and membership isolation"`. Complete its task gate.

### Task 4: Explain original versus default routing in the companion [size: S | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-04, AC-06, AC-07

**Files:** Modify `companion/Sources/CodexProjectRouter/ControlsView.swift`, `companion/Tests/CompanionAppTests/ControlsPresentationTests.swift`, `README.md`, `companion/README.md`, `docs/operating-guide.md`.

**Interfaces:** Produce `ControlsPresentation.originalConnectionGuidance` with the fixed policy text above, rendered as a secondary account-mode explanation near the existing default display. It consumes only existing inspection mode, adds no readiness/ownership claim and changes no controller/wire type.

- [x] **Step 1 — write failing presentation cases.** Add `testOriginalConnectionGuidanceOnlyAppearsForAccounts` and `testOriginalConnectionGuidanceDoesNotImplyReadinessOrChangeRecovery`. Assert exact text for account mode in known On/Off/not-running/unavailable states; nil for legacy/credential/missing mode. Existing default label, errors, confirmation, control enablement and recovery guidance remain unchanged. No original endpoint or secret is displayed.
- [x] **Step 2 — run RED.** Run `swift test --package-path companion --filter ControlsPresentationTests`. Expected: missing projection/new copy assertion fails before the view edit.
- [x] **Step 3 — implement focused copy and current documentation.** Add the projection and render it without changing layout/navigation authority or fixing deferred viewport/focus observations. In current docs state the exact mode/schema boundary, original/default distinction, all-chat shared-request change, title opt-in, first-message positive proof and safe update/restart/recovery process. Preserve historical validation and old standalone descriptions. Correct overlapping present-tense pending-acceptance wording only where these touched routing sections would otherwise contradict their completed linked reports; do not rewrite historical closeout statements or unrelated documentation.
- [x] **Step 4 — run GREEN.** Repeat Step 2; run `npm run companion:test` and `git diff --check`. Expected: focused/full native checks pass and whitespace is clean. Inspect source diff to confirm changes are presentation/docs only.
- [x] **Step 5 — commit.** Stage Task 4 files only; `git commit -m "docs: explain original connection routing in companion"`. Complete its task gate.

### Task 5: Verify new behavior from relocated signed resources [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-06, AC-07, AC-08

**Files:** Create `test/helpers/projectless-package-probe.mjs`; extend `test/companion-package.test.js`. Security risk: fixture setup must not weaken source denial, read private stores, alter existing Keychain items or obscure cleanup. Preserve the production source allowlist; there are no new runtime modules to add.

**Interfaces:** Implement the package-only runner contract above and reuse it in both existing relocated execution cases. Existing assembly, bundled managed-child mode/assignment/activation tests and native Keychain harness stay separate and authoritative for their own boundaries. Do not present a synthetic reader seam as production Keychain acceptance.

- [x] **Step 1 — add bundled behavior assertions.** The runner constructs an owned synthetic JSON/SQLite fixture, three local TLS observers and distinct public incoming/default/override values, then imports relocated `createProxy` through its absolute bundled path. Using existing snapshot/credential seams, verify projectless response/compact and shared catalog/eligible-title original routing in both modes; mapped On override and Off default remain paired; conflicting/unknown identity and bad incoming auth make no model call. Emit only the fixed pass marker, not request/token/config values. In both relocated cases, copy runner/certificate/key into the private fixture before source denial; the runner must not import checkout helpers. Retain negative lexical/resolved/symlink read controls and all existing current-resource, signature, arm64, minimal-PATH, native window, owned lock/cleanup, assignment and recovery assertions. Use the existing lifecycle tracker and bounded process deadlines; close all runner servers in a finally path and verify process/port absence on failure.
- [x] **Step 2 — classify prebuild evidence correctly.** If package checks run against a stale app, record resource-equality/stale-artifact failure as such; it is not the new feature's causal RED. This task adds verification after production Tasks 1/2, so do not manufacture a failing implementation step. Do not skip or relax a fixture for acceptance.
- [x] **Step 3 — build and run the current package.** Confirm the target app is safely absent as in preflight, then run `npm run companion:build` followed by `npm run companion:package-test`. Expected: matching ad-hoc-signed resources; exactly three existing cases pass with zero skips. The new runner runs under existing minimal GUI environment and source-denial sandbox, whose outbound network is loopback-only. Intentional Security SDK warnings remain disclosed. Use optional `caffeinate -i` as documented; do not change product deadlines to accommodate idle sleep.
- [x] **Step 4 — verify evidence separation.** Existing control-only synthetic upstream counters must remain zero; the request runner owns different observers and reports explicit request coverage. Compare bundled/current source and signature through existing assertions. Preserve actual user items/default Keychain; existing disposable-Keychain harness must still verify its own cleanup. Assert no orphan probe process or bound synthetic port remains.
- [x] **Step 5 — commit.** Stage Task 5 helper/test files only; `git commit -m "test: verify bundled projectless routing in relocated app"`. Complete its task gate.

### Task 6: Complete native/live acceptance, recovery and final review [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10, AC-11, AC-12

**Files:** Create `docs/validation/projectless-chat-compatibility.md`; update only lifecycle/checklists in this approved pair and necessary current-documentation evidence links. Risk: synthetic or visible-only outcomes must not be overstated as complete native/live compatibility, and recovery must finish even after a failed observation.

**Interfaces:** Consume the approved behavior, actual ordered check results, exact tested source/app identity, private checkpoints and human observations. Produce a sanitized acceptance matrix, final review dispositions and a truthful local completion or incomplete-capability report. No automatic chat creation/messages or implicit next increment.

- [x] **Step 1 — run ordered current-source acceptance.** With the exact target bundle safely stopped and source inputs settled, run `npm run companion:test`, `npm run companion:build`, `npm test`, `npm run companion:package-test`, `node --check src/cli.js`, `node --check src/identity.js`, `node --check src/proxy.js`, `node --check src/diagnostics.js`, `node --check test/helpers/projectless-package-probe.mjs`, then `git diff --check`. Expected: every command exits 0; exactly three explicit package cases pass with zero skips; no stale-source substitution. Record actual counts/exits and intentional warnings. Repeat only checks affected by later edits or unresolved failures. Freeze/recheck the tested executable source and signed bundle identity for live acceptance.
- [x] **Step 2 — prepare bounded private live validation.** Preserve exact prior normal/selected router/provider/journal settings, optional-property presence, activation context, owned runtime selection and recovery evidence outside Git. Use a compatible ready schema-2 controlled configuration with preserved original URL and companion default demonstrably distinct, existing incoming verifier, and provisioned existing accounts; do not rotate/create real keys. Keep controller access and guarded recovery available. Launch the exact tested native app through macOS LaunchServices/Finder, not a foreground Codex PTY, and independently attribute its app/listener identities. Any external diagnostic launcher must remain private, bounded, protocol-preserving, positively owned and exactly restorable; never log secrets/bodies or treat instrumentation as a product fix.
- [x] **Step 3 — observe the required workflow.** The user explicitly starts Off, activates if necessary, manually restarts and confirms the routed response under existing guards. Have the user create a genuinely new chat outside every project and send its first message; correlate supported identity evidence and original selection, retaining visible/transport outcomes separately. On the same exact owned listener, switch On and receive a same-chat follow-up, then Off and another follow-up, without routine restart. Reopen/resume the projectless chat and verify original selection again. At least one actual projectless response is required in each mode. Compare a control project using its On override and Off default without changing those assignments. If the existing title option is enabled in the controlled config, observe eligible unassigned titles on original; otherwise record that live case unrun and retain automated disabled-policy coverage. Compaction, saved ancestry and in-flight cases have mandatory deterministic coverage from Tasks 1–3; any absent live instances are explicitly unrun, not claimed passes. Record full prefix/selection symbolically, never credential values, endpoint strings or billing inference.
- [x] **Step 4 — enforce the first-message stop condition and exact recovery.** If fresh projectless identity cannot be proven within supported lookup rules, mark AC-09 incomplete; do not use absence, a new evidence source or unknown-request forwarding as a repair. After success or failure, Restore direct for the retained context, preserve unrelated edits, have the user manually restart and confirm a working direct response before guarded owned Stop/Quit where required. Independently verify exact owned app/router/launcher exit, listener absence, correctly bound Direct/restored records, no pending confirmation and restored owned settings/optional presence. Preserve backups/receipts/raw evidence privately. Whole-file equality is claimed only if true; otherwise identify preserved unrelated differences. Never adopt/signal/delete an unverified resource.
- [ ] **Step 5 — consolidate, commit and complete review.** Record actual source/app identity, command results, first-message evidence, native copy observations, selection/transport matrix, compatibility boundaries, unrun cases and recovery in the new report. Commit with `git commit -m "docs: record projectless compatibility acceptance"` after staging only intended evidence/docs. Complete remaining task gates under the selected method, then use `personal-workflows:code-review` for the sole final sequential specification → quality whole-branch gate against the recorded implementation base and approved pair. Follow its scoped correction rules and rerun affected verification; no duplicate generic final review and no success claim if required live evidence is incomplete.
  - [x] Evidence portion: automated/native/live observations, failed-fixture and transport limits, unrun cases, source/app identity and exact operational recovery are recorded in `docs/validation/projectless-chat-compatibility.md` for the local acceptance-evidence commit.
  - [ ] Controller-owned remainder: sole final sequential specification → quality whole-branch review and its dispositions.
- [ ] **Step 6 — close locally and stop.** Only after required acceptance/recovery/review succeeds, update lifecycle/checklists and commit documentation closeout if needed. Run `git diff --check` and `git status --short --branch`; report actual branch/commits, working behavior, observed checks, evidence limitations and implications for visibility. If compatibility is incomplete, report the evidence and next scope decision after recovery instead of marking complete. No push, merge or later increment starts automatically.

## Criterion traceability

| Criterion | Owning task / decisive evidence |
|---|---|
| AC-01 | 1 positive classification; 2 exact original pair; 3 lifecycle/compact; 5 bundled probe; 6 fresh native/live first request and both modes |
| AC-02 | 1 whole-chain/normalized evidence and bounded failure; 2 zero upstream denial; 3 incoherent transition denial; 5 confined negative probes |
| AC-03 | 1 ordinary identity precedence; 2 catalog/title matrix and unchanged proof; 5 bundled shared routing; 6 qualified live titles |
| AC-04 | 2 auth/pairing/failure regression matrix; 3 retained listener/control behavior; 4 unchanged native guards; 5 existing packaged assignment/recovery |
| AC-05 | 3 deterministic authentication/lookup/stream/reuse/transition barriers, with Tasks 1/2 causal ownership |
| AC-06 | 1 opt-in defaults; 2 schema/mode matrix; 3 setup/account/activation regression checks; 4 bounded UI copy; 5 old package lifecycle |
| AC-07 | 2 exact source/selection privacy; 4 current guidance/docs; 5 signed relocated/source-denied component and native evidence |
| AC-08 | 4 native checks; 5 current matching package; 6 final native → build → Node → package/syntax/whitespace chain |
| AC-09 | 6 required fresh projectless first message, same-chat mode changes, reopened continuation, distinct default and control project |
| AC-10 | 1–3 deterministic compaction/ancestry/timing; 6 separate visible/transport outcomes and explicit unrun/live limits |
| AC-11 | 6 exact restoration, human response/restart obligations and independent owned-process/listener absence |
| AC-12 | 6 final sequential specification/quality gate, truthful disposition and local delivery endpoint |

## Self-review and approval handoff

Self-review checked all five specification sections and AC-01–AC-12 against task ownership, exact shared option/result/diagnostic/property names, commands and expected results, mode/legacy boundaries and the five Review Focus cases. Test-only packaging/timing and observational acceptance tasks do not fabricate RED. No new runtime module, schema, wire protocol, evidence source or future increment is planned. The bounded live first-message uncertainty remains an explicit acceptance obligation and stop condition; neither automated passes nor code review can waive it.

**Historical Stage 3 handoff:** No unresolved product choice remained from the confirmed scope. At that handoff, execution method and this plan's approval were pending, and both artifacts were uncommitted. The later explicit `plan approved, subagent driven execution approved` message authorized Stage 4. Execution preflight created `feat/projectless-chat-compatibility` and committed the approved pair at `91b53e0` before implementation; approval was not inferred from the specification or prior increments.

**Current stage:** Stage 4 — the specification and separate plan were explicitly approved, and subagent-driven execution was authorized. Execution preflight and Tasks 1–5 are complete, with independent task reviews Approved and no findings. Task 6 ordered current-source acceptance passed. The first live run recorded fresh projectless Off/On responses, a failed controller-project validation case caused by setup and verified recovery. The corrected run recorded reopened projectless Off→On→Off responses on one retained listener and control selection categories, with cancelled control transports explicitly retained. Both live runs now have human Direct confirmation, guarded Stop/Quit and independently verified exact operational restoration. Task 6 acceptance evidence is recorded with its explicit transport/unrun limits; the sole final sequential review and lifecycle closeout remain pending. The increment is not yet declared complete. Approval provenance remains recorded above.

**Execution endpoint:** Only projectless chat compatibility, implemented and verified with truthful native/live limits, exact recovery, final sequential review and local commits on `feat/projectless-chat-compatibility`; then stop before visibility, another specification/plan, push or merge.
