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
    private func withQueuedPolling(_ controller: RouterController, action: @escaping () async -> Void) async {
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
@MainActor private final class ControlledBackend: CompanionBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var snapshot: Inspection
    var inspectBarrier: Barrier<Inspection>?
    var controlBarrier: Barrier<ControlResult>?
    var stopBarrier: Barrier<StopOutcome>?
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
        snapshot = Inspection(configuration: .init(state: "valid", path: context.configPath, mode: "legacy"), context: context, revision: "direct-1",
            provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"), catalog: .init(state: "ready", entries: []))
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
