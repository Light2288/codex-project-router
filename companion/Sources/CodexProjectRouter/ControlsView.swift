import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CompanionCore

@MainActor struct ControlsPresentation {
    let controller: RouterController
    var pendingRoutingMode: ProjectRoutingMode? = nil
    var routingState: String {
        if let pendingRoutingMode { return "Switching project routing \(pendingRoutingMode == .on ? "On" : "Off")…" }
        switch controller.projectRoutingStatus {
        case .known(.on): return "On"
        case .known(.off): return "Off"
        case .uncertain: return "Uncertain — refresh to check"
        case .unavailable: return "Unavailable"
        case .notRunning: return "Router not running"
        }
    }
    var routingActionTitle: String? {
        guard pendingRoutingMode == nil else { return nil }
        switch controller.projectRoutingStatus {
        case .known(.on): return "Turn project routing Off"
        case .known(.off): return "Turn project routing On"
        case .notRunning where controller.canStart: return "Start router (routing Off)"
        default: return nil
        }
    }
    var globalAccount: String { "Existing global provider account" }
    func assignment(for project: Inspection.Entry) -> String {
        if let alias = project.routeAlias {
            if controller.inspection?.configuration.mode == "legacy" { return "Global credential; saved alias: \(alias)" }
            if controller.inspection?.configuration.mode == "credential", pendingRoutingMode == nil {
                switch controller.projectRoutingStatus {
                case .known(.on): return "Override active — alias: \(alias)"
                case .known(.off): return "Override saved; inactive while Off — alias: \(alias)"
                default: break
                }
            }
            return "Override saved — alias: \(alias) (routing unconfirmed)"
        }
        if pendingRoutingMode == nil {
            switch controller.projectRoutingStatus {
            case .known(.on): return "Global (inherited)"
            case .known(.off): return "Global (routing Off)"
            default: break
            }
        }
        return "Global (inheritance policy; routing unconfirmed)"
    }
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

struct ControlsDisclosureState {
    var advancedExpanded = false
    var setupExpanded = false
    var recoveryExpanded = false
    mutating func reveal(for destination: QuitGuidance.Destination) {
        advancedExpanded = true
        if destination == .setup { setupExpanded = true }
        if destination == .manualRecovery { recoveryExpanded = true }
    }
}

@MainActor struct ControlsView: View {
    let controller: RouterController
    let navigation: QuitGuidanceNavigation
    @State private var search = ""
    @State private var showActivationNotice = false
    @State private var disclosures = ControlsDisclosureState()
    @State private var pendingRoutingMode: ProjectRoutingMode?
    @State private var lastNavigatedRequestID: UUID?
    @FocusState private var focusedGuidance: QuitGuidance.Destination?
    @AccessibilityFocusState private var accessibilityGuidance: QuitGuidance.Destination?
    private var display: ControlsPresentation { ControlsPresentation(controller: controller, pendingRoutingMode: pendingRoutingMode) }
    private var guidance: QuitGuidance? {
        navigation.requestID == nil ? nil : QuitGuidance.current(for: controller)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Codex Project Router").font(.title2.bold())
                Spacer()
                if controller.busy { ProgressView().controlSize(.small) }
                Button("Refresh") { Task { await controller.refresh() } }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        routingSection
                        Text("Projects").font(.headline)
                        TextField("Search names or route aliases", text: $search).textFieldStyle(.roundedBorder)
                        Text(display.catalog).font(.caption).foregroundStyle(.secondary)
                        ForEach(display.projects(matching: search), id: \.id) { project in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(project.name.isEmpty ? "Unresolved project" : project.name).fontWeight(.medium)
                                    Spacer()
                                }
                                Text(display.assignment(for: project)).foregroundStyle(.secondary)
                                Text(project.id).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                                if project.routeState == "target_missing" { Text("Route target missing").font(.caption).foregroundStyle(.orange) }
                                if project.routeState == "catalog_missing" { Text("Stale mapping — project absent from current catalog").font(.caption).foregroundStyle(.orange) }
                            }.padding(.vertical, 4)
                            Divider()
                        }
                        if display.projects(matching: search).isEmpty && controller.inspection?.catalog.state == "ready" {
                            Text(search.isEmpty ? "No local projects in this catalog." : "No matching projects.").foregroundStyle(.secondary)
                        }
                        Divider()
                        DisclosureGroup("Advanced", isExpanded: $disclosures.advancedExpanded) {
                            advancedContents.padding(.top, 8)
                        }
                    }
                }
                .task(id: navigation.requestID) { await navigateGuidance(using: proxy) }
                .onChange(of: guidance?.destination) { _, destination in
                    if let destination { disclosures.reveal(for: destination) }
                }
                .onAppear { revealRequiredPanels() }
                .onChange(of: controller.inspection?.configuration.state) { _, _ in revealRequiredPanels() }
                .onChange(of: controller.error) { _, _ in revealRequiredPanels() }
                .onChange(of: controller.desktopConfirmation) { _, _ in revealRequiredPanels() }
                .onChange(of: controller.recoveryContext) { _, _ in revealRequiredPanels() }
                .onChange(of: controller.needsManualListenerCleanup) { _, _ in revealRequiredPanels() }
                .onChange(of: controller.mutationRequiresReconciliation) { _, _ in revealRequiredPanels() }
            }
        }
        .padding(20).frame(minWidth: 720, minHeight: 640)
        .alert("Activate routing for every chat using this provider?", isPresented: $showActivationNotice) {
            Button("Cancel", role: .cancel) {}
            Button("Activate") { Task { await controller.activate() } }
        } message: {
            Text("This changes the provider-wide setting. Identified projects without an override inherit the existing global provider account; unresolved project identity may block a request. Restart Codex manually after this initial activation and confirm a working routed response. The listener is still required while project routing is Off. Keep it running until direct recovery is confirmed.")
        }
    }
    private var routingSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Project routing").font(.title2.bold())
                    Spacer()
                    if pendingRoutingMode != nil { ProgressView().controlSize(.small) }
                    Text(display.routingState).font(.headline)
                }
                if let title = display.routingActionTitle {
                    Button(title) {
                        if controller.ownedRouter == nil {
                            Task { await controller.start() }
                        } else if case .known(let mode) = controller.projectRoutingStatus {
                            let target: ProjectRoutingMode = mode == .on ? .off : .on
                            pendingRoutingMode = target
                            Task {
                                await controller.setProjectRouting(target)
                                pendingRoutingMode = nil
                            }
                        }
                    }
                    .disabled(controller.ownedRouter == nil ? !controller.canStart : !controller.canSetProjectRouting)
                }
                Text(display.globalAccount).font(.headline)
                if controller.inspection?.configuration.mode == "legacy" {
                    Text("Uses the caller's existing credential; aliases do not select separate accounts.")
                }
                Text("Off suspends project overrides. Codex still uses the router listener until direct settings are restored and verified.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = controller.routingModeError {
                    Text(error).foregroundStyle(.orange)
                    Text("Refresh to check routing mode before changing it again.").font(.caption)
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
                if let error = controller.error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                    Text("Refresh to recheck current evidence. For setup errors select an existing private configuration or installed Node 24. Preserve recovery files when recovery is blocked.").font(.caption)
                }
                if display.recoveryGuidance != nil || controller.needsManualListenerCleanup || controller.mutationRequiresReconciliation {
                    Button("Show recovery controls") {
                        let request = navigation.beginRequest()
                        navigation.present(request)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var advancedContents: some View {
        VStack(alignment: .leading, spacing: 14) {
            DisclosureGroup("Setup", isExpanded: $disclosures.setupExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(display.configuration).font(.headline)
                    pathRow("Configuration", controller.selectedConfiguration?.path ?? "No configuration selected")
                    Button("Select existing configuration…") { selectFile(node: false) }.disabled(!controller.canSelectConfiguration)
                    pathRow("Node runtime", controller.selectedNode?.path ?? "Automatic installed Node 24 discovery")
                    Button("Select Node 24 executable…") { selectFile(node: true) }.disabled(!controller.canSelectNode)
                    Text("Configuration stays in place outside Git and the app. Selection never starts or activates the router.").font(.caption).foregroundStyle(.secondary)
                    guidanceText(for: .setup)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay { guidanceOutline(for: .setup) }
            .id(QuitGuidance.Destination.setup)
            GroupBox("Independent operational facts") {
                VStack(alignment: .leading, spacing: 8) {
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 7) {
                        fact("Configuration kind", controller.inspection?.configuration.mode == "credential" ? "Credential routing" : controller.inspection?.configuration.mode == "legacy" ? "Legacy routing" : "Unknown")
                        fact("On disk", display.disk)
                        fact("Matching readiness", display.readiness)
                        fact("Process ownership", display.ownership)
                        fact("Desktop confirmation", display.confirmation)
                        if let outcome = controller.lastStopOutcome {
                            fact("Last owned child stop", outcome.childExited ? "Child exited" : "Exit not confirmed")
                            fact("Port after stop", outcome.portState == .empty ? "Empty" : outcome.portState == .occupied ? "Occupied — manual cleanup required" : "Unknown — inspect locally")
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    guidanceText(for: .status)
                }
            }
            .overlay { guidanceOutline(for: .status) }
            .id(QuitGuidance.Destination.status)
            VStack(alignment: .leading, spacing: 8) {
                if !controller.canStart {
                    Button("Start router (routing Off)") { Task { await controller.start() } }.disabled(!controller.canStart)
                }
                Button("Activate for provider…") { showActivationNotice = true }.disabled(!controller.canActivate)
                Button("Restore direct") { Task { await controller.restoreDirect() } }.disabled(!controller.canRestoreDirect)
                    .overlay { guidanceOutline(for: .restoreDirect) }
                    .id(QuitGuidance.Destination.restoreDirect)
                Button("Stop owned router") { Task { await controller.stop() } }.disabled(!controller.canStop)
                    .overlay { guidanceOutline(for: .stopRouter) }
                    .id(QuitGuidance.Destination.stopRouter)
            }
            guidanceText(for: .restoreDirect)
            guidanceText(for: .stopRouter)
            GroupBox("Manual desktop restart and response checks") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("After provider changes, restart Codex yourself and send a model request. Only confirm after a working response. Readiness does not prove desktop-loaded settings, gateway acceptance, billing, or complete streaming.").fixedSize(horizontal: false, vertical: true)
                    Button("I restarted Codex and received a routed response") { Task { await controller.confirmRoutedResponse() } }.disabled(!controller.canConfirmRoutedResponse)
                    guidanceText(for: .directResponse)
                    Button("I restarted Codex and received a direct response") { Task { await controller.confirmDirectResponse() } }.disabled(!controller.canConfirmDirectResponse)
                        .overlay { guidanceOutline(for: .directResponse) }
                    Text(display.quitGuidance).font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(QuitGuidance.Destination.directResponse)
            if let context = controller.recoveryContext ?? controller.inspection?.context {
                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup("Manual recovery and external listener cleanup", isExpanded: $disclosures.recoveryExpanded) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("If Restore direct cannot run safely, inspect the selected configuration's private activation.json and its named TOML backup locally. Restore only the original base_url for the recorded provider; preserve authentication, models, and unrelated edits. Keep recovery evidence and verify any lock's helper has stopped before manual removal.")
                            pathRow("Recorded provider", context.providerId)
                            pathRow("Recorded provider settings", URL(fileURLWithPath: context.codexHome).appendingPathComponent("config.toml").path)
                            Text("Restart Codex manually and verify a direct response before confirming recovery. For an external listener, inspect the recorded port and independently verify its executable and origin before stopping it yourself. Retain an unverified listener for investigation.")
                            Text("lsof -nP -iTCP:\(context.listenPort) -sTCP:LISTEN").font(.caption.monospaced()).textSelection(.enabled)
                        }.font(.caption).padding(.top, 6)
                    }
                    guidanceText(for: .manualRecovery)
                }
                .overlay { guidanceOutline(for: .manualRecovery) }
                .id(QuitGuidance.Destination.manualRecovery)
            }
        }
    }
    private func revealRequiredPanels() {
        if let configuration = controller.inspection?.configuration.state, configuration != "valid" {
            disclosures.reveal(for: .setup)
        }
        if controller.error != nil || controller.mutationRequiresReconciliation || display.recoveryGuidance != nil ||
            controller.desktopConfirmation == .routedPending || controller.desktopConfirmation == .directPending {
            disclosures.advancedExpanded = true
        }
        if controller.needsManualListenerCleanup {
            disclosures.reveal(for: .manualRecovery)
        }
    }
    @ViewBuilder private func guidanceText(for destination: QuitGuidance.Destination) -> some View {
        if let guidance, guidance.destination == destination {
            Text(guidance.text)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(6)
                .focusable()
                .focused($focusedGuidance, equals: destination)
                .accessibilityFocused($accessibilityGuidance, equals: destination)
        }
    }
    @ViewBuilder private func guidanceOutline(for destination: QuitGuidance.Destination) -> some View {
        if guidance?.destination == destination {
            RoundedRectangle(cornerRadius: 6).stroke(Color.primary, lineWidth: 2)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
    private func navigateGuidance(using proxy: ScrollViewProxy) async {
        guard let request = navigation.requestID, request != lastNavigatedRequestID else { return }
        lastNavigatedRequestID = request
        if let destination = guidance?.destination { disclosures.reveal(for: destination) }
        // Let the inline guidance and disclosure participate in layout before locating the current target.
        await Task.yield()
        guard !Task.isCancelled, navigation.requestID == request else { return }
        if let destination = guidance?.destination {
            disclosures.reveal(for: destination)
            await Task.yield()
        }
        guard !Task.isCancelled, navigation.requestID == request, let destination = guidance?.destination else { return }
        proxy.scrollTo(destination, anchor: .center)
        focusedGuidance = destination
        accessibilityGuidance = destination
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
