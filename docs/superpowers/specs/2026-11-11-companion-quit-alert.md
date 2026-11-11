# Companion blocked-Quit alert — specification

**Slug:** `companion-quit-alert`

**Type:** bug

**Status:** APPROVED

**Created:** 2026-11-11

**Updated:** 2026-11-12

**Provenance:** User requested clearer feedback when pending confirmation prevents Quit, then replied `confirmed` to the alert-only Stage 1 proposal on 2026-11-11. Context: `docs/superpowers/specs/2026-11-11-companion-operational-controls.md`, its matching implementation plan, and `docs/validation/companion-operational-controls.md`. Those completed artifacts remain unchanged. Scope confirmation authorizes this DRAFT only.

**Specification approval:** After this DRAFT was presented, the user replied `approved` on 2026-11-11. That approval authorizes the separate Stage 3 implementation plan only. It does not authorize implementation.

## Problem and current behavior

The companion intentionally guards Quit while recovery or desktop confirmation remains unresolved. The application delegate routes menu Quit, keyboard Quit and application termination requests through the controller. If the request cannot complete, it currently opens Controls without presenting a dedicated alert. Explanatory text can be below the visible area, making Quit appear to do nothing.

The user encountered Direct on disk, no owned router and a stopped/empty listener, with direct-response confirmation pending again. Reapplying the user's reported direct confirmation allowed Quit. Why that confirmation reopened is unestablished; this increment does not diagnose or fix it.

Repository evidence is the completed companion at `c2887a5` on the local `feat/companion-operational-controls` branch. `RouterApp.swift` contains the common termination path; `RouterController.swift` owns authorization and recovery; `ControlsView.swift` already displays inline guidance. Existing app/core XCTest targets are available. Main must not be assumed to contain this unmerged companion work.

## Selected increment and desired outcome

The wider direction is a convenient, recoverable companion. This small increment makes an unsuccessful Quit understandable and provides an obvious route to the existing recovery controls.

Present a native macOS alert after the existing Quit attempt is denied. The alert explains the actual blocking condition and offers **Open Controls** and **Keep Running**. It must be visible when the control window is closed or minimized. Closing the control window continues to leave the app running.

For the observed clean-direct state with pending direct confirmation, use:

> **Cannot quit yet**
>
> Direct-response confirmation is pending. Open Controls to complete the check.
>
> **Open Controls** · **Keep Running**

Other denied states must use similarly short, fixed, actionable wording:

| Observed blocking condition | Required explanation and next step |
|---|---|
| Direct response confirmation pending, with readable direct settings | Explain that confirmation remains pending; direct the user to the existing manual restart/working-response check. Do not imply a router is running or require restoring a URL already direct. |
| Routing/recovery requires restoration before direct confirmation | Explain that direct recovery must be completed in Controls, including the existing manual restart/response confirmation where applicable. |
| An operation is still running or requires reconciliation | Explain that it must finish or be reconciled; direct the user to Controls and existing guidance. Do not prescribe blind retries or claim it is safe to quit. |
| Evidence/context is unavailable, conflicting, or otherwise cannot authorize Quit | Explain that safe Quit could not be confirmed and direct the user to Controls for the existing actionable error/recovery guidance. Avoid guessing which prerequisite succeeded. |

Exact wording outside the observed case is an author implementation choice within these requirements. Messages reflect the completed denied attempt's current state, prioritize an in-flight/uncertain operation over later recovery steps, and do not claim independent knowledge of settings loaded by Codex.

**Open Controls** dismisses the alert and opens or brings forward the existing control window. Its normal refresh/reconciliation behavior remains unchanged. **Keep Running**, including the native cancel/Escape action, dismisses the alert without retrying Quit or changing window visibility. Neither action directly accepts a response confirmation, clears recovery, or starts, activates, restores or stops routing. No **Quit Anyway** action is added.

## Approach and safeguards

A native alert in the existing common Quit flow is the selected approach. An additional inline hint would leave the feedback easy to miss; a general notification system would add unnecessary scope. Native presentation and minimal reason selection are implementation details; this specification does not prescribe new module boundaries or controller APIs.

The controller remains the authority for whether Quit succeeds. Preserve its existing reconciliation, authorized child-stop behavior, ownership checks, confirmation rules and initialization-failure/second-instance safe-exit exceptions. The alert is feedback after a denied attempt, not a new authorization rule. A successful Quit shows no blocked-Quit alert. It must not be delayed waiting for acknowledgement of such an alert.

Only one blocked-Quit alert may be presented at a time. Repeated Quit requests while the existing request or alert is in progress must not stack dialogs, queue duplicate operations or repeatedly stop children. Dismissing an alert never retries Quit automatically, even if state changed while it was visible.

Use fixed sanitized messages. Do not include private paths, project IDs/mappings, endpoints, credentials, references, raw subprocess output or raw exceptions. Existing detailed local recovery guidance stays in Controls.

## Acceptance criteria

| ID | Verifiable outcome |
|---|---|
| **AC-01** | A denied menu Quit or keyboard/application Quit presents the same native blocked-Quit feedback. It is visible with Controls open, closed or minimized; an unsuccessful attempt no longer relies solely on opening Controls. |
| **AC-02** | The observed direct-confirmation-pending state displays the specified title, message and two actions, without asserting that a router is running or that direct settings need restoring. |
| **AC-03** | Other denied states show truthful, sanitized, actionable guidance for recovery, operation/reconciliation, or unavailable/conflicting evidence, with the priority described above. |
| **AC-04** | Open Controls reveals the existing window; Keep Running/cancel dismisses without changing window visibility or retrying Quit. Neither action performs a confirmation or routing/recovery operation beyond existing normal window refresh behavior. |
| **AC-05** | Successful Quit, including existing safe initialization-failure and second-instance exits, shows no blocked alert. Window close retains its existing behavior. All prior Quit/stop/recovery authorization semantics remain intact. |
| **AC-06** | Repeated Quit requests cannot stack alerts or duplicate the existing Quit/stop operation; dismissing an alert cannot trigger an automatic retry or later automatic exit. |
| **AC-07** | Focused automated presentation/coordination regressions, affected native checks and a fresh app build/package verification pass. Appropriate existing regression checks remain required by the later plan. A manual native check demonstrates both actions and menu/keyboard entry with isolated synthetic blocked state, without live routing activation or real provider changes. Operational documentation explains the alert. |
| **AC-08** | Required final sequential specification and quality review is completed with dispositions. Report the working result, observed checks and remaining limits, then stop at this increment's endpoint. |

## Edge cases and verification boundary

Cover pending direct confirmation with no owned router, recovery that still retains an owned listener, uncertain/in-flight operations, unavailable context, repeated requests, state changes while the alert is visible, closed/minimized Controls, and permitted exit after failed initialization or a second-instance launch. Tests must distinguish alert presentation/actions from controller authorization and demonstrate no new confirmation or mutation side effects.

Use synthetic private state and positively tracked test processes. No real proxy activation, gateway calls, credential access, Codex restart or model prompt is needed for this increment. Do not recreate pending recovery in the user's real configuration merely to demonstrate the alert. Report automated and manual observations separately; do not promote the new alert into evidence that the earlier recurrence is fixed.

## Constraints, deferred work and notes

- Stage 2 only: save this DRAFT uncommitted; create no implementation plan or product changes before separate approvals. Preserve the existing checkout, local completed companion branch and all existing work. No main update, new implementation branch, worktree, push or merge in this stage.
- Keep the current native app, installed Node requirement, private configuration, routing schema and authentication behavior. Preserve existing operational and privacy safeguards.
- Defer any relaxation of Quit when no router remains, investigation of reopened confirmation, notification systems, general error-UI redesign, account/default/assignment editing, visibility and startup/supervision work. Later increments remain provisional.
- The outcome resolves whether users can see why Quit was denied and reach the existing next step. It does not establish why confirmation reopened or independently verify what Codex has loaded.

**Execution endpoint:** Deliver the native blocked-Quit alert with its two actions, focused safeguards/tests, build/package and manual native verification, documentation and required final review; report evidence and limitations, then stop before any later increment or integration action.

**Current stage:** Stage 4 — the specification and separately presented plan have received explicit approvals. Implementation of this increment is authorized; no push or merge is authorized.
