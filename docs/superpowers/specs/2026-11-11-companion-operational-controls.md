# Companion operational controls — specification

**Slug:** `companion-operational-controls`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-11

**Provenance:** The user's companion-UI handoff, read-only repository and operational inspection, native clarification answers, and Stage 1 scope/design proposal in this chat. The user approved that proposal with `i confirm the scope/design, proceed`. Existing evidence includes `README.md`, all reports under `docs/validation/`, and `docs/superpowers/specs/2026-11-11-project-credential-routing.md` with its corresponding plan. These earlier artifacts remain unchanged.

**Approval state:** Stage 1 was confirmed by `i confirm the scope/design, proceed`. The user separately approved this saved specification with `approved`, immediately following its Stage 2 handoff. The user then separately approved the saved implementation plan with a distinct later `approved` immediately following its Stage 3 handoff, and subsequently explicitly selected subagent-driven execution. Stage 4 implementation is authorized. Native clarification answers are decision evidence, not artifact approvals.

## 1. Problem, desired outcome and delivery boundary

The wider direction is a convenient, recoverable macOS companion for accounts, project assignments and router operation. The selected first increment is **operational controls for existing configurations**. It must provide an independently runnable menu-bar app from which the user can inspect projects and configuration, start the router, explicitly activate routing, and restore direct operation through a guided manual-restart workflow.

The app must work without a functioning model connection. It must preserve authentication, models, unrelated Codex settings, existing assignments and the historical validation record. A stopped listener is not evidence of successful return to direct operation, and a matching listener is not evidence of settings loaded by a running desktop process.

This boundary evaluates lifecycle coordination and usable recovery before adding account authoring or routing migration. Include the native app, local packaging, router integration, private operational state, safeguards, automated verification, documentation, one brief live lifecycle check, and sequential specification/quality review. Do not extend this increment into the deferred capabilities in section 9.

**Execution endpoint:** deliver the locally runnable companion, complete verification/review and the brief live activation/recovery check, report working behavior, evidence and limitations, restore the exact prior operational settings and confirm a working direct response and stopped test listener, then stop before later increments.

## 2. Current behavior and evidence

Inspection found a clean `main` at `66cc1c9e24361ea3dd807e4ade2c8a2f37317220`; local `main`, `origin/main` and actual remote `main` matched. This records inspected state, not a guarantee for later execution. There is no existing native app or build system. The router uses Node.js 24, ES modules, built-in APIs and `smol-toml@1.9.1`. Swift and Xcode are available on the user's local arm64 macOS installation.

`src/cli.js` exposes `serve`, `status`, `activate` and `rollback`, each with an explicit private configuration path. Configuration is loaded at router startup; settings changes require a listener restart. `src/activation.js` changes only the supported provider's base URL, protects writes with a lock and expected-content checks, and retains an exclusive backup and activation record next to the configuration used for activation. Recovery records do not necessarily live next to the normal configuration. CLI status reports disk state and matching readiness; it cannot establish desktop-loaded settings or process ownership.

Both existing modes remain supported:

- Legacy mode preserves the incoming credential for admitted requests.
- Credential-routing mode verifies incoming authentication against `credentialRouting.globalCredential`, then selects mapped model targets from `credentialRouting.routeTargets`. Catalog and qualifying unassigned-title requests retain the verified incoming credential and global destination.

Keep that coupling and routing behavior unchanged. The old `routeCredentials` format remains rejected. The first UI does not introduce default-account selection, inheritance, implicit mappings or new routing fallbacks. Known unmapped projects remain failures.

Private inspection confirmed direct operation for both the normal and saved enabled configurations, restored activation records, provider bytes matching their recorded backups, and no listener on the configured validation port. No credentials were retrieved or settings changed. The normal configuration has credential routing, observation and the title exception disabled; the saved enabled configuration is inactive. Inspection of the current project catalog found no project archive/hide field. These are observations of the current installation, not stable platform guarantees.

Recorded credential-routing verification is 643 passing tests plus syntax/whitespace checks and sequential reviews without findings. Those checks were not rerun for this specification. Preserve the reports' qualifications: four mapped live requests initiated 499/CANCELLED despite user-visible complete responses; stream completeness and cancellation cause remain unproven; cross-instance continuation and independent team attribution remain unverified; live fork, saved-subagent and dedicated-compaction cases were unrun for credential routing. Preserve the historical failed validation that sent project keys to the global gateway.

The user's subsequent billing observations provide additional operational confidence, including a later Project A HTTP 200 and increases in global and shared project-gateway usage. These are user-supplied evidence from the handoff, not independently revalidated here. Shared gateway credit counters do not distinguish teams; Project B was not separately retested in that run. No new load or billing tests are authorized by this increment.

## 3. Selected approach and application delivery

Native clarification selected:

1. Operational controls first, rather than account routing and controls together.
2. A SwiftUI menu-bar app with a small control window, rather than a Dock-only app or local web UI.
3. Guided manual desktop restarts, rather than app-driven quit/reopen.
4. Direct recovery before Quit stops a required router, rather than leaving an intentionally detached service.
5. Both existing configuration modes, deferring the new designated-default activation rule.
6. One brief live lifecycle check, rather than synthetic-only acceptance.
7. Bundled router code with an installed Node 24 executable, rather than bundling Node itself.

The native approach fits menu-bar operation and later macOS integration without adding a browser control server. Reusing the router's validated controls avoids a second provider editor. Deferring account/default migration keeps the first outcome independently testable.

Deliver a locally built `.app` for the current arm64 macOS environment. Bundle the router sources and required production dependency so the launched app does not depend on an open terminal, the source checkout, or a development server. Use the selected installed Node executable through an absolute path; validate major version 24. Offer local executable selection when discovery fails or the saved executable is unavailable. Do not execute shell startup files, install Node automatically or rely on the GUI's inherited `PATH`.

The following are design calls proposed by the author within the confirmed scope, not additional user selections: local build/package support rather than public distribution; no Dock-only primary interface; serialized subprocess controls rather than a network control API; no automatic adoption of a previously running listener. Exact internal module/file layout and build tooling remain implementation-planning choices.

## 4. Configuration selection and project browsing

On first launch, inspect the normal private configuration if present. Remember an explicitly selected existing configuration in private companion preferences. Allow selection of another existing private file, including a saved enabled configuration, without copying, rewriting or migrating it. Do not search private validation directories and silently choose a candidate. Never activate on launch, selection, discovery or refresh.

Retain existing schema and provider-compatibility validation. Files must remain private and outside Git and the app bundle; packaging must not weaken containment checks by relocating router sources. Do not place actual endpoints, references, IDs, mappings, runtime paths or private evidence in committed build metadata.

Missing configuration shows `Setup required` and permits selection and project browsing where the catalog is readable. Invalid/incompatible configuration is reported distinctly and blocks start/activation. This setup state means an existing operational configuration is needed; the future designated-default rule is not implemented. A valid legacy configuration is activatable under the current CLI rules. Missing/wrong Node disables controls requiring it and provides runtime selection, without inventing a connection failure.

Read the selected configuration's `codexHome` for project discovery; when no configuration is selected, browse the normal Codex home if readable. Catalog browsing must not depend on listener readiness, provider compatibility, model connectivity or Keychain availability. Display project names and current explicit aliases, distinguish no mapping from a missing credential target in enabled mode, and retain configured mappings whose projects are absent from the current catalog as unresolved entries. Do not infer an account or project from a name, folder or recent activity.

Refresh automatically while the control window is open and provide manual refresh. Newly created projects can appear without restarting the companion. Discovery never writes a mapping or changes routing; a newly identified unmapped project remains blocked even while the UI is closed. Unreadable/malformed catalog state is a visible browsing failure; cached entries, if retained, must be marked stale. Validate record/key identity sufficiently to avoid displaying a misleading assignment. Do not read chat bodies or mutate desktop state.

Selection is locked while a listener owned by this companion, an activation, or pending recovery depends on the current context. Preserve the selected canonical configuration path and its own recovery context across operations and relaunch. A relaunch with unfinished recovery prioritizes that context over normal-path discovery. Unresolved external state must be reported before another configuration can be used to activate the same provider/listener. Do not treat an unrelated restored record as recovery for a different configuration.

## 5. Controls and truthful state

Present separate facts rather than a single optimistic connected indicator:

| Dimension | Meaning |
|---|---|
| Configuration | Selected path, validation/setup outcome and legacy or credential-routing mode |
| Provider on disk | Direct, points to router, conflict, or unavailable according to validated state |
| Listener | Matching readiness, not ready, or unavailable/unknown; readiness is not process ownership |
| Process ownership | Child launched and still tracked by this companion, external/unowned, or none |
| Desktop confirmation | Unknown, restart/confirmation pending, or user-confirmed routed/direct operation for the current context |

Expose `Start router`, `Activate routing`, `Restore direct connection`, guarded stop, refresh and Quit. Internal presentation may combine steps into one explicit activation flow, but it must show which step failed and preserve the recovery guard.

Starting launches bundled router code with system CA support and the validated Node path, without changing provider settings. Activation requires a compatible selected configuration, a live tracked child launched for that configuration, matching readiness, and no unresolved conflict. If needed, the explicit activation flow may start the child first. A matching external listener can be inspected but is not adopted or used for a new activation. Never kill a process merely because it occupies the port or answers health requests.

Activation retains the existing helper's backup, locking and narrow base-URL replacement. Explain its provider-wide effect and that unmapped requests can block. After a URL change, show restart/confirmation pending and guide the user to fully restart Codex and confirm a short working response. No helper or UI action automatically restarts the desktop or sends a prompt.

The confirmation records what the user reported; it does not prove process-loaded settings, credential correctness, gateway billing, or complete stream delivery. Repeated no-change operations and later status refreshes cannot clear pending confirmation. Invalidate confirmation after an observed relevant configuration/record change, child exit or readiness loss; relaunch begins with desktop-loaded state unknown and preserves any pending recovery obligation. A later healthy probe alone cannot reinstate prior confirmation.

Serialize mutating controls and disable conflicting actions while an operation is in progress. Concurrent companion launches must not create duplicate owned listeners or race recovery; a second instance presents the existing app or fails visibly without mutation. Use bounded structured subprocess I/O, no shell, no secret arguments, and fixed sanitized errors. Drain process output so diagnostics cannot block the listener; never show raw subprocess exceptions/output as UI errors. Read-only inspection/catalog communication may use an additive local subprocess interface. Preserve the existing public CLI and routing behavior; exact bridge schemas are planning decisions.

## 6. Direct recovery, Quit and failure handling

`Restore direct connection` remains available when the selected listener or model connection is unavailable. It uses the configuration and activation record associated with that activation, not an assumed normal directory. Execute the existing rollback semantics without credentials, destination probes or desktop authentication-helper execution.

The workflow is:

1. Restore only the owned provider URL using validated recovery evidence; preserve current unrelated changes and authentication/model settings.
2. Report direct settings on disk separately from pending desktop restart/confirmation. Keep an owned listener available while Codex may still use it.
3. Guide a full manual restart and obtain explicit confirmation of a working direct response. Recheck that disk state remains direct for the same context.
4. Stop only the still-tracked owned child, verify its exit and listener outcome, and report completion accurately. An unexpected remaining listener is an external/unknown condition, not a successful stopped state.

The restoration write itself never waits for a working model response. If confirmation is impossible, leave the workflow visibly pending and retain the listener when possible. Report direct operation as user-confirmed only after the user's confirmation; lack of a response is not repaired by a factory reset or settings deletion.

Closing the control window leaves the menu-bar app and router running. Explicit Quit follows the same guard: do not terminate an owned listener while the desktop may depend on it or recovery is unresolved. Direct-on-disk status alone is insufficient after activation. A listener that was only started may be stopped without a new response check only when no activation/imported recovery dependency has been introduced; unknown state is not treated as proof of safety.

Unexpected companion termination, child exit or machine shutdown cannot be prevented by this increment. On relaunch, re-read provider/configuration/recovery state and local readiness, show degradation or pending recovery, and offer restoration without automatically starting, activating, adopting or terminating a listener. A surviving child from an earlier app instance is unowned by the new instance; PID persistence or matching readiness alone does not authorize signalling it. After direct confirmation, report any independently managed listener and provide a targeted manual cleanup procedure rather than claiming automatic cleanup. Supervised crash recovery remains deferred.

Missing or changed backups, malformed/prepared records, competing locks, an unexpected owned URL, unsupported provider syntax or externally edited configuration retain existing fail-closed behavior. Do not force an overwrite or automatically remove a lock. If the helper cannot safely run, show a targeted local recovery procedure for the recorded provider URL/backup; preserve evidence and unrelated settings. A missing runtime is recoverable by selecting Node; native replacement of the provider editor is outside scope. Do not promise automatic recovery from destroyed/unverifiable evidence.

Private companion preferences and pending-operation context live outside Git with owner-only protection. Keep only the operational metadata needed for selection, ownership tracking and conservative reconciliation; do not duplicate credential material or entire provider/router configurations. Such state supplements rather than replaces existing activation records. An interrupted operation is reconciled by fresh inspection, never assumed to have completed from an earlier UI intention.

## 7. Privacy, compatibility and validation

UI operations retrieve no Keychain secrets and create/edit/delete/unlock no items. Actual routed requests retain existing bounded fresh Keychain reads in enabled mode. Controls do not preflight gateways, invoke the desktop authentication helper, change optional policies, alter provider authentication, rewrite models/continuations or introduce fallback/retries. No new background service, login item, SessionStart hook or automatic activation is installed.

Private project names, aliases and paths may be rendered locally where needed for operation. Do not log/export raw catalog or configuration state. Keep credentials, values/hashes/prefixes, Keychain references, actual destinations and raw process errors out of app diagnostics and committed evidence. Existing router request diagnostics remain private under their established allowlist. Retained operational logs/evidence are bounded and owner-only. Package/build output must contain no actual private configuration or evidence.

Verification includes existing Node regression checks (`npm test`, `node --check src/cli.js`, `git diff --check`), appropriate native unit/integration and build/package checks, and visual/manual native UI verification. Synthetic fixtures cover malformed state, process/runtime failures, mismatched/external listeners, duplicate launch, interrupted activation/recovery, external edits, pending-confirmation persistence and invalidation, repeated operations, preserved unrelated settings, output bounds/privacy, and restoration with proxy/model/Keychain unavailable. Tests use synthetic state and local destinations; do not retrieve real credentials or contact real gateways.

Verify the packaged app launched through macOS without a terminal, with a minimal GUI environment and unavailable source checkout. Include missing/wrong runtime, app/resource paths with spaces, and preservation of private-path validation. Build artifacts and private generated preferences stay outside committed sources.

After separate specification and plan approval and implementation, perform one controlled live lifecycle check. Privately checkpoint exact prior settings, choose an existing compatible configuration, start/activate through the companion, manually restart Codex, and obtain one short working response confirmation. Restore through the companion, manually restart, confirm direct response, then stop the known owned listener and independently check its absence. The user performs restarts and model prompts. Restore exact prior settings even on validation failure; preserve unrelated changes. Report missing/failed live actions honestly rather than substituting synthetic success. Do not repeat project matrices, long responses, concurrency, key changes, load or billing tests. Existing credential-routing limitations remain applicable.

Complete the required sequential specification review followed by quality review for the implemented increment. The DRAFT's builder check is a separate completeness check, not that final gate or artifact approval.

## 8. Acceptance criteria

| ID | Criterion |
|---|---|
| **AC-01** | A locally built native menu-bar `.app` opens its control window and runs bundled router code/dependencies using a validated installed Node 24 path, without an open terminal, development server or accessible checkout. Missing/wrong runtime yields actionable setup state. |
| **AC-02** | First launch and explicit configuration selection inspect existing private files in place, preserve exact configuration/mapping/optional-property contents and mode semantics, and never start/activate automatically. Missing/invalid/incompatible configuration is distinguished; both valid existing modes are supported. |
| **AC-03** | Read-only project browsing shows current names, aliases, unmapped/missing-target and unresolved entries; automatic and manual refresh discover new projects without writing mappings. Unreadable/conflicting catalog state is visible and cannot invent an assignment. |
| **AC-04** | UI state separates on-disk provider configuration, matching listener readiness, tracked ownership and desktop confirmation. Status/health cannot establish loaded settings, gateway/key readiness or billing. Confirmation stays pending across repeated operations and is invalidated/reconciled as specified. |
| **AC-05** | Explicit start/activation launches only the selected bundled router, requires matching tracked readiness, preserves existing backup/lock/URL-only editing, and guides manual restart/response confirmation. Conflicting operations, duplicate app launches and active-context switching cannot race or discard recovery context. |
| **AC-06** | Restore works with the proxy/model/Keychain unavailable when runtime and recovery evidence are valid; it restores only the intended URL, preserves authentication/models/later unrelated edits and uses the activation's own directory. Failures remain visible without force overwrite, broad reset or automatic lock removal. |
| **AC-07** | After activation, stop and Quit retain a required owned listener until direct disk state, manual restart and working-direct-response confirmation. Window close leaves operation running. Child termination and independent listener checks determine reported cleanup; unknown/external processes are never killed/adopted by PID or readiness alone. |
| **AC-08** | Interrupted operations, child failure and relaunch reconcile fresh disk/record/listener evidence conservatively, preserve pending recovery, and provide offline restoration/manual guidance. No automatic activation/restart/supervision is introduced or crash availability promised. |
| **AC-09** | Synthetic privacy and process tests demonstrate no credential retrieval/preflight for UI controls, bounded drained output and no raw private-state/error leakage. The package preserves containment validation and excludes actual private configuration/evidence. Existing routing, authentication and transport regressions pass unchanged. |
| **AC-10** | Native tests/build/package/UI checks and the existing Node/syntax/whitespace checks pass; operational/setup/recovery/deferred-work documentation is delivered; sequential final specification and quality reviews have actionable dispositions. |
| **AC-11** | The brief real companion lifecycle is recorded with user-confirmed routed/direct responses, exact prior-settings restoration and independently verified stopped owned listener. No load/billing test is added; historical failures and unverified capabilities retain their qualifications. Missing live evidence remains incomplete. |

## 9. Constraints, deferred increments and handoff

Use the existing checkout; no worktree. Keep the artifacts uncommitted until the implementation branch is created. Do not update `main` or create the implementation branch before separate specification and implementation-plan approvals. Stage 3 creates a separate plan with this specification's exact basename and shared slug. Before implementation, save both approved artifacts, identify their approval messages, safely update `main` while preserving local work, and create a conventional implementation branch. No push or merge is authorized.

Future delivery remains provisional and explicitly includes:

| Deferred capability | Required future outcome/decisions |
|---|---|
| Account setup and editing | Account registry/display names, complete HTTPS prefixes, concealed key entry, native Keychain creation/editing and existing-item selection, affected-project preview, reassignment before deleting an in-use account. |
| Default setup, inheritance and assignment editing | Explicit default designation and setup-required activation rule, first-account selection and migration, caller verification versus outgoing-default coordination/separation, preserving overrides, and default routing for identified new projects even while the UI is closed. |
| Visibility | Router-owned hiding with override preservation/reveal; verify what the user's Codex action changes before promising any project archive synchronization. |
| Startup and supervision | Optional login startup, supported integration mechanisms, crash supervision and reliable ownership/adoption. Discovery, startup and activation remain separate behaviors. |

No account/Keychain/default/routing-schema migration, assignment editing, project hiding/archive writes, desktop automatic restart, telemetry/export service, network control API, App Store/public distribution, notarization, bundled Node, cross-platform/remote-host support or fix for the historical unreproduced connection issue is included.

**Builder completeness check:** A fresh read-only reviewer returned `nothing important left`. This confirms no material planning question was identified; it is not specification approval, an implementation plan, or the final implementation review gate. Author checks confirmed DRAFT metadata, sequential AC-01–AC-11, the execution endpoint and absence of a companion plan.

**Current handoff:** Stage 4 — this specification and the separate saved implementation plan are approved, and subagent-driven execution is explicitly selected. Implementation is authorized. The builder check is not the final implementation review gate.
