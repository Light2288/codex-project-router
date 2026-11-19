import XCTest
@testable import CompanionCore

@MainActor final class ProjectListObservationTests: XCTestCase {
    private var root: URL!
    private var store: PrivateStore!
    private var backend: ControlledBackend!
    private let context = ActivationContext(configPath: "/synthetic/private/config.json", codexHome: "/synthetic/codex", providerId: "router", listenPort: 43129)
    private let projectID = "11111111-1111-4111-8111-111111111111"
    private let account = AccountSummary(id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", displayName: "Running default")
    private let custom = AccountSummary(id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", displayName: "Running custom")

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("list observation \(UUID())")
        store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath))
        backend = ControlledBackend(context: context)
        backend.assignmentReady = true
        backend.snapshot.configurationRevision = String(repeating: "a", count: 64)
        backend.snapshot.configurationIdentity = String(repeating: "b", count: 64)
        backend.snapshot.routingFingerprint = String(repeating: "c", count: 64)
        backend.snapshot.recoveryRevision = String(repeating: "d", count: 64)
        backend.snapshot.catalog.revision = String(repeating: "e", count: 64)
        backend.snapshot.configuration.accounts = [.init(id: account.id, displayName: "Saved default"), .init(id: custom.id, displayName: "Saved custom")]
        backend.snapshot.catalog.entries = [.init(id: projectID, name: "Project", routeAlias: nil, routeState: "unmapped", assignmentKind: "inherited")]
        backend.listObservation = observation()
    }
    override func tearDown() async throws {
        backend = nil; store = nil
        try FileManager.default.removeItem(at: root)
    }
    private func observation() -> RunningProjectListObservation {
        .init(context: context, snapshot: .init(runningRevision: String(repeating: "a", count: 64), runningIdentity: String(repeating: "b", count: 64), runningFingerprint: String(repeating: "c", count: 64), mode: .off), defaultAccount: account, assignments: [projectID: .init(kind: "override", account: custom, routeAlias: "custom")])
    }
    private func started() async -> RouterController {
        let controller = RouterController(backend: backend, store: store, browseHome: root)
        await controller.refresh(); await controller.start()
        return controller
    }
    private func observed(_ controller: RouterController, file: StaticString = #filePath, line: UInt = #line) -> ProjectListRunningAssignments? {
        guard case .observed(let value) = controller.projectListRuntimeState else { XCTFail("Expected complete running assignments", file: file, line: line); return nil }
        return value
    }
    private func waitUntil(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1000 { if predicate() { return }; await Task.yield() }
        XCTFail("Observation did not reach its barrier", file: file, line: line)
    }

    func testOrdinaryRefreshCollectsAllCatalogIDsWithOneSecondDeadlineAndNoPreflightReads() async {
        // Suppressing reads because inspectNow owns busy would leave every ordinary poll unconfirmed.
        let controller = await started()
        XCTAssertTrue(backend.listReads.isEmpty)
        let began = Date()
        await controller.refreshAndWait()
        let value = observed(controller)
        XCTAssertEqual(value?.mode, .off)
        XCTAssertEqual(value?.defaultAccount, account)
        XCTAssertEqual(value?.assignments[projectID]?.account, custom)
        XCTAssertEqual(backend.listReads.count, 1)
        XCTAssertTrue(backend.listReads.first?.0 === controller.ownedRouter)
        XCTAssertEqual(backend.listReads.first?.1, [projectID])
        if let deadline = backend.listReads.first?.2 {
            XCTAssertGreaterThan(deadline.timeIntervalSince(began), 0)
            XCTAssertLessThanOrEqual(deadline.timeIntervalSinceNow, 1)
        }
        _ = await controller.loadAssignment(projectID: projectID)
        await controller.setProjectRouting(.on)
        XCTAssertEqual(backend.listReads.count, 1, "Editor and mode preflights must not collect list pages")
    }
    func testExternalSavedEditRemainsObservableWhileReadinessDiffersAndKeepsRunningNames() async {
        let controller = await started()
        backend.assignmentReadOverride = backend.assignmentState(projectID: nil, live: true)
        backend.snapshot.configurationRevision = String(repeating: "8", count: 64)
        backend.snapshot.routingFingerprint = String(repeating: "9", count: 64)
        backend.snapshot.provider.proxyReady = false
        await controller.refresh()
        let value = observed(controller)
        XCTAssertEqual(value?.defaultAccount.displayName, "Running default")
        XCTAssertEqual(value?.assignments[projectID]?.account?.displayName, "Running custom")
        XCTAssertEqual(controller.assignmentStatus, .diverged)
        XCTAssertFalse(controller.canEditAssignment(backend.snapshot.catalog.entries[0]))
    }
    func testListTimeoutDoesNotRevokeAssignmentOrRecoveryEvidence() async {
        let controller = await started()
        await controller.activate(); await controller.confirmRoutedResponse()
        await controller.refresh()
        XCTAssertNotNil(observed(controller))
        let inspection = controller.inspection
        backend.listError = .timedOut
        await controller.refresh()
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
        XCTAssertEqual(controller.inspection, inspection)
        XCTAssertEqual(controller.assignmentStatus, .ready)
        XCTAssertEqual(controller.desktopConfirmation, .confirmedRouted)
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertNil(controller.error)
        XCTAssertFalse(controller.assignmentRequiresReconciliation)
    }
    func testChangedRuntimeTokenDiscardsWholeObservation() async {
        let controller = await started()
        let value = observation()
        backend.listObservation = .init(context: context, snapshot: .init(runningRevision: String(repeating: "f", count: 64), runningIdentity: value.snapshot.runningIdentity, runningFingerprint: value.snapshot.runningFingerprint, mode: .off), defaultAccount: account, assignments: value.assignments)
        await controller.refresh()
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
        XCTAssertEqual(controller.assignmentStatus, .ready)
    }
    func testChangedContextDiscardsWholeObservation() async {
        let controller = await started()
        let value = observation()
        backend.listObservation = .init(context: .init(configPath: "/synthetic/other.json", codexHome: context.codexHome, providerId: context.providerId, listenPort: context.listenPort), snapshot: value.snapshot, defaultAccount: account, assignments: value.assignments)
        await controller.refresh()
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
    }
    func testChildExitWhileCollectingCannotPublishObservationOrClaimStoppedWithUnknownPort() async {
        let controller = await started()
        let barrier = Barrier<Void>(); backend.listBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        backend.exitChild()
        barrier.release(()); await refresh.value
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
        XCTAssertNil(controller.ownedRouter)
    }
    func testExitedProcessRevokesPriorObservationBeforeItsExitCallback() async {
        // The backend can await stderr drainage before it reports the child's exit.
        let controller = await started()
        await controller.refresh()
        XCTAssertNotNil(observed(controller))
        let barrier = Barrier<Void>(); backend.listBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        (backend.child!.process as! SyntheticProcess).live = false
        barrier.release(()); await refresh.value
        XCTAssertNotNil(controller.ownedRouter, "This case deliberately delays the exit callback")
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
    }
    func testFailedListReadRevokesPriorObservationWhenProcessExitsBeforeCallback() async {
        let controller = await started()
        await controller.refresh()
        XCTAssertNotNil(observed(controller))
        let barrier = Barrier<Void>(); backend.listBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        backend.listError = .assignmentUnavailable
        (backend.child!.process as! SyntheticProcess).live = false
        barrier.release(()); await refresh.value
        XCTAssertNotNil(controller.ownedRouter)
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
    }
    func testNewActionGenerationDiscardsAnInFlightObservation() async {
        let controller = await started()
        let barrier = Barrier<Void>(); backend.listBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        let action = Task { await controller.selectNode(URL(fileURLWithPath: "/synthetic/node")) }
        await waitUntil { controller.busy }
        barrier.release(()); await refresh.value; await action.value
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
        XCTAssertEqual(backend.listReads.count, 1)
    }
    func testMissingCoverageCannotPublishPartialObservation() async {
        let controller = await started()
        let value = observation()
        backend.listObservation = .init(context: context, snapshot: value.snapshot, defaultAccount: account, assignments: [:])
        await controller.refresh()
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
    }
    func testSaveInvalidatesWarningsUntilOrdinaryRefreshAndDoesNotRebaseOpenEditor() async {
        let controller = await started()
        _ = await controller.loadAssignment(projectID: projectID)
        await controller.refresh()
        XCTAssertNotNil(observed(controller))
        await controller.saveAssignment(projectID: projectID, accountID: custom.id)
        XCTAssertEqual(backend.assignmentChanges.count, 1)
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
        XCTAssertEqual(backend.listReads.count, 1)
        let state = backend.assignmentState(projectID: projectID, live: true)
        backend.listObservation = .init(context: context, snapshot: .init(runningRevision: state.runningRevision!, runningIdentity: state.runningIdentity!, runningFingerprint: state.runningFingerprint!, mode: .off), defaultAccount: account, assignments: [projectID: backend.assignmentSummary])
        await controller.refresh()
        XCTAssertEqual(observed(controller)?.assignments[projectID]?.account?.id, custom.id)
        backend.snapshot.configurationRevision = String(repeating: "8", count: 64)
        await controller.refresh()
        await controller.saveAssignment(projectID: projectID, accountID: nil)
        XCTAssertEqual(backend.assignmentChanges.count, 1, "Polling list changes must not rebase the editor's approved baseline")
        XCTAssertEqual(controller.assignmentError, CompanionError.assignmentConflict.rawValue)
    }
    func testChangedSavedBaselineRevokesPriorListBeforeAwaitingModeReconciliation() async {
        // A slow mode reply must not leave already contradicted list evidence visible.
        let controller = await started()
        await controller.refresh()
        XCTAssertNotNil(observed(controller))
        backend.snapshot.configurationRevision = String(repeating: "8", count: 64)
        let barrier = Barrier<Result<ProjectRoutingMode, CompanionError>>()
        backend.modeReadBarrier = barrier
        let refresh = Task { await controller.refresh() }
        await waitUntil { barrier.waiting }
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
        barrier.release(.success(.off)); await refresh.value
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
    }
    func testStoppedPortProofAndExternalListenerRemainDistinct() async {
        let controller = RouterController(backend: backend, store: store, browseHome: root)
        await controller.refresh()
        XCTAssertEqual(controller.projectListRuntimeState, .notRunning)
        backend.assignmentPort = .occupied
        backend.snapshot.provider.proxyReady = true
        await controller.refresh()
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
        XCTAssertTrue(backend.listReads.isEmpty)
    }
    func testListFailureCannotSettleUncertainAssignment() async {
        let controller = await started()
        backend.assignmentError = .assignmentUncertain
        await controller.saveAssignment(projectID: projectID, accountID: custom.id)
        let pending = controller.pendingAssignmentOperationID
        backend.assignmentReady = false
        backend.listError = .assignmentUnavailable
        await controller.refresh()
        XCTAssertNotNil(pending)
        XCTAssertEqual(controller.pendingAssignmentOperationID, pending)
        XCTAssertTrue(controller.assignmentRequiresReconciliation)
        XCTAssertTrue(controller.canRestoreDirect)
        XCTAssertEqual(controller.projectListRuntimeState, .unconfirmed)
    }
}
