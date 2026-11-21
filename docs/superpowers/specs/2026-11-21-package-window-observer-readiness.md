# Package window observer readiness — specification

**Slug:** `package-window-observer-readiness`  
**Type:** bug  
**Status:** APPROVED  
**Created:** 2026-11-21  
**Updated:** 2026-11-21  
**Provenance:** Read-only investigation following the completed Keychain lookup fix; the test-only scope/design proposal and the user's subsequent “confirmed”. This draft was first presented in chat in Plan mode and subsequently saved in Default mode without changing its requirements.

## Problem and current behavior

The native package test launches the relocated app, verifies its synthetic instance lock, then starts a Swift process to observe its window. Swift startup can miss a brief valid window appearance.

Independent metadata observations saw the exact test predicate become true briefly while the test subsequently timed out. In one passing run, the observer's first sample arrived approximately 430 milliseconds after invocation, shortly before the window disappeared from the on-screen list.

This supports an observer startup race. The precise macOS mechanism behind the visibility transition remains unproven. The user reported that Codex was in full-screen mode.

## Desired outcome and approach

Prepare the window observer and receive an explicit readiness acknowledgement **before launching the synthetic app**. Once launched, supply the exact tracked child PID promptly so observation does not wait for instance-lock verification.

Readiness must establish that the observer is initialized and waiting for its target; merely spawning its process is insufficient.

Preserve the existing success condition: the exact native child has regular activation policy and an actual on-screen layer-0 window. Observing that condition once remains sufficient; sustained visibility is not a new requirement.

Use one absolute **20-second observation deadline**, beginning before observer startup. Readiness, target handoff and window observation consume that same budget. No phase renews it. Preserve the test's existing 60-second overall timeout.

The selected approach addresses the demonstrated ordering problem entirely within tests. Longer deadlines, fixed readiness sleeps, weaker window predicates and production startup changes are excluded.

**Wider direction:** This is a separate verification fix following the completed Keychain increment. Broader UI and distribution work remain provisional.

**Selected increment:** Deliver the observer-ordering correction, meaningful regression coverage, validation documentation, required review and authorized local commits.

**Uncertainty:** Verification must establish whether preparing the observer first resolves the observed failure under the existing desktop conditions. This specification does not claim that the correction is already proven.

## Acceptance criteria

- **AC-01 — Readiness ordering:** The real package test receives observer readiness before launching the relocated native app. Startup failure, premature observer exit or readiness timeout fails the test without launching that app.
- **AC-02 — Identity and predicate:** Observation targets only the exact tracked native child PID and retains both regular activation policy and the on-screen layer-0 window requirement. Another process, an off-screen window or an incorrect layer cannot satisfy it.
- **AC-03 — Deadline:** One absolute 20-second deadline covers observer startup through successful observation. Readiness and PID handoff cannot reset it. No fixed readiness delay, increased timeout, skip or fallback substitutes for the required condition.
- **AC-04 — Independent evidence:** Window observation starts promptly after target launch and can succeed while lock verification is pending. Overall test success still requires proof that the exact native child holds the synthetic `instance.lock`, plus all existing downstream assertions.
- **AC-05 — Failure and cleanup:** Native-child exit terminates pending observation promptly. Observer errors, malformed coordination, timeout and cleanup failures remain visible with bounded diagnostics. Every owned fixture process is reaped through the existing lifecycle machinery, and existing port-reuse checks remain effective.
- **AC-06 — Regression coverage:** Controlled event ordering demonstrates that an observer ready before launch can capture a transient valid condition without timing sleeps. Negative coverage verifies predicate rejection, readiness/observation expiry, early process exit and cleanup. Tests exercise the coordination used by the package test.
- **AC-07 — Integration verification:** Run the focused native package case, the complete isolated package suite and the standard parallel `npm test` suite. Report failures and skips explicitly. Serial runs remain diagnostic evidence and cannot replace the default parallel check.
- **AC-08 — Delivery evidence:** Record commands, results, relevant desktop conditions, cleanup evidence and limitations. Complete the required specification/quality review and authorized local commits before reporting delivery.

## Safeguards and exclusions

Retain the real relocated packaged app, signature verification, source-denial sandbox and negative controls, synthetic home/configuration/provider isolation, existing lifecycle assertions and owned-process cleanup.

No production Swift, UI startup, routing, assignment, account, Keychain or distribution behavior changes are included. No public interface, dependency or persistent state change is required.

Do not change macOS preferences, full-screen mode or Spaces. Do not quit or replace the user's canonical companion for this test-only increment. Avoid a general test framework or unrelated test cleanup.

Historical failures and prior passing checks remain recorded separately from verification of this future change. A failure after implementation must be investigated without silently weakening these requirements.

## Approval handoff

**Current stage: Stage 4 — implementation authorized.**

Artifact resolution found no existing specification or plan for this slug, including the exact legacy paths. The DRAFT was presented in chat, then saved and presented with its path for Stage 2 approval. The user's subsequent “approved” explicitly approved this specification and authorized planning only. The separate plan was then presented in full in Plan mode, Native execution selected, and the following “Please implement the plan” approved that plan. The approved plan is now saved at `docs/superpowers/plans/2026-11-21-package-window-observer-readiness.md` before implementation.

The separate specification and plan approvals authorize implementation through the repository's existing-checkout Git workflow. No worktree, push or merge is authorized.

**Execution endpoint:** Deliver only this test-observer fix with regression coverage, integration verification, documentation, required review and authorized local commits; report observed results and remaining limitations, then stop. No push, merge or worktree creation is authorized.
