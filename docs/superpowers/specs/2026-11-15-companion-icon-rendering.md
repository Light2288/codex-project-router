# Companion icon rendering — specification

**Slug:** `companion-icon-rendering`

**Type:** bug

**Status:** APPROVED

**Created:** 2026-11-15

**Updated:** 2026-11-15

**Provenance:** The user reported two app bundles in `dist` and an incorrectly sized Dock icon. Their screenshot, supplied as `/var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/codex-clipboard-ca85be01-6bd2-4921-a4eb-913cdfb82560.png`, shows the navy artwork inset within a separate gray rounded-square tile. The user clarified that the folder and blue background together constitute the icon, rejected enlarging the folder relative to its background, and confirmed the corrected three-point scope with “confirmed.” After this DRAFT specification was saved and separately presented, the user's subsequent “approved” explicitly approved the specification and authorized implementation planning only. Existing branding and Dock-presence artifacts remain historical inputs with their original scope and approval history.

## Problem

The Dock shows the complete navy artwork inside a larger gray tile, making the
app's visual identity smaller than intended. The user expects the navy
background itself to occupy the app icon's rounded-square surface, with no
additional gray surround. Two locally built app bundles also make it unclear
which copy to open.

## Current behavior and evidence

- `assets/branding/codex-project-router.png` is the original 1254 × 1254 image.
  Its visible navy tile spans approximately 96% of the canvas width; the cyan
  folder spans approximately 66%. These proportions are intentional for this
  correction and must be preserved.
- `scripts/generate-companion-icons.swift` scales that complete canvas into
  standard ICNS representations. The source, committed ICNS, and both app
  bundles have matching artwork proportions. The extra gray tile is absent
  from the source artwork.
- The bundle declares `CFBundleIconFile = AppIcon.icns` and packages no compiled
  icon asset catalog. The screenshot is consistent with macOS applying a
  compatibility surround; the exact packaging/rendering cause remains to be
  established before implementation changes are chosen.
- The observed host runs macOS 27.0.1. The project's declared minimum remains
  macOS 14.0.
- `dist/Codex Project Router.app` is the older build;
  `dist/Codex Project Router Dock Preview.app` is the later Dock-presence build.
  Both were running at the most recent specification-stage inspection. Process
  state must be checked again at implementation time.

## Desired outcome and delivery boundary

The wider direction is a companion with a consistent native identity and a
clear app launch target. This focused increment corrects native app-icon
presentation and consolidates the local deliverable to one current bundle.

The complete navy tile and cyan folder remain one piece of artwork. Correct
native icon resources, declarations, or packaging as needed so the navy fills
the system's rounded-square icon surface without a second gray container.
Preserve the folder-to-background proportions, colors, and composition. A
normal macOS outer shadow, antialiasing, or spacing between neighboring Dock
items is outside the reported gray-surround defect.

Build the latest code, including the completed conditional Dock lifecycle, as
`dist/Codex Project Router.app`. After that build is verified and no process
uses the obsolete preview, remove only
`dist/Codex Project Router Dock Preview.app`. Temporary verification bundles
belong in disposable scratch space, not beside the canonical deliverable.

This boundary includes necessary generation, bundle integration, regression
checks, targeted documentation, native visual verification, and final review.
It is one coherent correction because the user must open the intended current
bundle to assess the icon reliably.

## Approaches and confirmed design

The user selected correcting native packaging/rendering while preserving the
existing artwork. The exact Apple-toolchain mechanism is an implementation
choice to be grounded in evidence during planning and diagnosis. Retain an
appropriate legacy icon fallback for the declared macOS minimum.

Enlarging only the cyan folder was explicitly rejected. Merely trimming the
small transparent outer margin does not address the separate gray container
shown in the screenshot. A manual Finder icon override would not provide a
reproducible correction for a fresh packaged app and is not the delivery path.

## Acceptance criteria

| ID | Verifiable outcome |
| --- | --- |
| **AC-01** | A fresh canonical app opened on the observed macOS host shows the complete navy icon filling the Dock icon's rounded-square surface, without the additional gray container shown in the user's screenshot. Preserve native outer shadow and edge rendering. Capture and inspect actual Dock evidence; decoded resource images alone do not satisfy this criterion. |
| **AC-02** | The cyan folder's scale and position relative to the navy tile are preserved. Neither enlarging the cyan folder independently nor clipping its strokes is used to remove the gray surround. Any native canvas or mask adaptation preserves the visible composition. |
| **AC-03** | At delivery, `dist/Codex Project Router.app` contains the latest verified implementation and `dist/Codex Project Router Dock Preview.app` is absent. No replacement preview deliverable is left in `dist`. Replacement or removal occurs only after checking that the affected bundle is no longer running. |
| **AC-04** | The supplied source PNGs, menu-bar TIFF, companion-header PNG, and README artwork remain byte-for-byte unchanged. The menu-bar icon and companion header retain their current presentation. |
| **AC-05** | Icon generation and packaging are reproducible from repository inputs with documented Apple tooling. A fresh built bundle has valid icon declarations and resources, is ad-hoc signed, passes package integrity/relocation checks, and retains an icon fallback and the existing macOS 14.0 minimum. Actual older-OS execution is claimed only if observed. |
| **AC-06** | Existing controls-window Dock lifecycle, guarded Quit, routing, saved configuration, credentials, and background/menu-bar operation remain intact. Verification uses isolated state and owned test processes without changing the user's routing setup. |
| **AC-07** | Meaningful regression coverage addresses the established packaging/rendering cause and preserves existing package safeguards. Affected automated checks, the fresh build, native Dock observation, and sequential specification/quality review complete with evidence recorded. Generation or packaging errors retain contextual diagnostics. |
| **AC-08** | Targeted branding/build documentation records any changed generation requirements and the single canonical app output. The final report identifies the working bundle, verification evidence, and any material limitations. |

## Safeguards, uncertainty, and verification

The remaining technical uncertainty is which native packaging or icon-shape
requirements cause the system to add the gray surround. Establish that cause
and choose the smallest reproducible correction. Do not treat source bounds or
an ICNS decode as proof that the Dock rendering is correct. If the required
correction materially changes this design, return for specification approval.

Recheck running companion processes before replacing or deleting either
bundle. Do not force-terminate a running companion or bypass its guarded Quit.
If a user-owned process is still running, preserve it and obtain normal guarded
shutdown before replacing its bundle. Do not delete other `dist` content,
reset system-wide icon caches, change Dock preferences, or install a Finder
custom-icon override as part of verification.

Use the project's native Swift tests, Node tests, and packaging checks as
appropriate to the eventual change. Preserve existing resource allowlists,
signature validation, relocation coverage, source-read isolation, and owned
process cleanup. Native observation must show the final bundle in the Dock
using safe isolated state and distinguish system presentation from the source
image. If visual observation is unavailable, record that AC-01 is unverified;
do not report the correction complete solely on automated checks.

## Constraints and out of scope

No artwork redesign, new icon generation by AI, folder enlargement, menu-bar
icon change, README restyling, companion UI redesign, routing behavior change,
or new runtime dependency belongs to this increment. Installation, release,
push, merge, and further features remain deferred.

Preserve the completed branding and Dock-presence commits and their historical
artifacts. Follow the user's existing-checkout Git workflow: keep this DRAFT
uncommitted, create no new implementation branch and do not update `main`
until this specification and a separately presented implementation plan have
both received explicit approval.

**Execution endpoint:** Deliver and locally commit the corrected packaged icon,
one current canonical app bundle, necessary documentation and regression
coverage, native visual verification, and final review; report the result and
limitations, then stop before installation, push, merge, or another increment.

**Current stage:** Stage 4 — implementation authorized. The user separately
approved the presented specification, then the presented implementation plan
with a subsequent “approved.” Both artifacts were saved before product edits.
Implementation, verification, and final review are in progress.
