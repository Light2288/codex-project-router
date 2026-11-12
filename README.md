# Codex Project Router

Experimental local proxy for automatic project identification in Codex desktop. With optional credential routing enabled, mapped Responses and compaction requests use the project's explicitly configured HTTPS destination and Keychain credential. Without it, admitted requests retain the caller's existing credential.

The router relies on observed internal request headers and local desktop state. Check the [validation report](docs/validation/desktop-project-identification-validation.md) for what has actually been tested. Passing local tests does not establish desktop-to-gateway compatibility. Live testing passed the primary chat lifecycle matrix. The [metadata validation](docs/validation/auxiliary-request-metadata-validation.md) identified additional title-generation requests whose temporary IDs have no proven project origin. They remain blocked by default. The optional narrow title policy below allows qualifying initial-title requests without project attribution; see its [validation report](docs/validation/unassigned-title-request-policy.md) for current evidence.

## Requirements and installation

- macOS with Node.js 24 and npm.
- A configured HTTP Responses provider using a command-backed authentication helper, with `supports_websockets = false`.
- The currently observed `.codex-global-state.json` assignment/catalog structures and `state_5.sqlite` parent-edge table. The optional title policy also requires the saved `threads.id` table/column.

```sh
npm ci
```

There is no build step, global installation, background service, or automatic configuration editing.

## Private configuration

Create a user-owned directory with mode `700` outside the checkout, normally `~/.codex-project-router`. Create `config.json` there with mode `600`, using [the synthetic example](examples/router.example.json) as the shape. Preserve any existing private configuration.

Set `codexHome`, `providerId`, and `upstreamBaseUrl` to the existing provider setup. Preserve the complete upstream API prefix. Put desktop project IDs and non-secret route aliases in `projectRoutes`; include the controller project's ID so this chat can continue during validation. Alias values are short letters/digits/underscore/hyphen labels. They never contain keys.

Configuration requires `schemaVersion: 1`; the port defaults to `8787`. The listener is fixed to `127.0.0.1`. An explicit config path is required by every command. Restart the foreground proxy after changing its configuration.

Keep actual endpoints, project mappings, Keychain references, configuration backups, and private run evidence outside Git. The router rejects a configuration stored inside its checkout. It never runs the desktop authentication helper. Configuration loading, startup, health, status, activation and rollback retrieve no credentials and send no destination-preflight requests, including when credential routing is enabled. Local readiness probes remain permitted.

## Optional project credential routing

Omit `credentialRouting` to retain legacy behavior and its readiness fingerprint with zero Keychain calls. Its presence enables routing under the existing `schemaVersion: 1`; `false`, `null`, incomplete objects and unknown fields are invalid. Use the separate [synthetic enabled example](examples/router.credentials.example.json); the [legacy example](examples/router.example.json) remains available.

The enabled object contains exactly `globalCredential` and `routeTargets`. `globalCredential` is a Keychain reference. `routeTargets` maps each alias to an object containing exactly `upstreamBaseUrl` and `credential`. Each `credential` reference contains exactly `keychainPath`, `service` and `account`: nonempty strings of at most 1,024 characters without control characters. Use an absolute keychain path; `~` and environment expressions are not expanded. `projectRoutes` maps each project ID to an alias. Include complete targets for A, B and the controller before validation. Several projects or aliases may deliberately share a destination, item or whole target. Unused valid entries and an empty target map are allowed; an absent alias blocks its model requests. A supplied incomplete target invalidates configuration.

Bind every credential to the gateway instance that issued and accepts it. Each destination must be an absolute HTTPS URL without user information, query or fragment. Preserve its full API prefix: a target ending `/region/v1` receives `/region/v1/responses` or `/region/v1/responses/compact`, with the original query. The top-level `upstreamBaseUrl` remains the global destination for catalog and qualifying unassigned-title requests. The controller is an ordinary mapped project: explicitly configure its target to use the global destination and global item if that is the intended pair. There is no controller bypass or automatic instance discovery.

To migrate the earlier unmerged `routeCredentials` format, restore direct operation and stop the old listener, then manually replace each alias's reference with a complete `routeTargets` pair. Remove `routeCredentials`; the old format is rejected even alongside `routeTargets`. Existing Keychain items need no recreation or rotation. Restart the proxy and check readiness before activation. Control commands require valid configuration, so migrate an obsolete enabled object or omit `credentialRouting` before using them.

### Provision items manually in Keychain Access

1. Privately checkpoint the direct provider URL and the exact prior router settings, including which optional properties were absent. Keep the existing desktop authentication command in place.
2. Open macOS **Keychain Access**, select the intended keychain, and use **File → New Password Item** to create a generic password item. Set **Keychain Item Name** to the configured `service`, **Account Name** to `account`, and enter the key in the password field locally. Do not paste keys into this chat, terminal commands, files in the checkout, or reports.
3. Provision a global item holding the exact token supplied by the desktop authentication helper. Provision separate A/B items holding distinct project API keys, and explicitly configure the controller target to reuse the global item and global destination when intended. Example names such as `example-global-service` / `example-global-account` and `example-project-a-service` / `example-project-a-account` are synthetic labels. Actual values and paths stay in private configuration.
4. Verify each selected item's service/account and its containing keychain locally. Copy only those references into private router configuration, using the full absolute keychain path, for example the synthetic `/Users/example/Library/Keychains/login.keychain-db`. Avoid ambiguous duplicate items. The router reads only the exact referenced generic password; it does not provision, edit, delete or explicitly unlock items. Keychain access policy may require user interaction; a denied or locked item can make lookup fail.
5. Restart the foreground proxy after changing mappings, destinations or references, check `status`, then use the activation procedure below. Matching readiness confirms configuration/listener agreement; it does not preflight Keychain access, destination connectivity or gateway acceptance.

For each admitted non-health request, the router retrieves the global item and verifies the incoming bearer token before metadata observation, identity resolution or project-key retrieval. The scheme is case-insensitive; the token is exact and case-sensitive. Mapped model requests then retrieve their target credential and forward to that target's destination with replaced `Authorization` and its matching `Host`. Deliberate controller reuse of the global item still performs separate verification and target reads. Catalog requests and qualifying unassigned titles use the global destination, retain the exact verified caller authorization and retrieve no project key. Mapped title-marked requests retain ordinary target priority. The title and observation options are independent and remain off unless explicitly enabled.

| Failure | Result |
|---|---|
| Incoming token differs from the retrieved global token | `AUTH_INVALID` (401) |
| Resolved alias has no complete target | `CREDENTIAL_UNMAPPED` (422) |
| Required item is absent, inaccessible, times out, or returns invalid output | `CREDENTIAL_UNAVAILABLE` (503) |

Global-item failure blocks authenticated requests. Project-item failure affects requests needing that key; unrelated healthy projects can continue. Failures never select another credential or destination, fall back to the global pair, retry the model request, or follow redirects. An active request fixes its resolved project, alias, destination and credential before forwarding. Project reassignment affects subsequent lookups; configuration changes require a proxy restart. Cross-credential or cross-instance continuation failures from the gateway remain failures; the router does not rewrite models, payloads or continuation IDs to repair them. Use fresh validation chats when switching gateway instances.

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

Restart the desktop app when the command reports `restartRequired`. The helper never restarts it. The provider setting affects every chat using that provider: model requests without a resolvable, explicitly mapped project will block, except qualifying initial titles when their separate policy is enabled. Arrange validation while other work is idle.

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

It re-reads desktop state per request and fixes the chosen assignment for that request. Transient lookup failures get a one-second window with 50 ms retries. Ancestry is limited to 32 nodes. Projectless, conflicting, unsupported, or unmapped requests never reach the upstream model endpoint. There is no default Global route, working-directory inference, foreground-window inference, or prompt inspection.

Allowed local operations:

| Operation | Behavior |
|---|---|
| `GET /healthz` | Local readiness; no authentication, credential lookup or upstream request |
| `GET /v1/models` | Provider-wide catalog; bearer authentication required, chat identity optional |
| `POST /v1/responses` | Bearer authentication and resolved project required; optional narrow initial-title exception below |
| `POST /v1/responses/compact` | Same identity and authentication requirements |

Other routes, methods, and WebSocket upgrades are rejected. Allowed queries retain their original content. Forwarding preserves body bytes, model names, and streaming status/content. Authorization follows the selected mode: unchanged caller authorization in legacy mode, or the verified global/selected project credential as described above. Hop-by-hop headers are removed while the intended routed authorization is retained, client disconnects cancel pending lookups and upstream work, and upstream inactivity is limited to five minutes. The router introduces no model-request retries and follows no redirects.

Diagnostics contain only fixed event/error codes, timestamps, correlation IDs, required chat/project IDs, aliases, resolution source, fixed operation labels, status, and timing. Prompts, responses, credentials, whole headers, raw metadata, raw desktop state, and exception text are excluded, including failure paths.

## Optional unassigned initial-title policy

Set `allowUnassignedThreadTitles` to `true` in private configuration to permit the observed initial-title pattern through `POST /v1/responses`. This strict boolean defaults to `false` under `schemaVersion: 1`. Restart the foreground proxy after changing it. Readiness distinguishes both policy and observation modes; rollback remains usable after mode changes and with the proxy offline. Existing activation records need no migration.

Ordinary mapped resolution always wins. The exception requires exactly one valid metadata object with singleton `thread_source` and `turn_trigger` strings both equal to `thread_title`. Header `thread-id`/`session-id` and metadata `thread_id`/`session_id` must all contain the same valid UUID. Header `x-codex-parent-thread-id` and metadata parent/fork-source members must be absent, including no null or empty occurrences. Duplicate allowlisted metadata members, including escaped key spellings, disqualify the exception. `request_kind` values do not authorize it.

Fresh healthy JSON and read-only SQLite checks must prove that the temporary ID has no assignment entry, projectless marker, saved thread, or incoming/outgoing spawn edge. Malformed state, missing schema, detected file/database changes, failed final checks and cancellation cannot grant the exception. Transient failures share the existing one-second lookup budget and 50 ms retry cadence. The checks use current readable snapshots, not an atomic transaction across both state files. No prior absence is cached for later attempts or requests.

Accepted titles use the top-level global upstream and caller credential unchanged; credential-routing mode first verifies that credential against the global Keychain item. Their diagnostics use `source: unassigned_title` with no project, owner or route alias. They have no project cost attribution. Client-supplied markers can be imitated by a local caller with an accepted credential; enabling this option accepts that limitation. The router does not inspect the body to prove that it generates a title.

This policy works independently of `observeRequestMetadata` and enables no additional metadata logging. Compaction, title reconsideration, other auxiliary families, known projectless/unmapped identities and other unresolved requests retain their existing behavior. There is no general unresolved-request fallback. Mapped requests retain priority and use their configured destination/credential pair when routing is enabled.

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

For a controlled run, establish a direct baseline, enable observation, start/activate the proxy, restart the desktop when required, and exercise fresh chats in both disposable projects plus a follow-up. Restore direct configuration and the previous observation setting, restart as required, verify a direct response, and stop the proxy. Preserve whether the option was originally absent. Keep checkpoints and actual IDs outside Git, and publish only symbolic labels in a report. See the [auxiliary metadata validation report](docs/validation/auxiliary-request-metadata-validation.md) for observed evidence and limitations.

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

The local Apple silicon app keeps router start, provider activation, direct recovery
and manual desktop-response confirmation in one controls window. It requires macOS
14 or newer and an installed Node 24; configuration stays private in place. The app
never starts routing on launch or selection. Closing controls leaves the app and
owned listener running; Quit uses guarded direct recovery.

```sh
npm run companion:test
npm run companion:build
npm run companion:package-test
open "dist/Codex Project Router.app"
```

The app can move independently of this checkout and uses only its bundled router
resources plus an installed absolute Node path. See [companion setup, lifecycle,
packaging and recovery](companion/README.md) for runtime selection, provider-wide
activation effects, separate readiness/ownership/confirmation facts, external
listener cleanup, manual GUI checks and deferred work.

## Development checks

```sh
npm test
node --check src/cli.js
git diff --check
```

Tests use temporary synthetic desktop state and local HTTPS upstreams with distinct global/project origins and API prefixes. The committed TLS key/certificate are public, test-only fixtures for localhost. Production uses normal upstream certificate verification. Tests never contact ICA or retrieve real credentials.

Scope and approval history are recorded in the initial [specification](docs/superpowers/specs/2026-11-10-desktop-project-identification-validation.md) and [implementation plan](docs/superpowers/plans/2026-11-10-desktop-project-identification-validation.md), the metadata increment's [specification](docs/superpowers/specs/2026-11-10-auxiliary-request-metadata-validation.md) and [implementation plan](docs/superpowers/plans/2026-11-10-auxiliary-request-metadata-validation.md), the title policy's [specification](docs/superpowers/specs/2026-11-10-unassigned-title-request-policy.md) and [implementation plan](docs/superpowers/plans/2026-11-10-unassigned-title-request-policy.md), and credential routing's [specification](docs/superpowers/specs/2026-11-11-project-credential-routing.md) and [implementation plan](docs/superpowers/plans/2026-11-11-project-credential-routing.md).
