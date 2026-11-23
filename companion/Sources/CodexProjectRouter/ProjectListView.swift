import SwiftUI
import CompanionCore

/// List state stays mounted even while discovery or configuration mode is unavailable.
/// It controls presentation only; the controller and existing editor retain all write authority.
@MainActor struct ProjectListView: View {
    let controller: RouterController
    let editingProjectID: String?
    let canOpenEditor: Bool
    var pendingRoutingMode: ProjectRoutingMode? = nil
    let onEdit: (Inspection.Entry) -> Void
    @State private var state = ProjectListViewState()

    private var presentation: ProjectListPresentation {
        .init(inspection: controller.inspection, runtimeState: controller.projectListRuntimeState, routingStatus: controller.projectRoutingStatus,
              selectedAssignment: controller.selectedAssignment, assignmentStatus: controller.assignmentStatus,
              assignmentError: controller.assignmentError,
              pendingProjectID: controller.pendingAssignmentOperationID != nil && controller.busy ? controller.selectedAssignment?.projectId : nil,
              pendingRoutingMode: pendingRoutingMode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects").textSelection(.enabled).font(.headline)
            HStack {
                TextField("Search projects or accounts", text: $state.query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search projects or accounts")
                    .accessibilityIdentifier("project-search")
                if !state.query.isEmpty {
                    Button("Clear search") { state.clearSearch() }
                        .accessibilityIdentifier("project-clear-search")
                }
            }
            ForEach(presentation.notices, id: \.kind) { notice in
                let explanatory = notice.kind == .notRunning || notice.kind == .routingOff
                Text(notice.kind == .defaultDifference
                     ? "Saved and running default accounts differ. \(notice.text)" : notice.text).textSelection(.enabled)
                    .font(.callout).foregroundStyle(explanatory ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let hidden = presentation.hiddenAttentionText(state: state) {
                Text(hidden).textSelection(.enabled).font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let empty = presentation.emptyState(state: state) {
                Text(empty.text).textSelection(.enabled).foregroundStyle(.secondary)
            }
            if presentation.usesAccountSections {
                ForEach(presentation.sections(state: state)) { section in
                    sectionView(section)
                }
            } else {
                ForEach(presentation.flatRows(state: state)) { row in rowView(row) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: editingProjectID) { _, id in
            // Opening captures placement synchronously before the parent presents its sheet.
            // Only completed dismissal releases it; refresh/save never rebases the draft.
            if id == nil { state.endEditing() }
        }
    }

    private func sectionView(_ section: ProjectListSection) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                if section.kind == .noActive {
                    Button {
                        state.inactiveExpanded.toggle()
                    } label: {
                        Label(section.title, systemImage: section.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .disabled(!state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(section.title)
                    .accessibilityValue(section.isExpanded ? "Expanded" : "Collapsed")
                    .accessibilityHint(state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Show or hide projects with no active chats" : "Search temporarily shows matching projects")
                    .accessibilityIdentifier("project-section-noActive")
                } else {
                    Text(section.title).textSelection(.enabled).font(.headline).accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 8)
                if section.kind != .noActive || !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(section.countText).textSelection(.enabled).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let subtitle = section.subtitle {
                Text(subtitle).textSelection(.enabled).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(section.notices, id: \.kind) { notice in
                Text(notice.text).textSelection(.enabled).font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Previews already include the editing exception and never add to section counts.
            ForEach(section.isExpanded ? section.rows : section.problemPreviews) { row in rowView(row) }
        }
        .padding(.top, 5)
    }

    private func rowView(_ row: ProjectListRow) -> some View {
        ProjectListRowView(row: row, isDisclosed: Binding(
            get: { state.disclosedProjectIDs.contains(row.id) },
            set: { expanded in
                if expanded { state.disclosedProjectIDs.insert(row.id) }
                else { state.disclosedProjectIDs.remove(row.id) }
            }), showsEdit: controller.inspection?.configuration.mode == "accounts",
            canEdit: canOpenEditor && editingProjectID == nil && controller.canEditAssignment(row.project)) {
                state.beginEditing(projectID: row.id, displayedSections: presentation.sections(state: state))
                onEdit(row.project)
            }
    }
}

/// Full rows and collapsed problem previews share actions, accessibility and wrapping.
@MainActor private struct ProjectListRowView: View {
    let row: ProjectListRow
    @Binding var isDisclosed: Bool
    let showsEdit: Bool
    let canEdit: Bool
    let onEdit: () -> Void
    private var name: String { row.project.name.isEmpty ? "Unresolved project" : row.project.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).textSelection(.enabled).fontWeight(.medium).fixedSize(horizontal: false, vertical: true)
                    Text(row.accountText).textSelection(.enabled).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    if showsEdit {
                        Button("Edit…", action: onEdit)
                            .disabled(!canEdit)
                            .focusable()
                            .accessibilityLabel("Edit assignment for \(name)")
                            .accessibilityIdentifier("project-edit-\(row.id)")
                    }
                    Button { isDisclosed.toggle() } label: {
                        Label("Details", systemImage: isDisclosed ? "chevron.down" : "chevron.right")
                    }
                    .focusable()
                    .accessibilityLabel("Details for \(name)")
                    .accessibilityValue(isDisclosed ? "Expanded" : "Collapsed")
                    .accessibilityIdentifier("project-details-\(row.id)")
                }
                .controlSize(.small).fixedSize()
            }
            ForEach(row.issues, id: \.kind) { issue in
                Text(issue.text).textSelection(.enabled).font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let status = row.chatStatusText {
                Text(status).textSelection(.enabled).font(.caption).foregroundStyle(.secondary)
            }
            if let notice = row.placementNotice {
                Text(notice).textSelection(.enabled).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isDisclosed {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(row.details, id: \.self) { detail in Text(detail) }
                    if let detail = row.chatStatusDetail { Text(detail) }
                    if row.runningStatus == .matching { Text("Saved and running assignments match.") }
                    if row.runningStatus == .unconfirmed { Text("Running assignment unconfirmed.") }
                }
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
