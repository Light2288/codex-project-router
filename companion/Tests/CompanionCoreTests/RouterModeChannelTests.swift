import XCTest
import Darwin
@testable import CompanionCore

@MainActor final class RouterModeChannelTests: XCTestCase {
    private let context = ActivationContext(configPath: "/synthetic/config.json", codexHome: "/synthetic/home", providerId: "fixture", listenPort: 43129)

    func testAssignmentRequiresCapabilityAndExactChild() async throws {
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.readyAndWait()
        do { _ = try await peer.channel.applyAssignment(AssignmentFixtures.change()); XCTFail("Missing capability accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
        let reading = Task { try await peer.channel.readMode() }
        let read = try await peer.command(); try await peer.reply(to: read, mode: "off")
        _ = try await reading.value
        XCTAssertEqual(peer.commands.count, 1)
    }

    func testAssignmentTimeoutNeedsFreshAssignmentRead() async throws {
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.assignmentReady()
        let change = AssignmentFixtures.change()
        let saving = Task { try await peer.channel.applyAssignment(change) }
        let command = try await peer.command()
        XCTAssertEqual(command["action"] as? String, "set_assignment")
        XCTAssertTrue(command.keys.contains("accountId")); XCTAssertTrue(command["accountId"] is NSNull)
        do { _ = try await saving.value; XCTFail("Timeout accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        do { _ = try await peer.channel.applyAssignment(AssignmentFixtures.change()); XCTFail("Unreconciled write accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        let reading = Task { try await peer.channel.readAssignment(projectID: change.projectId, operationID: change.operationId) }
        let read = try await peer.command()
        try await peer.assignmentReply(to: read, state: AssignmentFixtures.state(change, applied: true))
        let state = try await reading.value
        XCTAssertEqual(state.savedRevision, AssignmentFixtures.candidate)
        XCTAssertEqual(peer.commands.filter { $0["action"] as? String == "set_assignment" }.count, 1)
        do { _ = try await peer.channel.applyAssignment(change); XCTFail("Immediate operation ID reused") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentConflict) }
        var next = AssignmentFixtures.change()
        next.expectedSavedRevision = AssignmentFixtures.candidate; next.expectedConfigurationIdentity = AssignmentFixtures.candidateIdentity
        next.expectedRunningRevision = AssignmentFixtures.candidate
        let explicitSave = Task { try await peer.channel.applyAssignment(next) }
        let nextCommand = try await peer.command()
        try await peer.assignmentFailure(to: nextCommand, outcome: "rejected", code: "ASSIGNMENT_CONFLICT")
        do { _ = try await explicitSave.value; XCTFail("Conflict accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentConflict) }
    }

    func testModeReadCannotReconcileAssignment() async throws {
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.assignmentReady()
        let change = AssignmentFixtures.change()
        let saving = Task { try await peer.channel.applyAssignment(change) }
        _ = try await peer.command(); saving.cancel()
        do { _ = try await saving.value; XCTFail("Cancellation accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        let reading = Task { try await peer.channel.readMode() }
        let read = try await peer.command(); try await peer.reply(to: read, mode: "off"); _ = try await reading.value
        do { _ = try await peer.channel.applyAssignment(AssignmentFixtures.change()); XCTFail("Mode read settled persistence") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        XCTAssertEqual(peer.commands.count, 2)
    }

    func testQueuedFreshReadIgnoresRetiredMutationReply() async throws {
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.assignmentReady()
        let change = AssignmentFixtures.change()
        let saving = Task { try await peer.channel.applyAssignment(change) }
        let old = try await peer.command(); saving.cancel()
        do { _ = try await saving.value; XCTFail("Cancellation accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        let reading = Task { try await peer.channel.readAssignment(projectID: change.projectId, operationID: change.operationId) }
        let read = try await peer.command()
        try await peer.assignmentResult(to: old, change: change)
        var state = try AssignmentFixtures.state(change, applied: true)
        state["savedState"] = "unavailable"; state["savedRevision"] = NSNull(); state["savedIdentity"] = NSNull()
        state["savedFingerprint"] = NSNull(); state["savedAssignment"] = NSNull(); state["catalogRevision"] = NSNull(); state["intent"] = NSNull()
        try await peer.assignmentReply(to: read, state: state)
        let result = try await reading.value; XCTAssertEqual(result.savedState, "unavailable")
        do { _ = try await peer.channel.applyAssignment(AssignmentFixtures.change()); XCTFail("Late result settled persistence") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
    }

    func testPartialFrameDisablesChannelWithoutSignalling() async throws {
        // A truncated response cannot grant authority and EOF cannot authorize a second write.
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.assignmentReady()
        let saving = Task { try await peer.channel.applyAssignment(AssignmentFixtures.change()) }
        _ = try await peer.command()
        try await peer.write(Data("{\"schemaVersion\":1".utf8)); try peer.routerOutput.close()
        do { _ = try await saving.value; XCTFail("Partial response accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        do { _ = try await peer.channel.readAssignment(projectID: nil, operationID: nil); XCTFail("Broken channel accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
    }

    func testAppliedAssignmentRequiresMatchingChoiceAndRuntimeAttestation() async throws {
        // A plausible commit cannot attest another choice or a different runtime snapshot.
        for variant in ["choice", "runtime", "intent", "extra", "nullSummary", "badToken", "missingNull"] {
            let peer = ModePeer(context: context); defer { peer.close() }
            try await peer.assignmentReady()
            let change = AssignmentFixtures.change()
            let saving = Task { try await peer.channel.applyAssignment(change) }
            let command = try await peer.command()
            var commit = try AssignmentFixtures.commit(change), state = try AssignmentFixtures.state(change, applied: true)
            switch variant {
            case "choice": commit["after"] = ["kind": "override", "routeAlias": "synthetic", "account": ["id": AssignmentFixtures.account, "displayName": "Synthetic"]]
            case "runtime": state["runningRevision"] = AssignmentFixtures.token; state["runningIdentity"] = AssignmentFixtures.identity
            case "intent": var intent = AssignmentFixtures.intent(change); intent["accountId"] = AssignmentFixtures.account; commit["intent"] = intent
            case "extra": state["privateSource"] = "synthetic"
            case "nullSummary": var summary = AssignmentFixtures.summary; summary["routeAlias"] = NSNull(); state["savedAssignment"] = summary
            case "badToken": state["savedIdentity"] = "INVALID"
            default: state.removeValue(forKey: "lastAttempt")
            }
            try await peer.assignmentResult(to: command, commit: commit, state: state)
            do { _ = try await saving.value; XCTFail("Unsafe applied attestation accepted: \(variant)") }
            catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
            do { _ = try await peer.channel.readAssignment(projectID: change.projectId, operationID: change.operationId); XCTFail("Malformed channel stayed available: \(variant)") }
            catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
        }
    }

    func testPartialOutboundAssignmentRetiresTheEntireChannel() async throws {
        // Appending a query after a partially delivered JSON command would corrupt the stream.
        let longContext = ActivationContext(configPath: "/" + String(repeating: "a", count: 7000), codexHome: context.codexHome, providerId: context.providerId, listenPort: context.listenPort)
        let peer = ModePeer(context: longContext); defer { peer.close() }
        try await peer.assignmentReady()
        let filled = peer.fillInputPipe(); XCTAssertGreaterThan(filled, 4096)
        XCTAssertEqual(peer.discardInput(maximum: 4096), 4096)
        let saving = Task { try await peer.channel.applyAssignment(AssignmentFixtures.change(context: longContext)) }
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertGreaterThan(peer.channel.retainedOutputByteCount, 4096)
        saving.cancel()
        do { _ = try await saving.value; XCTFail("Partial command accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        XCTAssertGreaterThan(peer.discardInput(), filled - 4096, "No partial command was delivered")
        do { _ = try await peer.channel.readAssignment(projectID: nil, operationID: nil); XCTFail("Query appended after partial command") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
        XCTAssertEqual(peer.channel.retainedOutputByteCount, 0)
    }

    func testUncertainAssignmentResultRequiresMatchingFreshEvidence() async throws {
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.assignmentReady()
        let change = AssignmentFixtures.change()
        let saving = Task { try await peer.channel.applyAssignment(change) }
        let command = try await peer.command()
        try await peer.assignmentFailure(to: command, outcome: "uncertain", code: "ASSIGNMENT_UNCERTAIN")
        do { _ = try await saving.value; XCTFail("Uncertain result accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        let unrelated = Task { try await peer.channel.readAssignment(projectID: change.projectId, operationID: UUID().uuidString) }
        let unrelatedCommand = try await peer.command()
        try await peer.assignmentReply(to: unrelatedCommand, state: AssignmentFixtures.state(change))
        _ = try await unrelated.value
        do { _ = try await peer.channel.applyAssignment(AssignmentFixtures.change()); XCTFail("Unrelated operation reconciled") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        let matching = Task { try await peer.channel.readAssignment(projectID: change.projectId, operationID: change.operationId) }
        let matchingCommand = try await peer.command()
        try await peer.assignmentReply(to: matchingCommand, state: AssignmentFixtures.state(change))
        _ = try await matching.value
        let next = Task { try await peer.channel.applyAssignment(AssignmentFixtures.change()) }
        let nextCommand = try await peer.command()
        try await peer.assignmentFailure(to: nextCommand, outcome: "rejected", code: "ASSIGNMENT_UNAVAILABLE")
        do { _ = try await next.value; XCTFail("Unavailable accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
    }

    func testMalformedRetiredAssignmentReplyDisablesControl() async throws {
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.assignmentReady()
        let change = AssignmentFixtures.change()
        let saving = Task { try await peer.channel.applyAssignment(change) }
        let old = try await peer.command(); saving.cancel()
        do { _ = try await saving.value; XCTFail("Cancellation accepted") } catch { XCTAssertEqual(error as? CompanionError, .assignmentUncertain) }
        let reading = Task { try await peer.channel.readAssignment(projectID: change.projectId, operationID: change.operationId) }
        let read = try await peer.command()
        var malformed = try AssignmentFixtures.commit(change); malformed["extra"] = true
        try await peer.assignmentResult(to: old, commit: malformed, state: AssignmentFixtures.state(change, applied: true))
        try await peer.assignmentReply(to: read, state: AssignmentFixtures.state(change, applied: true))
        do { _ = try await reading.value; XCTFail("Malformed retired frame was ignored") }
        catch { XCTAssertEqual(error as? CompanionError, .assignmentUnavailable) }
    }

    func testExplicitAccountChoiceAndNoOpUseTheirExactOperation() async throws {
        for explicit in [true, false] {
            let peer = ModePeer(context: context); defer { peer.close() }
            try await peer.assignmentReady()
            var change = AssignmentFixtures.change(); change.accountId = explicit ? AssignmentFixtures.account : nil
            let saving = Task { try await peer.channel.applyAssignment(change) }
            let command = try await peer.command()
            XCTAssertEqual(command["requestId"] as? String, change.operationId)
            var commit = try AssignmentFixtures.commit(change), state = try AssignmentFixtures.state(change, applied: explicit)
            if explicit {
                XCTAssertEqual(command["accountId"] as? String, AssignmentFixtures.account)
                let summary: [String: Any] = ["kind": "override", "routeAlias": "explicit", "account": ["id": AssignmentFixtures.account, "displayName": "Synthetic"]]
                commit["after"] = summary; state["savedAssignment"] = summary; state["runningAssignment"] = summary
            } else {
                commit["changed"] = false; commit["checkpointPath"] = NSNull(); commit["intent"] = NSNull()
                for key in ["candidateRevision", "savedRevision", "runningRevision"] { commit[key] = AssignmentFixtures.token }
                for key in ["candidateIdentity", "savedIdentity", "runningIdentity"] { commit[key] = AssignmentFixtures.identity }
            }
            try await peer.assignmentResult(to: command, commit: commit, state: state)
            let applied = try await saving.value
            XCTAssertEqual(applied.changed, explicit); XCTAssertEqual(applied.after.kind, explicit ? "override" : "inherited")
            do { _ = try await peer.channel.applyAssignment(change); XCTFail("Immediate completed operation reused") }
            catch { XCTAssertEqual(error as? CompanionError, .assignmentConflict) }
            XCTAssertEqual(peer.commands.count, 1)
        }
    }

    func testManagedReadyBindsExactChildAndContext() async throws {
        // Accepting another session/context or historical listener readiness would grant authority to the wrong child.
        let peer = ModePeer(context: context); defer { peer.close() }
        let waiting = Task { try await peer.channel.waitUntilReady() }
        try await peer.ready()
        let initial = try await waiting.value
        XCTAssertEqual(initial, .off)
        let setting = Task { try await peer.channel.setMode(.on) }
        let command = try await peer.command()
        XCTAssertEqual(command["action"] as? String, "set_mode")
        XCTAssertEqual(command["mode"] as? String, "on")
        XCTAssertEqual(command["sessionId"] as? String, peer.session.uuidString)
        try await peer.reply(to: command, mode: "on")
        let applied = try await setting.value
        XCTAssertEqual(applied, .on)
    }

    func testLateReplyCannotCompleteReadReconciliation() async throws {
        // Reusing the timed-out set ID, or publishing its late ack, would falsely reconcile the next read.
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.readyAndWait()
        let setting = Task { try await peer.channel.setMode(.on) }
        let old = try await peer.command()
        do { _ = try await setting.value; XCTFail("Set did not time out") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        do { _ = try await peer.channel.setMode(.off); XCTFail("Unreconciled set accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        let reading = Task { try await peer.channel.readMode() }
        let fresh = try await peer.command()
        XCTAssertEqual(fresh["action"] as? String, "get_mode")
        XCTAssertNotEqual(fresh["requestId"] as? String, old["requestId"] as? String)
        try await peer.reply(to: old, mode: "on")
        try await peer.reply(to: fresh, mode: "off")
        let reconciled = try await reading.value
        XCTAssertEqual(reconciled, .off)
        let retry = Task { try await peer.channel.setMode(.on) }
        let retryCommand = try await peer.command()
        try await peer.reply(to: retryCommand, mode: "on")
        let applied = try await retry.value
        XCTAssertEqual(applied, .on)
        XCTAssertEqual(peer.commands.count, 3)
    }

    func testMalformedFloodedAndSplitFramesAreBounded() async throws {
        // Ignoring malformed/overlong frames, retaining flood bytes, or assuming complete reads breaks framing.
        let split = ModePeer(context: context); defer { split.close() }
        let frame = try split.readyFrame()
        let waiting = Task { try await split.channel.waitUntilReady() }
        for byte in frame { try await split.write(Data([byte])) }
        let initial = try await waiting.value
        XCTAssertEqual(initial, .off)
        for payload in [Data("{bad}\n".utf8), Data(repeating: 0x61, count: 65_536), Data([0xff, 0x0a])] {
            let peer = ModePeer(context: context); defer { peer.close() }
            try await peer.readyAndWait()
            try await peer.write(payload)
            try await Task.sleep(nanoseconds: 80_000_000)
            do { _ = try await peer.channel.readMode(); XCTFail("Malformed output granted authority") }
            catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
            XCTAssertLessThanOrEqual(peer.channel.retainedInputByteCount, 32_768)
            XCTAssertEqual(peer.channel.retainedOutputByteCount, 0)
        }
    }

    func testUnsupportedReadyNeverGrantsModeAuthority() async throws {
        // Relaxing schema, context, session, initial Off, or exact-key validation must never grant mode authority.
        let changes: [[String: Any]] = [
            ["schemaVersion": 2], ["schemaVersion": true], ["sessionId": UUID().uuidString],
            ["mode": "on"], ["mode": "unknown"], ["extra": "private"],
            ["capabilities": []], ["capabilities": ["future"]], ["capabilities": ["project_assignments_v1", "project_assignments_v1"]],
            ["context": ["configPath": context.configPath, "codexHome": context.codexHome, "providerId": "wrong", "listenPort": context.listenPort]],
            ["context": ["configPath": context.configPath, "codexHome": context.codexHome, "providerId": context.providerId, "listenPort": context.listenPort, "extra": true]]
        ]
        for change in changes {
            let peer = ModePeer(context: context); defer { peer.close() }
            let waiting = Task { try await peer.channel.waitUntilReady() }
            try await peer.ready(changes: change)
            do { _ = try await waiting.value; XCTFail("Unsupported Ready accepted") }
            catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
            do { _ = try await peer.channel.setMode(.on); XCTFail("Bad Ready authorized set") }
            catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
            XCTAssertTrue(peer.commands.isEmpty)
        }
    }

    func testCancellationRetiresFullyDeliveredMutationAndRequiresRead() async throws {
        // Cancellation may follow delivery; it must not retry a set or accept its late ack as reconciliation.
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.readyAndWait()
        let setting = Task { try await peer.channel.setMode(.on) }
        let command = try await peer.command()
        setting.cancel()
        do { _ = try await setting.value; XCTFail("Cancelled set completed") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        try await peer.reply(to: command, mode: "on")
        do { _ = try await peer.channel.setMode(.off); XCTFail("Late ack reconciled mutation") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        let reading = Task { try await peer.channel.readMode() }
        let read = try await peer.command()
        try await peer.reply(to: read, mode: "on")
        let mode = try await reading.value
        XCTAssertEqual(mode, .on)
        XCTAssertEqual(peer.commands.count, 2)
    }

    func testBackpressureDeadlineKeepsMainActorResponsiveAndDoesNotRetry() async throws {
        // A blocking write would freeze this actor; resetting the deadline on delivery would exceed five seconds.
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.readyAndWait()
        let filled = peer.fillInputPipe()
        XCTAssertGreaterThan(filled, 0)
        let started = Date()
        let setting = Task { try await peer.channel.setMode(.on) }
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        XCTAssertLessThanOrEqual(peer.channel.retainedOutputByteCount, 16_384)
        do { _ = try await setting.value; XCTFail("Backpressured set completed") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        XCTAssertLessThan(Date().timeIntervalSince(started), 5.75)
        XCTAssertEqual(peer.channel.retainedOutputByteCount, 0)
        XCTAssertEqual(peer.discardInput(), filled, "Timed-out mutation was delivered or retried")
        let reading = Task { try await peer.channel.readMode() }
        let read = try await peer.command()
        XCTAssertEqual(read["action"] as? String, "get_mode")
        try await peer.reply(to: read, mode: "off")
        let reconciled = try await reading.value
        XCTAssertEqual(reconciled, .off)
        XCTAssertEqual(peer.commands.count, 1)
    }

    func testConcurrentRequestsDoNotOverwriteThePendingContinuation() async throws {
        // Replacing a pending request would lose its continuation and could reorder a mutation and refresh.
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.readyAndWait()
        let setting = Task { try await peer.channel.setMode(.on) }
        let command = try await peer.command()
        do { _ = try await peer.channel.readMode(); XCTFail("Concurrent query accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
        try await peer.reply(to: command, mode: "on")
        let mode = try await setting.value
        XCTAssertEqual(mode, .on)
        XCTAssertEqual(peer.commands.count, 1)
    }

    func testWrongSessionAndMalformedReplyPermanentlyDisableControl() async throws {
        // A plausible mode with foreign identity or malformed fields must not publish or reconcile state.
        for change: [String: Any] in [["sessionId": UUID().uuidString], ["mode": "unknown"], ["extra": 1], ["requestId": "invalid"]] {
            let peer = ModePeer(context: context); defer { peer.close() }
            try await peer.readyAndWait()
            let setting = Task { try await peer.channel.setMode(.on) }
            let command = try await peer.command()
            try await peer.reply(to: command, mode: "on", changes: change)
            do { _ = try await setting.value; XCTFail("Unsafe reply accepted") }
            catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
            do { _ = try await peer.channel.readMode(); XCTFail("Broken channel reconciled") }
            catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
        }
    }

    func testEOFCloseAndFailedDeliveryCompleteWaiters() async throws {
        // Lost pipes must promptly finish pending continuations without leaking requests.
        let peer = ModePeer(context: context); defer { peer.close() }
        try await peer.readyAndWait()
        let reading = Task { try await peer.channel.readMode() }
        _ = try await peer.command()
        try peer.routerOutput.close()
        do { _ = try await reading.value; XCTFail("EOF accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
        let failed = ModePeer(context: context); defer { failed.close() }
        try await failed.readyAndWait()
        try failed.routerInput.close()
        do { _ = try await failed.channel.setMode(.on); XCTFail("Failed write accepted") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUncertain) }
        do { _ = try await failed.channel.readMode(); XCTFail("Failed delivery reconciled") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
        let closed = ModePeer(context: context); defer { closed.close() }
        let waiting = Task { try await closed.channel.waitUntilReady() }
        closed.channel.close()
        do { _ = try await waiting.value; XCTFail("Closed channel became ready") }
        catch { XCTAssertEqual(error as? CompanionError, .routingModeUnavailable) }
    }
}

@MainActor private final class ModePeer {
    let session = UUID()
    let channel: RouterModeChannel
    let routerInput: FileHandle
    private let inputWriter: FileHandle
    let routerOutput: FileHandle
    let context: ActivationContext
    var commands: [[String: Any]] = []
    private var inputBytes = Data()
    init(context: ActivationContext) {
        self.context = context
        let input = Pipe(), output = Pipe()
        routerInput = input.fileHandleForReading; routerOutput = output.fileHandleForWriting
        inputWriter = input.fileHandleForWriting
        _ = fcntl(routerInput.fileDescriptor, F_SETFL, O_NONBLOCK)
        _ = fcntl(routerOutput.fileDescriptor, F_SETNOSIGPIPE, 1)
        channel = RouterModeChannel(input: input.fileHandleForWriting, output: output.fileHandleForReading, sessionID: session, context: context)
    }
    func assignmentReady() async throws {
        let waiting = Task { try await channel.waitUntilReady() }
        try await ready(changes: ["capabilities": ["project_assignments_v1"]]); _ = try await waiting.value
    }
    func assignmentReply(to command: [String: Any], state: [String: Any]) async throws {
        var bytes = try AssignmentFixtures.data(["schemaVersion": 1, "type": "assignment_state", "sessionId": session.uuidString,
            "requestId": command["requestId"]!, "state": state]); bytes.append(0x0a); try await write(bytes)
    }
    func assignmentFailure(to command: [String: Any], outcome: String, code: String) async throws {
        var bytes = try AssignmentFixtures.data(["schemaVersion": 1, "type": "assignment_result", "sessionId": session.uuidString,
            "requestId": command["requestId"]!, "outcome": outcome, "code": code, "commit": NSNull(), "state": NSNull()])
        bytes.append(0x0a); try await write(bytes)
    }
    func assignmentResult(to command: [String: Any], commit: [String: Any], state: [String: Any]) async throws {
        var bytes = try AssignmentFixtures.data(["schemaVersion": 1, "type": "assignment_result", "sessionId": session.uuidString,
            "requestId": command["requestId"]!, "outcome": "applied", "code": NSNull(), "commit": commit, "state": state])
        bytes.append(0x0a); try await write(bytes)
    }
    func assignmentResult(to command: [String: Any], change: AssignmentChange) async throws {
        var bytes = try AssignmentFixtures.data(["schemaVersion": 1, "type": "assignment_result", "sessionId": session.uuidString,
            "requestId": command["requestId"]!, "outcome": "applied", "code": NSNull(),
            "commit": AssignmentFixtures.commit(change), "state": AssignmentFixtures.state(change, applied: true)])
        bytes.append(0x0a); try await write(bytes)
    }
    func readyFrame(changes: [String: Any] = [:]) throws -> Data {
        var frame: [String: Any] = ["schemaVersion": 1, "type": "ready", "sessionId": session.uuidString,
            "context": ["configPath": context.configPath, "codexHome": context.codexHome, "providerId": context.providerId, "listenPort": context.listenPort], "mode": "off"]
        frame.merge(changes) { _, new in new }
        var bytes = try JSONSerialization.data(withJSONObject: frame); bytes.append(0x0a); return bytes
    }
    func ready(changes: [String: Any] = [:]) async throws { try await write(readyFrame(changes: changes)) }
    func readyAndWait() async throws {
        let waiting = Task { try await channel.waitUntilReady() }
        try await ready()
        let mode = try await waiting.value
        XCTAssertEqual(mode, .off)
    }
    func reply(to command: [String: Any], mode: String, changes: [String: Any] = [:]) async throws {
        var frame: [String: Any] = ["schemaVersion": 1, "type": "mode", "sessionId": session.uuidString, "requestId": command["requestId"]!, "mode": mode]
        frame.merge(changes) { _, new in new }
        var bytes = try JSONSerialization.data(withJSONObject: frame); bytes.append(0x0a)
        try await write(bytes)
    }
    func write(_ bytes: Data) async throws {
        let handle = routerOutput
        try await Task.detached { try handle.write(contentsOf: bytes) }.value
    }
    func command() async throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let newline = inputBytes.firstIndex(of: 0x0a) {
                let frame = inputBytes.prefix(upTo: newline); inputBytes.removeSubrange(...newline)
                let command = try XCTUnwrap(JSONSerialization.jsonObject(with: frame) as? [String: Any])
                commands.append(command); return command
            }
            var bytes = [UInt8](repeating: 0, count: 4096)
            let count = Darwin.read(routerInput.fileDescriptor, &bytes, bytes.count)
            if count > 0 { inputBytes.append(contentsOf: bytes.prefix(count)) }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTFail("No channel command received"); throw CompanionError.timedOut
    }
    func fillInputPipe() -> Int {
        var count = 0
        let bytes = [UInt8](repeating: 0x61, count: 4096)
        while true {
            let wrote = Darwin.write(inputWriter.fileDescriptor, bytes, bytes.count)
            if wrote <= 0 { return count }
            count += wrote
        }
    }
    func discardInput(maximum: Int = Int.max) -> Int {
        var total = 0, bytes = [UInt8](repeating: 0, count: 4096)
        while total < maximum {
            let count = Darwin.read(routerInput.fileDescriptor, &bytes, min(bytes.count, maximum - total))
            if count <= 0 { return total }
            total += count
        }
        return total
    }
    func close() { channel.close(); try? routerInput.close(); try? routerOutput.close() }
}
