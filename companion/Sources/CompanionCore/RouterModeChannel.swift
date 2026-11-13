import Foundation
import CoreFoundation
import Darwin

// A capability for one retained child's pipes. All protocol state and I/O stay on this queue.
internal final class RouterModeChannel: @unchecked Sendable {
    private enum Operation: Sendable { case ready, read, set(ProjectRoutingMode) }
    private struct Pending {
        let id: UUID
        let operation: Operation
        let continuation: CheckedContinuation<ProjectRoutingMode, Error>
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

    func waitUntilReady() async throws -> ProjectRoutingMode { try await perform(.ready) }
    func readMode() async throws -> ProjectRoutingMode { try await perform(.read) }
    func setMode(_ mode: ProjectRoutingMode) async throws -> ProjectRoutingMode { try await perform(.set(mode)) }
    func close() {
        queue.async { [self] in
            guard !closed else { return }
            closed = true; disable()
            if let reader { reader.cancel(); self.reader = nil }
            else { try? output.close() }
        }
    }
    private func perform(_ operation: Operation) async throws -> ProjectRoutingMode {
        let id = UUID(), cancellation = Cancellation()
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
    private func begin(id: UUID, operation: Operation, continuation: CheckedContinuation<ProjectRoutingMode, Error>, deadline: DispatchTime, cancelled: Bool) {
        guard available, !closed else { continuation.resume(throwing: CompanionError.routingModeUnavailable); return }
        guard pending == nil else { continuation.resume(throwing: CompanionError.routingModeUnavailable); return }
        if case .set = operation, needsReconciliation {
            continuation.resume(throwing: CompanionError.routingModeUncertain); return
        }
        if case .ready = operation, ready { continuation.resume(returning: .off); return }
        if case .ready = operation {} else if !ready {
            continuation.resume(throwing: CompanionError.routingModeUnavailable); return
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
                  let type = value["type"] as? String,
                  let rawMode = value["mode"] as? String, let mode = ProjectRoutingMode(rawValue: rawMode) else { disable(); return }
            if type == "ready" {
                guard !ready, Set(value.keys) == ["schemaVersion", "type", "sessionId", "context", "mode"], mode == .off,
                      validContext(value["context"]) else { disable(); return }
                ready = true
                if let pending, case .ready = pending.operation {
                    guard DispatchTime.now() < pending.deadline else { retire(id: pending.id); return }
                    complete(.success(.off))
                }
            } else if type == "mode" {
                guard ready, Set(value.keys) == ["schemaVersion", "type", "sessionId", "requestId", "mode"],
                      let requestID = value["requestId"] as? String, UUID(uuidString: requestID) != nil else { disable(); return }
                // Fresh request IDs make retired/unsolicited replies inert without an unbounded history set.
                guard let pending, requestID == pending.id.uuidString else { continue }
                guard DispatchTime.now() < pending.deadline else { retire(id: pending.id); continue }
                if case .ready = pending.operation { disable(); return }
                if case .set(let expected) = pending.operation, expected != mode { disable(); return }
                guard outgoing.isEmpty else { disable(); return }
                if case .read = pending.operation { needsReconciliation = false }
                complete(.success(mode))
            } else { disable(); return }
        }
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
        if case .set = pending.operation { needsReconciliation = true }
        complete(.failure(isSet(pending.operation) ? CompanionError.routingModeUncertain : CompanionError.routingModeUnavailable))
    }
    private func disable() {
        available = false; buffer.removeAll(keepingCapacity: false)
        writer?.cancel(); writer = nil
        try? input.close()
        if let pending {
            if case .set = pending.operation { needsReconciliation = true }
            complete(.failure(isSet(pending.operation) ? CompanionError.routingModeUncertain : CompanionError.routingModeUnavailable))
        }
    }
    private func isSet(_ operation: Operation) -> Bool { if case .set = operation { return true }; return false }
    private func complete(_ result: Result<ProjectRoutingMode, Error>) {
        guard let pending else { return }
        self.pending = nil
        timer?.cancel(); timer = nil; writer?.cancel(); writer = nil
        outgoing.removeAll(keepingCapacity: false); written = 0
        pending.continuation.resume(with: result)
    }
}
