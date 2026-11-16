# Companion branding and README validation

**Date:** 2026-11-14  
**Scope:** [Approved specification](../superpowers/specs/2026-11-14-companion-branding-readme.md) and [separately approved plan](../superpowers/plans/2026-11-14-companion-branding-readme.md). Native execution in the existing checkout on `chore/companion-branding-readme`, based on `5be89ca45ca4d50824827eed37063236a6c0f8ff`.

## Observed acceptance

The final acceptance sequence ran after switching the SwiftUI images to native
AppKit resource loading. Every command exited 0:

| Command | Decisive result |
| --- | --- |
| `npm run companion:test` | 176 Core and 62 App tests passed; 238 total, zero failures |
| `npm run companion:build` | Built and ad-hoc signed `dist/Codex Project Router.app` |
| `npm test` | 817 passed; zero failed, cancelled, or skipped |
| `npm run companion:package-test` | 3 passed; zero failed, cancelled, or skipped |
| `node --check src/cli.js` | No syntax errors |
| `git diff --check` | No whitespace errors |

Build diagnostics were the existing file-backed Security API deprecation
warnings. No new runtime dependency was added.

The initial packaging regression failed on the absent branding resources and
app-icon declaration before implementation; the completed integration passes.

The package tests exercised the exact resource allowlist, corrupt PNG rejection,
missing-resource build errors, native image decoding, transparency, app icon
sizes, menu image template metadata and logical dimensions. Relocated copies
passed `codesign --verify --deep --strict`. Native image lookup also passed in a
macOS Seatbelt process denied reads of the checkout, including lexical, resolved,
and symlink paths. The existing synthetic lifecycle checks retained their
isolated configuration, owned process groups, bounded termination, disposable
Keychain cleanup, and port-reuse assertions. All passed.

## Artwork identity and preparation

The repository originals match the supplied Downloads files byte-for-byte:

| File | SHA-256 |
| --- | --- |
| `assets/branding/codex-project-router.png` | `dce0a2d6e486622ed741b902eb3c43d71f2b5d685d24aa82726d6ca40725723b` |
| `assets/branding/menu-bar-source.png` | `71343bcb526218ab25a0a9f06a525f5986b68a34d8cecd556874f978a9561d1d` |
| `companion/Resources/AppIcon.icns` | `729568e41a5dc37512324a4b1a604a24b21feadbcf9da27e25183cf0abe09757` |
| `companion/Resources/CompanionIcon.png` | `dce0a2d6e486622ed741b902eb3c43d71f2b5d685d24aa82726d6ca40725723b` |
| `companion/Resources/MenuBarIconTemplate.tiff` | `ab61605ff0b7f10da013d254f61172b13dd0f6c3965050f37473ad7cdbf3c026` |

Repeated native regeneration produced the same three resource hashes. The ICNS
includes 16, 32, 64, 128, 256, 512, and 1024-pixel dimensions, including standard
normal/Retina representations. The menu TIFF contains 26 × 18 and 52 × 36-pixel
frames and loads as a 26 × 18-point template. The navy header remains full color.
See [provenance and regeneration](../../assets/branding/README.md).

**Ruling:** The menu source has alpha-1 noise beyond its visible mark. Crop
bounds therefore use alpha ≥16/255, plus a one-source-pixel antialias guard. A
first generated image failed the effective-symbol-height assertion; the corrected
crop passed. This preserves the original file and visible geometry. The cost if
the threshold is unsuitable is exclusion of exceptionally faint outer pixels.

## Visual and documentation observations

The actual-size menu silhouette remains readable in inspected black-on-light and
white-on-dark previews. Native decoding confirms transparent corners. These are
size/color previews rather than captures of the running system menu bar.

![Menu artwork at native size and enlarged, light/dark appearances, and navy app artwork](assets/companion-branding-icons.png)

Offscreen rendering of the actual `ControlsView` header exposed that SwiftUI's
named-image initializer omitted the loose bundled PNG even though AppKit could
load it. A comparison rendered the native image while omitting the named-image
variants. Both UI surfaces now use `Image(nsImage:)` with native resource lookup.
The header pixel check failed before this correction and passed afterward. The
menu label retains a contextual logged fallback to the original routing symbol.

The header below was rendered from the same source, with module imports flattened
only in a scratch harness and isolated temporary storage. The 36-point icon sits
beside the title without obscuring Refresh. Its decorative accessibility hiding
and the menu label's accessible app name are retained in source.

![Offscreen companion header with navy icon, title, and Refresh button](assets/companion-branding-header.png)

The README was inspected in a browser-rendered Markdown preview: the logo and
badges loaded and the introductory layout rendered. A local check passed all
52 link/image targets and fragment anchors in the README, operating guide,
companion reference, and artwork guide. All 11 original README sections remain
in the operating guide. Legacy standalone schema-1 wording was clarified against
existing managed default inheritance; no routing behavior changed.

## Limits

No installation or replacement of the running companion was performed. Finder
icon-cache refresh for an existing installation, a live status-bar appearance,
human accessibility testing, and a full interactive controls-window walkthrough
are unobserved. The offscreen header does not establish full-scroll-view
rendering. Synthetic/native package results do not establish live gateway
compatibility, billing attribution, or every macOS version's behavior. Real
private configuration and the existing companion session were not changed.

## Final review — historical blocked run, 2026-11-14

The integrated review stopped at **SPEC REVIEW: BLOCKED**. The reviewer verified
the package identity and its 21-file change list, then found inconsistent stage
metadata: the specification retains its historical Stage 3 marker while the
approved plan records Stage 4. The implementation approvals are recorded in the
plan and execution ledger. No product defect was reported, but specification
review did not return PASS, so quality review was not dispatched.

The reviewer's remedy is to correct or explicitly contextualize the
specification's stage marker and provide an updated review package. The active
review skill requires stopping on BLOCKED; that remedy has not been applied in
this run. Task 3 remains open, and final quality approval is unobserved.

- `GATE_RUN_ID`: `28241290-b5be-4e4e-8452-6a1ce0826216`
- `REVIEWED_STATE_ID`: `50f73d21-72c4-4708-8609-701673033fdc`
- `PACKAGE_SHA256`: `d9b3f68aab77af8848edf0f5f882ddd98ef562144d647942752b746c2a7a695f`
- Reviewed implementation commit: `609ee6b`.

## Closeout resumption — 2026-11-16

`AUDIT-DOCS-BRANDING-CLOSEOUT-STAGE-CONFLICT` remained open at clean `main`
`c0a5a53`, which matched both `origin/main` and actual remote `main`. The original
specification and plan presentations and their separate approval messages were
verified in **Design companion app icons**; exact turn references are recorded in
the specification. The retained execution ledger agrees. The original immutable
review package's SHA-256 was recomputed and matched its recorded identity.

The specification now contextualizes its historical Stage 3 handoff and records
the authorized Stage 4 resumption. Approved requirements and the BLOCKED review
above are preserved. Review scope is the original branding increment from
`5be89ca` through `2c20965`, plus the closeout documentation corrections on
`docs/companion-branding-closeout`; later account/default, Dock and icon reviews
are not reopened. Later approved Dock/icon behavior remains authoritative.

This resumption changes documentation only. The acceptance counts above remain
2026-11-14 evidence. No fresh full test suite, build, app launch, credential
retrieval, settings change or live application observation was performed for this
resumption. The resumed sequential review results are recorded below.

## Resumed final review and local closeout — 2026-11-16

The outstanding integrated review continued with one updated immutable package.
The specification reviewer recomputed its hash, matched the expected identities,
verified both file lists/diffs and returned **SPEC REVIEW: PASS**. A citation-only
report correction removed invalid snapshot line suffixes; neither the package nor
the substantive verdict changed. Only then was quality review dispatched with
the unchanged package and complete fresh specification PASS report.

Quality independently matched expected/current/specification-PASS identities and
recomputed the package hash. It verified all 21 snapshot files against the package
or exact binary hashes, reviewed the original branding changes and three closeout
documents, and returned **QUALITY REVIEW: PASS — findings: NONE**. No fix pass,
deferred minor, generic reviewer or later-increment review was dispatched. The
package hash was independently rechecked unchanged after both stages.

- `GATE_RUN_ID`: `f906e14a-e9e6-46c6-915a-f051d37b8e8c`
- `REVIEWED_STATE_ID`: `6144655d-2d88-4a64-930c-b34d6f1aadcb`
- `PACKAGE_SHA256`: `fb934af29b858db302b27bd7bff0fd8a880aea6ce7e6afec9bce212de0e0a514`
- Original implementation/review range: `5be89ca..2c20965`; 21 changed files.
- Closeout base: `c0a5a53`; three Markdown documents, with no product changes.

Fresh bounded checks passed: `git diff --check` and local Markdown target checks
for the closeout documents. No fresh full suites, build or live-app checks were
performed for this documentation-only completion. The recorded 238 native, 817
Node and three package tests remain the original 2026-11-14 acceptance. Later icon
acceptance and current operational state are not substituted for those results.

Quality explicitly declined to judge present-runtime compatibility, fresh full
suites, live menu-bar appearance, Finder caching, human accessibility and full
window interaction, which it did not observe. These remain the stated evidence
limits, not additional passes or newly established capabilities.

**Ruling:** Review the complete original branding range with corrected governing
metadata, without reopening later approved increments. This preserves review
ownership and the user's required separation. The cost is that later regressions
are outside this historical branding review; no current-runtime acceptance is
claimed. The original alpha-threshold crop ruling and its faint-pixel tradeoff
remain recorded above, with no artwork changes in this closeout.

`AUDIT-DOCS-BRANDING-CLOSEOUT-STAGE-CONFLICT` is resolved. The existing branding
increment's Task 3 review and local documentation closeout are complete. Final
edits only record observed results and consistent lifecycle/checklist metadata.
The separate local `docs/companion-branding-closeout` branch is retained; `main`
is unchanged, and no worktree, assignment artifacts/product changes, push or merge
are part of this closeout.
