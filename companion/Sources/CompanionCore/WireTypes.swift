import Foundation

public struct ActivationContext: Codable, Equatable {
    public var configPath: String
    public var codexHome: String
    public var providerId: String
    public var listenPort: Int
    public init(configPath: String, codexHome: String, providerId: String, listenPort: Int) {
        self.configPath = configPath; self.codexHome = codexHome
        self.providerId = providerId; self.listenPort = listenPort
    }
}
public struct Inspection: Codable, Equatable {
    public struct Configuration: Codable, Equatable {
        public var state: String; public var path: String?; public var mode: String?
        public init(state: String, path: String? = nil, mode: String? = nil) { self.state = state; self.path = path; self.mode = mode }
    }
    public struct Provider: Codable, Equatable {
        public var state: String; public var recoveryRequired: Bool; public var proxyReady: Bool?; public var recordPhase: String
        public init(state: String, recoveryRequired: Bool, proxyReady: Bool?, recordPhase: String) {
            self.state = state; self.recoveryRequired = recoveryRequired; self.proxyReady = proxyReady; self.recordPhase = recordPhase
        }
    }
    public struct Entry: Codable, Equatable {
        public var id: String; public var name: String; public var routeAlias: String?; public var routeState: String
        public init(id: String, name: String, routeAlias: String?, routeState: String) { self.id = id; self.name = name; self.routeAlias = routeAlias; self.routeState = routeState }
    }
    public struct Catalog: Codable, Equatable {
        public var state: String; public var entries: [Entry]
        public init(state: String, entries: [Entry]) { self.state = state; self.entries = entries }
    }
    public var configuration: Configuration; public var context: ActivationContext?; public var revision: String?
    public var provider: Provider; public var catalog: Catalog
    public init(configuration: Configuration, context: ActivationContext? = nil, revision: String? = nil, provider: Provider, catalog: Catalog) {
        self.configuration = configuration; self.context = context; self.revision = revision; self.provider = provider; self.catalog = catalog
    }
}
public enum ControlAction: String, Codable { case activate, rollback }
public struct ControlResult: Codable, Equatable {
    public var state: String; public var changed: Bool; public var restartRequired: Bool
    public init(state: String, changed: Bool, restartRequired: Bool) { self.state = state; self.changed = changed; self.restartRequired = restartRequired }
}
public struct WireEnvelope<Result: Codable>: Codable {
    public struct Failure: Codable { public var code: String; public var message: String }
    public var schemaVersion: Int; public var ok: Bool; public var result: Result?; public var error: Failure?
}
public enum CompanionError: String, Error, LocalizedError {
    case privateState = "Private companion state is unavailable or unsafe."
    case instanceRunning = "Another companion instance is running."
    case nodeUnavailable = "Select an executable Node 24 runtime."
    case resourcesUnavailable = "Bundled router resources are unavailable."
    case protocolFailure = "The router returned an invalid response."
    case commandFailed = "The router command failed."
    case timedOut = "The router command timed out."
    case mutationUncertain = "The provider operation is uncertain. Refresh before continuing."
    case mutationBusy = "A provider operation must finish and be reconciled first."
    case startupFailed = "The router could not be started."
    case unownedChild = "The router child is not owned by this session."
    public var errorDescription: String? { rawValue }
}
public struct CompanionJournal: Codable, Equatable {
    public enum Phase: String, Codable { case activationAttempt = "activation_attempt", routedConfirmation = "routed_confirmation", restoring, directConfirmation = "direct_confirmation" }
    public struct Pending: Codable, Equatable {
        public var context: ActivationContext; public var phase: Phase
        public init(context: ActivationContext, phase: Phase) { self.context = context; self.phase = phase }
    }
    public var schemaVersion: Int = 1
    public var selectedConfigurationPath: String?; public var nodeExecutablePath: String?; public var pending: Pending?
    public init(selectedConfigurationPath: String? = nil, nodeExecutablePath: String? = nil, pending: Pending? = nil) {
        self.selectedConfigurationPath = selectedConfigurationPath; self.nodeExecutablePath = nodeExecutablePath; self.pending = pending
    }
}
@MainActor public protocol CompanionBackend: AnyObject {
    var onChildExit: ((UUID, Int32) -> Void)? { get set }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection
    func validateNode(_ path: URL) async throws -> URL
    func setNodeExecutable(_ validatedPath: URL)
    func start(configPath: URL) async throws -> OwnedRouter
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult
    func stop(_ child: OwnedRouter) async throws -> StopOutcome
}
public final class OwnedRouter {
    public let id: UUID; public let context: ActivationContext; public let process: Process
    public init(process: Process, context: ActivationContext, id: UUID = UUID()) {
        self.process = process; self.context = context; self.id = id
    }
}
public struct StopOutcome: Equatable {
    public enum PortState: String { case empty, occupied, unknown }
    public var childExited: Bool; public var portState: PortState
    public init(childExited: Bool, portState: PortState) { self.childExited = childExited; self.portState = portState }
}
