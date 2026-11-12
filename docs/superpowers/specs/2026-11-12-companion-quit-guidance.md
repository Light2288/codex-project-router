# Companion Quit dialog and guidance — specification

**Slug:** `companion-quit-guidance`

**Type:** bug

**Status:** APPROVED

**Created:** 2026-11-12

**Updated:** 2026-11-12

**Provenance:** Follow-up to the completed `docs/superpowers/specs/2026-11-11-companion-quit-alert.md`, its matching plan, and `docs/validation/companion-quit-alert.md`. Those artifacts remain historical records of the approved and verified idle-Quit correction. The user requested resuming the deferred dialog improvement after that correction. In native clarification the user selected **Focus existing controls** rather than a dedicated steps section. The presented scope/design included short blocker-specific descriptions, **Show steps to quit**, navigation/highlighting of existing controls, brief guidance, and preservation of cancellation and Quit safeguards. The user explicitly confirmed it with `scope/design confirmed`. That confirmation authorized the DRAFT only. After the DRAFT was saved and presented with its path in Stage 2, the user separately replied `approved`. Specification approval authorized the separate implementation plan only. After that plan was saved and presented in Stage 3, the user separately replied `approved`, authorizing implementation.

## Problem and current behavior

The wider companion direction is convenient, understandable and recoverable operation. The immediate problem is that a denied-Quit alert says **Open Controls**, including when the window is already open, without clearly locating the next action. Its descriptions use terms such as reconciliation and direct-response confirmation that do not explain the task plainly enough.

Inspected baseline: `f1e00832a000510043a02e6abce442a4d8ee473d` on `fix/companion-quit-alert`, clean before this specification. `QuitAlert.swift` supplies four fixed descriptions. `RouterApp.swift` reveals the existing window after the primary alert response; it has no targeted navigation. `ControlsView.swift` contains Setup, operational facts, router controls, manual response checks, and a collapsed manual-recovery disclosure in a scroll view.

The preceding increment already permits fresh verified idle Direct Quit with durable matching recovery information and no owned router, while retaining pending confirmation. It preserves owned-listener and uncertain-operation guards. Its recorded verification is 102 native tests, 664 Node tests, three package tests, a signed build, isolated native exit/relaunch, human closed-window cancellation, and final specification/quality reviews. These are baseline results, not fresh verification of this follow-up.

## Selected increment and desired outcome

Deliver a clear path from a genuinely denied Quit to the relevant existing action: a short explanation in the alert, followed by visible guidance and emphasis at the appropriate controls. This must work with the window open, closed, minimized, or scrolled elsewhere. The user still decides whether to perform any operation.

This increment resolves whether the remaining blocked cases tell the user what to do next without reinstating the removed idle-app confirmation requirement. Necessary delivery includes navigation, accessible emphasis, behavior tests, isolated native/usability checks, documentation and sequential final review.

**Approaches considered:** A dedicated **Steps to quit** section would gather instructions in one place but introduce another area of the window. The user chose focusing existing controls, which keeps guidance next to the actions already available. Implement this choice without a separate steps panel, wizard, or duplicate recovery controls.

## Dialog content

Keep the warning title **Cannot quit yet**. Use **Show steps to quit** as the first action and Return default, and **Keep Running** as the second action and Escape/cancel binding. No additional alert action is introduced.

The proposed exact descriptions for specification approval are:

| Existing blocker | Description |
|---|---|
| Direct confirmation pending, owned router retained | **Codex may still need the router. Check the direct connection before quitting.** |
| Direct confirmation pending, no owned router | **Quit needs a fresh check of the saved recovery information. Review the status, then try Quit again.** |
| Operation in progress or uncertain | **A router operation is running or needs checking. Review its status before quitting.** |
| Direct recovery required | **The app still needs to restore the direct connection before it can quit.** |
| Context or saved recovery information unavailable/inconsistent | **The app cannot check that quitting is safe. Review its status and recovery instructions.** |

The alert uses the actual denied attempt's reason and ownership, with existing operation/uncertainty priority. The no-owned-router variant covers a pending result that still needs another explicit action-time check, for example after child exit during the attempt; it must not demand a manual response check. Keep text stable during that one modal interaction. A permitted Quit continues to exit without showing this alert.

## Guidance at existing controls

**Show steps to quit** dismisses the alert, reveals/raises and, if necessary, deminimizes the existing window. Retain ordinary window refresh behavior. Using current controller evidence after that refresh, bring the relevant existing controls into view, visibly emphasize the target, and place the corresponding brief guidance next to it. Apply the same behavior when the window is already open. Do not create another window or require the user to search for the target.

| Current situation | Existing destination and brief guidance |
|---|---|
| Operation still running or uncertain | Operational status and **Refresh**: **Click Refresh to check the operation. Wait while it is running; use the recovery instructions if it cannot finish.** |
| Direct-confirmation guard still applies to an owned router | Manual response-check group, emphasizing its existing direct-response confirmation button: **Quit and reopen Codex, then send a message. After a working reply, click the direct-response confirmation below and choose Quit again. Keep the router running until then.** |
| Direct recovery required, owned router retained | Existing **Restore direct** button: **Click Restore direct. Keep the router running while you restart Codex and verify a reply; then confirm the direct response below and choose Quit again.** |
| Direct recovery required, no owned router | Existing **Restore direct** button: **Click Restore direct, then choose Quit again. Quit will check the saved settings and recovery information.** |
| Unavailable/inconsistent context or recovery information | Existing manual-recovery disclosure, expanded when present; otherwise existing Setup/status and **Refresh**: **Click Refresh and review any recovery instructions shown. Choose Quit again after the problem is resolved.** |
| Owned router now meets the existing safe Stop condition | Existing **Stop owned router** button: **Choose Quit again to recheck and close the app, or use Stop owned router first.** |
| No owned router and matching clean Direct evidence now exists, with no current operation or unavailable-evidence blocker | Existing operational facts and idle-Quit guidance: **Choose Quit again to check the saved recovery information. A pending response check can stay saved while this idle app is closed.** |
| Controller now permits normal Quit | Existing operational facts: **The previous blocker has cleared. Choose Quit again.** |

Current operation/uncertainty takes priority. Next recognize an existing normal Quit permission or existing safe Stop permission as the cleared/advanced cases in the table. For remaining cases, unavailable-evidence blockers precede confirmation or idle guidance. If confirmation or restoration is disabled by the current context, show the applicable status/recovery destination rather than instructing the user to press a disabled button. If relevant context disappears, use the unavailable-evidence destination. Do not infer safe exit or desktop-loaded settings from listener readiness, Direct on disk, or a stale reason alone.

The no-owned-router Direct guidance requests another explicit Quit check; it does not authorize exit or promise that durable recovery information is valid. In particular, an unavailable journal must not be presented as a response-confirmation task. An owned router that still needs protection retains the existing manual restart/working-response requirement.

Emphasis must be readable without relying only on color and usable with keyboard/accessibility navigation. Showing guidance must not turn a routing or confirmation button into an automatically invoked/default action. Guidance is transient window presentation, not saved configuration or journal state. Keep it visible while relevant; discard it when the window closes. A new explicit **Show steps to quit** request navigates again even if its target is unchanged.

## State changes and side effects

The destination and text must reflect current evidence, including changes while the alert was open. Do not replay stale restart instructions after the app becomes an idle Direct candidate or after the existing safe Stop/normal Quit condition applies. When evidence changes after guidance is shown, update or withdraw obsolete instructions/emphasis; routine polling must not repeatedly steal focus or scroll the window. Only an explicit guidance request initiates that navigation.

Guidance does not retry Quit, grant permission, restore settings, start/stop/adopt a listener, record response confirmation, or clear recovery. Retain existing refresh/reconciliation behavior; do not add a new permission check or private-store read to presentation getters. The existing controller remains the authority for operations and fresh action-time verification.

**Keep Running**, Escape, abort and cancellation dismiss without navigation, window reveal, recovery mutation or Quit retry. Preserve closed and minimized windows. Closing the main window still leaves the companion running. Preserve one in-flight Quit/alert, reentrant-request protection and explicit retry requirements when state becomes safe during a dialog.

## Acceptance criteria

| ID | Verifiable outcome |
|---|---|
| **AC-01** | A denied Quit uses the specified title, exact blocker description and **Show steps to quit** / **Keep Running** labels with Return/Escape bindings. All menu, keyboard and application Quit entry points retain the common flow; permitted exits show no alert. |
| **AC-02** | The primary action reveals the existing window and brings the appropriate current destination into view with visible emphasis and brief guidance, including when already open or scrolled elsewhere. Manual recovery expands when it is the destination. No separate steps section/window is added. |
| **AC-03** | Guidance follows the table and current permissions, distinguishes owned recovery from no-owned-router idle Direct, and never tells the eligible idle user to restart Codex or confirm a response merely to close the app. Disabled/unavailable operations fall back to truthful status/recovery guidance. |
| **AC-04** | State changes while an alert or guidance is visible do not produce stale confirmation instructions, automatic retry/exit, routing operation, or lost recovery. Ordinary polling does not repeat navigation; a later explicit guidance request works again. |
| **AC-05** | Keep Running/Escape/cancel/abort preserve window visibility and perform no guidance action or retry. Main-window close leaves the app running. Repeated and reentrant Quit requests remain coordinated. |
| **AC-06** | Guidance is transient, readable without color alone and keyboard/accessibility usable. It disappears on window close and does not make a routing/confirmation action the default or invoke one. |
| **AC-07** | Existing Quit, Stop, idle durable-evidence, context binding, uncertainty and safe-exception behavior remain intact. Presentation adds no authorization or private-store reads and does not itself change routing/confirmation; existing refresh/reconciliation and controller actions remain authoritative. |
| **AC-08** | All new dialog and inline messages are fixed sanitized text. Do not interpolate private paths, project IDs/mappings, destinations, credentials/references or raw exceptions/output into them. Existing locally displayed operational facts remain private UI data. |
| **AC-09** | Focused behavioral regressions and affected existing native tests pass, followed by the repository's relevant Node, fresh signed build/package, syntax and whitespace checks. Isolated native observation establishes navigation with open/closed/minimized/scrolled windows and cancellation visibility; record actual evidence and its limits. |
| **AC-10** | Update companion documentation and a sanitized follow-up validation report, preserve predecessor history, and pass sequential final specification then quality review. Report the delivered outcome and limits, then stop. |

## Edge cases and verification boundary

Cover every blocker and both ownership branches for restoration, live uncertainty newer than the displayed state, unavailable journal/context, destination disappearing, safe Stop or idle Direct becoming available while the modal is held, an already visible target, repeated identical guidance requests, ordinary polling, and close/reopen of a guided window. Exercise real controller/delegate boundaries with synthetic dependencies; test behavior rather than source-text matching.

Use temporary owner-only journals/configuration and positively tracked native processes. No real private configuration change, Keychain access, gateway/model request, Codex restart or operational activation is required for verification. A confined synthetic listener may be used only when necessary to demonstrate an owned-router case. Preserve the predecessor's safeguards and historical failed-validation qualifications. Native tools that activate/reopen windows cannot establish cancellation visibility; use attributed human observation when necessary, as in the preceding report.

## Constraints, deferred work and notes

- The increment is a focused UI correction with the existing SwiftUI/AppKit companion and controller. No backend, private schema, authentication, routing policy or Quit-permission change is authorized by this specification.
- Keep the main menu-bar **Open controls…** action and ordinary navigation behavior. General terminology/layout redesign, a dedicated steps panel/wizard, automatic recovery, unconditional Quit, detached/supervised listeners, startup integration, account/default/assignment editing and confirmation-reopening diagnosis remain deferred.
- This follow-up explicitly supersedes the predecessor's fixed alert copy/primary-action presentation only after this specification and its separate plan are approved. The completed predecessor artifacts and reports are not rewritten or invalidated.
- Current pair resolution: specification MISSING and plan MISSING before this draft, with no legacy/conflicting candidate. New canonical specification path is `docs/superpowers/specs/2026-11-12-companion-quit-guidance.md`; its matching plan is not created in Stage 2. No material product decision remains unresolved; proposed exact copy above is subject to this specification approval.
- Preserve the existing checkout and local work. Keep this DRAFT uncommitted. Do not update main, create an implementation branch/worktree, modify product code or operational settings, push or merge during specification approval.

**Execution endpoint:** Deliver the clearer blocked-Quit dialog and targeted guidance at existing controls, with preserved permission/cancellation safeguards, documentation, fresh automated/native verification and sequential final review; report results and limitations, then stop before broader UI work or integration.

**Current stage:** Stage 4 complete — implemented after separate scope/design, specification and plan approvals. Fresh automated acceptance, isolated native observations (including attributed human visibility checks), independent task reviews and the sole final sequential specification/quality gate passed. See `docs/validation/companion-quit-guidance.md`. Stop before broader companion work or integration; keep the existing branch and checkout.
