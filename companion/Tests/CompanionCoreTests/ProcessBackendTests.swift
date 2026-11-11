import XCTest
import Darwin
@testable import CompanionCore

@MainActor final class ProcessBackendTests: XCTestCase {
    private var root: URL!; private var resources: URL!; private var node: URL!; private var config: URL!
    private var backend: ProcessBackend!
    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("companion process \(UUID())")
        resources = root.appendingPathComponent("bundled resources")
        try FileManager.default.createDirectory(at: resources.appendingPathComponent("src"), withIntermediateDirectories: true)
        node = root.appendingPathComponent("selected node")
        try FileManager.default.copyItem(at: Bundle.module.url(forResource: "node-fixture", withExtension: nil, subdirectory: "Fixtures")!, to: node)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: node.path)
        for name in ["companion-cli.js", "cli.js"] { try Data().write(to: resources.appendingPathComponent("src/\(name)")) }
        try setMode("valid")
        config = root.appendingPathComponent("selected config.json")
        let port = try unusedPort()
        try JSONSerialization.data(withJSONObject: ["port": port, "home": root.appendingPathComponent("synthetic home").path]).write(to: config)
        backend = ProcessBackend(resourcesURL: resources, nodeExecutable: node)
    }
    override func tearDown() async throws {
        // Kill only this test's retained fixture PID if an assertion interrupted lifecycle cleanup.
        if let data = try? String(contentsOf: resources.appendingPathComponent("src/pid")), let pid = Int32(data), kill(pid, 0) == 0 { kill(pid, SIGKILL) }
        try FileManager.default.removeItem(at: root)
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
        let child = try await backend.start(configPath: config)
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
        let child = try await backend.start(configPath: config)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(child.process.isRunning)
        _ = try await backend.stop(child)
        XCTAssertEqual(exits.count, 1); XCTAssertEqual(exits.first?.0, child.id)
    }
    func testFailedMutationRequiresReconciliation() async throws {
        // Nonzero exit can follow a provider write; plausible stdout must not authorize another write.
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(inspection.context)
        try setMode("exitFailure")
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
        let child = try await backend.start(configPath: config)
        XCTAssertTrue(child.process.isRunning)
        let inspection = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertEqual(inspection.provider.proxyReady, false)
        _ = try await backend.stop(child)
        try setMode("childExit")
        do { _ = try await backend.start(configPath: config); XCTFail("Exited router accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .startupFailed) }
    }
    func testPortReuseIsReportedWithoutAdoptingTheListener() async throws {
        // Child termination and an empty port are separate facts; a replacement listener remains external.
        try setMode("reusePort")
        let child = try await backend.start(configPath: config)
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
        try setMode("heldMutation")
        defer { try? releaseFixture("release-mutation"); try? releaseFixture("release-snapshot") }
        let mutation = Task { try await backend.control(action: .activate, configPath: config, expectedContext: context) }
        try await waitForFixture("mutation-started")
        let mutationPID = try fixturePID()
        mutation.cancel()
        do { _ = try await mutation.value; XCTFail("Cancelled mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        try setMode("delayedInspection")
        let stale = Task { try await backend.inspect(configPath: config, browseHome: root) }
        try await waitForFixture("snapshot-captured")
        try releaseFixture("release-mutation")
        try await waitForExit(mutationPID)
        try releaseFixture("release-snapshot")
        let snapshot = try await stale.value
        XCTAssertEqual(snapshot.provider.state, "direct")
        XCTAssertEqual(try String(contentsOf: resources.appendingPathComponent("src/provider-state")), "router")
        try setMode("valid")
        do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Pre-exit snapshot authorized a mutation") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationBusy) }
        let fresh = try await backend.inspect(configPath: config, browseHome: root)
        XCTAssertEqual(fresh.provider.state, "router")
        _ = try await backend.control(action: .rollback, configPath: config, expectedContext: context)
    }
    func testInterveningMutationInvalidatesReconciliationInspection() async throws {
        // A reconciliation request for one mutation cannot clear a later mutation's uncertainty.
        let initial = try await backend.inspect(configPath: config, browseHome: root)
        let context = try XCTUnwrap(initial.context)
        try setMode("exitFailure")
        do { _ = try await backend.control(action: .activate, configPath: config, expectedContext: context); XCTFail("Failed mutation accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .mutationUncertain) }
        try setMode("delayedInspection")
        defer { try? releaseFixture("release-snapshot") }
        let stale = Task { try await backend.inspect(configPath: config, browseHome: root) }
        try await waitForFixture("snapshot-captured")
        try setMode("valid")
        _ = try await backend.inspect(configPath: config, browseHome: root)
        try setMode("exitFailure")
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
