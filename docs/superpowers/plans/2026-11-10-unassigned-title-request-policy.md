# Unassigned title-request policy — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement` to implement this plan task by task using Native execution. Steps use checkbox syntax for tracking.

**Goal:** Allow only the approved unassigned initial-title pattern through the existing upstream and caller credential, then verify automatic desktop titles and restore direct operation.

**Architecture:** Keep route/authentication admission and ordinary project resolution first. A separate strict matcher and read-only absence verifier may authorize the narrow exception inside the existing identity lookup window; accepted requests share the current streaming path and receive unattributed diagnostics.

**Tech Stack:** Node.js 24, JavaScript ES modules, built-in HTTP/HTTPS, filesystem, SQLite and test libraries; existing `smol-toml@1.9.1`. No new dependencies.

**Spec:** [Approved specification](../specs/2026-11-10-unassigned-title-request-policy.md)

**Slug:** `unassigned-title-request-policy`

**Status:** APPROVED

**Created:** 2026-11-10

**Updated:** 2026-11-10

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Native

**Provenance:** Approved specification; scope/design confirmation followed by the separate user message reproducing the DRAFT specification under “PLEASE IMPLEMENT THIS PLAN”. Preserve the user's prior Native execution preference. The user separately approved this plan with “approved” after its presentation.

## Evidence and planning decisions

- Verified checkout: `/Users/davide/Personal/Projects/codex-project-router`; branch `main`, HEAD `f5621e25106c0bb9207003acc7fb55184dcdc915`, matching the local `origin/main` reference. No main update or implementation branch creation occurred during planning.
- The checkout was clean before saving the approved specification. Specification resolution is now `NEW_ONLY`; implementation-plan resolution was `MISSING`. No competing legacy artifacts, architecture map, or ADRs were found; map freshness and ADR constraints are inapplicable.
- Node is `24.21.0`. The previous observed baseline has 136 passing tests; it was not rerun merely to write this plan.
- `src/identity.js` already owns the one-second/50 ms retry loop. `STATE_UNAVAILABLE` conflates absent relationships with failed reads. Do not catch that error in the proxy and grant an exception there.
- Read-only schema inspection confirmed `threads.id` and `thread_spawn_edges.parent_thread_id`, `child_thread_id`, and `status`. The synthetic fixture currently contains only the edge table. No production schema change is needed.
- `package.json` supplies `npm test` as `node --test test/*.test.js`. Targeted commands below use that existing runner pattern and the precedent in the approved metadata plan. README supplies installation, CLI, syntax and whitespace checks.
- Planner-selected internal names and interfaces appear below. Absence checks use fresh reads, read transactions, file-change guards and SQLite `data_version`, not cached negative results. Deterministic filesystem fault injection using built-in mocks and `syncBuiltinESMExports()` was checked against Node 24; no production test hook is required.
- No material user-owned design decision remains unresolved. Native implementation preserves the existing execution preference; the full tier follows the data, security and concurrency risks. Inline execution does not switch the parent model.

## Global constraints

- `allowUnassignedThreadTitles` is an optional strict boolean, default `false`, under `schemaVersion: 1`; omitted and false preserve the existing fingerprint.
- Policy and observation are independent. Both affect readiness; neither requires an activation-record migration. Rollback remains mode-independent and works offline.
- Existing admission and successful mapped resolution have priority. Only admitted `POST /v1/responses`, including already-permitted queries, can use the exception.
- Require the exact approved metadata/identity pattern and fresh healthy evidence of no assignment, projectless marker, saved thread, or incoming/outgoing edge. Claims and labels do not establish project membership.
- Use the current caller credential unchanged; never retrieve, replace or persist credentials or invoke Keychain. Add no dependencies, commands, retries, redirect following or content inspection.
- Retain macOS/Node.js 24, loopback binding, normal TLS verification, system CA support, read-only desktop-state access, existing streaming and cancellation.
- Never log content, credentials, complete headers, raw metadata/state, parser exceptions, or arbitrary metadata keys. Keep actual IDs, endpoints, mappings, backups and private evidence outside Git.
- Work in the existing checkout without a worktree. Update main and create the implementation branch only after separate plan approval. Push and merge remain unauthorized.
- Material specification or plan changes return to their respective approval gates; execution rulings cannot silently expand the approved scope.
- Stop after the reviewed policy, desktop findings and recovery; credential selection and other auxiliary policies remain deferred.

## Review focus

1. Duplicate/escaped keys, origin values that merely look absent, and inconsistent UUIDs must not create an eligible title candidate.
2. A healthy earlier read followed by a failed or changed final read must never grant unattributed forwarding; missing tables and orphan edges must block it.
3. Forged title labels on known or mapped identities must retain ordinary resolution outcomes, including unsupported/unmapped failures.
4. Overlapping mapped and title streams must retain separate credentials, attribution, cancellation and diagnostics.
5. Policy changes during activation or recovery must affect readiness without preventing offline rollback or overwriting unrelated edits.

---

### Task 0: Preserve approvals and prepare the implementation branch [size: S | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-09

**Risk:** Preserve approved documents and unrelated work while updating the base.

**Files:** This specification/plan pair. Product files remain untouched.

- [x] After separate approval, record the two approval messages and mark this plan approved. Confirm both artifacts are saved before product changes.
- [x] Inspect tracked, staged and untracked changes; preserve all existing work. Fetch `origin`, fast-forward `main` only, and create `feat/unassigned-title-request-policy` in this checkout. Stop on a concrete preservation conflict; never reset, force, or discard work.
- [x] Commit only the approved pair with `docs: record approved title policy increment`.
- [x] Verify with `git status --short --branch` and `git log -1 --oneline`. **Expected:** Implementation branch, approved-artifact commit, no unexpected changes. Initialize the Native ledger and task/interface pre-flight under the selected execution workflow.

### Task 1: Add policy configuration and readiness compatibility [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-01, AC-08

**Risk:** Mode changes must not undermine safe activation or recovery.

**Files:** Modify `src/config.js`, `test/config-identity.test.js`, and `test/activation.test.js`.

**Interfaces:** `loadRouterConfig(configPath)` adds frozen normalized `allowUnassignedThreadTitles: boolean`; `configFingerprint(config)` appends `allowUnassignedThreadTitles:true` only when enabled, after the existing observation marker. Activation/status/rollback interfaces and record schema stay unchanged.

- [x] Write tests for omission, both booleans, invalid null/string/number/array/object values and sentinel-safe errors. Assert omitted/false fingerprints equal the historical value for each observation mode, and all four effective mode combinations differ as appropriate.
- [x] Add readiness mismatches in both policy directions with unchanged TOML and no activation record. Add legacy `active` and interrupted `prepared` offline rollbacks after changing either/both flags, including unrelated edits and both pre/post-replacement prepared states.
- [x] Run `node --test test/config-identity.test.js test/activation.test.js`. **Expected RED:** New option/default/fingerprint assertions fail against the baseline.
- [x] Implement strict optional-boolean validation and normalization; preserve disabled fingerprints and mode-independent recovery validation.
- [x] Run the same command. **Expected GREEN:** All configuration, ordinary identity and activation tests pass; authentication sentinels remain absent from helper output.
- [x] Commit with `feat: add opt-in unassigned title policy configuration`.

### Task 2: Match the exact initial-title pattern [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-02, AC-05

**Risk:** Client metadata is an eligibility claim and must not bypass strict matching.

**Files:** Create `src/title-policy.js` and `test/title-policy.test.js`.

**Interfaces:** `matchUnassignedTitle(rawHeaders) → string | undefined` is synchronous, does no I/O, and returns only the normalized temporary UUID when the exact request pattern matches. Nonmatches and unusable input return undefined without exposing input. It is independent of the advisory observer.

- [x] Write table-driven tests for the exact two `thread_title` labels; all four UUID claims present/equal; case-insensitive header names; UUID normalization; absence of every parent/fork field; and each missing, conflicting, malformed or unsupported required value.
- [x] Cover identical/differing/escaped duplicates in all seven metadata members, repeated headers, present null/empty origin values, nested lookalikes, braces/quotes/key-like text inside strings, unsupported roots and throwing synthetic inputs. Unknown fields and singleton `request_kind` values must not broaden or restrict matching; duplicate `request_kind` still disqualifies under the approved contract. Use prohibited-content sentinels.

  ```js
  assert.equal(matchUnassignedTitle(titleHeaders(TEMP)), TEMP);
  assert.equal(matchUnassignedTitle(withNullParent), undefined);
  assert.equal(matchUnassignedTitle(withEscapedDuplicate), undefined);
  ```

- [x] Run `node --test test/title-policy.test.js`. **Expected RED:** Missing matcher/module.
- [x] Implement the approved pattern with a valid JSON object, own top-level fields, and decoded top-level key-token duplicate detection before consuming parsed values. No last-value selection or nested capture; leave the ordinary identity and observation parsers unchanged.
- [x] Run the same command. **Expected GREEN:** Every candidate/sentinel case passes; no arbitrary value escapes the matcher.
- [x] Commit with `feat: match the approved initial title request pattern`.

### Task 3: Prove absence within the existing resolution window [size: M | risk: data | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: data,security]

**Acceptance criteria:** AC-02, AC-03, AC-05

**Risk:** Unavailable or changing desktop state must never be mistaken for proven absence.

**Files:** Create `src/title-state.js` and `test/title-state.test.js`; modify `src/identity.js`, `test/helpers/fixtures.js`, and `test/config-identity.test.js`.

**Interfaces:**

- `proveUnassignedTitle(threadId, config, { signal, deadline }) → Promise<boolean>` returns true only for a complete fresh absence proof, false for a known record, and sanitized `STATE_UNAVAILABLE`/`CANCELLED` errors when proof cannot complete. `deadline` is the absolute `Date.now()` deadline owned by the existing lookup.
- `identifyProject(rawHeaders, config, { signal, allowUnassignedTitle = false })` retains its signature compatibly. Its result is the existing frozen mapped resolution or frozen `{ threadId, source: "unassigned_title" }`. Both the internal option and normalized config flag must be true to consider Task 2's matcher.

- [x] Extend synthetic SQLite with `threads(id TEXT PRIMARY KEY)` and helpers for saved rows. Add proof tests for healthy absence and each blocker: own assignment key regardless of its value, projectless entry, thread row, either edge direction regardless of status, missing/unsupported JSON structures, missing tables/columns, malformed JSON, unavailable/locked SQLite, expired deadline and cancellation. Compare state snapshots before/after to prove no writes. Check equivalent UUID casing in saved keys/rows.
- [x] Add deterministic serial fault tests for JSON changes or replacement, SQLite commits/replacement between reads, and a successful initial read followed by a failed final read. Use built-in mocks restored with `syncBuiltinESMExports()`; inject no production hook. Add partial-state recovery and between-request assignment/relationship changes.
- [x] Add resolver tests for ordinary mapped priority, terminal ordinary failures, default/no-route-option behavior, title acceptance only with positive proof, no fallback for saved/orphan identities, one shared budget, cancellation, and immutable per-request results. Ordinary mapped resolution must continue working without a `threads` table when no exception is needed.
- [x] Run `node --test test/title-state.test.js test/config-identity.test.js`. **Expected RED:** Missing proof helper and unimplemented exception outcomes.
- [x] Implement fresh JSON reads bracketing the SQLite check. Validate required containers; test own assignment-key and projectless membership without consuming unrelated values. Use read-only SQLite existence queries for `threads.id` and both edge endpoints, comparing UUIDs without case distinctions. Read no content columns and apply no status filter.
- [x] Guard the proof with unchanged JSON bytes/file identity and stat metadata, unchanged database file identity/stat metadata, and unchanged `PRAGMA data_version` on the same connection across a read transaction and final checks. Normalize failed reads/queries/cleanup to fixed errors. Close every database/handle. A detected change invalidates the attempt; check signal and deadline again before returning true. This detects observed changes without claiming cross-file atomicity.
- [x] Integrate inside the existing retry loop: try ordinary resolution first; only an eligible candidate and `STATE_UNAVAILABLE` may trigger a fresh proof before the current deadline. Never cache a prior absence. Known records cannot authorize; transient proof failures rejoin the same 50 ms cadence. Terminal ordinary errors stay terminal. Do not start a second lookup window or run a proof after expiration.
- [x] Run the same command. **Expected GREEN:** Positive absence grants the exact result; final-check failures and known records never do; existing ordinary identity tests pass unchanged.
- [x] Commit with `feat: prove unassigned title identity with fresh desktop state`.

### Task 4: Integrate unattributed forwarding and diagnostics [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,auth]

**Acceptance criteria:** AC-02, AC-04, AC-05

**Risk:** Mapped and unattributed concurrent requests must retain isolated authentication and outcomes.

**Files:** Modify `src/proxy.js`, `src/diagnostics.js`, `test/proxy.test.js`, and `test/admission-diagnostics.test.js`.

**Interfaces:** `createProxy(config, options)` and `emitDiagnostic(stream, event)` keep their signatures. The proxy supplies `allowUnassignedTitle: true` only for the admitted ordinary Responses operation. Diagnostics add fixed source `unassigned_title` and omit ownership/project/alias fields for that source, independently of observation mode.

- [x] Extend the test setup to select policy before server creation. Cover the four policy/observation combinations, exact accepted titles with permitted queries, disabled rejection, ordinary mapped title-labelled requests, and all noneligible routes/admission failures. Assert no extra observations when observation is off.
- [x] Test unmapped, projectless, saved-thread, orphan-edge, conflicting and unavailable candidates with zero upstream calls. Cover metadata duplicate handling and ensure invalid title-only fields do not add errors for otherwise valid mapped requests. Denied candidates retain fixed existing errors and never acquire the admitted-title source.
- [x] Exercise overlapping mapped and multiple title requests, distinct auth sentinels, unchanged body/header/query bytes, chunks/status, redirects/upstream failures, slow consumers, and cancellation before and after forwarding. Reuse existing transport cases in both policy modes and both observation modes; compare behavior excluding generated IDs/timing. Confirm separate attribution snapshots and upstream cleanup.
- [x] Directly test diagnostic source acceptance, ownership omission even if extra ownership is supplied with that source, safe optional observations, and prohibited-content sentinels.
- [x] Run `node --test test/proxy.test.js test/admission-diagnostics.test.js`. **Expected RED:** New title acceptance and diagnostic assertions fail before integration; existing transport cases remain green.
- [x] Pass the route-scoped option into Task 3's resolver and allow its result through the existing streaming path. Extend diagnostic sanitization without changing admission, forwarding, cancellation or observation collection order.
- [x] Run the same command. **Expected GREEN:** Exact candidates forward unchanged, all rejected candidates make zero upstream calls, and concurrent diagnostics contain only the appropriate ownership or unattributed source.
- [x] Commit with `feat: forward eligible unassigned titles without project attribution`.

### Task 5: Document and validate actual desktop titles, then recover [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-06, AC-07, AC-08, AC-09

**Risk:** Preserve private runtime settings and recovery evidence during temporary activation.

**Files:** Modify `README.md` and `examples/router.example.json`; create `docs/validation/unassigned-title-request-policy.md`.

**Interfaces:** Existing `serve`, `status`, `activate`, and `rollback` CLI commands with explicit private `--config` path. Production startup remains `node --use-system-ca src/cli.js serve --config "$HOME/.codex-project-router/config.json"`.

- [x] Document default-off behavior, exact supported family, additional state/schema requirement, unattributed caller-credential use, spoofable local markers, independent observation, readiness, restart and offline recovery. Update statements/table entries that currently say every unresolved model request blocks. Add `allowUnassignedThreadTitles: false` to the synthetic example; retain deferred credential selection.
- [x] Run `npm ci`, `npm test`, `node --check src/cli.js`, and `git diff --check`. **Expected:** Successful install, full passing suite, clean syntax/whitespace. Keep commands, exit statuses and decisive output for final review.
- [x] Verify Project A, Project B and controller mappings read-only, direct URL and stopped listener. Save a restrictive private checkpoint of the original URL and each flag's exact presence/value. Preserve unrelated settings and existing recovery evidence.
- [x] Ask the user for fresh direct-response baselines in both disposable projects and confirmation that automatic titles appear. Capture completion only; do not place prompt/response/title content in diagnostics or the report.
- [x] Enable policy and, for evidence, observation in private configuration. Start the foreground proxy with private restrictive output, activate using the existing helper, and have the user restart when required. Verify matching readiness and controller attribution.
- [x] Have the user open one new chat in each DIFFERENT project and send controlled requests close together; confirm both responses and automatic visible titles. Obtain a same-chat follow-up. Record sanitized intervals showing overlap and distinguish mapped main requests from unattributed title families. Repeat one paired fresh-chat round if title requests or useful overlap are absent. Do not create/message chats through coordination tools.
- [x] Analyze classification, saved-state absence and outcomes read-only, using symbolic labels in the report. Check observed failures within scope and rerun affected cases; never guess membership, admit a broader family or inspect request content. Classify every required case as observed pass/failure/not run. Missing user actions remain incomplete; demonstrated incompatibility after in-scope fixes/review may conclude with failed capability.
- [x] Roll back the original provider URL and restore each flag's exact prior presence/value while preserving unrelated current edits. Obtain the required user restart and a successful direct response, then stop the proxy. Verify `state=direct`, `proxyReady=false`, no recovery required, and no listener. Preserve private checkpoints/backups; do not delete recovery evidence with execution scratch.
- [x] Complete the sanitized report: app/build/engine/Node versions, mode combinations used, symbolic families and request intervals, overlap, mapped/unattributed outcomes, visible-title confirmation, follow-up, failures, trust/state-snapshot limitations and recovery. Actual IDs/endpoints/mappings/raw evidence remain outside Git.
- [x] Commit with `docs: record unassigned title policy validation`.

### Task 6: Verify and complete the sequential final review [size: S | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01–AC-09

**Risk:** Ensure implementation and actual desktop evidence satisfy the entire increment.

**Inputs:** Approved pair, complete branch diff, changed files, Native ledger and rulings, observed verification evidence, sanitized report and recovery status.

- [x] Run `npm test`, `node --check src/cli.js`, and `git diff --check`. **Expected:** All checks pass; retain exact commands, exit statuses and decisive output.
- [x] Self-check criterion traceability, completed live cases, restored settings, excluded private evidence and task ledger. Create one finalized review package and invoke `personal-workflows:code-review` once in integrated mode: specification review first, quality review only after specification PASS against the same package. No generic or per-task reviewer dispatch.
- [x] Apply the active Native policy: assess findings, record rulings/minors, and perform one verified fix pass for actionable Critical/Important findings using targeted RED→GREEN tests and then the full suite. Do not dispatch a second generic review. Commit verified fixes conventionally and preserve outcome evidence.
- [x] Confirm the approved artifacts, code, tests, documentation and report are committed on the implementation branch; verify Git status and private-file exclusion. Finish execution bookkeeping under the active skills without deleting private recovery evidence.
- [x] Report working behavior, observed desktop/test results, review outcomes, recovery, limitations, all rulings/deferred minors, and implications for later credential routing. Leave push and merge pending; stop this increment.

## Traceability and handoff

| Criterion | Owning tasks / evidence |
|---|---|
| AC-01 | Task 1 configuration/fingerprint/readiness/offline recovery; Task 4 mode matrix |
| AC-02 | Task 2 exact matcher; Task 3 resolver precedence; Task 4 route/admission boundaries |
| AC-03 | Task 3 absence/freshness/schema/cancellation/state-change tests |
| AC-04 | Task 4 transport/isolation/zero-call tests and existing forwarding path |
| AC-05 | Tasks 2–4 sentinels, source/ownership and disabled-mode parity |
| AC-06 | Task 5 direct/proxied A/B titles, overlap and follow-up |
| AC-07 | Task 5 sanitized report and private evidence |
| AC-08 | Task 1 offline recovery; Task 5 actual restoration/restart/direct response/shutdown |
| AC-09 | Tasks 0 and 5–6 approved artifacts, documentation, checks and sequential review |

**Execution endpoint:** Deliver the reviewed opt-in exception and desktop findings, restore direct operation and exact prior settings, verify a direct response, stop the proxy, and stop before per-project credentials or other background-request policies.

**Current stage:** Implementation complete — verification, desktop recovery and sequential review recorded in the validation report.

**Approval record:** Specification approved in the user message reproducing it; this separate plan approved by the subsequent “approved” message.

**Approval authorizes:** Implementation of this increment using Native execution after recording plan approval and safely preparing the implementation branch. Specification approval was already recorded; no product code had changed when this plan was approved.

**Execution result:** Completed on `feat/unassigned-title-request-policy`; see [sanitized validation report](../../validation/unassigned-title-request-policy.md). Both review stages passed; one Minor report-wording finding is deferred under the Native policy. Push and merge remain unauthorized.
