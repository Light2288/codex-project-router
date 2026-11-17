import XCTest
@testable import CompanionCore

@MainActor final class RouterControllerTests: XCTestCase {
    private var root: URL!
    private var store: PrivateStore!
    private var backend: ControlledBackend!
    private let context = ActivationContext(configPath: "/synthetic/private/config.json", codexHome: "/synthetic/codex", providerId: "router", listenPort: 43129)

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("companion controller \(UUID())")
        store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath))
        backend = ControlledBackend(context: context)
    }
    override func tearDown() async throws {
        backend = nil; store = nil
        try FileManager.default.removeItem(at: root)
    }
    private func makeController() -> RouterController {
        RouterController(backend: backend, store: store, browseHome: URL(fileURLWithPath: "/synthetic/normal-codex"))
    }
    private func started() async -> RouterController {
        let controller = makeController()
        await controller.refresh(); await controller.start()
        return controller
    }
    private func activated() async -> RouterController {
        let controller = await started()
        await controller.activate()
        return controller
    }
    func testStartPublishesOffOnlyAfterOwnedModeEvidence() async {
        // A retained child and readiness are insufficient to invent an initial Off acknowledgement.
        let controller = makeController()
        XCTAssertEqual(controller.projectRoutingStatus, .notRunning)
        await controller.refresh()
        let barrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeReadBarrier = barrier
        let start = Task { await controller.start() }
        await waitUntil { barrier.waiting }
        XCTAssertNotNil(controller.ownedRouter)
        XCTAssertNotEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertFalse(controller.canSetProjectRouting)
        barrier.release(.success(.off)); await start.value
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertTrue(controller.canSetProjectRouting)
        XCTAssertTrue(backend.modeReads.last === controller.ownedRouter)
        XCTAssertTrue(backend.modeSets.isEmpty)
    }
    func testModeAckPreservesProviderJournalAndConfirmation() async throws {
        // Mode acknowledgement and its later read must leave provider and response-confirmation evidence intact.
        let files = try prepareModeEvidenceFiles()
        let controller = await activated(); await controller.confirmRoutedResponse()
        await controller.setProjectRouting(.on)
        let before = try files.map { try Data(contentsOf: $0) }
        let inspection = controller.inspection
        let controls = backend.controls.count
        await controller.setProjectRouting(.off)
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertFalse(controller.canStop)
        XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.inspection, inspection)
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, before)
        await controller.refresh()
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, before)
        XCTAssertEqual(backend.controls.count, controls)
        XCTAssertTrue(backend.modeSets.last?.1 === controller.ownedRouter)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertEqual(backend.startCount, 1)
    }
    func testLostModeAckPreservesRestoreAndCatalog() async throws {
        // A lost mode reply cannot authorize a second set or poison otherwise usable recovery evidence.
        let files = try prepareModeEvidenceFiles()
        let controller = await activated(); await controller.confirmRoutedResponse()
        let before = try files.map { try Data(contentsOf: $0) }
        let barrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeSetBarrier = barrier
        let change = Task { await controller.setProjectRouting(.on) }
        await waitUntil { barrier.waiting }
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertFalse(controller.canSetProjectRouting)
        barrier.release(.failure(.routingModeUncertain)); await change.value
        XCTAssertEqual(controller.projectRoutingStatus, .uncertain)
        XCTAssertEqual(controller.routingModeError, CompanionError.routingModeUncertain.rawValue)
        XCTAssertFalse(controller.canSetProjectRouting)
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertEqual(controller.inspection?.catalog.state, "ready")
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, before)
        XCTAssertNil(controller.error)
        await controller.setProjectRouting(.off)
        XCTAssertEqual(backend.modeSets.count, 1)
        backend.modeReadError = .timedOut
        await controller.refresh()
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        XCTAssertEqual(controller.routingModeError, CompanionError.routingModeUnavailable.rawValue)
        XCTAssertEqual(controller.inspection?.catalog.state, "ready")
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, before)
        XCTAssertNil(controller.error)
        await controller.restoreDirect()
        XCTAssertEqual(backend.controls.map(\.0), [.activate, .rollback])
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(backend.stopCount, 0)
    }
    func testModeReconciliationCannotPublishStaleChildOrGeneration() async {
        // A mode query begun before exit must not attach its On result to the next owned child.
        let controller = await started()
        let oldChild = controller.ownedRouter
        let barrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeReadBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        backend.exitChild()
        XCTAssertEqual(controller.projectRoutingStatus, .notRunning)
        backend.snapshot.provider.proxyReady = false
        let replacement = Task { await controller.start() }
        await waitUntil { controller.busy }
        barrier.release(.success(.on)); await refresh.value; await replacement.value
        XCTAssertFalse(controller.ownedRouter === oldChild)
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertTrue(controller.canSetProjectRouting)
        XCTAssertEqual(backend.startCount, 2)
        let replacementChild = controller.ownedRouter
        let generationBarrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeReadBarrier = generationBarrier
        let oldGeneration = Task { await controller.refreshAndWait() }
        await waitUntil { generationBarrier.waiting }
        let selection = Task { await controller.selectNode(URL(fileURLWithPath: "/synthetic/replacement-node")) }
        await waitUntil { controller.busy }
        generationBarrier.release(.success(.on)); await oldGeneration.value; await selection.value
        XCTAssertTrue(controller.ownedRouter === replacementChild)
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
    }
    func testOverlappingModeAndRecoveryActionsAreSerialized() async {
        // A held mode mutation owns the action gate and the mode/inspection slot until its outcome is known.
        let controller = await activated()
        let modeBarrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeSetBarrier = modeBarrier
        let change = Task { await controller.setProjectRouting(.on) }
        await waitUntil { modeBarrier.waiting }
        let reads = backend.modeReads.count
        let poll = Task { await controller.refreshAndWait() }
        await controller.restoreDirect(); await controller.activate(); await controller.stop(); await controller.requestQuit()
        await controller.setProjectRouting(.off)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(controller.busy)
        XCTAssertFalse(controller.canRestoreDirect)
        XCTAssertFalse(controller.quitRequested)
        XCTAssertEqual(backend.controls.count, 1)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertEqual(backend.modeSets.count, 1)
        XCTAssertEqual(backend.modeReads.count, reads)
        modeBarrier.release(.success(.on)); await change.value; await poll.value
        XCTAssertEqual(controller.projectRoutingStatus, .known(.on))
        let restoreBarrier = Barrier<ControlResult>(); backend.controlBarrier = restoreBarrier
        let restore = Task { await controller.restoreDirect() }
        await waitUntil { restoreBarrier.waiting }
        let recoveryReads = backend.modeReads.count
        await controller.refresh()
        await controller.setProjectRouting(.off)
        XCTAssertEqual(backend.modeReads.count, recoveryReads)
        XCTAssertEqual(backend.modeSets.count, 1)
        backend.snapshot.provider.state = "direct"; backend.snapshot.provider.recordPhase = "restored"
        backend.snapshot.revision = "restored-after-mode"
        restoreBarrier.release(.init(state: "direct", changed: true, restartRequired: true)); await restore.value
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(backend.maximumConcurrentModeCommands, 1)
    }
    func testOffDoesNotAuthorizeStopOrQuit() async {
        // Off on the owned listener is still routed provider state and requires explicit direct recovery.
        let controller = await activated()
        await controller.setProjectRouting(.off)
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        await controller.stop(); await controller.requestQuit()
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
        XCTAssertFalse(controller.quitRequested)
        XCTAssertEqual(controller.inspection?.provider.state, "router")
        XCTAssertEqual(backend.controls.map(\.0), [.activate])
        XCTAssertEqual(backend.stopCount, 0)
        await controller.restoreDirect(); await controller.confirmDirectResponse(); await controller.stop()
        XCTAssertTrue(controller.canQuit)
        XCTAssertEqual(controller.projectRoutingStatus, .notRunning)
    }
    func testFreshModeQueryReconcilesLostAckWithoutDesktopChanges() async throws {
        // Only a later query, never the requested value, resolves a lost acknowledgement.
        let files = try prepareModeEvidenceFiles()
        let controller = await activated(); await controller.confirmRoutedResponse()
        let before = try files.map { try Data(contentsOf: $0) }
        backend.modeSetError = .routingModeUncertain
        await controller.setProjectRouting(.on)
        XCTAssertEqual(controller.projectRoutingStatus, .uncertain)
        backend.mode = .on
        await controller.refreshAndWait()
        XCTAssertEqual(controller.projectRoutingStatus, .known(.on))
        XCTAssertTrue(controller.canSetProjectRouting)
        XCTAssertNil(controller.routingModeError)
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, before)
        XCTAssertEqual(backend.modeSets.count, 1)
    }
    func testQueuedPreSwitchModeQueryCannotReplaceAcknowledgement() async {
        // Starting a switch invalidates an older in-flight read even when its Off reply arrives later.
        let controller = await started()
        let barrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeReadBarrier = barrier
        let oldPoll = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        let change = Task { await controller.setProjectRouting(.on) }
        await waitUntil { controller.busy }
        let queuedPoll = Task { await controller.refreshAndWait() }
        barrier.release(.success(.off)); await oldPoll.value; await change.value; await queuedPoll.value
        XCTAssertEqual(controller.projectRoutingStatus, .known(.on))
        XCTAssertEqual(backend.modeSets.count, 1)
        XCTAssertEqual(backend.maximumConcurrentModeCommands, 1)
    }
    func testModeAckCannotSurviveChildExitOrContextReplacement() async {
        // Neither an old child's acknowledgement nor a mode read can survive a changed recovery binding.
        let controller = await started()
        let barrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeSetBarrier = barrier
        let change = Task { await controller.setProjectRouting(.on) }
        await waitUntil { barrier.waiting }
        backend.exitChild()
        barrier.release(.success(.on)); await change.value
        XCTAssertEqual(controller.projectRoutingStatus, .notRunning)
        XCTAssertFalse(controller.canSetProjectRouting)
        backend.snapshot.provider.proxyReady = false
        await controller.start()
        backend.snapshot.context?.codexHome = "/synthetic/replaced-home"
        let reads = backend.modeReads.count
        await controller.refresh()
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        XCTAssertFalse(controller.canSetProjectRouting)
        XCTAssertEqual(backend.modeReads.count, reads)
    }
    func testMismatchedModeAcknowledgementDoesNotPublishRequestedOrOldMode() async {
        // An acknowledgement for a different value is unavailable evidence, not a successful switch.
        let controller = await activated(); await controller.confirmRoutedResponse()
        let barrier = Barrier<Result<ProjectRoutingMode, CompanionError>>(); backend.modeSetBarrier = barrier
        let change = Task { await controller.setProjectRouting(.on) }
        await waitUntil { barrier.waiting }
        barrier.release(.success(.off)); await change.value
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        XCTAssertEqual(controller.routingModeError, CompanionError.routingModeUnavailable.rawValue)
        XCTAssertFalse(controller.canSetProjectRouting)
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertNil(controller.error)
        XCTAssertEqual(backend.modeSets.count, 1)
        XCTAssertEqual(backend.controls.map(\.0), [.activate])
    }
    func testModeUnavailableForExternalUnsupportedOrUnreadyListener() async {
        // Observed readiness, unsupported pipes and a start readiness timeout cannot invent controllable Off.
        let controller = makeController()
        backend.snapshot.provider.proxyReady = true
        await controller.refresh(); await controller.setProjectRouting(.on)
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        XCTAssertTrue(backend.modeReads.isEmpty); XCTAssertTrue(backend.modeSets.isEmpty)
        backend.snapshot.provider.proxyReady = false
        backend.startBecomesReady = false
        await controller.start()
        XCTAssertNotNil(controller.ownedRouter)
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        XCTAssertFalse(controller.canSetProjectRouting)
        XCTAssertTrue(backend.modeReads.isEmpty)
        backend.snapshot.provider.proxyReady = true
        backend.modeReadError = .routingModeUnavailable
        await controller.refresh()
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        XCTAssertEqual(controller.routingModeError, CompanionError.routingModeUnavailable.rawValue)
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertEqual(controller.inspection?.catalog.state, "ready")
        XCTAssertFalse(controller.mutationRequiresReconciliation)
    }
    func testProviderUncertaintyBlocksModeButRecoveryOnlyStateDoesNotQuery() async throws {
        // Mode controls never bypass provider-helper uncertainty or adopt a journal's historical child.
        let controller = await started()
        backend.mutationRequiresReconciliation = true
        XCTAssertFalse(controller.canSetProjectRouting)
        await controller.setProjectRouting(.on)
        XCTAssertTrue(backend.modeSets.isEmpty)
        let (recovery, recoveryBackend, _) = try idlePendingFixture()
        await recovery.refresh()
        XCTAssertEqual(recovery.projectRoutingStatus, .notRunning)
        XCTAssertFalse(recovery.canSetProjectRouting)
        XCTAssertTrue(recovery.canRestoreDirect)
        XCTAssertTrue(recoveryBackend.modeReads.isEmpty)
    }
    func testObservedOccupiedPortKeepsModeUnavailableAfterRefresh() async {
        // A disk inspection that cannot identify the external listener does not erase the independent port result.
        let controller = await started()
        backend.stopOutcome = .init(childExited: true, portState: .occupied)
        await controller.stop()
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        backend.snapshot.provider.proxyReady = false
        await controller.refresh()
        XCTAssertEqual(controller.projectRoutingStatus, .unavailable)
        XCTAssertFalse(controller.canSetProjectRouting)
        XCTAssertTrue(controller.canQuit)
        XCTAssertTrue(controller.needsManualListenerCleanup)
    }
    private func prepareModeEvidenceFiles() throws -> [URL] {
        let config = root.appendingPathComponent("router.json"), home = root.appendingPathComponent("synthetic-home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let provider = home.appendingPathComponent("config.toml"), activation = home.appendingPathComponent("activation.json")
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "codexHome": home.path, "providerId": context.providerId,
            "listenPort": context.listenPort, "upstreamBaseUrl": "https://synthetic.invalid/v1", "projectRoutes": [:]]).write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        try Data("model_provider = \"synthetic\"\n".utf8).write(to: provider)
        try Data("{\"synthetic\":\"activation-evidence\"}".utf8).write(to: activation)
        var fixtureContext = context; fixtureContext.configPath = config.path; fixtureContext.codexHome = home.path
        try store.save(CompanionJournal(selectedConfigurationPath: config.path))
        backend = ControlledBackend(context: fixtureContext)
        return [store.directory.appendingPathComponent("state.json"), config, provider, activation]
    }
    func testRefreshAndWaitWaitsForExistingInspection() async {
        // Returning through refreshRunning or bypassing its inspection slot would finish early or overlap reads.
        let controller = makeController(); await controller.refresh()
        let baseline = backend.inspectedPaths.count
        let backgroundBarrier = Barrier<Inspection>(), guidanceBarrier = Barrier<Inspection>()
        backend.inspectBarrier = backgroundBarrier
        let background = Task { await controller.refresh() }
        await waitUntil { backgroundBarrier.waiting }
        backend.inspectBarrier = guidanceBarrier
        var started = false, completed = false
        let guidance = Task {
            started = true
            await controller.refreshAndWait()
            completed = true
        }
        await waitUntil { started }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(completed)
        XCTAssertEqual(backend.inspectedPaths.count, baseline + 1)
        backgroundBarrier.release(backend.snapshot)
        await waitUntil { guidanceBarrier.waiting }
        XCTAssertFalse(completed)
        XCTAssertEqual(backend.inspectedPaths.count, baseline + 2)
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        guidanceBarrier.release(backend.snapshot)
        await background.value; await guidance.value
        XCTAssertTrue(completed)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
    }
    func testRefreshAndWaitAppliesInspectionFailure() async {
        // Ignoring the normal inspection failure path would leave stale operational guidance available.
        let controller = makeController(); await controller.refresh()
        let baseline = backend.inspectedPaths.count
        backend.inspectionError = .commandFailed
        await controller.refreshAndWait()
        XCTAssertEqual(backend.inspectedPaths.count, baseline + 1)
        XCTAssertEqual(controller.inspection?.configuration.state, "unavailable")
        XCTAssertEqual(controller.inspection?.provider.state, "unavailable")
        XCTAssertEqual(controller.error, CompanionError.commandFailed.rawValue)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
    }
    func testRefreshAndWaitDiscardsInspectionFromStaleGeneration() async {
        // Applying a pre-exit result would replace newer child-exit evidence with stale router facts.
        let controller = await started()
        let baseline = backend.inspectedPaths.count
        var stale = backend.snapshot
        stale.provider.state = "router"; stale.provider.recordPhase = "active"
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let refresh = Task { await controller.refreshAndWait() }
        await waitUntil { barrier.waiting }
        backend.exitChild()
        barrier.release(stale)
        await refresh.value
        XCTAssertNil(controller.ownedRouter)
        XCTAssertEqual(controller.inspection?.provider.state, "direct")
        XCTAssertNil(controller.inspection?.provider.proxyReady)
        XCTAssertEqual(backend.inspectedPaths.count, baseline + 1)
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
    }
    func testQuitBlockReasonDirectPendingIsReadOnly() async throws {
        // Reading alert guidance must neither accept confirmation nor reconcile or mutate evidence.
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath,
            pending: .init(context: context, phase: .directConfirmation)))
        let controller = makeController(); await controller.refresh()
        XCTAssertNil(controller.ownedRouter)
        let journalBefore = try store.load()
        let inspectionsBefore = backend.inspectedPaths.count
        let controlsBefore = backend.controls.count
        let stopsBefore = backend.stopCount
        let confirmationBefore = controller.desktopConfirmation
        let recoveryBefore = controller.recoveryContext
        let quitBefore = controller.quitRequested
        for _ in 0..<3 {
            XCTAssertEqual(controller.quitBlockReason, .directConfirmationPending)
            XCTAssertFalse(controller.canQuit)
        }
        XCTAssertEqual(try store.load(), journalBefore)
        XCTAssertEqual(backend.inspectedPaths.count, inspectionsBefore)
        XCTAssertEqual(backend.controls.count, controlsBefore)
        XCTAssertEqual(backend.stopCount, stopsBefore)
        XCTAssertEqual(controller.desktopConfirmation, confirmationBefore)
        XCTAssertEqual(controller.recoveryContext, recoveryBefore)
        XCTAssertEqual(controller.quitRequested, quitBefore)
        await controller.requestQuit()
        XCTAssertTrue(controller.canQuit); XCTAssertTrue(controller.quitRequested)
        XCTAssertNil(controller.quitBlockReason)
    }
    private func idlePendingFixture(phase: CompanionJournal.Phase = .directConfirmation) throws -> (RouterController, ControlledBackend, PrivateStore) {
        let fixtureStore = PrivateStore(directory: root.appendingPathComponent(UUID().uuidString))
        try fixtureStore.save(CompanionJournal(selectedConfigurationPath: context.configPath,
            pending: .init(context: context, phase: phase)))
        let fixtureBackend = ControlledBackend(context: context)
        return (RouterController(backend: fixtureBackend, store: fixtureStore, browseHome: root), fixtureBackend, fixtureStore)
    }

    func testIdleQuitPreservesPendingRecovery() async throws {
        // Removing the idle exception, consuming confirmation, or signalling an external listener breaks this contract.
        for phase in [CompanionJournal.Phase.activationAttempt, .routedConfirmation, .restoring, .directConfirmation] {
            for record in ["none", "restored"] {
                let (controller, backend, store) = try idlePendingFixture(phase: phase)
                backend.snapshot.provider.recordPhase = record
                backend.snapshot.provider.proxyReady = true // External readiness never establishes ownership.
                await controller.refresh()
                let state = store.directory.appendingPathComponent("state.json")
                let bytesBefore = try Data(contentsOf: state)
                XCTAssertFalse(controller.canQuit)
                await withQueuedPolling(controller, backend: backend) { await controller.requestQuit() }
                XCTAssertTrue(controller.quitRequested, "\(phase)/\(record)")
                XCTAssertTrue(controller.canQuit)
                XCTAssertNil(controller.quitBlockReason)
                XCTAssertEqual(try Data(contentsOf: state), bytesBefore)
                XCTAssertNotEqual(controller.desktopConfirmation, .confirmedDirect)
                XCTAssertNil(controller.ownedRouter)
                XCTAssertTrue(backend.controls.isEmpty)
                XCTAssertEqual(backend.stopCount, 0)
                XCTAssertEqual(backend.startCount, 0)
                let inspections = backend.inspectedPaths.count
                await controller.requestQuit()
                XCTAssertTrue(controller.quitRequested)
                XCTAssertEqual(backend.inspectedPaths.count, inspections + 1)
                XCTAssertEqual(try Data(contentsOf: state), bytesBefore)
            }
        }
    }

    func testIdleQuitRequiresFreshMatchingEvidence() async throws {
        // Trusting cached Direct or an earlier authorization would permit exit after these action-time changes.
        let changes: [(String, (inout Inspection) -> Void)] = [
            ("routed", { $0.provider.state = "router"; $0.provider.recordPhase = "active" }),
            ("prepared", { $0.provider.recordPhase = "prepared" }),
            ("conflict", { $0.provider.state = "conflict" }),
            ("unavailable", { $0.provider.state = "unavailable" }),
            ("recovery", { $0.provider.recoveryRequired = true }),
            ("configuration", { $0.configuration.state = "unavailable" }),
            ("path", { $0.configuration.path = "/synthetic/other.json" }),
            ("config context", { $0.context?.configPath = "/synthetic/other.json" }),
            ("home", { $0.context?.codexHome = "/synthetic/other-home" }),
            ("provider", { $0.context?.providerId = "other" }),
            ("port", { $0.context?.listenPort = 43130 }),
            ("revision", { $0.revision = nil }),
            ("empty revision", { $0.revision = "" })
        ]
        for (name, change) in changes {
            let (controller, backend, store) = try idlePendingFixture()
            await controller.refresh()
            await controller.requestQuit()
            XCTAssertTrue(controller.quitRequested, name)
            let bytesBefore = try Data(contentsOf: store.directory.appendingPathComponent("state.json"))
            change(&backend.snapshot)
            await controller.requestQuit()
            XCTAssertFalse(controller.quitRequested, name)
            XCTAssertFalse(controller.canQuit, name)
            XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), bytesBefore, name)
            XCTAssertTrue(backend.controls.isEmpty, name)
            XCTAssertEqual(backend.stopCount, 0, name)
        }
        let (controller, backend, store) = try idlePendingFixture()
        await controller.requestQuit()
        XCTAssertTrue(controller.quitRequested)
        let before = try store.readExisting()
        backend.inspectionError = .commandFailed
        await controller.requestQuit()
        XCTAssertFalse(controller.quitRequested)
        XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.quitBlockReason, .contextUnavailable)
        XCTAssertEqual(try store.readExisting(), before)
    }

    func testIdleQuitRejectsChangedDurableJournal() async throws {
        // Recreating missing state or comparing only the pending context would lose or overwrite recovery evidence.
        for change in ["delete", "corrupt", "phase", "node", "pending", "context"] {
            let (controller, backend, store) = try idlePendingFixture()
            await controller.refresh()
            await controller.requestQuit()
            XCTAssertTrue(controller.quitRequested)
            let state = store.directory.appendingPathComponent("state.json")
            var changed = try store.readExisting()
            switch change {
            case "delete": try FileManager.default.removeItem(at: state)
            case "corrupt": try Data("SYNTHETIC_PRIVATE_SENTINEL".utf8).write(to: state)
            case "phase": changed.pending?.phase = .restoring; try store.save(changed)
            case "node": changed.nodeExecutablePath = "/synthetic/other-node"; try store.save(changed)
            case "pending": changed.pending = nil; try store.save(changed)
            default: changed.pending?.context.codexHome = "/synthetic/other-home"; try store.save(changed)
            }
            let bytesBefore = try? Data(contentsOf: state)
            await controller.requestQuit()
            XCTAssertFalse(controller.quitRequested, change)
            XCTAssertFalse(controller.canQuit, change)
            XCTAssertEqual(controller.quitBlockReason, .contextUnavailable, change)
            XCTAssertEqual(controller.error, CompanionError.privateState.rawValue, change)
            XCTAssertEqual(try? Data(contentsOf: state), bytesBefore, change)
            XCTAssertTrue(backend.controls.isEmpty)
            XCTAssertEqual(backend.stopCount, 0)
        }
    }

    func testIdleQuitCannotBypassBusyOrLiveMutation() async throws {
        // Neither an in-flight operation nor newer live/copied uncertainty can borrow cached idle permission.
        let (controller, backend, store) = try idlePendingFixture()
        await controller.requestQuit()
        XCTAssertTrue(controller.canQuit)
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let restore = Task { await controller.restoreDirect() }
        await waitUntil { barrier.waiting }
        await controller.requestQuit()
        XCTAssertFalse(controller.quitRequested)
        XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        backend.mutationRequiresReconciliation = true
        barrier.release(backend.snapshot); await restore.value
        XCTAssertFalse(controller.quitRequested)
        XCTAssertTrue(controller.mutationRequiresReconciliation)
        backend.mutationRequiresReconciliation = false
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        XCTAssertFalse(controller.canQuit)
        await controller.refresh()
        await controller.requestQuit()
        XCTAssertTrue(controller.canQuit)
        backend.mutationRequiresReconciliation = true
        XCTAssertFalse(controller.mutationRequiresReconciliation)
        XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        await controller.requestQuit()
        XCTAssertFalse(controller.quitRequested)
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        XCTAssertNotNil(try store.readExisting().pending)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
    }

    func testIdleQuitRejectsMemoryOnlyRecovery() async throws {
        // A failed intent save plus unexpected child exit must not turn missing durable recovery into permission.
        let controller = await started()
        let state = store.directory.appendingPathComponent("state.json")
        let bytesBefore = try Data(contentsOf: state)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: state.path)
        await controller.activate()
        backend.exitChild()
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: state.path)
        backend.snapshot.provider.proxyReady = false
        await controller.requestQuit()
        XCTAssertFalse(controller.quitRequested)
        XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.quitBlockReason, .contextUnavailable)
        XCTAssertEqual(try Data(contentsOf: state), bytesBefore)
        XCTAssertNil(try store.readExisting().pending)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
    }

    func testIdleQuitRelaunchRetainsPending() async throws {
        // Relaunch cannot treat a successful idle Quit as desktop confirmation or consume the retained journal.
        let expectedPending = CompanionJournal.Pending(context: context, phase: .restoring)
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath, pending: expectedPending))
        let state = store.directory.appendingPathComponent("state.json")
        let bytesBefore = try Data(contentsOf: state)
        var first: RouterController? = makeController()
        await first?.requestQuit()
        XCTAssertTrue(first?.quitRequested == true)
        first = nil; store.releaseInstanceLock()
        let relaunched = makeController()
        await relaunched.refresh()
        XCTAssertFalse(relaunched.canQuit)
        XCTAssertNotEqual(relaunched.desktopConfirmation, .confirmedDirect)
        XCTAssertEqual(try store.readExisting().pending, expectedPending)
        XCTAssertEqual(try Data(contentsOf: state), bytesBefore)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.startCount, 0)
        XCTAssertEqual(backend.stopCount, 0)
        await relaunched.requestQuit()
        XCTAssertTrue(relaunched.quitRequested)
        XCTAssertEqual(try Data(contentsOf: state), bytesBefore)
    }

    func testIdleQuitAuthorizationInvalidatesOnChangedPoll() async throws {
        // A changed revision/context/provider or failed poll must revoke permission even before the next explicit action.
        let changes: [(inout Inspection) -> Void] = [
            { $0.revision = "changed-direct" },
            { $0.context?.providerId = "other" },
            { $0.provider.recordPhase = "restored" }
        ]
        for change in changes {
            let (controller, backend, _) = try idlePendingFixture()
            await controller.requestQuit()
            XCTAssertTrue(controller.canQuit)
            let original = backend.snapshot
            change(&backend.snapshot)
            await controller.refresh()
            XCTAssertFalse(controller.canQuit)
            backend.snapshot = original
            await controller.refresh()
            XCTAssertFalse(controller.canQuit)
            await controller.requestQuit()
            XCTAssertTrue(controller.canQuit)
            backend.inspectionError = .commandFailed
            await controller.refresh()
            XCTAssertFalse(controller.canQuit)
        }
    }

    func testIdleQuitAfterUnexpectedOwnedExitRequiresFreshEvidence() async throws {
        // An exited activated child retains recovery, and only a later fresh direct inspection grants idle permission.
        let controller = await activated()
        backend.exitChild()
        XCTAssertFalse(controller.canQuit)
        backend.snapshot.provider = .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "restored")
        backend.snapshot.revision = "direct-after-exit"
        await controller.requestQuit()
        XCTAssertTrue(controller.quitRequested)
        XCTAssertNotEqual(controller.desktopConfirmation, .confirmedDirect)
        XCTAssertNotNil(try store.readExisting().pending)
        XCTAssertEqual(backend.stopCount, 0)
    }

    func testQuitBlockReasonRecoveryAndBusyPriority() async {
        // In-flight or uncertain work must take precedence over later recovery instructions.
        let controller = await activated()
        XCTAssertEqual(controller.quitBlockReason, .directRecoveryRequired)
        XCTAssertFalse(controller.canQuit)
        backend.mutationRequiresReconciliation = true
        XCTAssertFalse(controller.mutationRequiresReconciliation)
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        backend.mutationRequiresReconciliation = false
        let barrier = Barrier<ControlResult>(); backend.controlBarrier = barrier
        let restore = Task { await controller.restoreDirect() }
        await waitUntil { barrier.waiting }
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        XCTAssertFalse(controller.canQuit); XCTAssertFalse(controller.quitRequested)
        backend.snapshot.provider.state = "direct"; backend.snapshot.provider.recordPhase = "restored"
        backend.snapshot.revision = "direct-after-held-restore"
        barrier.release(.init(state: "direct", changed: true, restartRequired: true)); await restore.value
        XCTAssertEqual(controller.quitBlockReason, .directConfirmationPending)
        backend.mutationRequiresReconciliation = true
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        backend.mutationRequiresReconciliation = false
        for phase in ["prepared", "active"] {
            backend.snapshot.provider.recordPhase = phase
            await controller.refresh()
            XCTAssertEqual(controller.quitBlockReason, .directRecoveryRequired)
            XCTAssertFalse(controller.canQuit)
        }
        backend.snapshot.provider.recordPhase = "none"; backend.snapshot.provider.recoveryRequired = true
        await controller.refresh()
        XCTAssertEqual(controller.quitBlockReason, .directRecoveryRequired)
        XCTAssertFalse(controller.canQuit); XCTAssertFalse(controller.quitRequested)
    }
    func testQuitBlockReasonUsesLiveBackendUncertainty() async {
        // A backend flag raised between refreshes must not expose stale safe-exit advice.
        let controller = makeController(); await controller.refresh()
        XCTAssertNil(controller.quitBlockReason); XCTAssertTrue(controller.canQuit)
        backend.mutationRequiresReconciliation = true
        XCTAssertFalse(controller.mutationRequiresReconciliation)
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        XCTAssertTrue(controller.canQuit)
        await controller.requestQuit()
        XCTAssertFalse(controller.quitRequested); XCTAssertFalse(controller.canQuit)
        backend.mutationRequiresReconciliation = false
        XCTAssertTrue(controller.mutationRequiresReconciliation)
        XCTAssertEqual(controller.quitBlockReason, .operationInProgress)
        await controller.refresh()
        XCTAssertNil(controller.quitBlockReason); XCTAssertTrue(controller.canQuit)
    }
    func testQuitBlockReasonUnavailableAndFailedStop() async throws {
        // Incomplete or conflicting evidence cannot prescribe a specific successful recovery step.
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath,
            pending: .init(context: context, phase: .directConfirmation)))
        let controller = makeController()
        XCTAssertEqual(controller.quitBlockReason, .contextUnavailable)
        XCTAssertFalse(controller.canQuit)
        var invalidConfiguration = backend.snapshot; invalidConfiguration.configuration.state = "unavailable"
        var unmatchedPath = backend.snapshot; unmatchedPath.configuration.path = "/synthetic/other.json"
        var missingContext = backend.snapshot; missingContext.context = nil
        var changedContext = backend.snapshot; changedContext.context?.codexHome = "/synthetic/changed"
        var unavailableProvider = backend.snapshot; unavailableProvider.provider.state = "unavailable"
        var conflictingProvider = backend.snapshot; conflictingProvider.provider.state = "conflict"
        var unavailableRecord = backend.snapshot; unavailableRecord.provider.recordPhase = "unavailable"
        var missingRevision = backend.snapshot; missingRevision.revision = nil
        for (name, snapshot) in [("configuration", invalidConfiguration), ("path", unmatchedPath),
            ("missing context", missingContext), ("changed context", changedContext),
            ("provider", unavailableProvider), ("conflict", conflictingProvider),
            ("record", unavailableRecord), ("revision", missingRevision)] {
            backend.snapshot = snapshot
            await controller.refresh()
            XCTAssertEqual(controller.quitBlockReason, .contextUnavailable, name)
            XCTAssertFalse(controller.canQuit, name); XCTAssertFalse(controller.quitRequested, name)
        }
        backend.inspectionError = .commandFailed
        await controller.refresh()
        XCTAssertEqual(controller.quitBlockReason, .contextUnavailable)
        XCTAssertFalse(controller.canQuit); XCTAssertFalse(controller.quitRequested)

        let failedStore = PrivateStore(directory: root.appendingPathComponent("failed-stop"))
        try failedStore.save(CompanionJournal(selectedConfigurationPath: context.configPath))
        let failedBackend = ControlledBackend(context: context)
        let failedController = RouterController(backend: failedBackend, store: failedStore, browseHome: root)
        await failedController.refresh(); await failedController.start()
        failedBackend.stopOutcome = .init(childExited: false, portState: .unknown)
        await failedController.requestQuit()
        XCTAssertEqual(failedController.quitBlockReason, .contextUnavailable)
        XCTAssertFalse(failedController.canQuit); XCTAssertFalse(failedController.quitRequested)
        XCTAssertNotNil(failedController.ownedRouter)
        XCTAssertEqual(failedBackend.stopCount, 1)
    }
    func testQuitBlockReasonPermittedExceptions() async throws {
        // Alert projection must preserve normal exits and safe failed-initialization/second-instance exits.
        let controller = makeController(); await controller.refresh()
        XCTAssertNil(controller.quitBlockReason); XCTAssertTrue(controller.canQuit)
        await controller.requestQuit()
        XCTAssertNil(controller.quitBlockReason); XCTAssertTrue(controller.quitRequested)

        let secondBackend = ControlledBackend(context: context)
        secondBackend.mutationRequiresReconciliation = true
        let second = RouterController(backend: secondBackend, store: PrivateStore(directory: store.directory), browseHome: root)
        XCTAssertEqual(second.error, CompanionError.instanceRunning.rawValue)
        XCTAssertNil(second.quitBlockReason); XCTAssertTrue(second.canQuit)
        await second.requestQuit()
        XCTAssertTrue(second.quitRequested)
        XCTAssertTrue(secondBackend.inspectedPaths.isEmpty); XCTAssertTrue(secondBackend.controls.isEmpty)
        XCTAssertEqual(secondBackend.stopCount, 0)

        let invalidStore = root.appendingPathComponent("invalid-store")
        try Data("SYNTHETIC_PRIVATE_SENTINEL".utf8).write(to: invalidStore)
        let failedBackend = ControlledBackend(context: context)
        failedBackend.mutationRequiresReconciliation = true
        let failed = RouterController(backend: failedBackend, store: PrivateStore(directory: invalidStore), browseHome: root)
        XCTAssertEqual(failed.error, CompanionError.privateState.rawValue)
        XCTAssertNil(failed.quitBlockReason); XCTAssertTrue(failed.canQuit)
        await failed.requestQuit()
        XCTAssertTrue(failed.quitRequested)
        XCTAssertTrue(failedBackend.inspectedPaths.isEmpty); XCTAssertTrue(failedBackend.controls.isEmpty)
        XCTAssertEqual(failedBackend.stopCount, 0)
    }
    func testActionWaitsForRefreshAndUsesItsOwnFreshInspection() async {
        // A pre-action poll cannot authorize an action or allow a second simultaneous backend inspection.
        let controller = await started()
        let oldReady = backend.snapshot
        let baseline = backend.inspectedPaths.count
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = false
        var actionStarted = false
        let activation = Task { actionStarted = true; await controller.activate() }
        await waitUntil { actionStarted }
        for _ in 0..<20 { await controller.refresh() }
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        XCTAssertEqual(backend.inspectedPaths.count, baseline + 1)
        barrier.release(oldReady)
        await refresh.value; await activation.value
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        XCTAssertLessThanOrEqual(backend.inspectedPaths.count, baseline + 3)
        XCTAssertEqual(controller.inspection?.provider.proxyReady, false)
        XCTAssertTrue(backend.controls.isEmpty)
    }
    func testActionCanActivateAfterWaitingForFreshPostRefreshEvidence() async {
        // Serializing inspection must not reject an otherwise valid action merely because an older poll existed.
        let controller = await started()
        var oldNotReady = backend.snapshot; oldNotReady.provider.proxyReady = false
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        let activation = Task { await controller.activate() }
        await waitUntil { controller.busy }
        for _ in 0..<20 { await controller.refresh() }
        barrier.release(oldNotReady)
        await refresh.value; await activation.value
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        XCTAssertEqual(backend.controls.count, 1)
        XCTAssertEqual(backend.controls.first?.1, context)
        XCTAssertEqual(controller.inspection?.provider.state, "router")
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
    }
    func testStartupInspectionCannotOverlapCoalescedRefresh() async {
        // ProcessBackend.start performs inspections internally; polling must share its inspection slot too.
        let controller = makeController(); await controller.refresh()
        let barrier = Barrier<Inspection>(); backend.startInspectionBarrier = barrier
        let start = Task { await controller.start() }
        await waitUntil { barrier.waiting }
        var refreshStarted = false
        let refresh = Task { refreshStarted = true; await controller.refresh() }
        await waitUntil { refreshStarted }
        for _ in 0..<20 { await controller.refresh() }
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        barrier.release(backend.snapshot)
        await start.value; await refresh.value
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        XCTAssertNotNil(controller.ownedRouter)
    }
    func testQueuedPollingDoesNotPreventStart() async {
        let controller = makeController(); await controller.refresh()
        XCTAssertTrue(controller.canStart)
        await withQueuedPolling(controller) { await controller.start() }
        XCTAssertEqual(backend.startCount, 1)
        XCTAssertNotNil(controller.ownedRouter)
        XCTAssertNil(controller.error)
    }
    func testQueuedPollingDoesNotPreventActivation() async {
        let controller = await started()
        await withQueuedPolling(controller) { await controller.activate() }
        XCTAssertEqual(backend.controls.count, 1)
        XCTAssertEqual(controller.inspection?.provider.state, "router")
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
        XCTAssertNil(controller.error)
    }
    func testQueuedPollingDoesNotPreventDirectRestoration() async throws {
        let controller = await activated()
        await withQueuedPolling(controller) { await controller.restoreDirect() }
        XCTAssertEqual(backend.controls.count, 2)
        XCTAssertEqual(backend.controls.last?.0, .rollback)
        XCTAssertEqual(controller.inspection?.provider.state, "direct")
        XCTAssertEqual(try store.load().pending?.phase, .directConfirmation)
        XCTAssertNil(controller.error)
    }
    func testQueuedPollingDoesNotPreventRoutedConfirmation() async {
        let controller = await activated()
        await withQueuedPolling(controller) { await controller.confirmRoutedResponse() }
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertNil(controller.error)
    }
    func testQueuedPollingDoesNotPreventDirectConfirmation() async throws {
        let controller = await activated(); await controller.restoreDirect()
        await withQueuedPolling(controller) { await controller.confirmDirectResponse() }
        XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
        XCTAssertNil(try store.load().pending)
        XCTAssertTrue(controller.canStop)
        XCTAssertNil(controller.error)
    }
    func testQueuedPollingDoesNotPreventStop() async {
        let controller = await started()
        await withQueuedPolling(controller) { await controller.stop() }
        XCTAssertEqual(backend.stopCount, 1)
        XCTAssertNil(controller.ownedRouter)
        XCTAssertTrue(controller.canQuit)
        XCTAssertNil(controller.error)
    }
    func testQueuedPollingDoesNotPreventQuit() async {
        let controller = makeController(); await controller.refresh()
        await withQueuedPolling(controller) { await controller.requestQuit() }
        XCTAssertTrue(controller.quitRequested)
        XCTAssertTrue(controller.canQuit)
        XCTAssertNil(controller.error)
    }
    private func withQueuedPolling(_ controller: RouterController, backend fixtureBackend: ControlledBackend? = nil, action: @escaping () async -> Void) async {
        let backend = fixtureBackend ?? self.backend!
        // Queuing timer requests is not newer evidence and cannot discard this unchanged action inspection.
        let baseline = backend.inspectedPaths.count
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let operation = Task { await action() }
        await waitUntil { barrier.waiting }
        var pollStarted = false
        let poll = Task { pollStarted = true; await controller.refresh() }
        await waitUntil { pollStarted }
        for _ in 0..<20 { await controller.refresh() }
        barrier.release(backend.snapshot)
        await operation.value; await poll.value
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        XCTAssertLessThanOrEqual(backend.inspectedPaths.count, baseline + 4)
    }
    func testConfirmationPresentationGuardsFollowFreshContextAndReconciliation() async {
        let controller = await activated()
        XCTAssertTrue(controller.canSelectNode)
        XCTAssertTrue(controller.canConfirmRoutedResponse)
        XCTAssertFalse(controller.canConfirmDirectResponse)
        backend.mutationRequiresReconciliation = true
        await controller.refresh()
        XCTAssertFalse(controller.canConfirmRoutedResponse)
        backend.mutationRequiresReconciliation = false
        await controller.restoreDirect()
        XCTAssertFalse(controller.canConfirmRoutedResponse)
        XCTAssertTrue(controller.canConfirmDirectResponse)
        backend.snapshot.context?.codexHome = "/synthetic/changed"
        await controller.refresh()
        XCTAssertFalse(controller.canConfirmDirectResponse)
        backend.snapshot.context = context
        await controller.refresh()
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let confirmation = Task { await controller.confirmDirectResponse() }
        await waitUntil { barrier.waiting }
        XCTAssertFalse(controller.canConfirmDirectResponse)
        XCTAssertFalse(controller.canSelectNode)
        barrier.release(backend.snapshot); await confirmation.value
    }
    func testNoChangeRollbackKeepsConfirmationPending() async throws {
        // Clearing obligation from rollback success/no-change would stop a still-required listener.
        let controller = await activated()
        await controller.restoreDirect(); await controller.restoreDirect()
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(try store.load().pending?.phase, .directConfirmation)
        await controller.confirmDirectResponse()
        XCTAssertTrue(controller.canStop)
        XCTAssertFalse(controller.canQuit)
        await controller.requestQuit()
        XCTAssertTrue(controller.canQuit); XCTAssertTrue(controller.quitRequested)
    }
    func testActivationAttemptPersistsBeforeMutation() async throws {
        // Moving the journal write after control would leave a crash window with no recovery intent.
        let controller = await started()
        var recorded: CompanionJournal.Pending?
        backend.onControl = { _, expected in
            recorded = try self.store.load().pending
            XCTAssertEqual(recorded?.context, expected)
            XCTAssertEqual(recorded?.phase, .activationAttempt)
        }
        await controller.activate()
        XCTAssertEqual(recorded?.phase, .activationAttempt)
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
        XCTAssertFalse(controller.canStop)
    }
    func testLateRefreshCannotReplaceRecoveryContext() async throws {
        // Applying a pre-restore poll after recovery would replace the disk/recovery facts.
        let controller = await activated()
        let old = backend.snapshot
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        let restore = Task { await controller.restoreDirect() }
        await waitUntil { controller.busy }
        barrier.release(old); await refresh.value; await restore.value
        XCTAssertEqual(controller.inspection?.provider.state, "direct")
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(controller.recoveryContext, context)
    }
    func testRefreshCoalescesRequestsAndRechecksCurrentSelection() async throws {
        // Concurrent refresh clicks must coalesce and inspect the new selection after stale work.
        let controller = makeController()
        let old = backend.snapshot
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let first = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        await controller.refresh(); await controller.refresh()
        let another = URL(fileURLWithPath: "/synthetic/another.json")
        var next = old; next.context?.configPath = another.path; next.configuration.path = another.path
        backend.snapshot = next
        let selection = Task { await controller.selectConfiguration(another) }
        await waitUntil { controller.busy }
        barrier.release(old); await first.value; await selection.value
        XCTAssertEqual(controller.selectedConfiguration, another)
        XCTAssertEqual(controller.inspection?.context?.configPath, another.path)
        XCTAssertEqual(backend.inspectedPaths.count, 2)
        XCTAssertEqual(backend.inspectedPaths.last!, another)
    }
    func testRelaunchPrioritizesPendingProfile() async throws {
        // Normal-path discovery must never supersede an imported pending recovery profile.
        let pending = CompanionJournal.Pending(context: context, phase: .directConfirmation)
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath, pending: pending))
        try Data("normal".utf8).write(to: root.appendingPathComponent("config.json"))
        backend.snapshot.provider.recordPhase = "restored"
        backend.snapshot.provider.proxyReady = true
        let controller = makeController()
        XCTAssertEqual(controller.desktopConfirmation, .unknown)
        await controller.refresh()
        XCTAssertEqual(controller.selectedConfiguration?.path, context.configPath)
        XCTAssertNil(controller.ownedRouter)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
        XCTAssertTrue(controller.needsManualListenerCleanup)
        await controller.confirmDirectResponse()
        XCTAssertTrue(controller.canQuit)
        XCTAssertTrue(controller.needsManualListenerCleanup)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertNil(try store.load().pending)
    }
    func testRecoveredProbeDoesNotReconfirmDesktop() async throws {
        // A recovered health probe must not reinstate a confirmation invalidated by readiness loss.
        let controller = await activated()
        await controller.confirmRoutedResponse()
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        backend.snapshot.provider.proxyReady = false
        await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
        backend.snapshot.provider.proxyReady = true
        await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
        XCTAssertFalse(controller.canStop)
    }
    func testExternalListenerCannotAuthorizeActivationOrStop() async {
        // Matching readiness without a retained child must never confer signalling/mutation authority.
        backend.snapshot.provider.proxyReady = true
        let controller = makeController(); await controller.refresh()
        await controller.activate(); await controller.start(); await controller.stop()
        XCTAssertTrue(controller.needsManualListenerCleanup)
        XCTAssertEqual(backend.controls.count, 0); XCTAssertEqual(backend.startCount, 0); XCTAssertEqual(backend.stopCount, 0)
        XCTAssertNil(controller.ownedRouter)
    }
    func testDuplicateMutationAndContextSwitchAreRejectedWhileHeld() async {
        // Re-entry while a helper is held must not launch a second write or replace its context.
        let controller = await started()
        let barrier = Barrier<ControlResult>(); backend.controlBarrier = barrier
        let activation = Task { await controller.activate() }
        await waitUntil { barrier.waiting }
        await controller.activate(); await controller.restoreDirect(); await controller.start()
        await controller.selectConfiguration(URL(fileURLWithPath: "/synthetic/other.json"))
        await controller.requestQuit()
        XCTAssertTrue(controller.busy); XCTAssertFalse(controller.quitRequested)
        XCTAssertEqual(backend.controls.count, 1); XCTAssertEqual(controller.selectedConfiguration?.path, context.configPath)
        backend.snapshot.provider.state = "router"; backend.snapshot.provider.recordPhase = "active"; backend.snapshot.revision = "routed-2"
        barrier.release(.init(state: "active", changed: true, restartRequired: true)); await activation.value
        XCTAssertFalse(controller.busy); XCTAssertEqual(controller.desktopConfirmation, .routedPending)
    }
    func testRuntimeReplacementDuringRecoveryRetainsBinding() async throws {
        // Choosing a replacement runtime must preserve the exact pending context and owned handle.
        let controller = await activated()
        let child = controller.ownedRouter
        backend.inspectionError = .nodeUnavailable
        await controller.refresh()
        XCTAssertEqual(controller.recoveryContext, context)
        XCTAssertFalse(controller.canQuit)
        backend.inspectionError = nil
        let node = URL(fileURLWithPath: "/synthetic/new node")
        await controller.selectNode(node)
        XCTAssertTrue(controller.ownedRouter === child)
        XCTAssertEqual(try store.load().pending?.context, context)
        XCTAssertEqual(try store.load().nodeExecutablePath, node.path)
        await controller.restoreDirect()
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
    }
    func testRelevantMappingEditInvalidatesConfirmationWithoutRetargetingRollback() async throws {
        // A new revision invalidates response confirmation, while same-context mappings allow rollback.
        let controller = await activated(); await controller.confirmRoutedResponse()
        backend.snapshot.revision = "mapping-edited"
        await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
        await controller.restoreDirect()
        XCTAssertEqual(backend.controls.last?.0, .rollback)
        XCTAssertEqual(backend.controls.last?.1, context)
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
    }
    func testChangedHomeCannotRetargetPendingRecovery() async throws {
        // A same-path config with a new home/provider/port is not the old activation's recovery.
        let controller = await activated()
        backend.snapshot.context?.codexHome = "/synthetic/different-home"
        backend.snapshot.revision = "context-edited"
        await controller.restoreDirect()
        XCTAssertEqual(backend.controls.count, 1)
        XCTAssertEqual(controller.recoveryContext, context)
        XCTAssertEqual(try store.load().pending?.context, context)
        XCTAssertFalse(controller.canSelectConfiguration); XCTAssertFalse(controller.canQuit)
    }
    func testRollbackBeforeAndAfterExternalURLChange() async throws {
        // Rollback failure after an external URL edit must preserve both obligation and readable catalog.
        let controller = await activated()
        backend.snapshot.provider.state = "conflict"; backend.snapshot.revision = "url-edited"
        backend.snapshot.catalog.entries = [.init(id: "synthetic-project", name: "Readable project", routeAlias: nil, routeState: "unmapped")]
        backend.controlError = .mutationUncertain
        await controller.restoreDirect()
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(controller.inspection?.provider.state, "conflict")
        XCTAssertEqual(controller.inspection?.catalog.entries.count, 1)
        XCTAssertEqual(try store.load().pending?.phase, .restoring)
        XCTAssertFalse(controller.canStop); XCTAssertNotNil(controller.error)
        backend.controlError = nil
        backend.snapshot.provider.state = "router"; backend.snapshot.revision = "url-returned"
        await controller.restoreDirect()
        XCTAssertEqual(controller.inspection?.provider.state, "direct")
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
    }
    func testFailedActivationReconcilesActualDiskAndKeepsObligation() async throws {
        // A thrown helper error is not proof that the provider remained direct.
        let controller = await started()
        backend.onControl = { _, _ in
            self.backend.snapshot.provider.state = "router"
            self.backend.snapshot.provider.recordPhase = "prepared"
            self.backend.snapshot.revision = "partial-activation"
        }
        backend.controlError = .mutationUncertain
        await controller.activate()
        XCTAssertEqual(controller.inspection?.provider.state, "router")
        XCTAssertEqual(try store.load().pending?.phase, .activationAttempt)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
        XCTAssertNotNil(controller.error)
    }
    func testInterruptedRestoreRelaunchStillNeedsExplicitConfirmation() async throws {
        // Relaunch cannot infer a user's restart/response confirmation from already-direct disk state.
        var controller: RouterController? = await activated()
        backend.onControl = { action, _ in
            if action == .rollback {
                self.backend.snapshot.provider.state = "direct"
                self.backend.snapshot.provider.recordPhase = "restored"
                self.backend.snapshot.provider.proxyReady = true
                self.backend.snapshot.revision = "restored-after-error"
            }
        }
        backend.controlError = .mutationUncertain
        await controller?.restoreDirect()
        XCTAssertEqual(try store.load().pending?.phase, .restoring)
        controller = nil; store.releaseInstanceLock()
        let reloaded = RouterController(backend: backend, store: PrivateStore(directory: store.directory), browseHome: URL(fileURLWithPath: "/synthetic/normal"))
        await reloaded.refresh()
        XCTAssertEqual(reloaded.desktopConfirmation, .unknown)
        XCTAssertFalse(reloaded.canQuit); XCTAssertNil(reloaded.ownedRouter)
        await reloaded.confirmDirectResponse()
        XCTAssertEqual(reloaded.desktopConfirmation, .confirmedDirect)
        XCTAssertTrue(reloaded.canQuit); XCTAssertTrue(reloaded.needsManualListenerCleanup)
        XCTAssertEqual(backend.stopCount, 0)
    }
    func testChildDeathDuringActivationKeepsRecovery() async throws {
        // An exit callback cannot erase the recovery intent while a provider helper is suspended.
        let controller = await started()
        let activationBarrier = Barrier<ControlResult>(); backend.controlBarrier = activationBarrier
        let activation = Task { await controller.activate() }
        await waitUntil { activationBarrier.waiting }
        backend.exitChild()
        backend.snapshot.provider.state = "router"; backend.snapshot.provider.recordPhase = "active"; backend.snapshot.provider.proxyReady = false
        activationBarrier.release(.init(state: "active", changed: true, restartRequired: true)); await activation.value
        XCTAssertNil(controller.ownedRouter); XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(try store.load().pending?.phase, .routedConfirmation)
        let rollbackBarrier = Barrier<ControlResult>(); backend.controlBarrier = rollbackBarrier
        let rollback = Task { await controller.restoreDirect() }
        await waitUntil { rollbackBarrier.waiting }
        backend.snapshot.provider.state = "direct"; backend.snapshot.provider.recordPhase = "restored"
        rollbackBarrier.release(.init(state: "direct", changed: true, restartRequired: true)); await rollback.value
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertFalse(controller.canQuit)
        await controller.confirmDirectResponse()
        XCTAssertTrue(controller.canQuit)
    }
    func testExplicitConfirmationRejectsRevisionOrChildChangeWhileInspecting() async {
        // A click on an older view cannot confirm a concurrently changed revision or dead router.
        let controller = await activated()
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let confirmation = Task { await controller.confirmRoutedResponse() }
        await waitUntil { barrier.waiting }
        backend.exitChild()
        var changed = backend.snapshot; changed.revision = "changed-during-confirmation"
        barrier.release(changed); await confirmation.value
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
        XCTAssertFalse(controller.canQuit)
    }
    func testPendingDirectConfirmationRequiresReadableDirectSnapshot() async {
        // Unavailable direct evidence must leave the explicit confirmation pending even after recovery.
        let controller = await activated(); await controller.restoreDirect()
        backend.snapshot.provider.state = "unavailable"; backend.snapshot.provider.recordPhase = "unavailable"; backend.snapshot.revision = nil
        await controller.confirmDirectResponse()
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        backend.snapshot.provider.state = "direct"; backend.snapshot.provider.recordPhase = "restored"; backend.snapshot.revision = "direct-again"
        await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .directPending); XCTAssertFalse(controller.canStop)
        await controller.confirmDirectResponse()
        XCTAssertTrue(controller.canStop)
    }
    func testNeverActivatedDirectChildCanStopAndQuitWaitsForExitAndPort() async {
        // Quit must await stop completion and its independent port result, even in the direct-only exception.
        let controller = await started()
        XCTAssertTrue(controller.canStop)
        let barrier = Barrier<StopOutcome>(); backend.stopBarrier = barrier
        let quit = Task { await controller.requestQuit() }
        await waitUntil { barrier.waiting }
        await controller.requestQuit(); await controller.stop()
        XCTAssertFalse(controller.quitRequested); XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(backend.stopCount, 1)
        barrier.release(.init(childExited: true, portState: .occupied)); await quit.value
        XCTAssertTrue(controller.quitRequested); XCTAssertTrue(controller.canQuit)
        XCTAssertEqual(controller.lastStopOutcome?.portState, .occupied)
        XCTAssertTrue(controller.needsManualListenerCleanup); XCTAssertNotNil(controller.error)
        await controller.stop(); await controller.requestQuit()
        XCTAssertEqual(backend.stopCount, 1)
    }
    func testFailedOrUnknownStopRemainsVisible() async {
        // A stop that has not observed child exit cannot authorize Quit.
        let controller = await started()
        backend.stopOutcome = .init(childExited: false, portState: .unknown)
        await controller.requestQuit()
        XCTAssertFalse(controller.quitRequested); XCTAssertFalse(controller.canQuit)
        XCTAssertNotNil(controller.ownedRouter); XCTAssertNotNil(controller.error)
        XCTAssertEqual(controller.lastStopOutcome?.portState, .unknown)
        backend.stopOutcome = .init(childExited: true, portState: .unknown)
        await controller.stop()
        XCTAssertNil(controller.ownedRouter); XCTAssertNotNil(controller.error)
        XCTAssertEqual(controller.lastStopOutcome?.portState, .unknown)
    }
    func testMalformedJournalAndSecondInstanceFailWithoutMutation() async throws {
        // A corrupt journal or missing lock must never trigger normal discovery or overwrite evidence.
        let controller = makeController(); await controller.refresh()
        let original = try Data(contentsOf: store.directory.appendingPathComponent("state.json"))
        let second = RouterController(backend: ControlledBackend(context: context), store: PrivateStore(directory: store.directory), browseHome: root)
        await second.refresh(); await second.activate()
        XCTAssertEqual(second.error, CompanionError.instanceRunning.rawValue)
        XCTAssertFalse(second.canSelectNode)
        XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), original)
        let malformedRoot = root.appendingPathComponent("corrupt")
        let malformedStore = PrivateStore(directory: malformedRoot); _ = try malformedStore.load()
        let corrupt = Data("{broken PRIVATE_SENTINEL".utf8)
        try corrupt.write(to: malformedRoot.appendingPathComponent("state.json"))
        let failedBackend = ControlledBackend(context: context)
        let failed = RouterController(backend: failedBackend, store: malformedStore, browseHome: root)
        let entries = try FileManager.default.contentsOfDirectory(atPath: malformedRoot.path)
        await assertInitializationFailureAllowsOnlyQuit(failed, backend: failedBackend)
        XCTAssertEqual(try Data(contentsOf: malformedRoot.appendingPathComponent("state.json")), corrupt)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: malformedRoot.path), entries)
    }
    func testUnsafeStoreInitializationAllowsQuitWithoutMutation() async throws {
        // Failure before acquiring a safe store cannot launch a helper or create new journal evidence.
        let unsafeRoot = root.appendingPathComponent("unsafe")
        try FileManager.default.createDirectory(at: unsafeRoot, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])
        let state = unsafeRoot.appendingPathComponent("state.json")
        let original = Data("UNSAFE_PRIVATE_SENTINEL".utf8)
        try original.write(to: state)
        let failedBackend = ControlledBackend(context: context)
        let failed = RouterController(backend: failedBackend, store: PrivateStore(directory: unsafeRoot), browseHome: root)
        await assertInitializationFailureAllowsOnlyQuit(failed, backend: failedBackend)
        XCTAssertEqual(try Data(contentsOf: state), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: unsafeRoot.path), ["state.json"])
        let attributes = try FileManager.default.attributesOfItem(atPath: unsafeRoot.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o755)
    }
    private func assertInitializationFailureAllowsOnlyQuit(_ failed: RouterController, backend: ControlledBackend,
                                                          file: StaticString = #filePath, line: UInt = #line) async {
        XCTAssertNil(failed.selectedConfiguration, file: file, line: line)
        XCTAssertNil(failed.ownedRouter, file: file, line: line)
        XCTAssertFalse(failed.canSelectConfiguration, file: file, line: line)
        XCTAssertFalse(failed.canSelectNode, file: file, line: line)
        XCTAssertFalse(failed.canStart, file: file, line: line)
        XCTAssertFalse(failed.canActivate, file: file, line: line)
        XCTAssertFalse(failed.canRestoreDirect, file: file, line: line)
        XCTAssertFalse(failed.canConfirmRoutedResponse, file: file, line: line)
        XCTAssertFalse(failed.canConfirmDirectResponse, file: file, line: line)
        XCTAssertFalse(failed.canStop, file: file, line: line)
        XCTAssertTrue(failed.canQuit, file: file, line: line)
        await failed.refresh(); await failed.selectConfiguration(URL(fileURLWithPath: context.configPath))
        await failed.selectNode(URL(fileURLWithPath: "/synthetic/node"))
        await failed.start(); await failed.activate(); await failed.restoreDirect()
        await failed.confirmRoutedResponse(); await failed.confirmDirectResponse(); await failed.stop()
        await failed.requestQuit()
        XCTAssertTrue(failed.quitRequested, file: file, line: line)
        XCTAssertTrue(failed.canQuit, file: file, line: line)
        XCTAssertEqual(failed.error, CompanionError.privateState.rawValue, file: file, line: line)
        XCTAssertFalse(failed.error?.contains("SENTINEL") ?? true, file: file, line: line)
        XCTAssertTrue(backend.inspectedPaths.isEmpty, file: file, line: line)
        XCTAssertTrue(backend.validatedNodes.isEmpty, file: file, line: line)
        XCTAssertNil(backend.executable, file: file, line: line)
        XCTAssertEqual(backend.startCount, 0, file: file, line: line)
        XCTAssertTrue(backend.controls.isEmpty, file: file, line: line)
        XCTAssertEqual(backend.stopCount, 0, file: file, line: line)
    }
    func testJournalWriteFailureBlocksNewMutationAndPreservesPriorObligation() async throws {
        // Ignoring a failed intent save would mutate without crash-recoverable authority.
        let controller = await activated()
        let state = store.directory.appendingPathComponent("state.json")
        let original = try Data(contentsOf: state)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: state.path)
        await controller.restoreDirect()
        XCTAssertEqual(backend.controls.count, 1)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.error, CompanionError.privateState.rawValue)
        XCTAssertEqual(try Data(contentsOf: state), original)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: state.path)
    }
    func testNormalDiscoveryOnlyWhenNoSavedSelectionAndExistingFile() async throws {
        // Missing normal config permits catalog browsing; an existing normal config is inspected in place.
        try store.save(CompanionJournal())
        var controller: RouterController? = makeController()
        await controller?.refresh()
        XCTAssertNil(backend.inspectedPaths.last!)
        XCTAssertNil(controller?.selectedConfiguration)
        controller = nil; store.releaseInstanceLock()
        let normal = root.appendingPathComponent("config.json")
        try Data("synthetic-existing-only".utf8).write(to: normal)
        controller = makeController(); await controller?.refresh()
        XCTAssertEqual(backend.inspectedPaths.last!, normal)
        XCTAssertEqual(try Data(contentsOf: normal), Data("synthetic-existing-only".utf8))
        XCTAssertEqual(backend.startCount, 0); XCTAssertEqual(backend.controls.count, 0)
    }
    func testOwnedReadinessTimeoutDoesNotAuthorizeActivation() async {
        // A returned live handle without fresh readiness cannot be treated as a successful start.
        backend.startBecomesReady = false
        let controller = await started()
        XCTAssertNotNil(controller.ownedRouter)
        XCTAssertFalse(controller.canActivate)
        await controller.activate()
        XCTAssertEqual(backend.controls.count, 0)
    }
    func testSuccessfulStopDoesNotReopenRecoveryOnExpectedReadinessLoss() async {
        // Observing the requested teardown after a confirmed stop must not fabricate a new desktop dependency.
        let controller = await activated(); await controller.restoreDirect(); await controller.confirmDirectResponse()
        await controller.stop()
        backend.snapshot.provider.proxyReady = false
        await controller.refresh()
        XCTAssertTrue(controller.canQuit)
        XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
    }

    func testLaterObservedRouterStateInvalidatesQueuedDirectConfirmation() async throws {
        // A poll that actually observes reactivation must reopen recovery after an unchanged confirmation read.
        let controller = await activated(); await controller.restoreDirect()
        let oldDirect = backend.snapshot
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let confirmation = Task { await controller.confirmDirectResponse() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.state = "router"; backend.snapshot.provider.recordPhase = "active"; backend.snapshot.revision = "external-reactivation"
        let refresh = Task { await controller.refresh() }
        await Task.yield()
        barrier.release(oldDirect); await confirmation.value; await refresh.value
        XCTAssertEqual(controller.inspection?.provider.state, "router")
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertNotNil(try store.load().pending)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
    }
    func testConfirmationRejectsChangedRevisionWhenPollingIsQueued() async throws {
        // Changed evidence returned by confirmation must retain recovery even while timer requests are queued.
        let controller = await activated(); await controller.restoreDirect()
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let confirmation = Task { await controller.confirmDirectResponse() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.state = "router"; backend.snapshot.provider.recordPhase = "active"; backend.snapshot.revision = "external-reactivation"
        let refresh = Task { await controller.refresh() }
        await Task.yield()
        barrier.release(backend.snapshot); await confirmation.value; await refresh.value
        XCTAssertEqual(controller.inspection?.provider.state, "router")
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertNotNil(try store.load().pending)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
    }
    func testActivationRejectsReadinessLossWhenPollingIsQueued() async {
        // A held action inspection returning lost readiness cannot authorize activation, regardless of queued polls.
        let controller = await started()
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let activation = Task { await controller.activate() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = false
        let refresh = Task { await controller.refresh() }
        await Task.yield()
        barrier.release(backend.snapshot); await activation.value; await refresh.value
        XCTAssertEqual(backend.controls.count, 0)
        XCTAssertEqual(controller.inspection?.provider.proxyReady, false)
    }

    func testUncertainLiveMutationCannotBeConfirmedOrCleanedUp() async throws {
        // Direct disk state while the timed-out writer can still change it must never release the listener.
        let controller = await started()
        backend.onControl = { _, _ in self.backend.mutationRequiresReconciliation = true }
        backend.controlError = .mutationUncertain
        await controller.activate()
        await controller.confirmDirectResponse()
        XCTAssertNotEqual(controller.desktopConfirmation, .confirmedDirect)
        XCTAssertNotNil(try store.load().pending)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
        await controller.stop(); await controller.requestQuit()
        XCTAssertEqual(backend.stopCount, 0); XCTAssertFalse(controller.quitRequested)
        // A later post-exit fresh reconciliation permits a new explicit confirmation, never a poll alone.
        backend.mutationRequiresReconciliation = false
        await controller.refresh()
        XCTAssertNotEqual(controller.desktopConfirmation, .confirmedDirect)
        await controller.confirmDirectResponse()
        XCTAssertTrue(controller.canStop)
    }
    func testQuitWithoutOwnedChildRechecksExternalProviderState() async {
        // External provider activation after a harmless direct session must be imported before Quit.
        let controller = makeController(); await controller.refresh()
        backend.snapshot.provider.state = "router"; backend.snapshot.provider.recordPhase = "active"; backend.snapshot.revision = "external-new-activation"
        await controller.requestQuit()
        XCTAssertFalse(controller.quitRequested); XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.inspection?.provider.state, "router")
    }

    func testChildDeathDuringRollbackKeepsDirectConfirmationPending() async throws {
        // An unexpected owned-child exit during rollback cannot authorize Quit from direct disk alone.
        let controller = await activated()
        let barrier = Barrier<ControlResult>(); backend.controlBarrier = barrier
        let restore = Task { await controller.restoreDirect() }
        await waitUntil { barrier.waiting }
        backend.exitChild()
        backend.snapshot.provider.state = "direct"; backend.snapshot.provider.recordPhase = "restored"; backend.snapshot.provider.proxyReady = false
        backend.snapshot.revision = "direct-after-child-death"
        barrier.release(.init(state: "direct", changed: true, restartRequired: true)); await restore.value
        XCTAssertNil(controller.ownedRouter)
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(try store.load().pending?.phase, .directConfirmation)
        XCTAssertFalse(controller.canQuit)
        await controller.confirmDirectResponse()
        XCTAssertTrue(controller.canQuit)
    }
    func testNoChangeRestoreOfNeverActivatedDirectSessionKeepsSafeStopException() async throws {
        // A no-change rollback that proves no dependency must not turn a start-only session into activation.
        let controller = await started()
        await controller.restoreDirect()
        XCTAssertTrue(controller.canStop)
        XCTAssertNil(try store.load().pending)
        await controller.requestQuit()
        XCTAssertTrue(controller.quitRequested)
    }

    func testUnexpectedExitDoesNotPresentCachedOwnedReadinessAsExternalListener() async {
        // Readiness observed before child death is stale, not proof of a surviving external listener.
        let controller = await activated()
        backend.exitChild()
        XCTAssertNil(controller.inspection?.provider.proxyReady)
        XCTAssertFalse(controller.needsManualListenerCleanup)
        XCTAssertFalse(controller.canQuit)
        backend.snapshot.provider.proxyReady = true
        await controller.refresh()
        XCTAssertTrue(controller.needsManualListenerCleanup)
        XCTAssertNil(controller.inspection?.revision)
    }

    func testHeldStopReadinessLossDoesNotReopenRecovery() async throws {
        // Refresh can observe the requested teardown before stop's independent port result returns.
        let controller = await activated(); await controller.restoreDirect(); await controller.confirmDirectResponse()
        let barrier = Barrier<StopOutcome>(); backend.stopBarrier = barrier
        let stop = Task { await controller.stop() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = false
        await controller.refresh(); await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
        XCTAssertNil(try store.load().pending)
        XCTAssertFalse(controller.canQuit)
        barrier.release(.init(childExited: true, portState: .empty)); await stop.value
        XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
        XCTAssertNil(try store.load().pending)
        XCTAssertTrue(controller.canQuit)
        XCTAssertEqual(controller.lastStopOutcome, .init(childExited: true, portState: .empty))
        await controller.requestQuit()
        XCTAssertTrue(controller.quitRequested)
    }
    func testHeldQuitReadinessLossPreservesIndependentPortOutcomes() async throws {
        // Successful child exit permits Quit while occupied/unknown port results remain separate visible facts.
        for portState in [StopOutcome.PortState.empty, .occupied, .unknown] {
            store = PrivateStore(directory: root.appendingPathComponent(portState.rawValue))
            try store.save(CompanionJournal(selectedConfigurationPath: context.configPath))
            backend = ControlledBackend(context: context)
            let controller = await activated(); await controller.restoreDirect(); await controller.confirmDirectResponse()
            let barrier = Barrier<StopOutcome>(); backend.stopBarrier = barrier
            let quit = Task { await controller.requestQuit() }
            await waitUntil { barrier.waiting }
            backend.snapshot.provider.proxyReady = false
            backend.exitChild()
            await controller.refresh()
            XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
            XCTAssertNil(try store.load().pending)
            XCTAssertFalse(controller.quitRequested); XCTAssertFalse(controller.canQuit)
            barrier.release(.init(childExited: true, portState: portState)); await quit.value
            XCTAssertTrue(controller.quitRequested); XCTAssertTrue(controller.canQuit)
            XCTAssertEqual(controller.lastStopOutcome?.portState, portState)
            if portState == .empty { XCTAssertNil(controller.error) }
            else { XCTAssertNotNil(controller.error) }
            XCTAssertEqual(controller.needsManualListenerCleanup, portState == .occupied)
        }
    }
    func testHeldStopStillInvalidatesConfirmationForRevisionChange() async throws {
        // Requested readiness loss cannot suppress a concurrent relevant revision change.
        let controller = await activated(); await controller.restoreDirect(); await controller.confirmDirectResponse()
        let barrier = Barrier<StopOutcome>(); backend.stopBarrier = barrier
        let stop = Task { await controller.stop() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = false
        backend.snapshot.revision = "changed-during-stop"
        await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(try store.load().pending?.context, context)
        barrier.release(.init(childExited: true, portState: .empty)); await stop.value
        XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(controller.lastStopOutcome?.portState, .empty)
    }
    func testHeldQuitStillInvalidatesConfirmationForContextChange() async throws {
        // A changed home/provider/port during requested teardown retains the original recovery binding.
        let controller = await activated(); await controller.restoreDirect(); await controller.confirmDirectResponse()
        let barrier = Barrier<StopOutcome>(); backend.stopBarrier = barrier
        let quit = Task { await controller.requestQuit() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = false
        backend.snapshot.context?.codexHome = "/synthetic/changed-during-quit"
        await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(try store.load().pending?.context, context)
        barrier.release(.init(childExited: true, portState: .occupied)); await quit.value
        XCTAssertFalse(controller.quitRequested); XCTAssertFalse(controller.canQuit)
        XCTAssertEqual(controller.recoveryContext, context)
        XCTAssertEqual(controller.lastStopOutcome?.portState, .occupied)
        XCTAssertNotNil(controller.error)
    }
    func testFailedHeldStopReadinessLossRetainsRecovery() async throws {
        // Only verified requested exit consumes readiness loss; a failed stop keeps recovery conservative.
        let controller = await activated(); await controller.restoreDirect(); await controller.confirmDirectResponse()
        let barrier = Barrier<StopOutcome>(); backend.stopBarrier = barrier
        let stop = Task { await controller.stop() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = false
        await controller.refresh()
        barrier.release(.init(childExited: false, portState: .unknown)); await stop.value
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(try store.load().pending?.context, context)
        XCTAssertNotNil(controller.ownedRouter); XCTAssertFalse(controller.canQuit)
        XCTAssertNotNil(controller.error)
        XCTAssertEqual(controller.lastStopOutcome, .init(childExited: false, portState: .unknown))
    }

    func testFailedHeldStopRetainsReadinessLossObservedAfterStopBegins() async throws {
        // Loss observed during a failed stop also matters when the stop began with readiness false.
        let controller = await activated(); await controller.restoreDirect()
        backend.snapshot.provider.proxyReady = false
        await controller.refresh(); await controller.confirmDirectResponse()
        let barrier = Barrier<StopOutcome>(); backend.stopBarrier = barrier
        let stop = Task { await controller.stop() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = true
        await controller.refresh()
        backend.snapshot.provider.proxyReady = false
        await controller.refresh()
        barrier.release(.init(childExited: false, portState: .unknown)); await stop.value
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertEqual(try store.load().pending?.context, context)
        XCTAssertNotNil(controller.ownedRouter); XCTAssertFalse(controller.canQuit)
    }

    private let assignmentProjectID = "11111111-1111-4111-8111-111111111111"
    private let assignmentAccountID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private func enableAssignments() -> Inspection.Entry {
        backend.assignmentReady = true
        backend.snapshot.configurationRevision = String(repeating: "a", count: 64)
        backend.snapshot.configurationIdentity = String(repeating: "b", count: 64)
        backend.snapshot.routingFingerprint = String(repeating: "c", count: 64)
        backend.snapshot.recoveryRevision = String(repeating: "d", count: 64)
        backend.snapshot.catalog.revision = String(repeating: "e", count: 64)
        backend.snapshot.configuration.accounts = [.init(id: assignmentAccountID, displayName: "Synthetic account")]
        let project = Inspection.Entry(id: assignmentProjectID, name: "Synthetic project", routeAlias: nil, routeState: "unmapped", assignmentKind: "inherited")
        backend.snapshot.catalog.entries = [project]
        return project
    }
    private func unavailableAssignment(projectID: String, live: Bool, savedState: String = "unavailable") throws -> AssignmentState {
        var state = backend.assignmentState(projectID: projectID, live: live)
        state.savedState = savedState
        state.savedRevision = nil; state.savedIdentity = nil; state.savedFingerprint = nil
        state.catalogRevision = nil; state.savedAssignment = nil; state.intent = nil
        if live { state.runningAssignment = .init(kind: "inherited", account: .init(id: assignmentAccountID, displayName: "Synthetic account")) }
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        XCTAssertNotNil(AssignmentWire.state(object, context: context, projectID: projectID, operationID: nil, live: live))
        return state
    }
    func testFreshSetupRequiredAssignmentRemainsUnavailableAcrossPollAndSelection() async throws {
        // A successful incomplete-setup observation cannot invent a saved/running conflict.
        let project = enableAssignments()
        backend.snapshot.configuration.setupState = "required"
        backend.snapshot.configuration.accounts = []
        backend.assignmentReadOverride = try unavailableAssignment(projectID: project.id, live: false)
        let controller = makeController()
        for _ in 0..<2 {
            await controller.refresh()
            let state = await controller.loadAssignment(projectID: project.id)
            XCTAssertEqual(state?.savedState, "unavailable")
            XCTAssertEqual(controller.assignmentStatus, .unavailable)
            XCTAssertNil(controller.assignmentError)
            XCTAssertNil(state?.runningAssignment); XCTAssertNil(state?.mode)
            XCTAssertFalse(controller.canEditAssignment(project))
            await controller.saveAssignment(projectID: project.id, accountID: nil)
        }
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertNil(controller.pendingAssignmentOperationID)
        XCTAssertNil(controller.ownedRouter)
    }
    func testReturnedUnavailableReplacesConflictButReadFailureRemainsVisible() async throws {
        let project = enableAssignments()
        backend.assignmentReadOverride = try unavailableAssignment(projectID: project.id, live: false, savedState: "conflict")
        let controller = makeController()
        _ = await controller.loadAssignment(projectID: project.id)
        XCTAssertEqual(controller.assignmentStatus, .diverged)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
        backend.assignmentReadOverride = try unavailableAssignment(projectID: project.id, live: false)
        await controller.refresh()
        XCTAssertEqual(controller.assignmentStatus, .unavailable)
        XCTAssertNil(controller.assignmentError)
        XCTAssertFalse(controller.canEditAssignment(project))
        backend.assignmentReady = false
        await controller.refresh()
        XCTAssertEqual(controller.assignmentStatus, .unavailable)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentUnavailable.rawValue)
    }
    func testUnavailableSavedObservationRetainsKnownRuntimeEvidence() async throws {
        let project = enableAssignments()
        let controller = await started()
        let state = try unavailableAssignment(projectID: project.id, live: true)
        backend.assignmentReadOverride = state
        _ = await controller.loadAssignment(projectID: project.id)
        XCTAssertEqual(controller.assignmentStatus, .unavailable)
        XCTAssertEqual(controller.selectedAssignment, state)
        XCTAssertNotNil(controller.selectedAssignment?.runningAssignment)
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertNil(controller.assignmentError)
        XCTAssertFalse(controller.canEditAssignment(project))
    }
    func testUnavailableSavedObservationDoesNotClearPendingAssignment() async throws {
        let project = enableAssignments()
        let controller = await started()
        backend.assignmentError = .assignmentUncertain
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        let operation = try XCTUnwrap(controller.pendingAssignmentOperationID)
        backend.assignmentReadOverride = try unavailableAssignment(projectID: project.id, live: true)
        await controller.refresh()
        XCTAssertEqual(controller.assignmentStatus, .uncertain)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        XCTAssertEqual(controller.pendingAssignmentOperationID, operation)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentUncertain.rawValue)
        XCTAssertFalse(controller.canEditAssignment(project))
        XCTAssertEqual(backend.assignmentChanges.count, 1)
    }
    func testReadySavedMismatchStillReportsDivergence() async {
        let project = enableAssignments()
        let controller = await started()
        var state = backend.assignmentState(projectID: project.id, live: true)
        state.runningRevision = String(repeating: "9", count: 64)
        backend.assignmentReadOverride = state
        _ = await controller.loadAssignment(projectID: project.id)
        XCTAssertEqual(controller.assignmentStatus, .diverged)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
        XCTAssertFalse(controller.canEditAssignment(project))
    }
    func testVerifiedAssignmentPreservesConfirmedRoutedAndDirectAuthority() async throws {
        let project = enableAssignments()
        let controller = await activated(); await controller.confirmRoutedResponse()
        let pending = try store.load().pending
        _ = await controller.loadAssignment(projectID: project.id)
        XCTAssertTrue(controller.canEditAssignment(project))
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertEqual(try store.load().pending, pending)
        XCTAssertFalse(controller.assignmentRequiresReconciliation)
        XCTAssertEqual(controller.selectedAssignment?.savedAssignment?.account?.id, assignmentAccountID)
        XCTAssertEqual(backend.startCount, 1)
        await controller.restoreDirect(); await controller.confirmDirectResponse()
        _ = await controller.loadAssignment(projectID: project.id)
        await controller.saveAssignment(projectID: project.id, accountID: nil)
        XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
        XCTAssertTrue(controller.canStop)
        XCTAssertEqual(backend.startCount, 1)
        XCTAssertNil(controller.inspection?.configurationRevision)
        XCTAssertNil(controller.inspection?.recoveryRevision)
        XCTAssertEqual(backend.assignmentChanges.count, 2)
    }
    func testSameChoiceWithChangedRecoveryRevisionInvalidates() async {
        let project = enableAssignments()
        let controller = await activated(); await controller.confirmRoutedResponse()
        backend.assignmentNoOp = true
        backend.onAssignment = { self.backend.snapshot.recoveryRevision = String(repeating: "f", count: 64) }
        await controller.saveAssignment(projectID: project.id, accountID: nil)
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        XCTAssertFalse(controller.canEditAssignment(project))
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertEqual(controller.assignmentStatus, .diverged)
    }
    func testUncertainAssignmentRetainsRestoreDirectAndGuardedStop() async {
        let project = enableAssignments()
        let controller = await activated(); await controller.confirmRoutedResponse()
        backend.assignmentError = .assignmentUncertain
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        XCTAssertFalse(controller.mutationRequiresReconciliation)
        XCTAssertTrue(controller.canSelectNode) // Direct recovery may need a replacement helper runtime.
        XCTAssertFalse(controller.canEditAssignment(project))
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertFalse(controller.canBeginAccountSetup)
        XCTAssertNotNil(controller.pendingAssignmentOperationID)
        XCTAssertEqual(controller.assignmentStatus, .uncertain)
        await controller.restoreDirect(); await controller.confirmDirectResponse()
        XCTAssertTrue(controller.canStop)
        await controller.stop()
        XCTAssertNil(controller.ownedRouter)
        XCTAssertEqual(backend.assignmentChanges.count, 1)
    }
    func testPendingUnavailableObservationLaterProvesDivergenceWithoutRetry() async throws {
        // Fresh exact-child divergent evidence must update status without releasing the pending write block.
        let project = enableAssignments()
        let controller = await activated(); await controller.confirmRoutedResponse()
        let previous = backend.assignmentState(projectID: project.id, live: true)
        backend.assignmentError = .assignmentUncertain
        backend.assignmentAppliesBeforeError = true
        backend.onAssignment = { self.backend.assignmentReady = false }
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertEqual(controller.assignmentStatus, .uncertain)
        let operation = try XCTUnwrap(controller.pendingAssignmentOperationID)
        backend.assignmentReady = true
        var divergent = backend.assignmentState(projectID: project.id, live: true)
        divergent.runningRevision = previous.runningRevision
        divergent.runningIdentity = previous.runningIdentity
        divergent.runningFingerprint = previous.runningFingerprint
        divergent.runningAssignment = previous.runningAssignment
        backend.assignmentReadOverride = divergent
        await controller.refresh()
        XCTAssertEqual(controller.assignmentStatus, .diverged)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        XCTAssertEqual(controller.pendingAssignmentOperationID, operation)
        XCTAssertFalse(controller.canEditAssignment(project))
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertFalse(controller.canStop)
        XCTAssertEqual(backend.assignmentChanges.count, 1)
        XCTAssertEqual(backend.assignmentReads.last?.0, controller.ownedRouter?.id)
        XCTAssertEqual(backend.assignmentReads.last?.2, operation)
        backend.assignmentReady = false
        await controller.refresh()
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        XCTAssertNotEqual(controller.assignmentStatus, .ready)
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertEqual(backend.assignmentChanges.count, 1)
    }
    func testAssignmentReadDoesNotRequireMatchingReadiness() async {
        let project = enableAssignments()
        let controller = await started()
        backend.snapshot.provider.proxyReady = false
        let state = await controller.loadAssignment(projectID: project.id)
        XCTAssertNotNil(state?.runningRevision)
        XCTAssertFalse(controller.canEditAssignment(project))
        XCTAssertEqual(backend.assignmentReads.last?.0, controller.ownedRouter?.id)
    }
    func testStaleInspectionGenerationOrReplacedChildCannotApply() async {
        let project = enableAssignments()
        let controller = await activated(); await controller.confirmRoutedResponse()
        backend.onAssignment = { self.backend.exitChild() }
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertNil(controller.ownedRouter)
        XCTAssertNotEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        XCTAssertFalse(controller.canEditAssignment(project))
    }
    func testDismissedEditorRetainsPendingOperation() async {
        let project = enableAssignments()
        let controller = await started()
        let barrier = Barrier<Void>(); backend.assignmentBarrier = barrier
        let save = Task { await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID) }
        await waitUntil { barrier.waiting }
        let operation = controller.pendingAssignmentOperationID
        XCTAssertNotNil(operation); XCTAssertTrue(controller.busy)
        let unavailable = await controller.loadAssignment(projectID: project.id)
        XCTAssertNil(unavailable)
        XCTAssertEqual(controller.pendingAssignmentOperationID, operation)
        barrier.release(()); await save.value
        XCTAssertNil(controller.pendingAssignmentOperationID)
        XCTAssertEqual(backend.assignmentChanges.count, 1)
    }
    func testStoppedSaveAndAccountSetupBoundariesRemainIndependent() async {
        let project = enableAssignments()
        let controller = makeController(); await controller.refresh()
        backend.assignmentPort = .occupied
        _ = await controller.loadAssignment(projectID: project.id)
        XCTAssertFalse(controller.canEditAssignment(project))
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        backend.assignmentPort = .empty
        _ = await controller.loadAssignment(projectID: project.id)
        XCTAssertTrue(controller.canEditAssignment(project))
        XCTAssertTrue(controller.canBeginAccountSetup)
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertNil(controller.selectedAssignment?.runningRevision)
        XCTAssertEqual(controller.desktopConfirmation, .unknown)
        await controller.start()
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
        XCTAssertFalse(controller.canBeginAccountSetup)
        backend.snapshot.configuration.mode = "legacy"
        backend.snapshot.configuration.setupState = "migration_required"
        await controller.refresh()
        XCTAssertFalse(controller.canEditAssignment(project))
    }
    func testAssignmentPreservesPendingConfirmationAndModeAcrossRepeatedEdits() async {
        let project = enableAssignments()
        let controller = await activated()
        _ = await controller.loadAssignment(projectID: project.id)
        await controller.setProjectRouting(.on)
        for choice in [assignmentAccountID, nil, assignmentAccountID] {
            await controller.saveAssignment(projectID: project.id, accountID: choice)
            XCTAssertEqual(controller.desktopConfirmation, .routedPending)
            XCTAssertEqual(controller.projectRoutingStatus, .known(.on))
        }
        XCTAssertEqual(Set(backend.assignmentChanges.map(\.operationId)).count, 3)
        XCTAssertEqual(backend.startCount, 1)
    }

    func testUnrelatedSourceIdentityChangeInvalidatesExistingConfirmation() async {
        _ = enableAssignments()
        let controller = await activated(); await controller.confirmRoutedResponse()
        backend.snapshot.configurationIdentity = String(repeating: "9", count: 64)
        await controller.refresh()
        XCTAssertEqual(controller.desktopConfirmation, .routedPending)
    }
    func testPendingAssignmentCannotStartOrActivateThroughActionMethods() async {
        let project = enableAssignments()
        let controller = await started()
        backend.assignmentError = .assignmentUncertain
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        await controller.activate()
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertFalse(controller.canBeginAccountSetup)
    }
    func testAssignmentCapabilityAndUnsafeRecoveryEvidenceBlockWrites() async {
        let project = enableAssignments()
        backend.assignmentReady = false
        let controller = await started()
        XCTAssertFalse(controller.canEditAssignment(project))
        backend.assignmentReady = true
        for phase in ["prepared", "unavailable", "active"] {
            backend.snapshot.provider.recordPhase = phase
            backend.snapshot.provider.state = phase == "active" ? "conflict" : "router"
            backend.snapshot.provider.recoveryRequired = phase == "prepared"
            await controller.refresh()
            XCTAssertFalse(controller.canEditAssignment(project))
            await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        }
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertTrue(controller.canRestoreDirect)
    }
    func testAssignmentReadExitCannotPublishStaleCompoundEvidence() async {
        let project = enableAssignments()
        let controller = await started()
        let barrier = Barrier<Void>(); backend.assignmentReadBarrier = barrier
        let load = Task { await controller.loadAssignment(projectID: project.id) }
        await waitUntil { barrier.waiting }
        backend.exitChild(); barrier.release(())
        let result = await load.value
        XCTAssertNil(result)
        XCTAssertFalse(controller.canEditAssignment(project))
        XCTAssertNil(controller.ownedRouter)
    }
    func testExitedAssignmentChildCanSettleSavedEvidenceWithoutClaimingLiveApplication() async {
        let project = enableAssignments()
        let controller = await started()
        backend.assignmentAppliesBeforeError = true; backend.assignmentError = .assignmentUncertain
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        await controller.confirmDirectResponse()
        await controller.stop()
        XCTAssertNil(controller.ownedRouter)
        backend.assignmentError = nil
        backend.snapshot.provider.proxyReady = false // Independent post-exit listener observation.
        let state = await controller.loadAssignment(projectID: project.id)
        XCTAssertEqual(state?.savedAssignment?.account?.id, assignmentAccountID)
        XCTAssertNil(state?.runningRevision)
        XCTAssertFalse(controller.assignmentRequiresReconciliation)
        XCTAssertEqual(controller.desktopConfirmation, .confirmedDirect)
        await controller.start()
        XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
    }
    func testFailedAssignmentReadDoesNotReturnStaleSavedEvidence() async {
        let project = enableAssignments()
        let controller = await started()
        let first = await controller.loadAssignment(projectID: project.id)
        XCTAssertNotNil(first)
        backend.assignmentReady = false
        let failed = await controller.loadAssignment(projectID: project.id)
        XCTAssertNil(failed)
        XCTAssertEqual(controller.selectedAssignment?.runningRevision, first?.runningRevision)
        XCTAssertFalse(controller.canEditAssignment(project))
    }
    func testDifferentProjectReadCannotSettlePendingAssignment() async {
        let project = enableAssignments()
        let controller = await started()
        backend.assignmentError = .assignmentUncertain
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        let operation = controller.pendingAssignmentOperationID
        let other = await controller.loadAssignment(projectID: "22222222-2222-4222-8222-222222222222")
        XCTAssertNil(other)
        XCTAssertEqual(controller.pendingAssignmentOperationID, operation)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
    }
    func testFreshAssignmentPreflightRejectsChangedDisplayedBaseline() async {
        let project = enableAssignments()
        let controller = await started()
        backend.snapshot.configurationRevision = String(repeating: "9", count: 64)
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertNotNil(controller.assignmentError)
    }
    func testStoppedRefreshCanAuthorizeConfiguredOnlyCatalogRowWithoutSelectingIt() async {
        _ = enableAssignments()
        let project = Inspection.Entry(id: assignmentProjectID, name: "", routeAlias: "legacy", routeState: "catalog_missing", assignmentKind: "override")
        backend.snapshot.catalog.entries = [project]
        let controller = makeController(); await controller.refresh()
        XCTAssertTrue(controller.canEditAssignment(project))
        XCTAssertNil(controller.selectedAssignment)
        XCTAssertEqual(controller.assignmentActionTitle, "Save")
    }
    func testAssignmentPollingDoesNotImportTransientProviderLeaseAsRecoveryLock() async throws {
        let localContext = ActivationContext(configPath: root.appendingPathComponent("router.json").path, codexHome: root.path, providerId: "router", listenPort: 43129)
        backend = ControlledBackend(context: localContext)
        try store.save(CompanionJournal(selectedConfigurationPath: localContext.configPath))
        let project = enableAssignments()
        let controller = await started()
        let barrier = Barrier<ControlResult>(); backend.controlBarrier = barrier
        let activate = Task { await controller.activate() }
        await waitUntil { barrier.waiting }
        let lock = root.appendingPathComponent(".activation.lock")
        try Data("{\"pid\":123}".utf8).write(to: lock)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: lock.path)
        await controller.refresh()
        XCTAssertFalse(controller.canEditAssignment(project))
        try FileManager.default.removeItem(at: lock)
        backend.snapshot.provider.state = "router"; backend.snapshot.provider.recordPhase = "active"
        backend.snapshot.revision = "routed-after-transient-lock"
        barrier.release(.init(state: "active", changed: true, restartRequired: true)); await activate.value
        XCTAssertFalse(controller.configurationLockRequiresResolution)
        XCTAssertFalse(controller.mutationRequiresReconciliation)
        XCTAssertTrue(controller.canRestoreDirect)
    }
    func testRejectedAssignmentRetainsSafeErrorWithoutInventingUncertaintyOrRetry() async {
        let project = enableAssignments()
        let controller = await started()
        backend.assignmentError = .assignmentConflict
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
        XCTAssertFalse(controller.assignmentRequiresReconciliation)
        XCTAssertNil(controller.pendingAssignmentOperationID)
        XCTAssertEqual(backend.assignmentChanges.count, 1)
    }
    func testRejectedStoppedAssignmentAfterSourceChangeClearsPendingAndKeepsControlsAvailable() async {
        let project = enableAssignments()
        let controller = makeController(); await controller.refresh()
        let barrier = Barrier<Void>(); backend.assignmentBarrier = barrier; backend.assignmentError = .assignmentConflict
        let save = Task { await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID) }
        await waitUntil { barrier.waiting }
        XCTAssertNotNil(controller.pendingAssignmentOperationID)
        backend.snapshot.configurationRevision = String(repeating: "8", count: 64)
        backend.snapshot.configurationIdentity = String(repeating: "9", count: 64)
        barrier.release(()); await save.value
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
        XCTAssertNil(controller.pendingAssignmentOperationID)
        XCTAssertFalse(controller.assignmentRequiresReconciliation)
        XCTAssertFalse(controller.mutationRequiresReconciliation)
        XCTAssertFalse(controller.busy)
        XCTAssertTrue(controller.canStart); XCTAssertTrue(controller.canQuit); XCTAssertTrue(controller.canSelectConfiguration)
        XCTAssertTrue(controller.canEditAssignment(project))
        XCTAssertEqual(backend.assignmentChanges.count, 1)
        XCTAssertNil(backend.assignmentIntent)
        XCTAssertEqual(backend.startCount, 0); XCTAssertTrue(backend.controls.isEmpty)
    }
    func testStoppedRefreshRetainsEditorBaselineAndSaveRechecksPortAfterQueuedObservation() async {
        // Presentation continuity cannot rebase an explicit editor or let a queued save reuse a prior empty-port proof.
        let project = enableAssignments()
        let controller = makeController(); await controller.refresh()
        _ = await controller.loadAssignment(projectID: project.id)
        backend.snapshot.configurationRevision = String(repeating: "8", count: 64)
        backend.snapshot.configurationIdentity = String(repeating: "9", count: 64)
        await controller.refresh()
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
        _ = await controller.loadAssignment(projectID: project.id)
        let barrier = Barrier<Void>(); backend.assignmentReadBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        XCTAssertTrue(controller.canEditAssignment(project))
        let save = Task { await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID) }
        await waitUntil { controller.busy }
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        backend.assignmentPort = .occupied
        barrier.release(())
        await refresh.value
        await save.value
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertNil(controller.pendingAssignmentOperationID)
        XCTAssertFalse(controller.canEditAssignment(project))
        XCTAssertTrue(controller.canRestoreDirect)
    }
    func testBackgroundPollCannotRebaseExplicitEditorSourceOrAccounts() async {
        let project = enableAssignments()
        let controller = await started()
        _ = await controller.loadAssignment(projectID: project.id)
        backend.snapshot.configurationRevision = String(repeating: "8", count: 64)
        backend.snapshot.configurationIdentity = String(repeating: "9", count: 64)
        backend.snapshot.configuration.accounts?[0].displayName = "Renamed account"
        await controller.refresh()
        XCTAssertEqual(controller.selectedAssignment?.savedRevision, String(repeating: "8", count: 64))
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
        _ = await controller.loadAssignment(projectID: project.id)
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertEqual(backend.assignmentChanges.count, 1)
    }
    func testReplacementChildCannotRebaseExplicitEditor() async {
        let project = enableAssignments()
        let controller = await started()
        _ = await controller.loadAssignment(projectID: project.id)
        let old = controller.ownedRouter
        await controller.stop()
        backend.snapshot.provider.proxyReady = false
        await controller.start()
        XCTAssertFalse(controller.ownedRouter === old)
        await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID)
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
    }
    func testQueuedAssignmentSaveCannotSwitchToStoppedAfterExplicitEditorChildExits() async {
        await queuedAssignmentSave(loadEditor: true, exitChild: true)
    }
    func testQueuedAssignmentSaveCannotSwitchToStoppedWithoutExplicitEditor() async {
        await queuedAssignmentSave(loadEditor: false, exitChild: true)
    }
    func testQueuedAssignmentSaveKeepsLivePathForUnchangedChild() async {
        await queuedAssignmentSave(loadEditor: true, exitChild: false)
    }
    private func queuedAssignmentSave(loadEditor: Bool, exitChild: Bool) async {
        let project = enableAssignments()
        let controller = await started()
        if loadEditor { _ = await controller.loadAssignment(projectID: project.id) }
        let child = controller.ownedRouter
        XCTAssertEqual(controller.assignmentActionTitle, "Save and apply")
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        let save = Task { await controller.saveAssignment(projectID: project.id, accountID: assignmentAccountID) }
        await waitUntil { controller.busy }
        XCTAssertTrue(backend.assignmentChanges.isEmpty)
        XCTAssertNil(controller.pendingAssignmentOperationID)
        if exitChild {
            backend.exitChild()
            backend.snapshot.provider.proxyReady = false // Independent stopped listener observation.
        }
        barrier.release(backend.snapshot)
        await refresh.value; await save.value
        XCTAssertEqual(backend.maximumConcurrentInspections, 1)
        if exitChild {
            XCTAssertNil(controller.ownedRouter)
            XCTAssertTrue(backend.assignmentChanges.isEmpty)
            XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
            XCTAssertNil(controller.pendingAssignmentOperationID)
            XCTAssertFalse(controller.assignmentRequiresReconciliation)
            XCTAssertTrue(controller.canRestoreDirect)
        } else {
            XCTAssertTrue(controller.ownedRouter === child)
            XCTAssertEqual(backend.assignmentChanges.count, 1)
            XCTAssertNotNil(backend.assignmentChanges.first?.expectedRunningRevision)
            XCTAssertNil(controller.assignmentError)
        }
    }
    private func waitUntil(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1000 {
            if predicate() { return }
            await Task.yield()
        }
        XCTFail("Controlled operation did not reach its barrier", file: file, line: line)
    }

}

@MainActor private final class Barrier<Value> {
    private var continuation: CheckedContinuation<Value, Never>?
    private(set) var waiting = false
    func wait() async -> Value {
        await withCheckedContinuation { continuation = $0; waiting = true }
    }
    func release(_ value: Value) { continuation?.resume(returning: value); continuation = nil }
}
private final class SyntheticProcess: Process, @unchecked Sendable {
    var live = true
    override var isRunning: Bool { live }
}
@MainActor private final class ControlledBackend: CompanionBackend, ProjectAssignmentBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var snapshot: Inspection
    var inspectBarrier: Barrier<Inspection>?
    var controlBarrier: Barrier<ControlResult>?
    var stopBarrier: Barrier<StopOutcome>?
    var modeReadBarrier: Barrier<Result<ProjectRoutingMode, CompanionError>>?
    var modeSetBarrier: Barrier<Result<ProjectRoutingMode, CompanionError>>?
    var modeReadError: CompanionError?
    var modeSetError: CompanionError?
    var mode = ProjectRoutingMode.off
    var modeReads: [OwnedRouter] = []
    var modeSets: [(ProjectRoutingMode, OwnedRouter)] = []
    var concurrentModeCommands = 0
    var maximumConcurrentModeCommands = 0
    var mutationRequiresReconciliation = false
    var controlError: CompanionError?
    var inspectionError: CompanionError?
    var nodeError: CompanionError?
    var onControl: ((ControlAction, ActivationContext) throws -> Void)?
    var inspectedPaths: [URL?] = []
    var concurrentInspections = 0
    var maximumConcurrentInspections = 0
    var controls: [(ControlAction, ActivationContext)] = []
    var startBecomesReady = true
    var startInspectionBarrier: Barrier<Inspection>?
    var startCount = 0
    var stopCount = 0
    var validatedNodes: [URL] = []
    var executable: URL?
    var child: OwnedRouter?
    var stopOutcome = StopOutcome(childExited: true, portState: .empty)
    init(context: ActivationContext) {
        snapshot = Inspection(configuration: .init(state: "valid", path: context.configPath, mode: "accounts", setupState: "ready"), context: context, revision: "direct-1",
            provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"), catalog: .init(state: "ready", entries: []))
    }

    var assignmentNoOp = false
    var assignmentAppliesBeforeError = false
    var assignmentReadOverride: AssignmentState?
    var assignmentReadBarrier: Barrier<Void>?
    var assignmentReady = false
    var assignmentError: CompanionError?
    var assignmentBarrier: Barrier<Void>?
    var assignmentPort = StopOutcome.PortState.empty
    var onAssignment: (() -> Void)?
    var assignmentChanges: [AssignmentChange] = []
    var assignmentReads: [(UUID?, String?, String?)] = []
    var assignmentSummary = AssignmentSummary(kind: "inherited")
    var assignmentIntent: AssignmentIntent?
    func assignmentState(projectID: String?, live: Bool) -> AssignmentState {
        AssignmentState(context: snapshot.context!, savedState: "ready", savedRevision: snapshot.configurationRevision,
            savedIdentity: snapshot.configurationIdentity, savedFingerprint: snapshot.routingFingerprint, catalogRevision: snapshot.catalog.revision,
            runningRevision: live ? snapshot.configurationRevision : nil, runningIdentity: live ? snapshot.configurationIdentity : nil,
            runningFingerprint: live ? snapshot.routingFingerprint : nil, mode: live ? mode : nil, projectId: projectID,
            savedAssignment: projectID == nil ? nil : assignmentSummary, runningAssignment: live && projectID != nil ? assignmentSummary : nil,
            intent: assignmentIntent, lastAttempt: nil)
    }
    func readAssignment(_ child: OwnedRouter, projectID: String?, operationID: String?) async throws -> AssignmentState {
        guard assignmentReady else { throw CompanionError.assignmentUnavailable }
        assignmentReads.append((child.id, projectID, operationID))
        if let barrier = assignmentReadBarrier { assignmentReadBarrier = nil; await barrier.wait() }
        return assignmentReadOverride ?? assignmentState(projectID: projectID, live: true)
    }
    func readStoppedAssignment(context: ActivationContext, projectID: String, operationID: String?) async throws -> AssignmentState {
        guard assignmentReady else { throw CompanionError.assignmentUnavailable }
        assignmentReads.append((nil, projectID, operationID))
        if let barrier = assignmentReadBarrier { assignmentReadBarrier = nil; await barrier.wait() }
        return assignmentReadOverride ?? assignmentState(projectID: projectID, live: false)
    }
    func probeAssignmentPort(_ context: ActivationContext) async -> StopOutcome.PortState { assignmentPort }
    func applyAssignment(_ change: AssignmentChange, to child: OwnedRouter) async throws -> AssignmentCommit { try await performAssignment(change, live: true) }
    func saveStoppedAssignment(_ change: AssignmentChange) async throws -> AssignmentCommit { try await performAssignment(change, live: false) }
    private func performAssignment(_ change: AssignmentChange, live: Bool) async throws -> AssignmentCommit {
        assignmentChanges.append(change)
        if let barrier = assignmentBarrier { assignmentBarrier = nil; await barrier.wait() }
        if let assignmentError, !assignmentAppliesBeforeError { throw assignmentError }
        let before = assignmentSummary
        assignmentSummary = change.accountId.map { AssignmentSummary(kind: "override", account: .init(id: $0, displayName: "Synthetic account"), routeAlias: "route-new") } ?? .init(kind: "inherited")
        let revision = assignmentNoOp ? change.expectedSavedRevision : String(repeating: snapshot.configurationRevision == String(repeating: "1", count: 64) ? "2" : "1", count: 64)
        let identity = assignmentNoOp ? change.expectedConfigurationIdentity : String(repeating: snapshot.configurationIdentity == String(repeating: "3", count: 64) ? "4" : "3", count: 64)
        snapshot.configurationRevision = revision; snapshot.configurationIdentity = identity
        if !assignmentNoOp { snapshot.routingFingerprint = String(repeating: "5", count: 64); snapshot.revision = revision }
        if assignmentNoOp { assignmentSummary = before }
        assignmentIntent = assignmentNoOp ? nil : .init(schemaVersion: 1, operationId: change.operationId, context: change.expectedContext, projectId: change.projectId,
            accountId: change.accountId, checkpointName: "assignment-checkpoint-\(change.operationId.lowercased()).json", beforeRevision: change.expectedSavedRevision,
            beforeIdentity: change.expectedConfigurationIdentity, candidateRevision: revision, candidateIdentity: identity)
        onAssignment?()
        if let assignmentError { throw assignmentError }
        return AssignmentCommit(context: change.expectedContext, operationId: change.operationId, projectId: change.projectId, changed: !assignmentNoOp,
            beforeRevision: change.expectedSavedRevision, candidateRevision: revision, savedRevision: revision,
            beforeIdentity: change.expectedConfigurationIdentity, candidateIdentity: identity, savedIdentity: identity, before: before, after: assignmentSummary,
            checkpointPath: assignmentIntent.map { URL(fileURLWithPath: change.configPath).deletingLastPathComponent().appendingPathComponent($0.checkpointName).path },
            intent: assignmentIntent, runningRevision: live ? revision : nil, runningIdentity: live ? identity : nil,
            runningFingerprint: live ? snapshot.routingFingerprint : nil)
    }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection {
        concurrentInspections += 1
        maximumConcurrentInspections = max(maximumConcurrentInspections, concurrentInspections)
        defer { concurrentInspections -= 1 }
        inspectedPaths.append(configPath)
        if let barrier = inspectBarrier { inspectBarrier = nil; return await barrier.wait() }
        if let inspectionError { throw inspectionError }
        return snapshot
    }
    func validateNode(_ path: URL) async throws -> URL {
        validatedNodes.append(path)
        if let nodeError { throw nodeError }
        return path
    }
    func setNodeExecutable(_ validatedPath: URL) { executable = validatedPath }
    func start(configPath: URL) async throws -> OwnedRouter {
        startCount += 1
        mode = .off
        let child = OwnedRouter(process: SyntheticProcess(), context: snapshot.context!)
        self.child = child
        snapshot.provider.proxyReady = startBecomesReady
        if let barrier = startInspectionBarrier {
            startInspectionBarrier = nil; inspectBarrier = barrier
            _ = try await inspect(configPath: configPath, browseHome: configPath.deletingLastPathComponent())
        }
        return child
    }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult {
        controls.append((action, expectedContext))
        try onControl?(action, expectedContext)
        if let controlError { throw controlError }
        let changed = snapshot.provider.state != (action == .activate ? "router" : "direct")
        if let barrier = controlBarrier { controlBarrier = nil; return await barrier.wait() }
        snapshot.provider.state = action == .activate ? "router" : "direct"
        snapshot.provider.recordPhase = action == .activate ? "active" : "restored"
        snapshot.provider.recoveryRequired = false
        snapshot.revision = action == .activate ? "routed-1" : "restored-1"
        return ControlResult(state: action == .activate ? "active" : "direct", changed: changed, restartRequired: changed)
    }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode {
        modeReads.append(child)
        concurrentModeCommands += 1; maximumConcurrentModeCommands = max(maximumConcurrentModeCommands, concurrentModeCommands)
        defer { concurrentModeCommands -= 1 }
        if let barrier = modeReadBarrier { modeReadBarrier = nil; return try await barrier.wait().get() }
        if let modeReadError { throw modeReadError }
        return mode
    }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode {
        modeSets.append((mode, child))
        concurrentModeCommands += 1; maximumConcurrentModeCommands = max(maximumConcurrentModeCommands, concurrentModeCommands)
        defer { concurrentModeCommands -= 1 }
        if let barrier = modeSetBarrier {
            modeSetBarrier = nil
            let applied = try await barrier.wait().get(); self.mode = applied; return applied
        }
        if let modeSetError { throw modeSetError }
        self.mode = mode; return mode
    }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome {
        stopCount += 1
        let outcome = if let barrier = stopBarrier { await barrier.wait() } else { stopOutcome }
        if outcome.childExited { exitChild() }
        return outcome
    }
    func exitChild() {
        guard let child else { return }
        (child.process as! SyntheticProcess).live = false
        onChildExit?(child.id, 1)
    }
}
