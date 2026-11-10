# Desktop project-identification validation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement`. Implement task by task using the selected Native execution method.

**Goal:** Validate automatic project identification in actual desktop requests while forwarding with the existing global credential.

**Architecture:** A loopback HTTP proxy resolves request identity against read-only desktop state, then streams admitted requests to the original HTTPS upstream. Explicit helper commands change and restore only the active provider’s base URL.

**Tech Stack:** Node.js 24, JavaScript ES modules, built-in HTTP/HTTPS, streams, SQLite and test libraries; `smol-toml@1.9.1` for configuration validation.

**Spec:** docs/superpowers/specs/2026-11-10-desktop-project-identification-validation.md

**Slug:** `desktop-project-identification-validation`  
**Status:** APPROVED  
**Created:** 2026-11-10  
**Updated:** 2026-11-10  
**Execution tier:** full  
**Implementation model role:** full  
**Execution method:** Native  
**Provenance:** Approved specification; interactive selections of Native execution and temporary desktop test projects. Plan explicitly approved by the user message beginning “PLEASE IMPLEMENT THIS PLAN”.

## Evidence and decisions

- Repository HEAD: `326319b66d9963bf95d7df2e2dd7cc339ff01ff2`. The checkout contains `LICENSE` and the uncommitted approved specification.
- Specification resolution: `NEW_ONLY`. Implementation-plan resolution: `MISSING` before saving this approved plan.
- No architecture map or ADRs exist; map freshness and ADR constraints are therefore inapplicable.
- Observed environment: Node `24.21.0`; desktop `26.1029.61003`, build `24614`; bundled engine `0.166.0-alpha.6`.
- The active provider has a simple provider table and base-URL assignment, command-backed Keychain authentication, HTTP Responses transport, and no selected profile or configuration server.
- The installed desktop bundle exposes the `/compact` action. Its live behavior remains unverified.
- No project test commands exist. Task 1 introduces the package scripts below; `node --test`, `node --check`, and `--use-system-ca` were verified against the installed runtime. These are proposed commands, not existing repository checks.

No material design decisions remain unresolved. Temporary project IDs are runtime configuration inputs obtained after those projects are created.

## Global constraints

- Support the current local macOS installation and Node.js 24.
- Bind exclusively to `127.0.0.1`; default port `8787`.
- Keep the existing authentication helper and forward each caller’s credential unchanged in memory.
- Use normal TLS verification and Node’s system CA support; provide no insecure TLS option.
- Read desktop assignments and SQLite relationships without modifying them.
- Block unresolved, conflicting, projectless, unsupported, or unmapped model requests.
- Never log prompts, responses, credentials, complete headers, raw metadata, or raw desktop state.
- Keep actual endpoints, mappings, backups, and raw validation evidence outside Git.
- Work in the existing checkout. Create no worktree; push and feature-branch integration remain unauthorized.
- Separate credentials, billing attribution, GUI, and automatic startup remain deferred.

## Review focus

1. Duplicate or inconsistent identifiers must never select an unrelated project.
2. Partial state writes, unavailable SQLite state, and project moves must not produce stale attribution.
3. Catalog exceptions, unusual request paths, and error handling must not bypass admission or expose payloads.
4. Concurrent requests, stalled streams, and client cancellation must preserve isolation and release resources.
5. Interrupted activation and configuration changes between activation and rollback must preserve unrelated settings.

## Implementation tasks

### Task 0: Preserve approved artifacts and prepare the branch [size: S | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-11  
**Risk:** Preserve local work while updating the base branch.

- [ ] After separate plan approval, leave Plan mode if necessary, save this plan, and record its approval. Confirm both saved artifacts and the messages approving them.
- [ ] Inspect tracked, staged, and untracked changes. Preserve the approved documents and any user changes before updating `main`.
- [ ] Fetch `origin` and update `main` by fast-forward only. If the update cannot preserve local work, stop with the concrete conflict; do not reset or force an update.
- [ ] Create `feat/desktop-project-identification-validation` in this checkout.
- [ ] Commit only the approved specification and plan with `docs: record approved project-identification increment`.

Expected result: the implementation branch contains the approved artifacts; user work remains preserved.

### Task 1: Define private configuration and resolve project identity [size: M | risk: data | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-01, AC-02, AC-04, AC-05, AC-06

**Files:** Package manifest/lockfile, `.gitignore`, `src/config.js`, `src/identity.js`, and `test/config-identity.test.js`.

**Interfaces:**

- `loadRouterConfig(configPath) → Promise<RouterConfig>`
- `identifyProject(rawHeaders, config, { signal }) → Promise<Resolution>`
- `Resolution`: `threadId`, `ownerThreadId`, `projectId`, `routeAlias`, and `source` (`direct` or `ancestor`).

Private JSON configuration contains `schemaVersion: 1`, `codexHome`, `providerId`, `upstreamBaseUrl`, `listenPort`, and `projectRoutes`. Require an HTTPS upstream without embedded credentials and explicit project-ID-to-alias entries. Default private location: `~/.codex-project-router/config.json`.

- [ ] Bootstrap the ESM package, pin the TOML dependency, and define `npm test` as `node --test test/*.test.js`. Add synthetic temporary-state fixtures and failing tests for direct assignments, ancestry, malformed/conflicting identifiers, cycles, missing aliases, projectless markers, and transient state availability.
- [ ] Run `node --test test/config-identity.test.js`. Expected: failures for the missing implementation.
- [ ] Implement configuration validation and identity resolution. Access only required JSON fields and query `parent_thread_id`/`child_thread_id` from `thread_spawn_edges` using read-only SQLite access. Do not filter ancestry by agent completion status.
- [ ] Re-read state per request. Use a one-second lookup deadline, 50 ms asynchronous retry interval, and maximum ancestry depth of 32. Reject unproven identity relationships; never use working directories as a fallback. Freeze each successful resolution for its request.
- [ ] Run the same test command. Expected: all cases pass, including assignment changes between requests and unchanged fixture state. Commit with `feat: resolve desktop project identity`.

### Task 2: Enforce request admission and private diagnostics [size: M | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-01, AC-06, AC-08

**Files:** `src/admission.js`, `src/diagnostics.js`, and `test/admission-diagnostics.test.js`.

**Interfaces:**

- `admitRequest(method, rawUrl, rawHeaders) → Admission`
- `emitDiagnostic(stream, event) → void`

- [ ] Write failing tests for the exact route allowlist, missing authentication, duplicate identity/authentication headers, absolute-form URLs, path traversal, unsupported methods, WebSocket upgrades, and sentinel-bearing errors.
- [ ] Run `node --test test/admission-diagnostics.test.js`. Expected: failures before implementation.
- [ ] Implement local `GET /healthz`, provider-wide `GET /v1/models`, and gated `POST /v1/responses` and `POST /v1/responses/compact`. Map these routes onto the configured upstream prefix. Preserve permitted query strings without allowing them to change the destination.
- [ ] Require existing bearer authentication for upstream requests. Only health and catalog requests may omit project identity. Return fixed error codes and sanitized messages; never reflect raw URLs, parser errors, headers, or metadata.
- [ ] Restrict diagnostics to timestamps, event names, correlation identifiers, required chat/project identifiers, route aliases, resolution source/outcome, status, timing, and fixed error codes. Test every error path with credential and payload sentinels.
- [ ] Run the same test command. Expected: all tests pass and forbidden sentinels are absent. Commit with `feat: enforce proxy admission and private diagnostics`.

### Task 3: Stream requests to the existing upstream [size: M | risk: concurrency | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: concurrency,auth,performance]

**Acceptance criteria:** AC-01, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08

**Files:** `src/proxy.js`, `test/proxy.test.js`, and clearly marked synthetic TLS fixtures.

**Interface:** `createProxy(config, { diagnostics, upstreamAgent }) → http.Server`. The optional agent supports trusted test certificates; production uses normal certificate verification.

- [ ] Write failing integration tests against a local HTTPS dummy upstream: overlapping projects, distinct per-request authentication sentinels, streamed chunks, compaction, catalog requests, upstream failures, redirects, slow consumers, disconnects, and admission failures with zero upstream calls.
- [ ] Run `node --test test/proxy.test.js`. Expected: failures before implementation.
- [ ] Integrate admission, resolution, and forwarding using built-in HTTP/HTTPS streams. Preserve body bytes, model names, response status, and content; remove hop-by-hop headers and set the upstream host correctly.
- [ ] Propagate backpressure and cancellation. Keep request-specific state separate, introduce no upstream retries, and follow no redirects. Use a five-minute upstream inactivity timeout with shorter injected test timing.
- [ ] Emit start/completion outcomes without recording content. Sanitize connection and protocol failures, including errors occurring after response headers have been sent.
- [ ] Run the same test command. Expected: all cases pass, requests remain isolated, and connections close after cancellation. Commit with `feat: stream resolved requests to the existing gateway`.

### Task 4: Add explicit activation, status, and rollback [size: M | risk: data | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: data,auth]

**Acceptance criteria:** AC-01, AC-08, AC-09, AC-10

**Files:** `src/activation.js`, `src/cli.js`, `test/activation.test.js`, and `test/cli.test.js`.

**Interfaces:**

- CLI: `serve`, `status`, `activate`, and `rollback`, each accepting an explicit `--config` path.
- `activate(configPath)`, `status(configPath)`, and `rollback(configPath)` return sanitized status objects.

- [ ] Write failing temporary-file tests for provider validation, readiness mismatch, missing proxy, preservation of authentication/comments/unrelated settings, repeated commands, competing helpers, interrupted activation, and edits made before rollback.
- [ ] Run `node --test test/activation.test.js test/cli.test.js`. Expected: failures before implementation.
- [ ] Implement foreground serving and sanitized CLI errors. Document `node --use-system-ca src/cli.js serve --config …` as the production startup command.
- [ ] Validate the active provider and original upstream before activation. Match proxy readiness to the selected configuration without exposing its contents.
- [ ] Parse TOML for validation, but replace only the supported provider’s single-line base-URL value. Validate that the parsed configuration differs only at that setting. Reject unsupported or ambiguous representations instead of rewriting the whole file.
- [ ] Create restrictive private state and exclusive backups. Use guarded temporary-file replacement and an activation record that supports recovery from interruption. Check the current file again before replacement.
- [ ] Roll back against the latest configuration, preserving unrelated edits. Reject an unexpected owned base URL. Never invoke Keychain or restart the desktop app.
- [ ] Run both test files. Expected: all cases pass, including recovery and sentinel checks. Commit with `feat: add reversible proxy activation`.

### Task 5: Document, validate the desktop path, and review [size: M | risk: other | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01 through AC-11  
**Risk:** Desktop compatibility and user-operated actions cannot be established by dummy-upstream tests.

**Deliverables:** README, synthetic configuration example, and sanitized validation report.

- [ ] Document setup, commands, configuration support, privacy guarantees, failure behavior, provider-wide effects, restart requirements, and manual recovery. State clearly that route aliases do not switch credentials.
- [ ] Run `npm ci`, `npm test`, and `git diff --check`. Expected: installation succeeds, all tests pass, and whitespace checks are clean. Check the CLI syntax with `node --check src/cli.js`.
- [ ] Have the user create two disposable local desktop projects with scratch folders. Configure explicit aliases for both and for this controller project so this chat remains usable during validation. Keep their actual IDs and all upstream details private.
- [ ] Establish a direct-connection baseline using minimal controlled prompts. Activate the proxy and have the user restart the app when required. Do not create or message other chats through coordination tools without explicit authorization.
- [ ] Exercise the live matrix below. Record sanitized request intervals to demonstrate overlap and distinguish each project’s requests. Actual prompts and responses remain outside router diagnostics.
- [ ] Attempt fixes within scope for failures and rerun affected checks. Do not replace failed identity validation with a guessed assignment or alternative routing feature.
- [ ] Restore the original direct connection, have the user perform any required restart, and verify a successful direct desktop request.
- [ ] Complete `personal-workflows:code-review`: specification review first, then quality review after specification findings are resolved. Fix actionable findings and rerun affected checks.
- [ ] Commit the final implementation, documentation, and sanitized report. Leave push and branch integration pending.

**Live validation matrix:**

| Scenario | Required observation |
|---|---|
| New chat in each test project | First request identifies the correct project and receives an ICA response |
| Concurrent requests | Request intervals overlap and identities remain distinct |
| Follow-up and resumed chat | Identification remains correct |
| Forked chat | Its assigned project resolves correctly |
| Project move | Subsequent requests use the new assignment; scratch-folder grants stay confined to disposable projects |
| `/compact` | The actual desktop compaction request is identified and forwarded correctly |
| Subagent | Saved ancestry supports correct attribution without independent credential selection |
| Rollback | Direct desktop-to-ICA operation succeeds again |

The report classifies every scenario as observed pass, observed failure, or not run. A conclusive incompatibility may complete validation after in-scope fixes and review; it must remain a failed capability and block credential routing. Missing user actions alone do not establish incompatibility.

## Traceability and handoff

| Acceptance criteria | Owning tasks |
|---|---|
| AC-01 | 1–5 |
| AC-02 | 1 |
| AC-03 | 3, 5 |
| AC-04–AC-05 | 1, 3, 5 |
| AC-06 | 1–3 |
| AC-07 | 3 |
| AC-08 | 2–4 |
| AC-09 | 4 |
| AC-10 | 4–5 |
| AC-11 | 0, 5 |

**Execution endpoint:** Deliver and review the proxy, finish desktop validation with evidence, restore the direct baseline, report results and limitations, and stop before per-project credential selection.

**Approval:** The user explicitly approved this plan for implementation with “PLEASE IMPLEMENT THIS PLAN”. Both the specification and plan are now saved. Implementation must remain within this increment.
