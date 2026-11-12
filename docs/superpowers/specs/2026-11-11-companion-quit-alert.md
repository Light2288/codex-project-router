# Companion Quit behavior and blocked-Quit alert — specification

**Slug:** `companion-quit-alert`

**Type:** bug

**Status:** APPROVED

**Revision:** 2 — idle-direct Quit exception; approved 2026-11-12

**Created:** 2026-11-11

**Updated:** 2026-11-12

**Provenance:** Revision of this same specification and increment, not a replacement pair. The original alert-only scope was confirmed by `confirmed`, and its presented specification approved by `approved`, on 2026-11-11; its separate plan was approved on 2026-11-12. Those approvals authorized the implementation already present on `fix/companion-quit-alert`. After native testing the user questioned requiring restart/response confirmation merely to close an idle companion. The assistant proposed normal Quit for the verified idle direct state, preserving pending recovery, while retaining running-proxy protection. The user confirmed that direction on 2026-11-12: `ok, resolve that Quit behavior before refining the alert`. This confirms the revised scope/design and authorizes this DRAFT only. It does not approve this revision or its affected implementation plan.

The completed prerequisite artifacts `docs/superpowers/specs/2026-11-11-companion-operational-controls.md`, its matching plan and `docs/validation/companion-operational-controls.md` remain historical inputs. The previously approved version of this specification and plan remains in Git history. **Revision 2 approval:** After this revised DRAFT was presented, the user replied `approved` on 2026-11-12. That approval authorizes revision of `docs/superpowers/plans/2026-11-11-companion-quit-alert.md` only; the affected plan requires its own renewed approval before implementing the new Quit exception. Original approvals and implementation history remain preserved.

## Problem and current behavior

The companion currently refuses Quit whenever a pending recovery/confirmation obligation remains, including when direct settings are verified on disk and no owned router or mutating operation remains. Its native alert names the pending check, but instructing a user to restart Codex and generate a response merely to close this idle app is unnecessarily restrictive.

That check originally protects shutdown of an owned listener that a running Codex process may still use. Direct settings on disk do not establish what Codex has loaded. When the companion has no owned listener to stop, preserving pending information does not require keeping the UI process alive.

At inspected HEAD `54b6018` on `fix/companion-quit-alert`, the controller owns Quit/stop authorization and a read-only blocking reason; the app's common menu/keyboard/application Quit path presents one fixed native alert after denial. Recorded checks for that implementation are 85 native tests, 664 Node tests, a fresh signed build and three package tests. Those are prior observed results, not verification of the new behavior. Independent task reviews passed; the final integrated specification/quality gate has not run.

The user confirmed native Escape dismisses the alert while Controls stays minimized. Closed-window preservation has not been separately confirmed by an explicit user report. The synthetic fixture is cleaned up. Why an earlier direct confirmation reopened remains unestablished.

## Selected increment and desired outcome

The wider direction remains a convenient, recoverable companion. This revision keeps the existing alert increment together and first fixes the overly strict idle Quit rule. Alert wording and navigation refinement wait until this behavior is settled and verified.

**Outcome:** An idle companion can quit normally without a Codex restart, model prompt or manual response confirmation when fresh evidence verifies the direct state and no owned router or unfinished/uncertain mutating operation needs protection. Pending recovery/confirmation information survives unchanged for the next launch. An owned listener that Codex may still depend on retains its existing protection.

This is a narrow permission addition. Existing permitted exits, initialization-failure and second-instance safe exits remain permitted. It is not an unconditional Quit override and adds no Quit Anyway action.

## Quit permission and evidence

The additional idle exit applies only after the existing Quit flow obtains fresh evidence showing all of the following:

- No owned router remains. A retained process handle whose exit has not been established does not count as absence.
- No controller mutation or child-stop operation is in progress, and neither current backend evidence nor copied controller evidence retains an unfinished/uncertain mutation requiring reconciliation.
- The selected configuration and inspected activation context match the retained recovery context, including canonical configuration path, Codex home, provider and listener port.
- Provider settings are direct, recovery-required is false, the activation record is absent or restored, and the inspection has a usable revision. Unreadable, conflicting, routed, prepared or mismatched evidence does not qualify.
- Any pending recovery information to retain has a valid durable private journal consistent with that context. A failed persistence operation leaving the only recovery obligation in memory does not qualify; quitting must not silently lose that obligation.

Fresh permission is required at the action boundary. A prior display value, healthy listener, cached permission or pending-phase name alone cannot authorize the exception. Existing normal exits outside this added exception retain their established behavior.

| State at Quit | Required result |
|---|---|
| Verified idle direct state above, with pending confirmation/recovery | Quit normally, without blocked alert or new acknowledgement. Preserve pending information; do not require a restart or response check. |
| Owned router remains | Apply existing stop/Quit safeguards. After activation or imported dependency, retain it until the existing direct recovery and user confirmation requirements permit shutdown. Preserve the existing start-only direct-session exception. |
| A mutating operation is active or uncertain | Retain the existing wait/reconciliation guard. The idle exception cannot bypass it, including when the backend flag is newer than the copied flag. |
| Pending recovery with unavailable/conflicting/non-direct/context-mismatched evidence, or unsafe/unpreserved journal | Do not use the new exception. Keep existing guarded recovery behavior and truthful blocked feedback. |
| Existing normal safe exit, initialization failure or second instance | Preserve the existing permitted exit, without a blocked alert. |

Quit must not activate, restore, rewrite provider/router settings, confirm a response, delete recovery evidence or adopt/stop an external listener as a way to manufacture eligibility. The existing authorized owned-child stop within Quit remains available under its unchanged rules.

## Recovery persistence and truthful status

Allowing this additional exit does not clear the pending journal, mark desktop confirmation complete, or report that Codex has loaded direct settings. The existing user-confirmation action remains the authority for recording a reported working direct response.

Preserve the valid private pending journal and its original bound context across Quit and relaunch. On relaunch, inspect normally and display the retained check/recovery as pending, with desktop-loaded state unknown. Do not automatically start/activate a router, reroute traffic or discard pending state. The same verified idle state may quit again without repeating a check solely to close the companion.

Repeated status refreshes and a successful idle Quit do not consume confirmation. Existing UI guidance must accurately distinguish a pending check from permission to exit: it must not say that the check is mandatory before Quit when this new idle exception applies. Necessary conditional guidance changes are within this behavior correction; general alert wording and navigation redesign remain deferred.

## Existing blocked-Quit feedback and safeguards

Retain the implemented native alert for attempts that remain denied. It must be visible with Controls open, closed or minimized. Its current title is **Cannot quit yet**, and actions are **Open Controls** and **Keep Running**. For a guarded direct-confirmation case that still retains an owned router, retain the current description:

> Direct-response confirmation is pending. Open Controls to complete the check.

The newly eligible no-owned-router direct case must exit without showing this alert. Other denied states keep fixed sanitized guidance for operation/reconciliation, direct recovery or unavailable/conflicting evidence, with active/uncertain operation taking priority over later recovery advice. An unavailable persistence/context condition must not be described as resolvable merely by accepting a response confirmation.

Open Controls reveals the existing window with its normal refresh behavior. Keep Running/Escape dismisses without changing window visibility or retrying Quit. Alert actions do not confirm, clear recovery or perform routing mutations. Closing Controls still leaves the app running.

Preserve one request/alert at a time across asynchronous work and the native modal loop. Repeated requests cannot queue cleanup or dialogs. A state change while an alert is visible does not automatically retry Quit or exit; a new explicit request is required. A permitted exit shows no blocked alert.

Use fixed sanitized messages. No private paths, project IDs/mappings, endpoint configuration, credentials/references, raw output or exceptions may enter committed diagnostics or alert text.

## Acceptance criteria

Existing IDs are retained; their revised requirements explicitly supersede only the affected original alert-only requirements after renewed approval.

| ID | Verifiable outcome |
|---|---|
| **AC-01** | Denied menu, keyboard and application Quit share the native blocked feedback, visible with Controls open, closed or minimized. The new eligible idle direct case uses those same entry points and exits without an alert or extra acknowledgement. |
| **AC-02** | With valid pending recovery, fresh matching clean-direct evidence, no owned router and no unfinished/uncertain mutation, explicit Quit succeeds without restarting Codex, generating a response or confirming one. Cached evidence alone cannot authorize it. |
| **AC-03** | Remaining denied states retain truthful, sanitized guidance and operation/reconciliation priority. Context/storage failures cannot be bypassed by the idle exception or misrepresented as a response-confirmation task. |
| **AC-04** | Existing alert actions and native cancel keep their documented behavior; neither mutates recovery/routing or retries Quit. Window close still leaves the app running. No alert-label/navigation redesign is implemented in this revision. |
| **AC-05** | Existing normal, initialization-failure and second-instance exits remain permitted. Owned-listener stop/Quit rules, direct-only start exception, context binding and helper-uncertainty safeguards remain intact. The only added permission is the defined idle direct exit. |
| **AC-06** | Repeated Quit requests do not duplicate cleanup/dialogs. Becoming eligible while an alert is open does not cause automatic exit/retry. A later explicit Quit uses fresh evidence. |
| **AC-07** | Focused behavior regressions, affected native checks, existing Node regressions and fresh build/package verification pass. Isolated native observation demonstrates pending-direct/no-owned-router Quit without a Codex restart, prompt or confirmation, and confirms the retained journal. Documentation explains idle exit separately from listener shutdown. Prior alert evidence retains its attribution/limits. |
| **AC-08** | Complete the required final sequential specification then quality review for the whole increment, including already implemented alert code and this correction. Preserve dispositions and report the working result, evidence and limitations, then stop. |
| **AC-09** | Successful idle Quit preserves valid pending-journal contents/context and does not mark direct response confirmed or change provider/router files. Relaunch retains pending/unknown desktop state and performs no automatic routing action. Memory-only/unsafe recovery evidence cannot be silently lost through the new permission. |
| **AC-10** | Missing revision, inspection failure, context/path/home/provider/port changes, routed/prepared/conflicting state, live or copied mutation uncertainty, and a retained owned child do not qualify for the new exception. Existing guidance does not falsely require confirmation solely to close an eligible idle companion. |

## Edge cases and verification boundary

Cover a pending journal from a previous launch, repeated eligible idle launches/quits, unexpected child exit followed by verified direct/no-owned state, and prior recovery/confirmation phases whose matching settings are now verifiably direct. Do not authorize from the phase label alone. Cover memory-only persistence failure, unreadable/conflicting private state, stale pre-action inspection, live backend uncertainty and a child still awaiting verified exit.

Synthetic tests must prove permission, no confirmation/provider/journal mutation, durable recovery retention and continued owned-listener protection. Use temporary private state and positively tracked processes. No real activation, private operational configuration changes, gateway calls, Keychain access, Codex restart or model prompt is needed. An isolated fixture may hold synthetic pending state; never recreate it in the user's real configuration for demonstration. Record observations separately from automated claims and preserve the historical validation qualifications.

## Constraints, deferred work and notes

- Stage 2 revision only: save this DRAFT uncommitted. Do not revise the implementation plan before specification approval, or change product code before separate revised-plan approval. Use the existing checkout/branch; preserve prior work and commits. No main update, new branch, worktree, push or merge during this stage.
- Keep the native app, installed Node requirement, private configuration schema, authentication and routing behavior. Do not alter the completed prerequisite artifacts; this DRAFT explicitly describes its proposed narrow departure from the earlier blanket pending-confirmation Quit guard.
- Defer general alert wording/button refinement and step navigation. The user's accepted preference **Show steps to quit** is retained for that later discussion, not silently discarded or implemented now. The rejected restart-instructions description is not adopted.
- Defer unconditional exit for routed/unreadable/conflicting recovery, leaving an owned proxy running independently, supervision/startup, automatic Codex restart/prompts, why confirmation reopened, account/default/assignment editing and general UI redesign.
- This outcome resolves whether an idle companion can close while keeping pending recovery information. It does not verify settings loaded by Codex, establish why a confirmation reopened, or prove a running proxy can always be shut down without disruption.

**Execution endpoint:** Deliver and verify the defined idle direct Quit behavior with durable pending-state retention, existing listener/alert safeguards, necessary conditional guidance and documentation, fresh checks/native evidence and the whole-increment sequential final review; report results and limitations, then stop before general alert refinement or integration.

**Current stage:** Stage 4 — revision 2 specification and separately presented revised implementation plan explicitly approved on 2026-11-12. Implement Tasks 3–5 using the preserved Subagent-driven method.
