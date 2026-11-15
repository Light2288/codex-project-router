# Companion Icon Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Show the complete navy artwork as the app icon without the extra gray surround and deliver one current app bundle.

**Architecture:** Compile a native `AppIcon.icon` document into `Assets.car`, declare its catalog name, and retain `AppIcon.icns` as a legacy fallback. Treat the folder and navy background as one flattened composition; adapt only the app-icon canvas to the native mask. Keep existing SwiftUI/AppKit behavior and the explicit bundle resource allowlist.

**Tech Stack:** Existing Swift/AppKit/ImageIO generator, Xcode Icon Composer and `actool`, Node.js 24 packaging/tests, native macOS observation. No new runtime dependency.

**Spec:** [Approved specification](../specs/2026-11-15-companion-icon-rendering.md)

**Slug:** `companion-icon-rendering`

**Status:** APPROVED

**Created:** 2026-11-15

**Updated:** 2026-11-15

**Execution tier:** full

**Implementation model role:** full

**Execution method:** Native; preserve the user's earlier explicit choice. Inline execution retains the current session model.

**Provenance:** The corrected scope was confirmed, the specification was saved and separately presented, and the user's subsequent “approved” authorized this planning stage. The user subsequently approved this separately presented plan with “approved,” authorizing implementation. Earlier branding and Dock-presence artifacts remain historical inputs.

## Global Constraints

- Preserve the complete navy tile and cyan folder as one composition, including their relative scale, position, and colors. Do not enlarge the folder independently.
- Remove the additional gray container through reproducible native icon packaging/rendering. A normal system shadow, antialiasing, and Dock item spacing remain expected.
- Keep the supplied source PNGs, menu-bar TIFF, companion-header PNG, and README artwork byte-for-byte unchanged.
- Retain macOS 14.0 as the declared minimum, Apple silicon packaging, Node.js 24, `LSUIElement = true`, and the completed conditional Dock lifecycle and guarded Quit.
- Deliver only `dist/Codex Project Router.app`; remove only the obsolete `dist/Codex Project Router Dock Preview.app` after verifying its replacement and confirming it is not running. Do not delete other `dist` content.
- Recheck running copies before any bundle replacement/removal. Do not force-terminate user processes or bypass guarded Quit. Use disposable scratch outside `dist` while either affected bundle remains in use.
- Use isolated state and owned test processes. Do not change real routing/configuration/credentials, reset system-wide icon caches, change Dock preferences, install a Finder custom icon, install the app, push, or merge.
- Start product edits only after separate plan approval. Safely update local `main` without discarding changes or divergent history, then create `fix/companion-icon-rendering` from preserved HEAD `b1c6e56e96a57f3f51e752234c5cacca9aff7b62` or its verified descendant, retaining the unmerged branding and Dock work. Use the existing checkout; no worktree. Commit the approved artifacts on that branch before product changes.

## Repository evidence and assumptions

- Specification resolution: **NEW_ONLY** at the linked path; prior plan resolution: **MISSING**, including the exact legacy paths. The new plan reuses the specification's basename.
- Planning HEAD is `b1c6e56e96a57f3f51e752234c5cacca9aff7b62`, on `feat/companion-dock-presence`. Only this increment's specification was untracked before planning. No product edits or project build/test commands ran during planning.
- Architecture map `docs/architecture/map.md` is absent; therefore its HEAD and freshness cannot be established. No architecture/ADR/decision documents were found under `docs`; there are no discovered ADR statuses to apply. Direct key-path inspection covered the generator, plist, build script, package tests/probe, README instructions, and previous validation record. Do not generate a map in this increment.
- The generator currently scales the full source into ICNS sizes and copies the unchanged header. The plist declares only `CFBundleIconFile`. The assembler and package tests allow exactly three image resources, and tests require transparent corners for those current resources. A modern opaque input must be checked separately from the legacy representations.
- The existing package probe can decode raw resources without proving catalog resolution. Add a catalog-only probe against a disposable bundle with the fallback absent to prevent that false positive.
- The local host has macOS 27.0.1 and Xcode 27.2, including `actool` and Icon Composer's `ictool`. Tool discovery was read-only. Full Xcode is a generation-time requirement; ordinary builds continue copying committed generated resources.
- Apple's [Icon Composer documentation](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) and [app-icon guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons) describe native masks and compilation, including older-system representations. [Apple Developer Forums](https://developer.apple.com/forums/thread/794485) documents catalog/fallback interactions; it is supporting evidence, not authority for undocumented flags. Avoid such flags.
- Native catalog support is the selected packaging mechanism. The missing modern asset and the source's nonstandard outer geometry are diagnostic hypotheses until controlled native observation establishes which produces the surround. No material product decision remains unresolved.

## Review Focus

1. Catalog lookup must work after relocation with the ICNS fallback unavailable; otherwise a successful decode could hide a broken catalog declaration.
2. Missing or corrupt `Assets.car` must fail validation contextually rather than silently falling back and reporting success.
3. Canvas adaptation must preserve cyan-to-navy proportions and avoid a navy seam, transparent edge, or new gray border when the system masks the icon.
4. A running canonical/preview copy must never be replaced or removed; cleanup targets only the known obsolete artifact after a verified replacement exists.
5. Native Dock evidence must correspond to the final canonical bundle and current resources, rather than a cached old icon or an instrumented substitute.

---

## Files and responsibilities

| Files | Responsibility |
| --- | --- |
| `assets/branding/AppIcon.icon/icon.json`, `assets/branding/AppIcon.icon/Assets/Artwork.png` (new) | Native document and derived opaque composition, with no independent folder layer or added glass styling |
| `scripts/generate-companion-icons.swift` | Derive the native canvas, compile the document with Apple tooling, preserve legacy/header/menu outputs, and contextualize failures |
| `companion/Resources/Assets.car` (new), `companion/Resources/AppIcon.icns`, `companion/Resources/Info.plist` | Compiled native resource, retained legacy representations, and catalog declaration |
| `scripts/build-companion.mjs` | Include the modern resource in the existing explicit allowlist |
| `test/helpers/branding-package-probe.swift`, `test/companion-package.test.js` | Real catalog resolution, corrupt/missing asset rejection, proportions and preservation checks, existing signing/relocation/source isolation |
| `assets/branding/README.md`, `companion/README.md` | Generation tooling, resource roles, canonical output, and safe rebuild instructions |
| `docs/validation/companion-icon-rendering.md`, `docs/validation/assets/companion-icon-rendering-dock.png` (new) | Observed diagnostic, test, native visual, cleanup, and final review evidence |

No application source, routing code, source artwork, header/menu image content, or root README presentation change is planned.

## Task 1: Integrate and regress native icon packaging [size: M | risk: other | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-02, AC-04, AC-05, AC-07; contributes to AC-01 and AC-08.

**Risk:** Native icon compilation, resource lookup, and system masking can disagree even when raw image decoding succeeds. Task 2 supplies decisive Dock observation.

**Files:** The document, generator, bundle resources/plist, assembler, tests, and branding documentation listed above.

**Interfaces:** Preserve `generate(root: URL) throws`, `assembleCompanion({binaryPath,routerRoot,outputPath})`, and all existing build commands. Add private `appIconArtwork(_ image: CGImage) throws -> CGImage` to return an opaque 1024 × 1024 sRGB composition. Extend the existing Swift probe's command line with `--catalog-only`; its success output is `branding-catalog-pass`, while ordinary success remains `branding-package-pass`.

- [x] **Record the baseline before editing.** Retain the supplied gray-surround screenshot, source/resource hashes and alpha/color bounds, current icon declarations, host/toolchain versions, and affected running bundle paths in this increment's execution ledger. Establish safe scratch/ownership using the existing source-denied native package fixture. Do not run the canonical build while its bundle is in use.
- [x] **Add native catalog regressions in the existing package cases.** Require `CFBundleIconName = AppIcon`, retain `CFBundleIconFile = AppIcon.icns` and `LSMinimumSystemVersion = 14.0`, and expect `Assets.car` in both explicit resource lists. Add `--catalog-only` mode to the Swift probe: resolve `Bundle.image(forResource: "AppIcon")`, require nonempty native image representations, and emit the catalog success marker. Invoke it in a separate process against a disposable assembled copy with `AppIcon.icns` removed, avoiding resource cache reuse. Ordinary verification must also establish catalog resolution with the fallback excluded in a disposable copy.
- [x] **Cover corrupt/missing resources and preservation.** In disposable fixture copies, remove or corrupt `Assets.car` while excluding ICNS; expect a named catalog/resource failure. Extend the existing synthetic-builder missing-resource test to `Assets.car`, restoring each fixture input before the existing menu failure case. Preserve the corrupt-header case. Compare unchanged source/header/menu bytes with their known baseline hashes. Check derived native artwork has no transparent pixels and preserves source cyan bounds relative to the navy tile's visible bounds: allow at most two output pixels of resampling error in center and extent. Keep legacy ICNS size/alpha checks separate; do not require transparent corners for the modern opaque input.
- [x] **Observe RED.** Run `npm run companion:package-test` with the added expectations; expected failure names the missing catalog declaration/resource or unresolved catalog. The first assembly case exercises current committed resources without replacing `dist`; record that later built-app cases still see the old bundle. If a fresh baseline build is needed while the canonical app is running, use the previous validation record's SHA-checked disposable source mirror, with the same absolute Node 24 path, and run the existing build/package commands there. No second deliverable is added to `dist`.
- [x] **Generate the native composition without redesign.** Implement `appIconArtwork` by normalizing the complete navy tile uniformly onto the native square canvas and extending only its transparent perimeter with nearby navy background color. Preserve the cyan mark and its relationship to the visible navy tile; do not stretch, recolor, extract, or independently scale it. Store the derived image in the new native document. Configure a single flattened artwork layer with opaque navy backing, no extra padding, and no custom glass, shadow, specular, blur, or translucency effects. Let macOS apply the outer mask and ordinary edge treatment.
- [x] **Compile and package the native asset.** Extend the existing generator to compile `AppIcon.icon` in its owned temporary directory using `xcrun actool`, `--platform macosx`, `--minimum-deployment-target 14.0`, `--target-device mac`, `--app-icon AppIcon`, and `--output-partial-info-plist` there. Validate nonempty output and the reported icon declaration; commit only the required `Assets.car` output alongside the native document/derived input. Retain the existing ICNS generation and header/menu output contracts. Set the plist's catalog name, preserve its fallback/minimum/lifecycle fields, and add only `Assets.car` to the assembler's explicit resource list. Propagate native compiler failures with tool output and context, and clean owned scratch on success/failure.
- [x] **Observe GREEN and document generation.** Run `swift scripts/generate-companion-icons.swift`, then `npm run companion:build` and `npm run companion:package-test` in the safe current checkout or verified mirror. Expected: successful compilation, signed app, and all package cases passing without skips; catalog-only resolution and corrupt/missing controls run. Recheck immutable artwork/header/menu hashes after regeneration. Update `assets/branding/README.md` with Xcode requirements, derived input, native catalog/fallback roles, and the unchanged-source contract.
- [x] **Commit this integrated correction and tests.** Commit only Task 1 files with `fix(companion): package the navy icon as a native app asset`. Retain exact commands, exits, RED/GREEN proof, and any diagnostic rulings for final review.

## Task 2: Verify the Dock result and consolidate delivery [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-01, AC-03, AC-06, AC-07, AC-08; confirms AC-02, AC-04, AC-05.

**Risk:** The user may still be running one or both old bundles, and Dock caching can obscure which resource is displayed. Process ownership, normal guarded shutdown, and final-bundle observation are required.

**Files:** Targeted companion documentation, validation document/image, this increment's lifecycle metadata, and the two exact ignored local bundle paths. Consume Task 1's unchanged build interfaces and generated resources.

- [x] **Establish the native rendering cause and inspect the candidate.** Use owned scratch copies and the existing package fixture's synthetic home, source-denial protections, PID ownership, and cleanup. Compare the old ICNS presentation with the catalog-backed candidate while keeping the composition and application code fixed. Observe the actual Dock, identify each owned process/path, and record any differing resource/mask inputs. The expected candidate has one navy rounded-square surface with no gray surround, unchanged cyan-to-navy composition, and no seam at the mask. Use only available authorized native observation. If three distinct diagnostic cycles fail to establish a cause, use the debugging skill's escalation record; do not improvise an artwork redesign or claim AC-01 passed.
- [x] **Check running copies before delivery.** Recheck both exact bundle paths and any process executing inside them. If either is user-owned and still running, request normal guarded Quit and continue only after confirming exit. Do not send force signals, bypass a refusal, or replace the bundle while it is in use. Any generated candidate remains in owned disposable scratch until canonical replacement is safe.
- [x] **Build and accept the canonical app.** From the existing checkout with Node 24, run the repository's documented sequence: `npm run companion:test`, `npm run companion:build`, `npm test`, `npm run companion:package-test`, `node --check src/cli.js`, and `git diff --check`. Expected: all commands exit 0, no failed/cancelled/skipped tests, valid ad-hoc signature, modern catalog plus fallback, and passing relocation/source-denial/owned-cleanup checks. Record actual counts, not historical totals. Preserve existing lifecycle/Quit regressions; add no application behavior for verification.
- [x] **Observe the final canonical bundle in the Dock.** Launch its uninstrumented executable using the established disposable native home and owned-process setup. Verify the retained synthetic store lock, regular policy, and on-screen controls window; capture actual Dock evidence and inspect the full navy surface at a useful size. Match the executing bundle path and resource hashes to the fresh canonical build. Record the user's before screenshot and the new Dock image in validation. End only the owned test process and verify cleanup. If capture/observation is unavailable or the gray surround persists, AC-01 remains unverified/failed and this increment is not complete; resolve within scope before claiming success.
- [x] **Remove the obsolete preview only after acceptance.** Recheck no process executes from `dist/Codex Project Router Dock Preview.app`, then remove that exact obsolete bundle. Confirm the canonical signed bundle still exists, the preview is absent, and no temporary replacement app was left in `dist`. Preserve all unrelated output. This is a bounded delivery cleanup, not a new generic build-output cleanup feature.
- [x] **Document the actual result.** Update `companion/README.md` to identify the canonical output and normal guarded Quit before rebuilding an in-use bundle. Create the validation record with approval evidence, baseline/implementation commits, controlled diagnostic observations, unchanged artwork hashes/proportions, command results, native Dock image, bundle identities, cleanup, and limitations. Verify local documentation targets. Do not claim macOS 14 execution unless it was observed; distinguish retained minimum/fallback from tested host behavior.
- [x] **Complete the sole final integrated review.** Before packaging, ensure both artifacts consistently record Stage 4 and their separate approvals. Invoke `personal-workflows:code-review` once as the native workflow's sole final review seat: one immutable package containing this specification/plan, full increment diff from the preserved Dock-presence baseline, evidence, relevant unchanged context, and unique identities/hashes. Specification review runs first; quality runs only after specification PASS. Follow the skill's stop/fix-loop rules and preserve blocked evidence. Earlier historical review issues remain outside this correction.
- [x] **Commit and report the reached endpoint.** Record permitted final review results, finish this increment's checklist/lifecycle metadata, and commit documentation/evidence locally. Run `git diff --check` and inspect `git status --short --branch`; expected clean implementation branch and no whitespace errors. Report the canonical app path, actual Dock result, evidence and limits. Keep the branch/checkout without installation, push, merge, or later work.

## Verification command sources and traceability

Generation uses `swift scripts/generate-companion-icons.swift` from
`assets/branding/README.md`. Test/build/syntax/whitespace commands are the
existing `package.json` scripts and root README development sequence. Native
bundle/signature/probe/source-isolation operations reuse
`test/companion-package.test.js` and its existing Swift helper. A safe source
mirror, if needed, follows `docs/validation/companion-dock-presence.md` and does
not create a Git worktree. New catalog assertions run through these existing
commands; no separate test runner or runtime diagnostic interface is introduced.

| Criterion | Tasks and decisive evidence |
| --- | --- |
| AC-01 | Task 2 controlled native comparison and final canonical Dock image |
| AC-02 | Task 1 normalized composition assertions; Task 2 visual inspection |
| AC-03 | Task 2 running-copy checks, canonical build, and exact preview cleanup |
| AC-04 | Task 1 before/after source/header/menu hash comparisons |
| AC-05 | Task 1 reproducible compiler, plist, catalog-only and fallback checks; Task 2 fresh signed relocated package |
| AC-06 | Existing native/lifecycle and isolated package tests in Task 2; no application source changes |
| AC-07 | Task 1 RED/GREEN and negative controls; Task 2 automated/native evidence and sequential review |
| AC-08 | Task 1 branding instructions; Task 2 companion instructions, validation, and final report |

Self-review: every acceptance criterion and review-focus condition has an
implementation or observation step. Native visual acceptance supplements rather
than follows automatically from catalog decoding. Full tier is required because
the native integration is non-mechanical and visual acceptance needs observation.
No unresolved material product choice or extra approval gate has been introduced.

**Execution endpoint:** Locally commit the corrected packaged icon, one verified
canonical app bundle, documentation, regression coverage, native Dock evidence,
and final review; report the result and limits, then stop before installation,
push, merge, or another increment.

**Current stage:** Stage 4 — implementation complete. Separate specification
and plan approvals were recorded before product edits. Native icon packaging,
canonical bundle consolidation, verification, documentation, and sequential
specification/quality review are complete; see the
[validation record](../../validation/companion-icon-rendering.md). The approved
endpoint is reached: local commits and the existing checkout remain, with no
installation, push, merge, or later increment begun.
