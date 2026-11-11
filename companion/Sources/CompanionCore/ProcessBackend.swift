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
private final class RunningCommand {
    let process: Process
    var inputFailed = false
    let stdout = BoundedCapture(limit: 1024 * 1024)
    let stderr = BoundedCapture(limit: 16 * 1024)
    init(process: Process) { self.process = process }
    var drained: Bool { stdout.snapshot.eof && stderr.snapshot.eof }
    var overflow: Bool { stdout.snapshot.overflow || stderr.snapshot.overflow }
    func discard() { stdout.discard(); stderr.discard() }
}

@MainActor public final class ProcessBackend: CompanionBackend {
    public var onChildExit: ((UUID, Int32) -> Void)?
    private let resourcesURL: URL
    private var nodeExecutable: URL?
    private var owned: [UUID: (child: OwnedRouter, command: RunningCommand)] = [:]
    private var mutationInFlight = false
    private var mutationProcess: RunningCommand?
    private var needsReconciliation = false
    private var uncertainContext: ActivationContext?

    public init(resourcesURL: URL, nodeExecutable: URL?) {
        self.resourcesURL = resourcesURL; self.nodeExecutable = nodeExecutable
    }
    public func setNodeExecutable(_ validatedPath: URL) { nodeExecutable = validatedPath }

    public func validateNode(_ path: URL) async throws -> URL {
        guard path.isFileURL, path.path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path.path) else { throw CompanionError.nodeUnavailable }
        let canonical = path.resolvingSymlinksInPath()
        do {
            let command = try launch(executable: canonical, arguments: ["--version"])
            let bytes = try await wait(command, mutating: false)
            guard bytes.count <= 128, let text = String(data: bytes, encoding: .utf8),
                  text.range(of: "^v24\\.[0-9]+\\.[0-9]+\\n?$", options: .regularExpression) != nil else { throw CompanionError.nodeUnavailable }
            return canonical
        } catch { throw CompanionError.nodeUnavailable }
    }
    private func runtime() async throws -> URL {
        if let nodeExecutable {
            do { return try await validateNode(nodeExecutable) }
            catch CompanionError.nodeUnavailable { /* Continue discovery after a stale saved path. */ }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        var candidates = ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"].map { URL(fileURLWithPath: $0) }
        let versions = home.appendingPathComponent(".nvm/versions/node")
        if let directories = try? FileManager.default.contentsOfDirectory(at: versions, includingPropertiesForKeys: nil) {
            candidates += directories.filter { $0.lastPathComponent.hasPrefix("v24.") }
                .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
                .map { $0.appendingPathComponent("bin/node") }
        }
        for candidate in candidates {
            if let validated = try? await validateNode(candidate) { nodeExecutable = validated; return validated }
        }
        throw CompanionError.nodeUnavailable
    }
    public func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection {
        try await inspect(configPath: configPath, browseHome: browseHome, deadline: Date().addingTimeInterval(5))
    }
    private func inspect(configPath: URL?, browseHome: URL, deadline: Date) async throws -> Inspection {
        var request: [String: Any] = ["schemaVersion": 1, "action": "inspect", "configPath": configPath?.path as Any? ?? NSNull()]
        if configPath == nil { request["browseHome"] = browseHome.path }
        let result: Inspection = try await requestResult(request, mutating: false, deadline: deadline)
        guard valid(result) else { throw CompanionError.protocolFailure }
        if !mutationInFlight, let context = uncertainContext, result.context == context,
           ["direct", "router"].contains(result.provider.state), result.provider.recordPhase != "unavailable" {
            needsReconciliation = false; uncertainContext = nil
        }
        return result
    }
    public func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult {
        guard !mutationInFlight, !needsReconciliation else { throw CompanionError.mutationBusy }
        mutationInFlight = true
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
    private func resource(_ name: String) throws -> URL {
        let path = resourcesURL.appendingPathComponent("src/\(name)")
        var isDirectory: ObjCBool = false
        guard resourcesURL.isFileURL, FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory),
              !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: path.path) else { throw CompanionError.resourcesUnavailable }
        return path
    }
    private func requestResult<Result: Codable>(_ request: [String: Any], mutating: Bool, deadline: Date? = nil) async throws -> Result {
        let script = try resource("companion-cli.js")
        let executable = try await runtime()
        let input: Data
        do { input = try JSONSerialization.data(withJSONObject: request) } catch { throw CompanionError.protocolFailure }
        guard input.count <= 16 * 1024 else { throw CompanionError.protocolFailure }
        let command = try launch(executable: executable, arguments: ["--use-system-ca", script.path], input: input)
        if mutating { mutationProcess = command }
        let bytes = try await wait(command, mutating: mutating, deadline: deadline)
        if mutating { mutationProcess = nil }
        do {
            let envelope = try JSONDecoder().decode(WireEnvelope<Result>.self, from: bytes)
            guard envelope.schemaVersion == 1, envelope.ok, envelope.error == nil, let result = envelope.result else { throw CompanionError.protocolFailure }
            return result
        } catch {
            if mutating { needsReconciliation = true; throw CompanionError.mutationUncertain }
            throw CompanionError.protocolFailure
        }
    }
    private func launch(executable: URL, arguments: [String], input: Data? = nil) throws -> RunningCommand {
        let process = Process(); process.executableURL = executable; process.arguments = arguments
        // An allowlist avoids forwarding tokens, dynamic-loader injection, or Node startup hooks.
        let ordinary = ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TZ"]
        var environment = ProcessInfo.processInfo.environment.filter { ordinary.contains($0.key) }
        environment["NODE_USE_SYSTEM_CA"] = "1"
        process.environment = environment
        let stdout = Pipe(), stderr = Pipe(), stdin = Pipe()
        process.standardOutput = stdout; process.standardError = stderr; process.standardInput = stdin
        let command = RunningCommand(process: process)
        command.stdout.attach(stdout.fileHandleForReading); command.stderr.attach(stderr.fileHandleForReading)
        do { try process.run() }
        catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            throw CompanionError.commandFailed
        }
        do {
            if let input { try stdin.fileHandleForWriting.write(contentsOf: input) }
            try stdin.fileHandleForWriting.close()
        } catch {
            // Even failed stdin delivery can follow a partial provider write. The caller retains it.
            command.inputFailed = true
        }
        return command
    }
    private func wait(_ command: RunningCommand, mutating: Bool, deadline: Date? = nil) async throws -> Data {
        let deadline = deadline ?? Date().addingTimeInterval(5)
        while command.process.isRunning || !command.drained {
            if Task.isCancelled || Date() >= deadline || command.overflow || command.inputFailed {
                if mutating {
                    needsReconciliation = true
                    Task { [self, command] in
                        while command.process.isRunning || !command.drained { await pause(0.02) }
                        command.discard(); mutationProcess = nil; mutationInFlight = false
                    }
                    throw CompanionError.mutationUncertain
                }
                await terminateReadOnly(command)
                if command.overflow || command.inputFailed { throw CompanionError.protocolFailure }
                throw CompanionError.timedOut
            }
            await pause(0.01)
        }
        defer { command.discard() }
        guard command.process.terminationStatus == 0, !command.overflow, !command.inputFailed else {
            if mutating { mutationProcess = nil; needsReconciliation = true; throw CompanionError.mutationUncertain }
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
        guard let context = before.context, before.configuration.state == "valid", !owned.values.contains(where: { $0.child.context == context && $0.child.process.isRunning }) else { throw CompanionError.startupFailed }
        let script = try resource("cli.js")
        let executable = try await runtime()
        let command = try launch(executable: executable, arguments: ["--use-system-ca", script.path, "serve", "--config", configPath.path])
        let child = OwnedRouter(process: command.process, context: context)
        owned[child.id] = (child, command)
        Task { [self, child, command] in
            while command.process.isRunning || !command.drained {
                command.discard()
                await pause(0.02)
            }
            command.discard()
            owned.removeValue(forKey: child.id)
            onChildExit?(child.id, command.process.terminationStatus)
        }
        let deadline = Date().addingTimeInterval(5)
        while command.process.isRunning, Date() < deadline {
            if let inspection = try? await inspect(configPath: configPath, browseHome: URL(fileURLWithPath: context.codexHome), deadline: deadline),
               inspection.context == context, inspection.provider.proxyReady == true { return child }
            if Task.isCancelled { return child }
            await pause(0.1)
        }
        guard command.process.isRunning else { throw CompanionError.startupFailed }
        return child // A live child remains owned even when matching readiness is uncertain.
    }
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

    private func valid(_ inspection: Inspection) -> Bool {
        guard ["missing", "valid", "invalid", "unavailable"].contains(inspection.configuration.state),
              inspection.configuration.mode == nil || ["legacy", "credential"].contains(inspection.configuration.mode!),
              ["direct", "router", "conflict", "unavailable"].contains(inspection.provider.state),
              ["none", "prepared", "active", "restored", "unavailable"].contains(inspection.provider.recordPhase),
              ["ready", "unavailable"].contains(inspection.catalog.state),
              inspection.catalog.entries.allSatisfy({ ["mapped", "unmapped", "target_missing", "catalog_missing"].contains($0.routeState) }) else { return false }
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
