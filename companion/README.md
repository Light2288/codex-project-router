# Companion operational controls

The companion uses bundled router modules through an installed Node 24 executable.
Private router configuration remains in its original location, outside all Git
checkouts and application bundles. Controls never retrieve credentials, execute
the provider authentication helper, or preflight destinations.

## Local bridge

`src/companion.js` exports `inspectCompanion({configPath, browseHome})` and
`runCompanionControl({action, configPath, expectedContext})`.

`configPath` is an absolute canonical path. For browsing without a configuration,
pass `configPath: null` and an explicit absolute normal Codex `browseHome`.
Selected configurations use their own `codexHome` and activation directory.
Inspection reads current state without changing configuration or mappings.

Run `node src/companion-cli.js` with one JSON object on stdin. The request has
`schemaVersion: 1` and `action: "inspect"`, `"activate"`, or `"rollback"`.
Inspection accepts only `configPath`, plus `browseHome` when the path is null.
Mutations require `configPath` and the exact fresh inspection `expectedContext`:
`{configPath,codexHome,providerId,listenPort}`. No shell is required.

The CLI accepts at most 16 KiB and emits exactly one JSON envelope, at most 1 MiB:
`{schemaVersion:1,ok:true,result}` or
`{schemaVersion:1,ok:false,error:{code,message}}`. Failures exit nonzero with
fixed safe errors. Overflow fails without a partial catalog. The existing
`src/cli.js` commands and status output are unchanged.

Inspection separates configuration, provider and catalog outcomes. Configuration
is `missing`, `valid`, `invalid`, or `unavailable`; a valid selection includes its
canonical path and `legacy` or `credential` mode. Provider state is `direct`,
`router`, `conflict`, or `unavailable`, with independent `proxyReady`,
`recoveryRequired`, and `recordPhase`. A provider/recovery failure retains the
selected context and any independently readable catalog.

Catalog entries contain only `{id,name,routeAlias,routeState}`. They use current
`local-projects`, validate UUID key/record agreement and string names, and sort
by name then ID. Routing keeps exact existing mapping keys. Unmapped projects
have null aliases; missing credential targets are `target_missing` in credential
mode. Configured projects absent from the catalog remain `catalog_missing`, with
an empty name: display these as explicitly unresolved projects with their IDs.
Malformed/unreadable catalogs return `unavailable` with no fresh entries.

`revision` is private comparison metadata for configuration identity, effective
provider state and validated activation-record identity/phase. Never render or
log it. It excludes raw provider bytes and authentication values. Provider URL
changes within an already conflicting state cannot create usable confirmation.
`inspectActivation(configPath)` exports `{context,revision,recordPhase,status}`;
the historical `status(configPath)` returns only its unchanged status object.

Activation and rollback freshly validate the exact expected context before
delegating to existing controls. Activation still requires matching listener
fingerprint readiness. Rollback works offline and tolerates unrelated mapping
changes while preserving the selected recovery context. Existing helper locks,
backup validation, URL-only editing and compare-before-replace remain
authoritative; there is no cross-file transaction against external editors.

Readiness proves neither desktop-loaded settings nor gateway/key acceptance.
Restart Codex manually after provider changes and explicitly confirm a working
response. Native lifecycle and recovery controls are documented with the app.

## Native core verification

`npm run companion:test` builds the macOS Swift package and runs its XCTest
suite. Tests use private temporary directories and controlled fixture processes;
they do not select or modify actual router/provider configuration or Keychain.

The `CompanionCore` library contains the wire types, `PrivateStore`, and the
main-actor `ProcessBackend`. The `CodexProjectRouter` executable adds the native
menu-bar item and controls window on macOS 14 or newer (Apple silicon).
`ProcessBackend(resourcesURL:nodeExecutable:)` expects a resource directory with
`src/companion-cli.js` and `src/cli.js`; packaging must include their production
modules and dependencies. Paths containing spaces are passed as individual
arguments to `Process`, never interpreted by a shell.

Runtime discovery validates an explicit/saved executable first, then
`/opt/homebrew/bin/node`, `/usr/local/bin/node`, `/usr/bin/node`, and versioned
Node 24 installations under `~/.nvm/versions/node/`. It never searches the GUI
`PATH` or reads a shell profile. Commands pass `--use-system-ca`; their environment
contains only ordinary identity, locale and temporary-directory variables.
`NODE_OPTIONS`, `NODE_PATH`, dynamic-loader variables and unrelated secret-bearing
environment variables are excluded.

Read-only requests have a five-second deadline. One-shot stdout is limited to
1 MiB and stderr to 16 KiB; error messages never contain raw child output.
Timeout, cancellation, overflow, invalid responses or unsuccessful exit after a
provider operation begins leave its outcome uncertain. A live mutation keeps
draining and is never killed or retried automatically. Further writes remain
blocked until it exits and a fresh matching inspection reconciles the context.

A router start retains the actual child `Process` and a session-local UUID.
Matching readiness is polled for at most five seconds after launch. If the child
is still live after that interval, the caller receives its retained handle and
must inspect fresh readiness rather than assume startup succeeded. Stopping
accepts only that exact currently live handle. Its result distinguishes child
exit from the loopback port being empty, occupied or unknown. An occupied port
can belong to another listener, which is never adopted or signalled.

The app supplies `~/.codex-project-router/companion/` as the production private
store directory. It must be owned by the current user with mode 0700; `state.json`
and `instance.lock` must be regular, singly linked, owner-only mode-0600 files.
Symlinks, foreign ownership, unsafe modes, corrupt/unknown journal fields and
unsupported schemas fail visibly. State is atomically replaced and synced;
existing unsafe evidence is preserved. The schema stores only selected paths
and optional recovery context/phase, never process IDs, process ownership,
configuration copies, destinations, credential references or authentication
commands. The nonblocking advisory instance lock is held until explicit release
or store lifetime ends; its descriptor is closed on exec and kernel-released on
process exit. Existing router activation locks are untouched. If initialization
fails on corrupt or unsafe private state before this instance can launch a child
or helper, operational controls remain disabled and normal Quit is available.
Quit preserves that evidence; it does not repair the store or confirm recovery.

## Controller state and recovery

`RouterController` is a main-actor observable coordinator over `CompanionBackend`
and `PrivateStore`. Construct it with the normal Codex home for catalog browsing.
It acquires the instance lock before loading or initializing state. A second
instance fails visibly and does not inspect, start, mutate or overwrite state.
Corrupt state is preserved and prevents fallback discovery. Without saved selection
or pending context, only an existing `config.json` beside the `companion/` private
store is discovered; a missing file leaves selection empty for setup and browsing.
No launch, selection, refresh or runtime discovery starts or activates a router.

The public presentation snapshot strips private revision metadata. Its disk state,
matching readiness, `ownedRouter`, and `desktopConfirmation` are independent facts.
The controller exposes `busy`, fixed safe `error` text, guarded control properties,
`lastStopOutcome`, `needsManualListenerCleanup`, and `quitRequested`. The app should
terminate only when `requestQuit()` returns with `quitRequested` true and
`canQuit` true. Closing a
window is not a Quit request and must leave the app/controller running.

| Event | Journal/recovery outcome | Desktop confirmation |
| --- | --- | --- |
| Before activation helper | Save `activation_attempt` for the exact context | Routed pending |
| Activation succeeds, including no change | Retain `routed_confirmation` | Routed pending |
| Before rollback helper | Save `restoring` for the retained context | Direct pending |
| Rollback succeeds, including no change after possible dependency | Retain `direct_confirmation` | Direct pending |
| Helper fails or is interrupted | Re-inspect; preserve its prior intent and context | Remains pending |
| Explicit routed-response confirmation | Fresh same-context router/record/readiness plus live owned child required | User-confirmed routed |
| Explicit direct-response confirmation | Fresh same-context direct disk/record evidence; clear pending only after saving | User-confirmed direct |
| Relaunch with pending recovery | Pending context wins over normal discovery; all old listeners are unowned | Unknown |
| Relevant revision change, unexpected exit or readiness loss | Invalidate confirmation; keep conservative recovery | Pending; a later healthy poll cannot confirm |

A no-change rollback in a proven direct session with no activation attempt/imported
dependency preserves the start-only safe-stop exception after fresh reconciliation.
Any uncertainty or possible dependency retains the confirmation requirement.
Runtime replacement is allowed during recovery without changing the bound context
or owned child. Configuration selection stays locked while an owned child or
pending/imported recovery depends on it. Mapping-only edits invalidate confirmation
but cannot retarget rollback; a changed home/provider/port blocks recovery until
the recorded context is restored. The activation/rollback helper rechecks the
retained context against its own loaded configuration before creating a mutation
lock or writing provider/recovery state. Replacement contents or a retargeted
configuration symlink that changes that context fail with `ACTIVATION_CONFLICT`.
Independently readable catalogs remain available even when provider/record
compatibility fails.

Mutating actions reject conflicting re-entry. Refresh calls coalesce; every async
inspection carries both a context generation and request sequence. Older polls or
action inspections cannot replace newer evidence or authorize a confirmation.
A shared inspection gate serializes action-time checks with background refresh;
a waiting action performs its own fresh inspection after earlier work finishes.
Refresh requests coalesce instead of adding an unbounded queue.
`CompanionBackend.mutationRequiresReconciliation` is an explicit protocol
requirement. `ProcessBackend` reports its writing-child or reconciliation gate;
confirmation, stop and Quit cannot bypass it with apparently-direct disk evidence.
Only its post-exit fresh reconciliation permits later controls. The controller
never retries or terminates an uncertain helper.

After activation/imported dependency, stop requires current direct settings and an
explicit manual restart/working-direct-response confirmation. The exception is a
child started during a proven direct session with no later possible dependency.
Stop signals only the exact retained handle and awaits both exit and the backend's
independent port result. Failed exit retains ownership and blocks Quit. Verified
requested exit consumes the old readiness observation; an expected teardown poll
does not reopen completed recovery. Occupied and unknown port results remain
visible separately, and neither is reported as an empty port.

On relaunch or after an occupied-port result, no PID or readiness response grants
ownership. After direct confirmation the desktop recovery obligation can clear,
but any remaining listener needs manual cleanup. For the recorded port, inspect
`lsof -nP -iTCP:<recorded-port> -sTCP:LISTEN`, independently verify the executable
and its origin, then stop that verified listener yourself. If its origin cannot
be verified, retain it and investigate locally. The companion never adopts or
signals it. Preserve activation evidence when recovery fails; do not force a URL
replacement, remove activation locks automatically, or reset desktop settings.

Controller tests use temporary private journals, synthetic Process handles and
held inspection/helper/exit boundaries. They never read operational configuration,
retrieve credentials, contact destinations or control the real Codex desktop.

## Build and run the native app

Install the existing pinned production dependency with `npm ci` if needed, and
use an installed Node 24 plus the Swift/macOS toolchain on Apple silicon:

```sh
npm run companion:test
npm test
npm run companion:build
npm run companion:package-test
open "dist/Codex Project Router.app"
```

`companion:build` runs `swift build --package-path companion -c release --product
CodexProjectRouter` and `swift build --package-path companion -c release
--show-bin-path`, then assembles and ad-hoc signs the ignored local app. This is a
local build, without distribution notarization or an installer. Move the entire
app wherever convenient, including a path with spaces. It loads its router only
from `Contents/Resources/router`; no checkout location or selected Node path is
embedded. The explicit resource allowlist contains the router ESM manifest and
production source modules plus the installed pinned `smol-toml` manifest, `dist`
and license. Node, tests, real configuration, Git data and private state are not
bundled. Rebuild after changing router source or dependencies.

`companion:package-test` requires the already-built app and fails if it is absent.
It relocates a copy, checks metadata/arm64/signature/resources, and uses the
selected absolute real Node 24 path under a minimal GUI-like `PATH`. Its private
synthetic configuration exercises inspection, listener startup and
activation/rollback without a gateway call, credential lookup or desktop restart.
It also checks rejection of files inside a synthetic Git checkout and app bundle.
An additional macOS Seatbelt check denies checkout reads (including symlink
access), launches the relocated native executable, proves its visible window and
synthetic private-store lock, and separately exercises bundled controls under the
same confinement. It requires a logged-in GUI session, `sandbox-exec` and the Swift
toolchain. `CFFIXED_USER_HOME` isolates Foundation's native store; the test verifies
that isolation rather than assuming `HOME` is sufficient. It guards real private
configuration locations and allows outbound network access only to loopback.
Ordinary `npm test` explicitly skips the two artifact integration tests when an
app has not yet been built. Final package acceptance requires a current build and
zero skipped package tests; rebuild when executable resources change.

The controls window opens at launch; the menu-bar item reopens it after closing.
First launch discovers only an existing normal private router configuration, or
allows selecting an existing file through a native panel. Configuration and Node
selection, launch and refresh never start or activate the router. Browsing remains
available without a configuration if the normal Codex catalog is readable. Select
an installed Node 24 executable if automatic discovery fails; the GUI does not
inherit an nvm shell setup. Neither runtime nor configuration is installed or
created by the controls.

The window shows exact selected local paths, routing mode, on-disk provider state,
matching readiness, session ownership and manual desktop confirmation separately.
Provider errors do not hide a readable project catalog. Search filters local names
and aliases without changing assignments or mappings; stale mapping-only projects
and missing route targets are visibly marked. An unavailable catalog is displayed
as unavailable without presenting older rows as fresh. Inspection runs immediately,
every two seconds with controls visible and every five seconds while hidden;
manual refresh and action-time checks use the controller's coalescing and fresh
context validation.

Activation asks for provider-wide confirmation: every chat using that provider
can be affected, and unmapped/unresolved model requests can block. Restart Codex
and send a request yourself, then use the separately labeled routed or direct
response confirmation button. Health does not establish desktop-loaded settings,
gateway/key acceptance, billing attribution or stream completeness. After possible
routed use, keep the app/listener running until direct restoration and a working
direct response have been confirmed. Closing the window leaves them running.
Quit (including keyboard/application termination) always requests guarded cleanup;
it remains blocked by unresolved recovery or an owned child that cannot safely
stop. An occupied or unknown port after owned-child exit remains distinct from
matching readiness. External listeners are never adopted or signalled.

Real native launch/menu/window appearance, first-launch behavior, selection panels,
close/reopen, setup errors, catalog refresh, sizing and legibility require a manual
macOS observation after the automated package checks. Automated fixture coverage
does not claim those observations or live operational acceptance. Preserve actual
provider/router settings during a UI-only package check.

This increment has no assignment editing, project hiding, account/default-route
management, Keychain management, startup automation, bundled Node, automatic Codex
restart, automatic prompts, or improved gateway/billing attribution. Later
increments require their own scope and approval.
