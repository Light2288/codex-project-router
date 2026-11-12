# Companion operational controls — validation and recovery

**Created:** 2026-11-11

**Updated:** 2026-11-11

**Slug:** `companion-operational-controls`

**Status:** Approved increment complete. Fresh verification and the brief user-assisted lifecycle/recovery are recorded; the sole integrated sequential specification/quality gate passed after scoped corrections. No open findings remain.

This report covers the approved [specification](../superpowers/specs/2026-11-11-companion-operational-controls.md) and [implementation plan](../superpowers/plans/2026-11-11-companion-operational-controls.md). It records controller-observed local facts separately from user-reported restarts and working responses. The document worker used only the controller's sanitized handoff; private live checkpoints, process evidence and full private logs remain outside Git with owner-only protection. Synthetic verification and review results are summarized here.

The real lifecycle used the existing normal **legacy** profile. Both required manual restarts and working-response confirmations were explicitly reported by the user. Direct restoration and the stopped owned listener were independently checked locally. No live restart, response-confirmation or owned-listener cleanup obligation remains. The companion remains running idle. These live observations provide no new independent HTTP, stream-completeness or billing evidence. The completed final review is recorded below.

## Build, runtime and automated verification

The local app is version `0.1.0`, bundle version `1`, on arm64 macOS `27.0.1`, using installed Node `v24.21.0`. The Swift package requires macOS 14 or newer. Delivery is a locally built, ad-hoc signed app; it includes router resources and the pinned production dependency, but no Node runtime, private configuration or operational evidence. There is no notarization, public distribution or installed startup/login service.

Fresh preactivation verification was run by the controller. Every command below exited 0; full logs were retained privately. Product code was at `a002020`; subsequent commits before the live check changed only progress metadata.

| Exact command | Exit | Decisive result |
|---|---|---|
| `npm test` | 0 | 659 tests, 659 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo |
| `npm run companion:test` | 0 | 68 core tests: 4 store, 15 process backend, 49 controller; plus 4 app tests. All 72 passed. Core: 35.813 seconds; app: 0.038 seconds |
| `npm run companion:build` | 0 | `Build complete` in 1.71 seconds; `Built and ad-hoc signed dist/Codex Project Router.app` |
| `npm run companion:package-test` | 0 | 2 tests, 2 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo |
| `node --check src/cli.js` | 0 | No output |
| `git diff --check` | 0 | No output |

Package tests used a relocated path containing spaces, an explicitly selected real Node runtime, `PATH=/usr/bin:/bin`, and a working directory outside the checkout. They checked pinned resources, ESM metadata, arm64 architecture and signature, explicit Swift command argument arrays, synthetic serve/readiness/activation/byte-exact rollback, no matching listener afterward, and rejection of configurations inside Git or the app bundle. Automated tests made no real gateway or Keychain calls.

The final-review source-denial check adds a third package test: `native relocated app and bundled controls work with checkout reads denied by macOS`. It copies the signed app outside the checkout and launches its actual native executable under `/usr/bin/sandbox-exec`. The Seatbelt profile denies filesystem reads and writes for both the lexical and resolved checkout paths and guards the real `~/.codex` and `~/.codex-project-router` locations. The actual checkout remains intact. The synthetic child environment uses a private temporary `HOME`, `CFFIXED_USER_HOME`, and `PATH=/usr/bin:/bin`; outbound network access is denied except loopback.

Negative controls under that same profile fail to read the existing checkout's `package.json`, including through a temporary symlink. A real Node source read through that symlink fails with `EPERM`; its source import fails with `ERR_MODULE_NOT_FOUND` because Node masks denied stat calls. The source fixture's existence is checked before confinement. These checks establish filesystem denial, rather than assuming relocation prevents source access.

The native child displayed its own on-screen window, identified by its exact tracked PID through CoreGraphics, and `lsof` confirmed that PID held the **synthetic** companion `instance.lock`. This directly verifies the native app's synthetic store location rather than assuming Foundation obeys `HOME`. The test separately invokes the relocated bundled CLI and serve entry points under the same profile, with a real installed Node 24 path: synthetic catalog inspection, readiness, activation, byte-exact provider rollback and unchanged router configuration all pass. Both tracked long-lived children exit; their PIDs are absent and the synthetic port can be rebound. Short-lived commands are awaited and bounded by deadlines. No GUI control click or native-owned router is inferred from those separately invoked bundled controls, and no user process is adopted or signalled.

The targeted command `node --test --test-name-pattern='native relocated' test/companion-package.test.js` passed with 1 test, 1 pass, 0 fail and 0 skipped. A deliberate temporary test-only change selecting the denied checkout CLI instead of bundled resources failed with exit 1 / `MODULE_NOT_FOUND`; restoring the bundled path returned the same command to exit 0. This closes the source-inaccessible launch/bundled-operation evidence gap. The full package command was rerun after the test change: **3 tests, 3 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo; exit 0**. No executable resources changed, so no rebuild was needed. `git diff --check` also exited 0.

This is macOS Seatbelt filesystem-denial evidence with direct native-executable launch, not a separate user account, VM or LaunchServices broker-inheritance test. It requires a logged-in macOS GUI session, the existing Swift toolchain and `sandbox-exec`; it fails when its required evidence is unavailable. The existing human GUI observations below and explicit restart/response confirmations retain their separate attribution. The check uses only synthetic configuration/catalog/provider/activation state, performs no gateway/authentication-helper calls, and leaves the user's idle companion untouched.

For local build and launch instructions, see the [companion documentation](../../companion/README.md). The built app opens through macOS with:

```sh
open "dist/Codex Project Router.app"
```

The source-denial-only test/report fix above did not change executable resources. Its historical checks remain separate from the executable remedies and fresh verification recorded below.

### Final-quality remedies and fresh automated verification

The final quality review found that the companion's retained context was lost
before the authoritative activation/rollback helper reloaded configuration. The
remedy forwards that context and compares it with the helper's own loaded
canonical path/home/provider/port before any mutation lock or write. Four
synthetic regressions replace configuration contents or retarget the selected
path to another configuration after companion validation, for both activation
and rollback. The symlink cases keep home/provider/port identical to isolate
canonical configuration/recovery-directory identity. Conflicts return
`ACTIVATION_CONFLICT`, attempt no mutation lock, and preserve both contexts'
provider, recovery, backup and other setting bytes apart from the deliberately
replaced selected configuration.

The second remedy explicitly distinguishes private-state initialization failure.
Such an instance cannot have launched a child/helper: its operational controls
remain disabled, while normal Quit preserves the corrupt/unsafe journal without
backend operations or writes. Native regressions cover both malformed journal
and unsafe-directory initialization. Existing usable-state recovery and in-flight
mutation/child/stop/Quit guards remain covered by the full suite.

Fresh checks after these executable changes passed; packaging checks used the
rebuilt app. Every command below exited 0. Full synthetic logs are retained
outside Git.

| Exact command | Exit | Decisive result |
|---|---|---|
| `npm test` | 0 | 664 tests, 664 pass, 0 fail/cancelled/skipped/todo; `duration_ms 45793.593542` |
| `npm run companion:test` | 0 | 69 core tests (4 store, 15 process backend, 50 controller) plus 4 app tests: 73 pass, 0 failures; core 36.457 seconds, app 0.036 seconds |
| `npm run companion:build` | 0 | `Build complete! (3,28 secs)`; `Built and ad-hoc signed dist/Codex Project Router.app` |
| `npm run companion:package-test` | 0 | 3 tests, 3 pass, 0 fail/cancelled/skipped/todo, including native source-denial; `duration_ms 2991.556458` |
| `node --check src/cli.js` | 0 | No output |
| `git diff --check` | 0 | No output |

Both new behaviors first failed their targeted regression assertions before the
fixes: four Node cases reported the missing `ACTIVATION_CONFLICT` rejection;
two native initialization cases failed Quit availability/request assertions.
Focused GREEN then passed 53 Node helper/companion tests and all 50 controller
tests before the full checks above.

These results exercise deterministic synthetic fixtures, not a fresh live race
or GUI initialization-failure/Quit scenario. The idle user companion remains the
earlier build and was left untouched. The rebuilt app is the new deliverable;
earlier live restarts, responses and recovery below remain separately attributed
historical observations. All MCP preservation, stream/billing, unrun and deferred
qualifications in this report remain in force. The scoped follow-up specification and quality reviews passed with both findings addressed and no new findings. Their identities and dispositions are recorded below.

## Actual native GUI observations

The controller opened a relocated signed app through macOS and independently observed its process alive. Initial router/provider bytes were unchanged and the selected port was empty: launch had neither started nor activated the router.

The user explicitly confirmed readable controls, a correct project list and project names, and successful close-window/reopen through the menu-bar **Open controls** action. Native menu **Quit** closed the companion; the controller verified the old process was gone before launching the updated reviewed app.

The actual file picker was used to select a synthetic example inside the checkout. The UI showed **Invalid configuration** with Start disabled. Returning to the existing normal private configuration showed **Valid / Legacy / Direct**. Before live start, the controller verified the updated app was running with the normal selected profile, no pending journal recovery, unchanged router/provider bytes and an empty selected port.

Existing route aliases were explained as saved labels, not account names. No account/assignment edits or routing migrations occurred. With the selected legacy profile, other unmapped projects remain blocked while routing is active. Account display names and editing remain deferred.

## One brief real lifecycle

### Preparation and activation

The controller privately verified the current chat's exact saved mapped assignment and chose the existing normal legacy configuration to preserve controller access. The selected activation record was restored/direct/not ready with no recovery required. Exact prior router/provider bytes and optional-property presence/value were checkpointed outside Git with owner-only protection.

Controls retrieved no credentials, changed no keys, ran no authentication helper or gateway preflight, and changed no configuration policy.

The user clicked **Start router**, waited for matching readiness and tracked ownership, then clicked **Activate for provider** and accepted its notice. The user reported **On disk Router**. Independent controller checks established:

- A valid active record and active disk state, matching readiness, and no recovery required.
- The listener was a direct child of the running reviewed companion and used that bundle's serve entry point with Node `v24.21.0`.
- Exact router configuration bytes were preserved.
- The provider change was exactly one `base_url` literal; every other byte and parsed setting was preserved at activation.
- The journal retained `routed_confirmation` bound to the selected context.

One private comparison checker initially returned false because `structuredClone` changed `smol-toml` object prototypes. Independent line/literal checks were already true. Read-only diagnosis identified the checker defect, and a parser-preserving comparison passed. Both failed and corrected private evidence were retained; no product or operational rewrite was made in response to that checker result.

### Routed restart and response

The user was instructed to fully restart Codex with the companion/router retained and return with a short marker in the same chat. After the marker, the controller observed active disk state, matching readiness, the same recorded router still listening, the reviewed app alive and routed confirmation still pending.

The user then explicitly reported the full restart and a working routed response, clicked the routed-response confirmation, and selected **Restore direct**. This is user-reported loaded-settings and working-response evidence. Local status/readiness does not independently establish what the desktop process loaded.

### Restoration, direct confirmation and stop

After Restore, the controller observed `state=direct`, `proxyReady=true`, `recoveryRequired=false` and a restored selected activation record. The same known owned router remained available and `direct_confirmation` persisted while the user still needed to restart.

The restoration comparison has two distinct outcomes:

| Compared fact | Observed outcome |
|---|---|
| Exact original owned provider URL | Restored |
| All provider tables, including authentication; model selection; every non-MCP setting | Restored/unchanged |
| Exact original router configuration bytes, including optional-property presence/value | Preserved |
| Whole-provider byte equality to the initial checkpoint | **FALSE** |
| Remaining provider differences | Exclusively unrelated `mcp_servers` table bytes/settings after restart |

No writer is attributed to the unrelated MCP changes without evidence. Those updates were preserved. This report makes no whole-provider byte-exact restoration claim.

The user was instructed to fully restart Codex again with the owned router retained and return with a direct marker. Afterward, the controller checked direct disk state, restored provider tables and all non-MCP settings, exact router bytes, the same retained router, and direct confirmation still pending. The user explicitly confirmed a full direct restart and working response, clicked direct confirmation and **Stop owned router**, then reported **Child exited / Port Empty**.

Final independent checks established all of the following:

- The original owned URL was restored; all provider tables and all non-MCP settings were unchanged. Remaining byte differences were exclusively within MCP settings.
- Exact original router bytes and optional-property presence/value were preserved.
- The positively recorded router PID was absent, with no bundled serve process remaining.
- Independent `lsof` inspection found no listener on the selected port.
- The pending journal was cleared and the normal selected profile retained.
- Final status was `state=direct`, `proxyReady=false`, `recoveryRequired=false`, with the record restored.

The companion remains running idle. No required live restart, response confirmation or owned-listener cleanup remains pending. The brief lifecycle used **Stop** after direct confirmation; menu Quit was observed before live activation, not as the active-router cleanup path.

## Acceptance evidence and review boundary

| Criterion | Evidence and qualification |
|---|---|
| AC-01 | Native/runtime and package tests, signed relocated macOS launch and observed live bundled child; focused Seatbelt test verifies actual native window/synthetic store plus separately invoked bundled controls while checkout reads are denied, including symlink negative controls |
| AC-02 | Inspection/containment regressions, unchanged first-launch bytes/empty port, real invalid-file selection and return to Valid/Legacy/Direct; no automatic activation |
| AC-03 | Catalog/mapping-state tests and user-confirmed correct visible project list/names. No assignment authoring or account-name inference |
| AC-04 | Controller confirmation/reconciliation tests and observed distinct disk/readiness/ownership/pending-confirmation states. Restarts/responses remain explicit user reports |
| AC-05 | Helper/process/controller guards, URL-only live activation, matching tracked bundled child and provider-wide notice |
| AC-06 | Existing offline/helper and preservation regressions; actual original URL/provider/auth/model/non-MCP restoration while preserving unrelated MCP updates. Whole-provider byte equality was false |
| AC-07 | Stop/Quit/ownership and port-outcome tests, observed close/reopen and native menu Quit, real direct confirmation followed by owned-child exit and independent empty-port check |
| AC-08 | Store/process/controller failure and conservative recovery tests plus documented guidance. Crash/relaunch/adoption was not separately exercised live; no supervision claim |
| AC-09 | Existing Node regressions, synthetic bounded-I/O/privacy/containment checks and clean bundle. Controls did not retrieve real credentials, inspect request bodies or preflight destinations |
| AC-10 | Fresh automated/native/build/package evidence, actual GUI observations and operational documentation. Sole integrated sequential specification/quality gate passed after scoped corrections; no open findings |
| AC-11 | User-confirmed routed/direct restarts and working responses, exact owned-setting/router recovery, preserved unrelated changes, independently stopped listener. No current transport/stream/billing outcome captured |

The sole final integrated gate is complete. Initial specification review identified the source-denial evidence gap, closed by the focused package test and scoped specification PASS. Whole-branch quality review then found the Important authoritative-context reload race and Minor initialization-failure Quit trap. The combined correction was committed as `d028350`, with meaningful RED/GREEN and all fresh checks above. Scoped specification review passed first; the same quality reviewer then marked both findings ADDRESSED and returned PASS with no new findings, breakage or out-of-scope observations. The prior unchanged-code assessment was retained; no second whole-branch review seat was dispatched. Missing/unrun evidence retains its qualifications. The extra corrective wave exceeded the base workflow cap under the explicitly recorded user-instruction-precedence ruling below.

## Unrun cases and limits of the current check

The real lifecycle exercised legacy mode only. A real credential-routing GUI lifecycle, missing/wrong-runtime GUI cases, duplicate-instance GUI behavior, crash/relaunch/adoption, external-listener replacement, failure injection and keyboard Quit were not separately exercised live. Automated coverage exists where documented in the approved plan and companion documentation; it does not turn those cases into live observations.

Direct native foreign-UID `chown` and deterministic `NWConnection` unknown-outcome fault injection were unobserved in Task 2. UID guards are implemented and had task-level code review; unsafe modes, symlinks and hardlinks were tested. Synthetic controller unknown-stop outcomes were tested.

No current HTTP transport status, complete stream delivery, cancellation cause, independent process-loaded settings, gateway/team attribution or billing proof was captured. A visible working response and matching readiness do not establish HTTP 200. There was no request-body inspection; the app continuously drains/discards diagnostics. No long-response, load, concurrency or project-matrix expansion occurred.

The earlier unreproduced connection issue remains undiagnosed and is not claimed fixed. Native router survival during the user-reported restarts is evidence for this lifecycle only.

## Preserved historical qualifications

The earlier [credential-routing validation](project-credential-routing.md) remains unchanged. Four mapped requests initiated with `499/CANCELLED` despite user-visible complete responses. Complete HTTP stream delivery, cancellation cause, cross-instance continuation and independent gateway billing/team attribution remain unestablished. Live fork, saved-subagent and dedicated-compaction cases were unrun, with synthetic coverage retained. The historical failed run sent project keys to the global gateway; separately approved endpoint/key pairing corrected that configuration capability. Neither that failure nor cancelled transport outcomes are relabeled here.

Subsequent user-supplied billing observations came from an earlier handoff, **not this companion run**: global usage increased `43 → 44`; Project A produced long responses, including one HTTP 200 around 178 seconds; and shared project-gateway budget usage increased `0 → 1`. Teams on that same instance share the budget, so those counters cannot distinguish teams or keys. The user privately verified the intended stored original keys. Together with mappings and successful routes, this provides operational confidence while independent gateway-side team attribution remains unverified. Project B was not separately retested in that billing run; earlier successful live evidence is retained. The user stopped load testing. Names and targets remain symbolic.

## Deferred capabilities and endpoint

The wider companion direction does not authorize subsequent increments. Deferred work remains:

- Account registry, display names and editing; complete destination-prefix entry; concealed secret entry; native Keychain create/edit/existing-item selection; affected-project preview and reassignment before deletion.
- Explicit default setup, designation, inheritance and assignment editing; first-account selection and migration; incoming-auth verification versus outgoing-default design/coordination; default routing for identified new projects while the UI is closed, with overrides preserved.
- Router-owned project hide/reveal with override preservation, and verification of Codex archive representation before promising synchronization.
- Optional supported login startup, supervision and crash recovery, including reliable ownership/adoption. Discovery, startup and activation remain separate.

No automatic desktop restart or prompt, startup/activation, connection factory reset, public distribution/notarization, bundled Node, cross-platform/remote-host support, telemetry/export service or network control API is included.

The approved increment has reached its endpoint: working local app, verification, user-assisted lifecycle/recovery, task reviews, sole final sequential gate and recorded dispositions. Required live recovery is complete with the owned-setting/MCP qualification above. Work is committed locally on `feat/companion-operational-controls`; no push, merge or subsequent increment was performed.

To use the reviewed rebuilt app, choose **Quit Codex Project Router** from the currently idle older copy, then open `dist/Codex Project Router.app` using the command above. Opening it does not activate routing. The new native build has synthetic launch/package evidence; the earlier human GUI/lifecycle observations retain their recorded build boundary.


## Final review identity and reports

The immutable package covered baseline `66cc1c9e24361ea3dd807e4ade2c8a2f37317220` through reviewed product HEAD `d02835080b0b1ffc2c582a0ca2fada1259156627`. The final evidence commit changes documentation only. Parent and both reviewers independently verified the same package bytes and identities; quality opened only after the fresh specification PASS.

- Gate run: `2be3c051-3a90-42aa-92d6-d68802c14bae`
- Reviewed state: `git:d02835080b0b1ffc2c582a0ca2fada1259156627:419fddd1-da64-4db8-b3f6-b5501e284f21`
- Review-package SHA-256 (nonsecret review evidence): `d3ed95ea527375b62bee137210ea0fc557666777a3181359fd42e5366bd8150f`
- Specification reviewer: `review-spec`, `gpt-6-luna`, high reasoning
- Quality reviewer: `review-quality`, `gpt-6.1-sol`, high reasoning

### Final scoped specification result

```text
SPEC REVIEW: PASS

GATE_RUN_ID: 2be3c051-3a90-42aa-92d6-d68802c14bae
REVIEWED_STATE_ID: git:d02835080b0b1ffc2c582a0ca2fada1259156627:419fddd1-da64-4db8-b3f6-b5501e284f21
PACKAGE_SHA256: d3ed95ea527375b62bee137210ea0fc557666777a3181359fd42e5366bd8150f

The package identities and recomputed hash match the expected values. It contains the approved specification and plan, complete changed-file list and branch diff, scoped corrective diff, verification evidence, integrated mode, and the disclosed execution-policy exception.

Both findings are addressed within approved scope:

- src/activation.js passes the retained context to the authoritative helper, which compares it with its freshly loaded context before directory validation, lock creation, readiness checks, or writes. Synthetic replacement and symlink-retarget regressions cover activation and rollback; they assert ACTIVATION_CONFLICT, no mutation lock, and preserved state.
- RouterController.swift allows normal Quit after initialization failure, which occurs before this instance launches a child or helper. Operational controls remain disabled, failed journal/store evidence is preserved, and ordinary recovery and Quit guards remain intact. Corrupt-journal and unsafe-store tests cover this path.

The package reports meaningful RED/GREEN results and fresh verification: 664 Node tests, 73 native tests, and 3 package tests passed with zero skips; build, syntax, and whitespace checks also passed. The corrective delta is limited to the helper, controller, tests, and related documentation; no new scope was found.

Declined to judge, retained from the prior assessment: private checkpoint and live-operation truth; GUI control invocation and native-owned router under source denial; unrun live GUI, failure-injection, and listener scenarios; direct foreign-UID and deterministic network unknown-outcome behavior; transport, stream, billing, and historical connection claims; and deferred account, Keychain, assignment, visibility, startup, distribution, and platform capabilities.
```

### Final scoped quality result

```text
QUALITY REVIEW: PASS — scoped corrective follow-up.

GATE_RUN_ID: 2be3c051-3a90-42aa-92d6-d68802c14bae
REVIEWED_STATE_ID: git:d02835080b0b1ffc2c582a0ca2fada1259156627:419fddd1-da64-4db8-b3f6-b5501e284f21
PACKAGE_SHA256: d3ed95ea527375b62bee137210ea0fc557666777a3181359fd42e5366bd8150f

Expected identities, current package identities/recomputed hash, and the complete fresh SPEC REVIEW: PASS all match. The package remained unchanged.

Reviewed only 0166e4d→d028350, the two original findings, their regression evidence, and possible new breakage from that delta. The prior unchanged-code assessment is retained.

Finding dispositions:

1. Important context-binding race — ADDRESSED. src/companion.js:89 forwards expectedContext. The authoritative helper compares it with its own loaded canonical path, home, provider and port at src/activation.js:156, before directory validation, lock creation, readiness checks or writes. Both mutation paths retain the loaded configuration afterward. Four regressions cover activation/rollback with replacement contents and symlink retargeting, including canonical-path-only differences. They assert ACTIVATION_CONFLICT, zero mutation-lock attempts and preserved state. Calls without the optional guard retain existing CLI behavior.

2. Minor initialization-failure Quit trap — ADDRESSED. RouterController.swift:91 records initialization failure separately. canQuit and requestQuit() allow exit for that state, which occurs before this instance launches any child/helper. Operational controls remain disabled; normal usable-state recovery and mutation guards are unchanged. Corrupt-journal and unsafe-store regressions verify Quit availability, no backend operations, preserved evidence and sanitized errors.

New findings: NONE.
New breakage: NONE found.
Out-of-scope observations: NONE.

The supplied evidence records meaningful RED failures followed by passing focused regressions and fresh checks: 664 Node tests, 73 native tests, rebuilt signed app, three package tests with zero skips, syntax and whitespace checks. I reviewed that evidence without rerunning suites or performing operational actions.

Declined-to-judge behaviors:
- Actual live replacement races and GUI initialization-failure Quit: synthetic evidence only; no fresh live exercise was claimed.
- Independent truth of private checkpoints, process comparisons and user restarts/responses: prohibited private/operational access; supplied attribution remains intact.
- GUI controls and a native-owned router under source denial: unobserved; the package establishes native window/store behavior and separately invoked bundled controls.
- Other disclosed unrun live GUI, crash/relaunch, listener-replacement, failure-injection and keyboard-Quit scenarios: automated evidence does not establish live observations.
- Direct foreign-UID and deterministic native network-unknown outcomes: direct behavioral evidence remains unobserved.
- Stream completeness, cancellation cause, independent loaded settings, gateway/team billing, cross-instance continuation and the historical connection issue: evidence remains insufficient.
- Deferred account/Keychain/default/assignment editing, visibility, startup/supervision, distribution, bundled Node and other platforms: outside approved scope.

Both original findings are closed by this corrective delta. No files were changed and no additional review seat or fix loop was initiated.
```

## Execution rulings

The following are every ledger ruling, in original order, with the stated cost if wrong. They preserve the implementation decisions before this plan's ignored workspace is removed.

- Ruling: Honor the explicit existing-checkout preference rather than create a worktree — user instructions override isolation defaults — reduced checkout isolation if wrong, with all work confined to the named feature branch.

- Ruling: Task 1 approval/main/branch/artifact step is already complete in b9d97c0; workers verify and consume it, never repeat setup — avoids replaying completed authorized work — rework only if the setup evidence is later disproven.

- Ruling: Package tests may skip a missing app only during ordinary npm test before packaging; npm_lifecycle_event=companion:package-test makes a missing artifact a failure — implements the approved dual invocation contract without a new production flag — failed final package verification if invocation detection is wrong.

- Ruling: For new compile-time interfaces, minimal signature scaffolding may enable meaningful failing behavioral assertions; do not count accidental import/fixture failures as TDD proof — aligns plan RED intent with TDD quality — rework if the reported RED does not exercise the intended behavior.

- Ruling: Preserve exact route-key semantics while validating UUID catalog key/id identity in normalized form; reject ambiguous duplicate normalized identities and leave non-exact case-only mappings catalog_missing — avoids inventing an assignment or changing the existing resolver — malformed-case data may require manual correction if this conservative UI projection rejects it.

- Ruling: Preserve the existing loader's CONFIG_UNAVAILABLE for unreadable/malformed JSON and project fixed companion invalid/unavailable categories without reparsing solely for classification — retains legacy error semantics and privacy — generic correction guidance may be less specific for malformed JSON.

- Ruling: Native decoding follows the reviewed Task 1 wire with proxyReady and recordPhase nested under provider; the planning bullet grouped those provider facts ambiguously — aligns consumers to the actual local bridge without a product-scope change — wire compatibility rework if consumers use a root-level field.

- Ruling: start retains and returns a live owned child after readiness timeout; fresh inspection determines readiness, without a new historical startupReady authority — avoids losing the child or activating from a stale startup observation — a delayed startup remains visibly not-ready until refreshed.

- Ruling: Permit a narrow internal discovery-candidate dependency injection initializer while preserving the public initializer and production candidate order — deadline tests need deterministic slow executables without editing real installations or HOME — extra internal testability seam may need removal if it diverges from production execution.

- Ruling: Add explicit CompanionBackend.mutationRequiresReconciliation property (ProcessBackend: mutationInFlight || needsReconciliation), with no default-false protocol extension — controller must not accept direct/routed confirmation or cleanup from apparently direct disk while an uncertain provider helper still runs — additive internal API/test work; false reporting by a backend would remain unsafe. This implements existing approved uncertainty/cleanup scope under the plan's allowed core extensions.

- Ruling: Enforce strict inspection single-flight across refresh and action inspections inside RouterController during Task 4 integration; UI busy gating alone is insufficient — approved Task 4 explicitly requires one inspection in flight and coalescing, and action authorization must stay fresh after prior reads — narrow scheduler/test changes may need rework if they weaken generation safety or queue stale requests. This fulfills existing scope, not a new concurrency product design.

- Ruling: Strengthen package validation with isolated macOS filesystem denial of the checkout while leaving the actual checkout intact — the final specification review requires direct AC-01 evidence beyond the approved plan's relocation/resource tests — extra platform-specific verification work, and an honest remaining limitation if the isolation mechanism cannot demonstrate that condition.

- Ruling: Make one additional combined corrective wave and scoped sequential follow-up for both quality findings, despite the base final-review single-wave cap — the user explicitly requires completing the approved increment autonomously with no extra gates between ordinary implementation tasks, and the context-binding guard/failure handling are already approved requirements; this higher-priority authorization takes precedence over stopping at the skill cap — additional implementation/review cost and rework if the narrow remediation broadens or weakens recovery. This is a disclosed execution-policy exception, not a new increment, artifact-scope change, or permission to push/merge.
