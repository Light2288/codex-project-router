# Project list organization and compact presentation — specification

**Slug:** `project-list-organization-and-compact-presentation`  
**Type:** feature  
**Status:** APPROVED  
**Created:** 2026-11-19  
**Updated:** 2026-11-19  
**Provenance:** The increment-4 continuation request, repository and local-metadata inspection, the user-operated lifecycle experiment, native clarification answers, and the subsequent `confirmed` message approving the revised scope/design. Existing assignment-editing and projectless-compatibility specifications remain governing preservation requirements: `docs/superpowers/specs/2026-11-16-companion-project-assignment-editing.md` and `docs/superpowers/specs/2026-11-18-projectless-chat-compatibility.md`.

**Current stage:** Stage 4 — specification and separate implementation plan approved; execution authorized.  
**Storage:** Saved in the existing checkout after leaving Plan mode. Requirements below are unchanged from the complete DRAFT presented in chat.  
**Approval evidence:** The complete Stage 2 DRAFT was presented in the preceding assistant response. The user's subsequent **“Please implement the plan.”** approves that pending specification under the supplied separate-gate rules. At that time no implementation plan had been presented, so this authorized planning only. The separate Stage 3 plan was later presented and explicitly approved with **“approve”**; the user then selected **“Subagent-driven (recommended): independent implementation and review per task; higher context cost.”** Stage 4 execution is authorized for the saved pair.

Artifact resolution before saving found no existing specification or plan with this slug and no conflicting candidate. This specification is now saved at `docs/superpowers/specs/2026-11-19-project-list-organization-and-compact-presentation.md`. The approved implementation plan uses this specification’s exact basename. Both artifacts were committed on `feat/project-list-organization` after separate plan approval. Execution evidence is recorded in `docs/validation/project-list-organization.md`. The initial specification-review correction for flat-row routing-mode preservation passed its targeted follow-up. The initial quality review then identified three bounded display gaps: flat missing-target warnings, running missing-target warnings/previews and missing-binding policy placement. Their correction preserves established explicit-policy semantics and distinct warning identities and has a fresh ordered verification chain (379 native tests, signed build, 1095 Node tests and 3 package tests; zero failures/skips). Integrated correction review/follow-up and local closeout remain pending. Approved requirements below are unchanged.

## 1. Problem, current behavior, and desired outcome

The wider roadmap covers routing-mode switching, account/default setup, assignment editing, project-list organization, broader UI simplification, and startup/distribution. Only the project-list increment is authorized here.

Discovery found a clean `main` at `b735f37`, matching local `origin/main`, with the projectless-compatibility merge included. Historical branch references in earlier artifacts do not describe the current checkout.

The catalog currently discovers local projects, retains configured projects absent from discovery, and distinguishes saved assignment kinds. The companion presents a flat list with repetitive saved/running information. It has no chat-activity grouping, and project-specific runtime confirmation currently centers on the selected assignment editor.

Deliver one coherent improvement comprising:

- Saved-account grouping and compact project rows.
- Conservative classification of projects with no unarchived chats.
- Existing assignment editing and on-demand technical details.
- Immediate visibility of actionable problems and meaningful saved-versus-running differences.
- Search, counts, stable refresh behavior, tests, documentation, and required review.

Presentation and chat classification must not change assignments, credentials, or request routing.

### Observed evidence and accepted limitation

A disposable experiment established the following using stable chat/project identities:

| User action | Observed saved evidence |
|---|---|
| Create a chat in project A | Direct membership in A; SQLite `archived = 0` |
| Archive | Membership retained; `archived = 1` |
| Unarchive | Same identity and membership; `archived = 0` |
| Move the unarchived chat to B | Membership changed from A to B |
| Permanently delete without archiving first | SQLite record and transcript files removed; global membership and membership-host entries still referenced B |

Both projects remained discoverable. Independent fresh Node and Python reads confirmed the deletion leftover. SQLite’s integrity check passed.

The user explicitly accepted this exception: **a missing referenced chat record leaves the project visible with unknown chat status**, including after deletion. Such a project need not enter **No active chats** while that uncertainty remains.

The experiment observed settled endpoints, not every intermediate write. Classification describes supported observations and converges after metadata settles and a successful refresh completes. It does not promise an atomic transaction across JSON and SQLite or instantaneous transition behavior.

## 2. Classification and supported evidence

Account policy and chat state are independent observations. Use stable identities throughout. Names, paths, timestamps, foreground activity, and elapsed inactivity never establish membership.

### Saved account policy

| Saved evidence | Classification |
|---|---|
| Known explicit account selection | Custom account |
| Explicit selection of today’s default account | Custom account; retains that account if the default changes |
| Inherited or legacy-inherited assignment | Default account |
| Missing binding or otherwise unclassifiable policy | Needs attention |
| Established explicit policy with an unavailable target | Custom account with a warning; Needs attention if the policy itself cannot be established |

An unresolved/configured-only project retains its independently known saved policy and discovery warning. Its chat state is unknown. Missing or invalid account data must not manufacture default inheritance.

Preserve existing browsing/setup behavior where named-account classification is unavailable, including schema-1 and absent configuration. Legacy route aliases must not appear as named accounts.

### Section placement

Apply this precedence:

1. Unclassifiable account policy → **Needs attention**.
2. Reliably established no-active-chat state → **No active chats**.
3. Remaining known policies → **Custom account** or **Default account**.

Consequently, the two account sections contain projects with unarchived chats and projects whose chat state is unknown.

Section order is **Needs attention**, **Custom account**, **Default account**, **No active chats**. Omit empty sections. Each project has exactly one full row. Sort within each section alphabetically using case-insensitive localized names and stable project-ID tie-breaking.

### Chat states

Expose three semantic states:

- At least one unarchived project chat.
- No active chats.
- Unknown, with a bounded explanation.

“Active” means **unarchived**. It does not mean running, recent, or awaiting a response.

A supported, unambiguous unarchived membership establishes the positive state. Mixed archived/unarchived chats therefore remain in an account section.

A negative classification requires complete supported evidence establishing either:

- No eligible project-chat memberships; or
- Every eligible membership resolves to an archived record.

Missing records, conflicting identities, unsupported representations, or unavailable required metadata prevent a negative classification. Unknown projects remain accessible in their known account section.

### Sanitized evidence and initial compatibility boundary

The initial observer supports the local representation inspected during discovery. Its negative-classification boundary is deliberately conservative:

| Source | Observed shape and required handling |
|---|---|
| `local-projects` | Object keyed by project UUID, with matching record `id`. Observed records contain `name`, `rootPaths`, `createdAt`, and `updatedAt`; no project archive field exists. |
| `thread-project-assignments` | Object keyed by chat UUID, with `{projectKind: "local", projectId: <project UUID>}`. This supplies direct legacy membership. |
| Membership host and projectless state | `thread-project-membership-host-ids` identifies the experiment’s chats as `local`; `projectless-thread-ids` is a UUID array. Contradictory or unavailable relevant identity evidence yields unknown. |
| Migration checkpoint | Observed owner key: `electron-owner-value:app-server-projects-migration-by-host:signed-out`, under `local:<codexHome>`. Observed values: `version: 1`, `projectsMigrated: true`, `threadAssignmentsMigrated: false`, and a pending UUID array; `threadAssignmentsReadMigrated` was absent. Negative classification requires this supported profile. Missing, conflicting, migrated, or unsupported checkpoints disable negative classification for their affected scope. |
| Stable identity bridge | `app-server-project-id-by-legacy-project-id-by-host`, under `local:<codexHome>`, maps legacy project UUIDs to app-server UUIDs. Observed pairs were one-to-one. Use this only to identify conflicting or unsupported canonical evidence. |
| SQLite chat records | Required evidence includes `threads.id`, `archived`, `source`, `thread_source`, `project_id`, and `attached_thread_parent_id`, plus saved spawn-parent edges. Archive values must be exactly 0 or 1. |
| Supported ordinary records | Observed assigned root kinds were `source = "vscode"` with `thread_source = "user"` or `"agent_created_thread"`, no attached parent, and no incoming spawn edge. These define the initial eligible record kinds. Referenced older or other source kinds remain unknown unless already positively identified as internal records. |
| Internal records | Observed subagent/guardian source structures and corresponding role/parent evidence identify internal records. Consistent internal evidence excludes them as independent project chats. Contradictory source/role/parent evidence yields unknown. |
| Index health | The observed `backfill_state.status` was `complete`. This is a required healthy-profile check for negative classification, never sufficient by itself or a current completeness guarantee. |
| Newer membership storage | Project tables and identity bridges exist, but observed chat `project_id` values were null. Non-null canonical membership is unsupported by the initial observer and must be localized as unknown, rather than ignored. |

No source depends on `has_user_event`: every initially inspected thread had value 0, including legitimate chats.

Do not count descendants by propagating the request resolver’s ancestor membership. Completed spawn edges remain parent evidence. Do not scan or read transcript contents at runtime; their disappearance was discovery corroboration only.

Validate normalized identities and reject duplicates or contradictions. If malformed or unsupported evidence cannot be localized safely, suppress negative classification for that refresh as a whole. Implementing a second membership backend is deferred.

### Observation and integration

Use read-only, WAL-aware SQLite access and a coherent database transaction. Compare relevant membership, archive, and role evidence around the observation. Retry detected changes within a bounded refresh budget, then return unknown. Unrelated token/status updates must not churn grouping.

Reevaluate on refresh without a persistent activity cache or visibility database. This observer must never repair, delete, or migrate Codex records.

Activity failures degrade activity only. Independently healthy catalog and assignment evidence remain usable. Existing catalog identity failures retain their current unavailable behavior.

Keep activity/presentation changes separate from catalog identity/name revisions. Archive and chat-move changes must not unnecessarily invalidate assignment-editor authority.

Inspection gains semantic chat state/reason and sufficient list-wide runtime evidence for the presentation below. Exact wire encoding belongs to planning; validation must remain strict. Unsupported observation capabilities degrade to unknown without weakening mutation checks.

## 3. Presentation and interaction

### Compact rows and sections

Use one basic row design:

- Project name.
- Selected account for custom policy, or **Uses default** for inheritance.
- Edit action.
- Details disclosure.

Under **Custom account**, use:

> Accounts selected for individual projects.

Identify the saved default once under **Default account**. Do not repeat its name in every healthy inherited row.

Keep legacy-label provenance, project IDs, route aliases, matching saved/running details, and technical classification reasons in disclosure. Unknown chat state receives a concise visible indication.

Long names must wrap without obscuring actions. Preserve usable scrolling, keyboard interaction, and accessible labels.

Use the inactive title **No active chats (N)** and explanation:

> Projects with no chats or only archived chats.

Collapse this section initially within the controls window. Retain account information, editing, and details in its rows, without nested account subgroups.

When collapsed, show every actionable problem as a preview containing the affected project name, concise issue, and Edit access. Expanded full rows replace these previews. Previews do not increase counts.

### Saved and running information

Immediately surface:

- Meaningful saved-versus-running assignment differences.
- Missing targets and unresolved project discovery.
- Pending, uncertain, or divergent assignment operations.
- Relevant failures to confirm running state.

Compare assignment policy and stable account identity, including the applicable default. An explicit-versus-inherited discrepancy matters even when both currently select the same account. Routing Off does not erase a saved/running discrepancy merely because overrides are suspended.

A route-label difference alone need not become an account warning. Existing source-identity, setup, and recovery safety warnings remain visible independently.

Present a running assignment as matching only with coherent evidence from the exact owned supported runtime. Saved configuration, On, listener health alone, or the last edited project is insufficient. A shared default discrepancy may appear once at section level if affected inherited rows are clearly covered.

Do not label unavailable evidence as a confirmed difference. Normal stopped state and Off suspension may be explained globally or at section level, keeping healthy rows compact. Account labels do not prove credential accessibility or upstream success.

### Search and counts

Search is trimmed and case-insensitive across every section, including collapsed projects. Match:

- Project display name and stable project ID.
- Route alias.
- Applicable saved account display name, including the default for inherited rows.

During search:

- Display matching rows and matching problem previews.
- Omit sections with no matches.
- Temporarily reveal matching inactive rows.
- Show counts as **matches of total**, such as **2 of 8**.

Without a query, counts represent total section entries. Preview rows never add entries. Clearing search restores the previous collapse state.

Keep an overall attention summary available when search filters out actionable problems, with a way to clear search and reveal them.

Distinguish an empty catalog, no search results, and unavailable discovery.

### Refresh, disclosure, and editing

Preserve the query and disclosure state by stable project ID across refreshes and section moves.

While an assignment editor is open, pin that project’s displayed section and position through refresh and saving. Continue updating warnings and applying existing stale-baseline checks. Save leaves the editor open.

On dismissal, apply the latest observed placement once. Counts reflect the displayed placement until dismissal.

Pinning applies to entries that remain in a healthy current catalog. If discovery fails or the identity disappears, preserve the editor with appropriate unavailable/stale status and existing write blocks; do not manufacture a fresh catalog row.

Never auto-dismiss, overwrite the draft, silently rebase it, retry a save, or suspend safety reconciliation to preserve layout. Retain the existing visible/hidden polling cadence and manual Refresh behavior.

## 4. Acceptance criteria and verification

| ID | Acceptance criterion |
|---|---|
| **AC-01** | Explicit, inherited, legacy-inherited, missing-binding, and configured-only cases follow the policy and placement rules without invented inheritance. |
| **AC-02** | Selecting today’s default by name remains custom after a default change. On/Off alone changes neither saved-policy groups nor assignments. |
| **AC-03** | Supported empty, archived-only, mixed, and unarchived fixtures classify correctly without an inactivity threshold. |
| **AC-04** | Missing records, unavailable/locked/corrupt stores, malformed identities, unsupported schemas/sources, and inconsistent membership prevent unsafe negative classification. Activity-only failure preserves healthy browsing. |
| **AC-05** | Archive/unarchive and unarchived-chat moves converge after settled metadata and a successful refresh. Deletion leftovers remain visible as unknown until complete evidence permits reclassification. |
| **AC-06** | Internal subagents, guardians, and attached children do not independently keep a project active through ancestor membership. Eligible records do not depend on `has_user_event`. |
| **AC-07** | Unsupported migrated membership and stable-ID conflicts degrade conservatively; incomplete-source absence never establishes an empty project. |
| **AC-08** | Every healthy catalog entry remains reachable as exactly one full row. Empty sections disappear and ordering remains stable. |
| **AC-09** | Compact rows, section-level default text, disclosures, unknown states, and exact inactive wording follow this specification. |
| **AC-10** | Meaningful runtime differences are detected for custom and inherited projects without opening their editors. Missing confirmation stays visibly unconfirmed. |
| **AC-11** | Collapsed inactive problems expose names, issues, and editing; expansion replaces previews without duplicate rows or counts. |
| **AC-12** | Search covers all documented fields and sections; counts, temporary expansion, warning summaries, clearing, empty states, and no-results behavior work as specified. |
| **AC-13** | Editing survives refresh/save without section movement, draft loss, silent rebasing, or weaker write guards. Latest placement appears after dismissal. |
| **AC-14** | Disclosures/query survive relevant refreshes. Long/duplicate names, keyboard/accessibility interaction, and a fixture of at least 200 projects remain usable without per-row process launches on every refresh. |
| **AC-15** | Browsing and presentation refresh write no Codex metadata, configuration, or visibility database and publish no routing mutation. Explicit saves retain their existing assignment-only scope. |
| **AC-16** | Relevant routing, account/default, assignment safety/recovery, and projectless regressions pass. Packaged integration is checked when observation/control changes affect bundled resources. |
| **AC-17** | Documentation explains unarchived semantics, the deletion/unknown limitation, supported evidence, refresh, search, counts, and warnings, distinguishing actual checks from unobserved behavior. |

Verification must include:

- Focused Node fixtures for classification, supported/unsupported evidence, internal records, missing rows, conflicts, and changing sources.
- Swift presentation/controller/editor coverage for grouping, warnings, search, counts, disclosure, and editing stability.
- List-wide runtime observation checks covering inheritance, explicit-current-default policy differences, Off, stopped, and unavailable states.
- Relevant existing regression suites and packaged integration checks.
- Native companion inspection of healthy, warning, unknown, inactive, search, long-name, and larger-list states.

Preserve the existing ordered native/build/Node/package validation convention where that path applies. String assertions alone do not establish usable UI behavior.

The disposable Codex experiment is discovery evidence, not verification of the future companion. No implementation tests or companion UI validation have been run during this specification stage. Further real-state experiments require their own explained, explicit authorization.

## 5. Constraints, exclusions, and approval

Preserve assignment persistence and inheritance, account/default configuration, On/Off, immutable request selection, projectless compatibility, existing recovery safeguards, and actionable information.

Read-only observation may extend catalog/control presentation. This increment does not change request identity resolution, routing policy, credential handling, provider setup, configuration-schema behavior, or general reload capabilities.

Defer:

- Manual hide/show and a companion visibility database.
- Age-based activity rules.
- Broader navigation, controls, or recovery redesign.
- Startup, installation, packaging, and distribution improvements.
- A second membership backend, metadata repair, or broader reverse engineering.

Do not commit private experimental IDs, prompts, transcripts, credentials, endpoints, or private paths.

Planning will choose module boundaries, exact read-only wire encoding, and bounded consistency mechanics. If the supported observation contract cannot be implemented from this evidence without broader work, return to scope/design rather than weakening the unknown policy.

Follow the supplied Git workflow: no main update, implementation branch, artifact commit, or product change before separate specification and plan approvals. Save both approved artifacts before implementation; preserve them uncommitted until the implementation branch exists. Use the existing checkout and an appropriate conventional branch. No worktree, push, or merge is authorized.

**Builder check:** A fresh reviewer requested exact sanitized observer evidence. That evidence has been incorporated; the reviewer confirmed the question resolved.

**Execution endpoint:** Complete only this approved increment, including verification, documentation, required review, and authorized local commits; report the working result, observed evidence, limitations, and implications for later increments, then stop.

**Approval history and next handoff:** The complete unsaved DRAFT was presented at Stage 2. The following user message, **“Please implement the plan.”**, approved that specification and authorized a separate implementation plan only. This saved specification records that approval without changing its substantive requirements. Stage 3 must present the separate plan and stop for its explicit approval. No implementation is authorized by this specification approval.

**Separate plan approval:** After the matching plan was presented at Stage 3, the user replied **“approve”**, then selected Subagent-driven execution. This completes the separate approval gates for this increment; no push or merge is authorized.
