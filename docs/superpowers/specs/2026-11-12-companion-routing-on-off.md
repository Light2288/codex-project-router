# Companion routing On/Off — specification

**Slug:** `companion-routing-on-off`

**Type:** feature

**Status:** APPROVED

**Created:** 2026-11-12

**Updated:** 2026-11-13

**Approval:** The user explicitly approved this saved specification with **specification approved** in this chat. That approval authorizes Stage 3 implementation planning only; a separate plan approval is still required before implementation. The provenance and Stage 2 handoff below describe the original drafting state.

**Plan:** `docs/superpowers/plans/2026-11-12-companion-routing-on-off.md` — separately approved with **plan confirmed, subagent driven confirmed**; implementation and qualified verification complete. See `docs/validation/companion-routing-on-off.md`.

**Provenance:** The user's next-companion-increment handoff in this chat; read-only repository, operational and historical-evidence inspection; the native clarification answer **Use global now (Recommended)** for identified projects without overrides while On; and the subsequently presented Stage 1 scope/design proposal. The user explicitly approved that proposal with **scope/design confirmed**. This authorizes this DRAFT specification only. It does not approve this specification, authorize an implementation plan, or authorize implementation.

Sources include `README.md`, `companion/README.md`, all existing reports under `docs/validation/`, and the specifications and matching plans for `project-credential-routing`, `companion-operational-controls`, `companion-quit-alert` and `companion-quit-guidance`. Those completed artifacts remain unchanged historical inputs. Artifact resolution before writing was MISSING for this slug's specification and plan, with no legacy or conflicting candidates. The new specification is `docs/superpowers/specs/2026-11-12-companion-routing-on-off.md`; no matching implementation plan has been created.

## 1. Problem, desired outcome and delivery boundary

The wider direction is a convenient native companion with account setup, an explicit default account, project assignments, understandable operation and recovery. The immediate increment is **everyday project routing On/Off through the running router**, with basic inheritance from the existing global account.

The intended user workflow is:

1. Start the companion and explicitly start its router before opening Codex.
2. Open Codex using the stable local router connection, initially with project routing Off and the existing global account.
3. Turn project routing On during the session: configured project overrides use their paired destinations and credentials; identified projects without overrides use the existing global pair.
4. Turn project routing Off: subsequent admitted requests use the existing global pair, preserving all saved overrides.
5. Repeat everyday switches without restarting Codex or changing its provider URL.

Existing requests may finish under their original mode. A mode change need not wait for open chats, pending requests or streams to drain. An open chat alone is not active request work; automatic/background model requests and compaction are request work.

This increment includes the router mode, owned-child control integration, necessary identity/selection separation, basic inheritance, focused companion presentation, startup/recovery guidance, safeguards, tests, local packaging, controlled live validation, documentation and sequential specification/quality review. It does not add the later account or assignment editors.

The outcome resolves whether the existing router and companion can provide reliable request-boundary switching without desktop restarts, and whether the observed desktop/gateway combination supports the required live workflow. Cross-instance continuation remains an explicit uncertainty until tested. A gateway incompatibility must remain visible; it cannot be repaired by silent account fallback or an unapproved continuation-migration feature.

**Boundary rationale:** Off already needs project identification without requiring an override. Applying the same distinction to On provides basic global inheritance and makes newly created projects usable without absorbing account designation, Keychain writes or assignment authoring. Keeping the current global incoming/outgoing coupling avoids an unnecessary authentication migration in this increment.

**Execution endpoint:** Deliver the confirmed routing switch and basic inheritance; complete automated/native verification, controlled live validation, exact owned-setting recovery and sequential specification/quality review; commit locally on the authorized implementation branch; report working behavior, evidence and limitations; then stop before later increments. Push and merge remain unauthorized.

## 2. Current behavior and evidence

Read-only inspection found clean `main` at `323536305723e767a8fdd2ac99ea26ca808d2175`. Local `main`, `origin/main` and actual remote `main` matched, with only `main` remaining locally/remotely. The branch and clean checkout were rechecked before drafting. These observations are not a guarantee of later execution state.

The normal private router configuration was valid and in legacy credential-forwarding mode. Its provider was direct, its activation record restored, matching readiness false, and independent listener inspection found no listener. The companion journal had no pending recovery and its instance lock was not open. No credentials were retrieved or operational settings changed. These facts apply to the inspected normal/selected context, not every possible private configuration or a running desktop's loaded settings.

`src/cli.js` loads configuration once for `serve`. `src/proxy.js` authenticates, resolves identity and selects a request-local destination/credential before forwarding. It has no runtime project-routing switch. `src/identity.js` currently combines proven project membership with a required explicit route alias, rejecting identified projects without mappings. Desktop assignment state is read per request; configured mappings and targets remain startup state.

In credential-routing configurations, each admitted non-health request first reads `credentialRouting.globalCredential` and verifies the incoming bearer token. Mapped model requests then read the selected `routeTargets` credential and use its paired URL. Catalog and qualifying unassigned-title requests use the global destination and verified incoming authorization. Legacy configurations perform no Keychain reads and retain incoming authorization.

The companion launches and retains an actual child Process plus session-local identity. Its current long-lived launch closes stdin and drains/discards stdout/stderr; it has no ongoing command/acknowledgement channel. Readiness does not grant process ownership. Activation/rollback use the selected configuration's own records and narrowly edit the provider URL. Guarded Stop/Quit protect a listener Codex may still need. Closing Controls leaves the companion/router running.

The latest recorded acceptance is 128 native tests, 664 Node tests, three package tests with zero skips, a signed local build and passing sequential final reviews. These are historical recorded results, not fresh tests in this specification stage. Preserve the validation reports' historical failures and qualifications: previously qualified 499/CANCELLED streams do not establish complete protocol delivery; independent gateway billing attribution and cross-instance chat continuation remain unproven. Later companion GUI checks do not strengthen those transport/billing claims.

## 3. Approaches and selected design

The confirmed design uses a stable local router connection and a small acknowledged control channel to the router child already owned by the companion. The live mode is held in that child, with no general configuration reload.

Alternatives considered:

| Approach | Tradeoff and disposition |
| --- | --- |
| Owned-child process channel and in-memory mode | Selected in the confirmed proposal. Fits existing child ownership and allows acknowledged switching without a network mutation endpoint or persistent mode file. Requires bounded ongoing process I/O and reconciliation. |
| Private per-configuration mode file | A plausible narrow alternative, but adds persistence, file-read/write failure and restart-policy behavior that this outcome does not need. Not selected. |
| Repeated provider-URL edits or general configuration reload | Repeated URL edits do not meet the restart-free everyday workflow; a general reload system broadens the change unnecessarily. Neither is the selected solution. |

The confirmed request policy lets existing work finish under its captured mode instead of waiting for all work to drain. The native inheritance choice brings forward only use of the existing global pair for identified projects without overrides. The proposal's explicit Off-at-start default and focused UI reorganization were confirmed with the rest of Stage 1.

Author design calls within that boundary: introduce companion-managed serving as an opt-in capability; preserve historical non-managed `serve` behavior and existing public command/status contracts; keep runtime mode separate from configuration identity; and keep exact protocol encoding, module layout and presentation layout for the separate implementation plan. These calls must satisfy the observable contracts below and do not authorize a new configuration framework.

## 4. Request policy and inheritance

For companion-managed serving, use the following selection rules after normal request admission and required incoming authentication:

| Request | Project routing Off | Project routing On |
| --- | --- | --- |
| Model request with proven project membership and a saved override | Global pair; saved override is inactive | Override's complete destination/credential pair |
| Model request with proven project membership and no saved override | Global pair | Global pair, inherited |
| Model request whose explicit alias lacks a target | Global pair; override deliberately suspended | Existing missing-target failure; no inheritance |
| Invalid, conflicting, unsupported, projectless or unresolved model identity | Existing failure behavior | Existing failure behavior |
| Catalog or qualifying unassigned title under its existing policy | Existing global behavior | Existing global behavior |
| Local health/readiness | No upstream or credential lookup | No upstream or credential lookup |

Here **global pair** means top-level `upstreamBaseUrl` and the existing incoming authorization; when `credentialRouting` is present, that authorization must first match a fresh `globalCredential` read. Do not select a different outgoing default or invoke the desktop authentication helper. Only an explicit project override in enabled credential routing causes project-credential substitution.

In managed legacy configurations, admitted requests still use the caller's credential and global destination with zero Keychain calls. There are no project account credentials to substitute; the UI must say so rather than portray route aliases as distinct account names. Existing saved aliases remain intact. Historical non-managed serving retains its current admission/mapping behavior; basic inheritance is part of this managed capability.

Separate successful project membership resolution from the policy decision that requires or selects a route. Membership still requires readable supported saved state and consistent identity/ancestry. A default is never inferred from missing identity, a folder, activity, timing or prompt contents. Relevant conflicting catalog/assignment identity must not become eligible merely because inheritance is available. Retain existing bounded lookup, cancellation and title-absence safeguards; strengthen relevant identity consistency only where needed to enforce these rules.

Use own-property distinction between no override and an explicit alias whose target is missing. Never treat a target lookup, credential failure, upstream rejection, exhausted credit balance or connection failure as absence of an override. Strict loading still rejects supplied malformed/incomplete targets in either mode. Existing explicit assignments, normalized endpoint prefixes and credential/endpoint pairing remain unchanged; the obsolete `routeCredentials` format remains rejected.

Off is an explicit request to suspend project overrides. It therefore performs no project-credential lookup, including for a saved override whose item is currently unavailable. In credential-routing mode, global authentication failure still blocks requests in both modes. Neither a failure nor credits exhaustion changes the runtime mode or triggers another credential/destination, model retry or redirect following.

### Request boundaries

Capture On/Off once at receipt of each HTTP request, before its first asynchronous lookup. A switch acknowledged later cannot change that request's captured mode, including during global authentication, identity retry or project-key retrieval. Normal project identity is still resolved from fresh supported state; mode capture does not promise an atomic snapshot of desktop state at receipt. Once a destination/credential is selected, retain the pair for the request and stream.

Apply the same rule to Responses, dedicated compaction and automatic/background requests admitted by current policies. After the switch acknowledgement, newly received requests use the acknowledged mode. Reusing an HTTP connection does not reuse the previous request's mode. An existing request keeps its own selection across any number of later switches.

Preserve request/response bytes, models, continuation identifiers, permitted headers, path prefixes and queries, streaming/backpressure, cancellation, inactivity limits, TLS verification and upstream outcomes. Do not retry or migrate an existing request to make a switch appear successful. A cross-account/instance continuation rejection remains an observed gateway failure.

## 5. Owned control, acknowledgements and truthful state

The companion may control mode only through a supported channel bound to its exact currently live owned child and configuration context. No recovered PID, port occupant, health response or previous app instance's child grants control authority. Introduce no HTTP mutation endpoint and pass no credentials through the control channel.

Companion-managed startup establishes Off before accepting requests. The explicit Start action/guidance must make this default clear. No last-used On setting is restored, no router starts automatically, and a failed/uncertain start cannot be presented as a confirmed Off listener. The historical standalone `serve` path remains usable with its existing behavior.

Mode commands set an absolute requested mode, rather than toggling whatever state happens to exist. Serialize incompatible actions, correlate each result with the command and owned child, and acknowledge only after that child applies the change. Stale replies, queued refreshes and child replacement cannot replace newer evidence or authorize another context. Configuration/listener readiness, acknowledged runtime mode and user-reported desktop connectivity remain separate facts.

Bound and validate ongoing control input/output, retain bounded buffers, drain diagnostics continuously and use fixed sanitized errors. Mode inspection, switching, startup and readiness perform no Keychain reads, authentication-helper execution or destination preflight. Readiness continues to establish configuration/listener agreement, not gateway success; mode/capability acknowledgement is additional owned-channel evidence. A managed mode change alone must not alter the configuration fingerprint, provider URL, activation record or restart/response-confirmation obligation.

A deadline, malformed/lost acknowledgement or channel failure may leave the outcome uncertain. Do not optimistically publish the requested mode, assume the old mode remained, silently choose Off, retry a mutation automatically or stop a possibly required listener. Show uncertainty and reconcile by obtaining fresh mode evidence from that same supported owned child before enabling another mode mutation. If reconciliation is unavailable, preserve recovery access and the existing listener protections.

Child exit makes mode unavailable; it does not start a replacement or change billing through another route. Loss of the companion/control channel must not itself reset a surviving router to Off or another account. Router/companion crash survival and supervision are not promised. A surviving router from an earlier app instance remains unowned and requires the established recovery/manual-cleanup procedure.

## 6. Companion presentation and project discovery

Keep the existing native menu-bar app and one controls window. Lead with project-routing state and an explicit main On/Off action, the existing global account designation, and the project list. Distinguish On, Off, not running, and unavailable/uncertain status. During a switch, make the pending operation clear and prevent conflicting re-entry. Do not label an unacknowledged state as confirmed On/Off or claim Codex uses the router from mode evidence alone.

The global designation is descriptive, such as the existing global provider account; there is no account picker or newly invented account display name. Project rows distinguish an active saved override, inheritance from global, and a saved override suspended while Off. Keep missing targets and stale/unresolved catalog entries visibly distinct; Off must not erase saved assignments or hide problems that will matter when On returns. Existing aliases may be displayed as aliases, not asserted to be account names.

Retain automatic catalog refresh and manual Refresh/search. A new project can appear without restarting either app. Request routing must work independently of catalog browsing, the current search, UI visibility or whether a row has been discovered. Unreadable catalog state remains visible and cannot be presented as a fresh cached list. No project or assignment is created/edited by discovery.

Move selected configuration/runtime paths, process ownership and technical diagnostics into secondary Settings/Advanced presentation as appropriate. Keep necessary setup/start actions and current errors/recovery visible when relevant. This is a focused reorganization for the delivered workflow, not comprehensive UI simplification.

Preserve the existing separate provider-on-disk, matching readiness, ownership and desktop-confirmation facts. Existing Quit guidance must still reveal/expand the appropriate current controls after reorganization, including closed/minimized windows, without invoking a recovery/confirmation action. Keep cancellation, transient guidance, focus and reentrant-Quit behavior. No duplicate recovery wizard or new Quit permission is introduced.

## 7. Integration, startup and recovery

The provider's loopback URL remains stable through everyday mode changes. On/Off never invokes activation/rollback or edits Codex/router configuration. Acknowledging a switch neither records a working response nor clears pending initial integration/recovery evidence.

The user explicitly starts the companion/router before Codex. Initial integration uses the existing activation helper and narrow provider-URL edit, with manual Codex restart and working-response confirmation when the URL change requires it. If the provider already points to the correct router, starting the required listener does not itself create another provider-change restart requirement. Existing conservative unknown/loaded-state presentation remains truthful. Launch, selection, refresh and discovery do not start or activate automatically.

Off is not direct bypass or safe-stop evidence. A desktop using the stable local URL still requires the listener in either mode. Keep the existing guarded Stop/Quit rules, including their direct-only start exception, verified idle-direct exit, durable pending-journal checks and uncertain-helper restrictions. No detached-listener exit, adoption, automatic restart or weaker shutdown rule is added.

Restore direct remains a separate recovery/disconnection action. Use the configuration and activation records belonging to that activation, even outside the normal directory. Preserve unrelated Codex settings, authentication and models, locking, context binding, backup checks and compare-before-replace. Restore may work without a live router, gateway or Keychain when runtime and recovery evidence are valid. Guide the required manual restart and working-direct-response confirmation before stopping an owned listener after possible desktop dependency.

Interrupted operations, incompatible/older listeners, changed contexts and unreadable recovery remain visible. Never force a URL overwrite, automatically delete locks/evidence, adopt or signal an external listener, or equate loss of matching readiness with an empty port. Use the existing offline/manual recovery guidance when control reconciliation is unavailable.

## 8. Privacy, verification and live acceptance

Actual credentials, references, endpoints, mappings, checkpoints and runtime evidence stay outside Git. No credential retrieval or operational mutation is needed to write or approve this specification. UI/control inspection never fetches secret values. Actual admitted requests retain the existing bounded Keychain reader where required; no new secret backend or credential cache is introduced.

Keep raw process output, exceptions, private configuration/state, prompts and responses out of new diagnostics. Existing permitted identifiers/aliases retain their established private allowlist. If mode/selection evidence is added, use fixed On/Off and global/override classifications captured for that request; do not imply a saved-but-suspended alias selected its project credential. Do not add credential values, hashes/prefixes, Keychain references or actual destination URLs. Only symbolic sanitized runtime results belong in committed reports.

Required automated verification includes:

- Selection in both managed modes and both existing credential configurations: mapped override, inherited project, missing target, shared references, catalog/title behavior and the existing optional-policy combinations. Preserve non-managed CLI behavior and legacy zero-Keychain behavior.
- Deterministic barriers for mode switches during global authentication, identity lookup/retry, project-key retrieval and active streams; repeated On/Off, concurrent requests, persistent HTTP connections, cancellation, compaction and background/title work. Assert the exact per-request origin/authorization/body and zero fallback/retry through a different origin.
- New-project inheritance before companion browsing and with Controls closed; discovery/Refresh/search without mapping writes; malformed/conflicting/unreadable/projectless identity denial. Explicit missing/unavailable targets and synthetic exhausted-credit/upstream rejection must never become inheritance.
- Native process/controller cases for acknowledged switching, stale/wrong-child replies, bounded malformed/flooded I/O, timeout/reconciliation, channel loss, child exit/replacement, overlapping actions and external listeners. Verify no mode-only provider/journal/configuration mutation, no control-time credentials/preflight and preserved recovery/Quit protections.
- Focused native presentation/guidance checks, the existing Node/native suites, syntax/whitespace checks, a fresh signed build and all package tests with zero skips against the current app. Use the documented `npm test`, `npm run companion:test`, `npm run companion:build`, `npm run companion:package-test`, `node --check src/cli.js` and `git diff --check` commands. Check the relocated bundle and existing source-denial/privacy boundaries. Test native primary presentation and necessary Settings/recovery navigation without claiming GUI observation from unit tests alone.

Tests use synthetic credentials, temporary private state, controlled process boundaries and local HTTPS destinations. Do not retrieve real credentials, alter real keys/credits or contact external gateways from automated suites.

After separate specification and plan approval and implementation, conduct a controlled user-assisted live check with an existing compatible credential-routing configuration and disposable projects/chats. Privately checkpoint exact prior owned settings and optional-property presence, positively track the companion-owned listener, and keep controller access/recovery available. Reuse existing provisioned items; no native Keychain provisioning or assignment editing is required. The user performs desktop restarts, project/chat creation and prompts.

Required live outcomes are initial global operation while Off; a switch to On and successful use of a configured override; return to global while Off; at least one same-chat continuation across the mode sequence; and a newly created identified project using global without an override while On and Controls closed, followed by visible automatic/manual discovery. Perform the mode sequence without restarting Codex, replacing the listener or editing its provider URL. Capture local symbolic mode/selection/transport evidence and explicit user-visible success/failure reports separately. Long responses, a broad project matrix, credit exhaustion, key rotation and billing/load tests are unnecessary; in-flight timing and exact credential selection are required synthetic evidence rather than an expanded live stress test.

Same-chat continuation across different accounts/instances is a capability under test, not a pre-established guarantee. Preserve any gateway rejection without payload/model/continuation repair, fallback or automatic retry. If an incompatibility prevents the required workflow, record that capability as failed/incomplete, complete recovery, and return to scope/design before proposing material changes. Fresh-chat success cannot substitute for the required same-chat observation.

Finish live work, including a failed run, by restoring exact prior owned router/provider settings and optional-property presence while preserving unrelated concurrent edits. Use the correct activation context; obtain the user's required manual restart and working-direct-response confirmation before stopping the positively tracked owned listener. Independently inspect final direct/recovery state and listener absence. Whole-file equality is claimed only when actually true; preserved unrelated edits must remain separately qualified.

Create a new sanitized validation report during implementation rather than rewrite historical reports. Record actual commands/exits, selected-mode evidence, user observations, transport outcomes, failures, unrun cases, recovery and review dispositions. Passing local tests and visible responses do not independently establish gateway billing attribution, loaded desktop settings or complete protocol delivery. Complete the sole final sequential specification review followed by quality review under the selected implementation workflow. Missing required evidence stays incomplete.

## 9. Acceptance criteria

| ID | Verifiable outcome |
| --- | --- |
| **AC-01** | An explicitly started companion-managed router accepts requests initially in Off. Initial integration retains the existing URL-only activation/restart workflow; acknowledged everyday On/Off switches use the same listener/provider URL without Codex restart, config edits or activation/rollback. Historical non-managed serving/command contracts remain usable. |
| **AC-02** | Off uses the existing global pair; On uses an explicit override's paired endpoint/credential or inherits global only after successful project identification with no override. Legacy credential behavior and zero-Keychain guarantees remain; enabled incoming verification stays coupled to `globalCredential`. |
| **AC-03** | Identified newly created projects inherit global while On before UI discovery and while Controls is closed. Automatic discovery and manual Refresh reveal them without restarting either app or writing assignments. Unreadable/conflicting identity and unavailable catalog state remain truthful failures; no unresolved-request fallback is added. |
| **AC-04** | The mode is captured before the request's first asynchronous lookup. Pending authentication/identity/key work and active streams retain that mode and their eventual selected pair across repeated switches; requests received after acknowledgement use the new mode, including on reused connections and for compaction/background traffic. Cancellation and transport behavior remain intact. |
| **AC-05** | Explicit missing targets, unavailable credentials, exhausted-credit/upstream errors and connection failures never cause inheritance, mode changes, alternate-account billing, model retries or redirects. Off deliberately suspends overrides without project-key reads; enabled global authentication still applies. Strict target loading and endpoint/key pairing are preserved. |
| **AC-06** | Only the exact live owned managed child accepts correlated mode commands. Mode is published only from valid current acknowledgements; stale/malformed/lost replies and deadlines produce visible uncertainty and same-child reconciliation without automatic mutation retry/fallback or unsafe listener shutdown. External/older listeners cannot be adopted from readiness/PID. |
| **AC-07** | Native presentation leads with truthful routing state/action, existing global designation and understandable active/inherited/inactive project assignments. Technical detail is secondary while required setup, errors/recovery and existing targeted Quit guidance remain reachable. Aliases do not become invented account names. |
| **AC-08** | Off does not permit stopping a required listener or clearing integration/recovery obligations. Existing context-bound restoration, manual restart/response confirmation, idle-direct Quit, owned Stop, persistence, uncertainty and external-listener safeguards pass regression checks after mode/UI integration. |
| **AC-09** | Control/startup/readiness actions make zero credential/auth-helper/destination-preflight calls; bounded ongoing I/O cannot leak private output or block undrained diagnostics. New mode evidence remains fixed/sanitized, and packaging contains no private configuration/evidence. |
| **AC-10** | Required selection/concurrency/failure/identity/process/presentation regressions, Node/native suites, syntax/whitespace checks, fresh signed build, three package tests with zero skips and appropriate native UI observations pass. Necessary usage/startup/recovery/deferred-work documentation is delivered. Recorded old results are never substituted for fresh acceptance. |
| **AC-11** | The user-assisted live check records Off → On → Off on the same listener without a Codex restart, a working configured override, same-chat continuation, new-project inheritance/discovery, and exact owned-setting recovery with user-confirmed direct operation and independently stopped listener. Failures and unrun evidence remain accurately classified, with historical stream/billing/continuation qualifications preserved. |
| **AC-12** | Sequential final specification then quality review is completed with actionable dispositions and a truthful result/evidence/limitations report. Work remains local on the approved implementation branch, and execution stops before subsequent increments, push or merge. |

## 10. Constraints, deferred work and approval handoff

Use the existing checkout; no worktree. Keep this DRAFT uncommitted. Do not update `main`, create an implementation branch, change product/operational files, push or merge in Stage 2. Specification approval authorizes only Stage 3, using `personal-workflows:spec-plan` to produce a separate plan with this exact basename and shared slug. That plan requires its own explicit approval before implementation. Only afterward may execution safely update `main`, create the conventional implementation branch, commit the approved artifact pair and implement the plan under `personal-workflows:spec-implement`.

Deferred work remains account setup/registry/names/editing, selecting a different default, incoming/outgoing authentication migration, native Keychain writes, configuration/assignment editing or general reload, project hiding/reveal, comprehensive UI redesign, login startup, supervision/adoption, detached-listener Quit, automatic Codex restart/prompts, bundled Node, distribution/notarization, other platforms, independent billing proof and continuation migration/translation. Later increments remain provisional and require their own approval stages.

No material product clarification remains unresolved before this DRAFT. The native inheritance answer resolved policy; Stage 1 confirmation approved the presented scope/design, not this unseen artifact. Exact control encoding, bounded protocol constants, module interfaces, test organization and focused layout are for the separate implementation plan within these contracts.

**Builder completeness check:** A fresh read-only reviewer returned **nothing important left**. This checks whether the specification can support planning; it is not specification approval or final implementation review. No additional product decision or scope change was requested.

**Current stage:** Stage 4 complete — implemented after separate scope/design,
specification and plan approvals using the authorized subagent-driven method.
Automated/native acceptance, the qualified live sequence, exact direct recovery,
independent task reviews and the sole final sequential specification/quality gate
are complete. Two Minor UI limitations and the live 499/CANCELLED qualification
remain explicit in `docs/validation/companion-routing-on-off.md`. Work is committed
locally on `feat/companion-routing-on-off`; stop before later increments, push or
merge.
