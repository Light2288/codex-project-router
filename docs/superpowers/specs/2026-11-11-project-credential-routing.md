# Project credential routing — specification

**Slug:** `project-credential-routing`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-11

**Provenance:** Continuation request, nine native clarification answers, and the subsequent `confirmed` message approving Stage 1 scope/design. Repository evidence includes README, the three validation reports, and the implementation at `cd58067`. The user separately approved the presented DRAFT specification in the message beginning `PLEASE IMPLEMENT THIS PLAN` and reproducing that specification. Under the separate approval gates, that message authorizes implementation planning only. Saved after returning to Default mode.

Artifact resolution found no existing specification or plan for this slug before this specification was saved. The builder check found no material questions remaining.

## 1. Problem, outcome and boundary

The wider goal is selecting credentials according to each chat’s assigned project.

The current router resolves mapped projects and saved subagent ancestry but forwards the caller’s credential unchanged. Incoming authentication checks bearer syntax; the upstream validates the supplied token. The previous increment also established a narrow, separately enabled exception for initial-title requests without project attribution. Its recorded suite passed 259 tests.

This increment adds **opt-in project credential routing**, including Keychain access, caller verification, configuration, safeguards, tests, documentation, controlled desktop validation, recovery and sequential specification/quality review.

It resolves whether distinct project credentials work across the supported desktop lifecycle against the existing HTTPS gateway. It does not establish gateway account or billing attribution.

The selected approach uses:

- macOS Keychain instead of launcher-dependent environment variables or plaintext credential files.
- Existing route aliases instead of separate credential mappings directly on project IDs.
- Verification against the existing global credential instead of trusting bearer syntax alone.
- Fresh lookups instead of startup caching.
- Request rejection instead of global-key fallback.
- Manual Keychain provisioning instead of router secret-management commands.
- Optional enablement instead of mandatory configuration migration.

Earlier approved artifacts remain unchanged. Their credential-preservation requirements continue to describe legacy mode; this increment explicitly authorizes Keychain reads and credential substitution in the new mode.

## 2. Configuration and credential access

Retain `schemaVersion: 1`, existing private-file validation and the current configuration interface. Add one optional object:

```json
{
  "credentialRouting": {
    "globalCredential": {
      "keychainPath": "/Users/example/Library/Keychains/login.keychain-db",
      "service": "example-global-service",
      "account": "example-global-account"
    },
    "routeCredentials": {
      "validation-a": {
        "keychainPath": "/Users/example/Library/Keychains/login.keychain-db",
        "service": "example-project-service",
        "account": "example-project-account"
      }
    }
  }
}
```

All example values are synthetic.

Omitting `credentialRouting` preserves existing behavior and makes **zero Keychain calls**. Its presence enables credential routing. Null, booleans, incomplete required structure and unknown fields are invalid.

Each Keychain reference contains exactly `keychainPath`, `service` and `account`. Require nonempty strings without control characters, capped at 1,024 characters each; the path must be absolute. Do not expand environment expressions or `~`.

`routeCredentials` keys use the existing route-alias syntax. Multiple projects or aliases may deliberately share an item. Unused, well-formed entries are permitted for advance setup. An empty map or missing alias entry remains structurally valid and blocks only affected model requests; malformed supplied references invalidate configuration.

Mappings and references require a proxy restart when changed. Credential values remain exclusively in Keychain.

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
5. Mapped model requests retrieve their alias’s credential and explicitly set outgoing `Authorization` after hop-by-hop filtering. This applies to Responses and dedicated compaction requests, including saved-ancestor attribution.
6. Catalog requests and qualifying unassigned titles explicitly retain the original verified caller authorization and retrieve no project key.

Mapped resolution retains priority over title markers. Authentication or credential-selection failures cannot become title exceptions. Neither existing optional policy is enabled automatically.

Use fixed, sanitized errors:

| Condition | Code | HTTP status |
|---|---|---:|
| Global token mismatch | `AUTH_INVALID` | 401 |
| Resolved alias lacks a credential reference | `CREDENTIAL_UNMAPPED` | 422 |
| Credential retrieval fails, times out or produces invalid output | `CREDENTIAL_UNAVAILABLE` | 503 |

Existing admission and identity errors retain their semantics. Global-key unavailability blocks authenticated requests; project-key unavailability affects only requests needing that key. No failure triggers another credential, a global fallback, a model-request retry or redirect following.

A request fixes its resolved project and retrieved outgoing credential before forwarding. Later project movement or key rotation affects subsequent lookups, not an active stream. Global rotation may also require the desktop to refresh its token; stale incoming tokens are rejected.

Preserve destination, model and body bytes, permitted headers and query strings, streaming, backpressure, cancellation, inactivity handling, upstream outcomes and normal TLS verification. Intended authorization must survive a `Connection` header naming `authorization`.

Do not rewrite payloads or continuation identifiers to repair cross-credential gateway incompatibilities. Record such failures accurately and reconsider scope rather than silently falling back.

Compatibility requirements:

- Legacy configurations retain existing behavior and readiness fingerprints.
- Enabled fingerprints include canonical routing/reference configuration, never credential values or their hashes.
- Key rotation alone does not change the fingerprint.
- Health indicates matching listener/configuration readiness, not Keychain accessibility or gateway success.
- Configuration loading, startup, health, status, activation and rollback perform no credential retrieval.
- Existing activation records remain usable. Activation continues to change only the provider base URL, preserving authentication, models and unrelated settings. Keychain unavailability must not prevent rollback.

Diagnostics retain their existing allowed identifiers, aliases, sources, timings, statuses and fixed errors. Exclude credential values, hashes or prefixes; Keychain references; subprocess output; raw headers/state; exception text; prompts and responses. Upstream content remains opaque rather than being newly inspected or redacted.

Global-token possession does not establish that a caller is a particular desktop chat. Existing local identity and title-marker trust limitations remain.

## 4. Acceptance criteria and validation

| ID | Acceptance criterion |
|---|---|
| **AC-01** | Strict optional configuration works as specified; legacy behavior and fingerprints remain compatible, with zero Keychain calls. Enabled readiness fingerprints are canonical and credential-free. |
| **AC-02** | Global mismatch and retrieval failure reject before observation, identity/project-key lookup and upstream forwarding. Health and control operations retrieve no credentials. |
| **AC-03** | A synthetic HTTPS upstream receives exact intended project credentials for Responses and compaction, using one common incoming global token. Tests cover alias sharing, ancestry, reassignment between requests, follow-up/fork state and overlapping streams. |
| **AC-04** | Missing mappings, absent/denied/locked items, timeouts, output overflow, invalid secrets, unsuccessful process outcomes and cancellation fail without upstream model calls. Healthy unrelated projects continue; no fallback or stale reuse occurs. |
| **AC-05** | Catalog and eligible unassigned-title requests retain verified caller authorization without project-key retrieval. Legacy/routing, observation and title-policy combinations preserve their respective contracts, including mapped priority and existing absence checks. |
| **AC-06** | Fresh lookups observe rotation/deletion; stale global tokens are rejected; pending children are cleaned up on cancellation or bounded failure. Active requests retain their selected snapshots. |
| **AC-07** | Transport regressions and sentinel tests verify credential selection, cancellation and privacy across normal and failure paths, including authorization named by `Connection`. Secrets remain absent from router output, fingerprints and committed material. |
| **AC-08** | Documentation and synthetic configuration explain manual provisioning, enablement, failures, rotation, trust limits and recovery. `npm test`, `node --check src/cli.js` and `git diff --check` pass, followed by sequential specification/quality review and actionable dispositions. |
| **AC-09** | Controlled desktop validation demonstrates distinct project keys, responses and automatic titles, overlapping requests, same-chat follow-up, reassignment and subsequent selection, followed by exact restoration, restart, a user-confirmed direct response and stopped listener. |

Synthetic tests use fake credentials, controlled process results and a local HTTPS upstream. They never retrieve actual credentials or contact the external gateway. Rotation and failure cases are synthetic; validation must not intentionally change real global/project keys.

For desktop validation:

- Use disposable projects A/B, distinct project keys and an explicit controller mapping.
- Keep the proxy in a separate Terminal session for restart resilience.
- Let the user provision Keychain items and perform required desktop interactions. Do not create or message chats through tools without explicit authorization.
- Checkpoint exact prior provider URL and private settings, including omitted properties. Keep actual references, mappings and runtime evidence outside Git.
- Exercise fork, saved subagent and compaction paths opportunistically; record unrun live cases explicitly. Their credential behavior remains required synthetic coverage.
- Record symbolic selection and transport evidence without claiming independent gateway billing attribution.
- Restore exact prior settings while preserving unrelated edits, restart as required, verify a direct response, then stop the proxy—even when validation fails.

Missing required actions or evidence leaves live validation incomplete. An observed incompatibility remains a failed capability and cannot be represented as supported.

## 5. Constraints and approval handoff

Work in the existing checkout. Do not update `main` or create the implementation branch before separate specification and plan approvals. Save both approved artifacts before product changes, then follow the supplied Git workflow. No worktree, push or merge is authorized.

Deferred work includes billing/account proof, stronger caller isolation, credential-management commands, additional secret backends, GUI, automatic startup, remote/cloud hosts, new identity inference or auxiliary policies, engine changes and continuation migration.

**Execution endpoint:** deliver, verify and review the approved credential-routing increment; report the working result, evidence and limitations; restore direct operation and exact prior settings; verify a direct response and stopped listener; then stop before subsequent increments.

**Approval record:** Stage 1 scope/design was approved by the user’s `confirmed` message. The user separately approved the presented DRAFT specification in the following `PLEASE IMPLEMENT THIS PLAN` message reproducing it, then separately approved the implementation plan in the later `PLEASE IMPLEMENT THIS PLAN` message reproducing that plan. Both artifacts are saved and APPROVED. Current stage: Stage 4 — implementation authorized for this increment.
