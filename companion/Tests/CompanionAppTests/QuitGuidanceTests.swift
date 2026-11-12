import XCTest
import CompanionCore
@testable import CodexProjectRouter

@MainActor final class QuitGuidanceTests: XCTestCase {
    private var root: URL!
    private let sentinel = "SYNTHETIC_PRIVATE_SENTINEL"
    private var context: ActivationContext {
        .init(configPath: "/synthetic/\(sentinel)/config.json", codexHome: "/synthetic/\(sentinel)/codex",
              providerId: sentinel, listenPort: 43129)
    }

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("quit guidance \(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDown() async throws { try FileManager.default.removeItem(at: root) }

    private func fixture(pending: Bool = true, owned: Bool = false) async throws -> GuidanceFixture {
        let store = PrivateStore(directory: root.appendingPathComponent(UUID().uuidString))
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath,
            pending: pending ? .init(context: context, phase: .directConfirmation) : nil))
        let backend = GuidanceBackend(context: context)
        let controller = RouterController(backend: backend, store: store, browseHome: root)
        await controller.refresh()
        if owned { await controller.start(); XCTAssertNotNil(controller.ownedRouter) }
        return GuidanceFixture(controller: controller, backend: backend, store: store)
    }
    private func assertGuidance(_ controller: RouterController, _ destination: QuitGuidance.Destination,
                                _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let guidance = QuitGuidance.current(for: controller)
        XCTAssertEqual(guidance.destination, destination, file: file, line: line)
        XCTAssertEqual(guidance.text, text, file: file, line: line)
        XCTAssertFalse(guidance.text.contains(sentinel), file: file, line: line)
    }

    func testAdvancedRevealsCurrentQuitTarget() async throws {
        // Nesting a target in collapsed Advanced must reveal its whole path before navigation.
        for destination in [QuitGuidance.Destination.status, .restoreDirect, .directResponse, .manualRecovery, .stopRouter, .setup] {
            var disclosure = ControlsDisclosureState()
            disclosure.reveal(for: destination)
            XCTAssertTrue(disclosure.advancedExpanded)
            XCTAssertEqual(disclosure.setupExpanded, destination == .setup)
            XCTAssertEqual(disclosure.recoveryExpanded, destination == .manualRecovery)
        }
        let f = try await fixture(owned: true)
        var disclosure = ControlsDisclosureState()
        disclosure.reveal(for: QuitGuidance.current(for: f.controller).destination)
        XCTAssertTrue(disclosure.advancedExpanded)
        f.backend.snapshot.context = nil
        await f.controller.refresh()
        disclosure.reveal(for: QuitGuidance.current(for: f.controller).destination)
        XCTAssertTrue(disclosure.recoveryExpanded)
        XCTAssertEqual(f.backend.counts["control"], 0)
        XCTAssertEqual(f.backend.counts["stop"], 0)
    }

    func testOwnedConfirmationTargetsEnabledResponseCheck() async throws {
        // Treating an owned router as idle would hide its required manual response check.
        let f = try await fixture(owned: true)
        XCTAssertEqual(f.controller.quitBlockReason, .directConfirmationPending)
        XCTAssertTrue(f.controller.canConfirmDirectResponse)
        assertGuidance(f.controller, .directResponse,
            "Quit and reopen Codex, then send a message. After a working reply, click the direct-response confirmation below and choose Quit again. Keep the router running until then.")
    }

    func testIdlePendingRequestsFreshQuitWithoutConfirmation() async throws {
        // Disk Direct and pending evidence must suggest a new check, never authorize or demand confirmation.
        let f = try await fixture()
        XCTAssertFalse(f.controller.canQuit)
        XCTAssertTrue(f.controller.canConfirmDirectResponse)
        assertGuidance(f.controller, .status,
            "Choose Quit again to check the saved recovery information. A pending response check can stay saved while this idle app is closed.")
    }

    func testNormalQuitPermissionClearsPreviousInstructions() async throws {
        // A resolved guard must withdraw old restart instructions, including after idle authorization.
        let normal = try await fixture(pending: false)
        let idle = try await fixture()
        await idle.controller.requestQuit()
        XCTAssertTrue(idle.controller.quitRequested)
        for f in [normal, idle] {
            XCTAssertTrue(f.controller.canQuit)
            assertGuidance(f.controller, .status, "The previous blocker has cleared. Choose Quit again.")
        }
    }

    func testLiveUncertaintyPrecedesCachedPermission() async throws {
        // Reading cached canQuit before the live reason would incorrectly clear an uncertain operation.
        let f = try await fixture(pending: false)
        XCTAssertTrue(f.controller.canQuit)
        f.backend.mutationRequiresReconciliation = true
        XCTAssertFalse(f.controller.mutationRequiresReconciliation)
        XCTAssertTrue(f.controller.canQuit)
        XCTAssertEqual(f.controller.quitBlockReason, .operationInProgress)
        assertGuidance(f.controller, .status,
            "Click Refresh to check the operation. Wait while it is running; use the recovery instructions if it cannot finish.")
    }

    func testRunningOperationPrecedesConfirmation() async throws {
        // A running Start must show status rather than instruct a disabled confirmation action.
        let f = try await fixture()
        let barrier = GuidanceStartBarrier()
        f.backend.startBarrier = barrier
        let start = Task { await f.controller.start() }
        await barrier.waitUntilStarted()
        XCTAssertTrue(f.controller.busy)
        XCTAssertFalse(f.controller.canConfirmDirectResponse)
        assertGuidance(f.controller, .status,
            "Click Refresh to check the operation. Wait while it is running; use the recovery instructions if it cannot finish.")
        barrier.release()
        await start.value
    }

    func testSafeStopPrecedesFallbackReason() async throws {
        // The generic contextUnavailable reason must not obscure an already permitted safe Stop.
        let f = try await fixture(pending: false, owned: true)
        XCTAssertTrue(f.controller.canStop)
        XCTAssertEqual(f.controller.quitBlockReason, .contextUnavailable)
        assertGuidance(f.controller, .stopRouter,
            "Choose Quit again to recheck and close the app, or use Stop owned router first.")
        f.backend.mutationRequiresReconciliation = true
        assertGuidance(f.controller, .status,
            "Click Refresh to check the operation. Wait while it is running; use the recovery instructions if it cannot finish.")
    }

    func testRestorationGuidanceDistinguishesOwnership() async throws {
        // Reusing owned restart instructions for an idle app would reinstate its removed response requirement.
        for owned in [false, true] {
            let f = try await fixture(owned: owned)
            f.backend.snapshot.provider = .init(state: "router", recoveryRequired: true,
                proxyReady: owned, recordPhase: "active")
            await f.controller.refresh()
            XCTAssertEqual(f.controller.quitBlockReason, .directRecoveryRequired)
            XCTAssertTrue(f.controller.canRestoreDirect)
            assertGuidance(f.controller, .restoreDirect, owned
                ? "Click Restore direct. Keep the router running while you restart Codex and verify a reply; then confirm the direct response below and choose Quit again."
                : "Click Restore direct, then choose Quit again. Quit will check the saved settings and recovery information.")
        }
    }

    func testUnavailableJournalNeverSuggestsConfirmation() async throws {
        // A failed durable check must override cached Direct confirmation eligibility.
        for corrupt in [false, true] {
            let f = try await fixture()
            let state = f.store.directory.appendingPathComponent("state.json")
            if corrupt { try Data(sentinel.utf8).write(to: state) }
            else { try FileManager.default.removeItem(at: state) }
            await f.controller.requestQuit()
            XCTAssertFalse(f.controller.quitRequested)
            XCTAssertEqual(f.controller.quitBlockReason, .contextUnavailable)
            XCTAssertTrue(f.controller.canConfirmDirectResponse)
            assertGuidance(f.controller, .manualRecovery,
                "Click Refresh and review any recovery instructions shown. Choose Quit again after the problem is resolved.")
        }
    }

    func testMissingContextUsesExistingFallback() async throws {
        // A disappearing context must target an existing disclosure, Setup, or status, never a disabled action.
        for (pending, state, destination) in [(true, "invalid", QuitGuidance.Destination.manualRecovery),
                                            (false, "missing", .setup), (false, "valid", .status)] {
            let f = try await fixture(pending: pending, owned: true)
            f.backend.snapshot.context = nil
            f.backend.snapshot.configuration.state = state
            await f.controller.refresh()
            XCTAssertFalse(f.controller.canRestoreDirect)
            XCTAssertFalse(f.controller.canConfirmDirectResponse)
            XCTAssertEqual(f.controller.quitBlockReason, .contextUnavailable)
            assertGuidance(f.controller, destination,
                "Click Refresh and review any recovery instructions shown. Choose Quit again after the problem is resolved.")
        }
    }

    func testUnavailableInspectionUsesRetainedRecoveryDisclosure() async throws {
        // Private backend failure text must not leak or direct the user toward disabled recovery controls.
        let f = try await fixture(owned: true)
        f.backend.inspectionError = NSError(domain: sentinel, code: 1, userInfo: [NSLocalizedDescriptionKey: sentinel])
        await f.controller.refresh()
        XCTAssertFalse(f.controller.canRestoreDirect)
        XCTAssertFalse(f.controller.canConfirmDirectResponse)
        assertGuidance(f.controller, .manualRecovery,
            "Click Refresh and review any recovery instructions shown. Choose Quit again after the problem is resolved.")
    }

    func testUnavailableRevisionPrecedesEnabledRestore() async throws {
        // Restore's broad context eligibility must not mask missing comparison evidence.
        let f = try await fixture(owned: true)
        f.backend.snapshot.revision = nil
        await f.controller.refresh()
        XCTAssertTrue(f.controller.canRestoreDirect)
        XCTAssertFalse(f.controller.canConfirmDirectResponse)
        XCTAssertEqual(f.controller.quitBlockReason, .contextUnavailable)
        assertGuidance(f.controller, .manualRecovery,
            "Click Refresh and review any recovery instructions shown. Choose Quit again after the problem is resolved.")
    }

    func testGuidanceReadsHaveNoEffects() async throws {
        // Projection must not inspect, authorize Quit, write recovery, confirm a reply, or control the router.
        for owned in [false, true] {
            let f = try await fixture(owned: owned)
            let state = f.store.directory.appendingPathComponent("state.json")
            let bytes = try Data(contentsOf: state)
            let modified = try FileManager.default.attributesOfItem(atPath: state.path)[.modificationDate] as? Date
            let confirmation = f.controller.desktopConfirmation
            let quitRequested = f.controller.quitRequested
            let canQuit = f.controller.canQuit
            let recovery = f.controller.recoveryContext
            let counts = f.backend.counts
            for _ in 0..<5 { _ = QuitGuidance.current(for: f.controller) }
            XCTAssertEqual(try Data(contentsOf: state), bytes)
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: state.path)[.modificationDate] as? Date, modified)
            XCTAssertEqual(f.controller.desktopConfirmation, confirmation)
            XCTAssertEqual(f.controller.quitRequested, quitRequested)
            XCTAssertEqual(f.controller.canQuit, canQuit)
            XCTAssertEqual(f.controller.recoveryContext, recovery)
            XCTAssertEqual(f.backend.counts, counts)
        }
    }
}

@MainActor private struct GuidanceFixture {
    let controller: RouterController
    let backend: GuidanceBackend
    let store: PrivateStore
}
private final class GuidanceSyntheticProcess: Process, @unchecked Sendable {
    override var isRunning: Bool { true }
}
@MainActor private final class GuidanceStartBarrier {
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
@MainActor private final class GuidanceBackend: CompanionBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false
    var snapshot: Inspection
    var inspectionError: Error?
    var startBarrier: GuidanceStartBarrier?
    private(set) var counts = ["inspect": 0, "control": 0, "start": 0, "stop": 0]
    init(context: ActivationContext) {
        snapshot = Inspection(configuration: .init(state: "valid", path: context.configPath, mode: "legacy"),
            context: context, revision: "SYNTHETIC_PRIVATE_SENTINEL",
            provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "restored"),
            catalog: .init(state: "ready", entries: []))
    }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection {
        counts["inspect", default: 0] += 1
        if let inspectionError { throw inspectionError }
        return snapshot
    }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ validatedPath: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter {
        counts["start", default: 0] += 1
        if let startBarrier { await startBarrier.wait() }
        guard let context = snapshot.context else { throw CompanionError.startupFailed }
        snapshot.provider.proxyReady = true
        return OwnedRouter(process: GuidanceSyntheticProcess(), context: context)
    }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult {
        counts["control", default: 0] += 1
        throw CompanionError.commandFailed
    }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode { throw CompanionError.routingModeUnavailable }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode { throw CompanionError.routingModeUnavailable }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome {
        counts["stop", default: 0] += 1
        throw CompanionError.unownedChild
    }
}
