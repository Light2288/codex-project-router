import Foundation
import CoreFoundation
import Darwin

// A capability for one retained child's pipes. All protocol state and I/O stay on this queue.
internal final class RouterModeChannel: @unchecked Sendable {
    private enum Operation: Sendable {
        case ready, read, set(ProjectRoutingMode)
        case readAssignment(String?, String?), setAssignment(AssignmentChange)
        var isAssignment: Bool {
            switch self { case .readAssignment, .setAssignment: return true; default: return false }
        }
        var isMutation: Bool {
            switch self { case .set, .setAssignment: return true; default: return false }
        }
    }
    private enum Value { case mode(ProjectRoutingMode), state(AssignmentState), commit(AssignmentCommit) }
    private struct Pending {
        let id: UUID
        let operation: Operation
        let continuation: CheckedContinuation<Value, Error>
        let deadline: DispatchTime
    }
    private final class Cancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        func cancel() { lock.lock(); cancelled = true; lock.unlock() }
        var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    }
    private let queue = DispatchQueue(label: "companion.router-mode")
    private let input: FileHandle
    private let output: FileHandle
    private let session: String
    private let context: ActivationContext
    private var reader: DispatchSourceRead?
    private var writer: DispatchSourceWrite?
    private var timer: DispatchSourceTimer?
    private var buffer = Data()
    private var outgoing = Data()
    private var written = 0
    private var pending: Pending?
    private var assignmentCapable = false
    private var uncertainAssignment: AssignmentChange?
    private var lastAssignmentID: String?
    private var ready = false
    private var available = true
    private var closed = false
    private var needsReconciliation = false
    private let frameLimit = 16 * 1024
    private let retainedLimit = 32 * 1024

    init(input: FileHandle, output: FileHandle, sessionID: UUID, context: ActivationContext) {
        self.input = input; self.output = output; session = sessionID.uuidString; self.context = context
        queue.async { [self] in
            let inFlags = fcntl(input.fileDescriptor, F_GETFL)
            let outFlags = fcntl(output.fileDescriptor, F_GETFL)
            guard inFlags >= 0, outFlags >= 0,
                  fcntl(input.fileDescriptor, F_SETFL, inFlags | O_NONBLOCK) == 0,
                  fcntl(output.fileDescriptor, F_SETFL, outFlags | O_NONBLOCK) == 0,
                  fcntl(input.fileDescriptor, F_SETNOSIGPIPE, 1) == 0 else {
                disable(); return
            }
            let source = DispatchSource.makeReadSource(fileDescriptor: output.fileDescriptor, queue: queue)
            source.setEventHandler { [weak self] in self?.readAvailable() }
            source.setCancelHandler { try? output.close() }
            reader = source; source.resume()
        }
    }
    // Bounds are observable without copying or exposing any protocol payload.
    var retainedInputByteCount: Int { queue.sync { buffer.count } }
    var retainedOutputByteCount: Int { queue.sync { outgoing.count } }

    func waitUntilReady() async throws -> ProjectRoutingMode { try await mode(.ready) }
    func readMode() async throws -> ProjectRoutingMode { try await mode(.read) }
    func setMode(_ mode: ProjectRoutingMode) async throws -> ProjectRoutingMode { try await self.mode(.set(mode)) }
    private func mode(_ operation: Operation) async throws -> ProjectRoutingMode {
        guard case .mode(let value) = try await perform(operation) else { throw CompanionError.routingModeUnavailable }
        return value
    }
    func readAssignment(projectID: String?, operationID: String?) async throws -> AssignmentState {
        guard case .state(let value) = try await perform(.readAssignment(projectID, operationID)) else { throw CompanionError.assignmentUnavailable }
        return value
    }
    func applyAssignment(_ change: AssignmentChange) async throws -> AssignmentCommit {
        guard case .commit(let value) = try await perform(.setAssignment(change)) else { throw CompanionError.assignmentUncertain }
        return value
    }
    func close() {
        queue.async { [self] in
            guard !closed else { return }
            closed = true; disable()
            if let reader { reader.cancel(); self.reader = nil }
            else { try? output.close() }
        }
    }
    private func perform(_ operation: Operation) async throws -> Value {
        let id = UUID()
        let cancellation = Cancellation()
        let deadline = DispatchTime.now() + .seconds(5)
        return try await withTaskCancellationHandler {
            if Task.isCancelled { cancellation.cancel() }
            return try await withCheckedThrowingContinuation { continuation in
                queue.async { [self] in
                    begin(id: id, operation: operation, continuation: continuation, deadline: deadline, cancelled: cancellation.isCancelled)
                }
            }
        } onCancel: {
            cancellation.cancel()
            self.queue.async { [self] in retire(id: id) }
        }
    }
    private func begin(id: UUID, operation: Operation, continuation: CheckedContinuation<Value, Error>, deadline: DispatchTime, cancelled: Bool) {
        let unavailable = operation.isAssignment ? CompanionError.assignmentUnavailable : CompanionError.routingModeUnavailable
        guard available, !closed, pending == nil else { continuation.resume(throwing: unavailable); return }
        if operation.isAssignment, !assignmentCapable { continuation.resume(throwing: unavailable); return }
        switch operation {
        case .setAssignment(let change):
            guard uncertainAssignment == nil else { continuation.resume(throwing: CompanionError.assignmentUncertain); return }
            guard AssignmentWire.change(change, live: true), change.expectedContext == context,
                  lastAssignmentID?.lowercased() != change.operationId.lowercased() else {
                continuation.resume(throwing: CompanionError.assignmentConflict); return
            }
            lastAssignmentID = change.operationId
        case .readAssignment(let projectID, let operationID):
            guard projectID.map(AssignmentWire.uuid) ?? true, operationID.map(AssignmentWire.uuid) ?? true else {
                continuation.resume(throwing: unavailable); return
            }
        default: break
        }
        if case .set = operation, needsReconciliation {
            continuation.resume(throwing: CompanionError.routingModeUncertain); return
        }
        if case .ready = operation, ready { continuation.resume(returning: .mode(.off)); return }
        if case .ready = operation {} else if !ready {
            continuation.resume(throwing: unavailable); return
        }
        pending = Pending(id: id, operation: operation, continuation: continuation, deadline: deadline)
        if cancelled || DispatchTime.now() >= deadline { retire(id: id); return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: deadline)
        source.setEventHandler { [weak self] in self?.retire(id: id) }
        timer = source; source.resume()
        if case .ready = operation { return }
        var frame: [String: Any] = ["schemaVersion": 1, "sessionId": session, "requestId": id.uuidString, "action": "get_mode"]
        if case .set(let mode) = operation { frame["action"] = "set_mode"; frame["mode"] = mode.rawValue }
        if case .readAssignment(let projectID, let operationID) = operation {
            frame["action"] = "get_assignment"
            do { frame["expectedContext"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) }
            catch { disable(); return }
            frame["projectId"] = projectID as Any? ?? NSNull(); frame["operationId"] = operationID as Any? ?? NSNull()
        }
        if case .setAssignment(let change) = operation {
            guard let fields = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(change)) as? [String: Any] else { disable(); return }
            frame.merge(fields) { _, value in value }; frame.removeValue(forKey: "configPath"); frame.removeValue(forKey: "operationId")
            // Preserve the explicit operation's spelling; the child echoes this exact wire identity.
            frame["requestId"] = change.operationId; frame["action"] = "set_assignment"
        }
        do { outgoing = try JSONSerialization.data(withJSONObject: frame); outgoing.append(0x0a) }
        catch { disable(); return }
        guard outgoing.count <= frameLimit else { disable(); return }
        written = 0
        let writer = DispatchSource.makeWriteSource(fileDescriptor: input.fileDescriptor, queue: queue)
        writer.setEventHandler { [weak self] in self?.writeAvailable() }
        self.writer = writer; writer.resume()
    }
    private func writeAvailable() {
        guard available, let pending else { return }
        guard DispatchTime.now() < pending.deadline else { retire(id: pending.id); return }
        // A frame is bounded and every syscall is nonblocking; no FileHandle.write runs on MainActor.
        for _ in 0..<4 {
            let count = outgoing.withUnsafeBytes { bytes in
                Darwin.write(input.fileDescriptor, bytes.baseAddress!.advanced(by: written), min(4096, bytes.count - written))
            }
            if count > 0 {
                written += count
                if written == outgoing.count {
                    writer?.cancel(); writer = nil; outgoing.removeAll(keepingCapacity: false); written = 0
                    return
                }
            } else if count < 0 && errno == EINTR { continue }
            else if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) { return }
            else { disable(); return }
        }
    }
    private func readAvailable() {
        guard !closed else { return }
        var chunk = [UInt8](repeating: 0, count: 4096)
        // Limit work per dispatch event as well as retained memory, including after protocol failure.
        for _ in 0..<8 {
            let count = Darwin.read(output.fileDescriptor, &chunk, chunk.count)
            if count > 0 {
                if available {
                    guard buffer.count + count <= retainedLimit else { disable(); continue }
                    buffer.append(contentsOf: chunk.prefix(count)); consumeFrames()
                }
            } else if count == 0 {
                disable(); reader?.cancel(); reader = nil; return
            } else if errno == EINTR { continue }
            else if errno == EAGAIN || errno == EWOULDBLOCK { return }
            else { disable(); reader?.cancel(); reader = nil; return }
        }
    }
    private func consumeFrames() {
        while available {
            guard let newline = buffer.firstIndex(of: 0x0a) else {
                if buffer.count >= frameLimit { disable() }
                return
            }
            let count = buffer.distance(from: buffer.startIndex, to: newline)
            guard count < frameLimit else { disable(); return }
            let frame = Data(buffer.prefix(count)); buffer.removeFirst(count + 1)
            guard String(data: frame, encoding: .utf8) != nil,
                  let object = try? JSONSerialization.jsonObject(with: frame),
                  let value = object as? [String: Any], exactInteger(value["schemaVersion"]) == 1,
                  value["sessionId"] as? String == session,
                  let type = value["type"] as? String else { disable(); return }
            if type == "assignment_state" || type == "assignment_result" {
                consumeAssignment(value, type: type); continue
            }
            guard let rawMode = value["mode"] as? String, let mode = ProjectRoutingMode(rawValue: rawMode) else { disable(); return }
            if type == "ready" {
                let original: Set<String> = ["schemaVersion", "type", "sessionId", "context", "mode"]
                let keys = Set(value.keys)
                guard !ready, keys == original || keys == original.union(["capabilities"]), mode == .off,
                      validContext(value["context"]) else { disable(); return }
                if keys.contains("capabilities") {
                    guard value["capabilities"] as? [String] == ["project_assignments_v1"] else { disable(); return }
                    assignmentCapable = true
                }
                ready = true
                if let pending, case .ready = pending.operation {
                    guard DispatchTime.now() < pending.deadline else { retire(id: pending.id); return }
                    complete(.success(.mode(.off)))
                }
            } else if type == "mode" {
                guard ready, Set(value.keys) == ["schemaVersion", "type", "sessionId", "requestId", "mode"],
                      let requestID = value["requestId"] as? String, UUID(uuidString: requestID) != nil else { disable(); return }
                // Fresh request IDs make retired/unsolicited replies inert without an unbounded history set.
                guard let pending, requestID == wireRequestID(pending) else { continue }
                guard DispatchTime.now() < pending.deadline else { retire(id: pending.id); continue }
                if case .ready = pending.operation { disable(); return }
                guard !pending.operation.isAssignment else { disable(); return }
                if case .set(let expected) = pending.operation, expected != mode { disable(); return }
                guard outgoing.isEmpty else { disable(); return }
                if case .read = pending.operation { needsReconciliation = false }
                complete(.success(.mode(mode)))
            } else { disable(); return }
        }
    }
    private func consumeAssignment(_ value: [String: Any], type: String) {
        let fields: Set<String> = ["schemaVersion", "type", "sessionId", "requestId"]
        guard ready, assignmentCapable,
              Set(value.keys) == fields.union(type == "assignment_state" ? ["state"] : ["outcome", "code", "commit", "state"]),
              let requestID = value["requestId"] as? String, UUID(uuidString: requestID) != nil else { disable(); return }
        if type == "assignment_result" {
            guard let outcome = value["outcome"] as? String, ["applied", "rejected", "uncertain"].contains(outcome),
                  outcome == "applied" ? value["code"] is NSNull : (value["code"] as? String).map({ AssignmentWire.codes.contains($0) }) == true,
                  outcome != "uncertain" || value["code"] as? String == "ASSIGNMENT_UNCERTAIN",
                  outcome != "rejected" || value["code"] as? String != "ASSIGNMENT_UNCERTAIN",
                  outcome == "applied" || value["commit"] is NSNull else { disable(); return }
        }
        // Validate complete variants even for retired IDs; only correlation grants authority.
        if let rawState = value["state"] as? [String: Any] {
            let intentID = (rawState["intent"] as? [String: Any])?["operationId"] as? String
            let attemptID = (rawState["lastAttempt"] as? [String: Any])?["operationId"] as? String
            guard AssignmentWire.state(rawState, context: context, projectID: rawState["projectId"] as? String,
                operationID: type == "assignment_result" ? requestID : intentID ?? attemptID, live: true) != nil else { disable(); return }
        } else if type == "assignment_state" || !(value["state"] is NSNull) { disable(); return }
        if type == "assignment_result", value["outcome"] as? String == "applied" {
            guard AssignmentWire.commitShape(value["commit"]!, live: true),
                  let commit = AssignmentWire.decode(AssignmentCommit.self, value["commit"]!),
                  commit.context == context, commit.operationId == requestID,
                  let state = AssignmentWire.decode(AssignmentState.self, value["state"]!), state.projectId == commit.projectId,
                  state.runningRevision == commit.runningRevision, state.runningIdentity == commit.runningIdentity,
                  state.runningFingerprint == commit.runningFingerprint else { disable(); return }
        }
        // A retired mutation's reply cannot complete a newer read or clear uncertainty.
        guard let pending, requestID == wireRequestID(pending) else { return }
        guard outgoing.isEmpty else { disable(); return }
        guard DispatchTime.now() < pending.deadline else { retire(id: pending.id); return }
        switch pending.operation {
        case .readAssignment(let projectID, let operationID):
            if type == "assignment_result" {
                guard value["outcome"] as? String == "rejected", value["state"] is NSNull else { disable(); return }
                complete(.failure(value["code"] as? String == "ASSIGNMENT_CONFLICT" ? CompanionError.assignmentConflict : CompanionError.assignmentUnavailable)); return
            }
            guard let state = AssignmentWire.state(value["state"]!, context: context, projectID: projectID, operationID: operationID, live: true) else { disable(); return }
            if let uncertainAssignment, operationID == uncertainAssignment.operationId,
               AssignmentWire.reconciles(state, change: uncertainAssignment, live: true) { self.uncertainAssignment = nil }
            complete(.success(.state(state)))
        case .setAssignment(let change):
            guard type == "assignment_result" else { disable(); return }
            let state: AssignmentState?
            if value["state"] is NSNull { state = nil }
            else {
                guard let decoded = AssignmentWire.state(value["state"]!, context: context, projectID: change.projectId, operationID: change.operationId, live: true) else { disable(); return }
                state = decoded
            }
            switch value["outcome"] as? String {
            case "applied":
                guard let state, let commit = AssignmentWire.commit(value["commit"]!, change: change, live: true),
                      state.runningRevision == commit.runningRevision, state.runningIdentity == commit.runningIdentity,
                      state.runningFingerprint == commit.runningFingerprint else { disable(); return }
                complete(.success(.commit(commit)))
            case "rejected":
                complete(.failure(value["code"] as? String == "ASSIGNMENT_CONFLICT" ? CompanionError.assignmentConflict : CompanionError.assignmentUnavailable))
            default:
                uncertainAssignment = change; complete(.failure(CompanionError.assignmentUncertain))
            }
        default: disable()
        }
    }
    private func wireRequestID(_ pending: Pending) -> String {
        if case .setAssignment(let change) = pending.operation { return change.operationId }
        return pending.id.uuidString
    }
    private func validContext(_ object: Any?) -> Bool {
        guard let value = object as? [String: Any], Set(value.keys) == ["configPath", "codexHome", "providerId", "listenPort"] else { return false }
        return value["configPath"] as? String == context.configPath && value["codexHome"] as? String == context.codexHome &&
            value["providerId"] as? String == context.providerId && exactInteger(value["listenPort"]) == context.listenPort
    }
    private func exactInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue == Double(number.intValue) else { return nil }
        return number.intValue
    }
    private func retire(id: UUID) {
        guard let pending, pending.id == id else { return }
        if case .ready = pending.operation { disable(); return }
        if !outgoing.isEmpty, written > 0 {
            // Never append a reconciliation query to a partially delivered JSON frame.
            disable(); return
        }
        markUncertain(pending.operation)
        complete(.failure(failure(pending.operation)))
    }
    private func disable() {
        available = false; buffer.removeAll(keepingCapacity: false)
        writer?.cancel(); writer = nil
        try? input.close()
        if let pending {
            markUncertain(pending.operation)
            complete(.failure(failure(pending.operation)))
        }
    }
    private func markUncertain(_ operation: Operation) {
        if case .set = operation { needsReconciliation = true }
        if case .setAssignment(let change) = operation { uncertainAssignment = change }
    }
    private func failure(_ operation: Operation) -> CompanionError {
        if operation.isAssignment { return operation.isMutation ? .assignmentUncertain : .assignmentUnavailable }
        return operation.isMutation ? .routingModeUncertain : .routingModeUnavailable
    }
    private func complete(_ result: Result<Value, Error>) {
        guard let pending else { return }
        self.pending = nil
        timer?.cancel(); timer = nil; writer?.cancel(); writer = nil
        outgoing.removeAll(keepingCapacity: false); written = 0
        pending.continuation.resume(with: result)
    }
}
