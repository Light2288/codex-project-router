# Keychain lookup fix validation

Created: 2026-11-20

Updated: 2026-11-20

Scope: `keychain-lookup-fix`; approved specification and matching plan dated
2026-11-20. Stage 4 in progress; full verification, rebuilt-app acceptance and
final review are pending. No push or merge is authorized.

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
`keychain-pending`. Match counts, omitted counts/explanation, captured scope,+picker and disabled Use action were readable without observed overlap. The
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
| AC-07 | Attribute-only/file-backed queries, serial execution and zero focused-test mutations asserted; creation/native adapter unchanged; full package regression pending |
| AC-08 | Presentation states, captured scope, clearing, disabled Use and draft preservation pass; actual rendered result area inspected; production selection pending |
| AC-09 | Controller preview/default/bindings preserved; no saved configuration/receipt/lock writes in browse fixtures; malformed recovery evidence retains receipt/lock and blocks creation; full regressions pending |
| AC-10, AC-11 | Focused RED/GREEN and fixture visual evidence complete; full chain, production observation, final review and closeout pending |

## Remaining checks

The full changed native suite, signed app build, Node suite and three package
checks have not yet run for this changed integration. Production app metadata
listing and explicit selection have not yet been observed. Final sequential
specification/quality review has not yet run. Record each result here before
claiming completion.

Real Keychain query failures still reject a whole listing. Metadata compatibility
never proves credential readability, provider acceptance or billing attribution.
