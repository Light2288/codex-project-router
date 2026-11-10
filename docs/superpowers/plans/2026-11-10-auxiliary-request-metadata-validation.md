# Auxiliary request metadata validation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement`. Implement task by task using the selected Native execution method.

**Goal:** Identify what safe feature and origin metadata actual desktop requests provide, without changing request admission, project resolution, or credentials.

**Architecture:** An optional observer collects allowlisted metadata after model-request admission and before identity resolution. The diagnostic writer independently sanitizes its output. Existing forwarding and activation safeguards remain authoritative.

**Tech Stack:** Node.js 24, JavaScript ES modules, built-in HTTP/HTTPS and test libraries; existing `smol-toml@1.9.1`. No new dependencies.

**Spec:** docs/superpowers/specs/2026-11-10-auxiliary-request-metadata-validation.md

**Slug:** `auxiliary-request-metadata-validation`  
**Status:** APPROVED  
**Created:** 2026-11-10  
**Updated:** 2026-11-10  
**Execution tier:** full  
**Implementation model role:** full  
**Execution method:** Native  
**Provenance:** Approved specification; Native selected through interactive clarification. Separately approved by the user's “PLEASE IMPLEMENT THIS PLAN” message reproducing this implementation plan after presentation.

**Destination:** `/Users/davide/Personal/Projects/codex-project-router/docs/superpowers/plans/2026-11-10-auxiliary-request-metadata-validation.md`

## Evidence and decisions

- Verified checkout: `/Users/davide/Personal/Projects/codex-project-router`.
- `main` and the local `origin/main` reference both point to `7305e0904cdafa24e62e3a9608909b95676f7f54`.
- The approved specification is the only local change and remains untracked at planning time.
- Specification resolution: `NEW_ONLY`. Implementation-plan resolution: `MISSING` before saving this approved plan.
- No architecture map, ADRs, or legacy candidates were found; map freshness and ADR constraints are inapplicable.
- Node is `24.21.0`. The last observed baseline has 68 passing tests.
- Existing configuration fingerprints drive readiness; activation records contain no fingerprint. Observation mode therefore needs no recovery-record migration.
- Verification commands come from `package.json`, README development checks, and the previous approved plan’s targeted `node --test` pattern.

The specification was approved by the user’s message beginning “PLEASE IMPLEMENT THIS PLAN” that reproduced it. This plan received separate approval in the later message reproducing this implementation plan.

## Global constraints

- Retain the current local macOS/Node.js 24 target, loopback binding, normal TLS verification, system CA support, and read-only desktop-state access.
- `observeRequestMetadata` is an optional strict boolean, defaulting to `false`, under `schemaVersion: 1`.
- Preserve existing admission decisions, identity resolution, caller credentials, forwarding, streaming, and cancellation.
- Claims about parents or fork sources confer no routing authority.
- Never infer projects from prompts, folders, foreground UI, nearby requests, or feature labels.
- Never log prompts, responses, credentials, whole headers, raw metadata, arbitrary metadata keys, raw desktop state, or parser exception text.
- Keep actual identifiers, endpoints, mappings, backups, and private evidence outside Git.
- Work in the existing checkout; create no worktree. Push and merge remain unauthorized.
- Stop before background-request exceptions, new identity fallbacks, or project-based credentials.

## Observation contract

Add the optional diagnostic property `requestMetadata`. Disabled mode omits it entirely.

```text
Observation {
  state: collected | unavailable
  turnMetadata: {
    state: absent | present | duplicate | malformed | unsupported | unavailable
    type: JsonType
    fields: fixed seven metadata fields → FieldObservation
  }
  headers: fixed three header fields → FieldObservation
}

FieldObservation {
  state: absent | valid | invalid | duplicate | unsupported | unavailable
  type: JsonType
  conflict: none | different | unassessed
  label?: fixed feature label or other
  id?: lowercase UUID
}

JsonType =
  absent | string | number | boolean | null | array | object | unknown
```

Use the original input names as field keys:

- Metadata: `thread_source`, `turn_trigger`, `request_kind`, `thread_id`, `session_id`, `parent_thread_id`, `forked_from_thread_id`.
- Headers: `thread-id`, `session-id`, `x-codex-parent-thread-id`.

Apply these rules:

- Feature strings emit only the specification’s nine labels or `other`. Invalid primitive types emit no label; arrays and objects are unsupported.
- Identifier strings emit an `id` only when they match the existing UUID syntax.
- Duplicate fields emit neither an ID nor a label, even when values match. Their type is `unknown`; no occurrence wins.
- Compare only valid singleton claims for the same role: header/metadata thread, session, and parent pairs. Mark both fields `different` when their UUIDs disagree, `none` when equal, and otherwise `unassessed`.
- Do not compare thread against session, parent against fork source, or feature fields against one another.
- Absent metadata produces absent metadata fields. Malformed, duplicated, or unsupported metadata containers make their child observations unavailable; independent header observations remain available.
- Unexpected collection failures return the fixed unavailable observation. They add no admission error.
- The diagnostic writer reconstructs the fixed schema, validates enums and claims again, and discards extra properties. Invalid observation structures become the fixed unavailable observation.

## Review focus

1. Escaped duplicate keys, misleading string contents, and nested keys must never produce an arbitrary claim.
2. Unknown values, unsupported shapes, and collection failures must remain useful diagnostics without exposing their contents.
3. Observation must occur only after admission and must accompany later identity failures without influencing resolution.
4. Overlapping requests and cancellation must retain separate observation snapshots and existing resource cleanup.
5. Mode changes must affect readiness while preserving legacy activation records and offline rollback.

## Implementation tasks

### Task 0: Preserve approvals and prepare the branch [size: S | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-08  
**Risk:** Preserve approved artifacts and unrelated local work during branch preparation.

**Files:** The approved specification and this plan at the paths above.

- [x] After separate plan approval and leaving Plan Mode, save this plan and record its approval. Identify both artifacts and their separate approval messages before product changes.
- [x] Inspect tracked, staged, and untracked changes. Preserve all existing work.
- [x] Fetch `origin`; update `main` by fast-forward only. Stop on a concrete conflict rather than resetting or overwriting local work.
- [x] Create `feat/auxiliary-request-metadata-validation` in this checkout.
- [x] Commit only the approved artifacts with `docs: record approved metadata validation increment`.

**Expected:** Both approved artifacts are saved on the implementation branch; unrelated work remains preserved.

### Task 1: Add observation configuration and readiness compatibility [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-01, AC-03, AC-07

**Files:**

- Modify `src/config.js`.
- Extend `test/config-identity.test.js` and `test/activation.test.js`.

**Interfaces:**

- `loadRouterConfig(configPath)` returns the existing frozen configuration plus normalized `observeRequestMetadata: boolean`.
- `configFingerprint(config)` treats omitted and `false` identically; `true` differs.
- Activation, status, rollback, CLI signatures, and activation-record schema remain unchanged.

- [x] Write configuration tests for omission, explicit booleans, and invalid values including `null`, strings, numbers, arrays, and objects. Check sanitized errors with sentinels.

  ```js
  assert.equal(loaded.observeRequestMetadata, false);
  assert.equal(configFingerprint(omitted), configFingerprint(off));
  assert.notEqual(configFingerprint(off), configFingerprint(on));
  ```

- [x] Add activation tests for enabled/disabled readiness mismatches in both directions, unchanged TOML on failed activation, and rollback after a mode change with the proxy unavailable. Cover existing active and interrupted `prepared` records and preservation of unrelated edits.
- [x] Run `node --test test/config-identity.test.js test/activation.test.js`.

  **Expected:** New assertions fail because the option is unsupported and fingerprints do not distinguish modes.

- [x] Accept the optional boolean and normalize omission to `false`. Preserve the existing disabled-mode fingerprint by appending an observation-mode marker to its canonical input only when enabled. Keep recovery-record validation independent of observation mode.
- [x] Run the same command.

  **Expected:** All cases pass, including existing identity tests and recovery records without any new fields.

- [x] Commit with `feat: add opt-in metadata observation configuration`.

### Task 2: Collect and sanitize allowlisted observations [size: M | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-02, AC-03

**Files:**

- Create `src/request-metadata.js`.
- Create `test/request-metadata.test.js`.
- Extend `src/diagnostics.js` and `test/admission-diagnostics.test.js`.

**Interfaces:**

- `collectRequestMetadata(rawHeaders) → Observation`
- `sanitizeRequestMetadata(value) → Observation`
- `emitDiagnostic(stream, event)` accepts optional `event.requestMetadata`.

Both new helpers are synchronous, perform no I/O, and return only the contract above.

- [x] Write table-driven tests for every allowed field, feature label, JSON type, absence, invalid UUID, uppercase UUID normalization, and unknown feature value.
- [x] Add duplicate tests with identical and differing values, escaped key spellings, case-insensitive header names, nested lookalikes, braces and escaped quotes inside strings, and duplicate parent headers. Verify malformed and non-object metadata roots.
- [x] Add conflict tests for same-role header/metadata pairs. Assert that differing current/session IDs are retained separately rather than classified as a same-role conflict.
- [x] Add sentinel tests for unknown keys and values, unsupported nested objects, malformed JSON, and an unexpected collection exception induced by a throwing synthetic input. Exercise the diagnostic writer directly with forged observations and extra properties.

  ```js
  assert.equal(observation.turnMetadata.fields.request_kind.label, "other");
  assert.equal(observation.turnMetadata.fields.thread_id.state, "duplicate");
  assert.equal(observation.turnMetadata.fields.thread_id.id, undefined);
  assert.doesNotMatch(JSON.stringify(observation), /SENTINEL/);
  ```

- [x] Run `node --test test/request-metadata.test.js test/admission-diagnostics.test.js`.

  **Expected:** Failures for the missing collector and unsupported diagnostic property.

- [x] Implement collection and sanitization. Validate JSON syntax, then detect duplicate allowlisted top-level members using decoded key tokens and structural depth before consuming parsed field values. Use the existing identity parser’s tokenization approach without refactoring identity resolution. Inspect only own allowlisted fields.
- [x] Extend the diagnostic writer to rebuild sanitized observations only when the optional property is supplied. Preserve all existing diagnostic fields and error handling.
- [x] Run the same command.

  **Expected:** All tests pass; no sentinel, arbitrary key, invalid claim, or parser exception reaches emitted diagnostics.

- [x] Commit with `feat: collect private request metadata observations`.

### Task 3: Integrate observations with unchanged proxy behavior [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,auth]

**Acceptance criteria:** AC-02, AC-03, AC-04

**Files:** Extend `src/proxy.js` and `test/proxy.test.js`.

**Interfaces:**

- `createProxy(config, options)` retains its existing signature.
- Consume Task 2’s collector and attach one request-local observation snapshot to existing diagnostic events.

- [x] Extend the test setup to select observation mode before creating the proxy.
- [x] Add enabled/disabled tests proving:
  - Successful responses and compaction requests receive observations only when enabled.
  - Later malformed-identity, conflict, unmapped, and unresolved failures retain observations.
  - Early admission failures, health, and catalog events omit observations.
  - Duplicate metadata members are observed before identity rejection; duplicate headers rejected by admission remain unobserved.
  - Unknown or malformed observation-only fields do not change the result.
  - Parent/fork claims cannot admit an unresolved chat or redirect a mapped chat.

  For an unresolved chat claiming a mapped fork source:

  ```js
  assert.equal(result.status, 503);
  assert.equal(JSON.parse(result.body).error.code, "STATE_UNAVAILABLE");
  assert.equal(calls.length, 0);
  ```

- [x] Run the existing forwarding, overlapping-request, streaming, slow-consumer, upstream-error, and client-cancellation cases in both modes. Compare destination, status, credential, body bytes, forwarded metadata, response chunks, and cleanup; ignore generated correlation IDs and timing differences. Assert distinct observations for overlapping requests.
- [x] Run `node --test test/proxy.test.js`.

  **Expected:** New enabled-mode diagnostic assertions fail before integration; existing transport behavior remains green.

- [x] Collect only when observation is enabled and admission returns a model request. Collect before `identifyProject`, retain the snapshot in the existing request closure, and include it in subsequent diagnostic events. Leave identity inputs, forwarding headers, bodies, and cancellation flow unchanged.
- [x] Run the same command.

  **Expected:** All parity and isolation tests pass; rejected requests make zero upstream model calls, cancellation still closes upstream work, and diagnostics contain no sentinels.

- [x] Commit with `feat: observe admitted model requests without changing routing`.

### Task 4: Document and complete controlled desktop validation [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-05, AC-06, AC-07, AC-08  
**Risk:** Preserve private runtime configuration and recovery evidence while temporarily activating observation.

**Files:**

- Update `README.md`.
- Update `examples/router.example.json`.
- Create `docs/validation/auxiliary-request-metadata-validation.md`.

**Runtime interface:** Existing `serve`, `status`, `activate`, and `rollback` commands with the private configuration path. No new CLI command.

- [x] Document the default-off setting, restart requirement, observation schema and privacy boundaries, unchanged blocking, readiness behavior, and mode-independent rollback. Show `observeRequestMetadata: false` in the synthetic example. Retain the production startup command using `node --use-system-ca`.
- [x] Run `npm ci`, `npm test`, `node --check src/cli.js`, and `git diff --check`.

  **Expected:** Installation succeeds; all tests pass; syntax and whitespace checks succeed.

- [x] Verify the existing Project A, Project B, and controller mappings read-only. Verify direct configuration and proxy shutdown. Save a restrictive private checkpoint recording the prior observation property, including whether it was absent, and the direct provider URL.
- [x] Ask the user to establish fresh direct-response baselines in both disposable projects. Record completion without capturing prompt or response content.
- [x] Enable observation in private configuration, preserving other settings. Start the foreground proxy with restrictive private diagnostic output, activate through the existing helper, and have the user restart the desktop when required.
- [x] Have the user send first requests in one new chat in Project A and one new chat in Project B, close together. Then obtain a follow-up control in one of those chats. Do not create or message other chats through coordination tools.
- [x] Observe the resulting request families, including lookup failures and retries. If auxiliary requests or useful overlap are absent, repeat one paired fresh-chat round. Record an observed absence explicitly; do not infer a feature from timing alone.
- [x] Analyze allowlisted classifications and UUID claims against saved assignments and spawn relationships read-only. Keep actual IDs and relationship evidence private. Distinguish supported feature labels, origin claims, absent fields, unsupported structures, and inference.
- [x] Restore the direct provider URL using rollback and restore the prior observation property, preserving unrelated current settings. Have the user restart when required, verify a successful direct response, then stop the proxy. Confirm `state=direct` and `proxyReady=false`; preserve private recovery evidence.
- [x] Write the sanitized report using symbolic request/chat labels instead of actual IDs. Include app/engine/Node versions, mode, intervals, overlap, diagnostic classifications, relationship findings, recovery outcome, and remaining uncertainty.

**Required report cases:**

| Case | Required evidence |
|---|---|
| Fresh Project A chat | Main request result and accompanying request family |
| Fresh Project B chat | Same, distinguishable from Project A |
| Follow-up control | Correct existing attribution and observed metadata |
| Auxiliary requests | Observed classification, absent/unsupported fields, or explicit non-observation |
| Origin claims | Saved relationship confirmed, absent, conflicting, or unverified |
| Recovery | Prior observation setting restored; direct response verified; proxy stopped |

Classify execution cases as observed pass, observed failure, or not run. An absent or unsupported metadata format is a valid finding. Missing user actions leave live validation incomplete.

- [x] Commit documentation and the completed sanitized report with `docs: record auxiliary metadata validation findings`.

### Task 5: Complete verification and sequential review [size: S | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01–AC-08  
**Risk:** Ensure the delivered evidence and implementation satisfy the entire increment.

**Inputs:** Approved artifacts, complete branch diff, changed files, observed test results, sanitized live report, and the Native execution ledger.

- [ ] Run `npm test`, `node --check src/cli.js`, and `git diff --check`.

  **Expected:** All checks pass. Retain exact commands, exit statuses, and decisive output for review.

- [ ] Invoke `personal-workflows:code-review` once in integrated mode as the sole whole-branch review gate: specification review first, then quality review only after a specification PASS, using the same finalized review package.
- [ ] Handle findings under the Native execution policy: one verified fix pass for actionable Critical/Important findings, targeted RED→GREEN tests, then the full suite. Record rulings and deferred minor findings; do not dispatch a second generic review.
- [ ] Commit any verified fixes with an appropriate conventional message. Confirm the branch contains the approved artifacts, implementation, documentation, and sanitized report, with private evidence excluded.
- [ ] Report observed results, limitations, review outcomes, recovery status, and implications for a later handling increment. Leave push and merge pending.

## Traceability and handoff

| Criterion | Owning tasks / evidence |
|---|---|
| AC-01 | Task 1 configuration, fingerprint, activation and rollback tests |
| AC-02 | Tasks 2–3 collector, diagnostic and proxy tests |
| AC-03 | Tasks 1–3 malformed-input and sentinel tests |
| AC-04 | Task 3 enabled/disabled transport and admission parity |
| AC-05 | Task 4 desktop validation |
| AC-06 | Task 4 sanitized report and private evidence |
| AC-07 | Tasks 1 and 4 recovery compatibility and actual restoration |
| AC-08 | Tasks 0, 4 and 5 artifacts, documentation, checks and review |

**Execution endpoint:** Deliver reviewed opt-in observations and desktop findings, restore direct operation and the prior observation setting, verify a direct response, stop the proxy, and stop before changing auxiliary-request admission or selecting credentials.

**Current stage:** Stage 4 — implementation, separately approved.  
**Approval evidence:** The earlier user message reproducing the DRAFT specification approved that specification; the later user message reproducing this implementation plan separately approved this plan. Both are saved before product-code changes.
