# Companion Selectable Text Implementation Plan

> **For agentic workers:** Use `personal-workflows:spec-implement` with `superpowers:executing-plans`. Execute the checkbox tasks using the user-selected **Native** method. The separate specification, plan-approval, and Git rules remain authoritative.

**Goal:** Make the companion’s informational text selectable and copyable while preserving concealed API-key entry and normal controls.

**Architecture:** Enable native selection directly on passive SwiftUI text. Preserve existing native alerts, which inspection found already selectable. Present file-dialog instructions through an owned, selectable native label. Verify actual clipboard behavior through the normal responder chain.

**Tech Stack:** Existing SwiftUI/AppKit application, macOS 14 minimum, SwiftPM, XCTest, and Node-based packaging. No dependencies, public APIs, schemas, or migrations.

**Spec:** `docs/superpowers/specs/2026-11-23-companion-selectable-text.md`

**Slug:** `companion-selectable-text`

**Status:** APPROVED

**Created:** 2026-11-23

**Updated:** 2026-11-24

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Native, selected through interactive clarification.

**Provenance:** The specification was separately presented and approved by the first “Please implement the plan.” after scope/design confirmation. This implementation plan was subsequently presented separately in Plan mode and Native execution selected. The user's second “Please implement the plan.”, immediately after presentation of this plan, approves the plan and authorizes implementation. Saved in Default mode before product changes; only lifecycle/storage metadata differs from the presented plan.

## Global constraints and evidence

- Cover passive informational text in the main window, project list, account/assignment sheets, alerts, and app-authored file-dialog instructions.
- Support substring and complete-block copying with ⌘C; informational text remains read-only.
- Preserve concealed API-key entry, existing secret clearing, control actions, enabled states, shortcuts, and recovery safeguards.
- Preserve selection across refreshes when the selected text has not changed.
- Exclude whole-window copying, control-label selection, macOS-owned interface text, walkthrough content, and the broader redesign.
- Source baseline is `46de00ef5be3a3d4b458e0036133dfb559d57b12`. No architecture map or ADR candidates were found; freshness metadata is unavailable. Relevant views, controllers, native test fixtures, and packaging were inspected directly.
- Synthetic native probes found both `NSAlert` and SwiftUI alert headings/messages selectable and read-only on this Mac. Clipboard copying remains unverified. File-dialog instructions were outside the local text-field view tree.
- Verification commands come from `package.json`; SwiftPM filtering follows existing usage in the Keychain validation report.

After plan approval, save this plan, record both artifact approvals, safely fast-forward `main`, and create `feat/companion-selectable-text` in the existing checkout. Preserve local changes. Commit the specification and plan on that branch before product changes. No worktree, push, or merge is authorized.

## Review focus

1. Unchanged polling must not discard an active selection.
2. Unicode and multiline selections must copy exactly.
3. Copying must not activate an alert’s default action or change cancellation.
4. Moving focus between informational text and secure entry must not expose a key.
5. File-dialog copying and cancellation must not select a configuration or create a file.

Each condition receives native interaction coverage in the tasks below.

## Task 1: Selectable window and sheet text [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-02, AC-05, AC-06, AC-07, AC-08, AC-09.

**Responsibility:** Update passive text in `ControlsView`, `ProjectListView`, `AccountSetupView`, and `ProjectAssignmentView`. Extend the existing native application tests and their `NativeProjectHost` fixture.

**Risk:** Selection and focus changes must not make secure entry copyable or expose its value.

**Interfaces:** Keep production view/controller interfaces unchanged. Extend the test host with:

- `selectText(_ text: String, range: NSRange, in target: NSWindow? = nil) throws`
- `copySelection(in target: NSWindow? = nil) throws -> String`

The helpers must select rendered text and dispatch ⌘C through normal application handling. They must not substitute the expected string into the clipboard.

- [x] **Add failing interaction coverage.** Reuse existing synthetic backends to cover main-window guidance/status/error text, project rows/details, account guidance/metadata, and assignment warnings/errors. Assert exact substring and full-block copying, read-only behavior, Unicode/multiline preservation, and selection retention through an unchanged refresh.
- [x] **Verify the failure.** Run `npm run companion:test`. Record the expected failures for currently unselectable informational text.
- [x] **Enable selection on passive text.** Apply native selection modifiers directly to informational text, including passive headings and labels supplied through container label closures. Preserve existing view identity and styling. Keep interactive labels and secure entry under their existing behavior.
- [x] **Verify security and controls.** Use a synthetic key to check that attempted copying from secure entry does not produce the key and accessibility exposes no clear value. Exercise search/editing, pickers, disclosures, nearby buttons, and sheet dismissal. Copying alone must leave backend mutation counters unchanged.
- [x] **Verify and commit.** Repeat `npm run companion:test`; expect all existing and new cases to pass. Keep clipboard contents only in memory for restoration, without logging or persisting them. Commit with `feat: make companion informational text selectable`.

## Task 2: Verify alerts and make file-dialog guidance copyable [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-07, AC-09.

**Responsibility:** Extend activation, blocked-Quit, and file-dialog interaction checks. Change native presentation only where needed to satisfy copying.

**Risk:** Native focus and keyboard handling can affect default actions, cancellation, or file-selection callbacks.

**Interfaces:** Preserve the SwiftUI activation alert, `QuitAlert.make(reason:ownsRouter:)`, and existing controller callbacks.

- [ ] **Add native regression checks.** Select and copy alert headings/messages. Cover each blocked-Quit reason, activation confirmation, and the configuration destination instructions. Verify copying does not mutate state, activate routing, or request termination.
- [ ] **Establish baseline behavior.** Run `npm run companion:test`. Record existing alert behavior separately from any copying failures; passing native behavior requires no replacement.
- [ ] **Make file-dialog instructions locally selectable.** In destination-panel construction, place the unchanged instructional message in a wrapping, selectable, read-only `NSTextField` accessory. Remove the duplicate native message. Preserve the panel title, allowed file types, destination handling, directory creation, and completion callback. Use public APIs without remote-view inspection.
- [ ] **Check keyboard behavior.** Exercise ⌘C, Return, Escape, and mouse actions after text selection. Preserve existing native Copy handling. If it is missing, supply standard AppKit responder-chain editing commands without global key interception or custom text export.
- [ ] **Verify and commit.** Repeat `npm run companion:test`. Confirm file-dialog cancellation produces no configuration change or file creation, confirmation retains its existing callback, and long instructions remain reachable. Commit with `feat: support copying companion dialog guidance`.

## Task 3: Build, review, and document the delivered increment [size: S | risk: none | mechanical: true | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01–AC-09.

**Interfaces:** Consume the completed UI changes and interaction evidence. Produce a rebuilt companion and a validation report at `docs/validation/companion-selectable-text.md`.

- [ ] **Run final verification sequentially.** Run `npm run companion:test`, `npm run companion:build`, `npm run companion:package-test`, and `git diff --check`. Expect passing tests, a rebuilt signed bundle, passing package checks, and no whitespace errors. Do not run GUI suites concurrently.
- [ ] **Complete native acceptance.** Inspect actual selection, clipboard results, wrapping, and nearby controls across the covered surfaces using synthetic state. Record any unverified packaged-app behavior explicitly.
- [ ] **Document results.** Record commands, outcomes, clipboard/security checks, native visual observations, and limitations. Add a short usage note explaining selection and ⌘C without broad documentation changes.
- [ ] **Complete the final review gate.** Use `personal-workflows:code-review`: specification review first, then quality review after PASS. Review the whole increment against the approved artifacts, address findings, and rerun affected checks.
- [ ] **Commit and report.** Commit validation/documentation and report the working result, evidence, limitations, commits, and final repository status.

| Criteria | Primary evidence |
|---|---|
| AC-01, AC-02 | Window/project/sheet copying checks |
| AC-03, AC-04 | Alert and file-dialog interaction checks |
| AC-05, AC-06 | Exact clipboard results, read-only and secure-entry checks |
| AC-07, AC-08 | Control, keyboard, long-content, and refresh checks |
| AC-09 | Integrated native acceptance and validation report |

**Execution endpoint:** Complete this increment, its verification, review, commits, and result report; then stop before further UI or walkthrough work.

**Current stage:** Stage 4 — the saved specification and this separately presented plan have separate explicit approvals. Native implementation is authorized. Both artifacts are saved before product changes.
