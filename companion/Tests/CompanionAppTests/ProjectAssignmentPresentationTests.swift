import XCTest
@testable import CompanionCore
@testable import CodexProjectRouter

@MainActor final class ProjectAssignmentPresentationTests: XCTestCase {
    private func withEditor(live: Bool = true, _ body: (RouterController, AssignmentDisplayBackend, Inspection.Entry) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("assignment presentation \(UUID())")
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { XCTFail("Assignment fixture cleanup failed: \(error)") }
        }
        let backend = AssignmentDisplayBackend(root: root)
        let store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(.init(selectedConfigurationPath: backend.context.configPath))
        let controller = RouterController(backend: backend, store: store, browseHome: root)
        await controller.refresh()
        if live { await controller.start() }
        let project = backend.snapshot.catalog.entries[0]
        _ = await controller.loadAssignment(projectID: project.id)
        try await body(controller, backend, project)
    }
    func testHealthyStoppedRefreshKeepsEditorPresentationThroughReadAndPortProbe() async throws {
        // Clearing prior port proof before a healthy observation completes inserts a sheet-height-changing reason.
        try await withEditor(live: false) { controller, backend, project in
            let editor = AssignmentEditor()
            await editor.load(controller: controller, project: project)
            editor.selection = .account(backend.work.id)
            await editor.save(controller: controller, project: project)
            let saved = controller.selectedAssignment
            for _ in 0..<2 {
                let read = AssignmentDisplayBarrier(), probe = AssignmentDisplayBarrier()
                backend.readBarrier = read; backend.portBarrier = probe
                let refresh = Task { await controller.refresh() }
                await read.waitUntilEntered()
                var display = AssignmentPresentation(controller: controller, project: project, selection: editor.selection)
                XCTAssertNil(display.disabledReason)
                XCTAssertTrue(display.canSave)
                XCTAssertEqual(display.savedText, "Saved: Override — Shared name")
                XCTAssertEqual(controller.selectedAssignment, saved)
                read.release()
                await probe.waitUntilEntered()
                display = AssignmentPresentation(controller: controller, project: project, selection: editor.selection)
                XCTAssertNil(display.disabledReason)
                XCTAssertTrue(display.canSave)
                XCTAssertNil(controller.selectedAssignment?.runningRevision)
                probe.release(); await refresh.value
                XCTAssertNil(AssignmentPresentation(controller: controller, project: project, selection: editor.selection).disabledReason)
                XCTAssertEqual(editor.selection, .account(backend.work.id))
            }
            XCTAssertEqual(backend.changes.count, 1)
        }
    }
    func testStoppedRefreshFailureAndOccupiedPortBlockEditorUntilCompleteHealthyProof() async throws {
        // Retained presentation during a pending read must not hide a completed failure or grant partial recovery proof.
        try await withEditor(live: false) { controller, backend, project in
            let read = AssignmentDisplayBarrier()
            backend.readBarrier = read
            let refresh = Task { await controller.refresh() }
            await read.waitUntilEntered()
            backend.readError = .assignmentUnavailable
            read.release(); await refresh.value
            var display = AssignmentPresentation(controller: controller, project: project, selection: .useDefault)
            XCTAssertFalse(display.canSave)
            XCTAssertNotNil(display.disabledReason)
            XCTAssertNotNil(controller.assignmentError)
            await controller.saveAssignment(projectID: project.id, accountID: nil)
            XCTAssertTrue(backend.changes.isEmpty)
            backend.readError = nil; backend.port = .occupied
            await controller.refresh()
            display = AssignmentPresentation(controller: controller, project: project, selection: .useDefault)
            XCTAssertFalse(display.canSave)
            XCTAssertNotNil(display.disabledReason)
            await controller.saveAssignment(projectID: project.id, accountID: nil)
            XCTAssertTrue(backend.changes.isEmpty)
            backend.port = .empty
            let probe = AssignmentDisplayBarrier(); backend.portBarrier = probe
            let recovering = Task { await controller.refresh() }
            await probe.waitUntilEntered()
            XCTAssertFalse(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            probe.release(); await recovering.value
            XCTAssertTrue(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            XCTAssertTrue(backend.changes.isEmpty)
        }
    }
    func testUnavailableStoppedReadRevokesEditorBeforePortProbeCompletes() async throws {
        try await assertNegativeStoppedReadRevokesBeforePortProbe(savedState: "unavailable")
    }
    func testConflictingStoppedReadRevokesEditorBeforePortProbeCompletes() async throws {
        try await assertNegativeStoppedReadRevokesBeforePortProbe(savedState: "conflict")
    }
    private func assertNegativeStoppedReadRevokesBeforePortProbe(savedState: String) async throws {
        // A returned negative state is already evidence; a delayed port observation cannot leave Save available.
        try await withEditor(live: false) { controller, backend, project in
            XCTAssertTrue(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            backend.returnedSavedState = savedState
            let negative = try backend.state(projectID: project.id, live: false)
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(negative))
            XCTAssertNotNil(AssignmentWire.state(object, context: backend.context, projectID: project.id, operationID: nil, live: false))
            let probe = AssignmentDisplayBarrier(); backend.portBarrier = probe
            let refresh = Task { await controller.refresh() }
            await probe.waitUntilEntered()
            let display = AssignmentPresentation(controller: controller, project: project, selection: .useDefault)
            XCTAssertFalse(controller.canEditAssignment(project))
            XCTAssertFalse(display.canSave)
            XCTAssertNotNil(display.disabledReason)
            XCTAssertEqual(display.savedText, "Saved assignment unavailable — refresh to check")
            XCTAssertEqual(controller.selectedAssignment?.savedState, savedState)
            XCTAssertTrue(backend.changes.isEmpty)
            probe.release(); await refresh.value
            await controller.saveAssignment(projectID: project.id, accountID: nil)
            XCTAssertTrue(backend.changes.isEmpty)
            backend.returnedSavedState = "ready"
            let read = AssignmentDisplayBarrier(), healthyProbe = AssignmentDisplayBarrier()
            backend.readBarrier = read; backend.portBarrier = healthyProbe
            let recovering = Task { await controller.refresh() }
            await read.waitUntilEntered()
            XCTAssertFalse(controller.canEditAssignment(project))
            read.release(); await healthyProbe.waitUntilEntered()
            XCTAssertFalse(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            healthyProbe.release(); await recovering.value
            XCTAssertTrue(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            XCTAssertTrue(backend.changes.isEmpty)
        }
    }
    func testStoppedRefreshDoesNotRestoreAuthorityFromPartialStorageCheck() async throws {
        // Removing a known lease must not combine new storage safety with an old read and port proof.
        try await withEditor(live: false) { controller, backend, project in
            let lease = URL(fileURLWithPath: backend.context.configPath).deletingLastPathComponent().appendingPathComponent(".activation.lock")
            try Data("synthetic active lease".utf8).write(to: lease)
            await controller.refresh()
            XCTAssertFalse(controller.canEditAssignment(project))
            try FileManager.default.removeItem(at: lease)
            let read = AssignmentDisplayBarrier(), probe = AssignmentDisplayBarrier()
            backend.readBarrier = read; backend.portBarrier = probe
            let refresh = Task { await controller.refresh() }
            await read.waitUntilEntered()
            XCTAssertFalse(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            read.release(); await probe.waitUntilEntered()
            XCTAssertFalse(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            probe.release(); await refresh.value
            XCTAssertTrue(controller.canEditAssignment(project))
            XCTAssertTrue(backend.changes.isEmpty)
        }
    }
    func testAssignSwitchAndUseDefaultUseStableIDs() async throws {
        // Duplicate display names must not turn a selection into a different account or project.
        try await withEditor { controller, backend, project in
            let editor = AssignmentEditor()
            await editor.load(controller: controller, project: project)
            for choice in [AssignmentSelection.account(backend.work.id), .account(backend.personal.id), .useDefault] {
                let presentation = AssignmentPresentation(controller: controller, project: project, selection: choice)
                XCTAssertTrue(presentation.canSave)
                XCTAssertEqual(presentation.actionTitle, "Save and apply")
                editor.selection = choice
                await editor.save(controller: controller, project: project)
            }
            XCTAssertEqual(backend.changes.map(\.projectId), [project.id, project.id, project.id])
            XCTAssertEqual(backend.changes.map(\.accountId), [backend.work.id, backend.personal.id, nil])
            XCTAssertEqual(Set(backend.changes.map(\.operationId)).count, 3)
            XCTAssertEqual(controller.selectedAssignment?.savedAssignment?.kind, "inherited")
            XCTAssertEqual(controller.projectRoutingStatus, .known(.off))
            XCTAssertEqual(backend.starts, 1)
        }
        try await withEditor(live: false) { controller, _, project in
            let stoppedPresentation = AssignmentPresentation(controller: controller, project: project, selection: .useDefault)
            XCTAssertEqual(stoppedPresentation.actionTitle, "Save")
            XCTAssertTrue(stoppedPresentation.canSave)
        }
    }
    func testNamedDefaultRemainsExplicitOverride() async throws {
        // Named default and inheritance resolve to the same account but persist different intent.
        try await withEditor { controller, backend, project in
            await controller.saveAssignment(projectID: project.id, accountID: backend.personal.id)
            let selection = AssignmentSelection(saved: controller.selectedAssignment?.savedAssignment)
            XCTAssertEqual(selection, .account(backend.personal.id))
            XCTAssertEqual(AssignmentPresentation(controller: controller, project: project, selection: selection).savedText, "Saved: Override — Shared name")
            await controller.saveAssignment(projectID: project.id, accountID: nil)
            XCTAssertEqual(AssignmentSelection(saved: controller.selectedAssignment?.savedAssignment), .useDefault)
            XCTAssertEqual(backend.changes.map(\.accountId), [backend.personal.id, nil])
        }
    }
    func testSavedAndRunningDivergenceNeverLooksApplied() async throws {
        // Runtime names must come from its retained summary, not today's saved account table.
        try await withEditor { controller, backend, project in
            backend.runningSummary = .init(kind: "override", account: .init(id: backend.work.id, displayName: "Previous runtime name"), routeAlias: "private-alias")
            backend.savedSummary = .init(kind: "override", account: .init(id: backend.work.id, displayName: "New saved name"), routeAlias: "private-alias")
            backend.snapshot.configurationRevision = String(repeating: "8", count: 64)
            backend.snapshot.configuration.accounts = [.init(id: backend.work.id, displayName: "New saved name")]
            await controller.refresh()
            let display = AssignmentPresentation(controller: controller, project: project, selection: .account(backend.work.id))
            XCTAssertEqual(display.savedText, "Saved: Override — New saved name")
            XCTAssertEqual(display.runningText, "Running: Override — Previous runtime name (suspended while Off)")
            XCTAssertFalse(display.canSave)
            XCTAssertTrue(display.warning?.contains("differ") == true)
            XCTAssertFalse(display.savedText.contains("private-alias")); XCTAssertFalse(display.runningText.contains("private-alias"))
            XCTAssertEqual(ControlsPresentation(controller: controller).assignment(for: project), display.savedText + "\n" + display.runningText)
        }
    }
    func testConfiguredOnlyWarningAndMissingTargetRepair() async throws {
        // Opening a broken explicit target may not silently choose inheritance.
        try await withEditor(live: false) { controller, backend, original in
            var project = original
            project.name = ""; project.routeState = "catalog_missing"; project.assignmentKind = "target_missing"; project.routeAlias = "missing-route"
            backend.snapshot.catalog.entries = [project]
            backend.savedSummary = .init(kind: "target_missing", routeAlias: "missing-route")
            _ = await controller.loadAssignment(projectID: project.id)
            let selection = AssignmentSelection(saved: controller.selectedAssignment?.savedAssignment)
            XCTAssertEqual(selection, .missingTarget)
            let display = AssignmentPresentation(controller: controller, project: project, selection: selection)
            XCTAssertEqual(display.savedText, "Saved: Missing account target")
            XCTAssertTrue(display.warning?.contains("absent from current discovery") == true)
            XCTAssertFalse(display.canSave)
            let editor = AssignmentEditor()
            await editor.load(controller: controller, project: project)
            await editor.save(controller: controller, project: project)
            XCTAssertTrue(backend.changes.isEmpty)
            XCTAssertEqual(editor.selection, .missingTarget)
            XCTAssertTrue(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).canSave)
            await controller.saveAssignment(projectID: project.id, accountID: backend.work.id)
            XCTAssertEqual(backend.changes.last?.projectId, original.id)
            XCTAssertEqual(controller.selectedAssignment?.savedAssignment?.kind, "override")
            backend.savedSummary = .init(kind: "legacy_inherited", account: backend.personal, routeAlias: "legacy-label")
            _ = await controller.loadAssignment(projectID: project.id)
            XCTAssertEqual(AssignmentSelection(saved: controller.selectedAssignment?.savedAssignment), .useDefault)
            XCTAssertTrue(AssignmentPresentation(controller: controller, project: project, selection: .useDefault).savedText.contains("Inherited label retained"))
            await controller.saveAssignment(projectID: project.id, accountID: nil)
            XCTAssertNil(controller.selectedAssignment?.savedAssignment?.routeAlias)
        }
    }
    func testOffSuspensionAndUnavailableControlRemainClear() async throws {
        // Off never presents an override as effective; channel loss never reuses old authority.
        try await withEditor { controller, backend, project in
            await controller.saveAssignment(projectID: project.id, accountID: backend.work.id)
            var display = AssignmentPresentation(controller: controller, project: project, selection: .account(backend.work.id))
            XCTAssertTrue(display.runningText.contains("suspended while Off"))
            XCTAssertFalse(display.runningText.contains("active"))
            backend.readError = .assignmentUnavailable
            let unavailable = await controller.loadAssignment(projectID: project.id)
            XCTAssertNil(unavailable)
            display = AssignmentPresentation(controller: controller, project: project, selection: .account(backend.work.id))
            XCTAssertEqual(display.runningText, "Running assignment unconfirmed")
            XCTAssertFalse(display.canSave); XCTAssertNotNil(display.disabledReason)
            XCTAssertFalse(display.savedText.contains("key")); XCTAssertFalse(display.runningText.contains("billing"))
        }
    }
    func testDismissalDoesNotRetryOrOwnMutation() async throws {
        // Dropping editor-local state cannot cancel or retry the controller's accepted action.
        try await withEditor { controller, backend, project in
            var editor: AssignmentEditor? = AssignmentEditor()
            await editor?.load(controller: controller, project: project)
            editor?.selection = .account(backend.work.id)
            backend.holdSave = true
            let saving = Task { [editor] in await editor?.save(controller: controller, project: project) }
            await backend.waitForSave()
            let operation = try XCTUnwrap(controller.pendingAssignmentOperationID)
            let pending = AssignmentPresentation(controller: controller, project: project, selection: .account(backend.work.id))
            XCTAssertFalse(pending.canSave)
            XCTAssertTrue(pending.warning?.contains("in progress") == true)
            XCTAssertTrue(ControlsPresentation(controller: controller).assignmentGuidance?.contains("in progress") == true)
            editor = nil
            XCTAssertEqual(controller.pendingAssignmentOperationID, operation)
            backend.releaseSave(); await saving.value
            XCTAssertEqual(backend.changes.count, 1)
            XCTAssertNil(controller.pendingAssignmentOperationID)
            XCTAssertFalse(controller.assignmentRequiresReconciliation)
            backend.saveError = .assignmentConflict
            let reopened = AssignmentEditor()
            await reopened.load(controller: controller, project: project)
            reopened.selection = .account(backend.personal.id)
            await reopened.save(controller: controller, project: project)
            XCTAssertEqual(reopened.selection, .account(backend.personal.id))
            XCTAssertEqual(controller.selectedAssignment?.savedAssignment?.account?.id, backend.work.id)
            XCTAssertNotNil(controller.assignmentError)
            // Background observations and presentation do not explicitly reload/rebase the editor.
            backend.snapshot.configurationRevision = String(repeating: "9", count: 64)
            backend.runningRevision = backend.snapshot.configurationRevision!
            await controller.refresh()
            reopened.selection = .useDefault
            let before = backend.changes.count
            await reopened.save(controller: controller, project: project)
            XCTAssertEqual(backend.changes.count, before)
            XCTAssertEqual(reopened.selection, .useDefault)
            backend.saveError = nil
            await reopened.load(controller: controller, project: project)
            XCTAssertEqual(reopened.selection, .account(backend.work.id))
            reopened.selection = .useDefault
            await reopened.save(controller: controller, project: project)
            XCTAssertEqual(backend.changes.count, before + 1)
        }
    }
}

@MainActor private final class AssignmentDisplayBackend: CompanionBackend, ProjectAssignmentBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false
    let context: ActivationContext
    let personal = AccountSummary(id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", displayName: "Shared name")
    let work = AccountSummary(id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", displayName: "Shared name")
    var snapshot: Inspection
    var savedSummary = AssignmentSummary(kind: "inherited")
    var runningSummary = AssignmentSummary(kind: "inherited")
    var runningRevision = String(repeating: "1", count: 64)
    var runningIdentity = String(repeating: "2", count: 64)
    var runningFingerprint = String(repeating: "3", count: 64)
    var intent: AssignmentIntent?
    var mode = ProjectRoutingMode.off
    var readError: CompanionError?
    var returnedSavedState = "ready"
    var readBarrier: AssignmentDisplayBarrier?
    var portBarrier: AssignmentDisplayBarrier?
    var port = StopOutcome.PortState.empty
    var saveError: CompanionError?
    var changes: [AssignmentChange] = []
    var starts = 0
    var holdSave = false
    private var saveContinuation: CheckedContinuation<Void, Never>?
    private var saveStarted: CheckedContinuation<Void, Never>?
    private var saving = false
    init(root: URL) {
        context = .init(configPath: root.appendingPathComponent("config.json").path, codexHome: root.appendingPathComponent("codex").path, providerId: "synthetic", listenPort: 43129)
        snapshot = .init(configuration: .init(state: "valid", path: context.configPath, mode: "accounts", setupState: "ready", defaultAccount: personal, accounts: [personal, work]), context: context, revision: "synthetic-operational",
            provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"),
            catalog: .init(state: "ready", entries: [.init(id: "11111111-1111-4111-8111-111111111111", name: "Exact project", routeAlias: nil, routeState: "unmapped", account: personal, assignmentKind: "inherited")], revision: String(repeating: "5", count: 64)),
            configurationRevision: String(repeating: "1", count: 64), configurationIdentity: String(repeating: "2", count: 64), routingFingerprint: String(repeating: "3", count: 64), recoveryRevision: String(repeating: "4", count: 64))
        savedSummary.account = personal; runningSummary = savedSummary
    }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection { snapshot }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ path: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter { starts += 1; snapshot.provider.proxyReady = true; return .init(process: AssignmentDisplayProcess(), context: context) }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult { throw CompanionError.commandFailed }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode { mode }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode { self.mode = mode; return mode }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome { throw CompanionError.unownedChild }
    func state(projectID: String?, live: Bool) throws -> AssignmentState {
        if let readError { throw readError }
        let ready = returnedSavedState == "ready"
        return .init(context: context, savedState: returnedSavedState, savedRevision: ready ? snapshot.configurationRevision : nil, savedIdentity: ready ? snapshot.configurationIdentity : nil,
            savedFingerprint: ready ? snapshot.routingFingerprint : nil, catalogRevision: ready ? snapshot.catalog.revision : nil, runningRevision: live ? runningRevision : nil,
            runningIdentity: live ? runningIdentity : nil, runningFingerprint: live ? runningFingerprint : nil,
            mode: live ? mode : nil, projectId: projectID, savedAssignment: ready && projectID != nil ? savedSummary : nil,
            runningAssignment: live && projectID != nil ? runningSummary : nil, intent: ready ? intent : nil, lastAttempt: nil)
    }
    func readAssignment(_ child: OwnedRouter, projectID: String?, operationID: String?) async throws -> AssignmentState { try state(projectID: projectID, live: true) }
    func readStoppedAssignment(context: ActivationContext, projectID: String, operationID: String?) async throws -> AssignmentState {
        if let barrier = readBarrier { readBarrier = nil; await barrier.enter() }
        return try state(projectID: projectID, live: false)
    }
    func probeAssignmentPort(_ context: ActivationContext) async -> StopOutcome.PortState {
        if let barrier = portBarrier { portBarrier = nil; await barrier.enter() }
        return port
    }
    func applyAssignment(_ change: AssignmentChange, to child: OwnedRouter) async throws -> AssignmentCommit { try await save(change, live: true) }
    func saveStoppedAssignment(_ change: AssignmentChange) async throws -> AssignmentCommit { try await save(change, live: false) }
    private func save(_ change: AssignmentChange, live: Bool) async throws -> AssignmentCommit {
        changes.append(change); saving = true; saveStarted?.resume(); saveStarted = nil
        if holdSave { await withCheckedContinuation { saveContinuation = $0 } }
        if let saveError { throw saveError }
        let before = savedSummary
        let selected = snapshot.configuration.accounts?.first { $0.id == change.accountId }
        savedSummary = change.accountId == nil ? .init(kind: "inherited", account: personal) : .init(kind: "override", account: selected, routeAlias: "technical-binding")
        snapshot.configurationRevision = String(repeating: snapshot.configurationRevision == String(repeating: "6", count: 64) ? "7" : "6", count: 64)
        snapshot.configurationIdentity = String(repeating: snapshot.configurationIdentity == String(repeating: "2", count: 64) ? "a" : "2", count: 64)
        snapshot.routingFingerprint = String(repeating: snapshot.routingFingerprint == String(repeating: "3", count: 64) ? "b" : "3", count: 64)
        intent = .init(schemaVersion: 1, operationId: change.operationId, context: context, projectId: change.projectId,
            accountId: change.accountId, checkpointName: "assignment-checkpoint-\(change.operationId.lowercased()).json",
            beforeRevision: change.expectedSavedRevision, beforeIdentity: change.expectedConfigurationIdentity,
            candidateRevision: snapshot.configurationRevision!, candidateIdentity: snapshot.configurationIdentity!)
        if live {
            runningRevision = snapshot.configurationRevision!; runningSummary = savedSummary
            runningIdentity = snapshot.configurationIdentity!; runningFingerprint = snapshot.routingFingerprint!
        }
        return .init(context: context, operationId: change.operationId, projectId: change.projectId, changed: true,
            beforeRevision: change.expectedSavedRevision, candidateRevision: snapshot.configurationRevision!, savedRevision: snapshot.configurationRevision!,
            beforeIdentity: change.expectedConfigurationIdentity, candidateIdentity: snapshot.configurationIdentity!, savedIdentity: snapshot.configurationIdentity!,
            before: before, after: savedSummary, checkpointPath: intent.map { URL(fileURLWithPath: change.configPath).deletingLastPathComponent().appendingPathComponent($0.checkpointName).path },
            intent: intent, runningRevision: live ? runningRevision : nil,
            runningIdentity: live ? runningIdentity : nil, runningFingerprint: live ? runningFingerprint : nil)
    }
    func waitForSave() async { if !saving { await withCheckedContinuation { saveStarted = $0 } } }
    func releaseSave() { saveContinuation?.resume(); saveContinuation = nil; holdSave = false }
}
private final class AssignmentDisplayProcess: Process, @unchecked Sendable { override var isRunning: Bool { true } }

@MainActor private final class AssignmentDisplayBarrier {
    private var continuation: CheckedContinuation<Void, Never>?
    private var entered: CheckedContinuation<Void, Never>?
    private var isEntered = false
    func enter() async {
        await withCheckedContinuation { continuation = $0; isEntered = true; entered?.resume(); entered = nil }
    }
    func waitUntilEntered() async {
        if !isEntered { await withCheckedContinuation { entered = $0 } }
    }
    func release() { continuation?.resume(); continuation = nil }
}
