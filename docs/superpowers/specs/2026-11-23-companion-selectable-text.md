# Companion selectable text — specification

**Slug:** `companion-selectable-text`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-23

**Updated:** 2026-11-24

**Provenance:** User’s first-use walkthrough request, repository inspection, interactive selection to include app-authored file-dialog instructions, and subsequent scope/design confirmation: “confirmed”. The DRAFT specification was then presented separately in chat while Plan mode prevented saving it. The user's subsequent “Please implement the plan.” approves that presented specification under the supplied AGENTS.md approval interpretation; no implementation plan had been presented. This file preserves the approved requirements, with lifecycle and storage metadata updated.

Artifact resolution found no pre-existing specification or plan for this slug when the draft was presented and again before saving it.

## 1. Problem and desired outcome

Users need to select and copy text from the companion while following a first-use walkthrough, particularly explanations, statuses, warnings, and errors.

Source inspection shows selection enabled only for certain errors, paths, operational facts, and advanced details. Other informational text lacks explicit selection support. Activation uses a SwiftUI alert; blocked Quit uses `NSAlert`. Their selection and keyboard behavior require direct verification.

The selected increment makes displayed informational text selectable and copyable while keeping API keys concealed and preserving existing controls. The broader UI redesign remains deferred.

## 2. Coverage and approach

Cover passive informational text in:

- The main controls window, including project rows, notices, operational facts, setup guidance, and recovery instructions.
- Account setup, import, default-selection, and project-assignment sheets.
- Activation and blocked-Quit alerts, including their headings and messages.
- App-authored instructional text inside native file-selection dialogs.

Include passive headings, names, counts, labels, paths, and displayed metadata. Text serving as an interactive control label—such as a button, picker option, toggle, or disclosure trigger—retains its existing interaction.

Use native text selection on passive SwiftUI text. Where alert or file-dialog presentation requires another native text control, make it selectable and read-only. Preserve warning presentation, message meaning, and action semantics. Copy buttons alone would not satisfy the selection requirement; replacing all text with editable fields would introduce unnecessary behavior changes.

No router API, bridge schema, configuration format, credential-storage change, or migration is required.

## 3. Interaction, security, and edge cases

Users can select a substring or a complete individual text block and copy it with ⌘C. Copied plain text preserves the selected characters, Unicode, and line breaks. Whole-window selection and selection spanning separate text blocks are excluded.

Informational text remains read-only, retains its existing visual hierarchy, and remains reachable through existing scrolling and disclosures. Long messages wrap or scroll without losing access to their full content.

Routine refreshes that leave a text block unchanged must not repeatedly interrupt selection. A changed or removed message may clear its selection.

The API-key entry remains a secure field. This change must not expose its value through displayed text, accessibility values, logging, or clipboard copying. Existing secret-clearing behavior remains intact. Displayed Keychain metadata remains copyable without retrieving credential values.

Selecting or copying text must not trigger routing, saving, activation, confirmation, dismissal, or Quit. Existing enabled states, keyboard shortcuts, cancellation, focus navigation, and recovery safeguards remain authoritative.

## 4. Acceptance criteria and verification

- **AC-01:** Informational text throughout the main window and project list supports selection and copying, including warnings, errors, statuses, and expanded details.
- **AC-02:** Account and assignment sheets provide the same behavior for guidance, outcomes, disabled-action explanations, errors, and metadata.
- **AC-03:** Activation and blocked-Quit alert headings and messages are selectable and copyable; their actions, Return/Escape handling, and safeguards retain existing behavior.
- **AC-04:** App-authored file-dialog instructions are selectable and copyable; file selection, filtering, confirmation, and cancellation retain existing behavior.
- **AC-05:** Substring and complete-block copying reproduce the selected text accurately, including multiline and Unicode content; informational text cannot be edited.
- **AC-06:** API keys remain concealed and cannot be copied in clear text from the secure field or exposed by the new selection behavior.
- **AC-07:** Buttons, pickers, toggles, disclosures, search, editable fields, and keyboard navigation remain usable alongside selectable text.
- **AC-08:** Long content remains accessible, and unchanged periodic refreshes do not interrupt selection.
- **AC-09:** Verification demonstrates actual selection and clipboard results, key concealment, and representative control interactions across all covered surface types.

Use synthetic data and keys for focused native interaction checks. Include relevant regression tests, a rebuilt companion, and concise documentation of verification results and any limitations. Source inspection alone does not establish that copying works. No implementation verification was run during drafting.

## 5. Delivery boundary and approval

This increment includes the presentation changes, necessary keyboard integration, security safeguards, tests, documentation, build verification, and review needed to demonstrate copying end to end.

Exclude broader layout/navigation redesign, walkthrough content, diagnostic export, bulk “copy all” features, changes to routing or credential handling, and customization of macOS-owned interface labels or window chrome.

**Execution endpoint:** Deliver the approved selectable-text improvement, complete verification and review, report evidence and limitations, and stop before subsequent UI work.

**Current stage:** Stage 4 complete — Native implementation, verification, and sequential specification/quality review are complete. The local branch is `feat/companion-selectable-text`; no push or merge. Evidence and limits are recorded in `docs/validation/companion-selectable-text.md`. The scope/design approval was “confirmed”; the specification approval was the first “Please implement the plan.” following presentation of the DRAFT. The separate implementation plan was then presented and approved by the later, second “Please implement the plan.” Both artifacts were saved before product changes.
