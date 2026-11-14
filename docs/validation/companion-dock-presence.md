# Companion Dock presence validation

**Date:** 2026-11-14

**Specification:** [Approved scope](../superpowers/specs/2026-11-14-companion-dock-presence.md)

**Plan:** [Separately approved plan](../superpowers/plans/2026-11-14-companion-dock-presence.md)

**Branch:** `feat/companion-dock-presence`

**Baseline:** `2c209656821a1017bf38f87880cce1c8bd600c69`

The user confirmed the proposed behavior with “ok, implement this,” approved the
separately presented specification with the first “approved,” and approved the
separately presented plan with the second “approved.” Both approved artifacts
were saved and committed before product edits. Native execution retained the
current session model. The baseline includes the earlier local branding work;
that increment's separate pending review is outside this review's scope.

## Delivered behavior

Opening controls requests regular application presence. Successful controls
closure requests accessory presence and retains the app/controller and router.
Minimizing and hiding preserve regular presence. Only the owned controls
window's close notification can clear guidance, change polling, or demote the
app. All opening paths converge on the same method, while native termination
still enters the existing guarded Quit flow.

The native setter checks the current AppKit policy without caching it. An
already-matching policy succeeds without a redundant setter call; a rejected
change is logged contextually and retried on the next relevant window action.

## Regression evidence

- Before implementation, the package's new PID-specific check reported
  `missing-regular-policy` alongside `visible-native-window`. The app was
  visible but remained an accessory. Two other package cases passed.
- After adding only the initializer/read-only-window test seam, native tests
  failed on missing regular/accessory requests and on unrelated close
  notifications clearing controls guidance. The completed delegate passed
  176 Core and 67 App tests, 243 total, and all three package cases with no skips.
- The held-account-save test uses actual `performClose`: a refused close keeps
  the window and regular policy, while an allowed close demotes it. Tests also
  cover real close/reopen reuse, unrelated/malformed notifications, minimized
  callbacks, rejected transitions/retries, and guarded native Quit/recovery.
- Synthetic owned-router ID, Off mode, journal bytes, and backend
  start/control/stop/mode-set counters remain unchanged across window cycles.
  Read-only refresh is permitted. Delayed quit-guidance refresh cannot restore
  navigation after an actual controls close.
- The first native RED run also exposed an unchanged timing-sensitive failure
  in `ProcessBackendTests.testCancelledMutationIsRetainedAndNotRetried`
  (`kill(pid, 0)` returned -1). Its fixture reads a PID after a fixed delay and
  can encounter the earlier inspection PID before the new helper writes it.
  The unchanged test passed in an isolated rerun and the subsequent full native
  GREEN run. No Core source or test was changed.
- Establishing a real window in the existing delayed-guidance test required
  waiting for its scheduled opening refresh before taking the inspection
  baseline; a direct `refreshAndWait` alone did not drain that scheduled task.

## Native observation

Accessibility trust was unavailable (`AXIsProcessTrusted() == false`); no new
permission was requested. An isolated probe build therefore retained the exact
production scene/delegate and added only a launch task calling a separate
verification source. It drove the real AppKit window and policy APIs in its own
process. The ordinary shipped binary was checked separately by package tests.

The probe used a disposable native home, the same `CFFIXED_USER_HOME` and
Seatbelt protections as packaging, direct executable launch, and PID ownership.
It verified the synthetic store lock before the transitions, unchanged journal
bytes, no created configuration or owned router, and no requested Quit. Its
owned process group and temporary tree were removed afterward.

| Native probe condition | Observed result |
| --- | --- |
| Launch | Regular policy and visible controls |
| Minimize | Window minimized; regular policy retained |
| Open controls after minimization | Same window restored; regular policy |
| Hide | Application hidden; regular policy retained |
| Open controls after hiding | Application unhidden and active; window key |
| Close and application reopen, twice | Accessory after each close; regular after each reopen; same window |
| End of cycles | One controls window; no router; no Quit request |

The first probe emitted false rejection diagnostics on already-matching policy
requests. A new probe assertion failed on those diagnostics, then passed after
checking the live policy before calling the setter. The final native probe
passed every row without a rejection diagnostic. Unit tests deliberately
returning `false` still exercise and emit the real rejection diagnostic.

**Ruling:** An already-matching native policy is treated as success using a live
query, without caching. This avoids false errors from redundant AppKit requests.
If a native query were stale, a transition could wait until the next action;
the observed cycle checks establish the resulting policy for this run.

## Build isolation and acceptance

**Ruling:** The user's running companion occupied the usual `dist` output.
After the initial unchanged-source baseline build, subsequent builds and package
verification used this increment's scratch source mirror and a separate preview
artifact. No Git worktree was created. All 118 repository files present at the
acceptance snapshot were copied and SHA-256 checked against the working tree
before running acceptance. This guards against divergence between the built
sources and the implementation. Later validation/checklist metadata is recorded
after acceptance and does not alter production or test inputs.

The default shell in that mirror initially selected Homebrew Node 26, which the
package check rejected. Subsequent mirror commands explicitly selected the same
installed Node 24.21.0 used by the project checkout; no product change was made
for that environment mismatch.

Final combined acceptance ran after the no-op diagnostic correction. All six
commands exited 0, using Node 24.21.0:

| Command | Observed result |
| --- | --- |
| `npm run companion:test` | 176 Core + 67 App tests passed; 243 total, zero failures, including the earlier cancellation regression |
| `npm run companion:build` | Fresh release app built and ad-hoc signed in the source mirror |
| `npm test` | 817 passed; zero failed, cancelled, or skipped |
| `npm run companion:package-test` | All 3 passed; zero failed, cancelled, or skipped |
| `node --check src/cli.js` | No syntax errors |
| `git diff --check` | No whitespace errors |

Package verification retained strict signatures, resource decoding/template
checks, relocated execution, checkout-read denial, and the native visible-window
and regular-policy assertion. Its synthetic lifecycle, disposable Keychain,
owned-child/process-group shutdown, and port-reuse checks passed. The existing
Security API deprecation diagnostics remain; no new compiler warnings were
introduced. Documentation checks passed 54 local link/image/anchor targets. A staging
whitespace check caught Markdown hard-break spaces in this new record; they
were normalized before reviewer dispatch, and the full increment diff was
checked again.

A separate uninstalled build is preserved as
`dist/Codex Project Router Dock Preview.app`, leaving the existing running
session in place. A safe quit and subsequent launch of the new build is needed
to use the new lifecycle. No app was installed or launched on the user's behalf.

## Limits

Native window/policy/focus checks establish the transitions above; visual Dock
icon presentation, the Command-Tab overlay, persistent menu-item appearance, and
mouse-driven Dock Quit were not visually inspected. Guarded native termination
is covered by delegate regressions. Minimize/hide/close/reopen observation used
the instrumented disposable build, while the uninstrumented relocated binary
is checked for regular policy and a visible window by package verification.

Pinned/recent Dock items follow user preferences. The existing running session
was not quit or reconfigured, and no installation, push, or merge was performed.
These checks do not establish every macOS version's behavior, live gateway
compatibility, or billing attribution. The earlier branding review remains
separate historical work.

## Final review

The integrated specification-then-quality review is pending final acceptance.
Review identity and results will be recorded after the gate. Both governing
artifacts currently record Stage 4 and their separate approvals.
