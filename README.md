# Codex Project Router

Experimental local proxy for validating automatic project identification in Codex desktop. It previews a project route alias and forwards every admitted request with the caller's existing global credential. **Per-project API-key selection is not implemented.**

The router relies on observed internal request headers and local desktop state. Check the [validation report](docs/validation/desktop-project-identification-validation.md) for what has actually been tested. Passing local tests does not establish desktop-to-gateway compatibility. Live testing passed the primary chat lifecycle matrix. The [metadata validation](docs/validation/auxiliary-request-metadata-validation.md) identified additional title-generation requests whose temporary IDs have no proven project origin. Those requests remain blocked; their handling policy must be resolved before progression to per-project credentials.

## Requirements and installation

- macOS with Node.js 24 and npm.
- A configured HTTP Responses provider using a command-backed authentication helper, with `supports_websockets = false`.
- The currently observed `.codex-global-state.json` assignment/catalog structures and `state_5.sqlite` parent-edge table.

```sh
npm ci
```

There is no build step, global installation, background service, or automatic configuration editing.

## Private configuration

Create a user-owned directory with mode `700` outside the checkout, normally `~/.codex-project-router`. Create `config.json` there with mode `600`, using [the synthetic example](examples/router.example.json) as the shape. Preserve any existing private configuration.

Set `codexHome`, `providerId`, and `upstreamBaseUrl` to the existing provider setup. Preserve the complete upstream API prefix. Put desktop project IDs and non-secret route aliases in `projectRoutes`; include the controller project's ID so this chat can continue during validation. Alias values are short letters/digits/underscore/hyphen labels. They never contain keys.

Configuration requires `schemaVersion: 1`; the port defaults to `8787`. The listener is fixed to `127.0.0.1`. An explicit config path is required by every command. Restart the foreground proxy after changing its configuration.

Keep actual endpoints, project mappings, configuration backups, and private run evidence outside Git. The router rejects a configuration stored inside its checkout. It never runs the authentication helper or independently retrieves a Keychain secret.

## Run, activate, inspect, restore

Start the foreground proxy in a terminal:

```sh
node --use-system-ca src/cli.js serve --config "$HOME/.codex-project-router/config.json"
```

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

Restart the desktop app when the command reports `restartRequired`. The helper never restarts it. The provider setting affects every chat using that provider: model requests without a resolvable, explicitly mapped project will block. Arrange validation while other work is idle.

Restore direct access before stopping the proxy:

```sh
node src/cli.js rollback --config "$HOME/.codex-project-router/config.json"
```

Restart the app when required, verify a direct gateway response, then stop the foreground proxy with Ctrl-C. Rollback works when the proxy is unavailable and preserves unrelated edits made after activation. An unexpected change to the owned base URL produces a conflict for inspection.

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
| `GET /healthz` | Local readiness; no authentication or upstream request |
| `GET /v1/models` | Provider-wide catalog; bearer authentication required, chat identity optional |
| `POST /v1/responses` | Bearer authentication and resolved project required |
| `POST /v1/responses/compact` | Same identity and authentication requirements |

Other routes, methods, and WebSocket upgrades are rejected. Allowed queries retain their original content. Forwarding preserves body bytes, model names, streaming status/content, and each request's credential. Hop-by-hop headers are removed, client disconnects cancel upstream work, and upstream inactivity is limited to five minutes. The router introduces no model-request retries and follows no redirects.

Diagnostics contain only fixed event/error codes, timestamps, correlation IDs, required chat/project IDs, aliases, resolution source, fixed operation labels, status, and timing. Prompts, responses, credentials, whole headers, raw metadata, raw desktop state, and exception text are excluded, including failure paths.

## Optional request metadata observation

Set `observeRequestMetadata` to `true` in the private configuration to investigate auxiliary desktop requests. The option is a strict boolean and defaults to `false` under the existing `schemaVersion: 1`. Restart the foreground proxy after changing it. Readiness distinguishes the two modes; a running proxy with the other mode is not ready for activation. Existing activation records remain usable, and rollback works with a changed observation setting or an unavailable proxy.

When enabled, eligible model-request diagnostics include `requestMetadata` after route/authentication admission, before identity resolution. This includes subsequent identity failures. Early admission failures, health, and catalog requests receive no observations. When disabled, the additional property is absent.

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

Use disposable projects named Router Validation A and Router Validation B with separate scratch folders. Add their IDs and the controller project's ID to private configuration. Keep folder-access changes confined to these scratch projects.

1. Establish a direct-response baseline using disposable chats with minimal prompts, for example `Reply ROUTER_A only; do not use tools or read or modify files.`
2. Start the proxy, activate it, restart the app, and verify the controller chat remains usable.
3. Send first requests in new chats in both projects. Send two modest requests close enough together to produce overlapping `started`/`completed` intervals. Record sanitized intervals and aliases, without copying prompt/response content.
4. Exercise follow-up and resumed chats, then fork a test chat and send a follow-up. Move a disposable chat to the other disposable project, accepting scratch-folder access only, and verify its next request resolves to the new project.
5. In an idle test chat, select `/compact` from the desktop composer and observe the resulting request.
6. In a test chat, explicitly request one read-only subagent to return a short marker without reading/changing files. Verify saved-parent attribution in the router diagnostics.
7. Restore direct configuration, restart the app, verify a direct response, and stop the proxy.

Desktop project/chat creation, sending prompts, moving/forking chats, and restarts require user interaction unless separately authorized. The router does not create or message chats.

Record each case as an observed pass, observed failure, or not run. A demonstrated incompatibility can conclude this validation increment after in-scope fixes and review. Missing user actions leave validation incomplete. Per-project credentials remain blocked until the evidence supports another approved increment.

## Development checks

```sh
npm test
node --check src/cli.js
git diff --check
```

Tests use temporary synthetic desktop state and a local HTTPS upstream. The committed TLS key/certificate are public, test-only fixtures for localhost. Production uses normal upstream certificate verification. Tests never contact ICA or retrieve real credentials.

Scope and approval history are recorded in the initial [specification](docs/superpowers/specs/2026-11-10-desktop-project-identification-validation.md) and [implementation plan](docs/superpowers/plans/2026-11-10-desktop-project-identification-validation.md), and the metadata increment's [specification](docs/superpowers/specs/2026-11-10-auxiliary-request-metadata-validation.md) and [implementation plan](docs/superpowers/plans/2026-11-10-auxiliary-request-metadata-validation.md).
