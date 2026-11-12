# Companion routing On/Off Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver acknowledged project-routing On/Off on the companion's existing owned listener, with global inheritance for identified projects and preserved direct recovery.

**Architecture:** An opt-in managed Node entry point owns an in-memory mode, initially Off, and a bounded private stdin/stdout command channel. The existing proxy captures mode at HTTP request receipt and separates identity proof from override selection. The native backend binds the channel to its retained child; the controller keeps mode, provider evidence and desktop confirmation separate and exposes a focused everyday interface.

**Tech Stack:** Node 24, existing built-in HTTP/HTTPS/SQLite facilities and smol-toml 1.9.1; Swift/SwiftUI/AppKit on macOS 14+, XCTest; existing arm64 ad-hoc-signed app packaging. No new dependency.

**Spec:** `docs/superpowers/specs/2026-11-12-companion-routing-on-off.md`

**Slug:** `companion-routing-on-off`

**Status:** APPROVED — implementation in progress

**Created:** 2026-11-12

**Updated:** 2026-11-12

**Provenance:** The selected saved specification, explicitly approved by the user's **specification approved** message after the separate **scope/design confirmed** message. Planning baseline HEAD `323536305723e767a8fdd2ac99ea26ca808d2175`. The user subsequently approved this plan and its execution method with **plan confirmed, subagent driven confirmed**. Historical predecessor plans inform conventions, not authorization for this increment.

**Execution tier:** full

**Implementation model role:** full

## Global Constraints

- "Capture On/Off once at receipt of each HTTP request, before its first asynchronous lookup."
- "Here **global pair** means top-level `upstreamBaseUrl` and the existing incoming authorization; when `credentialRouting` is present, that authorization must first match a fresh `globalCredential` read."
- "Off is an explicit request to suspend project overrides. It therefore performs no project-credential lookup, including for a saved override whose item is currently unavailable."
- "Strict loading still rejects supplied malformed/incomplete targets in either mode." The obsolete `routeCredentials` format remains rejected.
- "The historical standalone `serve` path remains usable with its existing behavior."
- "Introduce no HTTP mutation endpoint and pass no credentials through the control channel."
- "No last-used On setting is restored, no router starts automatically, and a failed/uncertain start cannot be presented as a confirmed Off listener."
- "A managed mode change alone must not alter the configuration fingerprint, provider URL, activation record or restart/response-confirmation obligation." This includes mode-only acknowledgement and reconciliation.
- "Off is not direct bypass or safe-stop evidence." Existing recovery and Stop/Quit authority remain decisive.
- "Actual credentials, references, endpoints, mappings, checkpoints and runtime evidence stay outside Git."
- "Do not retry or migrate an existing request to make a switch appear successful." No fallback, alternate account, redirects, payload/model/continuation repair or automatic mutation retry.
- "Use the existing checkout; no worktree." No push or merge. Do not begin another increment.

## Review Focus

1. A case-only or duplicate saved project identity must not look like an absent override and inherit global; Task 1 pins conservative rejection and truthful catalog presentation.
2. A mode switch while global authentication is pending must not reroute that already received request, even across repeated switches or a reused connection; Task 2 pins the request boundary.
3. Split/coalesced frames and a late reply after timeout must never satisfy a different command; Tasks 3/4 pin bounded framing and request/session correlation.
4. Losing a mode acknowledgement must preserve usable provider/catalog evidence, existing desktop confirmation and Restore direct access; Task 5 pins independent uncertainty domains.
5. Quit guidance targeting a control inside collapsed Advanced must reveal it from closed/minimized windows without executing it or replaying navigation on polling; Task 6 tests the projection/lifecycle and Task 8 supplies actual native observation.

---

## Resolution, repository evidence and decisions

Artifact resolution before this write: specification NEW_ONLY at the explicit Spec path; plan MISSING; exact legacy directories `specs/` and `plans/` absent; no conflicting slug/reference. The new plan reuses the specification's exact basename. Specification lifecycle metadata records approval; its substantive requirements are unchanged.

Local branch remains `main`, HEAD `323536305723e767a8fdd2ac99ea26ca808d2175`; the only initial local change was the untracked approved specification. Earlier inspection in this chat verified local main, origin/main and actual remote main matched, with only main locally/remotely. Planning has not fetched, updated main, created branches, committed, run tests/builds, started a listener or changed private settings. Recheck at execution; these observations are not lasting operational guarantees.

Architecture map `docs/architecture/map.md` and ADR locations `docs/decisions/` and `docs/adr/` were absent; no map/ADR-like documentation was found. Map freshness/HEAD are unavailable, and there is no discovered accepted ADR constraint. Do not generate a map while planning. Key paths checked at the inspected HEAD: proxy/admission/identity/configuration/diagnostics, standalone and companion bridges, native wire/backend/controller/view/Quit guidance, fixtures, package allowlists and verification scripts.

`createProxy` returns an HTTP server and selects destination/authorization request-locally. `identifyProject` currently requires an alias after membership proof. The catalog validates normalized project key/id consistency, but exact mapping lookup can portray a case-only saved mapping as unmapped. The managed path needs conservative consistency checks before inheritance; it does not need a global configuration reload or schema migration.

`ProcessBackend.launch` currently closes stdin and uses bounded one-shot captures; its long-lived serve output is drained/discarded. Keep one-shot provider-helper uncertainty handling intact. The new ongoing channel needs its own parser, deadlines and uncertainty. `RouterController.inspectNow` already serializes inspections and rejects stale generations; extend that gate rather than add another polling framework. Existing activation revision includes configuration/provider/recovery evidence; runtime mode must never enter that revision.

No unresolved material product decision remains. The native inheritance answer was **Use global now (Recommended)**. Protocol constants, interfaces and focused layout below are implementation decisions permitted by the approved spec. Managed identity checks may conservatively reject ambiguous case variants, but must not rewrite mappings, normalize them into a different assignment, or change standalone semantics. If the required same-chat live workflow fails, record failure, recover, and return to scope/design before material changes.

Command evidence: `package.json` defines `npm test`, `npm run companion:test`, `npm run companion:build` and `npm run companion:package-test`; the specification and `companion/README.md` document syntax/whitespace checks. Focused `swift test --package-path companion --filter <Class>` follows the existing native test target and predecessor plans. New Node tests use the existing `test/*.test.js` glob. Git commands follow global AGENTS.md. Historical 128 native/664 Node/three package results are context only; every new result must name its actual run.

## File responsibilities

| Files | Responsibility |
| --- | --- |
| `src/proxy.js`, `src/identity.js`, `src/diagnostics.js` | Opt-in request mode snapshot, proven membership/inheritance, selected-pair diagnostics |
| `src/companion.js` | Truthful catalog handling of ambiguous saved identity; public wire shape unchanged |
| New `src/managed-serve.js` | Managed startup, in-memory mode and bounded owned-pipe protocol; separate executable entry point |
| `test/proxy.test.js`, `test/config-identity.test.js`, `test/admission-diagnostics.test.js`, `test/companion.test.js`, new `test/managed-serve.test.js` | Synthetic selection, timing, identity, channel and compatibility proofs |
| `test/helpers/fixtures.js` | Small reusable synthetic project/thread additions when required; no real state |
| `companion/Sources/CompanionCore/WireTypes.swift`, new `RouterModeChannel.swift`, `ProcessBackend.swift` | Mode types, owned channel and backend integration |
| `companion/Sources/CompanionCore/RouterController.swift` | Serialized absolute mode actions and same-child reconciliation independent of provider recovery |
| `companion/Sources/CodexProjectRouter/ControlsView.swift` | Main routing/default/project presentation and secondary Advanced controls |
| Native core/app tests and `companion/Tests/CompanionCoreTests/Fixtures/node-fixture` | Actual fixture-process protocol, controller and presentation/Quit regressions |
| `scripts/build-companion.mjs`, `test/companion-package.test.js` | Add managed entry to explicit production allowlists; extend existing three package cases |
| `README.md`, `companion/README.md`, new `docs/validation/companion-routing-on-off.md` | Delivered workflow, integration/recovery limits and sanitized fresh acceptance |

No configuration schema, Keychain backend, activation editor, journal schema or public CLI/status change is planned. Preserve predecessor artifacts/reports. If a necessary material deviation emerges, follow the existing approval workflow before implementing it.

## Execution preflight — only after plan approval

- [ ] Identify the approved specification and this plan, quoting the two separate approval messages; preserve the chosen execution method. Load `personal-workflows:spec-implement` and its selected base exactly once. Use the current managed full role. Confirm artifact identity, HEAD, local changes and operational context without printing private values.
- [ ] Safely update main after approval: `git status --short --branch`, `git fetch origin`, `git switch main`, `git merge --ff-only origin/main`. Preserve the uncommitted artifact pair and any unrelated work. If an update cannot fast-forward or would overwrite work, preserve state and report the conflict; never reset, force or silently change the base. Reconcile a materially changed implementation baseline before proceeding.
- [ ] Verify `feat/companion-routing-on-off` is absent, then `git switch -c feat/companion-routing-on-off` in this checkout. Record the actual base commit. Mark the plan approved only from the user's actual approval. Commit just the approved pair with `git add docs/superpowers/specs/2026-11-12-companion-routing-on-off.md docs/superpowers/plans/2026-11-12-companion-routing-on-off.md` and `git commit -m "docs: approve companion routing on off"`. Create only the selected workflow's ignored evidence workspace/ledger. No worktree, push or merge.

### Task 1: Select managed destinations after identity proof [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-02, AC-03, AC-05, AC-09

**Files:** Modify `src/proxy.js`, `src/identity.js`, `src/diagnostics.js`, `src/companion.js`; test in `test/proxy.test.js`, `test/config-identity.test.js`, `test/admission-diagnostics.test.js`, `test/companion.test.js`. Extend `test/helpers/fixtures.js` only for shared synthetic state. Risk: accidentally treating an explicit assignment as inheritance could change account selection.

**Interfaces:** Extend `createProxy(config, options = {}) -> http.Server` with optional `options.getProjectRoutingMode: (() => "on" | "off")`; absence retains unmanaged behavior. Extend `identifyProject(rawHeaders, config, {signal, allowUnassignedTitle = false, requireRoute = true} = {}) -> Promise<Readonly<resolution>>`, where proven project resolutions retain `threadId`, `ownerThreadId`, `projectId`, `source` and optional `routeAlias`; special title resolutions keep their existing shape. Only managed requests pass `requireRoute: false`. No new wire fields in companion inspection. Diagnostics may add only fixed `routingMode: "on"|"off"` and `routeSelection: "global"|"override"`.

- [ ] **Step 1: Add selection and identity RED cases.** Extend `setupProxy` to pass the optional getter. Add `managed modes select exact paired origins and credentials`: with enabled routing assert Off mapped/unmapped requests reach only the global origin with `Bearer synthetic-global`, On mapped reaches only the project origin with `Bearer synthetic-project`, and On unmapped reaches global. Assert raw body bytes, URL prefixes/query and model/continuation bytes unchanged. Add `managed legacy preserves caller authorization without Keychain`: both modes use global/caller auth with a throwing credentialReader never called; absence of getter retains ROUTE_UNMAPPED for a proven unmapped project.
- [ ] **Step 2: Add denial/privacy RED cases.** Add `managed off suspends missing or unavailable explicit target`, `managed on explicit failure never inherits`, `managed identity ambiguity never inherits`, `new identified project inherits before browsing`, and `managed diagnostic selection cannot imply suspended override`. Cover missing target, denied project credential, shared global/project reference, synthetic 402/429/5xx, TLS/connection failure and 3xx without follow; assert no second-origin call/retry or mode mutation. Off still rejects incorrect incoming global auth and does not read a project credential. Test catalog and title-policy combinations with both optional flags, including valid title absence, conflicting/projectless identity and unassigned compaction denial. Existing strict config tests continue rejecting incomplete targets and `routeCredentials`.

For managed membership, require the selected catalog record's valid UUID `id` to agree with its key ignoring case; reject duplicate normalized identities for that project and normalized ancestor disagreement as IDENTITY_CONFLICT. A mapping key matching that project's normalized UUID but with different spelling, or duplicate normalized mapping keys, is an IDENTITY_CONFLICT rather than absence. Missing/unreadable state retains existing failures/retry bounds. Do not require project display names in request identity. Test inherited request success without any companion inspection. In companion catalog tests, case-only mapping/catalog mismatch or duplicate normalized mapping keys produces `catalog.state === "unavailable"` with empty entries; existing stale mappings remain visible. Standalone identity behavior stays unchanged.

```js
// Literal assertions in the corresponding named tests; credentials are synthetic.
assert.equal(f.calls[0].headers.authorization, "Bearer synthetic-global");
assert.equal(f.projectCalls[0].headers.authorization, "Bearer synthetic-project");
assert.deepEqual(f.projectCalls[0].bodyBytes, sentBodyBytes);
assert.equal(rejected.error.code, "IDENTITY_CONFLICT");
assert.equal(f.calls.length + f.projectCalls.length, 0); // denial fixture
```

- [ ] **Step 3: Run RED.** Run `npm test`. Expected: new selection/inheritance/consistency assertions fail against historical behavior; existing regressions retain their prior expectations. Record the actual first failures before product edits; a fixture mistake is not the intended RED.
- [ ] **Step 4: Implement the interfaces in the four production files.** Capture/validate the getter result synchronously inside the request's error boundary before the first await; an invalid supplied result fails closed with INTERNAL_ERROR. Keep health local. Resolve membership normally; skip only the mandatory-alias rule in managed mode. Use own-property checks for assignment absence, applying the conservative managed consistency policy above. Select an override only for managed On with an explicit alias (or historical unmanaged behavior); otherwise global. Credential-enabled auth always runs first; no project read in Off, no substitution in legacy. Diagnostics must omit a suspended `routeAlias` and describe the pair actually selected; allowlist the two fixed fields and reject arbitrary values. Keep catalog inspection read-only and all public schema values unchanged.
- [ ] **Step 5: Run GREEN.** Run `npm test`. Expected: all Node assertions pass, including existing auth/hop-header, identity/title, config, transport and companion contracts. Package cases may retain only their existing build-dependent skips at this intermediate stage; zero-skip acceptance belongs to Task 7. Diagnostic sentinel tests show no secret/reference/URL/body/raw exception leakage.
- [ ] **Step 6: Commit.** Stage only the Task 1 paths actually changed; `git commit -m "feat: select managed global and project routes"`. Apply the selected execution workflow's task gate before continuing.

### Task 2: Prove request-boundary switching and transport continuity [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-09

**Files:** Modify `test/proxy.test.js` and, only for reusable synthetic state, `test/helpers/fixtures.js`; minimal corrective changes in `src/proxy.js` or `src/identity.js` if a new behavioral RED requires them. Risk: asynchronous identity/authentication can otherwise observe a newer mode than the request received.

**Interfaces:** Consume Task 1 getter and identity contract. Extend the existing test `request(f, options)` helper with `options.agent: http.Agent` and return/capture the accepted socket identity for reused-connection assertions. Use existing credentialReader barriers and mutable temporary saved state; do not add a production identity-injection seam or clock framework.

- [ ] **Step 1: Write timing tests.** Add `received mode survives held global authentication`, `received mode survives identity retry and new project appearance`, `selected pair survives held project credential and repeated switches`, `active stream survives switches and cancellation`, and `reused connection captures each compact and background request`. Hold the global credential promise, switch Off→On before releasing it, and assert that received-Off request still uses global; inverse direction still uses the project. Force identity's existing retry via initially absent saved membership, then write supported state after a switch. Hold project-key retrieval across On→Off→On. In each case assert exact origin, authorization, request bytes, upstream call counts and captured diagnostic mode/selection.
- [ ] **Step 2: Exercise streaming and all request classes.** Keep a deterministic SSE stream open while later requests use new modes; assert each stream's byte sequence and original origin, then abort one and assert upstream cancellation plus exactly one completion. Use `new http.Agent({keepAlive: true, maxSockets: 1})`, sequential requests and accepted socket identity to prove connection reuse across changes. Include `/v1/responses/compact`, ordinary background/child-ancestry work, qualifying unassigned title, catalog and health. Preserve inactivity/backpressure/TLS and hop-header regressions. Assert a shared-reference request still performs the required fresh reads, never caches keys and never retries another destination on failure. All test resources/barriers/agents close deterministically.

```js
// received mode survives held global authentication: received Off, release after On.
assert.equal(f.calls.length, 1);
assert.equal(f.projectCalls.length, 0);
assert.equal(f.calls[0].headers.authorization, "Bearer synthetic-global");
// reused connection captures each compact and background request: after a valid switch.
assert.equal(firstSocket, secondSocket);
assert.deepEqual(f.projectCalls[0].bodyBytes, compactBodyBytes);
```

- [ ] **Step 3: Run the timing verification before edits.** Run `npm test`. Expected: either all new boundary assertions pass from Task 1's correctly placed snapshot, or a concrete timing assertion exposes a RED to fix. Do not manufacture a failure for test-only work; record which occurred. A new origin/body/cancellation mismatch must fail before any corrective product edit.
- [ ] **Step 4: Correct only a demonstrated boundary defect, then run GREEN.** Retain one synchronous mode snapshot and one request-local selected pair; do not recapture on retries, connection reuse or stream callbacks. Run `npm test`. Expected: all timing and existing transport tests pass, with no abandoned barrier/process, duplicate completion or second-origin call. No external traffic.
- [ ] **Step 5: Commit.** Stage only Task 2 changes; `git commit -m "test: verify routing mode request boundaries"` (use `fix:` if corrective product code was necessary). Continue under the selected task gate.

### Task 3: Add the managed Node process protocol [size: M | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-06, AC-09

**Files:** Create `src/managed-serve.js` and `test/managed-serve.test.js`; retain `src/cli.js`, config schema, activation and existing CLI/status outputs unchanged. Risk: an unbounded or unauthenticated process channel could accept commands outside the owned session or stop forwarding on control loss.

**Interfaces:** Export `startManagedRouter({configPath, sessionId, input = process.stdin, output = process.stdout, diagnostics = process.stderr}) -> Promise<{server: http.Server, closeControl: () => void}>`. Executed directly, accept only `--config <canonical-absolute-path> --session <UUID>` on Node 24. Load config once, establish `let mode = "off"` before `listen`, and supply Task 1's getter. Reuse existing loopback binding and SIGINT/SIGTERM close semantics. A module import must not launch a server.

Wire protocol is newline-delimited UTF-8 JSON, schemaVersion 1, with no unknown fields. `sessionId`/`requestId` are UUID strings, modes are exactly `"on"`/`"off"`. Ready context is the actual canonical loaded `{configPath,codexHome,providerId,listenPort}`; it contains no credentials/endpoints. No configuration fingerprint is added to channel output.

```json
{"schemaVersion":1,"type":"ready","sessionId":"<uuid>","context":{"configPath":"<private path>","codexHome":"<private path>","providerId":"<provider>","listenPort":8787},"mode":"off"}
{"schemaVersion":1,"sessionId":"<uuid>","requestId":"<uuid>","action":"get_mode"}
{"schemaVersion":1,"sessionId":"<uuid>","requestId":"<uuid>","action":"set_mode","mode":"on"}
{"schemaVersion":1,"type":"mode","sessionId":"<uuid>","requestId":"<uuid>","mode":"on"}
```

Ready is emitted after successful listen; reject control until ready. Set mode synchronously before writing its reply, preserving pipe order. Each valid set is absolute/idempotent; no automatic re-execution or remembered On state.

- [ ] **Step 1: Write managed startup/channel RED cases.** Add tests `managed start is off before first request`, `absolute commands acknowledge applied mode`, `split and coalesced commands preserve order`, `invalid session fields encoding and oversized frames disable control`, `blocked output is bounded`, `control eof preserves last mode and listener`, and `managed startup performs no credential or upstream lookup`. Use synthetic config/local sockets and injectable PassThrough input/output for deterministic framing; process-boundary tests execute the real entry with real pipes. Initial malformed config/listen failure emits no ready. Existing CLI tests assert their original command/status/serve shape remains unchanged.

```js
// absolute commands acknowledge applied mode: decoded reply for a supplied set request.
assert.deepEqual(reply, {schemaVersion: 1, type: "mode", sessionId, requestId, mode: "on"});
// managed start is off before first request: ready is separate from model connectivity.
assert.equal(ready.type, "ready");
assert.equal(ready.mode, "off");
assert.equal(upstreamCalls.length, 0);
// blocked output is bounded; test records stream/parser retained byte counts.
assert.ok(maxRetainedInputBytes <= 32768);
assert.ok(maxRetainedOutputBytes <= 32768);
```

- [ ] **Step 2: Run RED.** Run `npm test`. Expected: missing managed module/entry first; after adding only the test harness, startup/framing expectations fail before implementation. Preserve other suite expectations.
- [ ] **Step 3: Implement bounded protocol in `managed-serve.js`.** Limit a frame to 16 KiB including newline and retained unparsed input to 32 KiB; reject invalid UTF-8, malformed JSON, wrong sessions/actions/types/keys or overflow. Process one frame/reply at a time; pause input/parse on output backpressure, resume on drain, and bound retained output to 32 KiB. Read bounded chunks; do not use an unbounded readline queue or accumulate all commands. On invalid/flooded input, EOF, write error or explicit closeControl, permanently disable control and drain/discard remaining input without resetting mode, closing HTTP, exiting or leaking raw payloads. Observe stream errors, including EPIPE. Diagnostics stay on stderr; stdout contains protocol only. Startup errors use existing fixed safe error mapping with no raw exception. No key lookup, auth-helper execution or destination probe is performed.
- [ ] **Step 4: Run GREEN.** Run `npm test` and `node --check src/cli.js`. Expected: full Node suite passes (same intermediate package qualification as Task 1), standalone syntax exit 0. Tests assert exact Off→On→Off replies, response under surviving last mode after control EOF, zero upstream at startup/commands/health, bounded overflow/backpressure behavior and absence of sentinel payloads in exposed errors.
- [ ] **Step 5: Commit.** `git add src/managed-serve.js test/managed-serve.test.js`; `git commit -m "feat: add owned managed router mode protocol"`. Continue under the selected task gate.

### Task 4: Bind a bounded native channel to the retained child [size: L | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-06, AC-08, AC-09

**Files:** Modify `companion/Sources/CompanionCore/WireTypes.swift` and `ProcessBackend.swift`; create `companion/Sources/CompanionCore/RouterModeChannel.swift` and `companion/Tests/CompanionCoreTests/RouterModeChannelTests.swift`; modify `ProcessBackendTests.swift` and `Fixtures/node-fixture`. Update all test protocol conformers in `RouterControllerTests.swift`, `QuitGuidanceTests.swift`, `QuitAlertTests.swift` and `ControlsPresentationTests.swift` with explicit mode stubs. Risk: authority must remain attached to the exact live Process, even after startup uncertainty or stale replies.

**Interfaces:** Add `public enum ProjectRoutingMode: String, Codable { case on, off }`. Add backend methods `readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode` and `setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode`. Add fixed `CompanionError.routingModeUncertain` ("The routing mode is uncertain. Refresh before switching again.") and `.routingModeUnavailable` ("Routing control is unavailable. Keep the router running and use direct recovery if needed."). Keep provider `mutationRequiresReconciliation` semantics unchanged.

Internal `RouterModeChannel` owns stdin writer/stdout reader for one session/context: `init(input: FileHandle, output: FileHandle, sessionID: UUID, context: ActivationContext)`, `waitUntilReady() async throws -> ProjectRoutingMode`, `readMode() async throws -> ProjectRoutingMode`, `setMode(_ mode: ProjectRoutingMode) async throws -> ProjectRoutingMode`, and `close()`. Here input is the child's stdin write end and output its stdout read end. Only ProcessBackend constructs/retains channels, indexed by `OwnedRouter.id`; that same UUID supplies `--session`. The channel accepts Ready only for its expected session/context and Off; historical readiness never grants this capability.

- [ ] **Step 1: Add native channel/backend RED cases.** Add `testManagedReadyBindsExactChildAndContext`, `testLateReplyCannotCompleteReadReconciliation`, `testMalformedFloodedAndSplitFramesAreBounded`, `testTimeoutRetainsChildAndDoesNotRetryMutation`, `testControlLossDoesNotSignalOrResetChild`, `testUnsupportedReadyNeverGrantsModeAuthority`, and `testChildExitClosesChannelAndReplacementCannotReuseIt`. Extend the fixture to recognize `managed-serve.js` arguments and exchange the actual wire frames. Retain existing provider-helper stall/overflow, runtime/env, ownership and port-reuse cases. Existing long-output fixture stdout becomes protocol-malformed evidence, with the listener still owned; stderr floods remain independently drained. No test-only production switch.

```swift
// testManagedReadyBindsExactChildAndContext
let initialMode = try await backend.readRoutingMode(child)
XCTAssertEqual(initialMode, .off)
let appliedMode = try await backend.setRoutingMode(.on, for: child)
XCTAssertEqual(appliedMode, .on)
// testTimeoutRetainsChildAndDoesNotRetryMutation, after catching routingModeUncertain
XCTAssertTrue(child.process.isRunning)
XCTAssertFalse(backend.mutationRequiresReconciliation) // provider-helper domain untouched
XCTAssertEqual(recordedSetCommandCount, 1)
```

- [ ] **Step 2: Run RED.** Run `swift test --package-path companion --filter RouterModeChannelTests` and `swift test --package-path companion --filter ProcessBackendTests`. Expected: missing mode/channel APIs first, then intended handshake/deadline/correlation failures before production implementation.
- [ ] **Step 3: Implement channel framing/correlation.** Use the Task 3 16 KiB frame/32 KiB retained-input bounds. Validate exact envelope fields/enums/context and UTF-8; use one pending request with a new request UUID, a five-second absolute deadline shared by write/ack, and strict request/session correlation. Timeouts/cancellation retire the old request ID; a structurally valid late reply for a retired ID is discarded and can never satisfy a later read. Wrong session/context, malformed/oversized output or EOF makes the channel unavailable. Set timeout or partial/failed delivery is uncertain; prohibit another set until a later same-channel get succeeds. No mutation retry. Read reconciliation is ordered after earlier command bytes. A permanent parser/pipe failure cannot be reconciled by a health probe or new channel to another process.

Do pipe reads/writes off MainActor on a private serial queue, with nonblocking bounded reads/writes and deadline/cancellation completion; never block MainActor in FileHandle.write. Keep at most one bounded outgoing frame and one pending continuation; drain/discard unusable stdout and continuously drain stderr with bounded retention. If a frame was only partially written when delivery fails, make the channel unavailable rather than append a fresh query to that fragment; a fully delivered command with a lost reply permits ordered read reconciliation. Exposed errors are fixed strings only. `close()` releases pipe resources/completes waiters without signalling the child or changing mode. Tests assert retained bounds and command counts as well as visible error type.

- [ ] **Step 4: Integrate managed launch without changing one-shot launch.** Keep existing `launch`/`RunningCommand` path for version/inspect/activate/rollback. Add a dedicated long-lived managed launch using the same environment allowlist and stderr draining, persistent stdin, mode stdout reader and retained Process. `start(configPath:)` invokes managed-serve, registers ownership before awaiting readiness/handshake, and returns any still-live child even after deadline/handshake failure. A failed handshake must never manufacture known Off; preserve ownership for recovery. Keep matching configuration/listener readiness as separate evidence. Backend read/set must check tracked object identity, Process identity, live state, expected session and context; no PID/port adoption. Child exit closes channel and fires the existing exit callback once. Stop continues signalling only the retained child and independently probing the port; no new automatic signal on channel failure.
- [ ] **Step 5: Run GREEN.** Repeat the two focused commands, then `npm run companion:test`. Expected: all native tests pass, including all four conformers, existing helper uncertainty and actual fixture-process ownership/cleanup. Assert a second set is blocked after uncertainty, a fresh same-child read restores authority, stale replies cannot publish mode, command/start/read has no credential/auth-helper/preflight invocation, and external listeners are never signalled. Tests keep exact synthetic process cleanup.
- [ ] **Step 6: Commit.** Stage only Task 4 paths; `git commit -m "feat: control routing through the owned process channel"`. Continue under the selected task gate.

### Task 5: Integrate truthful controller mode and reconciliation [size: L | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-01, AC-06, AC-08, AC-09

**Files:** Modify `companion/Sources/CompanionCore/RouterController.swift` and `companion/Tests/CompanionCoreTests/RouterControllerTests.swift`; evolve the Task 4 ControlledBackend mode stubs into held-command fixtures. Risk: queued inspections or acknowledgements can otherwise overwrite newer mode/context evidence or weaken existing recovery authority.

**Interfaces:** Add nested public `ProjectRoutingStatus: Equatable { case known(ProjectRoutingMode), uncertain, unavailable, notRunning }`, read-only `projectRoutingStatus` (initial `.notRunning`), separate read-only `routingModeError: String?`, computed `canSetProjectRouting: Bool`, and `setProjectRouting(_ mode: ProjectRoutingMode) async`. Consume the Task 4 backend methods; do not add mode to Inspection/revision/journal or provider mutation state.

- [ ] **Step 1: Write controller RED cases.** Add `testStartPublishesOffOnlyAfterOwnedModeEvidence`, `testModeAckPreservesProviderJournalAndConfirmation`, `testLostModeAckPreservesRestoreAndCatalog`, `testModeReconciliationCannotPublishStaleChildOrGeneration`, `testOverlappingModeAndRecoveryActionsAreSerialized`, and `testOffDoesNotAuthorizeStopOrQuit`. Use existing real PrivateStore/temp config and barrier conventions. Capture byte-exact journal/provider/config files and desktop confirmation before/after mode-only action and reconciliation. Assert no activate/rollback/stop on mode action; an uncertain set increments mutation count once, publishes no requested mode, disables another set, and permits explicit Restore direct after busy clears. Query failure must not call generic inspectionFailed or erase usable disk/catalog evidence.

```swift
// testModeAckPreservesProviderJournalAndConfirmation, initially confirmed routed
XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
XCTAssertFalse(controller.canStop)
XCTAssertFalse(controller.canQuit)
// testLostModeAckPreservesRestoreAndCatalog, after the action returns uncertain
XCTAssertEqual(controller.projectRoutingStatus, .uncertain)
XCTAssertFalse(controller.canSetProjectRouting)
XCTAssertTrue(controller.canRestoreDirect)
XCTAssertEqual(controller.inspection?.catalog.state, "ready")
```

- [ ] **Step 2: Run RED.** Run `swift test --package-path companion --filter RouterControllerTests`. Expected: missing public properties/action, then intended state/action assertions fail before implementation. Keep existing direct-only start, durable idle-direct Quit, imported recovery, changed-context and uncertain-helper tests intact.
- [ ] **Step 3: Implement mode action and isolated refresh.** Use existing begin/finish busy and inspection serialization/generation rules; no new timer or generic reload. Require usable context, live exact owned child, matching current configuration/readiness, no provider-helper uncertainty, known mode and available channel before set. Send an absolute value once; publish only a matching current child/generation acknowledgement. Preserve desktop confirmation and journal on mode success/failure. After uncertain outcome show `.uncertain`; terminal channel failure shows `.unavailable`, both with fixed routingModeError and blocked set. Never optimistically choose Off or old mode.

After a successful disk inspection, query mode for that same owned child/context within the existing serialized inspection slot; apply the result only if generation, sequence and child still match. A fresh query can reconcile uncertainty; failure affects only mode evidence. Do not let a queued pre-switch inspection replace its acknowledgement, and do not issue mode queries while incompatible actions hold the gate. Publish `.notRunning` with no owned or observed listener, `.unavailable` for external/unsupported listener or lost channel, and drop old mode on owned child exit/context replacement. Existing provider evidence failures remain conservative. Mode alone never clears/recreates response-confirmation obligations, authorizes Stop/Quit, persists a mode, restarts/adopts a process or blocks otherwise valid restoration after busy ends.
- [ ] **Step 4: Run GREEN.** Repeat the focused controller command, then `npm run companion:test`. Expected: all native tests pass, preserving existing Quit/controller/guidance tests. The held mutation, queued timer, child-exit/replacement, context-change, mode-read timeout, standalone/external listener and recovery-only cases prove distinct evidence domains. Off is never substituted for direct mode.
- [ ] **Step 5: Commit.** Stage only Task 5 paths; `git commit -m "feat: expose acknowledged routing state in companion"`. Continue under the selected task gate.

### Task 6: Present everyday routing and retain targeted recovery navigation [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-03, AC-07, AC-08, AC-10

**Files:** Modify `companion/Sources/CodexProjectRouter/ControlsView.swift`, `companion/Tests/CompanionAppTests/ControlsPresentationTests.swift`, `QuitGuidanceTests.swift`, `QuitAlertTests.swift`; modify `companion/Sources/CodexProjectRouter/QuitGuidance.swift` or `RouterApp.swift` only if the new disclosure/layout needs navigation integration. Risk: moving recovery controls can make the existing guarded Quit path unreachable even when permission logic remains correct.

**Interfaces:** Extend existing `ControlsPresentation` with `routingState: String`, `routingActionTitle: String?`, `globalAccount: String`, and `assignment(for project: Inspection.Entry) -> String`. Consume Task 5 `projectRoutingStatus`, `routingModeError`, `canSetProjectRouting`, and absolute action. Keep `QuitGuidance.Destination` identities, navigation tokens and controller permissions unchanged.

- [ ] **Step 1: Write presentation/navigation RED cases.** Add `testRoutingPresentationDistinguishesKnownPendingAndUnavailable`, `testAssignmentPresentationKeepsSuspendedAndMissingOverrides`, `testLegacyAliasesAreNotAccountNames`, `testAdvancedRevealsCurrentQuitTarget`, and `testModeOnlyRefreshDoesNotReplayQuitNavigation`. Test known On/Off, busy switching, no router, external/unsupported/uncertain mode, credential/legacy configurations, target_missing/catalog_missing/unavailable catalog and a newly discovered unmapped row. Assert no invented account name, stale fresh-list claim or confirmed desktop connectivity from mode alone. Retain the full existing alert/guidance/cancel/reentrant/closed-window lifecycle tests.

```swift
// testAssignmentPresentationKeepsSuspendedAndMissingOverrides: credential config, Off
XCTAssertEqual(display.assignment(for: savedOverride), "Override saved; inactive while Off — alias: route-a")
// testRoutingPresentationDistinguishesKnownPendingAndUnavailable: uncertainty
XCTAssertNil(display.routingActionTitle)
XCTAssertEqual(display.globalAccount, "Existing global provider account")
// testModeOnlyRefreshDoesNotReplayQuitNavigation
XCTAssertEqual(navigation.requestID, originalRequestID)
XCTAssertEqual(controlActionCount, 0)
```

- [ ] **Step 2: Run RED.** Run `swift test --package-path companion --filter ControlsPresentationTests` and `swift test --package-path companion --filter QuitGuidanceTests`. Expected: missing new projection members and changed literal presentation assertions fail before UI edits. Update only assertions intentionally changed by the focused layout/copy; preserve safety/navigation effects checks.
- [ ] **Step 3: Implement the focused view.** Lead with "Project routing", state, and explicit "Turn project routing On"/"Turn project routing Off" action; show pending switch visibly and disable conflicting controls through existing authority. With no child, lead with "Start router (routing Off)" when allowed. Show "Existing global provider account" and, for legacy, "Uses the caller's existing credential; aliases do not select separate accounts." Put searchable Projects next; retain automatic 2/5-second refresh and manual Refresh, independent of Controls visibility.

Rows say "Global (inherited)" for unassigned identified projects while On; "Global (routing Off)" without an override while Off; "Override active — alias: …" for credential overrides while On; "Override saved; inactive while Off — alias: …" for suspended overrides. In legacy say "Global credential; saved alias: …" rather than implying separate accounts. Unknown mode labels assignment as saved/inheritance policy rather than active. Missing target/stale mapping warnings remain visible even Off. No account/default/assignment editor or disclosure of secret references/endpoints.

Move configuration/runtime paths, ownership and independent technical facts into one "Advanced" disclosure in this window. Setup is expanded when required; relevant errors, direct restoration, pending response checks and manual-recovery affordances remain visible/prominent when needed. Preserve separate provider/readiness/ownership/confirmation facts and existing Start/Activate/Restore/Stop controls. Update activation copy to explain identified unassigned inheritance while unresolved identity may block, manual initial restart and the listener's continuing necessity when Off.

Keep all six guidance target IDs. A fresh explicit Quit-guidance request expands Advanced/setup/recovery as required before the existing delayed scroll/focus; evidence changes may reveal the current relevant panel but must not execute controls, scroll repeatedly or move focus on ordinary polls. Keep cancellation, window-close token invalidation, minimized/closed reveal and reentrant guard. Add no duplicate wizard. Actual SwiftUI visibility/accessibility is Task 8 evidence, not inferred from unit projections.
- [ ] **Step 4: Run GREEN.** Repeat the two focused commands, then `swift test --package-path companion --filter QuitAlertTests` and `npm run companion:test`. Expected: all native tests pass, with no new provider/control effects from presentation/guidance reads. Confirm search/discovery never edits assignments and unavailable catalog never displays a cached list as current.
- [ ] **Step 5: Commit.** Stage Task 6 paths actually changed; `git commit -m "feat: lead companion controls with routing mode"`. Continue under the selected task gate.

### Task 7: Package and document the integrated managed capability [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-07, AC-08, AC-09, AC-10

**Files:** Modify `scripts/build-companion.mjs`, `test/companion-package.test.js`, `README.md`, `companion/README.md`; create `docs/validation/companion-routing-on-off.md`. Risk: an omitted managed resource could pass checkout tests but break the relocated app or accidentally expand bundle contents.

**Interfaces:** Consume `src/managed-serve.js`, Task 3 wire protocol and Task 4 managed arguments. Add only `managed-serve.js` to both explicit production source allowlists. Extend the existing three package tests rather than add a fourth. No product schema/API change.

- [ ] **Step 1: Add package RED assertions.** Extend assembly allowlist fixtures and relocated/source-denied lifecycle cases to require managed-serve, persistent stdin, Ready Off, get/set On/get/set Off, unchanged listener identity/provider/config bytes and no control-time upstream. Keep a standalone serve compatibility check. Preserve signing/arm64, dependency pinning, no checkout/runtime path embedding, HOME/CFFIXED_USER_HOME confinement, sentinel exclusion, source-denial negative control and positively attributed native instance lock. Tests must drain outputs, retain exact processes and clean/check synthetic ports even on failure.
- [ ] **Step 2: Run RED before allowlist edits.** Run `npm test`. Expected: assembly omission/new managed-resource assertions fail; relocated app cases may reflect the previous build until rebuilt. Do not count stale-build failures/skips as acceptance.
- [ ] **Step 3: Update allowlists and usage documentation.** Include the managed entry while keeping all private/runtime/test files excluded. Explain explicit Start→Off, one-time stable URL integration and restart/response check, everyday On/Off without restart, existing-global inheritance, legacy limitations, saved overrides retained Off, uncertainty/read reconciliation, and independent desktop confirmation. Explain Off still needs listener, Restore direct's separate restart/confirmation/owned-stop sequence, custom activation contexts, external listeners, no automatic fallback/restart/startup and the deferred account/assignment UI. Preserve historical report limitations; add a new report skeleton with unrun native/live/review items explicitly pending.
- [ ] **Step 4: Run fresh automated acceptance.** Run `npm run companion:test`, `npm run companion:build`, `npm test`, `npm run companion:package-test`, `node --check src/cli.js`, and `git diff --check`. Build before the final Node/package runs so their package cases use this artifact. Expected: all native/Node tests pass, signed current app builds, exactly three package tests pass with zero skips, syntax/whitespace exit 0. Inspect full output; record actual counts/exits and meaningful RED/GREEN evidence, not historical numbers. Repeat affected checks only after changes/failures/unresolved concern.
- [ ] **Step 5: Commit.** Stage only Task 7 files; `git commit -m "feat: package and document managed routing controls"`. Leave required native/live items pending until Task 8; continue under the selected task gate.

### Task 8: Observe the workflow, recover and finish final review [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-03, AC-07, AC-08, AC-10, AC-11, AC-12

**Files:** Complete `docs/validation/companion-routing-on-off.md`; update only lifecycle/checklists in the approved pair after actual completion. Any fix returns through the enclosing execution workflow and affected checks; material spec/plan change needs renewed approval. Risk: local synthetic success cannot establish native usability, live continuation compatibility or correct operational recovery.

**Interfaces:** Consume the current signed app, all completed tasks and the selected workflow's final evidence/review contract. Parent owns human-assisted acceptance and recovery; delegate completion never substitutes for these observations. No new product API.

- [ ] **Step 1: Observe the isolated native presentation.** Reuse the existing package/predecessor native harness pattern with relocated signed resources, synthetic private HOME/CFFIXED_USER_HOME, source/real-private-path and non-loopback outbound denial, negative source-read control and attributed native instance lock. Observe main state/action/global/projects, Advanced setup, unavailable/uncertain/errors/recovery, search/automatic/manual discovery and keyboard/accessibility reachability. Exercise Quit primary guidance from open/scrolled, closed and minimized windows, including a target inside collapsed Advanced. Verify repeated explicit guidance navigates, ordinary polling does not steal scroll/focus, cancellation leaves operations alone, and closing/reopening clears transient guidance. Use available supported GUI interaction or explicit human observations; unit tests are not GUI proof. Clean only tracked fixture processes/files and independently check port absence.
- [ ] **Step 2: Establish controlled live prerequisites privately.** Reinspect current provider/router/recovery state and the activation context actually selected. Privately checkpoint exact prior owned settings, optional-property presence and recovery records; preserve unrelated concurrent changes. Use existing compatible provisioned credential routing with one global and one explicit override, disposable identified projects/chats and a positively tracked companion-owned listener. If prior state cannot be recovered safely, do not activate; record the blocking prerequisite. Avoid retrieving/printing credentials, references, endpoints, mappings or private raw state. Keep user/controller recovery access throughout. The user performs Codex prompts/project creation/restarts; no automatic prompting or UI restart.
- [ ] **Step 3: Run the required live sequence.** Explicitly Start before Codex, confirm managed Off and initial global operation. Integrate through the existing URL-only activation/restart/working-response path only if needed. Record that initial obligation separately. On the same listener/provider URL, observe Off→On→Off with no Codex restart or configuration edit during switches; use an existing configured override and continue at least one same chat across the sequence. While On with Controls closed, have the user create a new project without override and send an identified request; record global inheritance before UI discovery, then observe automatic discovery/manual Refresh. Keep symbolic mode/selection/transport evidence separate from explicit user reports. Synthetic Task 2, not live stress, proves in-flight timing/exact credentials.

If a gateway rejects continuation, preserve the error and actual transport result, do not repair/retry/fallback, classify AC-11 failed/incomplete and continue recovery. Fresh-chat success cannot replace same-chat evidence. Do not proceed into another increment or material compatibility work under this plan.
- [ ] **Step 4: Complete and independently verify recovery, including after failure.** Use the activation records beside the selected configuration to Restore direct and restore exact prior owned router/provider settings and optional-property presence, preserving unrelated concurrent edits. Have the user perform the required restart and confirm a working direct response before stopping the possibly required owned listener. Stop only the positively tracked retained child, then independently verify listener absence and final direct/recovery state. Keep raw checkpoints/evidence outside Git. Qualify whole-file equality if unrelated edits remain. An interrupted/unconfirmed recovery is incomplete and must remain visible; never force overwrite/delete evidence/adopt an external listener.
- [ ] **Step 5: Consolidate evidence and commit.** Record actual commands/exits, native/user observations, mode sequence/listener continuity, origin-selection classifications, new-project discovery, transport results, historical qualifications, failures/unrun items and exact recovery disposition in the new sanitized report. Never claim independent gateway billing attribution, complete delivery from previously qualified cancelled streams, or proven continuation beyond the specific observed run. `git add docs/validation/companion-routing-on-off.md`; `git commit -m "docs: record routing on off acceptance"`. Complete the selected method's remaining task gate.
- [ ] **Step 6: Perform the sole final sequential review.** Use `personal-workflows:code-review` in integrated mode against the recorded implementation base..HEAD, with approved pair, immutable diff/evidence identity and task dispositions. Specification review must pass before quality review. Follow the selected implementation workflow's fix-loop policy and rerun affected checks; no duplicate generic final review. Record actionable dispositions and limitations in the report. Missing required live/native evidence remains incomplete even if code review passes.
- [ ] **Step 7: Close out and stop.** Mark lifecycle/checklists complete only when required evidence/reviews actually pass; otherwise preserve failed/pending status. Commit documentation-only closeout as needed, run `git diff --check` and `git status --short --branch`, and report the actual local branch/commits, working result, validation and limitations. Clean only owned scratch resources under the selected workflow. Stop before any later specification/plan, push, merge or main update beyond the approved execution preflight.

## Criterion traceability

| Criterion | Tasks and decisive evidence |
| --- | --- |
| AC-01 | 3 initial-Off/listener tests; 4 owned handshake; 5 acknowledgement separation; 7 standalone/relocated package; 8 live stable URL/listener |
| AC-02 | 1 paired origin/auth matrix, enabled global verification and legacy zero-Keychain |
| AC-03 | 1 independent new-project/identity/catalog tests; 2 retry/new membership; 6 discovery presentation; 8 closed-Controls live inheritance/discovery |
| AC-04 | 2 authentication/identity/key/stream barriers, repeated mode, reused sockets, compact/background/title/cancellation |
| AC-05 | 1 missing/unavailable/402/429/5xx/3xx/TLS/connection no-fallback; 2 exact call counts/transport |
| AC-06 | 3 strict channel/EOF/backpressure; 4 UUID/context/late reply/timeout/external ownership; 5 current-child/generation reconciliation |
| AC-07 | 6 projection/layout/Quit/navigation; 7 usage docs; 8 native visibility/accessibility |
| AC-08 | 4 retained-child/helper regressions; 5 Off/uncertainty preserve Stop/Quit/recovery; 6 targeted guidance; 8 correct-context restoration |
| AC-09 | 1 sanitized request evidence/zero legacy calls; 3/4 no control-time credentials/preflight, bounded I/O; 7 private-resource exclusion |
| AC-10 | 1–6 focused synthetic regressions; 7 fresh full suites/build/three zero-skip package cases; 8 actual native observation |
| AC-11 | 8 attributed Off→On→Off/same-chat/new-project outcomes and independently verified recovery |
| AC-12 | 8 sequential final spec/quality dispositions and local-only closeout |

## Self-review and approval handoff

Self-review: all AC-01–AC-12 have owning tasks/tests; all five Review Focus cases have explicit test ownership and native observation where needed. Producer/consumer mode enum, getter, backend methods, channel envelopes and controller names are consistent. Tasks carry separate reviewable selection, timing, Node protocol, native process, controller, presentation, packaging and acceptance outcomes. Test-only Task 2 records actual results rather than inventing RED; observation/documentation Task 8 does not add artificial tests. No future account/editor/startup work or product code is included in this planning stage.

**Execution endpoint:** Only this increment, verified/reviewed and committed locally on `feat/companion-routing-on-off`, with exact operational recovery and truthful limitations reported. A failed required workflow returns to scope after recovery, rather than silently expanding implementation.

**Current stage:** Stage 4 — both saved artifacts separately approved; subagent-driven implementation authorized by **plan confirmed, subagent driven confirmed**. Only this increment is authorized; no push, merge or later increment.
