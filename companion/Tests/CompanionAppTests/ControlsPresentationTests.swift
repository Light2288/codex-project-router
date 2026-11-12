import XCTest
import AppKit
import CompanionCore
@testable import CodexProjectRouter

@MainActor final class ControlsPresentationTests: XCTestCase {
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
        backend.snapshot = Inspection(configuration: .init(state: "valid", path: context.configPath, mode: "legacy"),
            context: context, revision: "synthetic-presentation-revision",
            provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "restored"),
            catalog: .init(state: "ready", entries: []))
        let controller = RouterController(backend: backend, store: store, browseHome: root)
        await controller.refresh()
        try await body(controller, backend, store)
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
            XCTAssertEqual(display.projects(matching: "alpha").map(\.id), ["project-a"])
            XCTAssertEqual(display.projects(matching: "route-a").map(\.id), ["project-a"])
            XCTAssertTrue(display.projects(matching: "missing").isEmpty)
            backend.snapshot.configuration.state = "invalid"
            backend.snapshot.provider.proxyReady = true
            await controller.refresh()
            let invalid = ControlsPresentation(controller: controller)
            XCTAssertEqual(invalid.projects(matching: "").count, 1)
            XCTAssertEqual(invalid.ownership, "External listener; never owned")
            XCTAssertEqual(invalid.readiness, "Matching listener ready")
            XCTAssertFalse(controller.canStop)
            XCTAssertFalse(controller.canActivate)
            XCTAssertFalse(controller.canConfirmRoutedResponse)
            XCTAssertFalse(controller.canConfirmDirectResponse)
        }
    }
    func testUnavailableCatalogNeverPresentsOldRowsAsFresh() async throws {
        try await withController { controller, backend in
            await controller.refresh()
            backend.snapshot.catalog.state = "unavailable"
            await controller.refresh()
            let display = ControlsPresentation(controller: controller)
            XCTAssertTrue(display.projects(matching: "").isEmpty)
            XCTAssertEqual(display.catalog, "Catalog unavailable. Refresh to retry.")
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
    func stop(_ child: OwnedRouter) async throws -> StopOutcome { stopCount += 1; throw CompanionError.unownedChild }
}
private final class DisplaySyntheticProcess: Process, @unchecked Sendable {
    override var isRunning: Bool { true }
}
