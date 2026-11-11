# Project Credential Routing — Amended Implementation Plan

> **For agentic workers:** Use `personal-workflows:spec-implement` with `superpowers:subagent-driven-development`. Execute the remaining tasks sequentially with fresh implementers and task reviews. Steps use checkbox syntax. Resume at Task 6; do not repeat completed work.

**Goal:** Complete project credential routing by selecting an explicit Keychain credential and full HTTPS API base URL together, while preserving the global target for catalogs and qualifying unassigned titles.

**Architecture:** Replace the unmerged key-only configuration with deeply frozen route targets. Extend the existing request-local selection to include the destination, using the existing bounded credential reader, authentication, identity resolution and transport. Configuration and its proxy consumer change together so tests and runtime do not require a transitional configuration dialect.

**Tech Stack:** Node.js 24, JavaScript ES modules, built-in child-process/crypto/HTTP/HTTPS/test APIs, existing `smol-toml@1.9.1`. No new dependency, public API or CLI command.

**Spec:** [Approved amended specification](../specs/2026-11-11-project-credential-routing.md)

**Slug:** `project-credential-routing`

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-11

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Subagent-driven

**Provenance:** Revision of `docs/superpowers/plans/2026-11-11-project-credential-routing.md`; its original approved content remains in Git at `639cbeb`. The user separately approved the amended scope/design with `confirm`, then the amended specification with `approved`. Native answers selected explicit credential/URL pairs and replacement of the unmerged key-only format. Preserve the earlier explicit subagent-driven execution choice. The subsequent separate `approved` message, immediately following this revised DRAFT plan handoff, approves this revised plan and authorizes Stage 4 implementation of the amendment.

## 1. Repository evidence and resumption

Planning HEAD is `639cbeb` on `feat/project-credential-routing`, in the existing checkout. Artifact resolution is `NEW_ONLY` for both paths above; slug and Spec reference agree. Product files are unchanged during planning. Node reports `v24.21.0`. Latest recorded verification is 586/586 tests, syntax and whitespace checks passing; these tests were not rerun while planning.

No architecture map or ADR was discovered under the repository's architecture/ADR locations. Map freshness and map HEAD are unavailable; do not generate a map. Inspected configuration/fingerprints, proxy admission/forwarding, credential-reader interfaces, activation/CLI controls, test fixtures and validation evidence against the planning HEAD. No material planning question remains unresolved.

The package script (`node --test test/*.test.js`), README development checks and approved specification supply the exact required commands: `npm test`, `node --check src/cli.js`, `git diff --check`. Live operation uses the existing `serve`, `status`, `activate` and `rollback` commands with an explicit private configuration path, as documented in README. Do not introduce gateway probes or real Keychain access into synthetic checks.

| Original work | Retained state |
|---|---|
| Task 1 / configuration | `520bb04`, task review passed |
| Task 2 / bounded reader | `fedac84`, task review passed; retain reader and its tests |
| Task 3 / authentication and key selection | `80e0e3b`, task review passed |
| Task 4 / lifecycle and transport | `04fe73d`, task review passed |
| Task 5 automated controls/documentation | `8a61a30`, implemented; task review still pending |
| Failed live validation and completed recovery | `639cbeb`, sanitized report committed; AC-09 remains incomplete |

Original Tasks 1–4 are complete. Do not rerun their implementers or reviews. Original Task 5's remaining obligations are allocated to Tasks 6 and 8 below; do not dispatch it again. Task 6's review also covers the original unreviewed Task 5 automation/documentation. Task 8's reviewed live evidence closes the remaining original Task 5 obligations. Preserve prior briefs/reports in this plan's SDD workspace; use new task numbers and filenames.

## Global Constraints

- Retain `schemaVersion: 1`, existing private-file validation and the current configuration interface.
- Omitting `credentialRouting` preserves existing behavior and makes **zero Keychain calls**.
- The object contains exactly `globalCredential` and `routeTargets`. Each target contains exactly `upstreamBaseUrl` and `credential`.
- The old `routeCredentials` property is rejected, including when supplied alongside `routeTargets`; there is no implicit migration or compatibility mode for the unmerged key-only format.
- Limit each lookup to five seconds and stdout/stderr to 16 KiB each. Terminate and reap the child on timeout, overflow or cancellation. Accept only 1–8,192 visible ASCII token bytes after removing at most one final LF.
- No failure triggers another credential or destination, a global fallback, a model-request retry or redirect following.
- Do not rewrite models, payloads or continuation identifiers to repair cross-credential or cross-instance gateway incompatibilities.
- Configuration loading, startup, health, status, activation and rollback perform no credential retrieval or upstream-destination preflight. Existing local readiness probes remain permitted.
- Actual endpoints, references, mappings, credentials, gateway error fragments and runtime evidence remain private outside Git and tool output. Only synthetic examples and sanitized symbolic results belong in committed material.
- Use the existing checkout and branch. Preserve initial approvals, commits and completed reviews. No `main` update, new branch, worktree, push or merge is authorized.
- After plan approval, save both approved artifact revisions before product edits. Resolve the managed `full` role at execution time; each fresh implementer explicitly uses that exact model with high reasoning. No implementation subagents run concurrently or spawn their own reviewers.

## Review Focus

1. A leading-slash URL join must not discard a target's API prefix, and its Host must not retain the global host — Task 6 tests distinct ports/prefixes and literal query bytes.
2. Missing/old-format targets and inherited `constructor`/`toString` entries must never create a global fallback — Task 6 covers loading and runtime own-property selection.
3. A bad global token must fail before observation, desktop-state access or project-key lookup, even with distinct destinations — Task 6 retains precedence tests with broken state and zero calls at both origins.
4. Moving a chat during selected-key retrieval or an active stream must not mix the previous destination with the next credential — Task 7 uses barriers and exact per-origin authorization assertions.
5. A project destination's rejection, redirect, TLS failure or disconnect must not send its key to another destination or impair a healthy route — Task 7 asserts per-origin request counts, outcomes and no retry.

---

## 2. Remaining implementation tasks

### Task 6: Integrate explicit route targets and retain control safety [size: L | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-07, AC-08

**Risk:** Configuration, authorization and destination must agree. Keep this integration atomic rather than inventing temporary compatibility behavior. Concurrency stress belongs to Task 7.

**Files:** Modify `src/config.js`, `src/proxy.js`, `test/config-identity.test.js`, `test/proxy.test.js`, `test/activation.test.js`, `test/cli.test.js`, `README.md` and `examples/router.credentials.example.json`. Preserve `examples/router.example.json`, the existing credential reader/error definitions and earlier validation history. Inspect unchanged diagnostics only for concrete privacy/interface risks; do not refactor them speculatively.

**Interfaces:** Preserve `loadRouterConfig(configPath)`, `configFingerprint(config)`, `createProxy(config, { diagnostics, upstreamAgent, inactivityTimeoutMs, credentialReader })` and `readKeychainCredential(reference, { signal })`. Loaded enabled configuration exposes:

```text
credentialRouting = {
  globalCredential: { keychainPath, service, account },
  routeTargets: { [alias]: { upstreamBaseUrl, credential: { keychainPath, service, account } } }
}
```

Use an internal `normalizeUpstreamBaseUrl(value)` in `src/config.js` for both global and target validation, preserving current global URL semantics. Deep-freeze targets/maps/references. Canonical enabled fingerprint data is global reference plus alias-sorted `[alias, normalizedUrl, referenceFieldsInFixedOrder]`; preserve the legacy canonical representation exactly.

Extend the private `setupProxy` test helper to optionally start a second local HTTPS upstream (`projectHandler`), retaining existing `calls` for global traffic and exposing separate `projectCalls`. Return `globalBaseUrl` (first listener plus `/api/v1`) and `projectBaseUrl` (second listener plus `/region/v1`, or the first base URL if no second listener). Its `credentialRouting` option accepts a configuration or a factory receiving `{ globalBaseUrl, projectBaseUrl }`. Change the local routing factory and its consumers to construct complete targets using those known URLs. Do not silently rewrite explicit target URLs in the helper. Reuse the committed public test-only certificate/CA and request helper; preserve existing string body capture and additionally capture raw `bodyBytes` buffers.

- [ ] Record amended specification approval (`approved`) and the separately obtained plan approval. Confirm the checkout/HEAD and only the expected artifact edits; commit the approved pair on the existing branch as `docs: approve explicit route target amendment`. Preserve any conflicting/unrelated work and stop rather than resetting. Do not repeat fetch/main/branch setup.
- [ ] Add `explicit target schema rejects obsolete and incomplete routing` and `target fingerprints preserve legacy compatibility and include normalized destinations` tests: exact required fields; reject old/both formats, invalid URL schemes/user info/query/fragment/relative URLs, malformed targets/references and unknown fields; retain reference bounds, historical fingerprint, empty/shared/unused targets and valid own aliases. Assert normalized URL/field/map reordering equivalence, deep freezing, and URL/reference changes affecting readiness. Migrate control-test fixtures to the new format, retaining fail-on-use reader/subprocess guards and offline/legacy-record recovery. With distinct local origins configured, assert startup/health/status/activation/rollback send no destination-preflight requests to either origin.
- [ ] Add `mapped route selects its exact credential destination and prefix` with one incoming `GLOBAL_CREDENTIAL_SENTINEL` and raw `bodyBytes` containing non-ASCII bytes. Pin the first A request with the assertions below. Add controller/global, catalog/title, compaction, ancestry, fork/follow-up, mapped title priority, shared target, missing alias and own `constructor`/`toString` variants. Assert no project reads for catalog/title and exact original authorization there. Retain the observation/title mode matrix and authentication-before-broken-state failures.

  ```js
  assert.equal(f.calls.length, 0);
  assert.equal(f.projectCalls.length, 1);
  assert.equal(f.projectCalls[0].url, "/region/v1/responses?x=a%2Fb&x=2");
  assert.equal(f.projectCalls[0].headers.host, new URL(f.projectBaseUrl).host);
  assert.equal(f.projectCalls[0].headers.authorization, "Bearer PROJECT_A_CREDENTIAL_SENTINEL");
  assert.deepEqual(f.projectCalls[0].bodyBytes, bodyBytes);
  ```
- [ ] Run `npm test`. Expected RED: new enabled configurations/target forwarding fail against the current key-only implementation; retain decisive failure output, not incidental fixture/import errors.
- [ ] Implement strict target loading/fingerprints and the proxy selection. After global verification and ordinary resolution, require `Object.hasOwn(routeTargets, alias)`, capture its destination, await its credential, and fix the pair before `started`. Build the URL from the full selected prefix plus admitted suffix/query; explicitly set authorization after hop filtering and Host from the selected URL. Keep cancellation checks, request-local secrets and all existing error text/codes. Missing aliases retain `CREDENTIAL_UNMAPPED`; malformed supplied targets fail configuration. Do not add a public selection API or touch the bounded reader without an evidenced defect.
- [ ] Migrate the README/example to explicit pairs and correct gateway-instance selection. Explain manual format migration, controller/global behavior, full prefixes, restart/readiness, no preflight/fallback, unchanged Keychain items and continuation limits. Preserve documented lookup limits, trust/privacy and exact recovery. Run `npm test`, `node --check src/cli.js`, `git diff --check`. Expected GREEN: all migrated tests and existing regressions pass, syntax/whitespace clean; retain exact commands/exits/proof lines.
- [ ] Self-review and commit only assigned changes as `feat: route project credentials to explicit API targets`. Complete the task review before Task 7. **Review range:** `04fe73d..TASK6_HEAD`, deliberately including unreviewed `8a61a30`/`639cbeb` automation, docs and truthful failed-run report alongside this task's amendment. Record the actual implementer BASE separately; fixes use that task's fix-round bases. Do not rereview completed Tasks 1–4 or interpret the earlier failed live report as AC-09 completion.

### Task 7: Verify destination snapshots and transport isolation [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,security]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-06, AC-07

**Risk:** Concurrent requests and reassignment must not combine credentials and destinations from different snapshots.

**Files:** Modify `test/proxy.test.js`; change `src/proxy.js` only for demonstrated in-scope lifecycle defects. Retain the existing reader tests and process seam; change them only if composition exposes a causal defect.

**Interfaces:** Consume Task 6's complete target shape and two-origin helper/factory. Add no public interface. Existing real synthetic-child cancellation tests remain mandatory regressions.

- [ ] Add barriers for overlapping A/B project streams and global controller/title streams, using distinct origins, fixed credential expectations and independently controlled completions. Require simultaneous active forwarding and no cross-origin/cross-request credential leakage under all four observation/title combinations; disabled titles still reject as before.
- [ ] Extend reassignment tests at both `selected project lookup` and `active stream`: explicitly configure A at the first origin with its project key and B at the second origin with its different project key. A's held request keeps that URL/key, while the next request goes to B. After both settle, assert first-origin authorization values equal exactly `["Bearer PROJECT_A_CREDENTIAL_SENTINEL"]` and second-origin values exactly `["Bearer PROJECT_B_CREDENTIAL_SENTINEL"]`; also assert each literal path/body and one call per origin. Keep fake rotation/deletion, stale-global rejection, shared global/project references and no-coalescing tests. Unchanged continuation IDs/body must be forwarded even when the simulated destination rejects them.
- [ ] Test selected-origin 401, a cross-origin 307 redirect, connection failure, TLS rejection and broken stream. Assert no request to a fallback/redirect origin and continued success for a separately healthy target. Retain streaming, backpressure, inactivity, malformed HTTP, hop headers and disconnect-during-global/project-lookup tests; require initiating `499/CANCELLED` and child reaping with zero post-cancellation forwarding. Sentinel checks exclude URLs/references/keys and gateway response fragments from router diagnostics while preserving opaque upstream HTTP content.
- [ ] Run `npm test`. Expected: newly added cases may expose defects; record any genuine RED before a fix, and do not claim or manufacture RED for already-correct behavior. Investigate unexpected failures through the integrated debugging workflow, retaining initiating outcomes and exact evidence.
- [ ] Apply only demonstrated causal fixes, then run `npm test`, `node --check src/cli.js`, `git diff --check`. Expected GREEN: lifecycle/transport cases and prior regressions pass with no surviving synthetic child/listener; no warnings or whitespace/syntax failures.
- [ ] Commit as `test: verify project destination lifecycle isolation`, including necessary fixes, and complete the task review before live validation.

### Task 8: Renew desktop validation and finish recovery evidence [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: security]

**Acceptance criteria:** AC-01, AC-02, AC-08, AC-09

**Risk:** Activation affects desktop availability. User-confirmed outcomes and exact recovery are required; unsupported gateway behavior remains visibly failed.

**Files:** Update `docs/validation/project-credential-routing.md` and, only where live evidence requires clarification, `README.md` and `examples/router.credentials.example.json`. No actual configuration, references, endpoints or runtime evidence enter Git.

**Ownership/interfaces:** The controller owns private checkpointing, instance/reference verification, separate-Terminal operation and recovery; the user owns provisioning and desktop interactions/restarts. Task 6 already provides operational documentation. After live evidence/recovery, dispatch a fresh full-role Task 8 implementer with a sanitized symbolic handoff to write/commit the final report; it must not read private runtime files. Its task review evaluates the report and changed docs. This completes the remaining original Task 5 obligations without repeating its implementation.

- [ ] Recheck direct operation and no listener, then create a new owner-only run/checkpoint outside Git. Capture exact prior provider/router bytes and optional-property presence. Reuse the already provisioned items without changing real key values. Privately construct explicit A/B project-instance targets and the controller's global target using the user-supplied complete API prefixes. Preserve the earlier failed run and recovery evidence separately. Obtain fresh user-confirmed direct A/B response/title baselines for this run.
- [ ] Before activation, run `npm test`, `node --check src/cli.js`, `git diff --check`; require exit 0 and retain exact evidence. Follow README's separate-Terminal `serve`, `status`, `activate` sequence with the explicit private config path. Verify matching readiness and URL-only provider edits; have the user restart and confirm controller operation. Keychain permission dialogs remain user-controlled; the bounded reader's timeout is unchanged.
- [ ] Have the user send fresh A/B requests with automatic titles and enough overlap to record simultaneous intervals, then test a same-chat follow-up and reassignment between A/B followed by another request. Capture symbolic route/source/transport results and user success/failure confirmations. Required synthetic coverage proves exact credential/URL selection; live evidence proves observed operation, not independent gateway billing attribution. Fork/saved-subagent/compaction live cases remain opportunistic and explicitly marked unrun if absent.
- [ ] If any gateway rejects keys, models or continuation state, retain the real failure classification; do not change keys, rewrite payloads, retry through another target or expand scope. Required missing/failed capabilities leave AC-09 incomplete. Proceed with recovery even when validation fails.
- [ ] Roll back through the existing CLI, restore exact prior owned settings/property omission while preserving unrelated edits, have the user restart and confirm a working direct response, then stop the positively identified validation proxy. Independently verify no listener and direct status with no recovery required. Keep checkpoints private. Do not stop the listener before direct-response confirmation.
- [ ] Give the fresh implementer only sanitized evidence and prior-report context. Retain the original failed-run history, distinguish the renewed run, classify every case, and record exact required checks/exits, lookup-excluding timestamp intervals, lookup-including `elapsedMs`, recovery and limitations. Update operational docs only as evidenced. Run `git diff --check` for documentation-only final edits; rerun required executable checks when code/tests changed. Commit as `docs: record project target validation and recovery` and complete Task 8 review. Close original Task 5 only when its automation/docs review and required live/recovery evidence are complete.

## 3. Traceability, final gate and handoff

| Criteria | Remaining task ownership / retained evidence |
|---|---|
| AC-01 | 6 schema/fingerprints/migration, 8 recovery; original Task 1 legacy evidence |
| AC-02 | 6 authentication/control regressions, 8 activation; original Tasks 2–3 |
| AC-03 | 6 exact origins/paths/keys, 7 overlap/reassignment; original ancestry/fork tests |
| AC-04 | 6 missing targets, 7 destination failure isolation; original bounded-reader cases |
| AC-05 | 6 global/title/controller selection, 7 mode/overlap matrix |
| AC-06 | 7 snapshots/rotation/cancellation; original reader cleanup tests |
| AC-07 | 6–7 isolation/privacy/transport; original sentinel tests |
| AC-08 | 6 docs/control review, 8 report and final gate |
| AC-09 | 8 user-assisted live outcomes and exact recovery |

After required task reviews and validation:

- [ ] Run `npm test`, `node --check src/cli.js`, `git diff --check` against the final reviewed code; retain exact commands, exits and decisive output. Do not count earlier runs as fresh final evidence.
- [ ] Invoke `personal-workflows:code-review` exactly once in integrated mode as the sole whole-branch seat; it has not run yet. Package the approved amended pair, complete changed-file list and diff from `cd58067` to the review HEAD, observed synthetic/sanitized live evidence, original-task dispositions, failed-run history and enclosing fix-loop policy in one immutable identity/hash-verified package. Specification review runs first; quality opens only after its verified PASS. Resolve managed review roles at execution; preserve the spec/quality ordering and full-role quality judgment.
- [ ] Handle findings under the selected subagent workflow's single final fix-wave/scoped-re-review policy. Do not add a duplicate generic final reviewer or independent review loop. A failed/missing required live capability stays incomplete and must not be reported as an overall PASS.
- [ ] Commit final evidence/dispositions on the existing local branch. Report working behavior, actual tests, live outcomes, recovery, limitations and pending integration. Stop; do not push, merge or start a later increment.

**Execution endpoint:** Complete the amended credential-routing increment, verification and review; restore exact prior settings and direct operation; confirm a direct response and stopped listener; report evidence and limitations; then stop before later work. Push and merge remain unauthorized.

**Self-review:** All nine stable acceptance IDs are covered. New configuration and proxy consumer change atomically, so no temporary format is needed. Task 6 explicitly reviews the previously unreviewed Task 5 commits; Task 8 owns its remaining live acceptance. Interfaces, own-property rules, URL prefix/Host behavior and review-focus cases agree with the approved specification. The existing execution choice and completed work are preserved. No material decision remains unresolved.

**Current stage:** Stage 4 — implementation authorized. The amended specification and revised plan were separately presented and approved by two distinct `approved` messages. Both approved revisions are saved before further product edits. Push and merge remain unauthorized.
