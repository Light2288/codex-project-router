import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CompanionCore

@MainActor struct ControlsPresentation {
    let controller: RouterController
    var configuration: String {
        switch controller.inspection?.configuration.state {
        case "valid": return "Valid"
        case "invalid": return "Invalid configuration. Select a valid private file."
        case "unavailable": return "Configuration unavailable. Check the selected file."
        default: return "Setup required"
        }
    }
    var disk: String {
        switch controller.inspection?.provider.state {
        case "direct": return "Direct"
        case "router": return "Router"
        case "conflict": return "Conflict — inspect recovery evidence"
        default: return "Unavailable"
        }
    }
    var readiness: String {
        switch controller.inspection?.provider.proxyReady {
        case true: return "Matching listener ready"
        case false: return "No matching listener ready"
        default: return "Unknown"
        }
    }
    var ownership: String {
        if controller.ownedRouter != nil { return "Owned by this app session" }
        if controller.needsManualListenerCleanup { return "External listener; never owned" }
        return "No owned router"
    }
    var confirmation: String {
        switch controller.desktopConfirmation {
        case .unknown: return "Not confirmed"
        case .routedPending: return "Routed response confirmation pending"
        case .directPending: return "Direct response confirmation pending"
        case .confirmedRouted: return "User confirmed routed response"
        case .confirmedDirect: return "User confirmed direct response"
        }
    }
    var recoveryGuidance: String? {
        guard controller.recoveryContext != nil, controller.desktopConfirmation != .confirmedDirect else { return nil }
        if controller.canConfirmDirectResponse {
            return controller.ownedRouter == nil
                ? "The direct response check is still pending. You can close this idle app after Quit verifies the saved recovery information."
                : "Direct settings are saved. Confirm a working direct response before Stop or Quit."
        }
        return "Recovery context retained. Restore direct, manually restart Codex, and confirm a working direct response before Quit."
    }
    var quitGuidance: String {
        if controller.recoveryContext != nil, controller.desktopConfirmation != .confirmedDirect,
           controller.ownedRouter == nil, controller.canConfirmDirectResponse {
            return "Closing this idle app does not confirm that Codex has reloaded its settings."
        }
        return "After possible routed use, restore direct and confirm a direct response before Stop or Quit. Closing this window keeps the app and owned router running."
    }
    var catalog: String {
        controller.inspection?.catalog.state == "ready" ? "Current local project catalog" : "Catalog unavailable. Refresh to retry."
    }
    func projects(matching search: String) -> [Inspection.Entry] {
        guard controller.inspection?.catalog.state == "ready" else { return [] }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return (controller.inspection?.catalog.entries ?? []).filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || ($0.routeAlias?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    static func refreshInterval(windowVisible: Bool) -> UInt64 { windowVisible ? 2 : 5 }
}

@MainActor struct ControlsView: View {
    let controller: RouterController
    @State private var search = ""
    @State private var showActivationNotice = false
    private var display: ControlsPresentation { ControlsPresentation(controller: controller) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Codex Project Router").font(.title2.bold())
                Spacer()
                if controller.busy { ProgressView().controlSize(.small) }
                Button("Refresh") { Task { await controller.refresh() } }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GroupBox("Setup") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(display.configuration).font(.headline)
                            pathRow("Configuration", controller.selectedConfiguration?.path ?? "No configuration selected")
                            Button("Select existing configuration…") { selectFile(node: false) }.disabled(!controller.canSelectConfiguration)
                            pathRow("Node runtime", controller.selectedNode?.path ?? "Automatic installed Node 24 discovery")
                            Button("Select Node 24 executable…") { selectFile(node: true) }.disabled(!controller.canSelectNode)
                            Text("Configuration stays in place outside Git and the app. Selection never starts or activates the router.").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Independent operational facts") {
                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 7) {
                            fact("Mode", controller.inspection?.configuration.mode == "credential" ? "Credential routing" : controller.inspection?.configuration.mode == "legacy" ? "Legacy routing" : "Unknown")
                            fact("On disk", display.disk)
                            fact("Matching readiness", display.readiness)
                            fact("Process ownership", display.ownership)
                            fact("Desktop confirmation", display.confirmation)
                            if let outcome = controller.lastStopOutcome {
                                fact("Last owned child stop", outcome.childExited ? "Child exited" : "Exit not confirmed")
                                fact("Port after stop", outcome.portState == .empty ? "Empty" : outcome.portState == .occupied ? "Occupied — manual cleanup required" : "Unknown — inspect locally")
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Button("Start router") { Task { await controller.start() } }.disabled(!controller.canStart)
                        Button("Activate for provider…") { showActivationNotice = true }.disabled(!controller.canActivate)
                        Button("Restore direct") { Task { await controller.restoreDirect() } }.disabled(!controller.canRestoreDirect)
                        Button("Stop owned router") { Task { await controller.stop() } }.disabled(!controller.canStop)
                    }
                    GroupBox("Manual desktop restart and response checks") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("After provider changes, restart Codex yourself and send a model request. Only confirm after a working response. Readiness does not prove desktop-loaded settings, gateway acceptance, billing, or complete streaming.").fixedSize(horizontal: false, vertical: true)
                            Button("I restarted Codex and received a routed response") { Task { await controller.confirmRoutedResponse() } }.disabled(!controller.canConfirmRoutedResponse)
                            Button("I restarted Codex and received a direct response") { Task { await controller.confirmDirectResponse() } }.disabled(!controller.canConfirmDirectResponse)
                            Text(display.quitGuidance).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let guidance = display.recoveryGuidance {
                        Text(guidance).foregroundStyle(.orange)
                    }
                    if controller.needsManualListenerCleanup {
                        Text("An external listener requires manual inspection and cleanup. This app cannot adopt or stop it. See the companion recovery instructions.").foregroundStyle(.orange)
                    }
                    if controller.mutationRequiresReconciliation {
                        Text("A provider operation must finish and be reconciled before further controls. Keep the app open and refresh.").foregroundStyle(.orange)
                    }
                    if let context = controller.recoveryContext ?? controller.inspection?.context {
                        DisclosureGroup("Manual recovery and external listener cleanup") {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("If Restore direct cannot run safely, inspect the selected configuration's private activation.json and its named TOML backup locally. Restore only the original base_url for the recorded provider; preserve authentication, models, and unrelated edits. Keep recovery evidence and verify any lock's helper has stopped before manual removal.")
                                pathRow("Recorded provider", context.providerId)
                                pathRow("Recorded provider settings", URL(fileURLWithPath: context.codexHome).appendingPathComponent("config.toml").path)
                                Text("Restart Codex manually and verify a direct response before confirming recovery. For an external listener, inspect the recorded port and independently verify its executable and origin before stopping it yourself. Retain an unverified listener for investigation.")
                                Text("lsof -nP -iTCP:\(context.listenPort) -sTCP:LISTEN").font(.caption.monospaced()).textSelection(.enabled)
                            }.font(.caption).padding(.top, 6)
                        }
                    }
                    if let error = controller.error {
                        Text(error).foregroundStyle(.red).textSelection(.enabled)
                        Text("Refresh to recheck current evidence. For setup errors select an existing private configuration or installed Node 24. Preserve recovery files when recovery is blocked.").font(.caption)
                    }
                    Divider()
                    Text("Projects and route aliases").font(.headline)
                    TextField("Search names or route aliases", text: $search).textFieldStyle(.roundedBorder)
                    Text(display.catalog).font(.caption).foregroundStyle(.secondary)
                    ForEach(display.projects(matching: search), id: \.id) { project in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(project.name.isEmpty ? "Unresolved project" : project.name).fontWeight(.medium)
                                Spacer()
                                Text(project.routeAlias ?? "Unmapped").foregroundStyle(.secondary)
                            }
                            Text(project.id).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                            if project.routeState == "target_missing" { Text("Route target missing").font(.caption).foregroundStyle(.orange) }
                            if project.routeState == "catalog_missing" { Text("Stale mapping — project absent from current catalog").font(.caption).foregroundStyle(.orange) }
                        }.padding(.vertical, 4)
                        Divider()
                    }
                    if display.projects(matching: search).isEmpty && controller.inspection?.catalog.state == "ready" {
                        Text(search.isEmpty ? "No local projects in this catalog." : "No matching projects.").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20).frame(minWidth: 720, minHeight: 640)
        .alert("Activate routing for every chat using this provider?", isPresented: $showActivationNotice) {
            Button("Cancel", role: .cancel) {}
            Button("Activate") { Task { await controller.activate() } }
        } message: {
            Text("This changes the provider-wide setting. Unmapped or unresolved model requests can block. Restart Codex manually afterward and confirm a working routed response. Keep the router running until direct recovery is confirmed.")
        }
    }
    private func pathRow(_ label: String, _ path: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(path).font(.system(.caption, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func fact(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }
    }
    private func selectFile(node: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.title = node ? "Select an installed Node 24 executable" : "Select existing private router configuration"
        if !node { panel.allowedContentTypes = [.json]; panel.allowsOtherFileTypes = true }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                if node { await controller.selectNode(url) } else { await controller.selectConfiguration(url) }
            }
        }
    }
}
