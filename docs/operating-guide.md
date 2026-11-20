# Operating guide

Detailed configuration, CLI operation, recovery, compatibility, and validation.
Run commands from the repository root. For a quick introduction and companion
installation, see the [project README](../README.md).

Experimental local proxy for automatic project identification in Codex desktop. The native companion creates or imports named accounts, saves an explicit default, and starts project routing Off. For identified projects, Off uses that default account's HTTPS destination and Keychain credential; On applies saved project overrides, while projects without an override inherit the default. In companion-managed, ready schema-2 account routing, proven projectless chats, model lists and permitted unassigned automatic titles use the original Codex connection in both modes. The incoming desktop credential is verified separately. Standalone schema-1/schema-2 and managed schema-1 behavior stays unchanged.

The router relies on observed internal request headers and local desktop state. Check the [validation report](validation/desktop-project-identification-validation.md) for what has actually been tested. Passing local tests does not establish desktop-to-gateway compatibility. Live testing passed the primary chat lifecycle matrix. The [metadata validation](validation/auxiliary-request-metadata-validation.md) identified additional title-generation requests whose temporary IDs have no proven project origin. They remain blocked by default. The optional narrow title policy below allows qualifying initial-title requests without project attribution; see its [validation report](validation/unassigned-title-request-policy.md) for current evidence.

## Requirements and installation

- macOS with Node.js 24 and npm.
- A configured HTTP Responses provider using a command-backed authentication helper, with `supports_websockets = false`.
- The currently observed `.codex-global-state.json` assignment/catalog structures and `state_5.sqlite` parent-edge table. The optional title policy also requires the saved `threads.id` table/column.

```sh
npm ci
```

The standalone Node CLI needs no build step or global installation. The optional native app has the local build step below. Neither starts a background service automatically.

## Private configuration

Create a user-owned directory with mode `700` outside the checkout, normally `~/.codex-project-router`. Create `config.json` there with mode `600`, using [the schema-2 synthetic example](../examples/router.accounts.example.json) as the shape, or create/import it through the companion below. Preserve any existing private configuration.

Set `codexHome`, `providerId`, and `upstreamBaseUrl` to the existing provider setup. Preserve the complete upstream API prefix. Put desktop project IDs and non-secret route aliases in `projectRoutes`; include the controller project's ID so this chat can continue during validation. Alias values are short letters/digits/underscore/hyphen labels. They never contain keys.

New companion configurations use `schemaVersion: 2`; schema 1 remains supported by the standalone CLI. The port defaults to `8787`. The listener is fixed to `127.0.0.1`. An explicit config path is required by every command. External configuration edits require a proxy restart; the companion's guarded assignment flow below applies only assignment changes live.

Keep actual endpoints, project mappings, Keychain references, configuration backups, and private run evidence outside Git. The router rejects a configuration stored inside its checkout. It never runs the desktop authentication helper. Configuration loading, startup, health, status, activation and rollback retrieve no credentials and send no destination-preflight requests, including when credential routing is enabled. Local readiness probes remain permitted.

## Account and default setup

The companion's **Create private configuration…** selects an absent JSON file in
an explicitly private directory. **Select existing / import…** and **Preview
import…** inspect an existing file before saving. Browsing and preview never start
routing. Keep the existing compatible desktop provider and its authentication
helper; setup does not rewrite desktop authentication.

An account pairs a display name, complete HTTPS API endpoint and exact file-backed
Keychain reference. Select an existing item using its metadata, or choose **Enter
new key…** and type into the concealed native field. Advanced contains the
**Destination file-backed Keychain path**, including an explicit path outside the
search list. New items use the predetermined service/account shown there. Creation
is add-only: existing items cannot be replaced, updated or deleted by the companion.
No entered key enters command arguments, JSON configuration, control messages or
logs. File-backed Security/ACL API deprecation warnings are an intentional
compatibility cost of the fixed `/usr/bin/security` reader; they are not suppressed.
Data Protection/iCloud-only items are unsupported. Supply a canonical HTTPS
endpoint, using ASCII/punycode hostnames and the complete API prefix.

Choose the **Default account** explicitly, even for the first account. Incoming
credential confirmation in Advanced is a separate choice: it must identify the
item matching the token the desktop already sends, while the outgoing default can
use a different item and HTTPS origin. Never infer one role from the other. A
saved configuration without both roles stays incomplete and cannot Start. The
configured default label and matching readiness do not prove that Keychain access,
the gateway, the account or billing attribution works; access is checked on an
actual request.

**Add account…** preserves the current default and project assignments, including
when adding the first account to an empty file. **Choose default…** requires its
own Save action. A schema-1 import preserves every complete endpoint/reference
pair, including unused targets and explicit targets equal to the old global pair.
Legacy labels import as explicit inheritance; unresolved enabled aliases remain
missing targets. Import preserves mapping keys, optional-property absence, the
original direct URL and a private byte-exact checkpoint. The new companion requires
migration before Start; schema-1 standalone serving keeps its historical behavior.

Forms can be browsed while routing runs. Save requires safe direct recovery,
confirmation where required, no owned listener and an empty selected port. Off
alone does not authorize Save, Stop or Quit. Stop safely, save, then explicitly
Start; each new managed start loads the saved configuration in Off. There is no
running reload or pending configuration save. **Restore direct** returns to the
preserved desktop connection, which can differ from the router default. Incomplete
or invalid accounts block routing while validated original-direct recovery remains
available; unsafe core configuration or recovery records still block.

A native add can succeed before configuration linking fails. Retain the private
`account-setup.json` receipt and use **Check operation outcome**; do not recreate
or automatically delete the item. Exact metadata and saved state reconcile the
predetermined identity without retrieving its secret. An uncertain helper keeps
writes and dismissal blocked until it exits and its result is checked. Existing
or stale `.activation.lock` evidence is never adopted, signalled or removed
automatically; independently inspect its origin and resolve it locally, preserving
receipts/checkpoints and recovery evidence. Account editing/deletion remains
deferred. See the [account setup validation record](validation/companion-account-default-setup.md)
for its completed local acceptance, bounded native/live observations and remaining
evidence limits.

## Original connection and projectless chats

This behavior applies only to companion-managed, ready `schemaVersion: 2` account
routing. Standalone schema-1/schema-2 and managed schema-1 retain their historical
routing semantics. Existing configurations need no migration or new option.

| Request | Project routing On | Project routing Off |
| --- | --- | --- |
| Identified project with an override | Selected complete account pair | Explicit default account pair |
| Identified project without an override | Explicit default account pair | Explicit default account pair |
| Positively proven projectless response or compaction | Original Codex connection | Original Codex connection |
| Model list, across all chats | Original Codex connection | Original Codex connection |
| Already-eligible unassigned automatic title, across all chats | Original Codex connection | Original Codex connection |

The original connection is the preserved top-level `upstreamBaseUrl`, with its full
API prefix, paired with the exact accepted incoming Authorization value after
incoming authentication. It is independent of the companion default, which can
use another destination and outgoing credential. Original paths read no outgoing
default/project key; project paths retain the complete selected URL/key pair even
when that URL equals the original. Authentication, missing-target, credential and
upstream failures remain failures. Neither path falls back to another account,
retries a model request, follows a redirect, or translates bodies, models or
continuations.

Projectless membership requires a positive supported saved marker and validation
of the complete relevant saved ancestry/session relationship. No project assignment,
unknown identity, an unsupported parent hint, or a title marker alone grants this
authority. Conflicting project/projectless evidence blocks. A fresh chat's first
message must satisfy the same proof; if that evidence is not yet available, the
request blocks. The first bounded live run observed a positively proven fresh
projectless first reply. A corrected run also observed reopened Off→On→Off
projectless replies on one retained listener. Both runs ended with verified Direct
recovery. The [current acceptance record](validation/projectless-chat-compatibility.md)
retains both runs, cancelled control transports, the initial fixture failure and
exact restoration evidence separately. A separate user-authorized continuation
now directly proves guarded routed-response confirmation and verifies exact
restoration of all three retained contexts. The historical MISSING finding is
retained; fresh sequential specification and quality reviews passed with no findings.
Synthetic evidence cannot substitute for required live checks. No new desktop-state
source or unresolved-request fallback is introduced.

The separate `allowUnassignedThreadTitles` option stays off by default. Its strict
metadata matching and fresh absence proof still apply. Ordinary proven project or
projectless membership takes priority over the title exception. Changing the shared
model-list/title destination applies across all chats using this managed provider;
it does not make other auxiliary request families eligible.

Configuration and routing mode are captured together at HTTP request receipt,
before asynchronous authentication. Membership resolves freshly afterward; this is
not a receipt-time membership promise or an atomic multi-file snapshot. Once a
request selects a destination, its stream retains that selection. A later coherent
move into or out of a project affects the next request; conflicting transition
state blocks. Continuing a chat across upstream accounts retains gateway-specific
limitations.

For a safe update/restart of an existing installation:

1. Retain private checkpoints for the selected/normal configuration, provider,
   recovery context and original option presence. Use **Restore direct** for the
   retained context, preserving unrelated edits.
2. Manually restart Codex, receive and confirm a working direct response, then use
   guarded **Stop** / **Quit**. Verify the exact owned app/router exited and its
   listener is absent before replacing the bundle. Do not adopt or stop an external
   listener.
3. Build the current app, relaunch it, and explicitly **Start router (routing Off)**.
   Initial/repeated provider integration still requires activation, manual Codex
   restart and a separately confirmed routed response. Keep recovery available.
4. Use ordinary On/Off or guarded assignment changes without routine restarts.
   Account/default saves retain their safe Direct/stopped boundary. Other external
   configuration or bundled-code changes require the safe restart sequence; no
   general reload is added.

After a validation failure as well as success, restore the exact prior private
settings and optional-property presence while preserving unrelated edits, Restore
direct, manually restart and confirm a working direct response before guarded
owned Stop/Quit. Retain recovery evidence outside Git. If a new projectless first
message cannot satisfy supported proof, report compatibility incomplete and return
to scope/design; do not broaden identity authority to complete a run.

## Project assignment editing

Open one project and choose an existing named account, or **Use default** to remove
that project's exact override. Selecting the current default account by name keeps
an explicit override. Imported legacy inheritance stays inherited until explicitly
changed. A missing target stays an error until you select an account or Use default;
opening the editor never converts it silently. Projects found only in saved
configuration show a warning and remain editable by their exact saved identity
when discovery is otherwise healthy. There is no manual ID entry or bulk editor.
Incomplete setup shows account-setup guidance and keeps assignment Save unavailable
without a false saved/running conflict. The main controls present setup actions and
an incomplete-setup warning before Start until setup is ready.

Editing requires a valid, ready schema-2 setup and fresh matching project/catalog
and configuration evidence. With the exact owned supported router and functioning
control channel, **Save and apply** persists and publishes the assignment without
an ordinary Codex restart, preserving On/Off. With safe Direct state, no owned
listener, an independently empty selected port and resolved recovery, **Save**
persists for the next explicit **Start router (routing Off)**. Off by itself does
not authorize a stopped save. Account/default changes retain their separate safe
Direct/stopped boundary; this is no account, credential, default or provider reload.

Saved and running summaries are separate. On applies overrides; Off suspends them
and uses the running default. A saved choice or On alone cannot prove that a
particular assignment is running. Unconfirmed control reads say **Running assignment
unconfirmed**. An external listener or unavailable/unsupported channel permits
browsing but blocks writes. Unsaved choices remain local to the editor; explicit
**Refresh** reloads its baseline. Background refresh does not silently rebase an
old selection. Save leaves the editor open so the result can be inspected.

A rejected save leaves the selection available for inspection. An ambiguous result
may have persisted: do not repeat it, assume rollback, or issue a second command
to finish applying. Refresh observes the exact operation's saved/running evidence;
unresolved or divergent evidence keeps assignment writes blocked. Closing the
editor does not cancel or repeat an accepted save. Direct recovery remains
available subject to its own checks: **Restore direct**, manually restart Codex,
confirm a working direct response, then guarded Stop. No process or stale lock is
adopted automatically. A provider rewrite with identical content can still change
recovery metadata and conservatively reopen Direct confirmation. Follow the renewed
confirmation guidance before Stop/Quit; a healthy poll alone does not confirm it.

Each request captures its immutable configured assignment and mode at receipt,
before authentication or other asynchronous lookup. Later changes affect later
requests; existing requests retain their selection. No model retry, alternate
account fallback or redirect is added. Shared bindings are never retargeted or
garbage-collected; unrelated settings and optional-property presence are preserved.
The shared lock and fresh source checks coordinate participating writers, but
cannot provide atomic compare-and-swap against external editors that ignore the
lock. Avoid concurrent external edits. Keep comparison tokens, actual mappings,
references, checkpoints and raw evidence private; they are not UI diagnostics.

See the [assignment validation record](validation/companion-project-assignment-editing.md)
for automated evidence, bounded native/live observations, exact recovery/cleanup
and the completed final whole-branch gate and scoped follow-up. Readiness and
configured account labels do not establish credential access, gateway acceptance,
billing attribution or
general cross-account continuation.

## Project list organization

In account mode, the list uses **Needs attention**, **Custom account**, **Default
account**, then **No active chats (N)**, omitting empty sections. Custom account
means **Accounts selected for individual projects.** Selecting today's default
by name remains an explicit custom assignment even after the default changes.
Inherited and legacy-inherited projects say **Uses default**; the saved default is
identified once for the section. Missing bindings never silently become inherited.
An unclassifiable saved policy takes precedence over inactive placement. Off
suspends overrides for requests while preserving saved assignments and groups.
Legacy/no-configuration browsing retains its flat list.

Here “active” means **unarchived**, including a chat with no user-event flag; it
says nothing about recency, a running request or a response in progress. **No active
chats (N)** means **Projects with no chats or only archived chats.** The section
starts collapsed. Every project remains reachable through expansion or search.
Missing chat records, incompatible metadata and conflicting identities instead
show neutral **Chat status unknown** in the known account group, with the reason
in Details. Permanently deleting a chat can leave its global membership behind:
that project remains visible with unknown status until supported complete evidence
permits reclassification. Do not edit Codex metadata to make it collapse.

Rows show a wrapping project name, saved account or Uses default, **Edit** and
**Details**. Details holds IDs, route aliases, provenance, matching saved/running
information and chat-state reasons. Missing targets, discovery problems, meaningful
saved/running differences and assignment-operation uncertainty remain visible.
Collapsed inactive projects with actionable problems retain named previews and
Edit/Details; expansion replaces previews with full rows. Previews never increase
counts. Unknown chat state alone is informational. Shared Off/stopped/unconfirmed
or differing-default notices remain available even with no search matches.
Account names and running confirmation do not prove credential access, gateway
acceptance, billing attribution or a successful routed response.

Search trims whitespace and ignores case across project names, stable IDs, route
aliases and applicable saved account names (including the default for inherited
projects). It searches collapsed entries, temporarily reveals matching inactive
rows, omits empty sections and reports **matches of total**. The temporarily open
inactive toggle is disabled during search; **Clear search** restores the previous
collapse choice. A summary warns when actionable projects are filtered out.
Empty discovery, unavailable discovery and no matches are separate states. Query
and Details choices survive refresh; Details is keyed by stable project identity.

Opening Edit pins that row's current placement until the sheet closes, with
**List position updates when editing closes.** when its destination changes.
Fresh policy, activity and warnings still update. Background refresh and saving
do not rebase the draft or dismiss the editor; current authority and stale-save
checks still apply. A repaired collapsed preview remains visible while editing,
then follows its latest placement after dismissal. Browsing grants no write or
routing authority. Refresh remains immediate/manual plus every two seconds while
controls are visible and five seconds while hidden.

Negative chat classification supports the initial local legacy-membership profile:
UUID-keyed `local-projects` and matching record IDs; direct
`thread-project-assignments` values `{projectKind:"local",projectId:<UUID>}`;
local membership hosts, projectless UUIDs and a one-to-one legacy/canonical bridge.
The signed-out `electron-owner-value:app-server-projects-migration-by-host:signed-out`
checkpoint under `local:<codexHome>` must have `version:1`,
`projectsMigrated:true`, `threadAssignmentsMigrated:false`, a valid unique
`pendingThreadAssignmentIds` UUID array and no `threadAssignmentsReadMigrated`.
Other owner checkpoints for this home must use that supported profile and agree
on the normalized pending-ID set. SQLite must provide `threads.id`, `archived`
(exactly 0/1), `source`, `thread_source`, `project_id`,
`attached_thread_parent_id`, spawn edges and `backfill_state.status = "complete"`.
Index health alone never proves completeness. Ordinary eligible roots have
`source = "vscode"`, `thread_source = "user"` or `"agent_created_thread"`, no
attached parent and no incoming spawn edge. Internal guardians require parsed
`source.subagent.other = "guardian"`, `thread_source = "guardian_review"` and no
parent evidence. Spawned internals require parsed
`source.subagent.thread_spawn.parent_thread_id`, `thread_source = "subagent"`
and a matching saved incoming edge (including completed edges); an attached parent,
if present, must agree. They are not counted independently through ancestor
membership. Non-null canonical `project_id`, newer/migrated profiles, unsupported
sources and contradictions yield unknown for the affected scope; unlocalizable
problems suppress negative classification for the refresh. Names, paths,
timestamps and `has_user_event` never supply membership authority.

The observer uses read-only WAL-aware SQLite and compares relevant projections
around JSON reads, retrying once within a 250 ms retry budget. It reads no
transcripts and repairs/migrates nothing. Settled archive/unarchive/move changes
converge on a successful refresh; JSON and SQLite are not one atomic transaction.
Global JSON, main database, committed WAL, router configuration and provider
settings remain unchanged by observation. SQLite may create or update its SHM
coordination sidecar, so an unchanged directory is not promised. Activity changes
do not change catalog identity/name revisions. Running-list observation reads all
catalog IDs in pages of at most eight, under one aggregate one-second deadline,
from the exact owned supported child; failure remains unconfirmed. Existing
five-second operation limits, 16 KiB frames and 32 KiB buffers remain in place.

The [project-list validation record](validation/project-list-organization.md)
separates synthetic automation, hosted native images/interactions, packaged
source-denial checks and the earlier user-operated discovery experiment. New live
production acceptance remains unobserved. Manual hiding, another membership
backend and later UI/startup/distribution work remain deferred.

## Schema-1 project credential routing compatibility

Omit `credentialRouting` to retain legacy behavior and its readiness fingerprint with zero Keychain calls. Its presence enables routing under the existing `schemaVersion: 1`; `false`, `null`, incomplete objects and unknown fields are invalid. Use the separate [synthetic enabled example](../examples/router.credentials.example.json); the [legacy example](../examples/router.example.json) remains available.

The enabled object contains exactly `globalCredential` and `routeTargets`. `globalCredential` is a Keychain reference. `routeTargets` maps each alias to an object containing exactly `upstreamBaseUrl` and `credential`. Each `credential` reference contains exactly `keychainPath`, `service` and `account`: nonempty strings of at most 1,024 characters without control characters. Use an absolute keychain path; `~` and environment expressions are not expanded. `projectRoutes` maps each project ID to an alias. Include complete targets for A, B and the controller before validation. Several projects or aliases may deliberately share a destination, item or whole target. Unused valid entries and an empty target map are allowed. In managed On mode, an identified project with no saved alias inherits the global pair; a saved alias without a complete target blocks when selected. Standalone `serve` keeps its existing mapped-project requirement. A supplied malformed or incomplete target invalidates configuration in every mode, including Off.

Bind every credential to the gateway instance that issued and accepts it. Each destination must be an absolute HTTPS URL without user information, query or fragment. Preserve its full API prefix: a target ending `/region/v1` receives `/region/v1/responses` or `/region/v1/responses/compact`, with the original query. The top-level `upstreamBaseUrl` remains the global destination for catalog and qualifying unassigned-title requests. The controller is an ordinary mapped project: explicitly configure its target to use the global destination and global item if that is the intended pair. There is no controller bypass or automatic instance discovery.

To migrate the earlier unmerged `routeCredentials` format, restore direct operation and stop the old listener, then manually replace each alias's reference with a complete `routeTargets` pair. Remove `routeCredentials`; the old format is rejected even alongside `routeTargets`. Existing Keychain items need no recreation or rotation. Restart the proxy and check readiness before activation. Control commands require valid configuration, so migrate an obsolete enabled object or omit `credentialRouting` before using them.

### Provision items manually in Keychain Access

1. Privately checkpoint the direct provider URL and the exact prior router settings, including which optional properties were absent. Keep the existing desktop authentication command in place.
2. Open macOS **Keychain Access**, select the intended keychain, and use **File → New Password Item** to create a generic password item. Set **Keychain Item Name** to the configured `service`, **Account Name** to `account`, and enter the key in the password field locally. Do not paste keys into this chat, terminal commands, files in the checkout, or reports.
3. Provision a global item holding the exact token supplied by the desktop authentication helper. Provision separate A/B items holding distinct project API keys, and explicitly configure the controller target to reuse the global item and global destination when intended. Example names such as `example-global-service` / `example-global-account` and `example-project-a-service` / `example-project-a-account` are synthetic labels. Actual values and paths stay in private configuration.
4. Verify each selected item's service/account and its containing keychain locally. Copy only those references into private router configuration, using the full absolute keychain path, for example the synthetic `/Users/example/Library/Keychains/login.keychain-db`. Avoid ambiguous duplicate items. The standalone reader reads only the exact referenced generic password; the companion adds new items only through the separate setup flow. Neither edits, deletes or explicitly unlocks existing items. Keychain access policy may require user interaction; a denied or locked item can make lookup fail.
5. Restart the foreground proxy after changing mappings, destinations or references, check `status`, then use the activation procedure below. Matching readiness confirms configuration/listener agreement; it does not preflight Keychain access, destination connectivity or gateway acceptance.

When credential routing is configured, each admitted non-health request retrieves the global item and verifies the incoming bearer token before metadata observation, identity resolution or project-key retrieval. The scheme is case-insensitive; the token is exact and case-sensitive. When project overrides apply, mapped model requests then retrieve their target credential and forward to that target's destination with replaced `Authorization` and its matching `Host`. Deliberate controller reuse of the global item still performs separate verification and target reads. Catalog requests and qualifying unassigned titles use the global destination, retain the exact verified caller authorization and retrieve no project key. When overrides apply, mapped title-marked requests retain ordinary target priority. The title and observation options are independent and remain off unless explicitly enabled.

| Failure | Result |
|---|---|
| Incoming token differs from the retrieved global token | `AUTH_INVALID` (401) |
| Selected saved override has no complete target | `CREDENTIAL_UNMAPPED` (422) |
| Required item is absent, inaccessible, times out, or returns invalid output | `CREDENTIAL_UNAVAILABLE` (503) |

Global-item failure blocks authenticated requests. Project-item failure affects requests needing that key; unrelated healthy projects can continue. Failures never select another credential or destination, fall back to the global pair, retry the model request, or follow redirects. A managed request captures On/Off at HTTP receipt, before its first asynchronous lookup, then fixes its resolved project, destination and credential before forwarding. Switching mode affects later requests; active streams keep their original selection and are never retried or migrated. Desktop project reassignment affects subsequent identity lookups. Companion assignment saves publish a new configured snapshot for later requests; external configuration edits require a proxy restart. Cross-credential or cross-instance continuation failures from the gateway remain failures; the router does not rewrite models, payloads or continuation IDs to repair them. Use fresh validation chats when switching gateway instances.

Each Keychain lookup runs fixed `/usr/bin/security find-generic-password` without a shell, using explicit account, service and keychain path. It has a five-second timeout and separate 16 KiB stdout/stderr limits. The child is terminated and reaped on timeout, overflow or cancellation. A token must contain 1–8,192 visible ASCII bytes after removing at most one final LF; spaces, other whitespace, control characters and non-ASCII bytes are rejected. Failed process outcomes reject even plausible output. Subprocess output is never included in router diagnostics or errors.

Credentials are read per request with no cross-request cache, coalescing, stale fallback or automatic lookup retry. To rotate a project key, the user updates the selected item in Keychain Access; later requests read the new value without a proxy restart. Global rotation also requires the desktop authentication helper/token to agree with the new value; refresh or restart the desktop as its provider requires. Stale incoming tokens fail. Separate global/project reads are not atomic. Rotation alone does not change readiness; reference, mapping or destination changes require a proxy restart and change readiness. Reordering entries or equivalent normalized URLs does not change readiness.

The listener stays on loopback, but possession of the global token does not prove a local caller is a particular chat. Existing identity and title-marker trust limits still apply. Keys exist in ordinary JavaScript request memory; secure erasure is not promised. Diagnostics exclude credential values, hashes, prefixes, Keychain references, actual destination URLs and subprocess output. Upstream content remains opaque. Local credential-selection and transport evidence does not independently prove gateway account or billing attribution.

## Run, activate, inspect, restore

Start the foreground proxy in a terminal:

```sh
node --use-system-ca src/cli.js serve --config "$HOME/.codex-project-router/config.json"
```

For desktop restart tests, use a separate macOS Terminal window and keep it open until rollback is complete.

This enables normal certificate verification with the system CA store. There is no insecure TLS mode. Startup prints the loopback listener; per-request diagnostics go to stderr.

In another terminal, inspect configuration and readiness:

```sh
node src/cli.js status --config "$HOME/.codex-project-router/config.json"
```

Status describes on-disk configuration and matching proxy readiness. It cannot establish which settings an already-running desktop process has loaded.

Activate explicitly:

```sh
node src/cli.js activate --config "$HOME/.codex-project-router/config.json"
```

Activation checks provider compatibility and a matching local health fingerprint, saves an exclusive private backup, and replaces only the supported provider's base-URL value. It preserves the existing authentication command, models, comments, and unrelated configuration. Supported editing is deliberately limited to a simple `[model_providers.PROVIDER_ID]` table with a single-line double-quoted `base_url`; ambiguous forms are rejected.

Restart the desktop app when the command reports `restartRequired`. The helper never restarts it. The provider setting affects every chat using that provider. In standalone schema-1 serving, model requests without a resolvable, explicitly mapped project block, except qualifying initial titles when their separate policy is enabled. Companion-managed schema-2 account routing follows the original/default policy above. Arrange validation while other work is idle.

Restore direct access before stopping the proxy:

```sh
node src/cli.js rollback --config "$HOME/.codex-project-router/config.json"
```

Restart the app when required, verify a direct gateway response, then stop the foreground proxy with Ctrl-C. Rollback works when the proxy is unavailable and preserves unrelated edits made after activation. An unexpected change to the owned base URL produces a conflict for inspection.

For a credential-routing validation run, restore the exact prior private router settings as well, including removal of properties that were originally absent; preserve unrelated edits. Keychain availability is unnecessary for rollback, and existing activation records require no migration. After rollback and any required restart, obtain a user-confirmed direct response before stopping the proxy. Confirm that its loopback port has no listener, for example with `lsof -nP -iTCP:8787 -sTCP:LISTEN` for the example port (no matching rows is the expected result). Complete recovery even if validation failed.

### Manual recovery

Private `activation.json` records the original base URL and identifies a `codex-config-UUID.toml` backup beside it. These files can contain private configuration and must remain local. If the helper cannot run, inspect them locally and restore just the original provider's `base_url` in Codex's `config.toml`. Preserve other current settings, restart the app, and verify a direct response.

A `.activation.lock` guards helper writes. A remaining lock after process termination produces a conflict. Inspect its recorded PID and confirm that helper has stopped before removing the stale lock. For a `prepared` activation record, `rollback` safely handles either the original or proxy base URL. Malformed records, missing/modified backups, and unexpected owned values require manual inspection.

The helper checks the current file before replacement. Avoid editing Codex configuration concurrently with helper commands; external editors do not participate in its lock.

## Identification and HTTP behavior

For model execution, the router validates `thread-id`, `session-id`, and the identity fields in `x-codex-turn-metadata`. It reads explicit local project assignments, following saved subagent parent edges when necessary. Completed parent-edge records remain relevant. Distinct current/session identities require proven ancestry; parent hints alone are insufficient.

It re-reads desktop state per request and fixes the chosen assignment for that request. Transient lookup failures get a one-second window with 50 ms retries. Ancestry is limited to 32 nodes. Companion-managed, ready schema-2 account routing accepts positively proven projectless identity as described above; conflicting and unsupported identities remain blocked. Outside that scope, projectless requests retain their historical rejection. The separate explicitly enabled narrow initial-title policy below remains available. Standalone schema-1 serving requires an explicit project mapping and has no default Global route. Managed routing uses the configured default for identified projects without an override and project requests while Off; inheritance never resolves an unknown or ambiguous identity. There is no working-directory inference, foreground-window inference, or prompt inspection.

Allowed local operations:

| Operation | Behavior |
|---|---|
| `GET /healthz` | Local readiness; no authentication, credential lookup or upstream request |
| `GET /v1/models` | Provider-wide catalog; bearer authentication required, chat identity optional |
| `POST /v1/responses` | Bearer authentication and resolved project required, or positively proven projectless identity in scoped managed account mode; optional narrow initial-title exception below |
| `POST /v1/responses/compact` | Same identity and authentication requirements |

Other routes, methods, and WebSocket upgrades are rejected. Allowed queries retain their original content. Forwarding preserves body bytes, model names, and streaming status/content. Authorization follows the selected mode: accepted incoming authorization on scoped original-connection paths, unchanged caller authorization in legacy mode, or the verified global/selected account credential as described above. Hop-by-hop headers are removed while the intended routed authorization is retained, client disconnects cancel pending lookups and upstream work, and upstream inactivity is limited to five minutes. The router introduces no model-request retries and follows no redirects.

Diagnostics contain only fixed event/error codes, timestamps, correlation IDs, required chat/project IDs, aliases, resolution source, fixed operation labels, status, and timing. Prompts, responses, credentials, whole headers, raw metadata, raw desktop state, and exception text are excluded, including failure paths.

## Optional unassigned initial-title policy

Set `allowUnassignedThreadTitles` to `true` in private configuration to permit the observed initial-title pattern through `POST /v1/responses`. This strict boolean defaults to `false` in both configuration schemas. Restart the foreground proxy after changing it. Readiness distinguishes both policy and observation modes; rollback remains usable after mode changes and with the proxy offline. Existing activation records need no migration.

Ordinary project resolution and scoped proven projectless resolution always win. The exception requires exactly one valid metadata object with singleton `thread_source` and `turn_trigger` strings both equal to `thread_title`. Header `thread-id`/`session-id` and metadata `thread_id`/`session_id` must all contain the same valid UUID. Header `x-codex-parent-thread-id` and metadata parent/fork-source members must be absent, including no null or empty occurrences. Duplicate allowlisted metadata members, including escaped key spellings, disqualify the exception. `request_kind` values do not authorize it.

Fresh healthy JSON and read-only SQLite checks must prove that the temporary ID has no assignment entry, projectless marker, saved thread, or incoming/outgoing spawn edge. Malformed state, missing schema, detected file/database changes, failed final checks and cancellation cannot grant the exception. Transient failures share the existing one-second lookup budget and 50 ms retry cadence. The checks use current readable snapshots, not an atomic transaction across both state files. No prior absence is cached for later attempts or requests.

In scoped managed schema-2 account mode, accepted titles use the preserved original upstream and exact accepted incoming authorization after separate incoming verification, without reading an outgoing account item. Schema-1 titles use the top-level global upstream and caller credential unchanged; credential-routing mode first verifies the global Keychain item. Standalone schema-2 retains its historical default-account selection and outgoing credential substitution. Their diagnostics use `source: unassigned_title` with no project, owner or route alias. They have no project cost attribution. Client-supplied markers can be imitated by a local caller with an accepted credential; enabling this option accepts that limitation. The router does not inspect the body to prove that it generates a title.

This policy works independently of `observeRequestMetadata` and enables no additional metadata logging. The title policy does not admit compaction, title reconsideration, other auxiliary families, known projectless/unmapped identities or other unresolved requests. Independently proven projectless requests can use scoped managed original routing as described above. There is no general unresolved-request fallback. Mapped requests retain priority and use their configured destination/credential pair when routing is enabled.

For a controlled run, checkpoint each flag's prior presence/value and the direct provider URL privately before enabling it. Use the existing activation and rollback commands. Restore the prior flags while preserving unrelated edits, restart the desktop when required, verify a direct response, then stop the foreground proxy. Keep backups and run evidence outside Git.

## Optional request metadata observation

Set `observeRequestMetadata` to `true` in the private configuration to investigate auxiliary desktop requests. The option is a strict boolean and defaults to `false` under the existing `schemaVersion: 1`. Restart the foreground proxy after changing it. Readiness distinguishes the two modes; a running proxy with the other mode is not ready for activation. Existing activation records remain usable, and rollback works with a changed observation setting or an unavailable proxy.

When enabled, eligible model-request diagnostics include `requestMetadata` after route/authentication admission and, in credential-routing mode, global-token verification, before identity resolution. This includes subsequent identity failures. Early admission or global-verification failures, health, and catalog requests receive no observations. When disabled, the additional property is absent.

Only these inputs are observed:

| Input | Fields |
|---|---|
| Top-level `x-codex-turn-metadata` members | `thread_source`, `turn_trigger`, `request_kind`, `thread_id`, `session_id`, `parent_thread_id`, `forked_from_thread_id` |
| Individual headers | `thread-id`, `session-id`, `x-codex-parent-thread-id` |

Feature values are classified as `user`, `desktop_app`, `thread_title`, `thread_title_reconsideration`, `thread_description`, `thread_summary`, `compact`, `compaction`, or `subagent`. Every other string becomes `other`; its original value is never emitted, truncated, or hashed. Only syntactically valid UUID claims are emitted, normalized to lowercase and kept under their original field.

The observation has `state` (`collected` or `unavailable`), `turnMetadata` with its container state/type and fixed `fields`, and a fixed `headers` object. Each field records `state`, `type`, and `conflict`, plus a validated `label` or `id` when valid. Field states distinguish `absent`, `valid`, `invalid`, `duplicate`, `unsupported`, and `unavailable`. Types distinguish string, number, boolean, null, array, object, absent, and unknown. The metadata container also distinguishes malformed JSON. Duplicate members, including escaped key spellings, emit no winning value. Nested structures are unsupported; unknown keys are excluded.

`conflict` compares only corresponding valid header/metadata claims for thread, session, or parent: `none`, `different`, or `unassessed`. Distinct thread/session or parent/fork roles are not compared. A claimed parent or fork source does not establish project membership. Observation failures produce fixed unavailable states; they introduce no admission error and confer no routing authority. Existing identity validation still decides whether a request can proceed.

These observations use the existing diagnostic stream and correlation IDs. Keep diagnostic files private; they contain permitted chat UUIDs. All other privacy exclusions still apply. Observation does not switch credentials, allow unresolved requests, or resolve auxiliary requests from timing or feature labels.

For a controlled run, establish a direct baseline, enable observation, start/activate the proxy, restart the desktop when required, and exercise fresh chats in both disposable projects plus a follow-up. Restore direct configuration and the previous observation setting, restart as required, verify a direct response, and stop the proxy. Preserve whether the option was originally absent. Keep checkpoints and actual IDs outside Git, and publish only symbolic labels in a report. See the [auxiliary metadata validation report](validation/auxiliary-request-metadata-validation.md) for observed evidence and limitations.

## Desktop validation procedure

Use disposable projects named Router Validation A and Router Validation B with separate scratch folders. Add their IDs and the controller project's ID to private configuration. For credential routing, provision distinct A/B keys and the global key, bind each to its intended gateway instance and full prefix, and configure an explicit controller target as described above. Use fresh chats for a different instance. Explicitly enable the separate `allowUnassignedThreadTitles` policy to exercise qualifying unassigned automatic titles. Checkpoint exact prior settings and the direct URL privately before any changes. Keep folder-access changes confined to these scratch projects.

1. Establish a direct-response baseline using disposable chats with minimal prompts, for example `Reply ROUTER_A only; do not use tools or read or modify files.`
2. Start the proxy in a separate Terminal window, inspect `status`, activate it, restart the app, and verify the controller chat remains usable.
3. Send first requests in new chats in both projects and verify their automatic titles. Send two modest requests close enough together to produce overlapping `started`/`completed` intervals. Record symbolic aliases, resolution sources, outcomes and sanitized intervals, without copying prompt/response content. Diagnostic timestamp intervals begin after lookup/selection; `elapsedMs` includes preceding lookup work. These demonstrate local selection/transport, not independent gateway account or billing attribution.
4. Exercise follow-up and resumed chats, then fork a test chat and send a follow-up. Move a disposable chat to the other disposable project, accepting scratch-folder access only, and verify its next request resolves to the new project.
5. In an idle test chat, select `/compact` from the desktop composer and observe the resulting request.
6. In a test chat, explicitly request one read-only subagent to return a short marker without reading/changing files. Verify saved-parent attribution in the router diagnostics.
7. Use `rollback` and restore exact prior private settings, preserving unrelated edits and whether optional properties were absent. Restart the app when required, obtain a user-confirmed direct response, stop the proxy, and verify no listener remains on its configured port.

Desktop project/chat creation, sending prompts, moving/forking chats, and restarts require user interaction unless separately authorized. The router does not create or message chats.

Record each case as an observed pass, observed failure, or not run. Credential-routing validation requires A/B responses and automatic titles, overlap, same-chat follow-up, reassignment and the subsequent request, plus exact recovery and direct-response confirmation. Exercise fork, saved subagent and compaction cases opportunistically and explicitly record any unrun cases. Missing required user actions or evidence leaves live validation incomplete. Observed incompatibilities remain failed capabilities. Earlier identification/title validation and passing synthetic tests do not establish live credential-routing compatibility.

## Native menu-bar companion (macOS)

The local Apple silicon app puts project-routing On/Off and searchable project
overrides first, with setup, provider activation and recovery in disclosures. It
requires macOS 14 or newer and an installed Node 24; configuration stays private in place. The app
never starts routing on launch or selection. Closing controls leaves the app and
owned listener running; Quit uses guarded direct recovery.

```sh
npm run companion:test
npm run companion:build
npm run companion:package-test
open "dist/Codex Project Router.app"
```

Choose **Start router (routing Off)** explicitly. Initial integration changes the
selected provider to the stable loopback URL once: activate, restart Codex yourself,
receive a working response and confirm it independently in the app. Once integrated,
use **Turn project routing On** / **Turn project routing Off** for everyday changes
without restarting Codex or rewriting its provider URL. Off keeps saved overrides
and sends identified project requests through the explicitly saved default account.
In ready schema-2 managed account mode, proven projectless requests, model lists and
permitted unassigned automatic titles instead preserve the original connection in
both modes. Incoming authorization must match the separately configured incoming
item; only project/default paths read and substitute the selected outgoing token.
Off makes no project override-item lookup. The top-level `upstreamBaseUrl` is the
original destination for scoped original routing and Direct recovery. Existing
schema-1 files require an explicit import before companion Start; their standalone semantics remain unchanged.
Identity and admission failures still block; inheritance does not resolve ambiguity.

The app can move independently of this checkout and uses only its bundled router
resources plus an installed absolute Node path. A failed or uncertain mode change
shows Uncertain or Unavailable until a fresh read can reconcile it; controls do
not retry a mutation.
Matching readiness, process ownership, routing mode and desktop-response
confirmation are separate facts. Mode changes do not satisfy restart/response
obligations from provider changes. **Restore direct** is a separate recovery flow:
restore the bound provider settings, restart Codex, verify and confirm a direct
response, then stop the owned listener when permitted. Off still needs the listener.
An external listener is never adopted or stopped. No last-used On state, automatic
startup, fallback, automatic restart or account editing/deletion is provided.
Named-account addition, explicit default selection and guarded project assignment editing are available as described above.

See [companion setup, lifecycle, packaging and recovery](../companion/README.md) for
custom activation contexts and recovery details. The [managed-routing validation
record](validation/companion-routing-on-off.md) records completed local acceptance
and final review, qualified native/live observations and accepted viewport/Tab
limitations. The separate [projectless acceptance record](validation/projectless-chat-compatibility.md)
records bounded native/live observations, the separately proven guarded
routed-response confirmation and exact recovery. The earlier specification MISSING
result remains historical; fresh sequential specification and quality reviews
passed with no findings. Local delivery of this increment is complete.
Historical validation reports retain their original scope and limitations.

## Development checks

Run the final native → build → Node → package sequence in this order so package
checks compare the current signed resources. On a host prone to idle sleep, use
process-scoped `caffeinate -i` around each command.

```sh
npm run companion:test
npm run companion:build
npm test
npm run companion:package-test
node --check src/cli.js
git diff --check
```

Tests use temporary synthetic desktop state and local HTTPS upstreams with distinct global/project origins and API prefixes. The committed TLS key/certificate are public, test-only fixtures for localhost. Production uses normal upstream certificate verification. Tests never contact ICA or retrieve real credentials. Package tests additionally create
a positively owned disposable Keychain with a public synthetic fixture, exercise the
production native metadata/create boundary and bundled reader, then validate cleanup.
No existing user item is queried, read, updated or deleted; the harness removes only
its own entry from the current search list and never changes the default Keychain.

Scope and approval history are recorded in the initial [specification](superpowers/specs/2026-11-10-desktop-project-identification-validation.md) and [implementation plan](superpowers/plans/2026-11-10-desktop-project-identification-validation.md), the metadata increment's [specification](superpowers/specs/2026-11-10-auxiliary-request-metadata-validation.md) and [implementation plan](superpowers/plans/2026-11-10-auxiliary-request-metadata-validation.md), the title policy's [specification](superpowers/specs/2026-11-10-unassigned-title-request-policy.md) and [implementation plan](superpowers/plans/2026-11-10-unassigned-title-request-policy.md), credential routing's [specification](superpowers/specs/2026-11-11-project-credential-routing.md) and [implementation plan](superpowers/plans/2026-11-11-project-credential-routing.md), and managed routing's [specification](superpowers/specs/2026-11-12-companion-routing-on-off.md) and [implementation plan](superpowers/plans/2026-11-12-companion-routing-on-off.md).
