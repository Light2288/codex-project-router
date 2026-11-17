import XCTest
import Darwin
@testable import CompanionCore

@MainActor final class ProcessBackendTests: XCTestCase {
    private var root: URL!; private var resources: URL!; private var node: URL!; private var config: URL!
    private var backend: ProcessBackend!
    private var startedChildren: [OwnedRouter] = []
    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("companion process \(UUID())")
        resources = root.appendingPathComponent("bundled resources")
        try FileManager.default.createDirectory(at: resources.appendingPathComponent("src"), withIntermediateDirectories: true)
        node = root.appendingPathComponent("selected node")
        try FileManager.default.copyItem(at: Bundle.module.url(forResource: "node-fixture", withExtension: nil, subdirectory: "Fixtures")!, to: node)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: node.path)
        for name in ["companion-cli.js", "cli.js", "managed-serve.js"] { try Data().write(to: resources.appendingPathComponent("src/\(name)")) }
        try setMode("valid")
        config = root.appendingPathComponent("selected config.json")
        let port = try unusedPort()
        try JSONSerialization.data(withJSONObject: ["port": port, "home": root.appendingPathComponent("synthetic home").path]).write(to: config)
        backend = ProcessBackend(resourcesURL: resources, nodeExecutable: node)
    }
    override func tearDown() async throws {
        // Retain exact managed Process objects even if later helper commands replace the PID marker.
        for child in startedChildren where child.process.isRunning {
            kill(child.process.processIdentifier, SIGKILL)
            while child.process.isRunning { try await Task.sleep(nanoseconds: 10_000_000) }
        }
        // Kill only this test's retained fixture PID if an assertion interrupted lifecycle cleanup.
        if let data = try? String(contentsOf: resources.appendingPathComponent("src/pid")), let pid = Int32(data), kill(pid, 0) == 0 { kill(pid, SIGKILL) }
        try FileManager.default.removeItem(at: root)
    }
    private func largeSetupChange(_ preview: SetupPreview) -> SetupChange {
        .migrate(accounts: (0..<1000).map { AccountRecord(id: UUID().uuidString, displayName: "Synthetic \($0)", upstreamBaseUrl: "https://example.invalid/api", credential: preview.incomingCredential!) }, incomingCredential: preview.incomingCredential, defaultAccountId: preview.defaultAccountId)
    }
    func testLargeSetupInputLeavesMainActorResponsiveWhileHelperDelaysReading() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: root), change = largeSetupChange(preview)
        let encoded = try JSONEncoder().encode(change)
        XCTAssertGreaterThan(encoded.count, 65_536); XCTAssertLessThan(encoded.count, 1024 * 1024)
        try setMode("stdinDelayed")
        let started = Date()
        let request = Task { try await backend.commitSetup(change, context: preview.context, revision: preview.configurationRevision, operationID: UUID().uuidString) }
        try await waitForFixture("stdin-paused")
        XCTAssertLessThan(Date().timeIntervalSince(started), 1, "Stdin delivery blocked MainActor before its first UI heartbeat")
        let result = try await request.value
        XCTAssertTrue(result.changed)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        let delivered = try Data(contentsOf: resources.appendingPathComponent("src/setup-request"))
        XCTAssertGreaterThan(delivered.count, 65_536)
    }
    func testLargeSetupInputTimeoutRetainsWritingHelperUntilNaturalExit() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: root), change = largeSetupChange(preview), op = UUID().uuidString
        try setMode("stdinTimeout")
        let started = Date()
        do { _ = try await backend.commitSetup(change, context: preview.context, revision: preview.configurationRevision, operationID: op); XCTFail("Stalled reader accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        XCTAssertLessThan(Date().timeIntervalSince(started), 5.8)
        let pid = try fixturePID()
        XCTAssertEqual(kill(pid, 0), 0); XCTAssertTrue(backend.setupHelperIsRunning)
        XCTAssertThrowsError(try backend.finishSetupReconciliation(operationID: op))
        try await waitForExit(pid)
        XCTAssertFalse(backend.setupHelperIsRunning); XCTAssertTrue(backend.mutationRequiresReconciliation)
        XCTAssertEqual(backend.uncertainSetupOperationID, op)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resources.appendingPathComponent("src/setup-request").path))
    }
    func testLargeSetupInputCancellationRetainsDeliveryWithoutRetry() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: root), change = largeSetupChange(preview), op = UUID().uuidString
        try setMode("stdinCancelled")
        let started = Date()
        let request = Task { try await backend.commitSetup(change, context: preview.context, revision: preview.configurationRevision, operationID: op) }
        try await waitForFixture("stdin-paused")
        let pid = try fixturePID()
        request.cancel()
        do { _ = try await request.value; XCTFail("Cancelled input accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
        XCTAssertEqual(kill(pid, 0), 0); XCTAssertTrue(backend.setupHelperIsRunning)
        do { _ = try await backend.commitSetup(change, context: preview.context, revision: preview.configurationRevision, operationID: UUID().uuidString); XCTFail("Cancelled input retried") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        try releaseFixture("release-stdin"); try await waitForExit(pid)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resources.appendingPathComponent("src/setup-request").path))
        XCTAssertFalse(backend.setupHelperIsRunning); XCTAssertTrue(backend.mutationRequiresReconciliation)
    }
    func testEarlyStdinClosureRejectsPlausibleSuccessAfterIncompleteDelivery() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: root), change = largeSetupChange(preview), op = UUID().uuidString
        let response = SetupCommitResult(context: preview.context, operationId: op, setupState: "ready", configurationRevision: String(repeating: "b", count: 64), checkpointPath: nil, changed: true)
        try JSONEncoder().encode(response).write(to: resources.appendingPathComponent("src/stdin-response"))
        try setMode("stdinEarlyExit")
        do { _ = try await backend.commitSetup(change, context: preview.context, revision: preview.configurationRevision, operationID: op); XCTFail("Incomplete delivery accepted as success") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        try await waitForExit(try fixturePID())
        XCTAssertTrue(backend.mutationRequiresReconciliation); XCTAssertFalse(backend.setupHelperIsRunning)
        XCTAssertEqual(backend.uncertainSetupOperationID, op)
        XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("src/setup-request").path))
    }
    func testSetupBridgeUsesMetadataOnlyLargerInputAndValidatesReturnedStates() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: root)
        XCTAssertEqual(preview.sourceKind, "accounts")
        let accounts = (0..<150).map { AccountRecord(id: UUID().uuidString, displayName: "Synthetic \($0)", upstreamBaseUrl: "https://example.invalid/api", credential: preview.incomingCredential!) }
        let op = UUID().uuidString
        let result = try await backend.commitSetup(.migrate(accounts: accounts, incomingCredential: preview.incomingCredential, defaultAccountId: accounts[0].id), context: preview.context, revision: preview.configurationRevision, operationID: op)
        XCTAssertEqual(result.operationId, op)
        let bytes = try Data(contentsOf: resources.appendingPathComponent("src/setup-request"))
        XCTAssertGreaterThan(bytes.count, 16 * 1024); XCTAssertLessThan(bytes.count, 1024 * 1024)
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("secret"))
        for mode in ["setupUnknownState", "setupWrongContext", "wireUnknownSetup", "wireUnknownAssignment"] {
            try setMode(mode)
            do {
                if mode.hasPrefix("wire") { _ = try await backend.inspect(configPath: config, browseHome: root) }
                else { _ = try await backend.previewSetup(configPath: config, browseHome: root) }
                XCTFail("Unsupported setup evidence accepted: \(mode)")
            } catch { XCTAssertEqual(error as? CompanionError, .protocolFailure) }
        }
    }
    func testSetupTimeoutRetainsExactHelperUntilExit() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: root), op = UUID().uuidString
        try setMode("mutationStall")
        do { _ = try await backend.commitSetup(.setDefault(defaultAccountId: preview.defaultAccountId), context: preview.context, revision: preview.configurationRevision, operationID: op); XCTFail("Timed out setup accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        let pid = try fixturePID()
        XCTAssertEqual(kill(pid, 0), 0); XCTAssertTrue(backend.setupHelperIsRunning)
        XCTAssertThrowsError(try backend.finishSetupReconciliation(operationID: op))
        try await waitForExit(pid)
        try setMode("valid")
        _ = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertFalse(backend.setupHelperIsRunning); XCTAssertTrue(backend.mutationRequiresReconciliation)
        XCTAssertEqual(backend.uncertainSetupOperationID, op)
    }
    func testSetupLostReplyCannotBeClearedByDirectInspection() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: root), op = UUID().uuidString
        try setMode("setupLostReply")
        do { _ = try await backend.commitSetup(.setDefault(defaultAccountId: preview.defaultAccountId), context: preview.context, revision: preview.configurationRevision, operationID: op); XCTFail("Lost reply accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        XCTAssertFalse(backend.setupHelperIsRunning); XCTAssertTrue(backend.mutationRequiresReconciliation)
        try setMode("valid")
        _ = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertTrue(backend.mutationRequiresReconciliation); XCTAssertEqual(backend.uncertainSetupOperationID, op)
        XCTAssertThrowsError(try backend.finishSetupReconciliation(operationID: UUID().uuidString))
        try backend.finishSetupReconciliation(operationID: op)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
    }
    func testBackendRejectsIncompleteAndLegacyManagedActionsButPreservesRecovery() async throws {
        for mode in ["setupRequired", "legacySetup"] {
            try setMode(mode)
            let value = try await backend.inspect(configPath: config, browseHome: root), context = try XCTUnwrap(value.context)
            do { _ = try await backend.start(configPath: config); XCTFail("Incomplete setup started") }
            catch { XCTAssertEqual(error as? CompanionError, .startupFailed) }
            do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Incomplete setup activated") }
            catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
            let result = try await backend.control(action: .rollback, configPath: config, expectedContext: context)
            XCTAssertEqual(result.state, "direct")
        }
    }
    func testNodeSelectionIgnoresGuiPath() async throws {
        // Using PATH or accepting the wrong major would select an unvalidated runtime.
        let previousPath = ProcessInfo.processInfo.environment["PATH"]
        setenv("PATH", "/does-not-exist", 1)
        defer { if let previousPath { setenv("PATH", previousPath, 1) } else { unsetenv("PATH") } }
        let validated = try await backend.validateNode(node)
        XCTAssertEqual(validated, node.resolvingSymlinksInPath())
        let wrong = root.appendingPathComponent("wrong node")
        try FileManager.default.copyItem(at: node, to: wrong)
        do { _ = try await backend.validateNode(wrong); XCTFail("Wrong major accepted") } catch { XCTAssertEqual(error as? CompanionError, .nodeUnavailable) }
        do { _ = try await backend.validateNode(root.appendingPathComponent("missing")); XCTFail("Missing executable accepted") } catch { XCTAssertEqual(error as? CompanionError, .nodeUnavailable) }
        let result = try await backend.inspect(configPath: nil, browseHome: root)
        XCTAssertEqual(result.configuration.state, "missing"); XCTAssertNil(result.provider.proxyReady)
        XCTAssertNil(result.catalog.entries.first?.routeAlias)
    }
    func testMissingSelectedDestinationPassesExplicitCatalogBrowseHome() async throws {
        // Omitting browseHome for a saved absent path makes first-setup browsing unavailable.
        let encoder = JSONEncoder(); encoder.outputFormatting = .withoutEscapingSlashes
        let homeJSON = String(data: try encoder.encode(root.path), encoding: .utf8)!
        let configJSON = String(data: try encoder.encode(config.path), encoding: .utf8)!
        let script = """
        #!/usr/bin/python3
        import json, sys
        if sys.argv[1:] == ['--version']:
            print('v24.10.0'); sys.exit(0)
        request = json.load(sys.stdin)
        if request.get('browseHome') != \(homeJSON) or request.get('configPath') != \(configJSON): sys.exit(7)
        print(json.dumps(dict(schemaVersion=1,ok=True,result=dict(configuration=dict(state='missing'),provider=dict(state='unavailable',recoveryRequired=True,proxyReady=None,recordPhase='unavailable'),catalog=dict(state='ready',entries=[dict(id='A',name='Available during setup',routeAlias=None,routeState='unmapped')])))))
        """
        try script.write(to: node, atomically: false, encoding: .utf8)
        try FileManager.default.removeItem(at: config)
        let result = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertEqual(result.configuration.state, "missing")
        XCTAssertEqual(result.catalog.entries.first?.name, "Available during setup")
        XCTAssertNil(result.context); XCTAssertNil(result.revision)
    }
    func testProtocolOverflowNeverEchoesPayload() async throws {
        // Unbounded accumulation or raw child errors would expose the sentinel.
        try setMode("overflow")
        do { _ = try await backend.inspect(configPath: nil, browseHome: root); XCTFail("Overflow accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .protocolFailure); XCTAssertFalse(error.localizedDescription.contains("SENTINEL")) }
    }
    func testMalformedFailureAndStderrFloodAreFixedErrors() async throws {
        // Parsing plausible stdout after nonzero exit, or logging stderr, would violate this boundary.
        for mode in ["malformed", "exitFailure", "stderr", "unknown"] {
            try setMode(mode)
            do { _ = try await backend.inspect(configPath: nil, browseHome: root); XCTFail("Unsafe child accepted: \(mode)") }
            catch { XCTAssertTrue(error is CompanionError); XCTAssertFalse(error.localizedDescription.contains("SENTINEL")) }
        }
    }
    func testMissingResourcesAndSanitizedEnvironment() async throws {
        setenv("NODE_OPTIONS", "SENTINEL_PRIVATE", 1); setenv("NODE_PATH", "SENTINEL_PRIVATE", 1); setenv("COMPANION_SECRET", "SENTINEL_PRIVATE", 1)
        defer { unsetenv("NODE_OPTIONS"); unsetenv("NODE_PATH"); unsetenv("COMPANION_SECRET") }
        _ = try await backend.inspect(configPath: nil, browseHome: root)
        let missing = ProcessBackend(resourcesURL: root.appendingPathComponent("missing resources"), nodeExecutable: node)
        do { _ = try await missing.inspect(configPath: nil, browseHome: root); XCTFail("Missing resources accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .resourcesUnavailable) }
    }
    func testStalledReadOnlyChildIsCleanedUp() async throws {
        // A timeout that abandons the Process leaks a child and its open pipes.
        try setMode("stall")
        let start = Date()
        do { _ = try await backend.inspect(configPath: nil, browseHome: root); XCTFail("Stall accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .timedOut) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 7)
        let pid = try fixturePID(); XCTAssertNotEqual(kill(pid, 0), 0)
    }
    func testMutationTimeoutRetainsChildAndRequiresReconciliation() async throws {
        // Killing/retrying a write after deadline could duplicate provider mutation.
        try setMode("mutationStall")
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(inspection.context)
        do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Stall accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        let pid = try fixturePID(); XCTAssertEqual(kill(pid, 0), 0)
        do { _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context); XCTFail("Second mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        try await Task.sleep(nanoseconds: 1_600_000_000)
        try setMode("valid")
        do { _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context); XCTFail("Unreconciled mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        _ = try await backend.inspect(configPath: config, browseHome: root)
        let control = try await backend.control(action: .rollback, configPath: config, expectedContext: context)
        XCTAssertTrue(control.changed)
    }
    func testOnlyTrackedLiveChildCanBeStopped() async throws {
        // Accepting a fabricated/recovered Process would turn stale process metadata into authority.
        let child = try await startFixture()
        XCTAssertTrue(child.process.isRunning)
        let forgery = OwnedRouter(process: child.process, context: child.context, id: child.id)
        do { _ = try await backend.stop(forgery); XCTFail("Forged ownership accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
        XCTAssertTrue(child.process.isRunning)
        let stopped = try await backend.stop(child)
        XCTAssertTrue(stopped.childExited); XCTAssertEqual(stopped.portState, .empty)
        do { _ = try await backend.stop(child); XCTFail("Exited child accepted") } catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
    }
    func testLongLivedOutputDrainsAndExitCallbackFires() async throws {
        // A full stdout/stderr pipe must not freeze the router; child exit must invalidate controller evidence.
        try setMode("longOutput")
        var exits: [(UUID, Int32)] = []; backend.onChildExit = { exits.append(($0, $1)) }
        let child = try await startFixture()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(child.process.isRunning)
        _ = try await backend.stop(child)
        XCTAssertEqual(exits.count, 1); XCTAssertEqual(exits.first?.0, child.id)
    }
    func testFailedMutationRequiresReconciliation() async throws {
        // Nonzero exit can follow a provider write; plausible stdout must not authorize another write.
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(inspection.context)
        try setMode("mutationExitFailure")
        do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Failed mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        try setMode("valid")
        do { _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context); XCTFail("Unreconciled write accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        _ = try await backend.inspect(configPath: config, browseHome: root)
        _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context)
    }
    func testCancelledMutationIsRetainedAndNotRetried() async throws {
        // Cancellation must not terminate a write that may already have changed the provider.
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(inspection.context)
        try setMode("mutationStall")
        let task = Task { try await backend.control(action: .activate, configPath: config, expectedContext: context) }
        try await Task.sleep(nanoseconds: 300_000_000)
        let pid = try fixturePID()
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        XCTAssertEqual(kill(pid, 0), 0)
        do { _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context); XCTFail("Second mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        // The fixture exits naturally; no cancellation-driven signal is sent.
        while kill(pid, 0) == 0 { try await Task.sleep(nanoseconds: 50_000_000) }
    }
    func testStartupUncertaintyRetainsChildAndDeadChildCannotBeAdopted() async throws {
        // Readiness timeout must retain the child without claiming its port is ready.
        try setMode("unready")
        let child = try await startFixture()
        XCTAssertTrue(child.process.isRunning)
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertEqual(inspection.provider.proxyReady, false)
        _ = try await backend.stop(child)
        try setMode("childExit")
        do { _ = try await startFixture(); XCTFail("Exited router accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .startupFailed) }
    }
    func testPortReuseIsReportedWithoutAdoptingTheListener() async throws {
        // Child termination and an empty port are separate facts; a replacement listener remains external.
        try setMode("reusePort")
        let child = try await startFixture()
        let replacement = Process(); replacement.executableURL = node
        replacement.arguments = ["--hold-port", String(child.context.listenPort), resources.appendingPathComponent("src/released").path]
        try replacement.run()
        defer { if replacement.isRunning { replacement.terminate(); replacement.waitUntilExit() } }
        let outcome = try await backend.stop(child)
        XCTAssertTrue(outcome.childExited); XCTAssertEqual(outcome.portState, .occupied)
        XCTAssertTrue(replacement.isRunning)
        do { _ = try await backend.stop(child); XCTFail("Stale child accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
        XCTAssertTrue(replacement.isRunning)
    }
    func testPreExitInspectionCannotReconcileUncertainMutation() async throws {
        // A snapshot captured while the mutation is running must not authorize the next write.
        let initial = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(initial.context)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        try setMode("heldMutation")
        defer { try? releaseFixture("release-mutation"); try? releaseFixture("release-snapshot") }
        let mutation = Task { try await backend.control(action: .activate, configPath: config, expectedContext: context) }
        try await waitForFixture("mutation-started")
        let mutationPID = try fixturePID()
        mutation.cancel()
        do { _ = try await mutation.value; XCTFail("Cancelled mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        XCTAssertTrue(backend.mutationRequiresReconciliation)
        try setMode("delayedInspection")
        let stale = Task { try await backend.inspect(configPath: config, browseHome: root) }
        try await waitForFixture("snapshot-captured")
        try releaseFixture("release-mutation")
        try await waitForExit(mutationPID)
        try releaseFixture("release-snapshot")
        let snapshot = try await stale.value
        XCTAssertTrue(backend.mutationRequiresReconciliation)
        XCTAssertEqual(snapshot.provider.state, "direct")
        XCTAssertEqual(try String(contentsOf: resources.appendingPathComponent("src/provider-state")), "router")
        try setMode("valid")
        do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Pre-exit snapshot authorized a mutation") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        let fresh = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertEqual(fresh.provider.state, "router")
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context)
    }
    func testInterveningMutationInvalidatesReconciliationInspection() async throws {
        // A reconciliation request for one mutation cannot clear a later mutation's uncertainty.
        let initial = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(initial.context)
        try setMode("mutationExitFailure")
        do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Failed mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        try setMode("delayedInspection")
        defer { try? releaseFixture("release-snapshot") }
        let stale = Task { try await backend.inspect(configPath: config, browseHome: root) }
        try await waitForFixture("snapshot-captured")
        try setMode("valid")
        _ = try await backend.inspect(configPath: config, browseHome: root)
        try setMode("mutationExitFailure")
        do { _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context); XCTFail("Failed mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        try releaseFixture("release-snapshot")
        _ = try await stale.value
        try setMode("valid")
        do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Earlier generation authorized a mutation") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        _ = try await backend.inspect(configPath: config, browseHome: root)
        _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context)
    }
    func testRuntimeDiscoverySharesInspectionDeadline() async throws {
        // Giving each candidate a new timeout lets discovery exceed the whole inspection deadline.
        let first = root.appendingPathComponent("slow wrong node one")
        let second = root.appendingPathComponent("slow wrong node two")
        try FileManager.default.copyItem(at: node, to: first)
        try FileManager.default.copyItem(at: node, to: second)
        let discovering = ProcessBackend(resourcesURL: resources, nodeExecutable: first, discoveryCandidates: [second, node])
        let started = Date()
        do { _ = try await discovering.inspect(configPath: nil, browseHome: root); XCTFail("Slow discovery accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .timedOut) }
        XCTAssertLessThan(Date().timeIntervalSince(started), 5.75)
        XCTAssertFalse(FileManager.default.fileExists(atPath: node.path + ".version-started"), "Discovery continued after the shared deadline")
        for candidate in [first, second] {
            let pid = try XCTUnwrap(Int32(String(contentsOfFile: candidate.path + ".version-started")))
            XCTAssertNotEqual(kill(pid, 0), 0, "Validation child survived its deadline")
        }
    }
    func testManagedReadyBindsExactChildAndContext() async throws {
        // Historical health or a forged wrapper must not grant the managed capability.
        setenv("NODE_OPTIONS", "SENTINEL_PRIVATE", 1); setenv("COMPANION_SECRET", "SENTINEL_PRIVATE", 1)
        defer { unsetenv("NODE_OPTIONS"); unsetenv("COMPANION_SECRET") }
        let child = try await startFixture()
        let beforeModeCommands = try String(contentsOf: resources.appendingPathComponent("src/invocations"))
        let initialMode = try await backend.readRoutingMode(child)
        XCTAssertEqual(initialMode, .off)
        let appliedMode = try await backend.setRoutingMode(.on, for: child)
        XCTAssertEqual(appliedMode, .on)
        let forgery = OwnedRouter(process: child.process, context: child.context, id: child.id)
        do { _ = try await backend.readRoutingMode(forgery); XCTFail("Forged read accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
        do { _ = try await backend.setRoutingMode(.off, for: forgery); XCTFail("Forged set accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        let invocations = try String(contentsOf: resources.appendingPathComponent("src/invocations"))
        XCTAssertEqual(invocations, beforeModeCommands, "Mode commands launched a helper or credential/preflight process")
        XCTAssertFalse(invocations.contains("activate")); XCTAssertFalse(invocations.contains("rollback"))
        XCTAssertFalse(invocations.contains("preflight")); XCTAssertFalse(invocations.contains("auth"))
        XCTAssertTrue(child.process.arguments?.contains(child.id.uuidString) == true)
        XCTAssertTrue(child.process.arguments?.contains(config.resolvingSymlinksInPath().path) == true)
        _ = try await backend.stop(child)
    }
    func testTimeoutRetainsChildAndDoesNotRetryMutation() async throws {
        // Retrying or signalling after a mode deadline can duplicate a switch or stop active requests.
        try setMode("modeTimeout")
        let child = try await startFixture()
        let start = Date()
        do { _ = try await backend.setRoutingMode(.on, for: child); XCTFail("Timeout accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 5.75)
        XCTAssertTrue(child.process.isRunning)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        do { _ = try await backend.setRoutingMode(.off, for: child); XCTFail("Unreconciled switch accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        let mode = try await backend.readRoutingMode(child)
        XCTAssertEqual(mode, .on)
        let commands = try String(contentsOf: resources.appendingPathComponent("src/commands")).split(separator: "\n")
        XCTAssertEqual(commands.filter { $0.contains("set_mode") }.count, 1)
        _ = try await backend.stop(child)
    }
    func testControlLossDoesNotSignalOrResetChild() async throws {
        // Closing stdout must preserve ownership and the running listener for direct recovery.
        try setMode("controlLoss")
        let child = try await startFixture()
        do { _ = try await backend.setRoutingMode(.on, for: child); XCTFail("Lost ack accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        XCTAssertTrue(child.process.isRunning)
        XCTAssertEqual(try String(contentsOf: resources.appendingPathComponent("src/router-mode")), "on")
        do { _ = try await backend.readRoutingMode(child); XCTFail("Lost channel reconciled") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertEqual(inspection.provider.proxyReady, true)
        do { _ = try await backend.readRoutingMode(child); XCTFail("Health probe restored capability") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
        XCTAssertTrue(child.process.isRunning)
        _ = try await backend.stop(child)
    }
    func testUnsupportedReadyNeverGrantsModeAuthority() async throws {
        // A live listener and plausible readiness cannot replace the exact managed handshake.
        for mode in ["unsupportedReady", "wrongContextReady", "noReady", "longOutput"] {
            try setMode(mode)
            let child = try await startFixture()
            XCTAssertTrue(child.process.isRunning)
            do { _ = try await backend.readRoutingMode(child); XCTFail("Unsupported Ready accepted: \(mode)") }
            catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
            _ = try await backend.stop(child)
        }
    }
    func testChildExitClosesChannelAndReplacementCannotReuseIt() async throws {
        // Mode authority must expire with the actual Process, even if a replacement binds the same port.
        let child = try await startFixture()
        let initial = try await backend.readRoutingMode(child)
        XCTAssertEqual(initial, .off)
        _ = try await backend.stop(child)
        let replacement = try await startFixture()
        XCTAssertNotEqual(replacement.id, child.id)
        do { _ = try await backend.setRoutingMode(.on, for: child); XCTFail("Exited child authorized mode") }
        catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
        let replacementMode = try await backend.readRoutingMode(replacement)
        XCTAssertEqual(replacementMode, .off)
        _ = try await backend.stop(replacement)
    }
    func testAssignmentRequiresCapabilityAndExactChild() async throws {
        let child = try await startFixture()
        let change = AssignmentFixtures.change(context: child.context)
        let forgery = OwnedRouter(process: child.process, context: child.context, id: child.id)
        do { _ = try await backend.applyAssignment(change, to: forgery); XCTFail("Forged assignment authority") }
        catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
        let state = try await backend.readAssignment(child, projectID: change.projectId, operationID: nil)
        XCTAssertEqual(state.runningRevision, AssignmentFixtures.token)
        let result = try await backend.applyAssignment(change, to: child)
        XCTAssertEqual(result.operationId, change.operationId)
        XCTAssertEqual(result.runningRevision, AssignmentFixtures.candidate)
        XCTAssertTrue(child.process.isRunning)
        _ = try await backend.stop(child)
        try setMode("modeOnlyReady")
        let old = try await startFixture()
        do { _ = try await backend.readAssignment(old, projectID: change.projectId, operationID: nil); XCTFail("Old ready accepted assignment") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
        let mode = try await backend.readRoutingMode(old); XCTAssertEqual(mode, .off)
        _ = try await backend.stop(old)
    }

    func testAssignmentReadRetainsOwnedPipeAuthorityAfterInspectionFailure() async throws {
        let child = try await startFixture()
        try setMode("malformed")
        do { _ = try await backend.inspect(configPath: config, browseHome: root); XCTFail("Invalid helper observation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .protocolFailure) }
        let state = try await backend.readAssignment(child, projectID: AssignmentFixtures.project, operationID: nil)
        XCTAssertEqual(state.runningRevision, AssignmentFixtures.token)
        XCTAssertTrue(child.process.isRunning)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        _ = try await backend.stop(child)
    }

    func testStoppedHelperMustExitBeforeReconciliation() async throws {
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(inspection.context), change = AssignmentFixtures.change(context: context)
        try setMode("assignmentHeld")
        defer { try? releaseFixture("release-assignment") }
        let saving = Task { try await backend.saveStoppedAssignment(change) }
        try await waitForFixture("assignment-started"); let pid = try fixturePID()
        saving.cancel()
        do { _ = try await saving.value; XCTFail("Cancelled helper accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        XCTAssertEqual(kill(pid, 0), 0)
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        do { _ = try await backend.readStoppedAssignment(context: context, projectID: change.projectId, operationID: change.operationId); XCTFail("Running helper reconciled") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        try setMode("valid"); _ = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        do { _ = try await backend.saveStoppedAssignment(AssignmentFixtures.change(context: context)); XCTFail("Second helper accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        try releaseFixture("release-assignment"); try await waitForExit(pid)
        _ = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        let state = try await backend.readStoppedAssignment(context: context, projectID: change.projectId, operationID: change.operationId)
        XCTAssertEqual(state.savedRevision, AssignmentFixtures.candidate)
        XCTAssertFalse(backend.assignmentRequiresReconciliation)
        let request = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: resources.appendingPathComponent("src/assignment-request"))) as? [String: Any])
        XCTAssertEqual(request["action"] as? String, "assignment_commit")
        XCTAssertTrue(request["accountId"] is NSNull)
        XCTAssertNil(request["expectedRunningRevision"])
    }

    func testAssignmentUncertaintyPreservesDirectRecoveryAndRequiresExactExitedChild() async throws {
        try setMode("assignmentLoss")
        let child = try await startFixture(), change = AssignmentFixtures.change(context: child.context)
        do { _ = try await backend.applyAssignment(change, to: child); XCTFail("Lost acknowledgment accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        XCTAssertTrue(child.process.isRunning); XCTAssertTrue(backend.assignmentRequiresReconciliation)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        _ = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        let recovered = try await backend.control(action: .rollback, configPath: config, expectedContext: child.context)
        XCTAssertEqual(recovered.state, "direct"); XCTAssertTrue(backend.assignmentRequiresReconciliation)
        do { _ = try await backend.readStoppedAssignment(context: child.context, projectID: change.projectId, operationID: change.operationId); XCTFail("Live child masqueraded as stopped") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
        _ = try await backend.stop(child)
        let replacement = try await startFixture()
        do { _ = try await backend.readStoppedAssignment(context: child.context, projectID: change.projectId, operationID: change.operationId); XCTFail("Replacement masqueraded as stopped") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        _ = try await backend.stop(replacement)
        let state = try await backend.readStoppedAssignment(context: child.context, projectID: change.projectId, operationID: change.operationId)
        XCTAssertEqual(state.savedRevision, AssignmentFixtures.candidate); XCTAssertNil(state.runningRevision)
        XCTAssertFalse(backend.assignmentRequiresReconciliation)
    }

    func testAssignmentReadRechecksExactChildAfterAwaitedLoss() async throws {
        try setMode("assignmentReadExit")
        let child = try await startFixture()
        do { _ = try await backend.readAssignment(child, projectID: AssignmentFixtures.project, operationID: nil); XCTFail("Exited child supplied authority") }
        catch { XCTAssertEqual(error as? CompanionError, .unownedChild) }
        XCTAssertFalse(backend.assignmentRequiresReconciliation)
    }

    func testStoppedAssignmentFailuresStaySeparateFromProviderUncertainty() async throws {
        let initial = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(initial.context), change = AssignmentFixtures.change(context: context)
        try setMode("assignmentRejected")
        do { _ = try await backend.saveStoppedAssignment(change); XCTFail("Rejection accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentConflict); XCTAssertFalse(error.localizedDescription.contains("SENTINEL")) }
        XCTAssertFalse(backend.assignmentRequiresReconciliation); XCTAssertFalse(backend.mutationRequiresReconciliation)
        try setMode("assignmentLostReply")
        let next = AssignmentFixtures.change(context: context)
        do { _ = try await backend.saveStoppedAssignment(next); XCTFail("Lost helper response accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain); XCTAssertFalse(error.localizedDescription.contains("SENTINEL")) }
        XCTAssertTrue(backend.assignmentRequiresReconciliation); XCTAssertFalse(backend.mutationRequiresReconciliation)
        try setMode("valid")
        _ = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        let state = try await backend.readStoppedAssignment(context: context, projectID: next.projectId, operationID: next.operationId)
        XCTAssertEqual(state.savedRevision, AssignmentFixtures.candidate)
        XCTAssertFalse(backend.assignmentRequiresReconciliation)
    }

    func testStoppedAssignmentExitOneAcceptsOnlyKnownCertainRejections() async throws {
        let initial = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(initial.context)
        for (mode, expected) in [("assignmentRejected", CompanionError.assignmentConflict), ("assignmentInvalid", .assignmentUnavailable), ("assignmentUnavailable", .assignmentUnavailable)] {
            try setMode(mode)
            let before = try String(contentsOf: resources.appendingPathComponent("src/invocations")).split(separator: "\n").count
            do { _ = try await backend.saveStoppedAssignment(AssignmentFixtures.change(context: context)); XCTFail("Rejection accepted: \(mode)") }
            catch { XCTAssertEqual(error as? CompanionError, expected); XCTAssertFalse(error.localizedDescription.contains("SENTINEL")) }
            XCTAssertFalse(backend.assignmentRequiresReconciliation, mode)
            XCTAssertNil(backend.uncertainAssignmentOperationID, mode)
            XCTAssertFalse(backend.assignmentHelperIsRunning, mode)
            XCTAssertFalse(backend.mutationRequiresReconciliation, mode)
            let after = try String(contentsOf: resources.appendingPathComponent("src/invocations")).split(separator: "\n").count
            XCTAssertEqual(after - before, 1, "A rejection must not retry")
            XCTAssertFalse(FileManager.default.fileExists(atPath: resources.appendingPathComponent("src/assignment-record").path))
        }
        try setMode("valid")
        let state = try await backend.readStoppedAssignment(context: context, projectID: AssignmentFixtures.project, operationID: nil)
        XCTAssertNil(state.intent)
        let later = try await backend.saveStoppedAssignment(AssignmentFixtures.change(context: context))
        XCTAssertTrue(later.changed)
    }

    func testAmbiguousStoppedAssignmentExitEvidenceRemainsUncertain() async throws {
        let initial = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(initial.context)
        for suffix in ["Uncertain", "Unknown", "Malformed", "Extra", "ErrorExtra", "Message", "Schema", "OK", "Contradictory", "Success", "Other", "Signal", "Undrained", "Overflow"] {
            let mode = "assignmentExit" + suffix
            try setMode(mode)
            let isolated = ProcessBackend(resourcesURL: resources, nodeExecutable: node)
            let change = AssignmentFixtures.change(context: context)
            let before = try String(contentsOf: resources.appendingPathComponent("src/invocations")).split(separator: "\n").count
            do { _ = try await isolated.saveStoppedAssignment(change); XCTFail("Ambiguous evidence accepted: \(mode)") }
            catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain, mode) }
            XCTAssertTrue(isolated.assignmentRequiresReconciliation, mode)
            XCTAssertEqual(isolated.uncertainAssignmentOperationID, change.operationId, mode)
            if suffix == "Undrained" { XCTAssertTrue(isolated.assignmentHelperIsRunning) }
            do { _ = try await isolated.saveStoppedAssignment(AssignmentFixtures.change(context: context)); XCTFail("Uncertain mutation retried: \(mode)") }
            catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain, mode) }
            let after = try String(contentsOf: resources.appendingPathComponent("src/invocations")).split(separator: "\n").count
            XCTAssertEqual(after - before, 1, mode)
            let deadline = Date().addingTimeInterval(3)
            while isolated.assignmentHelperIsRunning && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
            XCTAssertFalse(isolated.assignmentHelperIsRunning, mode)
            XCTAssertFalse(isolated.mutationRequiresReconciliation, mode)
        }
    }

    func testProductionCLIStaleSourceRejectsWithoutIntentOrBackendLockout() async throws {
        let canonicalPath = try XCTUnwrap(Darwin.realpath(root.path, nil))
        defer { free(canonicalPath) }
        let canonicalRoot = URL(fileURLWithPath: String(cString: canonicalPath))
        let directory = canonicalRoot.appendingPathComponent("production router")
        let home = canonicalRoot.appendingPathComponent("production home")
        for path in [directory, home] {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        let config = directory.appendingPathComponent("config.json"), project = AssignmentFixtures.project
        let account = "dddddddd-dddd-4ddd-8ddd-dddddddddddd", port = try unusedPort()
        let reference = ["keychainPath": "/private/synthetic-never-read.keychain-db", "service": "synthetic", "account": "synthetic"]
        let value: [String: Any] = ["schemaVersion": 2, "codexHome": home.path, "providerId": "synthetic", "upstreamBaseUrl": "https://synthetic.invalid/v1", "listenPort": port,
            "projectRoutes": [String: String](), "accountRouting": ["incomingCredential": reference, "defaultAccountId": account,
                "accounts": [account: ["displayName": "Synthetic account", "upstreamBaseUrl": "https://synthetic.invalid/account/v1", "credential": reference]], "routeAccounts": [String: String]()]]
        try JSONSerialization.data(withJSONObject: value).write(to: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        try JSONSerialization.data(withJSONObject: ["local-projects": [project: ["id": project, "name": "Synthetic project"]]]).write(to: home.appendingPathComponent(".codex-global-state.json"))
        let provider = home.appendingPathComponent("config.toml")
        let providerBytes = Data("""
        model_provider = "synthetic"
        [model_providers.synthetic]
        base_url = "https://synthetic.invalid/v1"
        wire_api = "responses"
        supports_websockets = false
        [model_providers.synthetic.auth]
        command = "/synthetic/auth-must-not-run"
        args = []
        """.utf8)
        try providerBytes.write(to: provider)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: provider.path)
        let environment = ProcessInfo.processInfo.environment
        let candidates = [environment["npm_node_execpath"]].compactMap { $0 } + (environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/node" }
        let node = URL(fileURLWithPath: try XCTUnwrap(candidates.first { FileManager.default.isExecutableFile(atPath: $0) })).resolvingSymlinksInPath()
        var repository = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { repository.deleteLastPathComponent() }
        let production = ProcessBackend(resourcesURL: repository, nodeExecutable: node)
        let context = ActivationContext(configPath: config.path, codexHome: home.path, providerId: "synthetic", listenPort: port)
        let initial = try await production.readStoppedAssignment(context: context, projectID: project, operationID: nil)
        XCTAssertEqual(initial.savedState, "ready")
        let stale = AssignmentChange(configPath: config.path, expectedContext: context, expectedSavedRevision: try XCTUnwrap(initial.savedRevision),
            expectedConfigurationIdentity: try XCTUnwrap(initial.savedIdentity), expectedRunningRevision: nil, expectedCatalogRevision: try XCTUnwrap(initial.catalogRevision),
            operationId: UUID().uuidString, projectId: project, accountId: account)
        var externalBytes = try Data(contentsOf: config); externalBytes.append(0x0a)
        try externalBytes.write(to: config, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)

        // Confirm the actual CLI contract independently of the native classification.
        var request = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stale)) as? [String: Any])
        request.removeValue(forKey: "expectedRunningRevision"); request["schemaVersion"] = 1; request["action"] = "assignment_commit"
        let child = Process(), input = Pipe(), output = Pipe(), errors = Pipe()
        child.executableURL = node; child.arguments = ["--use-system-ca", repository.appendingPathComponent("src/companion-cli.js").path]
        child.environment = ["NODE_USE_SYSTEM_CA": "1"]
        child.standardInput = input; child.standardOutput = output; child.standardError = errors
        try child.run()
        defer { if child.isRunning { kill(child.processIdentifier, SIGKILL) } }
        try input.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: request)); try input.fileHandleForWriting.close()
        let deadline = Date().addingTimeInterval(5)
        while child.isRunning && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(child.isRunning)
        guard !child.isRunning else { return }
        XCTAssertEqual(child.terminationReason, .exit); XCTAssertEqual(child.terminationStatus, 1)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
        XCTAssertEqual(Set(raw.keys), ["schemaVersion", "ok", "error"])
        XCTAssertEqual(raw["schemaVersion"] as? Int, 1); XCTAssertEqual(raw["ok"] as? Bool, false)
        let failure = try XCTUnwrap(raw["error"] as? [String: String])
        XCTAssertEqual(failure, ["code": "ASSIGNMENT_CONFLICT", "message": "Project assignment state changed; no overwrite was performed."])
        XCTAssertTrue(errors.fileHandleForReading.readDataToEndOfFile().isEmpty)

        do { _ = try await production.saveStoppedAssignment(stale); XCTFail("Stale source accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentConflict) }
        XCTAssertFalse(production.assignmentRequiresReconciliation)
        XCTAssertNil(production.uncertainAssignmentOperationID)
        XCTAssertFalse(production.assignmentHelperIsRunning); XCTAssertFalse(production.mutationRequiresReconciliation)
        XCTAssertTrue(try Data(contentsOf: config) == externalBytes)
        XCTAssertTrue(try Data(contentsOf: provider) == providerBytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["config.json"], "A rejected mutation must leave no intent, checkpoint, lock or temp")
        let fresh = try await production.readStoppedAssignment(context: context, projectID: project, operationID: stale.operationId)
        XCTAssertEqual(fresh.savedState, "ready"); XCTAssertNil(fresh.intent); XCTAssertNil(fresh.lastAttempt)
        XCTAssertTrue(fresh.savedRevision != initial.savedRevision); XCTAssertTrue(fresh.savedIdentity != initial.savedIdentity)
        let later = AssignmentChange(configPath: config.path, expectedContext: context, expectedSavedRevision: try XCTUnwrap(fresh.savedRevision),
            expectedConfigurationIdentity: try XCTUnwrap(fresh.savedIdentity), expectedRunningRevision: nil, expectedCatalogRevision: try XCTUnwrap(fresh.catalogRevision),
            operationId: UUID().uuidString, projectId: project, accountId: nil)
        let saved = try await production.saveStoppedAssignment(later)
        XCTAssertFalse(saved.changed); XCTAssertNil(saved.intent)
        XCTAssertTrue(try Data(contentsOf: config) == externalBytes); XCTAssertTrue(try Data(contentsOf: provider) == providerBytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["config.json"])
    }

    func testAssignmentTimeoutNeedsFreshAssignmentRead() async throws {
        try setMode("assignmentTimeout")
        let child = try await startFixture(), change = AssignmentFixtures.change(context: child.context)
        let invocations = try String(contentsOf: resources.appendingPathComponent("src/invocations"))
        let began = Date()
        do { _ = try await backend.applyAssignment(change, to: child); XCTFail("Timed-out mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        XCTAssertLessThan(Date().timeIntervalSince(began), 5.75)
        XCTAssertTrue(child.process.isRunning); XCTAssertFalse(backend.mutationRequiresReconciliation)
        let mode = try await backend.readRoutingMode(child); XCTAssertEqual(mode, .off)
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        do { _ = try await backend.applyAssignment(AssignmentFixtures.change(context: child.context), to: child); XCTFail("Unreconciled assignment retried") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        let state = try await backend.readAssignment(child, projectID: change.projectId, operationID: change.operationId)
        XCTAssertEqual(state.runningRevision, AssignmentFixtures.candidate)
        XCTAssertFalse(backend.assignmentRequiresReconciliation)
        let commands = try String(contentsOf: resources.appendingPathComponent("src/commands")).split(separator: "\n")
        XCTAssertEqual(commands.filter { $0.contains("set_assignment") }.count, 1)
        XCTAssertEqual(try String(contentsOf: resources.appendingPathComponent("src/invocations")), invocations)
        _ = try await backend.stop(child)
    }

    func testMalformedStoppedRejectionCannotClaimNoReplacement() async throws {
        let initial = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(initial.context), change = AssignmentFixtures.change(context: context)
        try setMode("assignmentBooleanSchema")
        do { _ = try await backend.saveStoppedAssignment(change); XCTFail("Malformed rejection accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        XCTAssertTrue(backend.assignmentRequiresReconciliation)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
        try setMode("valid")
        let state = try await backend.readStoppedAssignment(context: context, projectID: change.projectId, operationID: change.operationId)
        XCTAssertEqual(state.savedRevision, AssignmentFixtures.candidate)
        XCTAssertFalse(backend.assignmentRequiresReconciliation)
    }

    private func startFixture() async throws -> OwnedRouter {
        let child = try await backend.start(configPath: config)
        startedChildren.append(child)
        return child
    }
    private func releaseFixture(_ name: String) throws { try Data().write(to: resources.appendingPathComponent("src/\(name)")) }
    private func waitForFixture(_ name: String) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: resources.appendingPathComponent("src/\(name)").path) {
            guard Date() < deadline else { XCTFail("Fixture did not reach \(name)"); throw CompanionError.timedOut }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    private func waitForExit(_ pid: Int32) async throws {
        let deadline = Date().addingTimeInterval(3)
        while kill(pid, 0) == 0 {
            guard Date() < deadline else { XCTFail("Fixture did not exit"); throw CompanionError.timedOut }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        // Allow the backend's independent drain task to observe the already exited child.
        try await Task.sleep(nanoseconds: 60_000_000)
    }
    private func setMode(_ mode: String) throws { try JSONSerialization.data(withJSONObject: ["mode": mode]).write(to: resources.appendingPathComponent("src/behavior.json")) }
    private func fixturePID() throws -> Int32 { try XCTUnwrap(Int32(String(contentsOf: resources.appendingPathComponent("src/pid")))) }
    private func unusedPort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0); defer { close(fd) }
        var addr = sockaddr_in(); addr.sin_family = sa_family_t(AF_INET); addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        XCTAssertEqual(bound, 0)
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &size) } }
        return Int(UInt16(bigEndian: addr.sin_port))
    }
}
