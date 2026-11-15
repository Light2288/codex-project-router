# Companion Dock presence — specification

**Slug:** `companion-dock-presence`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-14

**Updated:** 2026-11-14

**Provenance:** After discussing the companion's menu-bar-only lifecycle, the assistant recommended showing the navy Dock icon while controls are open, hiding it after controls close, retaining the menu-bar item, and preserving guarded Quit. The user's “ok, implement this” confirmed that scope and design. The DRAFT specification was then saved and presented separately; the user's subsequent “approved” explicitly approves this specification and authorizes implementation planning only. Builds on the existing local branding integration; the earlier branding specification, plan, and pending review retain their original scope and history.

## Problem and current behavior

The controls window opens at launch, but the companion remains absent from the
Dock and Command-Tab because its bundle declares `LSUIElement = true` and the
application never changes its activation policy. This makes an open window
harder to find despite the newly bundled navy app icon.

`RouterAppDelegate` owns one reusable controls window. Opening, application
reopening, and recovery guidance converge on its existing window-opening path.
Closing controls preserves the app and owned router. Account setup can refuse
closure while saving. Native application termination already enters the guarded
Quit flow.

## Desired outcome and delivery boundary

The wider direction is a discoverable native companion that can continue routing
in the background. This increment delivers conditional Dock and Command-Tab
presence for its existing controls window, with the existing navy app icon.

Use AppKit activation policy at runtime: regular application presence while
controls are open, and accessory presence after an allowed close. Retain the
bundle's `LSUIElement` declaration for initial background identity. The existing
launch behavior still opens controls and therefore brings the app into the Dock.

The menu-bar item remains available throughout. Closing controls keeps the
controller and owned listener running. Window presentation does not start, stop,
activate, restore, or change routing.

### Window and application behavior

| Event or state | Expected behavior |
| --- | --- |
| Launch opens controls | Show the navy Dock icon and participate in Command-Tab; raise controls through the existing path. |
| Menu-bar Open controls, application reopen, or Show steps to quit | Reuse and raise the existing window, restore it from minimization when needed, and ensure regular application presence. |
| Controls close successfully | Remove the running app's Dock/Command-Tab presence and keep the menu-bar item and background operation. |
| Account setup refuses closure | Keep controls and regular application presence. |
| Controls minimize or the app hides | Keep regular application presence because the window remains open; preserve ordinary macOS restore/unhide behavior. |
| Another window or sheet closes | Keep presence consistent with the controls window; an unrelated close cannot demote the app. |
| Dock Quit or another native termination request | Enter existing guarded Quit; a denied request keeps the app and listener running and preserves the existing recovery alert and navigation. |

Minimization and hiding are explicitly treated as open-window states. This is a
design detail chosen to preserve standard macOS window recovery. Repeated
opening and closing must remain stable and must not create duplicate windows or
menu-bar items. Dock presentation follows macOS user preferences, including any
user-pinned or recent-app icons; this feature controls the running app's policy,
not the user's Dock configuration.

## Approaches

The user selected conditional Dock presence after the recommendation in chat.
Runtime AppKit activation policy fits the existing AppKit-owned window and
retains the background menu-bar role. Permanent regular application presence
would keep the Dock item after closing; retaining the current accessory policy
would preserve the window-discovery problem. Neither matches the selected
behavior.

## Acceptance criteria

| ID | Verifiable outcome |
| --- | --- |
| **AC-01** | A fresh built app opening controls uses regular application presence, displays the bundled navy Dock icon, and is available through Command-Tab. |
| **AC-02** | An allowed controls-window close returns to accessory presence while preserving the app, menu-bar item, owned listener, routing mode, and saved configuration. Closing the last window does not request Quit. |
| **AC-03** | A refused controls close during account setup leaves regular presence intact. Unrelated window/sheet closure cannot hide an open controls window's Dock presence. |
| **AC-04** | Minimizing or hiding retains regular presence; restoring or reopening reuses the controls window and restores normal foreground interaction. |
| **AC-05** | Launch, menu-bar opening, application reopening, and recovery-guidance opening all use the same presence behavior. Repeated open/close cycles produce one controls window and one menu-bar item. |
| **AC-06** | Dock/native Quit uses the current termination guard. Denied Quit preserves the app and listener; allowed Quit requires the existing fresh authorization. Existing account-save, recovery, and duplicate-Quit safeguards continue to pass. |
| **AC-07** | Relevant native regressions, fresh build, package/signature/relocation checks, and final specification/quality review pass. Native observation checks Dock/Command-Tab/open/close/reopen/minimization using isolated state; automated evidence and anything unobserved are labeled separately. |
| **AC-08** | Companion documentation explains temporary Dock presence, the distinction between close and Quit, and persistent menu-bar/background operation. |

## Safeguards, uncertainty, and verification

The remaining uncertainty is macOS behavior when changing activation policy in
this SwiftUI menu-bar app, including window focus and reopening. Native
observation and regression coverage must establish those transitions. Policy
changes must use native API results responsibly and provide contextual diagnostics
for a failure rather than silently treating it as success.

Use existing SwiftUI/AppKit, XCTest, and packaging infrastructure. Preserve
window dimensions, polling cadence, refresh, keyboard/accessibility behavior,
account setup dismissal guards, Quit serialization, and recovery navigation.
Tests and native observation use synthetic state and owned processes. Do not
replace, quit, or reconfigure the user's running companion or touch real
credentials/provider configuration for verification. Any visual check that
cannot be observed safely must be reported as unobserved.

## Constraints and out of scope

No routing, credential, configuration-schema, or public CLI changes are needed.
No new runtime dependency, icon redesign, preference switch, Dock badge, extra
window, permanent Dock mode, login item, installation, release, push, or merge
belongs to this increment. These remain deferred rather than provisional tasks
to begin automatically.

Keep the existing local branding commits and historical artifacts intact. This
new scope intentionally changes the prior menu-bar-only lifecycle constraint;
it does not retroactively change that earlier specification. Follow the user's
existing-checkout Git workflow after separate specification and plan approvals.
Leave this artifact uncommitted until the implementation branch is established.

**Execution endpoint:** Deliver and locally commit conditional Dock presence,
its necessary integration, documentation, verification, and final review; report
the result and limits, then stop before installation or any later increment.

**Current stage:** Stage 4 — implementation complete. Separate specification
and plan approvals were recorded before product edits. Conditional Dock presence,
verification, documentation, and the integrated specification/quality review are
complete; see the [validation record](../../validation/companion-dock-presence.md).
The approved endpoint is reached: keep local commits and the existing checkout,
with no installation, push, merge, or later increment begun.
