# Companion project routing On/Off validation

Created: 2026-11-12
Updated: 2026-11-12

Status: fresh automated packaging acceptance passed. Native/live acceptance,
actual private recovery and the final sequential specification/quality review
remain pending for Task 8. This report does not establish release completion.

Scope: the approved `companion-routing-on-off` increment. The approved
[specification](../superpowers/specs/2026-11-12-companion-routing-on-off.md) and
separate [implementation plan](../superpowers/plans/2026-11-12-companion-routing-on-off.md)
govern the integrated capability. Earlier validation reports remain historical
records with their original limitations; their results are not fresh evidence.

## Capability and boundaries

Explicit Start creates an owned listener with project routing Off. After initial
provider activation to a stable loopback URL, manual Codex restart and independent
working-response confirmation, ordinary On/Off changes need no desktop restart.
On applies explicit project overrides; an identified project without an override
inherits the existing global provider pair. Off retains saved overrides and uses
the global pair without looking up project credentials. In credential mode the
incoming authorization must first match a fresh global-credential read. Legacy
aliases retain the caller's credential and cannot select separate accounts.

Requests capture mode at HTTP receipt before the first asynchronous lookup;
active requests keep their chosen destination/credential and are never migrated
or retried. Identity/admission checks still apply. Supplied malformed/incomplete
targets fail strict loading in either mode; a selected explicit override failure
never falls back. Mode commands do not fetch credentials or probe destinations.
No HTTP mutation endpoint or credential-bearing control message is introduced.

Mode, readiness, ownership, on-disk provider state and desktop confirmation remain
independent. Uncertain commands require fresh read reconciliation before another
write; commands are never retried automatically. A mode-only acknowledgement or
read does not change the configuration fingerprint, provider URL, activation
record or restart/response obligations. Off still requires the listener and does
not authorize Stop or Quit. Restore direct, manual restart, working-direct-response
confirmation and guarded owned-child stop remain a separate recovery flow, bound
to the selected/retained context. External listeners are never adopted or signalled.
No automatic startup, last-used On restoration, desktop restart, fallback or
account/assignment management is delivered.

## Task 7 test-first packaging evidence

`npm test` ran before the production allowlist change: exit 1, 718 tests,
715 passed, 3 failed, 0 skipped. The assembly fixture correctly detected omitted
`src/managed-serve.js`; the relocated case detected the previous artifact's
omission. The source-denied case also exposed a test-fixture provider/upstream URL
mismatch introduced while adding the local HTTPS observer. That fixture was fixed
before proceeding; this third failure is not evidence for the product omission.

A subsequent focused `npm run companion:package-test`, still before the allowlist
change, exited 1: 3 failed, 0 skipped. Assembly and relocated resource assertions
required the missing file; the source-denied managed launch failed with
`MODULE_NOT_FOUND` for the bundled managed entry. Its negative checkout-read,
visible native window and positively attributed synthetic instance-lock controls
passed first. Stale-artifact failures are not acceptance results.

The production change adds only `managed-serve.js` to the explicit source list.
The three existing package tests are extended, without adding a fourth. They keep
arm64/signature checks, pinned dependency drift rejection, sentinel/private-file
exclusion, no embedded checkout/runtime path and minimal GUI environment. Managed
Ready Off, persistent stdin and correlated get/set On/get/set Off are exercised
both before and after synthetic activation. Checks compare the same retained
listener PID, health fingerprint, provider/router bytes, activation bytes and
inspection revision while a local HTTPS observer requires zero TCP connections.
Standalone `serve` remains covered.

Source-denial uses synthetic HOME/CFFIXED_USER_HOME, denies real private paths and
checkout reads including symlinks, proves negative reads/imports, and attributes
the native instance lock to the exact launched process. Tracked children drain
both outputs, and cleanup checks child exit and synthetic-port reuse even after
assertion failure. This establishes automated fixture behavior; no GUI control
interaction or live account acceptance is inferred.

## Fresh automated acceptance

These commands ran in the order below on 2026-11-12. The current signed app was
built before both final Node/package runs, so neither used the earlier artifact.
Full outputs and actual command exits were inspected; the complete logs and
command/exit/time manifest remain in the ignored task workspace during execution.

| Command | Exit | Fresh observed result |
| --- | --- | --- |
| `npm run companion:test` | 0 | 116 core + 44 app = 160 native tests, 0 failures |
| `npm run companion:build` | 0 | Current release app built and ad-hoc signed |
| `npm test` | 0 | 718 passed, 0 failed, 0 cancelled, 0 skipped |
| `npm run companion:package-test` | 0 | Exactly 3 passed, 0 failed, 0 cancelled, 0 skipped |
| `node --check src/cli.js` | 0 | No syntax diagnostics |
| `git diff --check` | 0 | No whitespace diagnostics |

Passing logs contained no compiler/runtime warnings or failure diagnostics. All
160 named native test starts had matching passing completions. The fresh package
run established the managed exchanges and unchanged synthetic bytes described
above, retained standalone compatibility, revalidated the negative source controls
and positively attributed native lock/window, and confirmed tracked child exit
plus reusable synthetic router/upstream ports. Local documentation links were
checked. Documentation-only evidence updates after this run do not change the
signed artifact or tested source.

## Pending acceptance and evidence limits

- Native interaction with the current signed build: explicit Start Off, truthful
  On/Off and uncertainty display, searchable override/inheritance rows, responsive
  layout, disclosures, keyboard/accessibility behavior and existing recovery/Quit
  flows. Automated visible-window presence is not this interaction evidence.
- Live desktop acceptance with existing approved private configuration: one-time
  integration and independent restart/response confirmation, On override behavior,
  Off global behavior, later On behavior and the approved active-stream switch
  case. Record every required case as observed pass, observed failure or not run.
- Actual private recovery: restore exact prior provider/router settings and optional
  property presence, preserve unrelated edits, restart as required, independently
  verify a direct response, then verify exact owned-child exit and port state.
  Actual endpoints, credentials/references, mappings, checkpoints and raw runtime
  evidence stay outside Git.
- Final whole-branch sequential specification then quality review, including
  disposition of remaining evidence limitations, is pending.

The Task 3 blocked-output test counts reads rather than measuring actual retained
input bytes. Its passing result must not be described as a direct retained-byte
measurement; production retention guards have task review, with this test-evidence
limitation reserved for final-review disposition. Synthetic routing and transport
evidence does not establish gateway account/billing attribution or complete live
stream delivery. No real private-state read, credential lookup, provider mutation,
Codex restart or live model request was performed for Task 7.
