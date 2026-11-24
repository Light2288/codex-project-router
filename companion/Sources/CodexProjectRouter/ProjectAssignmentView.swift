import SwiftUI
import Observation
import CompanionCore

/// Inheritance is distinct from naming the default account; a broken target needs an explicit repair.
enum AssignmentSelection: Hashable {
    case unselected, useDefault, account(String), missingTarget

    init(saved: AssignmentSummary?) {
        switch saved?.kind {
        case "inherited", "legacy_inherited": self = .useDefault
        case "override": self = saved?.account.map { .account($0.id) } ?? .missingTarget
        case "target_missing": self = .missingTarget
        default: self = .unselected
        }
    }
    var accountID: String? {
        if case .account(let id) = self { return id }
        return nil
    }
}

@MainActor struct AssignmentPresentation {
    let controller: RouterController
    let project: Inspection.Entry
    var selection: AssignmentSelection = .unselected

    private var state: AssignmentState? {
        guard let state = controller.selectedAssignment, state.projectId == project.id,
              state.context == controller.inspection?.context else { return nil }
        return state
    }
    var accounts: [AccountSummary] { controller.inspection?.configuration.accounts ?? [] }
    var savedText: String {
        if let state, state.savedState != "ready" { return "Saved assignment unavailable — refresh to check" }
        if let summary = state?.savedAssignment, controller.assignmentStatus != .unavailable {
            return "Saved: " + Self.describe(kind: summary.kind, account: summary.account)
        }
        let current = controller.inspection?.catalog.entries.first { $0.id == project.id } ?? project
        return "Saved: " + Self.describe(kind: current.assignmentKind,
            account: current.account ?? (current.assignmentKind == "inherited" || current.assignmentKind == "legacy_inherited" ? controller.inspection?.configuration.defaultAccount : nil))
    }
    var runningText: String {
        guard controller.ownedRouter != nil else { return "Router not running — saved assignment loads on next Start" }
        guard !controller.assignmentRequiresReconciliation || controller.assignmentStatus == .diverged,
              controller.pendingAssignmentOperationID == nil || !controller.busy,
              controller.assignmentStatus == .ready || controller.assignmentStatus == .diverged,
              let state, state.savedState == "ready", let summary = state.runningAssignment else {
            return "Running assignment unconfirmed"
        }
        let text = "Running: " + Self.describe(kind: summary.kind, account: summary.account)
        switch controller.projectRoutingStatus {
        case .known(.off): return text + (summary.kind == "override" || summary.kind == "target_missing" ? " (suspended while Off)" : " (routing Off)")
        case .known(.on): return text + " (routing On)"
        default: return "Running assignment unconfirmed"
        }
    }
    var actionTitle: String { controller.assignmentActionTitle }
    var canSave: Bool { disabledReason == nil }
    var disabledReason: String? {
        if controller.pendingAssignmentOperationID != nil && controller.busy { return "An assignment save is in progress." }
        if controller.assignmentRequiresReconciliation { return "Refresh to inspect the pending assignment. Further saves are blocked until it is reconciled." }
        if controller.busy { return "Wait for the current operation to finish." }
        guard controller.canEditAssignment(project) else {
            if controller.inspection?.configuration.setupState == "required" {
                return "Assignment editing is unavailable. Complete account setup in the main controls, then refresh this editor."
            }
            return "Assignment editing is unavailable. Refresh and check the configuration, account setup and router control. Direct recovery remains in the main controls."
        }
        switch selection {
        case .useDefault: return nil
        case .account(let id) where accounts.contains(where: { $0.id == id }): return nil
        case .missingTarget: return "Choose an existing account or Use default to repair the missing target."
        default: return "Choose an existing account or Use default."
        }
    }
    var warning: String? {
        var messages: [String] = []
        if project.routeState == "catalog_missing" {
            messages.append("This saved project is absent from current discovery. Its exact saved identity will be edited; discovery has not confirmed it.")
        }
        if controller.pendingAssignmentOperationID != nil && controller.busy {
            messages.append("Assignment save in progress. You may close this editor; the app will keep tracking the operation.")
        } else if controller.assignmentRequiresReconciliation {
            messages.append(controller.assignmentStatus == .diverged
                ? "Assignment or recovery information changed. Inspect saved and running assignments; the prior operation remains pending. Refresh observes its state without retrying it. Direct recovery remains available."
                : "Assignment outcome unconfirmed. Refresh to observe its state without retrying it. Direct recovery remains available.")
        } else if controller.assignmentStatus == .diverged {
            messages.append("Saved and running assignments differ or their shared baseline changed. Refresh and inspect both before editing.")
        }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
    private static func describe(kind: String?, account: AccountSummary?) -> String {
        switch kind {
        case "override": return "Override — \(account?.displayName ?? "Missing account target")"
        case "target_missing": return "Missing account target"
        case "legacy_inherited": return "Default (inherited) — \(account?.displayName ?? "No default designated"); Inherited label retained"
        case "inherited": return "Default (inherited) — \(account?.displayName ?? "No default designated")"
        default: return "Assignment unconfirmed"
        }
    }
}

/// Owns only the draft. Explicit loads rebase it; rejected saves leave the user's choice intact.
@MainActor @Observable final class AssignmentEditor {
    var selection = AssignmentSelection.unselected

    func load(controller: RouterController, project: Inspection.Entry) async {
        if let state = await controller.loadAssignment(projectID: project.id) {
            selection = AssignmentSelection(saved: state.savedAssignment)
        }
    }
    func save(controller: RouterController, project: Inspection.Entry) async {
        guard AssignmentPresentation(controller: controller, project: project, selection: selection).canSave else { return }
        let accountID = selection.accountID
        await controller.saveAssignment(projectID: project.id, accountID: accountID)
    }
}

@MainActor struct ProjectAssignmentView: View {
    let controller: RouterController
    let project: Inspection.Entry
    @Environment(\.dismiss) private var dismiss
    @State private var editor = AssignmentEditor()
    @State private var advanced = false
    private var display: AssignmentPresentation { .init(controller: controller, project: project, selection: editor.selection) }
    private var state: AssignmentState? {
        guard let state = controller.selectedAssignment, state.projectId == project.id,
              state.context == controller.inspection?.context else { return nil }
        return state
    }

    var body: some View {
        @Bindable var editor = editor
        VStack(alignment: .leading, spacing: 14) {
            Text("Project assignment").textSelection(.enabled).font(.title2.bold())
            Text(project.name.isEmpty ? "Saved project absent from discovery" : project.name).textSelection(.enabled).font(.headline)
            Text(display.savedText).textSelection(.enabled)
            Text(display.runningText).textSelection(.enabled).foregroundStyle(.secondary)
            Text("Off suspends project overrides and uses the running default. Saving never changes On/Off.").textSelection(.enabled)
                .font(.caption).foregroundStyle(.secondary)
            Picker("Account", selection: $editor.selection) {
                if editor.selection == .unselected { Text("Choose an assignment…").tag(AssignmentSelection.unselected) }
                if editor.selection == .missingTarget { Text("Missing account target — choose a repair").tag(AssignmentSelection.missingTarget) }
                if case .account(let id) = editor.selection, !display.accounts.contains(where: { $0.id == id }) {
                    Text("Selected account unavailable — choose a repair").tag(editor.selection)
                }
                Text("Use default").tag(AssignmentSelection.useDefault)
                ForEach(display.accounts, id: \.id) { account in
                    Text(account.displayName).tag(AssignmentSelection.account(account.id))
                }
            }
            .disabled(controller.busy || controller.assignmentRequiresReconciliation)
            Text("Choosing the default account by name saves an explicit override. Use default removes this project's saved override or inherited label.").textSelection(.enabled)
                .font(.caption).foregroundStyle(.secondary)
            if let warning = display.warning { Text(warning).textSelection(.enabled).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            if let error = controller.assignmentError { Text(error).textSelection(.enabled).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            if let reason = display.disabledReason { Text(reason).textSelection(.enabled).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            DisclosureGroup("Advanced", isExpanded: $advanced) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Project ID: \(project.id)")
                    if let alias = state?.savedAssignment?.routeAlias ?? project.routeAlias { Text("Saved route alias: \(alias)") }
                    if let alias = state?.runningAssignment?.routeAlias { Text("Running route alias: \(alias)") }
                }.font(.caption.monospaced()).textSelection(.enabled)
            }
            HStack {
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Refresh") { Task { await editor.load(controller: controller, project: project) } }.disabled(controller.busy)
                Button(display.actionTitle) {
                    // An explicit button task outlives the sheet; the controller owns all mutation tracking.
                    Task { await editor.save(controller: controller, project: project) }
                }.disabled(!display.canSave).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 540)
        .task { await editor.load(controller: controller, project: project) }
    }
}
