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
        await controller.restoreDirect()
        barrier.release(old); await refresh.value
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
        await controller.selectConfiguration(another)
        barrier.release(old); await first.value
        XCTAssertEqual(controller.selectedConfiguration, another)
        XCTAssertEqual(controller.inspection?.context?.configPath, another.path)
        XCTAssertEqual(backend.inspectedPaths.count, 3)
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
        XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), original)
        let malformedRoot = root.appendingPathComponent("corrupt")
        let malformedStore = PrivateStore(directory: malformedRoot); _ = try malformedStore.load()
        let corrupt = Data("{broken PRIVATE_SENTINEL".utf8)
        try corrupt.write(to: malformedRoot.appendingPathComponent("state.json"))
        let failed = RouterController(backend: backend, store: malformedStore, browseHome: root)
        await failed.refresh(); await failed.restoreDirect()
        XCTAssertNil(failed.selectedConfiguration); XCTAssertFalse(failed.canQuit)
        XCTAssertEqual(failed.error, CompanionError.privateState.rawValue)
        XCTAssertEqual(try Data(contentsOf: malformedRoot.appendingPathComponent("state.json")), corrupt)
        XCTAssertEqual(backend.controls.count, 0)
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

    func testStaleDirectConfirmationCannotReplaceNewerRouterSnapshot() async throws {
        // An older confirmation response must not clear recovery after a newer inspection found router state.
        let controller = await activated(); await controller.restoreDirect()
        let oldDirect = backend.snapshot
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let confirmation = Task { await controller.confirmDirectResponse() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.state = "router"; backend.snapshot.provider.recordPhase = "active"; backend.snapshot.revision = "external-reactivation"
        await controller.refresh()
        barrier.release(oldDirect); await confirmation.value
        XCTAssertEqual(controller.inspection?.provider.state, "router")
        XCTAssertEqual(controller.desktopConfirmation, .directPending)
        XCTAssertNotNil(try store.load().pending)
        XCTAssertFalse(controller.canStop); XCTAssertFalse(controller.canQuit)
    }
    func testStaleActivationInspectionCannotOverrideNewerReadinessLoss() async {
        // A held readiness check cannot authorize activation after a later inspection lost readiness.
        let controller = await started()
        let oldReady = backend.snapshot
        let barrier = Barrier<Inspection>(); backend.inspectBarrier = barrier
        let activation = Task { await controller.activate() }
        await waitUntil { barrier.waiting }
        backend.snapshot.provider.proxyReady = false
        await controller.refresh()
        barrier.release(oldReady); await activation.value
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
    var controls: [(ControlAction, ActivationContext)] = []
    var startBecomesReady = true
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
