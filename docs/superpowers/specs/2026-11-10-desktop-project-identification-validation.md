# Desktop project-identification validation

**Slug:** `desktop-project-identification-validation`  
**Type:** feature  
**Status:** APPROVED  
**Created:** 2026-11-10  
**Updated:** 2026-11-10  
**Provenance:** Investigation chat `01a1c4e0-fb47-76a0-a011-b57f9f2026c3`; scope/design confirmation “split is ok, scope/design confirmed”; subsequent interactive clarification; DRAFT specification approved by “proceed” after presentation in the current chat.

## Problem and desired outcome

The wider goal is automatic selection of API credentials according to each Codex chat’s assigned project, including concurrent chats.

This increment delivers a local proxy that identifies projects during actual desktop use while forwarding admitted requests with the existing global credential. It establishes whether desktop identification and ICA forwarding are reliable enough to support later credential routing.

Deliverables include the runnable proxy, identification diagnostics, activation/rollback commands, tests, documentation, and a validation report.

## Current evidence

The repository contains only `LICENSE`; no implementation or approved artifacts exist.

The investigation demonstrated distinct chat identifiers on concurrent bundled-engine requests and stable identity on a follow-up against a dummy endpoint. Desktop state contains project assignments and saved subagent parent relationships.

The current provider uses the Responses API over HTTPS, has WebSockets disabled, and retrieves authentication through a Keychain command. Real desktop-through-proxy-to-ICA behavior remains unverified.

The observed request headers and desktop-state structures are internal interfaces whose compatibility may change.

## Selected approach

Use Node.js 24, plain JavaScript, and built-in libraries for HTTP forwarding, streaming, SQLite access, and tests. Use minimal dependencies where necessary for safe configuration handling; no web framework or model SDK is required.

The proxy will:

- Listen exclusively on loopback and forward to one configured HTTPS upstream.
- Preserve the current provider, selected model, and Codex authentication helper.
- Forward the existing authentication credential in memory without retrieving keys independently.
- Resolve project identity before forwarding model-execution requests.
- Display the project and configured route alias that would inform future credential selection.

Manual model aliases would not validate automatic project identification. Full credential routing is deferred until this validation provides evidence for it.

## Project identification

Identify requests using the observed chat headers and structured turn metadata. Validate their consistency while distinguishing current-chat identity from parent identity.

Resolve explicit desktop project assignments by project ID. For subagents without a direct assignment, follow saved parent relationships using read-only access and bounded traversal. Conflicting assignments, ambiguous parents, and cycles must produce errors.

Do not infer projects from prompts, working directories, project names, or the foreground window. Read only the desktop-state fields required for identification.

Read assignments again for each new request so subsequent requests reflect project moves. Keep the resolved assignment fixed for an in-flight request.

Allow bounded local lookup retries for transient state availability. If identity remains unresolved, conflicting, unsupported, or projectless, block the model-execution request with a sanitized error and make no upstream call.

## Interfaces and configuration

Provide commands to run the foreground proxy, inspect status, activate it, and restore the direct connection.

Private configuration outside Git will contain:

- The original upstream URL, local port, and Codex-home location.
- Explicit project-ID-to-route-alias mappings.
- Configuration-format identification for validation.

A route alias represents a future credential destination; it contains no API key. Missing mappings block model execution. There is no implicit Global fallback.

Permit only the required Responses API operations and necessary provider-wide model discovery. Catalog requests may pass without chat identity because they do not execute a model; this exception must not admit model-execution requests.

Unsupported routes and transports fail visibly. WebSocket support is excluded.

## Forwarding and privacy

Preserve request bodies, model names, response status, and streaming behavior. Handle concurrency, backpressure, cancellation, disconnects, and upstream errors. The proxy must not introduce model-request retries or inspect prompt content for routing.

Diagnostic output is restricted to identification and operational metadata: correlation identifiers, required chat/project IDs, route aliases, resolution outcomes, status, and timing.

Never log prompts, responses, credentials, complete headers, raw turn metadata, raw desktop state, or error content that could expose them. These restrictions apply to normal operation, failure paths, and helper commands.

Keep actual upstream details, project mappings, and configuration backups outside Git. Repository examples must use synthetic values.

## Activation and rollback

Activation is an explicit command; installation and proxy startup do not edit Codex settings.

Before activation, validate the supported provider configuration and proxy readiness. Create a protected backup outside Git, then change only the intended provider’s base URL. Preserve authentication, model selection, and unrelated settings.

Rollback restores the original base URL while preserving unrelated subsequent edits. Unexpected changes to the setting owned by the helper must produce a conflict rather than be overwritten. Repeated commands must behave safely.

Provide manual recovery instructions that remain usable if the proxy or helper is unavailable. Report required desktop restarts without automatically terminating the app.

Activation affects every chat using that provider. Requests lacking resolvable identity or explicit mappings will block.

## Acceptance criteria

| ID | Criterion |
|---|---|
| AC-01 | The proxy runs on Node.js 24 with documented setup and binds only to loopback. |
| AC-02 | Identification resolves explicit assignments and saved subagent ancestry without inspecting prompts or guessing from folders. |
| AC-03 | Two desktop chats in different mapped projects make overlapping requests through the proxy to ICA, receive streamed responses, and produce distinct, correct identification results while retaining global authentication. |
| AC-04 | Validate new-chat first requests, follow-ups, resumed/forked chats, and subsequent requests after project moves. |
| AC-05 | Exercise compaction and subagents. Record unsupported or blocked positive scenarios as failed capabilities. |
| AC-06 | Missing, malformed, conflicting, unsupported, projectless, or unmapped identity produces bounded errors and zero upstream model calls. Test transient lookup recovery. |
| AC-07 | Dummy-upstream tests verify streaming, concurrency isolation, cancellation, backpressure, upstream failures, and absence of proxy-generated model retries. |
| AC-08 | Sentinel-based checks verify that diagnostics and helper errors exclude credentials, payloads, complete headers, and raw state. |
| AC-09 | Temporary configuration fixtures verify activation, rollback, backups, conflict handling, repeated commands, and preservation of unrelated settings. |
| AC-10 | After live validation, restore the direct connection and verify desktop-to-ICA operation following any required restart. |
| AC-11 | Documentation and the validation report distinguish observed passes, failures, and untested cases, recording relevant versions and required user actions. Complete specification and quality review. |

## Completion and limitations

Attempt fixes within the approved scope before concluding that a desktop path is incompatible.

Validation may finish with either demonstrated support or a conclusive incompatibility supported by evidence. A failed capability must remain visibly failed; it cannot be represented as successful support. Incompatibility blocks progression to per-project credentials.

Dummy-endpoint results alone do not establish desktop compatibility. Untested required scenarios leave validation incomplete unless a demonstrated incompatibility prevents them from running.

The supported target is the current local macOS installation and HTTP Responses transport. Do not modify desktop project assignments, SQLite state, or Keychain entries.

## Out of scope

Separate team credentials, credential switching, billing attribution, graphical interfaces, automatic startup, remote/cloud hosts, and general-purpose gateway functionality.

These remain provisional later increments requiring their own approvals.

**Execution endpoint:** deliver the proxy and reversible setup, complete verification/review and desktop validation, report demonstrated behavior and limitations, restore the direct baseline, then stop before per-project credential selection.
