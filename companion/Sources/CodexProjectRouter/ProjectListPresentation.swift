import Foundation
import CompanionCore

enum ProjectListSectionKind: String, CaseIterable, Hashable {
    case attention, custom, `default`, noActive
}

struct ProjectListPin: Equatable {
    let projectID: String
    let section: ProjectListSectionKind
    let index: Int
}

/// Transient layout only. Neither the pin nor disclosure state carries editor authority.
struct ProjectListViewState: Equatable {
    var query = ""
    var inactiveExpanded = false
    var disclosedProjectIDs: Set<String> = []
    var pin: ProjectListPin?
    private(set) var pinQuery: String?
    private(set) var pinVisibleIndex: Int?
    private(set) var pinWasPreview = false

    mutating func beginEditing(projectID: String, displayedSections: [ProjectListSection]) {
        for section in displayedSections {
            // Keep the pre-filter index: a visible match index would move the row when reapplied before search.
            if let index = section.projectIDs.firstIndex(of: projectID) {
                pin = .init(projectID: projectID, section: section.kind, index: index)
                pinQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                pinWasPreview = !section.isExpanded
                pinVisibleIndex = (pinWasPreview ? section.problemPreviews : section.rows).firstIndex { $0.id == projectID }
                return
            }
        }
        endEditing()
    }
    mutating func endEditing() { pin = nil; pinQuery = nil; pinVisibleIndex = nil; pinWasPreview = false }
    mutating func clearSearch() { query = "" }
}

struct ProjectListIssue: Equatable {
    enum Kind: Hashable {
        case policyUnknown, targetMissing, discoveryMissing, runtimeDifference
        case assignmentPending, assignmentUncertain, assignmentDiverged, assignmentFailure
    }
    let kind: Kind
    let text: String
}

struct ProjectListNotice: Equatable {
    enum Kind: Hashable {
        case runtimeUnconfirmed, notRunning, routingOff, defaultDifference
        case assignmentPending, assignmentUncertain, assignmentDiverged, assignmentFailure
    }
    let kind: Kind
    let text: String
}

enum ProjectListRunningStatus: Equatable { case matching, different, unconfirmed, notRunning }

struct ProjectListRow: Identifiable, Equatable {
    let project: Inspection.Entry
    var section: ProjectListSectionKind?
    let accountText: String
    let issues: [ProjectListIssue]
    let chatStatusText: String?
    let chatStatusDetail: String?
    let details: [String]
    let runningStatus: ProjectListRunningStatus
    var placementNotice: String?
    var id: String { project.id }
    var isActionable: Bool { !issues.isEmpty }
}

struct ProjectListSection: Identifiable, Equatable {
    let kind: ProjectListSectionKind
    let title: String
    let subtitle: String?
    let rows: [ProjectListRow]
    let problemPreviews: [ProjectListRow]
    let countText: String
    let notices: [ProjectListNotice]
    let isExpanded: Bool
    /// Unfiltered ordered identities, including collapsed entries, for placement and counts; never extra rendered rows.
    let projectIDs: [String]
    var id: ProjectListSectionKind { kind }
}

enum ProjectListEmptyState: Equatable {
    case emptyCatalog, noResults, unavailable
    var text: String {
        switch self {
        case .emptyCatalog: return "No local projects in this catalog."
        case .noResults: return "No matching projects."
        case .unavailable: return "Catalog unavailable. Refresh to retry."
        }
    }
}

/// A display projection of saved catalog policy and token-free runtime evidence. It never grants write authority.
struct ProjectListPresentation {
    let inspection: Inspection?
    let runtimeState: ProjectListRuntimeState
    let selectedAssignment: AssignmentState?
    let assignmentStatus: RouterController.AssignmentStatus
    let assignmentError: String?
    let pendingProjectID: String?

    init(inspection: Inspection?, runtimeState: ProjectListRuntimeState, selectedAssignment: AssignmentState?,
         assignmentStatus: RouterController.AssignmentStatus, assignmentError: String?, pendingProjectID: String?) {
        self.inspection = inspection; self.runtimeState = runtimeState; self.selectedAssignment = selectedAssignment
        self.assignmentStatus = assignmentStatus; self.assignmentError = assignmentError; self.pendingProjectID = pendingProjectID
    }

    var usesAccountSections: Bool { inspection?.configuration.mode == "accounts" }
    private var entries: [Inspection.Entry] { inspection?.catalog.state == "ready" ? inspection?.catalog.entries ?? [] : [] }
    private var savedDefault: AccountSummary? { inspection?.configuration.defaultAccount }
    private var running: ProjectListRunningAssignments? {
        if case .observed(let observation) = runtimeState { return observation }
        return nil
    }
    private var selectedProjectID: String? {
        guard selectedAssignment?.context == inspection?.context else { return nil }
        return selectedAssignment?.projectId
    }

    /// Shared facts remain visible even if search or collapse removes every affected row.
    var notices: [ProjectListNotice] {
        guard usesAccountSections else { return [] }
        var result: [ProjectListNotice] = []
        switch runtimeState {
        case .unconfirmed:
            result.append(.init(kind: .runtimeUnconfirmed, text: "Running assignments unconfirmed. Refresh to check the owned router."))
        case .notRunning:
            result.append(.init(kind: .notRunning, text: "Router not running — saved assignments load on next Start."))
        case .observed(let runtime):
            if runtime.mode == .off {
                result.append(.init(kind: .routingOff, text: "Off suspends project overrides and uses the running default."))
            }
            if let savedDefault, !sameID(savedDefault.id, runtime.defaultAccount.id) {
                let effect = runtime.mode == .off ? "Off uses the running default for every project." : "Projects using default use the running default."
                result.append(.init(kind: .defaultDifference,
                                    text: "Saved default: \(savedDefault.displayName). Running default: \(runtime.defaultAccount.displayName). \(effect)"))
            }
        }
        if let pendingProjectID, !entries.contains(where: { $0.id == pendingProjectID }) {
            result.append(.init(kind: .assignmentPending, text: "Assignment save in progress."))
        }
        if selectedProjectID == nil || !entries.contains(where: { $0.id == selectedProjectID }) {
            switch assignmentStatus {
            case .uncertain: result.append(.init(kind: .assignmentUncertain, text: "Assignment outcome unconfirmed. Refresh to inspect the pending save."))
            case .diverged: result.append(.init(kind: .assignmentDiverged, text: "Assignment information changed. Refresh to inspect the pending save."))
            default:
                if let assignmentError { result.append(.init(kind: .assignmentFailure, text: assignmentError)) }
            }
        }
        return result
    }

    func sections(state: ProjectListViewState) -> [ProjectListSection] {
        guard usesAccountSections else { return [] }
        let grouped = placedRows(state: state)
        let query = normalizedQuery(state)
        return ProjectListSectionKind.allCases.compactMap { kind in
            let all = grouped[kind] ?? []
            let matches = all.filter { matchesQuery($0, query: query) }
            guard !matches.isEmpty else { return nil }
            let expanded = kind != .noActive || state.inactiveExpanded || !query.isEmpty
            // Editing is the sole exception to actionable-only previews: a repaired row remains visible until dismissal.
            var previews = expanded ? [] : matches.filter { $0.isActionable || $0.id == state.pin?.projectID }
            if !expanded, let pin = state.pin, let index = previews.firstIndex(where: { $0.id == pin.projectID }) {
                var row = previews.remove(at: index)
                row.placementNotice = "List position updates when editing closes."
                let target = state.pinWasPreview && state.pinQuery == query.lowercased() ? state.pinVisibleIndex ?? index : index
                previews.insert(row, at: min(max(target, 0), previews.count))
            }
            let title: String
            let subtitle: String?
            switch kind {
            case .attention: title = "Needs attention"; subtitle = nil
            case .custom: title = "Custom account"; subtitle = "Accounts selected for individual projects."
            case .default: title = "Default account"; subtitle = savedDefault.map { "Saved default: \($0.displayName)" } ?? "No default designated"
            case .noActive: title = "No active chats (\(all.count))"; subtitle = "Projects with no chats or only archived chats."
            }
            return ProjectListSection(kind: kind, title: title, subtitle: subtitle,
                                      rows: expanded ? matches : [], problemPreviews: previews,
                                      countText: query.isEmpty ? "\(all.count)" : "\(matches.count) of \(all.count)", notices: [],
                                      isExpanded: expanded, projectIDs: all.map(\.id))
        }
    }

    func flatRows(state: ProjectListViewState) -> [ProjectListRow] {
        guard !usesAccountSections else { return [] }
        return entries.map(makeRow).sorted(by: alphabetical).filter { matchesQuery($0, query: normalizedQuery(state)) }
    }

    func hiddenActionableProjectCount(state: ProjectListViewState) -> Int {
        guard !normalizedQuery(state).isEmpty else { return 0 }
        return entries.map(makeRow).filter { $0.isActionable && !matchesQuery($0, query: normalizedQuery(state)) }.count
    }
    func hiddenAttentionText(state: ProjectListViewState) -> String? {
        let count = hiddenActionableProjectCount(state: state)
        guard count > 0 else { return nil }
        return count == 1 ? "1 project needing attention is hidden by search." : "\(count) projects needing attention are hidden by search."
    }
    func hiddenAttentionActionTitle(state: ProjectListViewState) -> String? {
        hiddenActionableProjectCount(state: state) > 0 ? "Clear search" : nil
    }
    func emptyState(state: ProjectListViewState) -> ProjectListEmptyState? {
        guard inspection?.catalog.state == "ready" else { return .unavailable }
        guard !entries.isEmpty else { return .emptyCatalog }
        return entries.map(makeRow).contains { matchesQuery($0, query: normalizedQuery(state)) } ? nil : .noResults
    }

    private enum Policy { case inherited, custom, unknown }
    private func policy(_ kind: String?) -> Policy {
        switch kind {
        case "inherited", "legacy_inherited": return .inherited
        case "override", "target_missing": return .custom
        default: return .unknown
        }
    }
    private func activity(_ entry: Inspection.Entry) -> ChatActivity {
        if entry.routeState == "catalog_missing" { return .init(state: .unknown, reason: .projectUnresolved) }
        return entry.chatActivity ?? .init(state: .unknown, reason: .metadataUnavailable)
    }
    private func naturalSection(_ entry: Inspection.Entry) -> ProjectListSectionKind {
        if policy(entry.assignmentKind) == .unknown { return .attention }
        if activity(entry).state == .noActiveChats { return .noActive }
        return policy(entry.assignmentKind) == .inherited ? .default : .custom
    }
    private func placedRows(state: ProjectListViewState) -> [ProjectListSectionKind: [ProjectListRow]] {
        var grouped = Dictionary(grouping: entries.map(makeRow), by: { $0.section! })
        for key in grouped.keys { grouped[key]?.sort(by: alphabetical) }
        guard let pin = state.pin,
              let source = ProjectListSectionKind.allCases.first(where: { grouped[$0]?.contains { $0.id == pin.projectID } == true }),
              let index = grouped[source]?.firstIndex(where: { $0.id == pin.projectID }),
              var row = grouped[source]?.remove(at: index) else { return grouped }
        row.section = pin.section
        var destination = grouped[pin.section] ?? []
        var target = min(max(pin.index, 0), destination.count)
        let query = normalizedQuery(state)
        if !query.isEmpty, state.pinQuery == query.lowercased(), let visibleIndex = state.pinVisibleIndex {
            let matchingIndices = destination.indices.filter { matchesQuery(destination[$0], query: query) }
            if visibleIndex < matchingIndices.count { target = matchingIndices[max(visibleIndex, 0)] }
            else if let last = matchingIndices.last { target = last + 1 }
        }
        if source != pin.section || index != target { row.placementNotice = "List position updates when editing closes." }
        destination.insert(row, at: target)
        grouped[pin.section] = destination
        return grouped
    }

    private func makeRow(_ entry: Inspection.Entry) -> ProjectListRow {
        let savedPolicy = policy(entry.assignmentKind)
        var issues: [ProjectListIssue] = []
        var details = ["Project ID: \(entry.id)"]
        if let alias = entry.routeAlias { details.append("Route alias: \(alias)") }
        if !usesAccountSections {
            let label: String
            if inspection?.configuration.mode == "legacy" {
                label = entry.routeAlias == nil ? "Global credential" : "Global credential; saved label retained"
            } else { label = entry.routeAlias == nil ? "Assignment unconfirmed" : "Override saved (routing unconfirmed)" }
            if entry.routeState == "catalog_missing" { issues.append(.init(kind: .discoveryMissing, text: "Saved project absent from current discovery.")) }
            return .init(project: entry, section: nil, accountText: label, issues: issues, chatStatusText: nil,
                         chatStatusDetail: nil, details: details, runningStatus: .unconfirmed)
        }
        let accountText: String
        switch savedPolicy {
        case .inherited:
            accountText = "Uses default"
            details.append("Saved: Uses default — \(savedDefault?.displayName ?? "No default designated")")
            if savedDefault == nil { issues.append(.init(kind: .targetMissing, text: "No default account designated.")) }
        case .custom:
            accountText = entry.assignmentKind == "target_missing" ? "Missing account target" : entry.account?.displayName ?? "Missing account target"
            details.append("Saved: \(accountText)")
            if entry.assignmentKind == "target_missing" || entry.account == nil {
                issues.append(.init(kind: .targetMissing, text: "Missing account target. Choose an existing account or Use default."))
            }
        case .unknown:
            accountText = "Assignment unconfirmed"
            issues.append(.init(kind: .policyUnknown, text: "Saved assignment policy is unavailable. Refresh to inspect it."))
        }
        if entry.assignmentKind == "legacy_inherited" { details.append("Inherited label retained") }
        if entry.routeState == "catalog_missing" { issues.append(.init(kind: .discoveryMissing, text: "Saved project absent from current discovery.")) }

        let runningStatus: ProjectListRunningStatus
        if let running, let summary = running.assignments.first(where: { sameID($0.key, entry.id) })?.value {
            let runningPolicy = policy(summary.kind)
            let defaultDifference = savedPolicy == .inherited && runningPolicy == .inherited &&
                savedDefault.map { !sameID($0.id, running.defaultAccount.id) } == true
            if savedPolicy == .unknown || runningPolicy == .unknown {
                runningStatus = .unconfirmed
            } else if savedPolicy != runningPolicy {
                runningStatus = .different
            } else if savedPolicy == .inherited, let savedDefault {
                runningStatus = sameID(savedDefault.id, running.defaultAccount.id) ? .matching : .different
            } else if savedPolicy == .custom, let savedAccount = entry.account, let runningAccount = summary.account {
                runningStatus = sameID(savedAccount.id, runningAccount.id) ? .matching : .different
            } else {
                runningStatus = .unconfirmed
            }
            if runningStatus == .different && !defaultDifference {
                issues.append(.init(kind: .runtimeDifference, text: "Saved and running assignments differ."))
            }
            let runningText = runningPolicy == .inherited ? "Uses default — \(summary.account?.displayName ?? running.defaultAccount.displayName)" : summary.account?.displayName ?? "Missing account target"
            details.append("Running: \(runningText)")
            if let alias = summary.routeAlias { details.append("Running route alias: \(alias)") }
        } else if runtimeState == .notRunning { runningStatus = .notRunning }
        else { runningStatus = .unconfirmed }

        if pendingProjectID == entry.id { issues.append(.init(kind: .assignmentPending, text: "Assignment save in progress.")) }
        else if selectedProjectID == entry.id {
            switch assignmentStatus {
            case .uncertain: issues.append(.init(kind: .assignmentUncertain, text: "Assignment outcome unconfirmed. Refresh to inspect the pending save."))
            case .diverged: issues.append(.init(kind: .assignmentDiverged, text: "Assignment information changed. Refresh to inspect the pending save."))
            default:
                if let assignmentError { issues.append(.init(kind: .assignmentFailure, text: assignmentError)) }
            }
        }
        let chat = activity(entry)
        return .init(project: entry, section: naturalSection(entry), accountText: accountText, issues: issues,
                     chatStatusText: chat.state == .unknown ? "Chat status unknown" : nil,
                     chatStatusDetail: chat.reason.map(reasonText), details: details, runningStatus: runningStatus)
    }

    private func normalizedQuery(_ state: ProjectListViewState) -> String { state.query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func matchesQuery(_ row: ProjectListRow, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        var fields = [row.project.name, row.id, row.project.routeAlias ?? ""]
        if usesAccountSections {
            fields.append(policy(row.project.assignmentKind) == .inherited ? savedDefault?.displayName ?? "" : row.project.account?.displayName ?? "")
        }
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }
    private func alphabetical(_ lhs: ProjectListRow, _ rhs: ProjectListRow) -> Bool {
        let result = lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name)
        return result == .orderedSame ? lhs.id < rhs.id : result == .orderedAscending
    }
    private func sameID(_ lhs: String, _ rhs: String) -> Bool { lhs.lowercased() == rhs.lowercased() }
    private func reasonText(_ reason: ChatActivity.Reason) -> String {
        switch reason {
        case .metadataUnavailable: return "Chat metadata is unavailable. Archive state cannot be confirmed."
        case .incompleteMetadata: return "Chat metadata is incomplete. Archive state cannot be confirmed."
        case .missingRecord: return "A referenced chat record is missing. Its archive state cannot be confirmed."
        case .conflictingMembership: return "Chat membership evidence conflicts. Archive state cannot be confirmed."
        case .unsupportedMetadata: return "Chat metadata uses an unsupported representation. Archive state cannot be confirmed."
        case .changedDuringRead: return "Chat metadata changed during inspection. Refresh to check again."
        case .projectUnresolved: return "This saved project is absent from current discovery. Its chat status cannot be confirmed."
        }
    }
}
