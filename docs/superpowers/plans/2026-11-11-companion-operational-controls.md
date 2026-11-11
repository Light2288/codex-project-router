# Companion Operational Controls Implementation Plan

> **For agentic workers:** Use `personal-workflows:spec-implement` with `superpowers:subagent-driven-development`, explicitly selected by the user after separate artifact approvals. Implement task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Both saved artifacts are approved for implementation.

**Goal:** Deliver a native menu-bar companion that browses existing projects and safely operates the existing router through explicit activation, manual desktop restart and confirmed direct recovery.

**Architecture:** Keep configuration/routing and provider editing in Node. Add a bounded local subprocess bridge for inspection and guarded existing controls; Swift owns the running child, private recovery journal and confirmation state. A SwiftUI shell presents those separate facts, and a local `.app` bundles router code/dependencies while using an installed Node 24 executable.

**Tech Stack:** Node.js 24 ES modules and existing `smol-toml@1.9.1`; Swift 6, SwiftPM, XCTest, SwiftUI, AppKit, Network and Foundation/Darwin APIs. No new npm/Swift dependency, web server, Keychain management or background service.

**Spec:** [Approved companion specification](../specs/2026-11-11-companion-operational-controls.md)

**Slug:** `companion-operational-controls`

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-11

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Subagent-driven, explicitly selected in the user's native execution-method answer after separate artifact approvals.

**Provenance:** New plan for the selected approved specification. Stage 1 approval was `i confirm the scope/design, proceed`; Stage 2 approval was the later `approved` immediately following the saved specification handoff. The subsequent distinct `approved`, immediately following this saved plan's Stage 3 handoff, separately approves this plan and authorizes Stage 4 implementation. The user then explicitly selected `Subagent-driven (recommended): a fresh implementer and independent review for each task; higher cost.` through the execution-method control.

## Global Constraints

- Use the existing checkout; no worktree. No push or merge is authorized.
- Before product edits, verify separate specification and plan approvals, save both approved artifacts, safely update `main`, create `feat/companion-operational-controls`, then commit the approved pair on that branch. Preserve unrelated work and stop on conflicting evidence rather than reset/force.
- Native menu-bar app; manual Codex restarts and user-sent model prompts. Never restart Codex or send prompts automatically.
- Bundle router code and production dependencies; use an installed, validated Node 24 executable. No bundled Node, shell startup scripts, automatic installation or reliance on GUI `PATH`.
- Both existing modes and the current global-authentication coupling remain unchanged. `routeCredentials` stays rejected; no new default, inheritance, mapping, account or Keychain-management behavior.
- Configuration stays in place, private, outside Git and the app bundle. Activation/recovery uses the selected configuration's own records. Never copy actual configuration into build resources or committed evidence.
- Readiness, on-disk provider state, child ownership and desktop confirmation are separate facts. No health/status result proves desktop-loaded settings, gateway/key acceptance, billing or stream completeness.
- After possible desktop dependency, retain the owned listener until direct-on-disk state plus manual restart/working-direct-response confirmation. Closing the window keeps the app running. Unknown/external listeners are never adopted or signalled from PID/readiness alone.
- No control-time credential retrieval, destination preflight, auth-helper execution, policy enablement, factory reset, forced URL overwrite, automatic activation-lock removal, retries/fallback or continuation repair.
- Complete verification, the brief live lifecycle check and the sole sequential specification/quality final review. Restore exact prior operational settings and stop the known test listener. Then report and stop before later increments.

## Review Focus

1. A configuration is replaced or a symlink retargeted between inspection and mutation: preserve the activation context and fail closed rather than operate on a different provider/home — Task 1 and Task 3 tests.
2. Rollback returns `changed: false`, the app relaunches, or a transient probe recovers: none may clear pending restart/direct confirmation — Task 3 tests.
3. A matching listener survives an app crash or another process occupies the old port: no ownership adoption, PID-based stop or false cleanup success — Tasks 2–4 tests.
4. Bundling relocates `config.js`, GUI `PATH` lacks nvm, or an app path contains spaces: the packaged app still launches with selected Node while rejecting configuration inside Git/the bundle — Tasks 1, 2 and 4 tests.
5. A child floods stderr, emits malformed protocol data or exits during a mutating command: drain bounded output, retain an uncertain recovery obligation and never display private raw errors or blindly retry — Tasks 2–3 tests.

---

## 1. Repository evidence and decisions

Planning HEAD is `66cc1c9e24361ea3dd807e4ade2c8a2f37317220` on `main`; the only initial local change was the untracked companion specification. Artifact resolution is `NEW_ONLY` for that explicit specification and `MISSING` for its plan, with no legacy candidates. The plan therefore uses the specification's exact basename and shared slug. Current approval evidence is recorded above; plan approval remains pending.

No architecture map or ADR was found under the repository's architecture/ADR locations. Map freshness, map HEAD and accepted ADR constraints are unavailable; do not generate a map during planning. Key-path inspection covered `src/config.js`, `src/activation.js`, `src/cli.js`, diagnostics/errors, existing fixtures/control tests, package metadata and the approved specification.

Relevant implementation facts:

- `status` returns exactly `{state, proxyReady, recoveryRequired}`. Its private helpers already validate the provider and activation backup; reuse them rather than implement another provider editor.
- `loadRouterConfig` currently rejects paths inside a root derived from its module location. Packaged execution changes that root, so containment must be strengthened before packaging.
- Existing fixtures create synthetic catalog entries with `id` but no `name`; new browsing tests must supply realistic names locally without breaking unrelated identity fixtures.
- The production dependency package contains its manifest, `dist/` and BSD license. Package those resources explicitly, not the checkout or all of `node_modules`.
- Node 24, Xcode and Swift 6.4.2 are available on the inspected arm64 macOS host. Installed Swift help confirms `--package-path`, `--filter`, release/product build and binary-path options. No native package currently exists, and no native test/build was run while planning.

Use a SwiftPM package under `companion/` with library `CompanionCore`, executable `CodexProjectRouter`, and test target `CompanionCoreTests`; no third-party Swift dependencies. Set the package's macOS floor to 14 as a build choice; deliver/test the current arm64 installation only. Use a menu-bar entry opening one controls window, with `LSUIElement=true`; this is a local app, without notarization/public-distribution work.

No material product question remains unresolved. Module boundaries, polling intervals and protocol limits below are author implementation decisions within the approved scope. Execution-method choice changes the review/execution workflow, not this artifact's product design.

### Command evidence and new command contract

Existing commands come from `package.json` and README's Development checks: `npm test`, `node --check src/cli.js`, `git diff --check`. `npm ci` is the documented dependency setup command; do not repeat it when installed dependencies are valid.

The approved specification section 7 requires native tests, build/package verification and a real GUI launch, but the repository has no native commands yet. Tasks 2 and 4 explicitly introduce and document the following command contract in `package.json`, `companion/Package.swift` and `companion/README.md` before invoking it. These are planned additions, not claims about current scripts:

| Introduced command | Definition / required result |
|---|---|
| `npm run companion:test` | `swift test --package-path companion`; XCTest passes with no failures |
| `npm run companion:build` | `node scripts/build-companion.mjs`; release-build `CodexProjectRouter`, assemble and ad-hoc sign `dist/Codex Project Router.app`, exit 0 |
| `npm run companion:package-test` | `node --test test/companion-package.test.js`; verify the already-built app with synthetic state, exit 0 |

The build script uses installed-toolchain-supported `swift build --package-path companion -c release --product CodexProjectRouter` and `swift build --package-path companion -c release --show-bin-path`. Its test validates the defined command arguments; no shell interpolation. README will document the native commands and GUI launch. Before Task 4 creates the real package, `npm test` must not require an existing app bundle; package integration tests explicitly skip only that unavailable artifact with a reason. Final acceptance always includes the explicit package-test command against the built bundle with zero skipped package tests.

## 2. Files and shared interfaces

Create:

- `src/companion.js`: reusable snapshot/control functions; `src/companion-cli.js`: bounded one-request stdin/stdout adapter.
- `test/companion.test.js`, `test/companion-cli.test.js`: synthetic bridge, catalog, privacy and context tests.
- `companion/Package.swift`; core files `companion/Sources/CompanionCore/{WireTypes,PrivateStore,ProcessBackend,RouterController}.swift`; executable files `companion/Sources/CodexProjectRouter/{RouterApp,ControlsView}.swift`.
- `companion/Tests/CompanionCoreTests/{PrivateStoreTests,ProcessBackendTests,RouterControllerTests}.swift` and synthetic process fixtures under that test target's `Fixtures/`.
- `companion/Resources/Info.plist`, `companion/README.md`, `scripts/build-companion.mjs`, `test/companion-package.test.js`, and `docs/validation/companion-operational-controls.md`.

Modify `src/config.js`, `src/activation.js`, their existing tests, `package.json`, `.gitignore` and README only as required by the tasks. Preserve routing/credential/transport modules unless a demonstrated in-scope integration defect requires a causal fix. Ignore `companion/.build/`, `companion/.swiftpm/` and `dist/`.

### Node bridge contract

Export `inspectCompanion({configPath, browseHome})` and `runCompanionControl({action, configPath, expectedContext})` from `src/companion.js`. `configPath` is an absolute canonical path or null for browsing without selection. `browseHome` is an explicit absolute normal Codex home used only with null selection. Control `action` is exactly `activate` or `rollback`; it delegates to the existing functions.

CLI input is one JSON object with `schemaVersion:1`, `action:inspect|activate|rollback`, and only the applicable parameters. Read at most 16 KiB. Return one envelope, at most 1 MiB: `{schemaVersion:1,ok:true,result}` or `{schemaVersion:1,ok:false,error:{code,message}}`, using fixed safe errors and nonzero exit for failure. Never return complete configuration, destinations, Keychain references, auth commands, raw exceptions or credentials. Overflow is a fixed failure, not a partial catalog.

An inspection result contains:

- `configuration`: `state` (`missing|valid|invalid|unavailable`), optional canonical `path` and `mode` (`legacy|credential`).
- Optional `context`: `{configPath,codexHome,providerId,listenPort}`. Optional private `revision` covers canonical configuration fingerprint, relevant provider state and validated activation-record identity/phase; it is internal comparison metadata, never UI text/logging and never a hash of a credential value.
- `provider`: `state` (`direct|router|conflict|unavailable`), `recoveryRequired`; `proxyReady` is boolean or null when inspection is unavailable; `recordPhase` is `none|prepared|active|restored|unavailable`.
- `catalog`: `state` (`ready|unavailable`), `entries` containing `{id,name,routeAlias,routeState}`. `routeAlias` may be null; `routeState` is `mapped|unmapped|target_missing|catalog_missing`. No selection permits names with null aliases. No cached state is represented as fresh.

Add `inspectActivation(configPath)` in `src/activation.js` using the existing context/provider/record/readiness helpers. It returns validated context, comparison revision, record phase and existing status; keep `status(configPath)`'s public output exactly unchanged. Map `active` to `router` only in the companion projection. A provider/record failure must not prevent an independently readable catalog from being returned.

Mutations require exact `expectedContext` equality after fresh loading before delegation, including the canonical path; reject changed home/provider/port or invalid configuration. Activation additionally retains the helper's matching-fingerprint check. Rollback may tolerate unrelated mapping changes while remaining bound to its original context. Existing helper locks/compare-before-replace remain authoritative; do not claim a cross-file atomic transaction against external editors.

### Swift contract and conservative state

`WireTypes.swift` defines Codable `Inspection`, `ActivationContext`, `ControlResult` and the envelope using the field names above; `ControlAction` has cases `activate` and `rollback`. `RouterController` is `@MainActor` and observable, initialized with `backend: any CompanionBackend`, `store: PrivateStore` and `browseHome: URL`. All action methods return `Void` asynchronously: `refresh()`, `selectConfiguration(_ path: URL)`, `selectNode(_ path: URL)`, `start()`, `activate()`, `restoreDirect()`, `confirmRoutedResponse()`, `confirmDirectResponse()`, `stop()` and `requestQuit()`. They expose busy/error state and reject incompatible re-entry. Its `desktopConfirmation` enum has `unknown`, `routedPending`, `directPending`, `confirmedRouted` and `confirmedDirect`; `canStop` and `canQuit` are derived guard properties.

Inject `@MainActor CompanionBackend` with these signatures: `inspect(configPath: URL?, browseHome: URL) async throws -> Inspection`, `validateNode(_ path: URL) async throws -> URL`, `setNodeExecutable(_ validatedPath: URL)`, `start(configPath: URL) async throws -> OwnedRouter`, `control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult`, and `stop(_ child: OwnedRouter) async throws -> StopOutcome`. `ProcessBackend(resourcesURL: URL, nodeExecutable: URL?)` implements it with Foundation `Process`; `OwnedRouter` wraps the live Process reference, original context and an instance-local UUID, never a recovered PID. `StopOutcome` records child exit and a port state of `empty|occupied|unknown`. An `onChildExit: ((UUID, Int32) -> Void)?` callback notifies the controller on the main actor. Tests use a controllable backend with the same interface. Updating the executable affects subsequent commands, not an already running child's ownership.

`PrivateStore(directory: URL)` exposes `load() throws -> CompanionJournal`, `save(_ journal: CompanionJournal) throws`, `acquireInstanceLock() throws` and `releaseInstanceLock()`. The production directory is `~/.codex-project-router/companion/`; `state.json` has schema version 1 and owner-only protection. Fields are the selected configuration/runtime paths and optional `pending:{context,phase}` with phase `activation_attempt|routed_confirmation|restoring|direct_confirmation`. No configuration copies, endpoints, refs, secrets or persisted ownership. It also owns a kernel-released advisory single-instance lock in that directory. Corrupt/unwritable state fails visibly without overwriting it or silently selecting normal configuration. Create initial companion state only when absent; router configuration is never created.

Persist `activation_attempt` before provider mutation and `restoring` before rollback. A successful/no-change rollback of a possibly dependent context retains `direct_confirmation`; only a fresh matching direct inspection plus explicit user confirmation clears that obligation. Successful/no-change activation retains routed-confirmation obligations. Relaunch restores context and pending obligations but resets desktop-loaded confirmation to unknown and all prior children to unowned. Any observed relevant revision change, child exit or readiness loss invalidates confirmation; a later healthy poll cannot reinstate it.

Configuration selection remains locked while a child, pending operation or imported active/prepared/uncertain recovery depends on it. Runtime replacement is allowed for recovery without losing context. Fresh selection/normal discovery cannot supersede a retained pending context. A child started during a proven direct/no-pending session may be stopped without a response check only if no activation attempt or imported dependency has since occurred. Otherwise stop/Quit requires current direct state and explicit direct-response confirmation. Uncertainty always blocks destructive cleanup, while `restoreDirect()` remains available whenever its evidence/runtime permit.

`canStop` permits signalling the owned child only after those guards pass. `canQuit` is true only with no running owned child, no in-flight mutation and no unresolved recovery obligation. `requestQuit()` may first call guarded stop, then allow termination; it cannot terminate early merely because stop is allowed. A remaining external listener is reported separately and never signalled; direct confirmation may clear the desktop recovery obligation without falsely reporting that external listener stopped.

## 3. Implementation tasks

### Task 1: Add the private local inspection/control bridge [size: L | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,auth]

**Acceptance criteria:** AC-02, AC-03, AC-04, AC-05, AC-06, AC-09.

**Risk:** This boundary handles private configuration and directs existing provider mutations. It must neither leak sensitive fields nor switch recovery contexts. Catalog data validation is part of that same trusted projection, not a new identity resolver.

**Files:** Create the two Node companion modules and two corresponding tests; modify `src/config.js`, `src/activation.js`, `test/config-identity.test.js` and `test/activation.test.js`. Start `companion/README.md` with the bridge/command contract. Do not edit the proxy or credential reader.

**Interfaces:** Produce the Node bridge and `inspectActivation` contracts above; preserve all existing CLI/status outputs and historical legacy fingerprints.

- [ ] Verify the actual separate plan approval and execution-method selection, specification approval message, saved artifacts and current Git state. Only after both artifact approvals, safely fetch/update `main` with a fast-forward while preserving local artifacts/unrelated changes, create `feat/companion-operational-controls`, mark this plan approved, and commit the pair as `docs: approve companion operational controls`. If upstream changes invalidate evidence, reconcile before product changes; do not reset.
- [ ] Add failing tests named `inspection projects each mode without secrets`, `catalog survives provider failure`, `new and absent catalog projects remain explicit`, `mutation rejects changed activation context`, and `relocated runtime preserves private configuration containment`. Assert exact projected fields, unchanged router/provider bytes for inspection, correct alias/missing-target states, key/id mismatch failures, and no endpoint/ref/auth-command sentinel in any bridge output. Reuse synthetic fixtures with names added in these new tests only.
- [ ] Run `npm test`. Expected RED: missing bridge/inspection interfaces or new containment assertions fail, while unrelated existing tests remain valid. Record the initiating failures; do not count incidental broken fixtures as the intended RED.
- [ ] Implement the shared interfaces, separating configuration, provider and catalog failures. Catalog uses only `local-projects`; validate UUID key/id agreement and string names, detect conflicting normalized IDs, preserve exact mapping semantics, and include configured-but-absent IDs as `catalog_missing`. Re-read on every inspection; sort by name then ID and never write state/mappings. Add fixed schema/bounds/error handling in the CLI.
- [ ] Strengthen `loadRouterConfig` containment using the canonical path: retain the existing source-root exclusion and reject any ancestor `.git` marker (file or directory) or enclosing `.app` bundle. Do not spawn Git, add a schema field or weaken ownership/mode checks. Test external symlinks into those forbidden roots and packaged copies of the module; unchanged valid private files/fingerprints still pass.
- [ ] Cover both modes with fail-on-use credential/auth-helper subprocess guards and two local synthetic HTTPS counters: inspect/activate/rollback cause zero Keychain/helper/destination-preflight calls. Exercise offline rollback, prepared records, missing/changed backups, competing locks, unsupported provider syntax and later unrelated model edits; actual provider bytes remain the existing helper's responsibility.
- [ ] Run `npm test`, `node --check src/cli.js`, `git diff --check`. Expected GREEN: existing regressions plus bridge/control/privacy tests pass, syntax and whitespace clean. Commit assigned files as `feat: expose private companion inspection and controls`; follow the selected execution workflow's review policy before Task 2.

### Task 2: Build the native process and private-state foundation [size: L | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-04, AC-05, AC-08, AC-09, AC-10.

**Risk:** Runtime execution, process ownership and stored recovery metadata must not turn private data or stale PIDs into authority. This task implements mechanisms only; user-facing lifecycle decisions belong to Task 3.

**Files:** Create `companion/Package.swift`, core `WireTypes.swift`, `PrivateStore.swift`, `ProcessBackend.swift`, the matching two native test files/fixtures; modify `package.json`, `.gitignore` and `companion/README.md`. Initially expose the core library/test target; add the executable target in Task 4.

**Interfaces:** Consume the Task 1 wire contract; produce `CompanionBackend`, `OwnedRouter`, `StopOutcome` and `PrivateStore` above. Store writes are atomic and owner-only; the single-instance lock is nonblocking and held for the app lifetime, with close-on-exec.

- [ ] Define/document `companion:test` and the native package/test target. Add XCTest cases `testJournalRejectsCorruptionAndUnsafeFiles`, `testSecondInstanceCannotAcquireLock`, `testNodeSelectionIgnoresGuiPath`, `testProtocolOverflowNeverEchoesPayload`, and `testOnlyTrackedLiveChildCanBeStopped`. Assertions include 0700/0600 modes, symlink/foreign-file rejection, lock release after owner exit, no persisted process ownership, wrong/missing Node and resource paths with spaces.
- [ ] Run `npm run companion:test`. Expected RED: the declared interfaces/behaviors are missing; keep the package syntactically valid so failures identify the new contract. Use synthetic process fixtures, never real provider mutation or Keychain access.
- [ ] Implement `PrivateStore` with atomic replacement and explicit errors, plus the advisory lock; never modify existing activation locks. Node discovery tries a saved/user-selected path, standard local installation paths, then versioned Node 24 nvm locations, validating `--version` through an absolute executable. Do not execute a shell or shell profile. Keep actual selected paths only in private state.
- [ ] Implement async `ProcessBackend` with explicit executable/argument arrays and bundled resource URLs. Inherit necessary ordinary environment without repurposing HOME; remove Node injection variables such as `NODE_OPTIONS`/`NODE_PATH`, use system CA support, and never pass secrets. Validation/read-only requests have five-second deadlines. One-shot stdout is capped at 1 MiB, stderr at 16 KiB; valid envelopes are parsed only after successful exit. Mutating overflow/long execution is marked uncertain while pipes continue draining; do not kill/retry a write blindly or permit a second mutation before exit/reconciliation.
- [ ] Start router children via the bundled `src/cli.js serve --config` path. Continuously drain both pipes with bounded buffers and discard raw payloads after parsing; no unlimited log accumulation. After launch poll matching readiness for at most five seconds, retaining an explicitly tracked child on uncertain startup rather than claiming ownership of the port. Stop signals only the retained live Process, waits for termination and independently probes the loopback port with a one-second `NWConnection`: ready means occupied, explicit connection refusal means empty, other errors/timeouts mean unknown. Cancel the probe after its outcome; no recovered PID is ever accepted by `stop`.
- [ ] Extend tests for stderr floods, malformed JSON, unsuccessful exit with plausible stdout, stalled read-only child cleanup, mutating interruption, child exit/port reuse and drained long-lived output. Assert only fixed errors escape and no sentinel/ref/destination is persisted or logged. Run `npm run companion:test`, `npm test`, `git diff --check`; expected GREEN with no surviving test children/listeners. Commit as `feat: add native companion process and state support` and apply the selected task-review policy.

### Task 3: Implement activation, recovery and Quit coordination [size: L | risk: concurrency | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: concurrency]

**Acceptance criteria:** AC-02, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09.

**Risk:** Async refresh, helper completion, external edits and process exits can otherwise clear the wrong obligation or terminate a still-required listener.

**Files:** Create `RouterController.swift` and `RouterControllerTests.swift`; extend the Task 2 core types/backend/store only as required by the declared contracts. Document the state transitions in `companion/README.md`.

**Interfaces:** Consume `CompanionBackend` and `PrivateStore`; produce the exact controller actions and observable state above. A test backend exposes barriers for inspection, helper completion and child exit. Maintain a monotonically increasing request/context generation so stale async replies cannot replace current state.

- [ ] Add failing transition tests with held async operations. Pin the central guard:

  ```swift
  // After activation and successful rollback, even a no-change repeat:
  XCTAssertEqual(controller.desktopConfirmation, .directPending)
  XCTAssertFalse(controller.canStop)
  XCTAssertFalse(controller.canQuit)
  // Only after an explicit response confirmation and fresh direct snapshot:
  await controller.confirmDirectResponse()
  XCTAssertTrue(controller.canStop)
  ```

  Cover `testLateRefreshCannotReplaceRecoveryContext`, `testNoChangeRollbackKeepsConfirmationPending`, `testRelaunchPrioritizesPendingProfile`, `testRecoveredProbeDoesNotReconfirmDesktop`, `testExternalListenerCannotAuthorizeActivationOrStop`, and `testActivationAttemptPersistsBeforeMutation`.
- [ ] Run `npm run companion:test`; expected RED on guard, persistence or ordering assertions. Implement serialized actions, persisted pre-mutation intent, fresh reconciliation after helper completion/failure, and generation-checked refresh results. A failed helper is never proof that the provider was untouched. A store write failure blocks a not-yet-started mutation and never clears a prior obligation.
- [ ] Require matching readiness and the tracked child before activation. Preserve context on provider/record/config failure; allow restore despite missing readiness/model/Keychain, subject to valid runtime/context/evidence. Keep catalog state independent. Existing unrelated mapping edits invalidate confirmation but cannot silently retarget rollback. Block configuration switching during any owned-child/pending/imported dependency.
- [ ] Implement both explicit user confirmations as asynchronous actions that re-inspect the same context before acceptance. No-change results/polls/window-close cannot confirm a desktop restart. On relevant revision change, readiness loss or child exit invalidate confirmation and retain conservative recovery. For pending restore, confirmation stays pending until direct state is readable; a later healthy poll alone never clears it.
- [ ] Implement guarded stop/Quit and never-activated direct-session exception exactly as the shared contract states. Await child exit and independent port result; do not equate matching-fingerprint disappearance with an empty port. A failed/unknown stop remains visible. On relaunch all prior listeners are external; after direct confirmation expose targeted manual cleanup instead of adoption. A second app instance fails visibly without state mutation.
- [ ] Add scenarios for duplicate clicks, runtime replacement during recovery, rollback before/after an external URL edit, stale returned snapshots, child death during activation/rollback, malformed journal, a short-lived port replacement and repeated stop/quit. Run `npm run companion:test`, `npm test`, `git diff --check`; expected GREEN. Commit as `feat: coordinate companion activation and direct recovery` and apply the selected review policy.

### Task 4: Deliver the menu-bar UI and relocatable local app [size: L | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10.

**Risk:** Integration must expose the tested controller truthfully and actually work when launched by macOS without the development environment. Platform packaging is the primary review domain; do not move provider-editing or ownership rules into UI callbacks.

**Files:** Create the executable SwiftUI files, `Info.plist`, build script and package test listed above. Modify the SwiftPM manifest, npm scripts, README and `companion/README.md`; extend native tests only for real presentation/controller integration gaps.

**Interfaces:** The app owns one `PrivateStore`/lock and one `RouterController`. `ControlsView` renders controller facts/actions. The build script exports `assembleCompanion({binaryPath,routerRoot,outputPath})` for synthetic copy-policy tests and its CLI performs the documented release build plus assembly/signing. Bundled router entry points are `Contents/Resources/router/src/cli.js` and `companion-cli.js`.

- [ ] Add presentation/controller tests and package tests before implementing the integration. Verify all five state dimensions remain separate; `Setup required` still allows selection/browsing; an invalid provider does not hide readable projects; close-window differs from Quit; control enablement matches controller guards; external listener status offers no stop/adopt action. Package assertions require the executable, ESM manifest, router sources and only `smol-toml` manifest/`dist`/license resources, with no Node binary, real configuration, tests, Git data or private paths.
- [ ] Run `npm run companion:test` and `npm test`; expected RED on the new presentation/resource contracts. Add the executable target and menu-bar/control-window UI. Use native file panels for existing configuration/Node selection; present a provider-wide activation notice and separately labeled manual restart/response confirmations. Show mode, exact local selected path, disk state, readiness, ownership, pending confirmation, projects and fixed actionable errors; never endpoint/ref details or a synthesized global connected indicator. An AppKit delegate keeps the app alive after the last window closes and intercepts both menu/keyboard and application termination requests: route them through `requestQuit()`, cancel while guards remain unresolved, and terminate only when `canQuit` is true.
- [ ] Refresh immediately and every two seconds while the controls window is visible; refresh operational state every five seconds while hidden and on every action. Only one inspection may be in flight, with a coalesced refresh rather than a request queue. Manual refresh remains available; stale/unavailable catalog entries are visibly marked. Use a local search field for names/aliases and stable per-project identity; no assignment editing, hiding or archive promises.
- [ ] Implement the bundle assembly from an explicit resource allowlist, copy actual installed pinned production dependency files and license, generate nonprivate app metadata, and ad-hoc sign the local app. Add/document `companion:build` and `companion:package-test` exactly as the command contract. No source-checkout path or selected Node path is embedded as a runtime dependency.
- [ ] Run `npm run companion:build`, then `npm run companion:package-test`. Tests use a relocated bundle path containing spaces, synthetic private configurations and a sanitized environment lacking nvm in PATH. Exercise bundled bridge/control startup using the explicitly selected real Node runtime and local fixtures, forbid checkout-relative resource loads, and test rejection of configs in a synthetic Git checkout and inside the bundle. Verify app metadata and signature through the package-test harness; this harness must fail rather than skip if the built artifact is missing.
- [ ] Launch the packaged app through macOS, confirm native menu/window behavior and inspect its states with the user. Keep provider/router settings unchanged during this UI/package check. Observe first launch/selection/no-auto-start, close/reopen controls, setup errors, catalog refresh, window sizing and legibility. A GUI check with inaccessible checkout can use the relocated artifact and resource tests; never rename/delete the user's actual checkout merely to test independence.
- [ ] Run `npm run companion:test`, `npm test`, `node --check src/cli.js`, `git diff --check`; expected GREEN, package tests run against a fresh built bundle with no skips. Complete setup/recovery/process-ownership/deferred-work documentation and commit as `feat: deliver native router companion app`. Apply the selected review policy before live activation.

### Task 5: Validate one real lifecycle, review and finish recovery [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-06, AC-07, AC-08, AC-09, AC-10, AC-11.

**Risk:** Real activation affects desktop availability, and restart/working-response evidence requires the user. Missing evidence must remain incomplete; no load/billing expansion is permitted.

**Files:** Create `docs/validation/companion-operational-controls.md`; update README/companion documentation only where observed evidence requires clarification. Do not edit the historical reports or add private runtime files to Git.

**Interfaces/ownership:** The controller owns private checkpointing, exact file comparisons, process evidence and recovery; the user owns model prompts/restarts. If subagent-driven execution is selected, only a sanitized symbolic handoff reaches a document implementer/reviewer; private files remain outside that worker's scope. The same real-user boundary applies under Native execution.

- [ ] Recheck current status and the relevant records for the exact chosen private configuration, confirm no conflicting listener, and checkpoint exact prior router/provider bytes/property presence in owner-only storage outside Git. Prefer an existing compatible configuration that preserves this controller's access; verify the project mapping privately without fetching credentials. Confirm the app's selected runtime/profile and no automatic activation.
- [ ] Record fresh preactivation `npm test`, `npm run companion:test`, `npm run companion:build`, `npm run companion:package-test`, `node --check src/cli.js` and `git diff --check` results. Start and activate through the companion, verify matching tracked readiness and URL-only provider changes, then ask the user to restart Codex and send one short prompt. Record user response confirmation and any available sanitized local transport outcome separately; do not turn a cancelled stream into HTTP 200 or claim independent loaded-settings/billing proof.
- [ ] Restore through the companion even if routed validation fails. Verify exact owned URL restoration and unrelated-setting preservation, require the user's full restart/working-direct-response confirmation, then stop the known owned child and independently verify no listener on that selected port. Confirm the companion reports the distinct final facts correctly. Exact original router settings remain unchanged by the UI; compare privately with the checkpoint. Keep recovery pending if any required user action/check is missing; do not claim completion.
- [ ] Write the symbolic report with app/runtime versions, exact commands/exits and decisive proof lines, UI observations, live outcomes, recovery, unrun cases and limitations. Preserve the earlier connection issue, cancellation/stream/billing qualifications and the user's later billing evidence as historical context, not new results. List all deferred account/default/assignment/visibility/startup outcomes explicitly. Commit as `docs: record companion validation and recovery` after whitespace checks; rerun executable checks only for changed executable artifacts or unresolved concerns.
- [ ] Run the sole whole-branch `personal-workflows:code-review` integrated gate with the approved pair, complete baseline-to-review-HEAD diff, automated evidence, sanitized package/UI/live report, and execution-policy dispositions in one immutable review package. Specification review runs first; quality opens only after its verified PASS. Apply the selected execution workflow's fix/re-review policy without adding another whole-branch reviewer. A failed/missing required live capability stays incomplete regardless of review verdict.
- [ ] Commit final reviewed evidence/dispositions on the implementation branch. Report the working app and how to launch it, fresh verification, live outcomes and recovery, limitations, deferred increments and reached endpoint. Do not push, merge or start later specification/planning work.

## 4. Acceptance traceability and self-review

| Criterion | Task / decisive evidence |
|---|---|
| AC-01 | 2 runtime/process tests; 4 built/relocated app and real native launch |
| AC-02 | 1 strict in-place mode/config projection; 3 context locks; 4 first-launch/no-activation checks |
| AC-03 | 1 current catalog and mapping states; 4 refresh/search/UI failure display |
| AC-04 | 1 independent facts; 3 confirmation/relaunch transitions; 4 rendered dimensions |
| AC-05 | 1 helper/context safety; 2 ownership/single-instance; 3 ordered guards; 4 activation notice |
| AC-06 | 1 offline/existing helper regressions; 3 recovery state; 5 real restoration evidence |
| AC-07 | 2 tracked stop/port reuse; 3 stop/Quit tests; 4 close-window/quit integration; 5 final stopped listener |
| AC-08 | 2 store/process failure; 3 conservative reconciliation; 4 visible guidance; 5 limitations |
| AC-09 | 1 projection/containment/no-secret controls; 2 bounded I/O; 4 clean bundle; existing Node regressions |
| AC-10 | 2 native command setup; 4 test/build/package/UI/docs; 5 sequential final gate |
| AC-11 | 5 user-assisted brief lifecycle, exact recovery and symbolic report |

Self-review completed against the approved specification: all AC-01–AC-11 have task/test ownership; shared method/field names agree; each Review Focus item is pinned by task tests; no product requirement is delegated to an unspecified future increment. Package/test commands are explicitly introduced contracts, not assumed pre-existing tools. The plan preserves the independent spec/plan approvals, current main/artifact state, private operational boundaries and all deferred work. No implementation, build, proxy start, credential retrieval or operational change occurred during planning.

**Execution endpoint:** complete this companion increment, required verification/review and brief live lifecycle; restore exact prior operational settings, verify a working direct response and stopped owned listener; report evidence and limitations; then stop. Push, merge and later increments remain unauthorized.

**Current stage:** Stage 4 — the saved specification and implementation plan received separate explicit approvals; the user separately selected subagent-driven execution. Implementation is authorized. No additional artifact approval is needed unless scope or plan changes materially.

**Initial execution checkpoint:** After the separate plan approval, `npm test` exited 0 with 643 tests, 643 passing, 0 failed/cancelled/skipped/todo (`duration_ms 45515.424083`). The full synthetic baseline log is retained outside Git. The checkout remains on `main` at `66cc1c9`; both artifacts are saved and uncommitted, with no product changes, branch creation, main update or operational change. The execution-method question is pending; no method is inferred from the plan approval.
