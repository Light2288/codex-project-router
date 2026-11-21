# Package window observer readiness validation

Created: 2026-11-21

Updated: 2026-11-21

Scope: `package-window-observer-readiness`, governed by the approved specification
and matching plan dated 2026-11-21. Stage 4 complete: the test-only correction,
verification, sole final sequential specification/quality gate and local
documentation closeout are complete. No push or merge is authorized.

## Historical evidence and boundary

The preceding read-only investigation observed the exact native test predicate
briefly becoming true while a subsequently started Swift observer missed it.
One passing diagnostic measured approximately 430 ms from observer invocation to
its first output, only about 38 ms before the independently observed window left
the on-screen list. The failed diagnostic did not measure its actual first-sample
time. This supports an observer startup race; it does not establish the precise
macOS mechanism behind the visibility transition.

The user reported that Codex was in full-screen mode. This increment does not
change or independently certify the current Space/full-screen configuration.
No screenshot, window content or GUI control interaction is inferred from the
metadata observation.

Earlier Keychain implementation results and default-parallel window failures
remain recorded in `docs/validation/keychain-lookup-fix.md`. They have not been
rewritten as results of this correction.

## Implemented behavior

The package test prepares an owned Swift observer, including initialization of
the application/window query boundaries, before launching its relocated native
app. A readiness acknowledgement gates launch. The exact native child PID is
then supplied immediately, before checking the synthetic instance lock.

One absolute 20-second deadline starts before observer startup. The existing
regular-activation, exact-PID, on-screen layer-0 predicate and 25 ms polling
cadence remain. A matching observation marker and successful observer exit are
required. Instance-lock proof and all downstream checks still run before success.
The overall native package test timeout remains 60 seconds.

Observer processes are registered with the existing owned-process lifecycle,
including an owned process group, and explicitly stopped/reaped on every path.
The parser rejects invalid/duplicate/mismatched protocol and stdout over 8 KiB;
failure diagnostics retain at most 4 KiB from each captured stream. Observation
and cleanup failures are both preserved when they occur together.

## Checks actually run

| Command/check | Observed result |
|---|---|
| Baseline `npm test` before test changes | Summary: 1,095 passes, zero failures/cancellations/skips, 63.395 s. The shell wrapper subsequently exited 1 because it assigned zsh's read-only `status` variable; the npm exit code was not separately retained. Subsequent wrappers use a task-specific variable. |
| `node --test --test-name-pattern='^native window observer' test/companion-package.test.js` RED | Exit 1; expected assertions that the coordinator and shared Swift predicate were not implemented. |
| Initial GREEN attempt | Exit 1; 6/28 passed. The cleanup assertion incorrectly counted the lifecycle's own `once(close)` error listener as a helper leak. It was corrected to preserve that original listener; lifecycle ownership was not changed. |
| Same focused observer command GREEN | Exit 0; 28/28 passed, zero failures/cancellations/skips, 0.322 s. |
| `node --test --test-name-pattern='^native relocated app and bundled controls' test/companion-package.test.js` | Exit 0; 1/1 passed, 8.721 s. |
| Same native command through required task-completion check | Exit 0; 1/1 passed, 8.698 s. |
| `npm run companion:package-test` | Exit 0; 31/31 passed, zero failures/cancellations/skips, 33.653 s. |
| First standard parallel `npm test` after implementation | Exit 0; 1,123/1,123 passed, zero failures/cancellations/skips, 63.423 s. |
| Focused observer command after strengthening the UTF-8 diagnostic-bound assertion | RED: exit 1, 27/28 passed; the byte-cap assertion failed. GREEN after correction: exit 0, 28/28 passed, 0.328 s; task-completion check also passed 28/28. |
| Standard parallel `npm test` on corrected code (`79ba868`) | Exit 0; 1,123/1,123 passed, zero failures/cancellations/skips, 63.593 s. |
| Required task-completion/branch-finishing standard parallel `npm test` | Exit 0; 1,123/1,123 passed, zero failures/cancellations/skips, 63.397 s. Run after final review on unchanged tested code. |
| `git diff --check` after implementation | Exit 0. |

The new checks use controlled process events/streams and mocked time rather
than readiness sleeps. They exercise the real coordinator. The real Swift
predicate is separately compiled and executed against injected window metadata,
including a source that exposes an off-screen window only to an incorrect query.

The isolated package run executed all three original package cases, not just
the new regressions. It passed signature/resource verification, Seatbelt denial
controls, synthetic lock/window observation, projectless/project-list fixtures,
assignment and routing lifecycle assertions, byte-exact provider rollback,
scratch-Keychain cleanup, owned PID/process-group absence and port reuse. The
existing 13 intentional file-backed Security API deprecation diagnostics remain.
That isolated run preceded the UTF-8 diagnostic-bound correction; the subsequent
full parallel run executed all package cases on the corrected code as well.

## Acceptance coverage

| Criterion | Evidence |
|---|---|
| AC-01 | No launch before full readiness, buffered/fragmented readiness, and startup spawn/error/exit/timeout cases; real package integration uses the same coordinator. |
| AC-02 | Shared Swift predicate rejects wrong/missing PID or layer, nonregular activation and off-screen-only evidence; wrong-PID observation markers fail; real exact-PID predicate passed. |
| AC-03 | Mocked readiness at 19,500 ms leaves 500 ms; timeout occurs at the original deadline. Real integration supplies one 20-second absolute deadline before startup. |
| AC-04 | Immediate result during PID handoff is retained; real observation precedes the independently required exact-PID synthetic lock check and unchanged downstream assertions. |
| AC-05 | Launch/exit races, observer/native/stream errors, invalid protocol, unsuccessful completion and combined cleanup failure checks pass. Existing owned-process/group and port checks passed in the real package run. |
| AC-06 | All 28 focused checks passed, including actual Swift predicate execution and controlled transient-result delivery without timing sleeps. |
| AC-07 | Focused and isolated package verification passed; three post-implementation standard parallel runs passed, including two runs of all package cases on corrected code. |
| AC-08 | This report preserves commands, failure history and limitations. Sequential specification and quality reviews both passed with no findings, followed by the final completion check and documentation closeout. |

## Preservation and limitations

Only tests, their helper and documentation change. Production routing, accounts,
assignments, Keychain behavior, UI startup and distribution are unchanged. No
macOS preference or Space change was made. The existing signed canonical app
was used without rebuilding/replacing/quitting it; its PID was still 10738 after
final verification. Full Swift tests and a companion rebuild were not rerun for this
test-only increment.

Package verification retains its existing owned disposable credential fixtures;
no real user's credential value or account/routing configuration was inspected
or changed by this fix. The source-denial policy and its negative controls remain
unchanged.

Passing runs demonstrate the corrected observation order in this environment,
not a guarantee for every macOS presentation condition. A genuine failure to
publish the required on-screen window must still fail the test. No broader
product startup or original router-timeout diagnosis is claimed.

## Review and local delivery

Branch: `test/package-window-observer-readiness`, stacked on preserved Keychain
tip `d905867c7dcfac99b0a0188962fd274f2c689fe4`. The Keychain branch remains intact.
Main's fast-forward-only update found it already current. No worktree, push or
merge was performed.

- `d0424bf` — approved specification and implementation plan.
- `e08ef36` — observer readiness correction and regression coverage.
- `79ba868` — enforce diagnostic excerpts in UTF-8 bytes, verified RED/GREEN.

The sole final integrated gate returned **SPEC REVIEW: PASS**, then **QUALITY
REVIEW: PASS**, with no findings or deferred minors. Both reviewers recomputed
the package hash and verified the same identities; quality received the full
specification PASS report and unchanged package.

- Specification reviewer: `/root/window_spec_review` (`review-spec`, configured light role).
- Quality reviewer: `/root/window_quality_review` (`review-quality`, configured full role).
- `GATE_RUN_ID`: `91a50f2e-3a27-4b4f-8aed-813d92f09c0e`.
- `REVIEWED_STATE_ID`: `34773586-9242-4f78-8c7a-7a003b6bed24`.
- `PACKAGE_SHA256`: `d5cf15ca10cb5332739e1d3628aeeb0f73fa6a43df7dba4d76ecf4e8fee6552a`.

The reviewed package covered the complete five-file increment against the
preserved Keychain tip, including current staged documentation, full relevant
sources, approval evidence, observed test results and the enclosing one-pass
review policy. No generic final reviewer, substitute reviewer, remediation pass
or independent review loop was used. No scope/plan rulings were required.

Only result/lifecycle documentation is updated after review; tested code remains
`79ba868`. The final documentation commit, `docs: record window observer readiness
validation`, contains this completed delivery record. Plan-owned execution scratch
is removed after preserving the evidence above; no sibling workspace is touched.

The execution endpoint is reached. The branch is kept local with a clean tracked
checkout, preserving the Keychain branch and all its commits. No integration
action is taken. Later roadmap work remains outside this increment.
