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
}

@MainActor private final class DisplayBackend: CompanionBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false
    var snapshot = Inspection(configuration: .init(state: "missing"), provider: .init(state: "unavailable", recoveryRequired: false, proxyReady: nil, recordPhase: "unavailable"), catalog: .init(state: "ready", entries: [.init(id: "project-a", name: "Alpha", routeAlias: "route-a", routeState: "mapped")]))
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection { snapshot }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ validatedPath: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter { throw CompanionError.startupFailed }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult { throw CompanionError.commandFailed }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome { throw CompanionError.unownedChild }
}
