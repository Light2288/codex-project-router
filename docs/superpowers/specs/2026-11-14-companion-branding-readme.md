# Companion branding and README — specification

**Slug:** `companion-branding-readme`

**Type:** chore

**Status:** APPROVED

**Created:** 2026-11-14

**Updated:** 2026-11-14

**Provenance:** User's icon integration and README request; scope/design explicitly confirmed with “scope and design confirmed.” The DRAFT specification was presented in chat during Plan mode on 2026-11-14 because that mode prohibited saving it. The next user message, “Please implement the plan.”, accepts that presented specification and advances only its pending gate under the supplied AGENTS.md. Specification approval authorizes a separate implementation plan only; no implementation plan has been presented or approved. This file materializes that specification with approval and storage metadata updated; its approved scope is unchanged.

## Problem and desired outcome

The companion currently uses a generic branching-arrow SF Symbol, has no configured app icon, and displays a text-only window header. The README contains extensive operating instructions without the visual identity or introductory structure requested.

Deliver one consistent identity across the macOS app, menu bar, companion header, and GitHub README. This is one focused increment within the wider direction of improving the companion's presentation and usability.

## Selected design

### Artwork and macOS integration

Use exactly these sources:

- **App, companion header, and README:** `/Users/davide/Downloads/Navy Folder Branching Arrows Icon.png`
- **Menu bar:** `/Users/davide/Downloads/Folder Routing Branch Icon.png`

Preserve byte-for-byte copies of both originals under `assets/branding/`, with descriptive repository filenames and source provenance. Builds and runtime resource loading must work independently of Downloads and the checkout's absolute location.

Derive a standard macOS `.icns` with the usual normal and Retina sizes from the navy artwork. Preserve its transparent corners, colors, proportions, and rounded-square tile.

Derive the menu-bar asset by trimming excess transparent canvas and adding a small, balanced margin. Preserve the supplied silhouette and proportions. Display it at approximately 18 points high with suitable Retina resolution and template rendering, allowing macOS to adapt its appearance.

Package and reference these resources through the existing app build. Retain the app's current menu-bar lifecycle, including its absence from the Dock during normal operation.

### Companion header

Place a decorative 36-point navy icon immediately beside the existing “Codex Project Router” title. Preserve the title, Refresh action, progress indicator, window sizing constraints, and keyboard/accessibility behavior.

The image conveys identity only; it does not indicate whether routing is running or enabled.

### README and operating documentation

Use the USDZ Validator README as the primary structural reference, with the Light Stimulus README as supplementary visual guidance.

The README will contain:

- A centered navy logo, project title, and concise description.
- Accurate badges for declared requirements and the existing license.
- A short introduction and feature list reflecting implemented capabilities.
- Prerequisites, dependency installation, companion build/open instructions, and an overview of initial setup and everyday use.
- Links to detailed documentation, validation evidence, development checks, and the license.

Move lengthy configuration, CLI operation, recovery, compatibility, optional-policy, and validation procedures into `docs/operating-guide.md`. Preserve substantive instructions and limitations, repair relative links, and update repository references affected by relocation.

Keep the project's experimental status and observed compatibility limits clear. Do not imply that tests establish live gateway compatibility or that deferred account/assignment editing is available.

## Acceptance criteria

| ID | Verifiable outcome |
| --- | --- |
| **AC-01** | Both selected originals are preserved in the repository; generated resources require no Downloads access. |
| **AC-02** | A fresh built app contains a valid multi-size `.icns`, referenced by its bundle metadata, using the navy artwork with transparent corners. |
| **AC-03** | The menu bar uses the selected black artwork with corrected padding, preserved proportions, and template rendering. Size previews establish legibility in light and dark appearances. |
| **AC-04** | The companion header displays the navy icon beside the existing title without obscuring controls, adding duplicate accessibility announcements, or suggesting operational state. |
| **AC-05** | The README follows the agreed structure and displays its repository-hosted logo. Detailed operating guidance remains available through working links. |
| **AC-06** | Documentation preserves relevant setup, recovery, privacy, compatibility, and validation qualifications; commands and feature claims match current behavior. |
| **AC-07** | A fresh signed app retains its branding resources after relocation outside the checkout; packaging and signature checks pass. |
| **AC-08** | Relevant Node/native checks, the companion build/package checks, documentation-link checks, whitespace checks, and final specification/quality review pass. Visual observations and any unverified items are reported accurately. |

## Constraints and verification

No public API, wire format, private configuration schema, credential handling, routing policy, or operational permission changes are required.

Use existing SwiftUI/AppKit and macOS build tooling without introducing a runtime dependency for branding. Packaging verification must detect missing or invalid required assets.

Verification must preserve real private configuration, credentials, listeners, and the running companion session. Use isolated resources where native observation is needed. Adding a decorative header image does not justify a new snapshot-test framework.

The remaining uncertainty concerns small-size appearance and packaged-resource behavior; previews and fresh build/relocation checks resolve those questions.

## Alternatives and exclusions

The selected approach reuses the supplied artwork across all requested surfaces. Keeping the generic menu-bar symbol would leave inconsistent branding; generating replacement artwork would exceed the confirmed request.

Artwork redesign, animated or state-dependent icons, broad interface changes, routing features, application installation, releases, pushing, and merging are outside this increment.

**Execution endpoint:** Complete the approved branding and documentation update, verification, final review, and local commits; report the result and limitations, then stop.

**Current stage:** Stage 3 — implementation planning is authorized. The specification has been approved and saved. A separate implementation plan must be presented and explicitly approved before product changes. Keep this specification uncommitted until the implementation branch is created after both approvals; preserve the existing checkout and local changes.
