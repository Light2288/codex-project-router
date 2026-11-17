import Foundation
import Network
import Darwin

// Pipe readers keep bounded data while continuing to drain the child's pipes.
private final class BoundedCapture {
    private let lock = NSLock()
    private let limit: Int
    private var bytes = Data()
    private var exceeded = false
    private var ended = false
    init(limit: Int) { self.limit = limit }
    func attach(_ handle: FileHandle) {
        handle.readabilityHandler = { [self] handle in
            let chunk = handle.availableData
            lock.lock()
            if chunk.isEmpty { ended = true }
            else {
                if bytes.count + chunk.count > limit { exceeded = true }
                bytes.append(chunk.prefix(max(0, limit - bytes.count)))
            }
            lock.unlock()
            if chunk.isEmpty { handle.readabilityHandler = nil; try? handle.close() }
        }
    }
    var snapshot: (data: Data, overflow: Bool, eof: Bool) {
        lock.lock(); defer { lock.unlock() }; return (bytes, exceeded, ended)
    }
    func discard() { lock.lock(); bytes.removeAll(keepingCapacity: false); lock.unlock() }
}
// The child can delay reading beyond the deadline. Keep delivery nonblocking and retained
// through uncertainty; completion includes both full delivery and the final stdin close.
private final class CommandInput {
    private let queue = DispatchQueue(label: "companion.command-input")
    private let lock = NSLock()
    private let handle: FileHandle
    private var bytes: Data
    private var offset = 0
    private var writer: DispatchSourceWrite?
    private var closing = false
    private var ended = false, failed = false
    init(handle: FileHandle, bytes: Data) { self.handle = handle; self.bytes = bytes }
    var snapshot: (ended: Bool, failed: Bool) {
        lock.lock(); defer { lock.unlock() }; return (ended, failed)
    }
    func start() {
        queue.async { [self] in
            let flags = fcntl(handle.fileDescriptor, F_GETFL)
            guard flags >= 0, fcntl(handle.fileDescriptor, F_SETFL, flags | O_NONBLOCK) == 0,
                  fcntl(handle.fileDescriptor, F_SETNOSIGPIPE, 1) == 0 else { finish(failed: true); return }
            guard !bytes.isEmpty else { finish(failed: false); return }
            let source = DispatchSource.makeWriteSource(fileDescriptor: handle.fileDescriptor, queue: queue)
            source.setEventHandler { [weak self] in self?.writeAvailable() }
            writer = source; source.resume()
        }
    }
    private func writeAvailable() {
        guard !closing else { return }
        // Bound work per event as well as retained input; every write is nonblocking.
        for _ in 0..<4 {
            let count = bytes.withUnsafeBytes { buffer in
                Darwin.write(handle.fileDescriptor, buffer.baseAddress!.advanced(by: offset), min(4096, buffer.count - offset))
            }
            if count > 0 {
                offset += count
                if offset == bytes.count { finish(failed: false); return }
            } else if count < 0 && errno == EINTR { continue }
            else if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) { return }
            else { finish(failed: true); return }
        }
    }
    private func finish(failed: Bool) {
        guard !closing else { return }
        closing = true; bytes.removeAll(keepingCapacity: false)
        if let writer {
            writer.setCancelHandler { [self] in closeInput(failed: failed) }
            writer.cancel(); self.writer = nil
        } else { closeInput(failed: failed) }
    }
    private func closeInput(failed: Bool) {
        var failed = failed
        do { try handle.close() } catch { failed = true }
        lock.lock(); self.failed = failed; ended = true; lock.unlock()
    }
}
private final class RunningCommand {
    let process: Process
    private let input: CommandInput
    var inputFailed: Bool { input.snapshot.failed }
    let stdout = BoundedCapture(limit: 1024 * 1024)
    let stderr = BoundedCapture(limit: 16 * 1024)
    init(process: Process, input: FileHandle, bytes: Data?) {
        self.process = process; self.input = CommandInput(handle: input, bytes: bytes ?? Data())
    }
    func startInput() { input.start() }
    var drained: Bool { input.snapshot.ended && stdout.snapshot.eof && stderr.snapshot.eof }
    var overflow: Bool { stdout.snapshot.overflow || stderr.snapshot.overflow }
    func discard() { stdout.discard(); stderr.discard() }
}

@MainActor public final class ProcessBackend: CompanionBackend, AccountSetupBackend, ProjectAssignmentBackend {
    public var mutationRequiresReconciliation: Bool { mutationInFlight || needsReconciliation }
    public private(set) var uncertainSetupOperationID: String?
    public var setupHelperIsRunning: Bool { uncertainSetupOperationID != nil && mutationInFlight }
    public var assignmentRequiresReconciliation: Bool { uncertainAssignment != nil }
    public var uncertainAssignmentOperationID: String? { uncertainAssignment?.change.operationId }
    public var assignmentHelperIsRunning: Bool { uncertainAssignment?.childID == nil && uncertainAssignment != nil && mutationInFlight }
    private var uncertainAssignment: (change: AssignmentChange, childID: UUID?)?
    private var assignmentInFlight = false
    public var onChildExit: ((UUID, Int32) -> Void)?
    private let resourcesURL: URL
    private var nodeExecutable: URL?
    private let discoveryCandidates: [URL]?
    private var owned: [UUID: (child: OwnedRouter, channel: RouterModeChannel, stderr: BoundedCapture)] = [:]
    private var mutationInFlight = false
    private var mutationProcess: RunningCommand?
    private var needsReconciliation = false
    private var uncertainContext: ActivationContext?
    private var mutationGeneration = UUID()

    public init(resourcesURL: URL, nodeExecutable: URL?) {
        self.resourcesURL = resourcesURL; self.nodeExecutable = nodeExecutable
        self.discoveryCandidates = nil
    }
    internal init(resourcesURL: URL, nodeExecutable: URL?, discoveryCandidates: [URL]) {
        self.resourcesURL = resourcesURL; self.nodeExecutable = nodeExecutable
        self.discoveryCandidates = discoveryCandidates
    }
    public func setNodeExecutable(_ validatedPath: URL) { nodeExecutable = validatedPath }

    public func validateNode(_ path: URL) async throws -> URL {
        try await validateNode(path, deadline: Date().addingTimeInterval(5))
    }
    private func validateNode(_ path: URL, deadline: Date) async throws -> URL {
        try requireTime(before: deadline)
        guard path.isFileURL, path.path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path.path) else { throw CompanionError.nodeUnavailable }
        let canonical = path.resolvingSymlinksInPath()
        do {
            let command = try launch(executable: canonical, arguments: ["--version"])
            let bytes = try await wait(command, mutating: false, deadline: deadline)
            try requireTime(before: deadline)
            guard bytes.count <= 128, let text = String(data: bytes, encoding: .utf8),
                  text.range(of: "^v24\\.[0-9]+\\.[0-9]+\\n?$", options: .regularExpression) != nil else { throw CompanionError.nodeUnavailable }
            return canonical
        } catch CompanionError.timedOut { throw CompanionError.timedOut }
        catch { throw CompanionError.nodeUnavailable }
    }
    private func runtime(deadline: Date) async throws -> URL {
        try requireTime(before: deadline)
        if let nodeExecutable {
            do { return try await validateNode(nodeExecutable, deadline: deadline) }
            catch CompanionError.nodeUnavailable { /* Continue discovery after a stale saved path. */ }
        }
        var candidates: [URL]
        if let discoveryCandidates { candidates = discoveryCandidates }
        else {
            candidates = ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"].map { URL(fileURLWithPath: $0) }
            let versions = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".nvm/versions/node")
            if let directories = try? FileManager.default.contentsOfDirectory(at: versions, includingPropertiesForKeys: nil) {
                candidates += directories.filter { $0.lastPathComponent.hasPrefix("v24.") }
                    .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
                    .map { $0.appendingPathComponent("bin/node") }
            }
        }
        for candidate in candidates {
            try requireTime(before: deadline)
            do {
                let validated = try await validateNode(candidate, deadline: deadline)
                nodeExecutable = validated
                return validated
            } catch CompanionError.nodeUnavailable { continue }
        }
        try requireTime(before: deadline)
        throw CompanionError.nodeUnavailable
    }
    private func requireTime(before deadline: Date) throws {
        guard !Task.isCancelled, Date() < deadline else { throw CompanionError.timedOut }
    }
    public func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection {
        try await inspect(configPath: configPath, browseHome: browseHome, deadline: Date().addingTimeInterval(5))
    }
    private func inspect(configPath: URL?, browseHome: URL, deadline: Date) async throws -> Inspection {
        // Only a request begun after the uncertain child exits can reconcile that generation.
        let reconciliationGeneration = needsReconciliation && !mutationInFlight && uncertainSetupOperationID == nil ? mutationGeneration : nil
        var request: [String: Any] = ["schemaVersion": 1, "action": "inspect", "configPath": configPath?.path as Any? ?? NSNull()]
        request["browseHome"] = browseHome.path
        let result: Inspection = try await requestResult(request, mutating: false, deadline: deadline)
        guard valid(result) else { throw CompanionError.protocolFailure }
        if let reconciliationGeneration, reconciliationGeneration == mutationGeneration,
           needsReconciliation, !mutationInFlight, let context = uncertainContext, result.context == context,
           ["direct", "router"].contains(result.provider.state), result.provider.recordPhase != "unavailable" {
            needsReconciliation = false; uncertainContext = nil
        }
        return result
    }
    public func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult {
        guard !mutationInFlight, !needsReconciliation, !assignmentInFlight,
              action == .rollback || uncertainAssignment == nil else { throw CompanionError.mutationBusy }
        if action == .activate {
            let inspection = try await inspect(configPath: configPath, browseHome: URL(fileURLWithPath: expectedContext.codexHome))
            guard inspection.context == expectedContext, inspection.configuration.setupState == "ready" else { throw CompanionError.mutationBusy }
        }
        guard !mutationInFlight, !needsReconciliation, !assignmentInFlight,
              action == .rollback || uncertainAssignment == nil else { throw CompanionError.mutationBusy }
        mutationInFlight = true
        mutationGeneration = UUID()
        defer { if mutationProcess == nil { mutationInFlight = false } }
        uncertainContext = expectedContext
        do {
            let context = try JSONSerialization.jsonObject(with: JSONEncoder().encode(expectedContext))
            let result: ControlResult = try await requestResult(["schemaVersion": 1, "action": action.rawValue,
                "configPath": configPath.path, "expectedContext": context], mutating: true)
            guard ["active", "direct"].contains(result.state), result.state == (action == .activate ? "active" : "direct") else {
                needsReconciliation = true; throw CompanionError.mutationUncertain
            }
            uncertainContext = nil
            return result
        } catch {
            if needsReconciliation { throw CompanionError.mutationUncertain }
            uncertainContext = nil
            throw error
        }
    }
    public func previewSetup(configPath: URL, browseHome: URL) async throws -> SetupPreview {
        let result: SetupPreview = try await requestResult(["schemaVersion": 1, "action": "setup_preview", "configPath": configPath.path, "browseHome": browseHome.path], mutating: false)
        guard valid(result), result.context.configPath == configPath.path else { throw CompanionError.protocolFailure }
        return result
    }
    public func commitSetup(_ change: SetupChange, context: ActivationContext, revision: String, operationID: String) async throws -> SetupCommitResult {
        guard !mutationInFlight, !needsReconciliation, !assignmentInFlight, uncertainAssignment == nil else { throw CompanionError.mutationBusy }
        guard UUID(uuidString: operationID) != nil, validRevision(revision) else { throw CompanionError.protocolFailure }
        let encodedContext = try JSONSerialization.jsonObject(with: JSONEncoder().encode(context))
        let encodedChange = try JSONSerialization.jsonObject(with: JSONEncoder().encode(change))
        mutationInFlight = true; mutationGeneration = UUID(); uncertainSetupOperationID = operationID
        defer { if mutationProcess == nil { mutationInFlight = false } }
        do {
            let result: SetupCommitResult = try await requestResult(["schemaVersion": 1, "action": "setup_commit", "configPath": context.configPath,
                "expectedContext": encodedContext, "expectedRevision": revision, "operationId": operationID, "change": encodedChange], mutating: true)
            guard result.context == context, result.operationId == operationID, ["ready", "required"].contains(result.setupState),
                  validRevision(result.configurationRevision), result.changed,
                  result.checkpointPath == nil || result.checkpointPath!.hasPrefix("/") else { needsReconciliation = true; throw CompanionError.mutationUncertain }
            uncertainSetupOperationID = nil
            return result
        } catch {
            if needsReconciliation { throw CompanionError.mutationUncertain }
            uncertainSetupOperationID = nil; throw error
        }
    }
    public func probeSetupPort(_ context: ActivationContext) async -> StopOutcome.PortState { await probe(port: context.listenPort) }
    public func finishSetupReconciliation(operationID: String) throws {
        guard uncertainSetupOperationID == operationID, !mutationInFlight, mutationProcess == nil, needsReconciliation else { throw CompanionError.mutationBusy }
        uncertainSetupOperationID = nil; needsReconciliation = false
    }
    private func validRevision(_ value: String) -> Bool { value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil }
    private func valid(_ value: SetupPreview) -> Bool {
        func account(_ a: SetupPreview.Account) -> Bool {
            UUID(uuidString: a.id) != nil && !a.displayName.isEmpty && a.displayName.unicodeScalars.count <= 80 &&
                a.displayName == a.displayName.trimmingCharacters(in: .whitespacesAndNewlines) &&
                !a.displayName.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } &&
                (try? AccountRecord.normalizedUpstreamBaseURL(a.upstreamBaseUrl)) == a.upstreamBaseUrl &&
                (a.credential == nil || a.credential!.isValid)
        }
        return validContext(value.context) && validRevision(value.configurationRevision) &&
            ["ready", "required", "migration_required"].contains(value.setupState) && ["missing", "legacy", "enabled", "accounts"].contains(value.sourceKind) &&
            value.accounts.allSatisfy(account) && account(value.originalDirect) && Set(value.accounts.map(\.id)).count == value.accounts.count &&
            (value.incomingCredential == nil || value.incomingCredential!.isValid) &&
            (value.defaultAccountId == nil || value.accounts.contains { $0.id == value.defaultAccountId }) &&
            value.routeAccounts.values.allSatisfy { $0 == nil || UUID(uuidString: $0!) != nil } &&
            (value.incomingHint == nil || (!value.incomingHint!.service.isEmpty && !value.incomingHint!.account.isEmpty &&
                (value.incomingHint!.keychainPath == nil || value.incomingHint!.keychainPath!.hasPrefix("/"))))
    }
    private func validContext(_ context: ActivationContext) -> Bool {
        [context.configPath, context.codexHome].allSatisfy { $0.hasPrefix("/") && !$0.contains("\0") } && (1...65535).contains(context.listenPort) &&
            context.providerId.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }
    private func resource(_ name: String) throws -> URL {
        let path = resourcesURL.appendingPathComponent("src/\(name)")
        var isDirectory: ObjCBool = false
        guard resourcesURL.isFileURL, FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory),
              !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: path.path) else { throw CompanionError.resourcesUnavailable }
        return path
    }
    private func requestResult<Result: Codable>(_ request: [String: Any], mutating: Bool, deadline: Date? = nil, assignment: Bool = false, validateAssignment: ((Any) -> Bool)? = nil) async throws -> Result {
        let deadline = deadline ?? Date().addingTimeInterval(5)
        let script = try resource("companion-cli.js")
        let executable = try await runtime(deadline: deadline)
        let input: Data
        do { input = try JSONSerialization.data(withJSONObject: request) } catch { throw CompanionError.protocolFailure }
        let inputLimit = (request["action"] as? String)?.hasPrefix("setup_") == true ? 1024 * 1024 : 16 * 1024
        guard input.count <= inputLimit else { throw CompanionError.protocolFailure }
        try requireTime(before: deadline)
        let command = try launch(executable: executable, arguments: ["--use-system-ca", script.path], input: input)
        if mutating { mutationProcess = command }
        let bytes = try await wait(command, mutating: mutating, deadline: deadline, assignment: assignment)
        if mutating { mutationProcess = nil }
        if assignment {
            guard let envelope = try? JSONDecoder().decode(WireEnvelope<Result>.self, from: bytes), envelope.schemaVersion == 1,
                  let raw = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
                throw mutating ? CompanionError.assignmentUncertain : CompanionError.assignmentUnavailable
            }
            if !envelope.ok {
                guard AssignmentWire.exact(raw, ["schemaVersion", "ok", "error"]), let failure = raw["error"] as? [String: Any],
                      AssignmentWire.exact(failure, ["code", "message"]), let code = failure["code"] as? String,
                      AssignmentWire.codes.contains(code), failure["message"] is String else {
                    throw mutating ? CompanionError.assignmentUncertain : CompanionError.assignmentUnavailable
                }
                if code == "ASSIGNMENT_UNCERTAIN" { throw CompanionError.assignmentUncertain }
                throw code == "ASSIGNMENT_CONFLICT" ? CompanionError.assignmentConflict : CompanionError.assignmentUnavailable
            }
            guard command.process.terminationReason == .exit, command.process.terminationStatus == 0,
                  AssignmentWire.exact(raw, ["schemaVersion", "ok", "result"]), let result = raw["result"],
                  validateAssignment?(result) == true else {
                throw mutating ? CompanionError.assignmentUncertain : CompanionError.assignmentUnavailable
            }
        }
        do {
            let envelope = try JSONDecoder().decode(WireEnvelope<Result>.self, from: bytes)
            guard envelope.schemaVersion == 1, envelope.ok, envelope.error == nil, let result = envelope.result else { throw CompanionError.protocolFailure }
            return result
        } catch {
            if assignment { throw mutating ? CompanionError.assignmentUncertain : CompanionError.assignmentUnavailable }
            if mutating { needsReconciliation = true; throw CompanionError.mutationUncertain }
            throw CompanionError.protocolFailure
        }
    }
    private func launch(executable: URL, arguments: [String], input: Data? = nil) throws -> RunningCommand {
        let process = Process(); process.executableURL = executable; process.arguments = arguments
        process.environment = childEnvironment
        let stdout = Pipe(), stderr = Pipe(), stdin = Pipe()
        process.standardOutput = stdout; process.standardError = stderr; process.standardInput = stdin
        let command = RunningCommand(process: process, input: stdin.fileHandleForWriting, bytes: input)
        command.stdout.attach(stdout.fileHandleForReading); command.stderr.attach(stderr.fileHandleForReading)
        do { try process.run() }
        catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            throw CompanionError.commandFailed
        }
        command.startInput()
        return command
    }
    private var childEnvironment: [String: String] {
        // An allowlist avoids forwarding tokens, dynamic-loader injection, or Node startup hooks.
        let ordinary = ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TZ"]
        var environment = ProcessInfo.processInfo.environment.filter { ordinary.contains($0.key) }
        environment["NODE_USE_SYSTEM_CA"] = "1"
        return environment
    }
    private func launchManaged(executable: URL, script: URL, context: ActivationContext) throws -> OwnedRouter {
        let process = Process(), id = UUID()
        process.executableURL = executable
        process.arguments = ["--use-system-ca", script.path, "--config", context.configPath, "--session", id.uuidString]
        process.environment = childEnvironment
        let stdout = Pipe(), stderr = Pipe(), stdin = Pipe()
        process.standardOutput = stdout; process.standardError = stderr; process.standardInput = stdin
        let capture = BoundedCapture(limit: 16 * 1024)
        capture.attach(stderr.fileHandleForReading)
        do { try process.run() }
        catch {
            stderr.fileHandleForReading.readabilityHandler = nil
            try? stderr.fileHandleForReading.close(); try? stdout.fileHandleForReading.close()
            try? stdin.fileHandleForWriting.close()
            throw CompanionError.startupFailed
        }
        let child = OwnedRouter(process: process, context: context, id: id)
        let channel = RouterModeChannel(input: stdin.fileHandleForWriting, output: stdout.fileHandleForReading, sessionID: id, context: context)
        owned[id] = (child, channel, capture)
        Task { [self, child, channel, capture] in
            while child.process.isRunning { capture.discard(); await pause(0.02) }
            channel.close()
            while !capture.snapshot.eof { capture.discard(); await pause(0.02) }
            capture.discard()
            owned.removeValue(forKey: child.id)
            onChildExit?(child.id, child.process.terminationStatus)
        }
        return child
    }
    private func wait(_ command: RunningCommand, mutating: Bool, deadline: Date? = nil, assignment: Bool = false) async throws -> Data {
        let deadline = deadline ?? Date().addingTimeInterval(5)
        while command.process.isRunning || !command.drained {
            if Task.isCancelled || Date() >= deadline || command.overflow || command.inputFailed {
                if mutating {
                    if !assignment { needsReconciliation = true }
                    Task { [self, command] in
                        while command.process.isRunning || !command.drained { await pause(0.02) }
                        command.discard(); mutationProcess = nil; mutationInFlight = false
                    }
                    throw assignment ? CompanionError.assignmentUncertain : CompanionError.mutationUncertain
                }
                await terminateReadOnly(command)
                if command.overflow || command.inputFailed { throw CompanionError.protocolFailure }
                throw CompanionError.timedOut
            }
            await pause(0.01)
        }
        defer { command.discard() }
        // The assignment CLI exits 1 for a complete rejection envelope. Only its
        // strict failure parser may establish certainty; a signal or success cannot.
        let assignmentFailure = assignment && mutating && command.process.terminationReason == .exit && command.process.terminationStatus == 1
        guard (command.process.terminationStatus == 0 || assignmentFailure), !command.overflow, !command.inputFailed else {
            if mutating {
                mutationProcess = nil
                if !assignment { needsReconciliation = true }
                throw assignment ? CompanionError.assignmentUncertain : CompanionError.mutationUncertain
            }
            throw command.overflow || command.inputFailed ? CompanionError.protocolFailure : CompanionError.commandFailed
        }
        return command.stdout.snapshot.data
    }
    private func terminateReadOnly(_ command: RunningCommand) async {
        if command.process.isRunning { command.process.terminate() }
        let deadline = Date().addingTimeInterval(0.5)
        while command.process.isRunning && Date() < deadline { await pause(0.01) }
        if command.process.isRunning { kill(command.process.processIdentifier, SIGKILL) }
        while command.process.isRunning || !command.drained { await pause(0.01) }
        command.discard()
    }
    public func start(configPath: URL) async throws -> OwnedRouter {
        let before = try await inspect(configPath: configPath, browseHome: configPath.deletingLastPathComponent())
        guard let context = before.context, before.configuration.state == "valid", before.configuration.setupState == "ready", !owned.values.contains(where: { $0.child.context == context && $0.child.process.isRunning }) else { throw CompanionError.startupFailed }
        let script = try resource("managed-serve.js")
        let executable = try await runtime(deadline: Date().addingTimeInterval(5))
        let child = try launchManaged(executable: executable, script: script, context: context)
        guard let tracked = owned[child.id] else { throw CompanionError.startupFailed }
        // Ownership is registered before awaiting either the pipe handshake or matching listener health.
        _ = try? await tracked.channel.waitUntilReady()
        let deadline = Date().addingTimeInterval(5)
        while child.process.isRunning, Date() < deadline {
            if let inspection = try? await inspect(configPath: configPath, browseHome: URL(fileURLWithPath: context.codexHome), deadline: deadline),
               inspection.context == context, inspection.provider.proxyReady == true { return child }
            if Task.isCancelled { return child }
            await pause(0.1)
        }
        guard child.process.isRunning else { throw CompanionError.startupFailed }
        return child // A live child remains owned even when matching readiness is uncertain.
    }
    public func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode {
        let mode = try await modeChannel(for: child).readMode()
        _ = try modeChannel(for: child)
        return mode
    }
    public func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode {
        let applied = try await modeChannel(for: child).setMode(mode)
        _ = try modeChannel(for: child)
        return applied
    }
    private func modeChannel(for child: OwnedRouter) throws -> RouterModeChannel {
        guard let tracked = owned[child.id], tracked.child === child, tracked.child.process === child.process,
              tracked.child.context == child.context, child.process.isRunning else { throw CompanionError.unownedChild }
        return tracked.channel
    }
    public func readAssignment(_ child: OwnedRouter, projectID: String?, operationID: String?) async throws -> AssignmentState {
        let channel = try modeChannel(for: child)
        let state: AssignmentState
        do { state = try await channel.readAssignment(projectID: projectID, operationID: operationID) }
        catch { _ = try modeChannel(for: child); throw error }
        guard try modeChannel(for: child) === channel else { throw CompanionError.unownedChild }
        if let uncertainAssignment, uncertainAssignment.childID == child.id,
           operationID == uncertainAssignment.change.operationId,
           AssignmentWire.reconciles(state, change: uncertainAssignment.change, live: true) { self.uncertainAssignment = nil }
        return state
    }
    public func applyAssignment(_ change: AssignmentChange, to child: OwnedRouter) async throws -> AssignmentCommit {
        let channel = try modeChannel(for: child)
        guard change.expectedContext == child.context, AssignmentWire.change(change, live: true) else { throw CompanionError.assignmentConflict }
        guard uncertainAssignment == nil, !assignmentInFlight else { throw CompanionError.assignmentUncertain }
        guard !mutationInFlight, !needsReconciliation else { throw CompanionError.assignmentUnavailable }
        assignmentInFlight = true
        defer { assignmentInFlight = false }
        do {
            let commit = try await channel.applyAssignment(change)
            guard try modeChannel(for: child) === channel else {
                uncertainAssignment = (change, child.id); throw CompanionError.assignmentUncertain
            }
            return commit
        } catch {
            guard (try? modeChannel(for: child)) === channel else {
                uncertainAssignment = (change, child.id); throw CompanionError.assignmentUncertain
            }
            if error as? CompanionError == .assignmentUncertain { uncertainAssignment = (change, child.id) }
            throw error
        }
    }
    public func readStoppedAssignment(context: ActivationContext, projectID: String, operationID: String?) async throws -> AssignmentState {
        guard AssignmentWire.context(context), AssignmentWire.uuid(projectID), operationID.map(AssignmentWire.uuid) ?? true else { throw CompanionError.assignmentUnavailable }
        // Reads begun before exit/drain cannot establish a possibly writing helper's outcome.
        guard !owned.values.contains(where: { $0.child.context == context }) else { throw CompanionError.assignmentUnavailable }
        guard !mutationInFlight, mutationProcess == nil, !assignmentInFlight else { throw CompanionError.assignmentUncertain }
        if let id = uncertainAssignment?.childID, owned[id] != nil { throw CompanionError.assignmentUncertain }
        let observed = uncertainAssignment
        let generation = mutationGeneration
        let request: [String: Any] = ["schemaVersion": 1, "action": "assignment_state", "configPath": context.configPath,
            "expectedContext": try JSONSerialization.jsonObject(with: JSONEncoder().encode(context)),
            "projectId": projectID, "operationId": operationID as Any? ?? NSNull()]
        let state: AssignmentState = try await requestResult(request, mutating: false, assignment: true) {
            AssignmentWire.state($0, context: context, projectID: projectID, operationID: operationID, live: false) != nil
        }
        guard !owned.values.contains(where: { $0.child.context == context }) else { throw CompanionError.assignmentUnavailable }
        guard !mutationInFlight, mutationProcess == nil, !assignmentInFlight else { throw CompanionError.assignmentUncertain }
        if let observed, operationID == observed.change.operationId,
           observed.childID.map({ owned[$0] == nil }) ?? true,
           generation == mutationGeneration,
           uncertainAssignment?.change.operationId == observed.change.operationId,
           AssignmentWire.reconciles(state, change: observed.change, live: false) { uncertainAssignment = nil }
        return state
    }
    public func saveStoppedAssignment(_ change: AssignmentChange) async throws -> AssignmentCommit {
        guard AssignmentWire.change(change, live: false) else { throw CompanionError.assignmentConflict }
        guard !owned.values.contains(where: { $0.child.context == change.expectedContext }) else { throw CompanionError.assignmentUnavailable }
        guard uncertainAssignment == nil, !assignmentInFlight else { throw CompanionError.assignmentUncertain }
        guard !mutationInFlight, !needsReconciliation else { throw CompanionError.assignmentUnavailable }
        var request = try JSONSerialization.jsonObject(with: JSONEncoder().encode(change)) as! [String: Any]
        request.removeValue(forKey: "expectedRunningRevision")
        request["schemaVersion"] = 1; request["action"] = "assignment_commit"
        mutationInFlight = true; assignmentInFlight = true; mutationGeneration = UUID()
        defer { assignmentInFlight = false; if mutationProcess == nil { mutationInFlight = false } }
        do {
            let commit: AssignmentCommit = try await requestResult(request, mutating: true, assignment: true) {
                AssignmentWire.commit($0, change: change, live: false) != nil
            }
            return commit
        } catch {
            if error as? CompanionError == .assignmentUncertain { uncertainAssignment = (change, nil) }
            throw error
        }
    }
    public func probeAssignmentPort(_ context: ActivationContext) async -> StopOutcome.PortState { await probe(port: context.listenPort) }
    public func stop(_ child: OwnedRouter) async throws -> StopOutcome {
        guard let tracked = owned[child.id], tracked.child === child, tracked.child.process === child.process,
              child.process.isRunning else { throw CompanionError.unownedChild }
        child.process.terminate()
        // Do not escalate to killing a recovered PID; only the retained Process receives a signal.
        let deadline = Date().addingTimeInterval(5)
        while child.process.isRunning && Date() < deadline { await pause(0.01) }
        let exited = !child.process.isRunning
        if exited {
            while owned[child.id] != nil { await pause(0.01) }
        }
        return StopOutcome(childExited: exited, portState: await probe(port: child.context.listenPort))
    }
    private func probe(port: Int) async -> StopOutcome.PortState {
        guard let port = NWEndpoint.Port(rawValue: UInt16(exactly: port) ?? 0), port.rawValue != 0 else { return .unknown }
        return await withCheckedContinuation { continuation in
            PortProbe(port: port, continuation: continuation).start()
        }
    }
    private func pause(_ seconds: Double) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { continuation.resume() }
        }
    }

    private func validSummary(_ value: AccountSummary?) -> Bool {
        guard let value else { return true }
        return UUID(uuidString: value.id) != nil && !value.displayName.isEmpty && value.displayName.unicodeScalars.count <= 80 &&
            value.displayName == value.displayName.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.displayName.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
    private func valid(_ inspection: Inspection) -> Bool {
        guard ["missing", "valid", "invalid", "unavailable"].contains(inspection.configuration.state),
              inspection.configuration.mode == nil || ["legacy", "credential", "accounts"].contains(inspection.configuration.mode!),
              ["direct", "router", "conflict", "unavailable"].contains(inspection.provider.state),
              ["none", "prepared", "active", "restored", "unavailable"].contains(inspection.provider.recordPhase),
              ["ready", "unavailable"].contains(inspection.catalog.state),
              inspection.catalog.entries.allSatisfy({ ["mapped", "unmapped", "target_missing", "catalog_missing"].contains($0.routeState) &&
                  ($0.assignmentKind == nil || ["override", "inherited", "legacy_inherited", "target_missing"].contains($0.assignmentKind!)) && validSummary($0.account) }),
              inspection.configuration.setupState == nil || ["ready", "required", "migration_required", "invalid"].contains(inspection.configuration.setupState!),
              validSummary(inspection.configuration.defaultAccount),
              inspection.configuration.accounts?.allSatisfy({ validSummary($0) }) ?? true,
              inspection.configuration.accounts.map({ Set($0.map(\.id)).count == $0.count }) ?? true,
              [inspection.configurationRevision, inspection.configurationIdentity, inspection.routingFingerprint, inspection.recoveryRevision, inspection.catalog.revision].allSatisfy({ $0.map(validRevision) ?? true }) else { return false }
        if let context = inspection.context {
            guard context.configPath.hasPrefix("/"), context.codexHome.hasPrefix("/"), (1...65535).contains(context.listenPort),
                  context.providerId.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else { return false }
        }
        return inspection.configuration.state != "valid" || (inspection.context != nil && inspection.configuration.path == inspection.context?.configPath)
    }
}

private final class PortProbe: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "companion.port-probe")
    private var continuation: CheckedContinuation<StopOutcome.PortState, Never>?
    init(port: NWEndpoint.Port, continuation: CheckedContinuation<StopOutcome.PortState, Never>) {
        connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        self.continuation = continuation
    }
    func start() {
        connection.stateUpdateHandler = { [self] state in
            switch state {
            case .ready: finish(.occupied)
            case .failed(let error), .waiting(let error):
                if case .posix(let code) = error, code == .ECONNREFUSED { finish(.empty) }
                else { finish(.unknown) }
            case .cancelled: finish(.unknown)
            default: break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 1) { self.finish(.unknown) }
    }
    private func finish(_ state: StopOutcome.PortState) {
        guard let continuation else { return }
        self.continuation = nil; connection.stateUpdateHandler = nil
        connection.cancel(); continuation.resume(returning: state)
    }
}
