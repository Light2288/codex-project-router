# Companion account and default setup validation

Created: 2026-11-13
Updated: 2026-11-14

Status: locally complete. Post-fix automated acceptance and the sole final
sequential gate are complete: specification PASS and quality APPROVED on
`ee8bd85`, both original findings addressed and no new findings. Earlier human
native/live observations and exact operational recovery remain recorded with
their limits; no post-fix human UI/live repeat is claimed. Parent final archival,
checks and reporting form the endpoint. No push, merge or next increment is
authorized.

Scope: the approved account/default setup increment, governed by its
[specification](../superpowers/specs/2026-11-13-companion-account-default-setup.md)
and [implementation plan](../superpowers/plans/2026-11-13-companion-account-default-setup.md).
Account editing/deletion, assignment editing, running reload, fallback and
automatic restart remain deferred. Original direct recovery remains distinct
from the configured outgoing default.

## Automated acceptance

The final ordered acceptance on post-fix implementation `ee8bd85` ran from the
repository with every command exiting 0 in the required order:

| Order | Command | Decisive result |
| --- | --- | --- |
| 1 | `npm run companion:test` | **238/238**: 176 Core + 62 App, zero failures |
| 2 | `npm run companion:build` | Current release app built and ad-hoc signed |
| 3 | `npm test` | **817/817**, zero failures/cancellations/skips/todo |
| 4 | `npm run companion:package-test` | Exactly **3/3**, zero failures/cancellations/skips/todo |
| 5 | `node --check src/cli.js` | Passed, no output |
| 6 | `git diff --check` | Passed, no output |

The pre-fix diagnostic revision passed 236 native tests (176 Core, 60 App),
812 Node tests and three zero-skip package tests, plus signed build/syntax/
whitespace. The still earlier repair run passed 234 native tests (176 Core,
58 App). Both are historical results, superseded for current-source automated
acceptance by 238/817/3 above. Parent independently rechecked the earlier decisive
proof and signature; neither earlier signed artifact is relabeled as the final
post-fix human UI observation.

The current signed artifact is an ignored local Apple-silicon app, not a
distribution notarization claim. Current package results use the rebuilt
post-fix artifact. Earlier development failures and native/live observations
below retain their original attribution.

Test-first `npm test` failed before the production resource change: 808 tests,
805 passed, three package failures and zero skips. Assembly decisively required
the missing setup module. This RED/stale artifact result is not acceptance.
A separately reproduced missing-selected-destination integration bug was fixed:
explicit normal-home browsing now survives a genuinely absent selection without
inventing context/mappings; valid selected files keep their own home and unsafe
existing evidence cannot trigger that fallback.
The three existing package cases cover explicit resource allowlists, relocated
schema-1 import with byte-exact checkpoint and standalone compatibility, and
source-denied schema-2 first setup/default completion. Their managed starts must
begin Off; activation/rollback retain the original provider connection. Synthetic
references in ordinary cases deliberately do not exist, and no model traffic or
credential lookup is needed for these controls.

The native subcase compiles a test-only Swift executable with production
KeychainStore/types. It may create only its positively owned disposable Keychain
and item. Public fixture values remain in process memory, with paths/references
only in arguments and fixed comparison markers in output. It checks metadata,
add-only duplicate rejection and the bundled fixed reader, then validates owned
cleanup. Search-list cleanup filters only its owned entry from the current list;
it never restores a historical whole list or changes the default Keychain.
This harness trusts its own executable plus the fixed reader. Its identity is
different from the packaged app's identity, so success cannot establish native
app consent or its actual ACL identity.

The actual native subcase passed production metadata/add, duplicate rejection,
bundled reading and owned cleanup together. The fixed comparison marker was the
only result leaving the reader child. The returned database and known native
sidecars were absent afterward; owned fixture directories were empty/removed,
the owned entry was absent from the current search list and the opaque default
Keychain handle remained unchanged. Ordinary controls observed zero destination
connections, unchanged synthetic configuration/provider bytes through mode
changes, byte-exact direct rollback, exact tracked-child exit and reusable ports.
Source-denial negative reads/imports passed, as did visible native-window and
synthetic-instance-lock attribution. These are fixture observations, not GUI
setup interactions.

Native harness development exposed macOS path-spelling disagreement and actual
atomic database inode replacement during the native add. An early filename-based
cleanup inference was corrected. The final harness captures the completed known
add's identity and requires it unchanged through subsequent checks/deletion,
bound to the same owned directory and native handle/path. Failed roots were
preserved and individually remediated with exact owned metadata/identity checks;
all observed failed fixtures are removed. No user item was read/updated/deleted,
no prior whole search list was restored and no default Keychain was changed.
Raw diagnostic and remediation evidence stays outside Git.

File-backed Security/ACL SDK deprecation diagnostics are an intentional reader
compatibility tradeoff. The fresh release build emitted seven such declarations;
each package harness compile emitted thirteen (production plus test-only native
lifecycle APIs). No other compiler warnings/errors occurred. Diagnostics remain
visible without global suppression.

## Native and live observations

All human native, keyboard and live observations in this section predate
`ee8bd85` and used the pre-fix signed artifact. No post-fix human UI/live repeat
is claimed. Focused regressions and actual disposable native/package checks
verify the final changes; they do not replace or relabel these observations.

The user observed the isolated synthetic catalog, setup-required/missing-default
state and disabled Start in an attributed native window. The first native Save
failed before a configuration, receipt, lease or Keychain item was created; the
owned helper independently confirmed unchanged metadata/database identity.
The real selected-missing bridge projected recovery required, while the native
first-setup authorization required no provider recovery. Tests using a synthetic
inspection had missed this disagreement.

The causal repair retains the native recovery guard and reports no provider
recovery only after a safe canonical private absent destination, compatible
settled HTTPS direct provider and no provider recovery records/backups/checkpoints
are established. Unsafe or unreadable evidence remains blocked. Native receipt
and lease checks retain separate authority, including revalidation with the
current operation's own prepared receipt. A new real Node-bridge/native-controller
regression completes first creation with fake Security, real configuration commit
and completed receipt; it also covers abandoned/unsafe receipt/lease and provider
recovery refusal before native creation. This is automated integration evidence.
The refreshed signed app subsequently completed the native observations recorded
below. Optional screenshot capture attempts failed; no screenshot evidence is
claimed.

| Capability | Current evidence |
| --- | --- |
| First configuration, metadata selection and distinct incoming/default choices | Observed in the isolated native fixture: first Save retained no default/incoming; explicit completion enabled Start |
| Concealed native entry, creation consent and actual packaged-app ACL identity | User observed concealed entry and disposable Keychain consent; exact app-created item passed the packaged fixed-reader comparison |
| Explicit first/default selection and add preserving current default/assignments | Explicit default observed; existing-item Add preserved it; duplicate-name and HTTP-prefix errors observed |
| Safe stop/save/next Start Off boundary | Isolated and actual Start Off observed. Actual direct recovery/confirmation and guarded Stop preceded alternate-default Save; the next owned Start loaded it Off. On/Off preserved full execution config and current provider bytes |
| Created-but-unlinked reconciliation and relaunch guidance | Controlled commit failure after actual item creation retained receipt/lease; Check outcome retained recovery, disabled Close and blocked Quit; relaunch retained evidence and blocked Start |
| Legacy and enabled import | Three inherited labels preserved; enabled import preserved explicit pair equal to chosen default and two unresolved targets; exact source checkpoints and original direct/provider preserved |
| Named default at a different destination, project override, inheritance and follow-up | Changed default observed with unchanged incoming/pairs/bindings. Fresh On override completed HTTP 200; fresh unmapped inheritance had a visible finished reply with initiating 499/CANCELLED. Detailed sample limits below |
| Missing/inaccessible selected item and upstream failure remain failures | Automated synthetic coverage; live unresolved STATE_UNAVAILABLE 503 and cancellation outcomes retained. No actual inaccessible-item or credit-failure observation is claimed |
| Exact direct restoration, manual restart/response confirmation | Completed final Restore direct, manual restart, fresh working direct reply, actual direct-response button, guarded Stop and normal Quit. Original active-provider definition and owned normal router settings restored; unrelated settings preserved |
| Native fixture cleanup | Owned disposable Keychain/root removed; default Keychain unchanged. Final recorded native/Node/logger processes absent and independent port check empty; context records settled and journal restored |
| Task 8 task review | Complete through `888ccd9`: specification compliant, quality Approved; intentional Security deprecations Minor |
| Sole final sequential specification/quality gate and local closeout | Specification PASS; quality APPROVED on `ee8bd85`; both findings addressed, no new findings. Documentation closeout complete; parent final archival/checks/reporting is the endpoint |

On 2026-11-14, a distinct current keyboard check used the same signed app opened
through LaunchServices while stopped/Direct, with original normal selection,
runtime optional absence, no pending action and an empty port. The user explicitly
reported that searching for a nonmatching public marker showed no matching
projects; Command-A/Delete restored the list; one Tab/Shift-Tab cycle kept focus
visible; and Command-Q quit normally. System keyboard settings remained unchanged,
and no save, Start or activation was performed. Parent independently verified
exact native exit, no remaining companion, empty port, original normal config and
activation bytes preserved, and final parsed journal equal to the original. This
is a narrow current search/keyboard/Quit observation, not a comprehensive focus
audit or a fix for the two accepted predecessor viewport/focus limitations; both
remain deferred.

The first interrupted native consent attempt did not create an item. Its private
prepared receipt and dead-owner lease were preserved before a controlled reset
of that disposable fixture. The successful later creation does not retroactively
complete the interrupted operation. The created-but-unlinked test used a distinct
operation with deliberate helper commit failure and actual native creation. Its
forced app relaunch is instrumentation, separate from ordinary successful Quit.

For live acceptance, the user authorized a separate private validation
configuration with one fixed test assignment. The earlier inspected normal
configurations contained legacy labels and no explicit endpoint/key overrides.
Through the native capture boundary, the original configuration and direct
provider remained unchanged; companion selection pointed to the private capture
copy. No real router Start, provider activation, new user Keychain item or
credential retrieval occurred in that capture. Native existing-item selection initially failed because
an unrestricted scan found the exact matching item, then encountered an
unsupported system-owned Keychain and rejected the entire result. A bounded
no-UI production query using the supported exact user Keychain path returned one
matching metadata item. No partial listing or automatic selection was introduced.
Native selection subsequently succeeded, and the user explicitly assigned that
item to incoming authentication and the original outgoing account separately,
chose Global as default and completed Import/Done. Private verification confirmed
the selected pair, original direct destination, mappings, legacy inheritance and
provider bytes were preserved.

The user later identified an earlier account-setup chat whose retained historical
source contained compatible credential-enabled routing (three targets across two
destinations). Parent verification established the intended distinct additional
pair and its exact existing-item metadata; the source supplied pair metadata
only, with no credential retrieval. The user then completed native existing-item
Add for that account, retained the original default, completed Done and ordinary
Quit. Private comparisons confirmed two saved accounts, the exact recovered pair,
preserved incoming/original account/direct/operational fields, mappings and
optional-property presence. Normal config/provider/activation remained unchanged;
no capture receipt, lease or activation remained, the exact native process exited
and the listener was empty. Unrelated new catalog changes were preserved. This
established the native two-account prerequisite. Metadata alone did not establish
secret access or gateway acceptance; the later bounded observations are recorded
separately below.

Parent then prepared and verified a separate private execution copy using explicit
account/project selectors. It preserves the capture and its original default,
accounts, incoming and existing mappings, adding one confirmed project's unique
alias and original-account override. Current catalog and journal bytes remained
unchanged during preparation. Inspection reported ready/Direct without recovery;
this preparation proves no actual gateway or live response outcome. The execution
context retains its own activation/recovery namespace and private checkpoints.

The separate actual execution then started successfully Off. The user observed
Off, Direct, Matching listener ready and Owned by app; parent attributed the exact
managed Node, native parent and listener PID. Bundled inspection confirmed ready
and Direct with the active-provider definition unchanged. This establishes owned
startup/readiness, not desktop-loaded settings or gateway acceptance.

During the subsequent live attempt, the user activated and quit Codex for the
required manual restart; the companion also disappeared, and reopened Codex had
no connection. The user manually opened the same tested bundle and chose Restore
direct. Parent verified the original native, managed Node and logger were gone,
the port was empty, the execution context's activation phase was restored and its
selected journal retained `direct_confirmation`. The original active-provider
definition, including URL and authentication, was restored exactly. Unrelated
`mcp_servers` edits were preserved, so the whole provider file is not byte-exact
with its earlier checkpoint.

The observer reached its 128 KiB retention cap and continued draining; retained
content contains health checks only. Later initiating requests and transport
outcomes are unobserved, not proved absent. No post-activation credential-access
claim is made. Old native output was empty and no recent native crash report or
fatal marker was found, but no exit status or terminating signal was established.
The original launch inherited Codex's foreground PTY; the manually reopened
instance has launchd parent PID 1 and no TTY. This supports a possible harness
lifetime explanation without proving the cause. No product fix is claimed.

The user then explicitly reported restarting Codex after Restore direct and
receiving a working reply; native direct-response confirmation cleared the
journal before further live work. The same tested companion, manually launched
independently of the original PTY, subsequently survived the required restarts.
This successful retry does not prove the original exit's cause.

The retry with the original outgoing default completed Start Off, activation,
manual Codex restart, a visible finished fresh reply and routed-response button
confirmation. A matched fresh request from the fixed test project recorded
Off/global with initiating `499/CANCELLED`. The routed button sets the in-memory
confirmed-routed state; durable `routed_confirmation` intentionally remains while
the desktop depends on the listener. An initial expectation of a nil journal was
corrected against the code, without a product change or defect claim. Restore
direct, manual restart, working direct reply and the direct-response button then
cleared the journal. Guarded Stop verified exact Node/logger exit and empty port.

The user explicitly saved the alternate default through native Save/Done only
after that settled boundary. The **only** parsed execution-config difference was
`accountRouting.defaultAccountId`; incoming, both complete account pairs,
original/direct destination, mappings, bindings and optional-property presence
were unchanged. The next explicit Start was Off, with a new owned listener and
matching fingerprint loading the alternate default. The changed revision
conservatively reopened direct-response confirmation under the existing recovery
authority. Activation, manual restart, a visible finished fresh Off
reply and routed-response confirmation then succeeded with the independent
companion. Runtime On/Off changes required no further Codex restart.

| Bounded live sample | Visible outcome and initiating transport |
| --- | --- |
| Original default, fresh fixed-project request, Off/global | Visible finished reply and routed confirmation; initiating `499/CANCELLED` |
| Alternate default, fresh fixed-project request, Off/global | Visible finished reply and routed confirmation; initiating `499/CANCELLED` |
| Alternate default, fresh fixed-project request, On/override | Original-account override selected; completed HTTP 200 |
| Alternate default, fresh other unmapped local project, On/inherited | Alternate default inherited; visible finished reply, initiating `499/CANCELLED` |
| Alternate-runtime ancillary identified Off/global model responses | Two completed HTTP 200 outcomes, separate from the fresh samples above |

Catalog HTTP 200, unresolved `STATE_UNAVAILABLE` HTTP 503 and cancellation
outcomes were also retained. The later private observer had a 2 MiB limit and did
not cap; only its retention limit changed, with synthetic tee/version/EOF cleanup
verified independently of product code. The same listener handled On and the
return to Off; **entire execution config and current provider TOML bytes stayed
unchanged** through those mode changes. Configuration/loaded-fingerprint and
symbolic selection evidence were compared privately; no actual values enter this
report. The visible finished replies do not turn initiating `499/CANCELLED`
outcomes into completed transport, and the ancillary HTTP 200 records do not
relabel the fresh samples. No billing attribution, general cross-account
continuation or complete delivery for a 499 sample is claimed.

Final recovery completed actual Restore direct, manual Codex restart, a fresh
working direct reply, the actual direct-response button and the user's direct
confirmation, then guarded Stop and ordinary native Quit. Parent independently
verified all recorded native/Node/logger processes absent and the listener port
empty; selected-context activation restored, no lease or receipt, and no pending
journal action. Normal router config and normal activation are byte-exact with
the originals. Native capture remains exact after its second Add, and execution
config remains exact since the alternate-default Save. The original active
provider definition, including URL/authentication, is restored exactly. Unrelated
`mcp_servers` changes and catalog/new-chat additions remain preserved, so the whole
provider TOML intentionally differs from its original checkpoint.

With native absent and its instance lock held, a compare-and-swap atomic journal
restore changed only owned selection/runtime/pending fields and their original
optional-property presence. The final parsed journal equals its original; no
provider or catalog write was used for that restoration. Raw final snapshots and
full outcomes remain parent-private outside Git. No further live operation is
needed for this evidence handoff. Task 8 task review, the sole final sequential
gate and documentation closeout are complete as recorded below. The normal
router configuration remains original and unmigrated; account setup remains in
the private test capture/execution contexts. Parent's independent post-fix
settled-state check confirmed journal/provider equality with the recovered
snapshots, app absence and an empty port. No live application of account setup
or further runtime action is implied.

Before that successful import, the native form presented an empty list with
identical privately compared filter values. Standalone probes compiled for both the app's deployment target
and release optimization return one match. Initial UI status instrumentation
passed 236 native tests and a fresh signed build, but its count reads back UI
state; it does not independently establish the raw returned-array count. The
later direct-result versus rendered-list observation reported one returned match and one list entry, with an actual item visible and selected in the native
dropdown. The earlier discrepancy's cause remains unproven: the diagnostic change,
additional rendering dependency and app relaunch were not isolated. Successful
selection/import is observed; no causal fix is claimed.

Actual endpoints, references, mappings, checkpoints and raw runtime evidence stay
outside Git. This report records only sanitized outcomes. Prior live
`499/CANCELLED` qualifications and the two accepted viewport/focus observations
remain in the historical validation record; this increment neither erases them
nor claims to have repeated those observations.


## Final review and local closeout

The sole sequential gate finished specification **PASS**, then quality
**APPROVED**, on implementation commit
`ee8bd85b91c0b982906700f8c3400266090a1032`. Its sanitized identity is:

- Gate run: `account-default-final-304cc353-3257-4f04-8577-b7a88de2eb01`.
- Reviewed state: `git-ee8bd85b91c0b982906700f8c3400266090a1032-fix-wave-4b1d07ff-d698-4fe1-a9c4-980a8a9ba07f`.
- Final fix-package SHA-256: `554d8130f5f9b564b36b331ae2f37a3ed939bc9a7edbf4b7ac03894a6055b9ac`.

Before substantive specification review, stale lifecycle text still described
Task 8 review as pending despite its actual approval through `888ccd9`.
Documentation reconciliation in `2c5099f` repaired that input inconsistency;
it was neither a product defect nor a second final gate. The same sole gate
then produced two findings, addressed in one combined fix wave. Its scoped
specification re-review passed before scoped quality approval; both reports
verified the unchanged package identity and exact-byte hash.

| Original finding | Final remedy and verification | Disposition |
| --- | --- | --- |
| Important: enabled schema-1 import could discard/replace the saved global incoming verifier | Preview and native form preserve the existing verifier; authoritative commit compares against freshly loaded source and rejects null/different references before checkpoint/write. Regressions verify a distinct outgoing default, each reference-component refusal, unchanged files and continued explicit incoming choice for legacy/fresh setup | ADDRESSED |
| Minor: native probe/reader lifecycle had a deadline and retained-cleanup gap | Probe is registered in retained lifecycle with a 20-second deadline and bounded TERM/KILL/group cleanup. POSIX-spawned reader inherits that owned group, has bounded wait/reaping, and permits scratch Keychain cleanup only after confirmed reaping; unverified cleanup retains evidence. Actual stalled-reader and unresponsive-probe fault cases passed | ADDRESSED |

Final quality reported **new findings: NONE**. Focused setup tests passed 27/27;
native presentation passed 14/14. Full fresh acceptance is the ordered
238-native/817-Node/three-package sequence above. Both Node and separate package
runs proved actual reader group inheritance, TERM-ignoring reader KILL/reaping,
outer probe deadline/escalation, absent child PIDs/groups and verified owned
scratch cleanup. Source-denial controls, managed Off/On controls, unchanged
synthetic bytes, activation/rollback and zero control-time upstream connections
also passed. These tests use disposable synthetic resources, not live-user
settings or a new human UI observation.

Intentional file-backed Security deprecations remain disclosed: seven release
warning sites and thirteen per native harness compile, with no other warnings;
the native test run had zero warning sites. No warning suppression or
warning-free release claim is made. Harness versus packaged-app ACL identity
remains distinct. The pre-fix picker and inherited-PTY exit causes remain
unproven; deferred viewport/focus observations and bounded cancellation limits
above are unchanged.

The approved specification/plan content, approval provenance and dates are
preserved; completed preflight/task checkboxes reflect the authoritative task
ledger and gates. Documentation is closed locally. Parent owns final archival,
Git/settled-state checks and the user report, then stops before another increment,
push or merge. No further live operation or implicit migration is authorized.


## Execution decisions

These are the ten execution-ledger rulings in their original order, retained here
so their decisions and costs survive removal of ignored execution scratch files.
They record implementation choices within the approved scope.

| # | Decision | Cost or tradeoff |
| --- | --- | --- |
| 1 | Use the existing checkout under explicit user authorization | No worktree isolation if unrelated edits appear; preserve and report them |
| 2 | Parent owns actual native/live observations; Task 8 worker consolidates evidence | Missing observations remain pending; worker reports cannot replace them |
| 3 | Early package checks may exercise the predecessor artifact; rebuild in Task 7 before acceptance | Stale artifacts or skips cannot count as current acceptance |
| 4 | Preflight found no mandated duplication or assertion-free tests; verify behavior | Per-task review remains required |
| 5 | Both serving entries hold the existing per-config `.activation.lock` through strict config load and listen, releasing only their exact safe owned inode | Closes the cooperating startup/save race; interrupted startup can leave stale evidence requiring manual resolution; no protocol/credential expansion |
| 6 | Add/set-default may explicitly fill a null schema-2 incoming verifier with a nonnull reference; an existing verifier cannot change or clear | Small additive DTO field completes otherwise incomplete setup; it provides no authentication rotation |
| 7 | Explicit caller/config-selected file-backed Keychain paths may be validated outside the search list; unscoped discovery/default use the current list/default without mutation | Allows exact-path access beyond discovery while retaining macOS consent/path validation and avoiding user search-list changes |
| 8 | Task 7 owns the narrow missing-selected-config browsing integration repair across inspection/CLI/ProcessBackend with focused tests | Additive browseHome input; valid selected codexHome remains authoritative and fallback applies only to true absence; no parallel implementer or scope expansion |
| 9 | Missing-config inspection separates proven settled provider recovery from separately guarded setup receipt/lease evidence, including exact own-operation prepared revalidation | An incorrect rule could admit unsafe first setup; abandoned/unsafe evidence and the real bridge/native boundary require tests |
| 10 | Retained-helper disarm may verify original identity/seed metadata read-only only after exact native exit and fresh no-prompt candidate absence; never adopt a new inode or retry/create an item | Failure preserves roots/lost-handle evidence; a wrong disarm risks loss of the retained helper/default comparison, not deletion or adoption |
