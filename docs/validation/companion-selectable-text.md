# Companion selectable text validation

**Created:** 2026-11-24  
**Updated:** 2026-11-24  
**Slug:** `companion-selectable-text`  
**Spec:** [Approved specification](../superpowers/specs/2026-11-23-companion-selectable-text.md)  
**Plan:** [Approved implementation plan](../superpowers/plans/2026-11-23-companion-selectable-text.md)

## Delivered behavior

Passive informational text in ControlsView, ProjectListView, AccountSetupView,
and ProjectAssignmentView uses native SwiftUI selection. Interactive labels keep
their existing behavior. Activation and blocked-Quit alerts already support native
selection and remain unchanged. Configuration-destination instructions now use a
440-point wrapping, selectable, read-only NSTextField accessory; the message,
file types, title, suggested filename, and completion block retain their meaning
and behavior. No router, storage, credential, or keyboard-interception code changed.

## Environment and observed commands

Apple silicon; macOS 27.2.1 (26B131), Apple Swift 6.4.2, Node v24.21.0.
Commands ran sequentially in the existing checkout on
`feat/companion-selectable-text`, based on
`46de00ef5be3a3d4b458e0036133dfb559d57b12`. No worktree, push, or merge.

| Command / checkpoint | Exit | Observed proof |
|---|---:|---|
| `npm run companion:test` — baseline | 0 | 279 core + 115 application tests, zero failures |
| `npm run companion:test` — Task 1 RED | 1 | New copying cases fail at unavailable selection in heading, project, account, and assignment text; fixture issues were corrected before GREEN |
| `npm run companion:test` — Task 1 GREEN | 0 | 279 core + 120 application tests, zero failures |
| `npm run companion:test` — Task 2 RED | 1 | 279 core pass; 123 application tests with exactly one failure: destination instructions absent from local selectable text tree; alert cases pass |
| `npm run companion:test` — Task 2 product state | 0 | `Executed 279 tests, with 0 failures`; `Executed 123 tests, with 0 failures` (402 total) |
| Native Save confirmation check — review remedy | 0 | Real accessibility Save action invokes the callback; selected URL matches; no file, commit, activation, or start |
| `npm run companion:test` — final review coverage | 0 | 279 core + 124 application tests (403), zero failures; native Save acceptance passed, no skips |
| `npm run companion:build` | 0 | `Built and ad-hoc signed dist/Codex Project Router.app` |
| `npm run companion:package-test` | 0 | 31 tests; 31 pass, 0 fail |
| `npm test` | 0 | 1,123 tests; 1,123 pass, 0 fail |
| `git diff --check` | 0 | No whitespace errors |

The Swift Testing footer reports zero tests because these suites use XCTest;
the XCTest counts above are the decisive results. The final review coverage adds a native Save regression without changing product
code. Build, packaging, and repository-suite evidence applies to the unchanged
product state.

## Native interaction evidence

| Criteria | Checks and observations |
|---|---|
| AC-01 | Main heading/status, project name, details, and empty-state text copy exactly. Copying leaves backend mutation counters unchanged. |
| AC-02 | Account guidance/metadata and assignment guidance/warning/error copy exactly. Existing sheet/action tests continue to pass. |
| AC-03 | Actual SwiftUI activation alert and NSAlert blocked-Quit heading/body selections copy without dismissal. All four blocked-Quit reasons, including both ownership variants for pending confirmation, are covered. Escape cancels; Return retains the primary response. Activation occurs only after Return, once. Existing delegate tests retain termination/recovery safeguards. |
| AC-04 | The real destination panel's owned accessory copies its complete message. The JSON filter and directory-creation option remain enabled. Escape closes the panel without changing selected configuration or creating a file. A separate native accessibility check edits the real Save As field and presses the real Save button. The actual completion callback selects the expected nonexistent synthetic filename in the panel's displayed directory, creates no file, and leaves commit/activation/start counters at zero. |
| AC-05 | Complete `café 🧭\nstatus — ready` block and its compass substring copy exactly with correct UTF-16 selection ranges. Native informational fields are selectable and read-only; SwiftUI text retains native read-only rendering. |
| AC-06 | Entered `SYNTHETIC_SELECTION_KEY` into the actual NSSecureTextField editor. Attempted Copy and accessibility traversal do not expose it. Moving focus to guidance and choosing existing-item entry retains concealment and secret-clearing behavior. Synthetic native-key creation and configuration commit counters stay zero. |
| AC-07 | Search editing/clearing, Details/Edit/Refresh actions, account-entry controls, alert Return/Escape, and destination Escape run alongside selected text. Existing picker/disclosure/action regressions pass. Control labels and SecureField receive no selection modifier. |
| AC-08 | Unchanged controller refresh preserves selected text in both main controls and project rows. Long guidance/warnings retain wrapping and scrolling; the accessory's full fitting height is available. |
| AC-09 | Tests select rendered text and dispatch a native ⌘C menu key equivalent to the window's selected first responder. Clipboard results come from native Copy, never from writing the expected string. All covered surface types have real selection/clipboard evidence. |

The test-only NativeClipboard fixture snapshots original pasteboard data in memory
and restores it and the original application menu on exit. Original clipboard
contents are never logged or saved. Only synthetic keys and synthetic setup state
are used. Existing private configuration and real credentials are not modified. The broader
repository suite also runs its established native Keychain harness using owned
scratch items, with cleanup verified by that harness.

The XCTest host does not run the SwiftUI App scene, so it installs standard Edit
commands for native menu validation/Copy dispatch. A separately compiled synthetic
MenuBarExtra scene confirmed that the production scene supplies Copy, Cut, Paste,
and Select All automatically. No production menu change is needed.

## Visual observations and limits

Inspected native cached snapshots of controls, account setup, assignment error,
activation, blocked Quit, and the selected destination accessory. Selected text is
visible; warning/error emphasis and surrounding layout remain intact. The complete
destination message fits in three wrapped lines. Existing scrolling keeps longer
controls/account content reachable. Native alert snapshots omit some composited
button glyphs/backgrounds; their labels and actions are verified through AppKit
interaction tests rather than inferred from those incomplete snapshots.

These are native in-process selection, clipboard, responder, and menu tests.
External OS-event injection into the rebuilt packaged app, real mouse dragging,
and testing on macOS 14 are **unobserved**.

AppKit hosts the destination accessory in a local NSAccessoryViewWindow beside its
remote file browser. Copying uses that actual owned field. Native Save confirmation
uses public Accessibility identifiers and actions on the real filename field and
Save button, with no private remote-view access or simulated completion. That check
requires existing Accessibility access and skips explicitly if it is absent;
**it ran and passed on this Mac**. The test chooses a unique nonexistent filename
in the panel's displayed directory and verifies that selection creates no file.
Earlier attempts with `NSSavePanel.ok:` and post-presentation property setters did
not drive native confirmation; the public accessibility check replaces that gap.

## Execution ruling and review

Initial ruling (superseded): retain real accessory Copy/Escape coverage, preserve
the completion block verbatim, and test its controller operation directly. The
stated cost was that a remote Save-confirmation regression could escape the checks.
The initial specification review rejected that evidence gap. The remedy now drives
the actual native Save button and verifies the callback, removing that deferral;
product code did not change. The new check first exposed filename/path handling in
the fixture, then passed with a unique synthetic filename.

Initial specification review: **MISSING** at `cf37951`, solely for AC-04 native
confirmation evidence. Targeted specification follow-up and quality review: pending.
