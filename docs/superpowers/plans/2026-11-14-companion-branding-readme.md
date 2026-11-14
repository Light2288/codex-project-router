# Companion Branding and README Implementation Plan

> **For agentic workers:** Use `personal-workflows:spec-implement` with `superpowers:executing-plans`. Implement the checkbox tasks in order after this plan receives separate approval.

**Goal:** Apply the selected artwork to the macOS app, menu bar, companion header, and README while preserving existing operation.

**Architecture:** Keep original artwork and derived resources in the repository. Extend the existing app assembly to copy an explicit branding allowlist, use native bundle resource loading in SwiftUI, and move detailed operating instructions into a linked guide.

**Tech Stack:** Existing Node.js 24, SwiftUI/AppKit, macOS image tools, XCTest, and Node test runner. No additional runtime dependencies.

**Spec:** [Approved specification](../specs/2026-11-14-companion-branding-readme.md)

**Slug:** `companion-branding-readme`

**Status:** APPROVED

**Created:** 2026-11-14

**Updated:** 2026-11-14

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Native, explicitly selected through the clarification control. Inline execution retains the current session model.

**Provenance:** Implements the separately approved specification. This plan was presented in chat during Plan mode. The subsequent user message “Please implement the plan.” explicitly approves this separately presented plan, authorizing implementation. The earlier message with the same wording approved the specification only; both pending gates have now been satisfied. Saved after leaving Plan mode, before any product changes.

## Global constraints and repository evidence

- Preserve both original images byte-for-byte. Asset preparation changes only cropping, transparent margins, resolution, and file format.
- Keep the decorative header icon at **36 points** and the menu-bar image at approximately **18 points high**.
- Preserve routing, account setup, recovery, permissions, window controls, accessibility, and `LSUIElement` behavior.
- Preserve substantive documentation and its compatibility/validation qualifications.
- Work in the existing checkout. After approval, save the plan, safely update `main`, create `chore/companion-branding-readme`, and commit the approved artifacts on that branch. Preserve unrelated changes; do not push or merge.
- Baseline: `5be89ca45ca4d50824827eed37063236a6c0f8ff`. Only the saved specification was untracked before this plan was saved.
- Specification resolution: **NEW_ONLY**. Plan resolution before creation: **MISSING**, with no conflicting legacy artifact.
- No architecture map or applicable ADR exists; freshness is unavailable. Inspected paths cover the app entry point, controls header, plist, package manifest, assembly script, package tests, and documentation.
- Verification commands below come from the existing package scripts, README, and package tests. No implementation or acceptance testing occurred during planning.

## Review focus

1. Transparent image padding must not make the menu symbol unexpectedly small.
2. Template rendering must preserve readable artwork in light and dark appearances.
3. Relocated builds must resolve all images without checkout or Downloads access.
4. Resource copying must retain the existing explicit packaging allowlist and signature validity.
5. Documentation relocation must preserve operating safeguards, relative links, and accurate feature claims.

## Task 1: Integrate artwork and native branding [size: M | risk: none | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-07; contributes to AC-08.

**Files and responsibilities:** Original artwork and provenance belong under the branding assets directory. Derived icons belong with the existing companion resources. Update the existing assembly script, plist, menu-bar label, controls header, and package tests. Add one native image-generation script for reproducible preparation.

**Interfaces:** Keep the existing `assembleCompanion({binaryPath, routerRoot, outputPath})` signature. Add no public API or configuration fields.

- [ ] Extend package tests to require an app icon declaration, the exact branding resources, decodable image representations, preserved transparency, and resource availability after relocation. Update the synthetic builder fixture to provide its required branding inputs.
- [ ] Run `npm run companion:package-test`. Confirm the new assertions fail because branding resources/declarations are absent; distinguish any unrelated environment failure.
- [ ] Copy the supplied originals into the repository and record their source filenames and SHA-256 hashes.
- [ ] Add reproducible native generation for `AppIcon.icns`, `CompanionIcon.png`, and `MenuBarIconTemplate.tiff`. Generate standard normal/Retina app representations. For the menu symbol, crop to its alpha bounds and fit it proportionally within a **26 × 18-point** canvas with balanced transparent margins and 1×/2× representations. Commit derived resources so ordinary builds need no artwork-generation step.
- [ ] Extend assembly with an explicit resource list and declare the `.icns` in bundle metadata. Missing resources must produce a contextual build failure; package verification must reject undecodable resources.
- [ ] Replace the SF Symbol with the bundled template image, retaining the accessible app name and existing menu actions. Add the navy image beside the controls title at 36 points, hidden from accessibility as decorative. Use ordinary bundle loading without absolute source paths.
- [ ] Run `npm run companion:test`, `npm run companion:build`, and `npm run companion:package-test`. Expect zero failures and no package-test skips. Inspect light/dark size previews and the header layout; record observations separately from automated results.
- [ ] Commit the branding integration.

## Task 2: Restructure README and preserve operating guidance [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-05, AC-06; contributes to AC-08.

**Files and responsibilities:** Rewrite the root README, create `docs/operating-guide.md`, and repair affected documentation links. Add artwork provenance/regeneration instructions beside the source assets.

**Interfaces:** Existing commands and operational behavior remain authoritative. Documentation introduces no new operational feature.

- [ ] Inventory the current README sections and links before editing so each substantive procedure has an explicit destination.
- [ ] Create a concise README using the USDZ example's structure: centered navy logo/title, description, accurate requirement/license badges, introduction, features, prerequisites, installation, companion build/open commands, setup/use overview, documentation links, development checks, and license.
- [ ] Move detailed operating material into the guide. Preserve configuration, authentication-role distinctions, activation/recovery procedures, schema compatibility, optional policies, privacy boundaries, and validation limitations. Resolve any contradictory legacy wording using current code and existing companion documentation.
- [ ] Correct relative links and repository references affected by the move. Preserve useful anchors or provide clearly linked destinations where needed.
- [ ] Check local link/image targets and fragment anchors, inspect README rendering, and compare the section inventory against the final documents. Expect no missing material, broken local links, or unsupported feature claims.
- [ ] Run `git diff --check`; expect no output. Commit the documentation update.

## Task 3: Verify, review, and close out [size: S | risk: none | mechanical: true | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-08; confirms AC-01–AC-07.

- [ ] Run the established acceptance sequence: `npm run companion:test`, `npm run companion:build`, `npm test`, `npm run companion:package-test`, `node --check src/cli.js`, and `git diff --check`. Retain exit statuses and decisive results; expect zero failures and no package-test skips.
- [ ] Confirm the relocated-app checks cover branding resources, valid signing, and operation with checkout reads denied. Preserve existing isolation and owned-process cleanup.
- [ ] Record source hashes, icon representations, visual observations, documentation checks, and acceptance results in a concise validation record. Label anything unobserved.
- [ ] Run `personal-workflows:code-review` once as the final integrated review: specification review first, then quality review after specification PASS. Resolve findings within the approved scope and rerun affected checks.
- [ ] Commit closeout documentation, verify the final Git state, and report the working result, evidence, and limitations.

**Criterion coverage:** Task 1 covers artwork/native integration; Task 2 covers documentation; Task 3 supplies the combined verification and final review required by AC-08.

**Execution endpoint:** Deliver and locally commit the verified branding/documentation increment, report results, and stop without installation, pushing, merging, or subsequent feature work.

**Current stage:** Stage 4 — implementation authorized by the separately presented and approved specification and implementation plan. Both artifacts are saved. Preserve their filenames and scope.
