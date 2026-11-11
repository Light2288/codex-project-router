# Project credential routing — specification

**Slug:** `project-credential-routing`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-11

**Provenance:** Revision of `docs/superpowers/specs/2026-11-11-project-credential-routing.md`, preserving its basename and original creation date. The previously approved single-upstream specification and implementation plan are preserved in Git at `639cbeb`. Their authorization covered the earlier credential-routing scope. Following failed live validation, the user identified separate gateway instances for the global and project keys, selected explicit credential/destination pairs and replacement of the unmerged key-only format through two native clarification answers, then approved the amended Stage 1 scope/design with `confirm`. That confirmation authorizes this DRAFT revision only. Earlier approval history is retained in section 5.

Artifact resolution is `NEW_ONLY` for this specification and `docs/superpowers/plans/2026-11-11-project-credential-routing.md`, with matching slug and plan reference. There are no legacy candidates. The previous plan approval covered only the prior single-upstream scope. The revised plan has now received its own separate approval for this amendment.

The fresh builder check reported `nothing important left`. This is a specification-completeness check, not implementation approval or the pending whole-branch review.

## 1. Problem, outcome and boundary

The wider goal is selecting the credential and gateway instance according to each chat’s assigned project.

At the original `cd58067` baseline, the router resolved mapped projects and saved subagent ancestry while preserving the caller's credential. That baseline's recorded suite passed 259 tests. The current unmerged implementation at `639cbeb` verifies the caller against a fresh global Keychain value and substitutes a selected project credential, but sends every request to one configured upstream. Its latest recorded suite passed 586 tests; these checks were not rerun during this specification revision.

Controlled desktop validation showed successful local project-key access and route selection, followed by upstream HTTP 401 for both project keys. The user subsequently identified a different gateway instance and API prefix for those keys. Acceptance by the intended instance remains untested. Exact prior settings and direct operation were restored, the user confirmed a direct response after restart, and the proxy was stopped with no listener remaining. Preserve the failed run in `docs/validation/project-credential-routing.md`; actual endpoints, references and runtime evidence remain private.

This amendment will complete the same **opt-in project credential-routing increment** by selecting an explicit HTTPS destination together with each mapped credential. It includes configuration migration for the unmerged enabled format, safeguards, tests, documentation, renewed desktop validation, recovery and sequential specification/quality review. Retain the implemented Keychain reader and authentication behavior unless an in-scope defect requires correction.

It resolves whether distinct project credentials work against their intended gateway instances using the desktop's existing request format and supported lifecycle. Local selection and transport evidence do not independently establish gateway account or billing attribution. Keeping destination selection in this increment is necessary to evaluate the credentials with their issuing instance; unrelated provider adaptations remain deferred.

The selected approach uses:

- macOS Keychain instead of launcher-dependent environment variables or plaintext credential files.
- Existing route aliases instead of separate credential mappings directly on project IDs.
- Verification against the existing global credential instead of trusting bearer syntax alone.
- Fresh lookups instead of startup caching.
- Request rejection instead of global-key fallback.
- Manual Keychain provisioning instead of router secret-management commands.
- Optional enablement instead of mandatory configuration migration.

For the amendment, the user selected **explicit credential-and-URL pairs per alias** over optional URL overrides that could silently retain the global destination. The user also selected **replacement of the unmerged key-only format** over supporting both enabled formats. Configurations without credential routing still require no migration.

Earlier increments' approved artifacts remain unchanged. Their credential-preservation requirements continue to describe legacy mode. The original approval authorized Keychain reads and credential substitution in enabled mode; this approved amendment additionally specifies explicit per-route destination selection. Further implementation requires an approved revised plan.

## 2. Configuration and credential access

Retain `schemaVersion: 1`, existing private-file validation and the current configuration interface. The top-level `upstreamBaseUrl` remains the global destination. Replace the unmerged enabled configuration with this optional object:

```json
{
  "credentialRouting": {
    "globalCredential": {
      "keychainPath": "/Users/example/Library/Keychains/login.keychain-db",
      "service": "example-global-service",
      "account": "example-global-account"
    },
    "routeTargets": {
      "validation-a": {
        "upstreamBaseUrl": "https://projects.example.invalid/region/v1",
        "credential": {
          "keychainPath": "/Users/example/Library/Keychains/login.keychain-db",
          "service": "example-project-a-service",
          "account": "example-project-a-account"
        }
      },
      "validation-b": {
        "upstreamBaseUrl": "https://projects.example.invalid/region/v1",
        "credential": {
          "keychainPath": "/Users/example/Library/Keychains/login.keychain-db",
          "service": "example-project-b-service",
          "account": "example-project-b-account"
        }
      },
      "controller": {
        "upstreamBaseUrl": "https://global.example.invalid/v1",
        "credential": {
          "keychainPath": "/Users/example/Library/Keychains/login.keychain-db",
          "service": "example-global-service",
          "account": "example-global-account"
        }
      }
    }
  }
}
```

All example values are synthetic. The example's controller URL represents the top-level global `upstreamBaseUrl`; matching it is an explicit configuration choice, not a special controller bypass.

Omitting `credentialRouting` preserves existing behavior and makes **zero Keychain calls**. Its presence enables credential routing. The object contains exactly `globalCredential` and `routeTargets`. Null, booleans, incomplete required structure and unknown fields are invalid. The old `routeCredentials` property is rejected, including when supplied alongside `routeTargets`; there is no implicit migration or compatibility mode for the unmerged key-only format.

Each Keychain reference contains exactly `keychainPath`, `service` and `account`. Require nonempty strings without control characters, capped at 1,024 characters each; the path must be absolute. Do not expand environment expressions or `~`.

`routeTargets` is an object whose keys use the existing route-alias syntax. Each target contains exactly `upstreamBaseUrl` and `credential`. Its credential is a Keychain reference with the exact fields above. Use own-property membership: absent aliases named `constructor` or `toString` must not resolve through inherited properties, while explicit own entries remain valid.

Target URLs use the existing top-level URL validation and canonicalization policy: an absolute HTTPS URL without user information, query or fragment, normalized with the existing URL parser and trailing-slash convention. Preserve the full API path prefix when appending the admitted operation suffix and its query string. For example, a target ending `/region/v1` receives `/region/v1/responses` or `/region/v1/responses/compact`; the prefix must not be replaced by a leading-slash URL join. Reject malformed, relative, protocol-relative and HTTP destinations.

Multiple projects or aliases may deliberately share a credential, destination or complete target. Unused, well-formed targets are permitted for advance setup. An empty map or missing alias remains structurally valid and blocks only affected model requests; every supplied target must be complete and valid. Missing URL or credential fields invalidate configuration rather than falling back to any global value. Loaded targets and references are deeply frozen.

Mappings, references and destination changes require a proxy restart. Credential values remain exclusively in Keychain. The enabled format requires a one-time manual configuration migration: give every desired alias an explicit target, including the controller. The user need not recreate or rotate existing Keychain items. Restore direct operation and stop an old listener before switching formats; this recovery has already been completed for the recorded failed run. Activation/rollback still require a valid configuration; if an obsolete enabled object is present, migrate it or omit it before invoking control commands.

Keychain access must:

- Run fixed `/usr/bin/security find-generic-password`, using explicit service, account, password-only output and the configured keychain path, without a shell.
- Read only requested items; never execute the desktop authentication helper or create, edit, delete or explicitly unlock Keychain items.
- Limit each lookup to five seconds and stdout/stderr to 16 KiB each. Terminate and reap the child on timeout, overflow or cancellation.
- Accept only a nonempty token of 1–8,192 visible ASCII bytes after removing at most one final LF emitted by the command. Reject whitespace, control characters, invalid bytes and unsuccessful process outcomes, even if plausible output was produced.
- Keep subprocess output and exception details out of diagnostics, HTTP errors and CLI output.

Each request independently retrieves its global verification key and, when needed, its selected project key. There is no cross-request cache, lookup coalescing, stale-value fallback or automatic retrieval retry. Separate reads are not atomic.

Credentials remain request-local as far as ordinary JavaScript memory permits; secure memory erasure is not promised. Internal module structure and test injection remain implementation-planning decisions.

## 3. Request behavior, compatibility and privacy

Preserve existing route, method, header-shape and bearer-syntax admission.

In credential-routing mode:

1. Health requests remain local and perform no credential lookup.
2. Every admitted non-health request retrieves the global credential and compares it with the incoming bearer token. Scheme parsing remains case-insensitive; token comparison is exact and case-sensitive, using constant-time comparison for equal-length values.
3. Authentication failure occurs before metadata observation, identity resolution, project-key retrieval or upstream forwarding.
4. After verification, model requests use the existing project resolver and title-eligibility rules.
5. Mapped model requests select their alias's complete target, retrieve its credential and forward to its `upstreamBaseUrl`. Explicitly set outgoing `Authorization` after hop-by-hop filtering, and set `Host` for the selected destination. This applies to Responses and dedicated compaction requests, including saved-ancestor attribution. The controller is an ordinary mapped route and requires an explicit target; deliberate reuse of the global item still performs separate global verification and mapped-credential reads.
6. Catalog requests and qualifying unassigned titles use the top-level global `upstreamBaseUrl`, explicitly retain the original verified caller authorization and retrieve no project key. They do not use a route target or infer title origin from timing or project activity.

Mapped resolution retains priority over title markers. Authentication or credential-selection failures cannot become title exceptions. Neither existing optional policy is enabled automatically.

Use fixed, sanitized errors:

| Condition | Code | HTTP status |
|---|---|---:|
| Global token mismatch | `AUTH_INVALID` | 401 |
| Resolved alias lacks an explicit route target | `CREDENTIAL_UNMAPPED` | 422 |
| Credential retrieval fails, times out or produces invalid output | `CREDENTIAL_UNAVAILABLE` | 503 |

Retain the existing `CREDENTIAL_UNMAPPED` message, `The assigned route has no credential reference.` A supplied but incomplete target is a configuration error, not a runtime missing-alias fallback. Invalid configuration uses the existing `CONFIG_INVALID` error. Existing admission and identity errors retain their semantics. Global-key unavailability blocks authenticated requests; project-key unavailability affects only requests needing that key. Connection/TLS failures retain the existing sanitized `UPSTREAM_FAILED` behavior; upstream HTTP outcomes are forwarded unchanged. No failure triggers another credential or destination, a global fallback, a model-request retry or redirect following.

A request fixes its resolved project, alias, selected destination and retrieved outgoing credential before recording `started` and forwarding. Later project movement, proxy configuration changes or key rotation do not alter an active request's selected target or stream. Subsequent requests re-read project assignment and key values; configuration changes take effect after proxy restart. Global rotation may also require the desktop to refresh its token; stale incoming tokens are rejected.

Destination and outgoing authorization are the intended changes for mapped requests. Preserve model and body bytes, permitted headers and query strings, streaming, backpressure, cancellation, inactivity handling, upstream outcomes and normal TLS verification. The selected URL determines TLS connection identity and the outgoing Host header; do not reuse the global host. Intended authorization must survive a `Connection` header naming `authorization`.

Do not rewrite models, payloads or continuation identifiers to repair cross-credential or cross-instance gateway incompatibilities. A moved chat's next request selects its new target even when the gateway cannot use its existing continuation identifiers. Record the resulting failure accurately and reconsider scope rather than silently falling back or migrating state.

Compatibility requirements:

- Legacy configurations retain existing behavior and readiness fingerprints.
- Enabled fingerprints include canonical routing, target URL and reference configuration, never credential values or their hashes. Reordered target maps/reference fields yield equivalent fingerprints; target URL or reference changes change readiness. Prior unmerged enabled fingerprints need not remain compatible because that format is deliberately replaced.
- Key rotation alone does not change the fingerprint.
- Health indicates matching listener/configuration readiness, not Keychain accessibility or gateway success.
- Configuration loading, startup, health, status, activation and rollback perform no credential retrieval or upstream-destination preflight. Existing local readiness probes remain permitted.
- Existing activation records remain usable. Activation continues to change only the provider base URL, preserving authentication, models and unrelated settings. Keychain unavailability must not prevent rollback.

Diagnostics retain their existing allowed identifiers, aliases, sources, timings, statuses and fixed errors. Exclude credential values, hashes or prefixes; Keychain references; actual upstream URLs; subprocess output; raw headers/state; exception text; prompts and responses. Upstream content remains opaque rather than being newly inspected or redacted. An upstream error body may contain sensitive gateway-generated details; do not copy such fragments into committed reports or evidence packages.

Global-token possession does not establish that a caller is a particular desktop chat. Existing local identity and title-marker trust limitations remain.

## 4. Acceptance criteria and validation

| ID | Acceptance criterion |
|---|---|
| **AC-01** | Strict optional target configuration works as specified; supplied incomplete/invalid targets and the old enabled format reject. Empty/unused/shared targets and own aliases work as specified. Legacy behavior and historical fingerprints remain compatible, with zero Keychain calls. Enabled readiness fingerprints canonically include target URLs/references and exclude credential values/hashes. |
| **AC-02** | Global mismatch and retrieval failure reject before observation, identity/project-key lookup and upstream forwarding. Health and control operations retrieve no credentials. |
| **AC-03** | Separate synthetic HTTPS origins receive only the exact credentials, Host headers, complete path prefixes, operation/query suffixes and unchanged bodies intended for them, using one common incoming global token. Cover Responses, compaction, shared targets, ancestry, follow-up/fork state and overlapping global/project destinations. |
| **AC-04** | Missing targets and credential failures reject without upstream model calls. Destination connection/TLS failures and upstream rejection retain their existing outcomes. Healthy unrelated targets continue; no credential/destination fallback, redirect following, model retry or stale reuse occurs. Retain absent/denied/locked item, timeout, output-overflow, invalid-secret, unsuccessful-process and cancellation coverage. |
| **AC-05** | Catalog and eligible unassigned-title requests reach the global destination with verified caller authorization and no project-key retrieval. Explicit mapped controller targets and mapped title-marked requests use their selected pairs. Legacy/routing, observation and title-policy combinations preserve their contracts and existing absence checks. |
| **AC-06** | Fresh lookups observe key rotation/deletion and reject stale global tokens. Reassignment can change both destination and credential for the next request; pending retrievals and active streams retain the already selected pair. Pending children are cleaned up on cancellation or bounded failure. No continuation repair occurs. |
| **AC-07** | Transport and sentinel tests verify destination/credential isolation, cancellation and privacy across normal and failure paths, including authorization named by `Connection`. Credential values/hashes/prefixes, actual URLs and Keychain references remain absent from diagnostics and committed runtime evidence; synthetic examples remain allowed. |
| **AC-08** | Documentation and synthetic configuration explain explicit targets, full API prefixes, manual migration/provisioning, enablement, failures, rotation, trust limits and recovery. `npm test`, `node --check src/cli.js` and `git diff --check` pass, followed by retained task reviews and the sole sequential specification/quality whole-branch review with actionable dispositions. |
| **AC-09** | Renewed controlled desktop validation demonstrates distinct project keys against their intended instance, controller operation on the global target, fresh responses and automatic titles, overlapping requests, same-chat follow-up, reassignment and subsequent selection. Finish with exact restoration, restart, a user-confirmed direct response and stopped listener; preserve earlier failed validation history. |

Synthetic tests use fake credentials, controlled process results and separate local HTTPS upstreams. They never retrieve actual credentials or contact external gateways. Rotation and failure cases are synthetic; validation must not intentionally change real global/project keys.

For desktop validation:

- Use disposable projects A/B, distinct project keys and an explicit controller mapping. Bind each credential reference to the issuer's intended full HTTPS base URL in private configuration; the controller explicitly selects the global item and destination. A/B may share a gateway URL while retaining distinct items. Use fresh chats after activation so the initial test does not inherit continuations from another instance.
- Keep the proxy in a separate Terminal session for restart resilience.
- Let the user provision Keychain items and perform required desktop interactions. Do not create or message chats through tools without explicit authorization.
- Checkpoint exact prior provider URL and private settings, including omitted properties. Keep actual URLs, references, mappings and runtime evidence outside Git. Preserve the original failed run and use a separately identifiable renewed run; do not relabel earlier failures as passes.
- Exercise fork, saved subagent and compaction paths opportunistically; record unrun live cases explicitly. Their credential behavior remains required synthetic coverage.
- Record symbolic selection and transport evidence without claiming independent gateway billing attribution.
- Restore exact prior settings while preserving unrelated edits, restart as required, verify a direct response, then stop the proxy—even when validation fails.

Missing required actions or evidence leaves live validation incomplete. An observed incompatibility remains a failed capability and cannot be represented as supported.

## 5. Constraints and approval handoff

Work in the existing checkout on `feat/project-credential-routing`, currently at `639cbeb`. The original approved artifacts were committed before implementation, and the initial branch setup is complete. Preserve those commits and completed task reviews. Do not repeat the initial `main` update, branch creation or completed implementation tasks. Stage 2 revised only this specification. The amended specification's approval now authorizes Stage 3 plan revision. After separate approval of the revised plan, save both approved revisions before further product changes and commit on the existing implementation branch. No worktree, push or merge is authorized.

Deferred work includes billing/account proof, stronger caller isolation, credential-management commands, additional secret backends, GUI, automatic startup, remote/cloud hosts, new identity inference or auxiliary policies, automatic instance discovery, model translation, engine changes and continuation migration. Do not add an account/provider registry or additional CLI commands merely to share target values.

**Execution endpoint:** deliver, verify and review the amended credential-routing increment; report the working result, evidence and limitations; restore direct operation and exact prior settings; verify a direct response and stopped listener; then stop before subsequent increments. A gateway incompatibility remains a failed capability; missing required live actions/evidence leaves the increment incomplete.

**Approval history:** Original Stage 1 scope/design was approved by the user's `confirmed` message. The user separately approved the original specification and plan in the two later `PLEASE IMPLEMENT THIS PLAN` messages reproducing those respective artifacts. That approval authorized the implemented single-upstream scope and remains historical evidence; it does not approve this amendment. For this amendment, native answers selected `Explicit pairs (Recommended)` and `Replace draft format (Recommended)`, followed by the user's `confirm` approving the separately presented amended scope/design. The user's subsequent `approved`, immediately following the saved amended DRAFT specification handoff, separately approves this amended specification and authorizes revised implementation planning only.

**Current stage:** Stage 4 — implementation authorized. After separately approving this amended specification, the user separately approved the revised implementation plan with the subsequent `approved` message immediately following that plan's handoff. Both approved revisions are saved before further product edits. Push and merge remain unauthorized.
