import Foundation
import Observation

@MainActor @Observable public final class RouterController {
    public enum DesktopConfirmation: Equatable { case unknown, routedPending, directPending, confirmedRouted, confirmedDirect }
    // Comparison metadata is stripped from this presentation snapshot.
    public private(set) var inspection: Inspection?
    public private(set) var selectedConfiguration: URL?
    public private(set) var selectedNode: URL?
    public private(set) var ownedRouter: OwnedRouter?
    public private(set) var desktopConfirmation: DesktopConfirmation = .unknown
    public private(set) var busy = false
    public private(set) var error: String?
    public private(set) var lastStopOutcome: StopOutcome?
    public private(set) var quitRequested = false
    public private(set) var mutationRequiresReconciliation = false

    @ObservationIgnored private let backend: any CompanionBackend
    @ObservationIgnored private let store: PrivateStore
    @ObservationIgnored private let browseHome: URL
    private var journal = CompanionJournal()
    private var usable = false
    private var secondInstance = false
    private var recoveryObligation = false
    private var dependencyContext: ActivationContext?
    private var hasDepended = false
    private var directOnlyChild: UUID?
    private var revision: String?
    private var generation: UInt64 = 0
    private var inspectionSequence: UInt64 = 0
    private var refreshRunning = false
    private var refreshAgain = false
    private var stoppingID: UUID?

    public var recoveryContext: ActivationContext? { dependencyContext }
    public var needsManualListenerCleanup: Bool {
        ownedRouter == nil && (lastStopOutcome?.portState == .occupied || inspection?.provider.proxyReady == true)
    }
    public var canSelectConfiguration: Bool { usable && !busy && !mutationRequiresReconciliation && ownedRouter == nil && !recoveryObligation }
    public var canStart: Bool {
        usable && !busy && !mutationRequiresReconciliation && ownedRouter == nil && matchingContext != nil && inspection?.provider.proxyReady == false
    }
    public var canActivate: Bool {
        guard usable, !busy, !mutationRequiresReconciliation, let child = ownedRouter, child.process.isRunning, matchingContext == child.context,
              let provider = inspection?.provider else { return false }
        return provider.proxyReady == true && ["direct", "router"].contains(provider.state) &&
            !provider.recoveryRequired && !["prepared", "unavailable"].contains(provider.recordPhase)
    }
    public var canRestoreDirect: Bool { usable && !busy && !mutationRequiresReconciliation && matchingContext != nil }
    public var canStop: Bool { !busy && stopPermitted }
    public var canQuit: Bool { secondInstance || (usable && !busy && !mutationRequiresReconciliation && ownedRouter == nil && !recoveryObligation && journal.pending == nil) }

    public init(backend: any CompanionBackend, store: PrivateStore, browseHome: URL) {
        self.backend = backend; self.store = store; self.browseHome = browseHome
        do {
            // Take the lock before even creating initial state: a second instance is read-only.
            try store.acquireInstanceLock()
            journal = try store.load()
            dependencyContext = journal.pending?.context
            recoveryObligation = journal.pending != nil
            hasDepended = recoveryObligation
            if let path = journal.pending?.context.configPath ?? journal.selectedConfigurationPath {
                selectedConfiguration = URL(fileURLWithPath: path)
            } else {
                let normal = store.directory.deletingLastPathComponent().appendingPathComponent("config.json")
                if FileManager.default.fileExists(atPath: normal.path) { selectedConfiguration = normal.resolvingSymlinksInPath() }
            }
            selectedNode = journal.nodeExecutablePath.map { URL(fileURLWithPath: $0) }
            if let selectedNode { backend.setNodeExecutable(selectedNode) }
            usable = true
            backend.onChildExit = { [weak self] id, _ in self?.childExited(id) }
        } catch {
            secondInstance = (error as? CompanionError) == .instanceRunning
            self.error = safe(error)
        }
    }

    public func refresh() async {
        guard usable else { return }
        if refreshRunning { refreshAgain = true; return }
        refreshRunning = true
        repeat {
            refreshAgain = false
            await inspectNow()
        } while refreshAgain && !busy
        refreshRunning = false
    }

    public func selectConfiguration(_ path: URL) async {
        guard canSelectConfiguration, begin() else { reject(); return }
        defer { finish() }
        guard path.isFileURL, path.path.hasPrefix("/") else { reject(); return }
        let canonical = path.resolvingSymlinksInPath()
        do {
            var next = journal; next.selectedConfigurationPath = canonical.path
            try persist(next)
            selectedConfiguration = canonical; inspection = nil; revision = nil
            dependencyContext = nil; hasDepended = false; desktopConfirmation = .unknown
            await inspectNow()
        } catch { self.error = safe(error) }
    }

    public func selectNode(_ path: URL) async {
        guard begin() else { return }
        defer { finish() }
        do {
            let validated = try await backend.validateNode(path)
            var next = journal; next.nodeExecutablePath = validated.path
            try persist(next)
            selectedNode = validated; backend.setNodeExecutable(validated)
            await inspectNow()
        } catch { self.error = safe(error) }
    }

    public func start() async {
        guard begin() else { return }
        defer { finish() }
        guard await inspectNow() else { return }
        guard !backend.mutationRequiresReconciliation, let context = matchingContext, ownedRouter == nil, inspection?.provider.proxyReady == false else { reject(); return }
        do {
            let directSession = !hasDepended && !recoveryObligation && cleanDirect(context)
            let child = try await backend.start(configPath: URL(fileURLWithPath: context.configPath))
            // A handle from a readiness timeout is still owned, but never implies readiness.
            ownedRouter = child
            directOnlyChild = directSession && child.context == context ? child.id : nil
            if !child.process.isRunning { childExited(child.id) }
            await inspectNow()
        } catch { self.error = safe(error) }
    }

    public func activate() async {
        guard begin() else { return }
        defer { finish() }
        guard await inspectNow() else { return }
        guard !backend.mutationRequiresReconciliation, let context = matchingContext, let child = ownedRouter, child.process.isRunning,
              child.context == context, let provider = inspection?.provider, provider.proxyReady == true,
              ["direct", "router"].contains(provider.state), !provider.recoveryRequired,
              !["prepared", "unavailable"].contains(provider.recordPhase) else { reject(); return }
        do {
            try setPending(context, .activationAttempt)
            hasDepended = true; directOnlyChild = nil; desktopConfirmation = .routedPending
            _ = try await backend.control(action: .activate, configPath: URL(fileURLWithPath: context.configPath), expectedContext: context)
            try setPending(context, .routedConfirmation)
        } catch { self.error = safe(error) }
        // Even a failed helper can have written the provider. Never infer rollback from an error.
        generation &+= 1
        await inspectNow()
    }

    public func restoreDirect() async {
        guard begin() else { return }
        defer { finish() }
        guard await inspectNow() else { return }
        guard !backend.mutationRequiresReconciliation, let context = matchingContext else { reject(); return }
        let previouslyIndependent = !hasDepended && !recoveryObligation && cleanDirect(context)
        let previousDirectOnlyChild = directOnlyChild
        var unchangedIndependentSession = false
        do {
            try setPending(context, .restoring)
            hasDepended = true; directOnlyChild = nil; desktopConfirmation = .directPending
            let result = try await backend.control(action: .rollback, configPath: URL(fileURLWithPath: context.configPath), expectedContext: context)
            try setPending(context, .directConfirmation)
            unchangedIndependentSession = previouslyIndependent && !result.changed
        } catch { self.error = safe(error) }
        generation &+= 1
        let reconciled = await inspectNow()
        if unchangedIndependentSession, reconciled, !backend.mutationRequiresReconciliation, cleanDirect(context) {
            do {
                var next = journal; next.pending = nil; try persist(next)
                recoveryObligation = false; hasDepended = false
                directOnlyChild = previousDirectOnlyChild; desktopConfirmation = .unknown
            } catch { self.error = safe(error) }
        }
    }

    public func confirmRoutedResponse() async { await confirm(direct: false) }
    public func confirmDirectResponse() async { await confirm(direct: true) }

    public func stop() async {
        guard begin() else { return }
        defer { finish() }
        await stopOwnedChild()
    }
    public func requestQuit() async {
        guard !secondInstance else { quitRequested = true; return }
        guard begin() else { return }
        defer { finish() }
        if ownedRouter != nil { await stopOwnedChild() }
        else { await inspectNow() }
        guard !backend.mutationRequiresReconciliation, ownedRouter == nil, !recoveryObligation, journal.pending == nil else { reject(); return }
        quitRequested = true
    }

    private var matchingContext: ActivationContext? {
        guard let value = inspection, value.configuration.state == "valid", let context = value.context,
              context.configPath == selectedConfiguration?.path, value.configuration.path == context.configPath else { return nil }
        if recoveryObligation, let dependencyContext, context != dependencyContext { return nil }
        if let child = ownedRouter, context != child.context { return nil }
        return context
    }
    private func cleanDirect(_ context: ActivationContext) -> Bool {
        matchingContext == context && inspection?.provider.state == "direct" && inspection?.provider.recoveryRequired == false &&
            ["none", "restored"].contains(inspection?.provider.recordPhase ?? "unavailable") && revision != nil
    }
    private var stopPermitted: Bool {
        guard usable, !backend.mutationRequiresReconciliation, !mutationRequiresReconciliation, let child = ownedRouter, child.process.isRunning, cleanDirect(child.context), !recoveryObligation else { return false }
        return desktopConfirmation == .confirmedDirect || (!hasDepended && directOnlyChild == child.id)
    }
    private func begin() -> Bool {
        guard usable, !busy else { if !busy { reject() }; return false }
        busy = true; error = nil; generation &+= 1; quitRequested = false
        return true
    }
    private func finish() { generation &+= 1; busy = false }
    private func reject() { if error == nil { error = "The action is unavailable until the current context is reconciled." } }
    private func safe(_ error: Error) -> String { (error as? CompanionError)?.rawValue ?? CompanionError.commandFailed.rawValue }
    private func persist(_ value: CompanionJournal) throws { try store.save(value); journal = value }
    private func setPending(_ context: ActivationContext, _ phase: CompanionJournal.Phase) throws {
        // Memory retains conservative authority even if persistence fails after a provider write.
        dependencyContext = context; recoveryObligation = true
        var next = journal; next.selectedConfigurationPath = context.configPath; next.pending = .init(context: context, phase: phase)
        try persist(next)
    }
    @discardableResult private func inspectNow() async -> Bool {
        inspectionSequence &+= 1
        let requestSequence = inspectionSequence
        let requestGeneration = generation
        defer { mutationRequiresReconciliation = backend.mutationRequiresReconciliation }
        do {
            let value = try await backend.inspect(configPath: selectedConfiguration, browseHome: browseHome)
            guard requestGeneration == generation, requestSequence == inspectionSequence else { return false }
            reconcile(value)
            return true
        } catch {
            guard requestGeneration == generation, requestSequence == inspectionSequence else { return false }
            inspectionFailed(error)
            return false
        }
    }
    private func inspectionFailed(_ failure: Error) {
        revision = nil
        if let value = inspection {
            inspection = Inspection(configuration: .init(state: "unavailable"), context: value.context,
                provider: .init(state: "unavailable", recoveryRequired: recoveryObligation, proxyReady: nil, recordPhase: "unavailable"),
                catalog: .init(state: "unavailable", entries: []))
        }
        invalidateConfirmation()
        error = safe(failure)
    }
    private func reconcile(_ value: Inspection) {
        let changed = revision != nil && revision != value.revision
        let readinessLost = inspection?.provider.proxyReady == true && value.provider.proxyReady != true
        revision = value.revision
        var presentation = value; presentation.revision = nil; inspection = presentation
        if changed || readinessLost || matchingContext == nil { invalidateConfirmation() }
        if let context = value.context, value.configuration.state == "valid",
           value.provider.recoveryRequired || ["router", "conflict", "unavailable"].contains(value.provider.state) || ["prepared", "active"].contains(value.provider.recordPhase) {
            // Imported recovery is bound once; later mapping/home edits cannot retarget it.
            if !recoveryObligation && desktopConfirmation != .confirmedDirect {
                hasDepended = true; directOnlyChild = nil
                let phase: CompanionJournal.Phase = value.provider.state == "router" ? .routedConfirmation : .activationAttempt
                do { try setPending(context, phase) } catch { self.error = safe(error) }
            }
        }
        if recoveryObligation, let dependencyContext, value.context != nil, value.context != dependencyContext {
            error = "The configuration context changed. Restore the recorded context before continuing."
        }
    }
    private func invalidateConfirmation() {
        guard desktopConfirmation == .confirmedDirect || desktopConfirmation == .confirmedRouted else { return }
        let direct = desktopConfirmation == .confirmedDirect
        desktopConfirmation = direct ? .directPending : .routedPending
        if let context = dependencyContext ?? ownedRouter?.context {
            do { try setPending(context, direct ? .directConfirmation : .routedConfirmation) }
            catch { self.error = safe(error) }
        }
    }
    private func childExited(_ id: UUID) {
        guard let child = ownedRouter, child.id == id else { return }
        generation &+= 1; ownedRouter = nil; directOnlyChild = nil
        if stoppingID == id { return }
        inspection?.provider.proxyReady = nil
        invalidateConfirmation()
        if hasDepended, !recoveryObligation {
            do { try setPending(child.context, .directConfirmation) }
            catch { self.error = safe(error) }
        }
        error = "The owned router exited. Refresh and complete direct recovery."
    }
    private func confirm(direct: Bool) async {
        guard begin() else { return }
        defer { finish() }
        guard let context = dependencyContext ?? matchingContext else { reject(); return }
        let expectedRevision = revision
        let confirmationGeneration = generation
        guard await inspectNow() else { reject(); return }
        guard !backend.mutationRequiresReconciliation, confirmationGeneration == generation, matchingContext == context, revision != nil,
              expectedRevision == nil || revision == expectedRevision else { reject(); return }
        if direct {
            guard cleanDirect(context) else { reject(); return }
            do {
                var next = journal; next.pending = nil; try persist(next)
                recoveryObligation = false; desktopConfirmation = .confirmedDirect
            } catch { self.error = safe(error) }
        } else {
            guard let child = ownedRouter, child.process.isRunning, child.context == context,
                  inspection?.provider.state == "router", inspection?.provider.proxyReady == true,
                  inspection?.provider.recordPhase == "active", inspection?.provider.recoveryRequired == false else { reject(); return }
            desktopConfirmation = .confirmedRouted
        }
    }
    private func stopOwnedChild() async {
        guard await inspectNow() else { return }
        guard stopPermitted, let child = ownedRouter else { reject(); return }
        stoppingID = child.id
        defer { stoppingID = nil }
        do {
            let outcome = try await backend.stop(child)
            lastStopOutcome = outcome
            if outcome.childExited && !child.process.isRunning {
                ownedRouter = nil; directOnlyChild = nil
                // The requested teardown consumed this readiness observation. The port result
                // remains independent; neither occupied nor unknown means matching readiness.
                inspection?.provider.proxyReady = nil
            }
            if !outcome.childExited || ownedRouter != nil { error = "The owned router has not been confirmed stopped." }
            else if outcome.portState == .occupied { error = "The owned router exited, but another listener remains. Manual cleanup is required." }
            else if outcome.portState == .unknown { error = "The owned router exited; the listener port could not be verified." }
        } catch { self.error = safe(error) }
    }
}
