# Keychain lookup fix validation

Created: 2026-11-20

Updated: 2026-11-20

Scope: `keychain-lookup-fix`; approved specification and matching plan dated
2026-11-20. Stage 4 in progress; automated verification passed, while rebuilt-app
interaction acceptance and final review are pending. No push or merge is authorized.

## Evidence boundary

The earlier user-Keychain diagnosis used metadata only and established that
unusable unrelated rows could abort discovery despite a supported exact match.
That diagnosis is historical defect evidence, not acceptance of the changed app.

Current automated tests inject only the native Security boundary and retain real
KeychainStore, controller and SwiftUI behavior. All fixture references and state
are synthetic. No real user credential was read, created or changed by these
focused tests, and no real router/configuration was started or modified.

## Checks actually run

| Command | Observed result |
|---|---|
| `npm run companion:test` before implementation | Exit 0; 268 core + 111 app tests; zero failures |
| `swift test --package-path companion --filter KeychainStoreTests` RED | Exit 1; expected missing `browseMetadata` API before implementation |
| Same core command GREEN and task completion rerun | Exit 0; 16 tests; zero failures |
| `swift test --package-path companion --filter AccountSetupControllerTests` RED | Exit 1; new listing/count contract absent |
| `swift test --package-path companion --filter AccountSetupPresentationTests` RED | Exit 1; completed state did not accept omission count |
| `swift test --package-path companion --filter AccountSetupActionTests` RED | Exit 1; integration contract absent before implementation |
| The three preceding focused commands GREEN | Exit 0; 23 controller, 16 presentation and 5 action tests; zero failures |
| Action suite after adding viewport reachability checks | Exit 0; 5 tests; zero failures |
| `npm run companion:test` after integration | Exit 0; 279 core + 115 app = 394 tests; zero failures |
| `npm run companion:build` | Exit 0; rebuilt and ad-hoc signed the canonical dist app |
| `npm test` | Exit 0; 1,095 passed; zero failures, cancellations or skips |
| `npm run companion:package-test` | Exit 0; all 3 passed; zero failures, cancellations or skips |

SwiftPM compiles the test targets before filtering, so the initial integration
RED runs can report a missing interface in another selected test target. The
failure reasons were the planned not-yet-implemented listing/completion contracts.
Full logs are temporarily retained in this plan's ignored execution workspace;
the durable results and boundaries are recorded here.

## Native fixture inspection

The real AccountSetupView was hosted at its existing 650×690 logical size using
the existing NativeProjectHost. Tests scroll to the metadata selector and assert
that its explanation and Use action are inside the visible scroll viewport.
The initial unscrolled captures did not show the result area; only the subsequent
scrolled captures support the observations below.

Four synthetic PNGs under ignored `companion/.build/project-list-qa/` were inspected:
`keychain-mixed-results`, `keychain-omitted-only`, `keychain-failed` and
`keychain-pending`. Match counts, omitted counts/explanation, captured scope,
picker and disabled Use action were readable without observed overlap. The
pending view retained “any service” after the service field was edited. Failed
and pending states had zero picker results and no stale omission explanation.
The scroll view preserved access to other form fields and fixed Close/Save actions.

Native interaction assertions cover a user-entered draft name surviving repeated
lookups, no automatic item application, no save/start/activation, and no receipt
or lease creation. Successful popup selection in the rebuilt production app is
still unobserved and requires the coordinated acceptance check; it is not implied
by hosted-view assertions.

## Acceptance coverage

| Criteria | Evidence / current status |
|---|---|
| AC-01, AC-02 | Mixed/missing/type/empty/control/limit/Unicode rows, row order, once-per-row omission, empty and all-omitted tests pass; UI counts inspected |
| AC-03 | Secret-bearing and contradictory fields take precedence over omission, including mixed-invalid rows and either order; fixed safe errors |
| AC-04, AC-05 | Later-Keychain/native/search-list/path failures reject entire results; filter/path scope and duplicate search paths tested; native decoding/open guards unchanged |
| AC-06 | Strict listing/exact lookup rejects omitted rows; existing duplicate/cross-Keychain ambiguity and exact validity tests pass; incoming/recovery strictness tested |
| AC-07 | Attribute-only/file-backed queries, serial execution and zero focused-test mutations asserted; creation/native adapter unchanged; full package regression passed |
| AC-08 | Presentation states, captured scope, clearing, disabled Use and draft preservation pass; actual rendered result area inspected; production selection pending |
| AC-09 | Controller preview/default/bindings preserved; no saved configuration/receipt/lock writes in browse fixtures; malformed recovery evidence retains receipt/lock and blocks creation; full regressions passed |
| AC-10, AC-11 | Focused RED/GREEN and fixture visual evidence complete; full chain passed; production observation, final review and closeout pending |

## Production metadata-only probe and remaining search-list limitation

A supplementary, temporary count-only harness was compiled from the actual
production sources using the same `xcrun swiftc -parse-as-library -target
arm64-apple-macos14.0` source list as the existing package probe. It called only
`KeychainStore.browseMetadata` and emitted fixed outcomes/counts, never item
identities or values. The initial unrestricted invocation exited 1 with a fixed
failure marker; a bounded diagnostic then established:

| Scope | Actual production result |
|---|---|
| Native search list | Unsupported; no partial result published |
| Exact supported login Keychain | 59 selectable references, 10 omitted items |
| Exact second supported user Keychain | 0 references, 0 omissions |

The cause was isolated without changing product code: `SecKeychainCopySearchList`
returned three paths, including the system-owned System Keychain. Its file was
regular but not owned by the user, so existing native opening validation rejects
it. The command-line user-domain list exposed only two user-owned paths; that
command is not equivalent to the native API used by the product. A separate
metadata-only shape probe confirmed native list success/count 3 and ownership
false for the system path, without opening items or retrieving credentials.

This is the approved whole-Keychain failure boundary, not a reason to silently
skip an unsupported Keychain or broaden the reader. The row-handling fix is
verified by the successful production login result, which previously failed on
unusable unrelated rows. Exact path selection remains necessary for this user's
full native search-list environment. Any automatic exclusion/partial-success
policy would require separately confirmed scope. No additional product change
was made during this investigation.

## Remaining checks

The full changed native suite, signed app build, Node suite and three package
checks passed. The package harness exercises owned disposable native items,
reader comparison and bounded failure cleanup; it does not read or modify the
user's existing credential values. File-backed Security API deprecation warnings
remain an intentional compatibility limitation, without global suppression.

Before rebuilding, the prior app was asked to Quit through its normal application
event. The initial event returned cancellation because its delegate initially
cancels termination; subsequent process inspection confirmed the old process had
exited. No force quit or router Stop was used. The rebuilt canonical app was then
opened and observed running at its exact dist executable path (PID 10738 in this
session). System Events again reported zero accessible companion windows. No
accessibility-enhancement loop was repeated.

The user was initially asked for an unrestricted listing. After isolating the
unsupported-system-Keychain failure, the live check was corrected to an exact
supported login path with empty service/account filters, explicit reference
application in an unsaved Add account form, then Close without Save. That
production interaction remains unobserved until the user reports it. Final
sequential specification/quality review has not yet run. Record each result here
before claiming completion.

Real Keychain query failures still reject a whole listing. Metadata compatibility
never proves credential readability, provider acceptance or billing attribution.
