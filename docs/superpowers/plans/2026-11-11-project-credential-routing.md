# Project Credential Routing — Implementation Plan

> **For agentic workers:** Use `personal-workflows:spec-implement` with `superpowers:subagent-driven-development`. Execute tasks sequentially with fresh implementers and task reviews. Steps use checkbox syntax.

**Goal:** Select each mapped chat’s API credential from Keychain while preserving authenticated global-credential handling for catalogs and qualifying unassigned titles.

**Architecture:** Extend private configuration and its readiness fingerprint. Add one bounded Keychain reader, then integrate authentication and credential selection into the existing proxy without changing identity resolution or title eligibility.

**Tech Stack:** Node.js 24, JavaScript ES modules, built-in child-process/crypto/HTTP/HTTPS/test APIs, existing `smol-toml@1.9.1`. No new dependency or CLI command.

**Spec:** [Approved specification](../specs/2026-11-11-project-credential-routing.md)

**Slug:** `project-credential-routing`

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-11

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Subagent-driven

**Provenance:** Separately approved specification and subsequent native selection of subagent-driven execution. The user separately approved this implementation plan in the latest `PLEASE IMPLEMENT THIS PLAN` message reproducing it. Saved after returning to Default mode; implementation of this approved scope is authorized.

## 1. Evidence, constraints and review focus

Repository HEAD at planning was `cd58067e3a4c613c13533e5f4836f12a5c86922e` on `main`. The approved specification was the only untracked change. Specification resolution was `NEW_ONLY`; plan resolution was `MISSING` before this plan was saved.

No architecture map or ADR exists. Map freshness and recorded map HEAD are therefore unavailable. Planning checked the configuration, admission, proxy, identity, diagnostics, activation, CLI and test paths against this repository HEAD. Node is `24.21.0`; the recorded baseline is 259 passing tests, not rerun during planning.

Command sources are the current package script, README development/operation instructions and the approved specification:

- `npm test`
- `node --check src/cli.js`
- `git diff --check`
- Existing `serve`, `status`, `activate` and `rollback` CLI commands with an explicit private configuration path.

Global constraints:

- Preserve legacy behavior and fingerprints when `credentialRouting` is absent; perform zero Keychain calls in that mode.
- Preserve `schemaVersion: 1`, existing identity resolution, title eligibility, transport and privacy boundaries.
- Enforce the specification’s five-second lookup timeout, separate 16 KiB output limits and 1–8,192-byte visible-ASCII token limit.
- Read credentials per request; never cache, fall back, retry another key, rewrite payloads or follow redirects.
- Keep secrets and actual runtime evidence outside Git and tool output.
- Use the existing checkout. Save both approved artifacts before product edits; update `main` safely and create `feat/project-credential-routing` only after plan approval.
- Preserve unrelated work. No worktree, push or merge into another branch.
- Resolve the managed `full` implementation role at execution time. Each implementer receives that model explicitly with high reasoning. Preserve per-task reviews and the sole integrated sequential final review.
- Material specification or plan changes return to their respective approval gates.

Review focus, each covered below:

1. A bad global token must fail before observations or desktop-state access, even when identity state is broken.
2. Missing aliases named `constructor` or `toString` must not resolve through inherited object properties.
3. Split output chunks, invalid bytes and successful-looking output from a failed child must never produce a credential.
4. Cancellation during either lookup must terminate pending work and prevent forwarding.
5. Rotation, project movement and unavailable Keychain access must preserve request snapshots and recovery.

## 2. Implementation tasks

### Task 1: Validate credential configuration and preserve readiness compatibility [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-07, AC-08

**Risk:** Configuration must identify only explicit credential references and preserve safe activation/recovery.

**Files:** Modify [config.js](/Users/davide/Personal/Projects/codex-project-router/src/config.js), [errors.js](/Users/davide/Personal/Projects/codex-project-router/src/errors.js), [config-identity.test.js](/Users/davide/Personal/Projects/codex-project-router/test/config-identity.test.js), [activation.test.js](/Users/davide/Personal/Projects/codex-project-router/test/activation.test.js) and [admission-diagnostics.test.js](/Users/davide/Personal/Projects/codex-project-router/test/admission-diagnostics.test.js).

**Interfaces:** Preserve `loadRouterConfig(configPath)` and `configFingerprint(config)`. Loaded enabled configurations expose deeply frozen `credentialRouting.globalCredential` and `credentialRouting.routeCredentials`. Legacy configurations omit the new property.

- [ ] Record the separate specification and plan approvals. Save both artifacts, inspect all changes, fetch `origin`, fast-forward `main` safely, create `feat/project-credential-routing`, and commit only the approved pair. Preserve conflicting work rather than resetting or forcing.
- [ ] Add tests for the exact optional schema: required fields, unknown fields, absolute paths, empty/control-containing/overlength strings, malformed references, valid shared/unused references and an empty credential map. Retain the existing historical fingerprint assertion.
- [ ] Assert deep freezing, equivalent fingerprints under reordered fields/maps, and fingerprint changes for routing/reference changes. Include valid own alias names such as `constructor`.
- [ ] Add fixed error definitions and assertions:

  ```text
  AUTH_INVALID          401  The incoming bearer credential is not accepted.
  CREDENTIAL_UNMAPPED   422  The assigned route has no credential reference.
  CREDENTIAL_UNAVAILABLE 503 The required credential could not be retrieved.
  ```

- [ ] Run `npm test`. **Expected RED:** New configuration or error assertions fail against the baseline.
- [ ] Implement strict validation without environment/tilde expansion. Canonicalize references in fixed field order and sort alias entries before fingerprinting; append enabled routing data without changing the legacy canonical representation.
- [ ] Run `npm test`. **Expected GREEN:** Configuration, diagnostics and activation regressions pass.
- [ ] Commit as `feat: validate project credential routing configuration`, then complete the task review.

### Task 2: Implement bounded, private Keychain retrieval [size: M | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-04, AC-06, AC-07

**Risk:** Subprocess failures and malformed output must never leak or authorize credentials.

**Files:** Create `/Users/davide/Personal/Projects/codex-project-router/src/credentials.js` and `/Users/davide/Personal/Projects/codex-project-router/test/credentials.test.js`.

**Interface:**

```text
readKeychainCredential(
  reference,
  { signal, spawnProcess = spawn } = {}
) → Promise<string>
```

`spawnProcess` is an in-process test seam, unavailable through configuration or CLI. The function returns a validated token or throws a fresh sanitized `CREDENTIAL_UNAVAILABLE`/`CANCELLED` error.

- [ ] Write reader tests that inspect the exact executable, separate arguments and piped output:

  ```text
  /usr/bin/security
  find-generic-password -a ACCOUNT -s SERVICE -w ABSOLUTE_KEYCHAIN_PATH
  ```

  Require no shell and ignored stdin.

- [ ] Test token lengths 0, 1, 8,192 and 8,193; no terminal LF, one LF and multiple LFs; CRLF, spaces, tabs, NUL, DEL and non-ASCII bytes. Exercise chunk boundaries before decoding.
- [ ] Test spawn errors, nonzero exit, signal termination, plausible stdout followed by failure, independent stdout/stderr overflow, timeout and cancellation before/during lookup. Verify rejection waits for child cleanup.
- [ ] Use fake process streams for deterministic boundaries and Node-only synthetic children for actual termination/reaping coverage. Never execute Keychain in tests.
- [ ] Run `npm test`. **Expected RED:** The reader is absent or fails the specified contract.
- [ ] Implement byte-counted output handling and a five-second timer. On cancellation, timeout or overflow, terminate the direct child and await closure; clear timers/listeners on every terminal path. Do not expose raw process errors or output.
- [ ] Run `npm test`. **Expected GREEN:** Reader boundaries and cleanup tests pass, without surviving synthetic children.
- [ ] Commit as `feat: add bounded Keychain credential retrieval`, then complete the task review.

### Task 3: Authenticate callers and select outgoing credentials [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-02, AC-03, AC-04, AC-05, AC-07

**Risk:** Stored project keys must be reachable only after successful global-token verification and ordinary project resolution.

**Files:** Modify [proxy.js](/Users/davide/Personal/Projects/codex-project-router/src/proxy.js) and [proxy.test.js](/Users/davide/Personal/Projects/codex-project-router/test/proxy.test.js).

**Interfaces:** Extend the existing options without changing existing defaults:

```text
createProxy(config, {
  diagnostics,
  upstreamAgent,
  inactivityTimeoutMs,
  credentialReader = readKeychainCredential
})
```

The reader receives a reference and `{ signal }`. Keep admission and identity interfaces unchanged. Extend the existing test helpers to accept routing configuration, an injected reader and an explicit authorization value.

- [ ] Add failing tests for global mismatch, case-sensitive token comparison, case-insensitive scheme parsing and global retrieval failure. Use broken desktop state to prove authentication takes precedence; assert no observations, project lookup or upstream call.
- [ ] Test exact project-key substitution for Responses and dedicated compaction, shared aliases/references, saved ancestry and mapped requests carrying title markers.
- [ ] Test missing credential mappings and failed project reads alongside a healthy second project. Use `Object.hasOwn` semantics: absent `constructor`/`toString` entries produce `CREDENTIAL_UNMAPPED`, while explicit own entries work.
- [ ] Test catalog and qualifying unassigned-title forwarding with the original caller authorization. Assert no project-key reads and unchanged title attribution/eligibility.
- [ ] Run `npm test`. **Expected RED:** Requests still forward caller credentials or fail the new authentication assertions.
- [ ] Authenticate after admission/health handling and before observation or identity resolution. Compare equal-length token buffers with `timingSafeEqual`.
- [ ] Select credentials only after the existing resolver succeeds. Explicitly set the intended authorization after hop filtering, including when `Connection` names `authorization`. Record `started` only after credential selection succeeds.
- [ ] Check cancellation after asynchronous stages and immediately before forwarding. Keep secret values in local variables, outside resolution objects and diagnostics.
- [ ] Run `npm test`. **Expected GREEN:** Selection, precedence and privacy assertions pass.
- [ ] Commit as `feat: route authenticated requests with project credentials`, then complete the task review.

### Task 4: Verify lifecycle isolation and transport parity [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-06, AC-07

**Risk:** Overlapping requests, cancellation and rotation must not share credentials or retain pending work.

**Files:** Modify the existing proxy and proxy/credential tests where necessary. Reuse Task 2 and Task 3 interfaces; add no public API.

- [ ] Add overlapping mapped/title streams with one incoming global token and distinct outgoing credentials. Use barriers to prove simultaneous upstream activity and independent outcomes.
- [ ] Move a chat while its project lookup/stream is in progress. Assert that the existing request retains its selected alias/key and the next request uses the new assignment.
- [ ] Rotate/delete fake stored values between requests. Assert fresh reads, rejection of stale global tokens, affected-project failure and continued operation for another project. Include an explicit global/project reference shared by both roles; perform both lookups without deduplication.
- [ ] Cover disconnects during global and project retrieval, request errors, forced connection closure and delayed child completion. Require zero forwarding after cancellation and preservation of the initiating `499/CANCELLED` outcome.
- [ ] Run `npm test`. **Expected RED where behavior is missing:** New lifecycle assertions expose any teardown or snapshot defect; retain already-passing regressions.
- [ ] Ensure terminal proxy failures abort pending lookups after recording their initiating outcome. Preserve existing streaming, backpressure, TLS, inactivity and upstream-error behavior.
- [ ] Exercise enabled routing under both observation/title settings, alongside the existing legacy matrix. Include streaming, slow consumers, redirects without retries, malformed HTTP and sentinel filtering.
- [ ] Run `npm test`. **Expected GREEN:** All mode combinations and lifecycle regressions pass.
- [ ] Commit as `test: verify credential routing lifecycle isolation`, including any necessary fixes, then complete the task review.

### Task 5: Document operation and complete desktop validation/recovery [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: security]

**Acceptance criteria:** AC-01, AC-02, AC-08, AC-09

**Risk:** Provider activation affects desktop availability; completion also requires user-observed desktop outcomes.

**Files:** Update [README.md](/Users/davide/Personal/Projects/codex-project-router/README.md) and relevant activation/CLI tests. Create `/Users/davide/Personal/Projects/codex-project-router/examples/router.credentials.example.json` and `/Users/davide/Personal/Projects/codex-project-router/docs/validation/project-credential-routing.md`.

**Interfaces:** Preserve the existing CLI and activation record schema. Keep the current legacy example; provide a separate synthetic enabled example.

- [ ] Add control-path regressions with credential routing configured: startup, health, status, activation and rollback must not retrieve credentials. Cover changed fingerprints, existing activation records, interrupted/offline recovery and unrelated TOML edits.
- [ ] Run `npm test`. **Expected:** These compatibility assertions pass; correct any in-scope regression without introducing credential preflight into control commands.
- [ ] Document manual Keychain Access provisioning, explicit references, optional enablement, missing-key behavior, token refresh, lookup limits, trust/privacy boundaries and recovery.
- [ ] Run `npm test`, `node --check src/cli.js` and `git diff --check`. **Expected:** Zero failures and clean syntax/whitespace checks. Retain exact commands, exit statuses and decisive output.
- [ ] Privately checkpoint the direct URL and exact prior configuration, including omitted properties. Obtain user-provisioned references for distinct A/B keys, the global key and an explicit controller route. Do not copy secret values into tools, reports or Git.
- [ ] Follow the README’s existing direct-baseline, separate-Terminal `serve`, `status` and `activate` procedure. The user performs desktop interactions and required restarts.
- [ ] Validate fresh A/B responses and automatic titles, overlapping requests, same-chat follow-up, reassignment and the subsequent request. Exercise fork/subagent/compaction opportunistically and record unrun cases.
- [ ] Record symbolic aliases, sources, outcomes and intervals. Timestamp intervals exclude preceding lookup work; `elapsedMs` includes it. Local selection/transport evidence does not establish gateway account or billing attribution.
- [ ] Restore exact prior settings and direct URL while preserving unrelated edits. Use rollback, restart as required, obtain a user-confirmed direct response, then stop the proxy and verify no listener remains.
- [ ] Commit the documentation and sanitized report, then complete the task review. Missing required actions/evidence leaves AC-09 pending; failures remain visibly failed.

## 3. Traceability, final review and handoff

| Criteria | Owning tasks |
|---|---|
| AC-01 | 1, 5 |
| AC-02 | 3, 5 |
| AC-03 | 3, 4 |
| AC-04 | 2, 3, 4 |
| AC-05 | 3, 4 |
| AC-06 | 2, 4 |
| AC-07 | 1–4 |
| AC-08 | 1, 5 and final gate |
| AC-09 | 5 |

After all task reviews and required validation:

- [ ] Run the required final checks and retain observed evidence.
- [ ] Invoke `personal-workflows:code-review` exactly once in integrated mode as the sole whole-branch review seat. Use one immutable package containing the approved artifacts, complete diff, changed-file list and observed evidence. Run specification review first; quality review opens only after its verified PASS.
- [ ] Handle findings under the selected subagent workflow’s fix-loop policy. Do not add a duplicate generic final reviewer.
- [ ] Commit final evidence/dispositions and finish with the implementation branch local. Report working behavior, tests, desktop evidence, recovery, limitations and pending integration.

**Execution endpoint:** Complete this credential-routing increment, verification and review; restore direct operation and exact prior settings; verify a direct response and stopped listener; report the result; stop before later increments. Push and merge remain unauthorized.

**Self-review:** All nine acceptance criteria have task coverage; interfaces agree across tasks; each review-focus case has explicit tests. No material planning decision remains unresolved.

**Approval record:** The specification was separately approved in the earlier `PLEASE IMPLEMENT THIS PLAN` message reproducing the specification, and the user approved this separately presented plan in the latest `PLEASE IMPLEMENT THIS PLAN` message reproducing this plan. Current stage: Stage 4 — implementation authorized. Both approved artifacts are saved before product changes.
