import XCTest
import AppKit
import SwiftUI
import CompanionCore
@testable import CodexProjectRouter

@MainActor final class ControlsPresentationTests: XCTestCase {
    func testActivationAlertCopiesAndKeepsCancelAndDefaultActions() async throws {
        try await withPendingDirectController { controller, backend, _ in
            backend.routingError = nil
            await controller.start()
            let host = NativeProjectHost(ControlsView(controller: controller, navigation: QuitGuidanceNavigation()))
            let clipboard = NativeClipboard()
            defer {
                for sheet in host.window.sheets { host.window.endSheet(sheet, returnCode: .cancel) }
                clipboard.restore(); host.close()
            }
            await host.settle()
            let heading = "Activate routing for every chat using this provider?"
            try host.press(title: "Activate for provider…", in: host.window)
            let alert = try await host.dialog(containing: heading)
            try host.selectText(heading, range: NSRange(location: 0, length: heading.utf16.count), in: alert)
            XCTAssertEqual(try host.copySelection(in: alert), heading)
            let message = "This changes the provider-wide setting. Identified projects without an override inherit the configured default account; unresolved project identity may block a request. Restart Codex manually after this initial activation and confirm a working routed response. The listener is still required while project routing is Off. Keep it running until direct recovery is confirmed."
            try host.selectText(message, range: NSRange(location: 0, length: message.utf16.count), in: alert)
            XCTAssertEqual(try host.copySelection(in: alert), message)
            XCTAssertEqual(backend.controlCount, 0)
            try host.snapshot("activation-selected-message", in: alert)
            try host.pressKey("\u{1b}", keyCode: 53, in: alert)
            await host.settle()
            XCTAssertEqual(backend.controlCount, 0)
            try host.press(title: "Activate for provider…", in: host.window)
            let again = try await host.dialog(containing: heading)
            try host.selectText(heading, range: NSRange(location: 0, length: heading.utf16.count), in: again)
            try host.pressKey("\r", keyCode: 36, in: again)
            for _ in 0..<30 where controller.busy || backend.controlCount == 0 { await host.settle() }
            XCTAssertEqual(backend.controlCount, 1)
        }
    }

    func testInformationalTextCopiesWithoutChangingRecoveryAndSurvivesRefresh() async throws {
        try await withPendingDirectController { controller, backend, store in
            let host = NativeProjectHost(ControlsView(controller: controller, navigation: QuitGuidanceNavigation()))
            let clipboard = NativeClipboard()
            defer { clipboard.restore(); host.close() }
            await host.settle()
            let journal = try store.load()
            try host.selectText("Project routing", range: NSRange(location: 0, length: 15))
            XCTAssertEqual(try host.copySelection(), "Project routing")
            try host.selectText("No default account designated", range: NSRange(location: 3, length: 7))
            XCTAssertEqual(try host.copySelection(), "default")
            await controller.refresh()
            await host.settle()
            XCTAssertEqual(try host.copySelection(), "default")
            XCTAssertEqual(try store.load(), journal)
            XCTAssertEqual(backend.startCount, 0)
            XCTAssertEqual(backend.controlCount, 0)
            XCTAssertFalse(controller.quitRequested)
            try host.snapshot("selectable-controls", width: 800, height: 820)
        }
    }

    private func withController(_ body: (RouterController, DisplayBackend) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("app presentation \(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = DisplayBackend()
        let controller = RouterController(backend: backend, store: PrivateStore(directory: root.appendingPathComponent("companion")), browseHome: root)
        try await body(controller, backend)
    }
    private func withPendingDirectController(_ body: (RouterController, DisplayBackend, PrivateStore) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pending presentation \(UUID())")
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { XCTFail("Pending presentation fixture cleanup failed: \(error)") }
        }
        let context = ActivationContext(configPath: "/synthetic/presentation/config.json", codexHome: "/synthetic/presentation/codex", providerId: "synthetic_provider", listenPort: 43129)
        let store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath,
            pending: .init(context: context, phase: .directConfirmation)))
        let backend = DisplayBackend()
        backend.snapshot = Inspection(configuration: .init(state: "valid", path: context.configPath, mode: "accounts", setupState: "ready"),
            context: context, revision: "synthetic-presentation-revision",
            provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "restored"),
            catalog: .init(state: "ready", entries: []))
        let controller = RouterController(backend: backend, store: store, browseHome: root)
        await controller.refresh()
        try await body(controller, backend, store)
    }
    func testRoutingPresentationDistinguishesKnownPendingAndUnavailable() async throws {
        // Unknown or pending evidence must never become a usable On/Off action or desktop confirmation.
        try await withPendingDirectController { controller, backend, _ in
            XCTAssertEqual(ControlsPresentation(controller: controller).routingState, "Router not running")
            XCTAssertEqual(ControlsPresentation(controller: controller).routingActionTitle, "Start router (routing Off)")
            backend.routingError = nil
            await controller.start()
            var display = ControlsPresentation(controller: controller)
            XCTAssertEqual(display.routingState, "Off")
            XCTAssertEqual(display.routingActionTitle, "Turn project routing On")
            XCTAssertEqual(display.confirmation, "Not confirmed")
            await controller.setProjectRouting(.on)
            display = ControlsPresentation(controller: controller)
            XCTAssertEqual(display.routingState, "On")
            XCTAssertEqual(display.routingActionTitle, "Turn project routing Off")
            let barrier = DisplayModeBarrier()
            backend.modeBarrier = barrier
            let switching = Task { await controller.setProjectRouting(.off) }
            await barrier.waitUntilStarted()
            display = ControlsPresentation(controller: controller, pendingRoutingMode: .off)
            XCTAssertEqual(display.routingState, "Switching project routing Off…")
            XCTAssertNil(display.routingActionTitle)
            XCTAssertFalse(controller.canSetProjectRouting)
            barrier.release()
            await switching.value
            for (error, state) in [(CompanionError.routingModeUnavailable, "Unavailable"), (.routingModeUncertain, "Uncertain — refresh to check")] {
                backend.routingError = error
                await controller.refresh()
                display = ControlsPresentation(controller: controller)
                XCTAssertEqual(display.routingState, state)
                XCTAssertNil(display.routingActionTitle)
                XCTAssertEqual(display.globalAccount, "No default account designated")
                XCTAssertEqual(display.confirmation, "Not confirmed")
            }
        }
        try await withController { controller, backend in
            backend.snapshot.provider.proxyReady = true
            await controller.refresh()
            XCTAssertEqual(ControlsPresentation(controller: controller).routingState, "Unavailable")
            XCTAssertNil(ControlsPresentation(controller: controller).routingActionTitle)
            XCTAssertFalse(controller.canSetProjectRouting)
        }
    }
    func testAccountPresentationPreservesQuitGuidance() async throws {
        // Account names and inherited labels must coexist with all existing recovery destinations.
        try await withPendingDirectController { controller, backend, _ in
            backend.snapshot.configuration.defaultAccount = .init(id: "default", displayName: "Personal")
            await controller.refresh()
            let before = QuitGuidance.current(for: controller)
            let display = ControlsPresentation(controller: controller)
            XCTAssertEqual(display.globalAccount, "Default account: Personal")
            XCTAssertEqual(QuitGuidance.current(for: controller), before)
            XCTAssertNil(controller.ownedRouter)
            XCTAssertEqual(backend.startCount, 0); XCTAssertEqual(backend.controlCount, 0)
        }
    }
    // Dropping controller mode evidence from the flat view hides whether saved overrides are suspended.
    func testFlatBrowsingPreservesModeAwareRowsWithoutAccountInference() async throws {
        for mode: String? in ["legacy", "credential", nil] {
            try await withPendingDirectController { controller, backend, _ in
                backend.snapshot.configuration.mode = mode
                if mode == nil { backend.snapshot.configuration.state = "missing" }
                backend.snapshot.configuration.defaultAccount = .init(id: "saved-account", displayName: "Private saved account")
                backend.snapshot.catalog.entries = [
                    .init(id: "global", name: "Global project", routeAlias: nil, routeState: "unmapped"),
                    .init(id: "override", name: "Override project", routeAlias: "technical-alias", routeState: "mapped",
                          account: .init(id: "target", displayName: "Private target account"))
                ]
                await controller.refresh()
                let host = NativeProjectHost(ScrollView {
                    ProjectListView(controller: controller, editingProjectID: nil, canOpenEditor: true) { _ in }.padding(20)
                })
                defer { host.close() }
                @MainActor func check(global: String, override: String, routing: String) async throws {
                    await host.settle()
                    XCTAssertTrue(host.text.contains(global), "mode=\(mode ?? "absent"): \(host.text)")
                    XCTAssertTrue(host.text.contains(override))
                    XCTAssertNotNil(host.find("project-details-global"))
                    XCTAssertNotNil(host.find("project-details-override"))
                    XCTAssertFalse(host.text.contains("technical-alias"))
                    try host.press("project-details-global")
                    try host.press("project-details-override")
                    await host.settle()
                    XCTAssertTrue(host.text.contains("Project routing: \(routing)"))
                    XCTAssertTrue(host.text.contains("Route alias: technical-alias"))
                    XCTAssertTrue(host.text.contains("Running assignment unconfirmed."))
                    XCTAssertFalse(host.text.contains("Saved and running assignments match."))
                    XCTAssertFalse(host.text.contains("Private saved account"))
                    XCTAssertFalse(host.text.contains("Private target account"))
                    try host.press("project-details-global")
                    try host.press("project-details-override")
                }
                let unknownOverride = mode == "legacy" ? "Global credential; saved label retained" : "Override saved (routing unconfirmed)"
                try await check(global: "Global (inheritance policy; routing unconfirmed)", override: unknownOverride, routing: "Router not running")
                if mode == nil { XCTAssertFalse(controller.canStart) }
                backend.snapshot.configuration.state = "valid"
                await controller.refresh()
                backend.routingError = nil
                await controller.start()
                XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
                let offOverride = mode == "credential" ? "Override saved; inactive while Off" : unknownOverride
                try await check(global: "Global (routing Off)", override: offOverride, routing: "Off")
                await controller.setProjectRouting(.on)
                XCTAssertEqual(controller.projectRoutingStatus, .known(.on))
                let onOverride = mode == "credential" ? "Override saved (running assignment unconfirmed)" : unknownOverride
                try await check(global: "Global (inherited)", override: onOverride, routing: "On")
                for (error, status, routing) in [
                    (CompanionError.routingModeUncertain, RouterController.ProjectRoutingStatus.uncertain, "Uncertain — refresh to check"),
                    (.routingModeUnavailable, .unavailable, "Unavailable")
                ] {
                    backend.routingError = error
                    await controller.refresh()
                    XCTAssertEqual(controller.projectRoutingStatus, status)
                    try await check(global: "Global (inheritance policy; routing unconfirmed)", override: unknownOverride, routing: routing)
                }
                XCTAssertEqual(backend.controlCount, 0)
                XCTAssertEqual(backend.modeSetCount, 1)
            }
        }
    }
    // Only ControlsView owns pending mode: the real button must invalidate stale row labels during its await.
    func testFlatRowsUseParentPendingModeUntilControlCompletes() async throws {
        try await withPendingDirectController { controller, backend, _ in
            backend.snapshot.configuration.mode = "credential"
            backend.snapshot.catalog.entries = [
                .init(id: "global", name: "Global project", routeAlias: nil, routeState: "unmapped"),
                .init(id: "override", name: "Override project", routeAlias: "technical-alias", routeState: "mapped")
            ]
            backend.routingError = nil
            await controller.refresh()
            await controller.start()
            let host = NativeProjectHost(ControlsView(controller: controller, navigation: QuitGuidanceNavigation()))
            defer { host.close() }
            await host.settle()
            try host.press("project-details-global")
            try host.press("project-details-override")
            for (target, oldLabel, newLabel) in [
                (ProjectRoutingMode.on, "Global (routing Off)", "Global (inherited)"),
                (.off, "Global (inherited)", "Global (routing Off)")
            ] {
                let barrier = DisplayModeBarrier()
                backend.modeBarrier = barrier
                let word = target == .on ? "On" : "Off"
                try host.press(title: "Turn project routing \(word)", in: host.window)
                await barrier.waitUntilStarted()
                await host.settle()
                XCTAssertTrue(host.text.contains("Global (inheritance policy; routing unconfirmed)"))
                XCTAssertTrue(host.text.contains("Override saved (routing unconfirmed)"))
                XCTAssertTrue(host.text.contains("Project routing: Switching project routing \(word)…"))
                XCTAssertFalse(host.text.contains(oldLabel))
                XCTAssertFalse(host.text.contains("Saved and running assignments match."))
                barrier.release()
                for _ in 0..<20 where controller.busy { await host.settle() }
                await host.settle()
                XCTAssertFalse(controller.busy)
                XCTAssertTrue(host.text.contains(newLabel))
                XCTAssertFalse(host.text.contains("Project routing: Switching"))
            }
            XCTAssertEqual(backend.modeSetCount, 2)
            XCTAssertEqual(backend.controlCount, 0)
        }
    }
    func testOriginalConnectionGuidanceOnlyAppearsForAccounts() async throws {
        // Routing status cannot grant or hide policy guidance for an inspected account configuration.
        try await withPendingDirectController { controller, backend, _ in
            let expected = "Chats outside projects use the original Codex connection in On and Off. Model lists and permitted automatic titles use it too."
            XCTAssertEqual(controller.projectRoutingStatus, .notRunning)
            XCTAssertEqual(ControlsPresentation(controller: controller).originalConnectionGuidance, expected)
            backend.routingError = nil
            await controller.start()
            XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
            XCTAssertEqual(ControlsPresentation(controller: controller).originalConnectionGuidance, expected)
            await controller.setProjectRouting(.on)
            XCTAssertEqual(controller.projectRoutingStatus, .known(.on))
            XCTAssertEqual(ControlsPresentation(controller: controller).originalConnectionGuidance, expected)
            backend.routingError = CompanionError.routingModeUnavailable
            await controller.refresh()
            XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
            XCTAssertEqual(ControlsPresentation(controller: controller).originalConnectionGuidance, expected)
            for mode: String? in ["legacy", "credential", nil] {
                backend.snapshot.configuration.mode = mode
                await controller.refresh()
                XCTAssertNil(ControlsPresentation(controller: controller).originalConnectionGuidance)
            }
        }
        try await withController { controller, _ in
            XCTAssertNil(ControlsPresentation(controller: controller).originalConnectionGuidance)
        }
    }
    func testOriginalConnectionGuidanceDoesNotImplyReadinessOrChangeRecovery() async throws {
        // Explanatory copy cannot promote retained recovery evidence into response or control authority.
        try await withPendingDirectController { controller, backend, store in
            backend.snapshot.configuration.defaultAccount = .init(id: "default", displayName: "Personal")
            await controller.refresh()
            let journal = try store.load()
            let quitGuidance = QuitGuidance.current(for: controller)
            let inspections = backend.inspectCount
            let display = ControlsPresentation(controller: controller)
            XCTAssertEqual(display.originalConnectionGuidance, "Chats outside projects use the original Codex connection in On and Off. Model lists and permitted automatic titles use it too.")
            XCTAssertEqual(display.globalAccount, "Default account: Personal")
            XCTAssertEqual(display.readiness, "No matching listener ready")
            XCTAssertEqual(display.ownership, "No owned router")
            XCTAssertEqual(display.confirmation, "Not confirmed")
            XCTAssertEqual(display.recoveryGuidance, "The direct response check is still pending. You can close this idle app after Quit verifies the saved recovery information.")
            XCTAssertEqual(display.quitGuidance, "Closing this idle app does not confirm that Codex has reloaded its settings.")
            XCTAssertNil(controller.error)
            XCTAssertNil(controller.routingModeError)
            XCTAssertTrue(controller.canStart)
            XCTAssertTrue(controller.canConfirmDirectResponse)
            XCTAssertFalse(controller.canSetProjectRouting)
            XCTAssertFalse(controller.canConfirmRoutedResponse)
            XCTAssertFalse(controller.canStop)
            XCTAssertFalse(controller.canQuit)
            XCTAssertEqual(QuitGuidance.current(for: controller), quitGuidance)
            XCTAssertEqual(try store.load(), journal)
            XCTAssertEqual(backend.inspectCount, inspections)
            XCTAssertEqual(backend.startCount, 0)
            XCTAssertEqual(backend.controlCount, 0)
            XCTAssertEqual(backend.modeSetCount, 0)
            XCTAssertEqual(backend.stopCount, 0)
        }
    }
    func testIdlePendingGuidanceDoesNotDemandConfirmationToQuit() async throws {
        // Removing the idle branch or treating display as fresh exit authority must fail.
        try await withPendingDirectController { controller, backend, store in
            let journalBefore = try store.load()
            let stateURL = store.directory.appendingPathComponent("state.json")
            let bytesBefore = try Data(contentsOf: stateURL)
            let modifiedBefore = try FileManager.default.attributesOfItem(atPath: stateURL.path)[.modificationDate] as? Date
            let inspectionsBefore = backend.inspectCount
            XCTAssertTrue(controller.canConfirmDirectResponse)
            XCTAssertNil(controller.ownedRouter)
            XCTAssertEqual(controller.desktopConfirmation, .unknown)
            XCTAssertNotNil(journalBefore.pending)
            for _ in 0..<3 {
                let display = ControlsPresentation(controller: controller)
                XCTAssertEqual(display.recoveryGuidance, "The direct response check is still pending. You can close this idle app after Quit verifies the saved recovery information.")
                XCTAssertEqual(display.quitGuidance, "Closing this idle app does not confirm that Codex has reloaded its settings.")
                XCTAssertEqual(display.confirmation, "Not confirmed")
            }
            XCTAssertFalse(controller.canQuit)
            XCTAssertFalse(controller.quitRequested)
            XCTAssertEqual(controller.desktopConfirmation, .unknown)
            XCTAssertEqual(controller.recoveryContext, journalBefore.pending?.context)
            XCTAssertEqual(try store.load(), journalBefore)
            XCTAssertEqual(try Data(contentsOf: stateURL), bytesBefore)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: stateURL.path)[.modificationDate] as? Date, modifiedBefore)
            XCTAssertEqual(backend.inspectCount, inspectionsBefore)
            XCTAssertEqual(backend.startCount, 0)
            XCTAssertEqual(backend.controlCount, 0)
            XCTAssertEqual(backend.stopCount, 0)
        }
    }
    func testOwnedPendingGuidanceRetainsShutdownCheck() async throws {
        // Applying the idle wording to an owned listener would hide its required response check.
        try await withPendingDirectController { controller, backend, store in
            await controller.start()
            XCTAssertNotNil(controller.ownedRouter)
            XCTAssertTrue(controller.canConfirmDirectResponse)
            let journalBefore = try store.load()
            let inspectionsBefore = backend.inspectCount
            let display = ControlsPresentation(controller: controller)
            XCTAssertEqual(display.recoveryGuidance, "Direct settings are saved. Confirm a working direct response before Stop or Quit.")
            XCTAssertEqual(display.quitGuidance, "After possible routed use, restore direct and confirm a direct response before Stop or Quit. Closing this window keeps the app and owned router running.")
            XCTAssertFalse(controller.canStop)
            XCTAssertFalse(controller.quitRequested)
            XCTAssertEqual(controller.desktopConfirmation, .unknown)
            XCTAssertEqual(try store.load(), journalBefore)
            XCTAssertEqual(backend.inspectCount, inspectionsBefore)
            XCTAssertEqual(backend.startCount, 1)
            XCTAssertEqual(backend.controlCount, 0)
            XCTAssertEqual(backend.stopCount, 0)
        }
    }
    func testUncertainRecoveryRetainsGuardedGuidance() async throws {
        // Cached Direct state cannot show idle guidance while live mutation evidence is uncertain.
        try await withPendingDirectController { controller, backend, _ in
            backend.mutationRequiresReconciliation = true
            let display = ControlsPresentation(controller: controller)
            XCTAssertEqual(display.recoveryGuidance, "Recovery context retained. Restore direct, manually restart Codex, and confirm a working direct response before Quit.")
            XCTAssertEqual(display.quitGuidance, "After possible routed use, restore direct and confirm a direct response before Stop or Quit. Closing this window keeps the app and owned router running.")
        }
    }
    func testAbsentAndConfirmedRecoveryOmitRecoveryGuidance() async throws {
        // A cleared recovery obligation must not leave an orange warning behind.
        try await withController { controller, _ in
            await controller.refresh()
            XCTAssertNil(ControlsPresentation(controller: controller).recoveryGuidance)
        }
        try await withPendingDirectController { controller, _, store in
            await controller.confirmDirectResponse()
            XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
            XCTAssertNil(try store.load().pending)
            XCTAssertNil(ControlsPresentation(controller: controller).recoveryGuidance)
        }
    }
    func testSetupAllowsSelectionAndReadableProjectsWithoutInventingOperationalFacts() async throws {
        try await withController { controller, backend in
            await controller.refresh()
            let display = ControlsPresentation(controller: controller)
            XCTAssertEqual(display.configuration, "Setup required")
            XCTAssertEqual(display.disk, "Unavailable")
            XCTAssertEqual(display.readiness, "Unknown")
            XCTAssertEqual(display.ownership, "No owned router")
            XCTAssertEqual(display.confirmation, "Not confirmed")
            XCTAssertTrue(controller.canSelectConfiguration)
            XCTAssertFalse(controller.canStart)
            backend.snapshot.configuration.state = "invalid"
            backend.snapshot.provider.proxyReady = true
            await controller.refresh()
            let invalid = ControlsPresentation(controller: controller)
            XCTAssertEqual(invalid.ownership, "External listener; never owned")
            XCTAssertEqual(invalid.readiness, "Matching listener ready")
            XCTAssertFalse(controller.canStop)
            XCTAssertFalse(controller.canActivate)
            XCTAssertFalse(controller.canConfirmRoutedResponse)
            XCTAssertFalse(controller.canConfirmDirectResponse)
        }
    }
    // Parent integration must retain the list instance through discovery and preserve routing/recovery controls.
    func testControlsRetainProjectSearchAcrossUnavailableDiscovery() async throws {
        try await withProjectListFixture { controller, backend in
            backend.snapshot.catalog.entries = [ProjectListLayoutTests.entry(1, "Synthetic retained project")]
            await controller.refresh()
            let host = NativeProjectHost(ControlsView(controller: controller, navigation: QuitGuidanceNavigation()))
            defer { host.close() }
            await host.settle()
            XCTAssertTrue(host.text.contains("Project routing"))
            XCTAssertTrue(host.text.contains("Advanced"))
            try host.search("retained"); await host.settle()
            backend.snapshot.catalog.state = "unavailable"
            await controller.refresh(); await host.settle()
            XCTAssertTrue(host.text.contains("Catalog unavailable. Refresh to retry."))
            XCTAssertNil(host.find("project-edit-\(ProjectListLayoutTests.id(1))"))
            XCTAssertEqual(host.find("project-search")?.accessibilityValue() as? String, "retained")
            backend.snapshot.catalog.state = "ready"
            await controller.refresh(); await host.settle()
            XCTAssertNotNil(host.find("project-edit-\(ProjectListLayoutTests.id(1))"))
            XCTAssertEqual(host.find("project-search")?.accessibilityValue() as? String, "retained")
            XCTAssertTrue(backend.changes.isEmpty)
            XCTAssertEqual(backend.starts, 0)
            try host.snapshot("controls-minimum-window")
        }
    }
    func testControlsOpenCloseAndReopenPreserveBackgroundRouting() async throws {
        // Closing presentation must neither lose the owned listener nor change its routing selection.
        try await withPendingDirectController { controller, backend, store in
            backend.routingError = nil
            await controller.start()
            let childID = try XCTUnwrap(controller.ownedRouter).id
            let journal = try Data(contentsOf: store.directory.appendingPathComponent("state.json"))
            var policies: [NSApplication.ActivationPolicy] = []
            let delegate = RouterAppDelegate(controller: controller, setActivationPolicy: { policies.append($0); return true })
            defer {
                delegate.controlsWindow?.close()
                delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            let window = try XCTUnwrap(delegate.controlsWindow)
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(policies.last, .regular)
            window.performClose(nil)
            XCTAssertFalse(window.isVisible)
            XCTAssertEqual(policies.last, .accessory)
            for _ in 0..<2 {
                XCTAssertTrue(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
                XCTAssertTrue(delegate.controlsWindow === window)
                XCTAssertTrue(window.isVisible)
                XCTAssertEqual(policies.last, .regular)
                window.performClose(nil)
                XCTAssertEqual(policies.last, .accessory)
            }
            await controller.refreshAndWait()
            XCTAssertEqual(policies, [.regular, .accessory, .regular, .accessory, .regular, .accessory])
            XCTAssertEqual(controller.ownedRouter?.id, childID)
            XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
            XCTAssertEqual(backend.startCount, 1)
            XCTAssertEqual(backend.controlCount, 0)
            XCTAssertEqual(backend.stopCount, 0)
            XCTAssertEqual(backend.modeSetCount, 0)
            XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), journal)
            XCTAssertFalse(controller.quitRequested)
            XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
        }
    }
    func testUnrelatedCloseDoesNotDemoteControls() async throws {
        // A sheet or another window must not remove the real controls from the Dock or invalidate guidance.
        try await withController { controller, _ in
            let navigation = QuitGuidanceNavigation()
            var policies: [NSApplication.ActivationPolicy] = []
            let delegate = RouterAppDelegate(controller: controller, navigation: navigation,
                setActivationPolicy: { policies.append($0); return true })
            defer {
                delegate.controlsWindow?.close()
                delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
            delegate.openControls()
            let token = navigation.beginRequest(); navigation.present(token)
            let requestID = try XCTUnwrap(navigation.requestID)
            let unrelatedObjects: [Any?] = [nil, "malformed", NSWindow()]
            for object in unrelatedObjects {
                delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: object))
            }
            XCTAssertEqual(policies, [.regular])
            XCTAssertEqual(navigation.requestID, requestID)
            XCTAssertTrue(try XCTUnwrap(delegate.controlsWindow).isVisible)
            await controller.refreshAndWait()
        }
    }
    func testMinimizingControlsPreservesRegularPresence() async throws {
        // A minimized window stays open and must remain discoverable through the Dock.
        try await withController { controller, _ in
            var policies: [NSApplication.ActivationPolicy] = []
            let delegate = RouterAppDelegate(controller: controller, setActivationPolicy: { policies.append($0); return true })
            defer {
                delegate.controlsWindow?.close()
                delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
            delegate.openControls()
            let window = try XCTUnwrap(delegate.controlsWindow)
            window.miniaturize(nil)
            delegate.windowDidMiniaturize(Notification(name: NSWindow.didMiniaturizeNotification, object: window))
            XCTAssertEqual(policies, [.regular])
            delegate.openControls()
            delegate.windowDidDeminiaturize(Notification(name: NSWindow.didDeminiaturizeNotification, object: window))
            XCTAssertTrue(delegate.controlsWindow === window)
            XCTAssertFalse(window.isMiniaturized)
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(policies, [.regular, .regular])
            await controller.refreshAndWait()
        }
    }
    func testRejectedActivationPolicyIsRetried() async throws {
        // A failed native transition must not become a cached success that prevents later recovery.
        try await withController { controller, _ in
            var policies: [NSApplication.ActivationPolicy] = []
            let delegate = RouterAppDelegate(controller: controller, setActivationPolicy: { policies.append($0); return false })
            defer {
                delegate.controlsWindow?.close()
                delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
            delegate.openControls()
            let window = try XCTUnwrap(delegate.controlsWindow)
            delegate.openControls()
            window.performClose(nil)
            delegate.openControls()
            window.performClose(nil)
            XCTAssertTrue(delegate.controlsWindow === window)
            XCTAssertEqual(policies, [.regular, .regular, .accessory, .regular, .accessory])
            XCTAssertFalse(controller.quitRequested)
            await controller.refreshAndWait()
        }
    }
    func testClosingLastWindowDoesNotRequestQuit() async throws {
        try await withController { controller, _ in
            await controller.refresh()
            let delegate = RouterAppDelegate(controller: controller)
            XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
            XCTAssertFalse(controller.quitRequested)
        }
    }
    func testVisibleAndHiddenPollingUseRequiredCadence() {
        XCTAssertEqual(ControlsPresentation.refreshInterval(windowVisible: true), 2)
        XCTAssertEqual(ControlsPresentation.refreshInterval(windowVisible: false), 5)
    }
    func testCancelledPendingNavigationCannotBePresentedLater() {
        // A refresh completing after window close must not republish the invalidated request.
        let navigation = QuitGuidanceNavigation()
        let pending = navigation.beginRequest()
        XCTAssertNil(navigation.requestID)
        navigation.clear()
        navigation.present(pending)
        XCTAssertNil(navigation.requestID)
    }
    func testOnlyLatestPendingNavigationCanBePresented() {
        // Publishing a superseded token would let delayed work replace a newer explicit request.
        let navigation = QuitGuidanceNavigation()
        let first = navigation.beginRequest()
        let second = navigation.beginRequest()
        XCTAssertNotEqual(first, second)
        navigation.present(first)
        XCTAssertNil(navigation.requestID)
        navigation.present(second)
        XCTAssertEqual(navigation.requestID, second)
        navigation.clear()
        navigation.present(second)
        XCTAssertNil(navigation.requestID)
    }
    func testPublishedGuidanceTracksEvidenceWithoutReplacingRequest() async throws {
        // Caching the published projection would retain direct-response instructions after context disappears.
        try await withPendingDirectController { controller, backend, store in
            await controller.start()
            let navigation = QuitGuidanceNavigation()
            let request = navigation.beginRequest(); navigation.present(request)
            XCTAssertEqual(QuitGuidance.current(for: controller).destination, .directResponse)
            let journal = try Data(contentsOf: store.directory.appendingPathComponent("state.json"))
            let inspections = backend.inspectCount
            backend.snapshot.context = nil
            await controller.refresh()
            XCTAssertEqual(QuitGuidance.current(for: controller).destination, .manualRecovery)
            XCTAssertEqual(navigation.requestID, request)
            XCTAssertEqual(backend.inspectCount, inspections + 1)
            XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), journal)
            XCTAssertFalse(controller.quitRequested)
            XCTAssertEqual(backend.controlCount, 0)
            XCTAssertEqual(backend.stopCount, 0)
        }
    }
}

@MainActor private final class DisplayBackend: CompanionBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false
    var routingMode: ProjectRoutingMode = .off
    var routingError: Error? = CompanionError.routingModeUnavailable
    var modeBarrier: DisplayModeBarrier?
    private(set) var modeSetCount = 0
    private(set) var inspectCount = 0
    private(set) var startCount = 0
    private(set) var controlCount = 0
    private(set) var stopCount = 0
    var snapshot = Inspection(configuration: .init(state: "missing"), provider: .init(state: "unavailable", recoveryRequired: false, proxyReady: nil, recordPhase: "unavailable"), catalog: .init(state: "ready", entries: [.init(id: "project-a", name: "Alpha", routeAlias: "route-a", routeState: "mapped")]))
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection { inspectCount += 1; return snapshot }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ validatedPath: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter {
        startCount += 1
        guard let context = snapshot.context else { throw CompanionError.startupFailed }
        let child = OwnedRouter(process: DisplaySyntheticProcess(), context: context)
        snapshot.provider.proxyReady = true
        return child
    }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult { controlCount += 1; throw CompanionError.commandFailed }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode {
        if let routingError { throw routingError }
        return routingMode
    }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode {
        modeSetCount += 1
        if let modeBarrier { await modeBarrier.wait() }
        if let routingError { throw routingError }
        routingMode = mode
        return mode
    }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome { stopCount += 1; throw CompanionError.unownedChild }
}
private final class DisplaySyntheticProcess: Process, @unchecked Sendable {
    override var isRunning: Bool { true }
}

@MainActor private final class DisplayModeBarrier {
    private var continuation: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var waiting = false
    func wait() async {
        await withCheckedContinuation { continuation = $0; waiting = true; started?.resume(); started = nil }
    }
    func waitUntilStarted() async {
        if !waiting { await withCheckedContinuation { started = $0 } }
    }
    func release() { continuation?.resume(); continuation = nil }
}
