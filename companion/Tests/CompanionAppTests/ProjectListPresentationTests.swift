import XCTest
@testable import CompanionCore
@testable import CodexProjectRouter

final class ProjectListPresentationTests: XCTestCase {
    private let personal = AccountSummary(id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", displayName: "Personal")
    private let work = AccountSummary(id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", displayName: "Work")
    private let context = ActivationContext(configPath: "/synthetic/config.json", codexHome: "/synthetic/codex", providerId: "synthetic", listenPort: 43129)

    private func entry(_ id: String, _ name: String, kind: String? = "inherited", account: AccountSummary? = nil,
                       activity: ChatActivity = .init(state: .unarchived), alias: String? = nil, routeState: String = "unmapped") -> Inspection.Entry {
        .init(id: id, name: name, routeAlias: alias, routeState: routeState, account: account, assignmentKind: kind, chatActivity: activity)
    }
    private func inspection(_ entries: [Inspection.Entry], defaultAccount: AccountSummary? = nil, mode: String? = "accounts", catalogState: String = "ready") -> Inspection {
        .init(configuration: .init(state: "valid", mode: mode, defaultAccount: defaultAccount ?? personal, accounts: [personal, work]), context: context,
              provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"),
              catalog: .init(state: catalogState, entries: entries))
    }
    private func display(_ snapshot: Inspection?, runtime: ProjectListRuntimeState = .notRunning, selected: AssignmentState? = nil,
                         status: RouterController.AssignmentStatus = .ready, error: String? = nil, pending: String? = nil) -> ProjectListPresentation {
        .init(inspection: snapshot, runtimeState: runtime, routingStatus: .notRunning, selectedAssignment: selected, assignmentStatus: status,
              assignmentError: error, pendingProjectID: pending)
    }
    private func runtime(_ summaries: [String: AssignmentSummary], defaultAccount: AccountSummary? = nil, mode: ProjectRoutingMode = .on) -> ProjectListRuntimeState {
        .observed(.init(mode: mode, defaultAccount: defaultAccount ?? personal, assignments: summaries))
    }
    private func selected(_ id: String) -> AssignmentState {
        .init(context: context, savedState: "ready", projectId: id)
    }
    private func allRows(_ sections: [ProjectListSection]) -> [ProjectListRow] { sections.flatMap(\.rows) }

    // Catches reversed precedence, identity deduplication bugs and explicit-default inheritance coercion.
    func testPolicyPrecedenceAndNamedDefaultGrouping() throws {
        let entries = [entry("a", "Attention", kind: nil, activity: .init(state: .noActiveChats)),
                       entry("b", "Named default", kind: "override", account: personal),
                       entry("c", "Inherited"), entry("d", "Archived", kind: "override", account: work, activity: .init(state: .noActiveChats)),
                       entry("e", "Legacy", kind: "legacy_inherited", account: personal, alias: "old-label")]
        var state = ProjectListViewState(); state.inactiveExpanded = true
        let sections = display(inspection(entries)).sections(state: state)
        XCTAssertEqual(sections.map(\.kind), [.attention, .custom, .default, .noActive])
        XCTAssertEqual(sections.map(\.title), ["Needs attention", "Custom account", "Default account", "No active chats (1)"])
        XCTAssertEqual(sections[1].subtitle, "Accounts selected for individual projects.")
        XCTAssertEqual(sections[3].subtitle, "Projects with no chats or only archived chats.")
        XCTAssertEqual(sections[2].subtitle, "Saved default: Personal")
        XCTAssertEqual(sections[2].rows.map(\.accountText), ["Uses default", "Uses default"])
        XCTAssertEqual(allRows(sections).map(\.id).sorted(), ["a", "b", "c", "d", "e"])
        let changed = display(inspection(entries, defaultAccount: work)).sections(state: state)
        XCTAssertEqual(changed[1].rows.first?.accountText, "Personal")
        XCTAssertEqual(changed[2].rows.first?.accountText, "Uses default")
        XCTAssertEqual(changed[2].subtitle, "Saved default: Work")
        XCTAssertTrue(changed[2].rows.first?.details.contains("Saved: Uses default — Work") == true)
    }

    // Missing bindings cannot disappear into inactive/default, while established explicit policy survives a missing target.
    func testMissingPolicyAndUnresolvedProjectsRemainRecognizable() throws {
        let entries = [entry("a", "Missing binding", kind: nil, activity: .init(state: .noActiveChats)),
                       entry("b", "Missing target", kind: "target_missing", activity: .init(state: .noActiveChats), alias: "lost", routeState: "target_missing"),
                       entry("c", "Unavailable explicit", kind: "override"),
                       entry("d", "Saved absent", kind: "override", account: work, activity: .init(state: .unknown, reason: .projectUnresolved), routeState: "catalog_missing")]
        let sections = display(inspection(entries)).sections(state: .init())
        XCTAssertEqual(sections.map(\.kind), [.attention, .custom])
        XCTAssertEqual(sections[0].rows.map(\.id), ["a", "b"])
        let missingBinding = try XCTUnwrap(sections[0].rows.first { $0.id == "b" })
        XCTAssertEqual(missingBinding.accountText, "Assignment unconfirmed")
        XCTAssertEqual(missingBinding.issues.map(\.kind), [.policyUnknown, .targetMissing])
        XCTAssertEqual(sections[1].rows.map(\.id), ["d", "c"])
        XCTAssertEqual(sections[1].rows[0].issues.map(\.kind), [.discoveryMissing])
        XCTAssertEqual(sections[1].rows[1].accountText, "Missing account target")
        XCTAssertEqual(sections[1].rows[1].issues.map(\.kind), [.targetMissing])
    }

    // A same-account explicit/inherited mismatch matters in both modes; aliases and display-name changes alone do not.
    func testRuntimePolicyDiffersEvenWhenEffectiveAccountMatches() throws {
        let entries = [entry("a", "Explicit", kind: "override", account: personal, alias: "saved"), entry("b", "Inherited"),
                       entry("c", "Alias only", kind: "legacy_inherited", account: personal, alias: "legacy")]
        for mode in [ProjectRoutingMode.on, .off] {
            let run = runtime(["a": .init(kind: "inherited", account: personal),
                               "b": .init(kind: "override", account: personal, routeAlias: "named"),
                               "c": .init(kind: "inherited", account: .init(id: personal.id.uppercased(), displayName: "Runtime personal"))], mode: mode)
            let rows = allRows(display(inspection(entries), runtime: run).sections(state: .init()))
            XCTAssertEqual(rows.first { $0.id == "a" }?.runningStatus, .different)
            XCTAssertEqual(rows.first { $0.id == "b" }?.runningStatus, .different)
            XCTAssertEqual(rows.first { $0.id == "c" }?.runningStatus, .matching)
            XCTAssertTrue(rows.first { $0.id == "a" }?.issues.contains { $0.kind == .runtimeDifference } == true)
            XCTAssertTrue(rows.first { $0.id == "c" }?.issues.isEmpty == true)
            XCTAssertTrue(rows.first { $0.id == "c" }?.details.contains("Route alias: legacy") == true)
            XCTAssertTrue(rows.first { $0.id == "c" }?.details.contains("Running: Uses default — Runtime personal") == true)
        }
    }

    // Off applies its own default even when no project inherits: the shared difference must stay visible.
    func testOffDefaultDifferenceSurvivesAnAllCustomCatalog() {
        let project = entry("a", "Custom", kind: "override", account: work)
        let model = display(inspection([project]), runtime: runtime(["a": .init(kind: "override", account: work, routeAlias: "work")], defaultAccount: work, mode: .off))
        XCTAssertEqual(model.notices.filter { $0.kind == .defaultDifference }.map(\.text),
                       ["Saved default: Personal. Running default: Work. Off uses the running default for every project."])
        XCTAssertEqual(allRows(model.sections(state: .init())).first?.runningStatus, .matching)
        XCTAssertTrue(allRows(model.sections(state: .init())).first?.issues.isEmpty == true)
    }

    // Default identity differences are shared, while duplicate account names cannot hide per-project identity changes.
    func testDefaultDifferenceAndDuplicateNamesCompareStableIdentities() {
        let duplicate = AccountSummary(id: work.id, displayName: "Personal")
        let entries = [entry("a", "Inherited"), entry("b", "Explicit", kind: "override", account: personal)]
        let model = display(inspection(entries), runtime: runtime(["a": .init(kind: "inherited", account: duplicate),
                                                                 "b": .init(kind: "override", account: duplicate, routeAlias: "work")], defaultAccount: duplicate))
        let rows = allRows(model.sections(state: .init()))
        XCTAssertEqual(rows.first { $0.id == "a" }?.runningStatus, .different)
        XCTAssertTrue(rows.first { $0.id == "a" }?.issues.isEmpty == true)
        XCTAssertEqual(rows.first { $0.id == "b" }?.issues.map(\.kind), [.runtimeDifference])
        XCTAssertEqual(model.notices.filter { $0.kind == .defaultDifference }.count, 1)
    }

    // Unknown activity is neutral, including missing optional enrichment, and reasons stay in disclosure.
    func testUnknownChatStatusDoesNotCreateActionableProblems() {
        let reasons: [ChatActivity.Reason] = [.metadataUnavailable, .incompleteMetadata, .missingRecord, .conflictingMembership,
                                              .unsupportedMetadata, .changedDuringRead, .projectUnresolved]
        for reason in reasons {
            var item = entry("a", "Unknown", activity: .init(state: .unknown, reason: reason))
            if reason == .metadataUnavailable { item.chatActivity = nil }
            let row = allRows(display(inspection([item])).sections(state: .init())).first
            XCTAssertEqual(row?.section, .default)
            XCTAssertEqual(row?.chatStatusText, "Chat status unknown")
            XCTAssertFalse(row?.chatStatusDetail?.isEmpty ?? true)
            XCTAssertTrue(row?.issues.isEmpty == true)
        }
        let missing = entry("a", "Deleted chat", activity: .init(state: .unknown, reason: .missingRecord))
        XCTAssertEqual(allRows(display(inspection([missing])).sections(state: .init())).first?.chatStatusDetail,
                       "A referenced chat record is missing. Its archive state cannot be confirmed.")
    }

    // Previews replace collapsed full rows and never inflate the section's eight project identities.
    func testCollapsedPreviewsCountOnce() throws {
        let entries = (0..<8).map { entry("\($0)", "Project \($0)", kind: $0 == 3 ? "override" : "inherited", activity: .init(state: .noActiveChats), alias: $0 == 3 ? "missing" : nil) }
        let model = display(inspection(entries))
        let collapsed = try XCTUnwrap(model.sections(state: .init()).first)
        XCTAssertEqual(collapsed.title, "No active chats (8)")
        XCTAssertEqual(collapsed.countText, "8")
        XCTAssertTrue(collapsed.rows.isEmpty)
        XCTAssertEqual(collapsed.problemPreviews.map(\.id), ["3"])
        XCTAssertEqual(collapsed.projectIDs.count, 8)
        var state = ProjectListViewState(); state.inactiveExpanded = true
        let expanded = try XCTUnwrap(model.sections(state: state).first)
        XCTAssertEqual(expanded.rows.count, 8)
        XCTAssertTrue(expanded.problemPreviews.isEmpty)
        XCTAssertEqual(Set(expanded.rows.map(\.id)).count, 8)
    }

    // A trimmed query searches hidden technical fields/default names and temporarily opens inactive without altering user state.
    func testSearchMatchesAllFieldsAndRestoresExpansion() throws {
        let entries = [entry("stable-id", "Long project", kind: "override", account: work, alias: "route-special"),
                       entry("inherit", "Inherited"), entry("archived", "Old project", activity: .init(state: .noActiveChats))]
        let model = display(inspection(entries))
        let cases: [(String, [String])] = [(" LONG ", ["stable-id"]), ("STABLE-ID", ["stable-id"]), ("ROUTE-special", ["stable-id"]),
                                           ("work", ["stable-id"]), ("personal", ["inherit", "archived"])]
        for (query, ids) in cases {
            var state = ProjectListViewState(); state.query = query
            XCTAssertEqual(allRows(model.sections(state: state)).map(\.id), ids)
            XCTAssertFalse(state.inactiveExpanded)
        }
        var state = ProjectListViewState(); state.query = "Old project"
        XCTAssertEqual(model.sections(state: state).first?.rows.map(\.id), ["archived"])
        XCTAssertTrue(model.sections(state: state).first?.problemPreviews.isEmpty == true)
        state.query = ""
        XCTAssertTrue(model.sections(state: state).last?.rows.isEmpty == true)
        let many = (0..<8).map { entry("\($0)", $0 < 2 ? "Match \($0)" : "Other \($0)", activity: .init(state: .noActiveChats)) }
        state.query = "match"
        XCTAssertEqual(display(inspection(many)).sections(state: state).first?.countText, "2 of 8")
    }

    // Search must not silently hide a repair, and clearSearch restores the previous inactive expansion preference.
    func testHiddenActionableSummaryOffersClearSearch() {
        let entries = [entry("a", "Broken", kind: "target_missing", activity: .init(state: .noActiveChats), alias: "missing"),
                       entry("b", "Healthy", activity: .init(state: .unknown, reason: .missingRecord))]
        let model = display(inspection(entries))
        var state = ProjectListViewState(); state.query = "Healthy"; state.inactiveExpanded = false
        XCTAssertEqual(model.hiddenActionableProjectCount(state: state), 1)
        XCTAssertEqual(model.hiddenAttentionText(state: state), "1 project needing attention is hidden by search.")
        XCTAssertEqual(model.hiddenAttentionActionTitle(state: state), "Clear search")
        state.clearSearch()
        XCTAssertEqual(model.hiddenActionableProjectCount(state: state), 0)
        XCTAssertFalse(state.inactiveExpanded)
        XCTAssertEqual(model.sections(state: state).first?.kind, .attention)
        XCTAssertEqual(model.sections(state: state).first?.rows.map(\.id), ["a"])
    }

    // Editor pinning affects placement only: fresh policy, warnings, disclosure, search and counts remain live.
    func testPinnedEditorUsesFreshValuesAtOldPlacement() throws {
        let original = display(inspection([entry("a", "Alpha"), entry("b", "Beta"), entry("c", "Gamma")]))
        var state = ProjectListViewState(); state.disclosedProjectIDs = ["b"]
        state.beginEditing(projectID: "b", displayedSections: original.sections(state: state))
        XCTAssertEqual(state.pin, .init(projectID: "b", section: .default, index: 1))
        let latest = display(inspection([entry("a", "Alpha"), entry("b", "Zeta", kind: "override", account: work, activity: .init(state: .noActiveChats)), entry("c", "Gamma")]), pending: "b")
        let pinned = try XCTUnwrap(allRows(latest.sections(state: state)).first { $0.id == "b" })
        XCTAssertEqual(pinned.section, .default)
        XCTAssertEqual(pinned.accountText, "Work")
        XCTAssertEqual(pinned.issues.map(\.kind), [.assignmentPending])
        XCTAssertEqual(pinned.placementNotice, "List position updates when editing closes.")
        XCTAssertEqual(latest.sections(state: state).first?.rows.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(latest.sections(state: state).first?.countText, "3")
        XCTAssertEqual(state.disclosedProjectIDs, ["b"])
        state.endEditing(); state.inactiveExpanded = true
        XCTAssertEqual(allRows(latest.sections(state: state)).first { $0.id == "b" }?.section, .noActive)
        XCTAssertNil(allRows(latest.sections(state: state)).first { $0.id == "b" }?.placementNotice)
    }

    // A vanished identity or unavailable catalog cannot be recreated by the presentation pin.
    func testPinFromCollapsedPreviewAndDisappearanceNeverInventRows() {
        let item = entry("a", "Missing", kind: "override", activity: .init(state: .noActiveChats), alias: "lost")
        let model = display(inspection([item]))
        var state = ProjectListViewState(); state.beginEditing(projectID: "a", displayedSections: model.sections(state: state))
        XCTAssertEqual(state.pin, .init(projectID: "a", section: .noActive, index: 0))
        XCTAssertTrue(display(inspection([])).sections(state: state).isEmpty)
        XCTAssertTrue(display(inspection([item], catalogState: "unavailable")).sections(state: state).isEmpty)
    }

    // Shared unknown/stopped states cannot manufacture per-project differences, even when one editor has evidence.
    func testSharedRuntimeStatesAndTargetedAssignmentProblems() {
        let entries = [entry("a", "Alpha"), entry("b", "Beta")]
        let unconfirmed = display(inspection(entries), runtime: .unconfirmed, selected: selected("a"))
        XCTAssertEqual(unconfirmed.notices.map(\.kind), [.runtimeUnconfirmed])
        XCTAssertTrue(allRows(unconfirmed.sections(state: .init())).allSatisfy { $0.runningStatus == .unconfirmed && $0.issues.isEmpty })
        XCTAssertEqual(display(inspection(entries)).notices.map(\.kind), [.notRunning])
        let cases: [(RouterController.AssignmentStatus, ProjectListIssue.Kind)] = [(.uncertain, .assignmentUncertain), (.diverged, .assignmentDiverged)]
        for (status, expected) in cases {
            let rows = allRows(display(inspection(entries), selected: selected("a"), status: status).sections(state: .init()))
            XCTAssertEqual(rows.first { $0.id == "a" }?.issues.map(\.kind), [expected])
            XCTAssertTrue(rows.first { $0.id == "b" }?.issues.isEmpty == true)
        }
        let pending = allRows(display(inspection(entries), selected: selected("a"), pending: "b").sections(state: .init()))
        XCTAssertEqual(pending.first { $0.id == "b" }?.issues.map(\.kind), [.assignmentPending])
        let failed = allRows(display(inspection(entries), selected: selected("a"), error: "Refresh before editing.").sections(state: .init()))
        XCTAssertEqual(failed.first { $0.id == "a" }?.issues.map(\.text), ["Refresh before editing."])
    }

    // Unknown saved policy or unavailable account identity cannot be promoted to a confirmed difference.
    func testIncompletePolicyEvidenceRemainsUnconfirmed() {
        let entries = [entry("a", "Unknown saved", kind: nil), entry("b", "Missing saved target", kind: "target_missing", alias: "lost")]
        let model = display(inspection(entries), runtime: runtime(["a": .init(kind: "inherited", account: personal),
                                                                 "b": .init(kind: "override", account: work, routeAlias: "work")]))
        let rows = allRows(model.sections(state: .init()))
        XCTAssertEqual(rows.first { $0.id == "a" }?.runningStatus, .unconfirmed)
        XCTAssertEqual(rows.first { $0.id == "a" }?.issues.map(\.kind), [.policyUnknown])
        XCTAssertEqual(rows.first { $0.id == "b" }?.runningStatus, .unconfirmed)
        XCTAssertEqual(rows.first { $0.id == "b" }?.section, .attention)
        XCTAssertEqual(rows.first { $0.id == "b" }?.issues.map(\.kind), [.policyUnknown, .targetMissing])
    }

    // Filtered visible indices cannot be applied as full-list indices when a refreshed project changes section.
    func testEditingFromSearchPreservesVisiblePositionWithHiddenRows() throws {
        let entries = [entry("a", "Alpha hidden"), entry("b", "Beta match"), entry("c", "Charlie hidden"), entry("d", "Delta match")]
        var state = ProjectListViewState(); state.query = "match"; state.disclosedProjectIDs = ["d"]
        let before = display(inspection(entries)).sections(state: state)
        XCTAssertEqual(before.first?.rows.map(\.id), ["b", "d"])
        state.beginEditing(projectID: "d", displayedSections: before)
        XCTAssertEqual(state.pin?.index, 3)
        let latest = display(inspection([entries[0], entries[1], entries[2], entry("d", "Delta match", kind: "override", account: work)]), pending: "d")
        let pinnedSections = latest.sections(state: state)
        XCTAssertEqual(pinnedSections.map(\.kind), [.default])
        XCTAssertEqual(pinnedSections.first?.rows.map(\.id), ["b", "d"])
        XCTAssertEqual(pinnedSections.first?.countText, "2 of 4")
        let pinned = try XCTUnwrap(pinnedSections.first?.rows.last)
        XCTAssertEqual(pinned.accountText, "Work")
        XCTAssertEqual(pinned.issues.map(\.kind), [.assignmentPending])
        XCTAssertEqual(pinned.placementNotice, "List position updates when editing closes.")
        XCTAssertEqual(state.query, "match")
        XCTAssertEqual(state.disclosedProjectIDs, ["d"])
        state.endEditing()
        XCTAssertEqual(latest.sections(state: state).map(\.kind), [.custom, .default])
        XCTAssertEqual(latest.sections(state: state).map(\.countText), ["1 of 1", "1 of 3"])
    }

    // Newly discovered nonmatches must not change an open editor's visible index under the same query.
    func testFilteredPinSurvivesNewNonmatchingRowsBeforeIt() throws {
        var state = ProjectListViewState(); state.query = "match"
        let original = [entry("a", "Alpha hidden"), entry("b", "Beta match"), entry("c", "Charlie hidden"), entry("d", "Delta match")]
        state.beginEditing(projectID: "d", displayedSections: display(inspection(original)).sections(state: state))
        let updated = [entry("new-1", "Aardvark hidden"), entry("new-2", "Abacus hidden"), original[0], original[1], original[2],
                       entry("d", "Delta match", kind: "override", account: work)]
        let model = display(inspection(updated), pending: "d")
        let sections = model.sections(state: state)
        XCTAssertEqual(sections.map(\.kind), [.default])
        XCTAssertEqual(sections.first?.rows.map(\.id), ["b", "d"])
        XCTAssertEqual(sections.first?.countText, "2 of 6")
        XCTAssertEqual(sections.first?.rows.last?.issues.map(\.kind), [.assignmentPending])
        XCTAssertEqual(sections.first?.rows.last?.accountText, "Work")
        state.endEditing()
        XCTAssertEqual(model.sections(state: state).map(\.kind), [.custom, .default])
    }

    // Repairing the last issue must keep the editing preview visible without marking it actionable or opening unrelated rows.
    func testRepairedEditingPreviewKeepsItsPositionWithoutExpandingInactive() throws {
        let inactive = ChatActivity(state: .noActiveChats)
        let initial = [entry("a", "Alpha problem", kind: "override", activity: inactive, alias: "lost-a"),
                       entry("b", "Beta healthy", activity: inactive),
                       entry("c", "Charlie editing", kind: "override", activity: inactive, alias: "lost-c")]
        var state = ProjectListViewState()
        state.beginEditing(projectID: "c", displayedSections: display(inspection(initial)).sections(state: state))
        let refreshed = [entry("new", "Aardvark problem", kind: "override", activity: inactive, alias: "lost-new"), initial[0], initial[1],
                         entry("c", "Charlie editing", kind: "override", account: work, activity: inactive)]
        let model = display(inspection(refreshed))
        let section = try XCTUnwrap(model.sections(state: state).first)
        XCTAssertFalse(state.inactiveExpanded)
        XCTAssertFalse(section.isExpanded)
        XCTAssertTrue(section.rows.isEmpty)
        XCTAssertEqual(section.countText, "4")
        XCTAssertEqual(section.problemPreviews.map(\.id), ["new", "c", "a"])
        let editing = try XCTUnwrap(section.problemPreviews.first { $0.id == "c" })
        XCTAssertFalse(editing.isActionable)
        XCTAssertTrue(editing.issues.isEmpty)
        XCTAssertEqual(editing.accountText, "Work")
        XCTAssertEqual(editing.placementNotice, "List position updates when editing closes.")
        state.query = "Beta"
        XCTAssertEqual(model.hiddenActionableProjectCount(state: state), 2)
        state.clearSearch(); state.endEditing()
        XCTAssertEqual(model.sections(state: state).first?.problemPreviews.map(\.id), ["new", "a"])
        XCTAssertFalse(state.inactiveExpanded)
    }

    // Legacy/no-config browsing remains flat; a route alias cannot masquerade as a named account or inherited policy.
    func testLegacyAndAbsentConfigurationPreserveFlatBrowse() {
        for mode in [String?.some("legacy"), "credential", nil] {
            let item = entry("a", "Project", kind: nil, alias: "private-route")
            let model = display(inspection([item], mode: mode))
            XCTAssertFalse(model.usesAccountSections)
            XCTAssertTrue(model.sections(state: .init()).isEmpty)
            let row = model.flatRows(state: .init()).first
            XCTAssertEqual(row?.id, "a")
            XCTAssertNotEqual(row?.accountText, "private-route")
            XCTAssertNotEqual(row?.accountText, "Uses default")
            XCTAssertTrue(row?.details.contains("Route alias: private-route") == true)
            XCTAssertTrue(row?.issues.isEmpty == true)
        }
    }

    // A credential route with an absent target must warn before Details in either routing mode and after filtering.
    @MainActor func testFlatCredentialMissingTargetsRemainActionableInOnOffAndSearch() throws {
        let broken = entry("broken", "Broken credential", kind: nil, alias: "lost-route", routeState: "target_missing")
        let healthy = entry("healthy", "Healthy credential", kind: nil)
        for mode in [ProjectRoutingMode.on, .off] {
            let model = ProjectListPresentation(inspection: inspection([broken, healthy], mode: "credential"), runtimeState: .unconfirmed,
                                                routingStatus: .known(mode), selectedAssignment: nil, assignmentStatus: .ready,
                                                assignmentError: nil, pendingProjectID: nil)
            let row = try XCTUnwrap(model.flatRows(state: .init()).first { $0.id == "broken" })
            XCTAssertEqual(row.issues.map(\.kind), [.targetMissing])
            XCTAssertEqual(row.issues.map(\.text), ["Route target missing."])
            XCTAssertTrue(row.isActionable)
            XCTAssertTrue(row.details.contains("Project routing: \(mode == .on ? "On" : "Off")"))
            var state = ProjectListViewState(); state.query = "LOST-route"
            XCTAssertEqual(model.flatRows(state: state).map(\.id), ["broken"])
            XCTAssertEqual(model.flatRows(state: state).first?.issues.map(\.kind), [.targetMissing])
            state.query = "Healthy"
            XCTAssertEqual(model.hiddenActionableProjectCount(state: state), 1)
            XCTAssertEqual(model.hiddenAttentionActionTitle(state: state), "Clear search")
            state.clearSearch()
            XCTAssertEqual(model.flatRows(state: state).count, 2)
        }
    }

    // Missing runtime targets are known failures even when account identity cannot be compared with a healthy saved override.
    func testMissingRunningTargetWarnsOnHealthySavedCustomPolicy() throws {
        let item = entry("a", "Healthy saved", kind: "override", account: work, alias: "saved-work")
        for mode in [ProjectRoutingMode.on, .off] {
            let model = display(inspection([item]), runtime: runtime(["a": .init(kind: "target_missing", routeAlias: "lost-running")], mode: mode))
            let row = try XCTUnwrap(allRows(model.sections(state: .init())).first)
            XCTAssertEqual(row.section, .custom)
            XCTAssertEqual(row.accountText, "Work")
            XCTAssertEqual(row.runningStatus, .unconfirmed)
            XCTAssertEqual(row.issues.count, 1)
            XCTAssertEqual(row.issues.map(\.text), ["Running account target missing. Refresh to inspect the running assignment."])
            XCTAssertTrue(row.isActionable)
            XCTAssertTrue(row.details.contains("Running: Missing account target"))
            XCTAssertTrue(row.details.contains("Running route alias: lost-running"))
        }
    }

    // Distinct saved/runtime warning identities keep SwiftUI from dropping either actionable issue.
    func testMissingSavedAndRunningTargetsHaveDistinctVisibleIssueIdentities() throws {
        let item = entry("a", "Both missing", kind: "target_missing", alias: "lost-saved", routeState: "target_missing")
        let model = display(inspection([item]), runtime: runtime(["a": .init(kind: "target_missing", routeAlias: "lost-running")]))
        let row = try XCTUnwrap(allRows(model.sections(state: .init())).first)
        XCTAssertEqual(row.section, .attention)
        XCTAssertEqual(row.runningStatus, .unconfirmed)
        XCTAssertEqual(row.issues.count, 3)
        XCTAssertEqual(Set(row.issues.map(\.kind)).count, 3)
        XCTAssertTrue(row.issues.contains { $0.text == "Missing account target. Choose an existing account or Use default." })
        XCTAssertTrue(row.issues.contains { $0.text == "Running account target missing. Refresh to inspect the running assignment." })
    }

    // Runtime failure previews must name the collapsed project, count once, and remain discoverable when search hides them.
    func testMissingRunningTargetRemainsInCollapsedPreviewAndHiddenSearchSummary() throws {
        let inactive = ChatActivity(state: .noActiveChats)
        let entries = [entry("a", "Archived running failure", kind: "override", account: work, activity: inactive),
                       entry("b", "Archived healthy", activity: inactive)]
        let model = display(inspection(entries), runtime: runtime(["a": .init(kind: "target_missing", routeAlias: "lost-running"),
                                                                 "b": .init(kind: "inherited", account: personal)]))
        var state = ProjectListViewState()
        let collapsed = try XCTUnwrap(model.sections(state: state).first)
        XCTAssertEqual(collapsed.kind, .noActive)
        XCTAssertEqual(collapsed.countText, "2")
        XCTAssertTrue(collapsed.rows.isEmpty)
        XCTAssertEqual(collapsed.problemPreviews.map(\.id), ["a"])
        XCTAssertEqual(collapsed.problemPreviews.first?.project.name, "Archived running failure")
        XCTAssertEqual(collapsed.problemPreviews.first?.issues.map(\.text), ["Running account target missing. Refresh to inspect the running assignment."])
        state.query = "healthy"
        XCTAssertEqual(model.sections(state: state).first?.rows.map(\.id), ["b"])
        XCTAssertEqual(model.sections(state: state).first?.countText, "1 of 2")
        XCTAssertEqual(model.hiddenActionableProjectCount(state: state), 1)
        XCTAssertEqual(model.hiddenAttentionText(state: state), "1 project needing attention is hidden by search.")
        XCTAssertEqual(model.hiddenAttentionActionTitle(state: state), "Clear search")
        state.clearSearch(); state.inactiveExpanded = true
        let expanded = try XCTUnwrap(model.sections(state: state).first)
        XCTAssertEqual(expanded.rows.map(\.id), ["b", "a"])
        XCTAssertTrue(expanded.problemPreviews.isEmpty)
        XCTAssertEqual(Set(expanded.rows.map(\.id)).count, 2)
    }

    // Empty, filtered-empty and failed discovery need different user actions/messages.
    func testEmptyNoResultsAndUnavailableAreDistinct() {
        XCTAssertEqual(display(inspection([])).emptyState(state: .init()), .emptyCatalog)
        var state = ProjectListViewState(); state.query = "no match"
        XCTAssertEqual(display(inspection([entry("a", "Alpha")])).emptyState(state: state), .noResults)
        XCTAssertEqual(display(nil).emptyState(state: .init()), .unavailable)
        XCTAssertEqual(display(inspection([entry("a", "Stale")], catalogState: "unavailable")).emptyState(state: state), .unavailable)
        XCTAssertNil(display(inspection([entry("a", "Alpha")])).emptyState(state: .init()))
    }

    // Case-insensitive localized ties use project identity, independent of input order; no list-size truncation.
    func testStableAlphabeticalTiesLongNamesAndTwoHundredEntries() {
        let longName = String(repeating: "Very long project 🧭 ", count: 40)
        var entries = (0..<197).map { entry(String(format: "p%03d", $0), String(format: "Project %03d", $0)) }
        entries += [entry("tie-z", "Éclair"), entry("tie-a", "éCLAIR"), entry("long", longName)]
        let rows = allRows(display(inspection(entries.reversed())).sections(state: .init()))
        XCTAssertEqual(rows.count, 200)
        XCTAssertEqual(Set(rows.map(\.id)).count, 200)
        XCTAssertEqual(rows.filter { $0.id.hasPrefix("tie-") }.map(\.id), ["tie-a", "tie-z"])
        XCTAssertEqual(rows.first { $0.id == "long" }?.project.name, longName)
        XCTAssertEqual(rows.map(\.id), allRows(display(inspection(entries)).sections(state: .init())).map(\.id))
    }
}
