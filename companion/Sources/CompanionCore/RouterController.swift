import Foundation
import Observation
import Darwin

@MainActor @Observable public final class RouterController {
    public enum DesktopConfirmation: Equatable { case unknown, routedPending, directPending, confirmedRouted, confirmedDirect }
    public enum QuitBlockReason: Equatable { case operationInProgress, directConfirmationPending, directRecoveryRequired, contextUnavailable }
    public enum ProjectRoutingStatus: Equatable { case known(ProjectRoutingMode), uncertain, unavailable, notRunning }
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
    public private(set) var projectRoutingStatus: ProjectRoutingStatus = .notRunning
    public private(set) var routingModeError: String?
    public private(set) var uncertainSetupOperationID: String?
    public private(set) var configurationLockRequiresResolution = false
    public enum AssignmentStatus: Equatable { case unavailable, ready, uncertain, diverged }
    public private(set) var selectedAssignment: AssignmentState?
    public private(set) var pendingAssignmentOperationID: String?
    public private(set) var assignmentRequiresReconciliation = false
    public private(set) var assignmentError: String?
    public private(set) var assignmentStatus: AssignmentStatus = .unavailable
    public var assignmentActionTitle: String { ownedRouter == nil ? "Save" : "Save and apply" }
    private var assignmentInspection: Inspection?
    private var assignmentBaseline: AssignmentState?
    private var assignmentChild: OwnedRouter?
    private var assignmentPortEmpty = false
    private var assignmentStorageSafe = false
    private var selectedAssignmentProjectID: String?
    private struct PendingAssignment {
        let change: AssignmentChange
        let before: Inspection
        let child: OwnedRouter?
        let confirmation: DesktopConfirmation
    }
    private var pendingAssignment: PendingAssignment?
    private struct AssignmentEditorBaseline {
        let projectID: String
        let state: AssignmentState
        let inspection: Inspection
        let child: OwnedRouter?
    }
    private var assignmentEditor: AssignmentEditorBaseline?
    private var setupReserved = false

    @ObservationIgnored private let backend: any CompanionBackend
    @ObservationIgnored private let store: PrivateStore
    @ObservationIgnored private let browseHome: URL
    private var journal = CompanionJournal()
    private var usable = false
    private var secondInstance = false
    private var initializationFailed = false
    private var recoveryObligation = false
    private var idleQuitAuthorized = false
    private var idleQuitJournalUnavailable = false
    private var dependencyContext: ActivationContext?
    private var hasDepended = false
    private var directOnlyChild: UUID?
    private var revision: String?
    private var generation: UInt64 = 0
    private var inspectionSequence: UInt64 = 0
    private var inspectionInFlight = false
    private var inspectionWaiters: [CheckedContinuation<Void, Never>] = []
    private var refreshRunning = false
    private var refreshAgain = false
    private var stoppingID: UUID?
    private var deferredReadinessLoss = false

    public var recoveryContext: ActivationContext? { dependencyContext }
    public var needsManualListenerCleanup: Bool {
        ownedRouter == nil && (lastStopOutcome?.portState == .occupied || inspection?.provider.proxyReady == true)
    }
    public var canSelectNode: Bool { usable && !busy && !mutationRequiresReconciliation }
    public var canSelectConfiguration: Bool { usable && !busy && !mutationRequiresReconciliation && !assignmentRequiresReconciliation && ownedRouter == nil && !recoveryObligation }
    public var canStart: Bool {
        usable && !busy && !mutationRequiresReconciliation && !assignmentRequiresReconciliation && ownedRouter == nil && matchingContext != nil && inspection?.provider.proxyReady == false && inspection?.configuration.setupState == "ready"
    }
    public var canActivate: Bool {
        guard usable, !busy, !mutationRequiresReconciliation, !assignmentRequiresReconciliation, inspection?.configuration.setupState == "ready", let child = ownedRouter, child.process.isRunning, matchingContext == child.context,
              let provider = inspection?.provider else { return false }
        return provider.proxyReady == true && ["direct", "router"].contains(provider.state) &&
            !provider.recoveryRequired && !["prepared", "unavailable"].contains(provider.recordPhase)
    }
    public var canRestoreDirect: Bool { usable && !busy && !mutationRequiresReconciliation && matchingContext != nil }
    public var canSetProjectRouting: Bool {
        guard usable, !busy, !mutationRequiresReconciliation, !backend.mutationRequiresReconciliation,
              case .known = projectRoutingStatus else { return false }
        return routingModeChild != nil
    }
    public var canConfirmRoutedResponse: Bool {
        guard usable, !busy, !mutationRequiresReconciliation, !backend.mutationRequiresReconciliation,
              let context = matchingContext, let child = ownedRouter, child.process.isRunning,
              child.context == context, let provider = inspection?.provider else { return false }
        return provider.state == "router" && provider.proxyReady == true && provider.recordPhase == "active" && !provider.recoveryRequired
    }
    public var canConfirmDirectResponse: Bool {
        guard usable, !busy, !mutationRequiresReconciliation, !backend.mutationRequiresReconciliation,
              let context = matchingContext else { return false }
        return cleanDirect(context)
    }
    public var canStop: Bool { !busy && stopPermitted }
    public var canQuit: Bool {
        secondInstance || initializationFailed || (usable && !busy && !mutationRequiresReconciliation && !assignmentRequiresReconciliation && ownedRouter == nil &&
            ((!recoveryObligation && journal.pending == nil) || (idleQuitAuthorized && hasIdleDirectQuitContext)))
    }
    public var quitBlockReason: QuitBlockReason? {
        // Presentation follows existing authority without refreshing or changing recovery evidence.
        if secondInstance || initializationFailed { return nil }
        if busy || mutationRequiresReconciliation || backend.mutationRequiresReconciliation || assignmentRequiresReconciliation { return .operationInProgress }
        if canQuit { return nil }
        if idleQuitJournalUnavailable { return .contextUnavailable }
        guard usable, let context = matchingContext, let provider = inspection?.provider, revision != nil,
              ["direct", "router"].contains(provider.state),
              ["none", "prepared", "active", "restored"].contains(provider.recordPhase) else { return .contextUnavailable }
        if cleanDirect(context), recoveryObligation || journal.pending != nil { return .directConfirmationPending }
        if provider.state == "router" || provider.recoveryRequired || ["prepared", "active"].contains(provider.recordPhase) {
            return .directRecoveryRequired
        }
        return .contextUnavailable
    }

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
            loadSetupEvidence()
            backend.onChildExit = { [weak self] id, _ in self?.childExited(id) }
        } catch {
            secondInstance = (error as? CompanionError) == .instanceRunning
            // Initialization cannot launch a child/helper; failed private evidence stays untouched.
            initializationFailed = !secondInstance
            self.error = safe(error)
        }
    }

    private func loadSetupEvidence() {
        guard let selectedConfiguration else { return }
        let directory = selectedConfiguration.deletingLastPathComponent()
        var hasEvidence = false
        for name in ["account-setup.json", ".activation.lock"] {
            var info = stat()
            if lstat(directory.appendingPathComponent(name).path, &info) == 0 { hasEvidence = true }
            else if errno != ENOENT { configurationLockRequiresResolution = true; mutationRequiresReconciliation = true; return }
        }
        guard hasEvidence else { return }
        do {
            let transaction = SetupTransactionStore(configPath: selectedConfiguration)
            switch try transaction.inspectLease() {
            case .absent: break
            case .activation: configurationLockRequiresResolution = true
            case let .setup(operationID): uncertainSetupOperationID = operationID
            }
            if let receipt = try transaction.load(), receipt.phase != .complete { uncertainSetupOperationID = receipt.operationId }
            mutationRequiresReconciliation = uncertainSetupOperationID != nil || configurationLockRequiresResolution
            if mutationRequiresReconciliation { error = "Account setup or activation is incomplete. Review the saved evidence and resolve the activation lock manually before continuing." }
        } catch {
            configurationLockRequiresResolution = true; mutationRequiresReconciliation = true
            self.error = CompanionError.privateState.rawValue
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

    public func refreshAndWait() async {
        guard usable else { return }
        await inspectNow()
    }

    public var canBeginAccountSetup: Bool {
        usable && !busy && !mutationRequiresReconciliation && !backend.mutationRequiresReconciliation && !assignmentRequiresReconciliation &&
            ownedRouter == nil && selectedConfiguration != nil && !recoveryObligation && journal.pending == nil
    }
    /// Reserves the action and inspection boundary until finishAccountSetup, including OS consent.
    public func beginAccountSetup() async throws -> SetupPreview {
        guard canBeginAccountSetup, let setup = backend as? any AccountSetupBackend, begin() else { throw CompanionError.mutationBusy }
        await acquireInspectionSlot(); setupReserved = true
        do { return try await authoritativeSetupPreview(setup) }
        catch { finishAccountSetup(); throw error }
    }
    func revalidateAccountSetup(_ expected: SetupPreview, includePreview: Bool = true) async throws {
        guard setupReserved, let setup = backend as? any AccountSetupBackend else { throw CompanionError.mutationBusy }
        if includePreview {
            let fresh = try await authoritativeSetupPreview(setup)
            guard fresh.context == expected.context, fresh.configurationRevision == expected.configurationRevision else { throw CompanionError.mutationBusy }
        } else {
            try await verifySetupDirect(expected.context)
            guard await setup.probeSetupPort(expected.context) == .empty else { throw CompanionError.mutationBusy }
        }
    }
    private func authoritativeSetupPreview(_ setup: any AccountSetupBackend) async throws -> SetupPreview {
        guard let selectedConfiguration, !backend.mutationRequiresReconciliation else { throw CompanionError.mutationBusy }
        let preview = try await setup.previewSetup(configPath: selectedConfiguration, browseHome: browseHome)
        guard preview.context.configPath == selectedConfiguration.path else { throw CompanionError.mutationBusy }
        try await verifySetupDirect(preview.context)
        guard await setup.probeSetupPort(preview.context) == .empty else { throw CompanionError.mutationBusy }
        let latest = try await setup.previewSetup(configPath: selectedConfiguration, browseHome: browseHome)
        guard latest.context == preview.context, latest.configurationRevision == preview.configurationRevision else { throw CompanionError.mutationBusy }
        return latest
    }
    private func verifySetupDirect(_ context: ActivationContext) async throws {
        guard setupReserved, ownedRouter == nil, !recoveryObligation, journal.pending == nil,
              selectedConfiguration?.path == context.configPath, await inspectInSlot(queryRoutingMode: false),
              !recoveryObligation, !backend.mutationRequiresReconciliation else { throw CompanionError.mutationBusy }
        if inspection?.configuration.state == "missing" {
            guard inspection?.context == nil, inspection?.provider.recoveryRequired == false else { throw CompanionError.mutationBusy }
        } else {
            guard matchingContext == context, cleanDirect(context), inspection?.provider.proxyReady == false else { throw CompanionError.mutationBusy }
        }
    }
    func markAccountSetupUncertain(_ operationID: String) {
        uncertainSetupOperationID = operationID; mutationRequiresReconciliation = true
    }
    func completeAccountSetup(operationID: String) {
        if uncertainSetupOperationID == operationID, !backend.mutationRequiresReconciliation { uncertainSetupOperationID = nil }
        finishAccountSetup()
    }
    public func finishAccountSetup() {
        mutationRequiresReconciliation = backend.mutationRequiresReconciliation || uncertainSetupOperationID != nil || configurationLockRequiresResolution
        if setupReserved { setupReserved = false; releaseInspectionSlot(); finish() }
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
            assignmentEditor = nil; selectedAssignment = nil; selectedAssignmentProjectID = nil
            assignmentInspection = nil; assignmentBaseline = nil; assignmentChild = nil; assignmentPortEmpty = false
            loadSetupEvidence()
            projectRoutingStatus = .notRunning; routingModeError = nil
            dependencyContext = nil; hasDepended = false; desktopConfirmation = .unknown
            await inspectNow()
        } catch { self.error = safe(error) }
    }

    public func selectNode(_ path: URL) async {
        guard canSelectNode, begin() else { return }
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
        guard !assignmentRequiresReconciliation, begin() else { return }
        defer { finish() }
        guard await inspectNow() else { return }
        guard !backend.mutationRequiresReconciliation, inspection?.configuration.setupState == "ready", let context = matchingContext, ownedRouter == nil, inspection?.provider.proxyReady == false else { reject(); return }
        do {
            let directSession = !hasDepended && !recoveryObligation && cleanDirect(context)
            let child: OwnedRouter
            // Startup probes through the backend too, so keep background inspection out until it returns.
            await acquireInspectionSlot()
            do {
                child = try await backend.start(configPath: URL(fileURLWithPath: context.configPath))
                releaseInspectionSlot()
            } catch {
                releaseInspectionSlot()
                throw error
            }
            // A handle from a readiness timeout is still owned, but never implies readiness.
            ownedRouter = child
            discardRoutingMode()
            directOnlyChild = directSession && child.context == context ? child.id : nil
            if !child.process.isRunning { childExited(child.id) }
            await inspectNow(queryRoutingMode: true)
        } catch { self.error = safe(error) }
    }

    public func activate() async {
        guard !assignmentRequiresReconciliation, begin() else { return }
        defer { finish() }
        guard await inspectNow() else { return }
        guard !backend.mutationRequiresReconciliation, inspection?.configuration.setupState == "ready", let context = matchingContext, let child = ownedRouter, child.process.isRunning,
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
    public func setProjectRouting(_ mode: ProjectRoutingMode) async {
        // Uncertainty requires a separate fresh query, never an automatic mutation retry.
        guard canSetProjectRouting, begin() else { return }
        defer { finish() }
        await acquireInspectionSlot()
        defer { releaseInspectionSlot() }
        guard await inspectInSlot(queryRoutingMode: false),
              !mutationRequiresReconciliation, !backend.mutationRequiresReconciliation,
              case .known = projectRoutingStatus, let child = routingModeChild else { return }
        let requestGeneration = generation, requestSequence = inspectionSequence
        do {
            let applied = try await backend.setRoutingMode(mode, for: child)
            guard modeEvidenceIsCurrent(child, generation: requestGeneration, sequence: requestSequence) else { return }
            guard applied == mode else { throw CompanionError.routingModeUnavailable }
            projectRoutingStatus = .known(applied); routingModeError = nil
        } catch {
            guard modeEvidenceIsCurrent(child, generation: requestGeneration, sequence: requestSequence) else { return }
            routingModeFailed(error)
        }
    }

    public func canEditAssignment(_ project: Inspection.Entry) -> Bool {
        guard usable, !busy, !assignmentRequiresReconciliation, !mutationRequiresReconciliation, assignmentStorageSafe,
              !backend.mutationRequiresReconciliation, !configurationLockRequiresResolution, !setupReserved,
              uncertainSetupOperationID == nil, let value = assignmentInspection, let state = assignmentBaseline,
              value.catalog.entries.contains(where: { $0.id == project.id && $0.name == project.name }),
              AssignmentWire.uuid(project.id),
              assignmentEvidenceMatches(state, value: value), assignmentProviderSafe(value),
              value.configuration.mode == "accounts", value.configuration.setupState == "ready",
              value.configuration.accounts != nil, value.catalog.state == "ready" else { return false }
        if let child = ownedRouter {
            return assignmentChild === child && child.process.isRunning && value.provider.proxyReady == true &&
                state.savedRevision == state.runningRevision && state.savedIdentity == state.runningIdentity &&
                state.savedFingerprint == state.runningFingerprint
        }
        return assignmentChild == nil && assignmentPortEmpty && value.provider.proxyReady == false &&
            !recoveryObligation && journal.pending == nil && state.runningRevision == nil
    }

    public func loadAssignment(projectID: String) async -> AssignmentState? {
        guard AssignmentWire.uuid(projectID), !busy,
              pendingAssignment == nil || pendingAssignment?.change.projectId == projectID, begin() else { return nil }
        defer { finish() }
        await acquireInspectionSlot()
        defer { releaseInspectionSlot() }
        selectedAssignmentProjectID = projectID
        guard await inspectInSlot(queryRoutingMode: false) else { return nil }
        guard let state = assignmentBaseline, state.projectId == projectID, let value = assignmentInspection else { return nil }
        assignmentEditor = .init(projectID: projectID, state: state, inspection: value, child: ownedRouter)
        return state
    }

    public func saveAssignment(projectID: String, accountID: String?) async {
        guard let project = assignmentInspection?.catalog.entries.first(where: { $0.id == projectID }),
              canEditAssignment(project), accountID.map(AssignmentWire.uuid) ?? true,
              accountID == nil || assignmentInspection?.configuration.accounts?.contains(where: { $0.id == accountID }) == true,
              let currentState = assignmentBaseline, let currentInspection = assignmentInspection else { return }
        let editor = assignmentEditor?.projectID == projectID ? assignmentEditor : nil
        guard editor.map({ sameAssignmentChild($0.child) }) ?? true else {
            assignmentError = CompanionError.assignmentConflict.rawValue; return
        }
        let displayed = editor?.state ?? currentState
        let displayedInspection = editor?.inspection ?? currentInspection
        let child = ownedRouter
        guard begin() else { return }
        let requestGeneration = generation
        defer { finish() }
        await acquireInspectionSlot()
        defer { releaseInspectionSlot() }
        selectedAssignmentProjectID = projectID
        guard await inspectInSlot(queryRoutingMode: false), requestGeneration == generation, sameAssignmentChild(child),
              let value = assignmentInspection, let state = assignmentBaseline,
              displayed.context == state.context, displayed.savedRevision == state.savedRevision, displayed.savedIdentity == state.savedIdentity,
              displayed.catalogRevision == state.catalogRevision, displayedInspection.recoveryRevision == value.recoveryRevision,
              displayedInspection.configuration == value.configuration,
              assignmentProviderSafe(value), assignmentEvidenceMatches(state, value: value),
              !assignmentRequiresReconciliation, !mutationRequiresReconciliation, !backend.mutationRequiresReconciliation, assignmentStorageSafe,
              let context = matchingContext, let savedRevision = state.savedRevision, let identity = state.savedIdentity,
              let catalogRevision = state.catalogRevision, let assignments = backend as? any ProjectAssignmentBackend else {
            assignmentError = CompanionError.assignmentConflict.rawValue; return
        }
        if let child {
            guard assignmentChild === child, child.process.isRunning, value.provider.proxyReady == true,
                  state.savedRevision == state.runningRevision, state.savedIdentity == state.runningIdentity,
                  state.savedFingerprint == state.runningFingerprint else { assignmentError = CompanionError.assignmentConflict.rawValue; return }
        } else {
            guard assignmentPortEmpty, !recoveryObligation, journal.pending == nil, cleanDirect(context),
                  value.provider.proxyReady == false, await assignments.probeAssignmentPort(context) == .empty,
                  ownedRouter == nil else { assignmentError = CompanionError.assignmentUnavailable.rawValue; return }
        }
        let change = AssignmentChange(configPath: context.configPath, expectedContext: context, expectedSavedRevision: savedRevision,
            expectedConfigurationIdentity: identity, expectedRunningRevision: child == nil ? nil : state.runningRevision,
            expectedCatalogRevision: catalogRevision, operationId: UUID().uuidString, projectId: projectID, accountId: accountID)
        let pending = PendingAssignment(change: change, before: value, child: child, confirmation: desktopConfirmation)
        pendingAssignment = pending; pendingAssignmentOperationID = change.operationId
        do {
            let commit: AssignmentCommit
            if let child { commit = try await assignments.applyAssignment(change, to: child) }
            else { commit = try await assignments.saveStoppedAssignment(change) }
            guard generation == requestGeneration, sameAssignmentChild(child) else { throw CompanionError.assignmentUncertain }
            guard await inspectAssignmentTransition(pending, commit: commit, allowSettlement: true) else {
                throw CompanionError.assignmentUncertain
            }
        } catch {
            // A rejected operation cannot have replaced the source. Every other
            // post-dispatch failure retains its exact operation for observation.
            let rejected = error as? CompanionError == .assignmentConflict || error as? CompanionError == .assignmentUnavailable
            if rejected {
                pendingAssignment = nil; pendingAssignmentOperationID = nil
                let message = safe(error)
                _ = await inspectInSlot(queryRoutingMode: false)
                assignmentError = message
            } else {
                assignmentRequiresReconciliation = true; assignmentStatus = .uncertain
                assignmentError = CompanionError.assignmentUncertain.rawValue
                // Collect current evidence without treating the failed call as a retry or success.
                _ = await inspectAssignmentTransition(pending, commit: nil, allowSettlement: false)
            }
        }
    }

    private func sameAssignmentChild(_ child: OwnedRouter?) -> Bool {
        if let child { return ownedRouter === child && child.process.isRunning }
        return ownedRouter == nil
    }
    private func assignmentProviderSafe(_ value: Inspection) -> Bool {
        guard !value.provider.recoveryRequired else { return false }
        if value.provider.state == "direct" { return ["none", "restored"].contains(value.provider.recordPhase) }
        return value.provider.state == "router" && value.provider.recordPhase == "active" && recoveryObligation &&
            journal.pending?.context == value.context && dependencyContext == value.context
    }
    private func assignmentEvidenceMatches(_ state: AssignmentState, value: Inspection) -> Bool {
        state.savedState == "ready" && state.context == value.context && state.context.configPath == selectedConfiguration?.path &&
            state.savedRevision != nil && state.savedIdentity != nil && state.savedFingerprint != nil && state.catalogRevision != nil &&
            state.savedRevision == value.configurationRevision && state.savedIdentity == value.configurationIdentity &&
            state.savedFingerprint == value.routingFingerprint && state.catalogRevision == value.catalog.revision && value.recoveryRevision != nil
    }
    private func assignmentStorageIsSafe() -> Bool {
        guard let selectedConfiguration else { return false }
        let directory = selectedConfiguration.deletingLastPathComponent()
        var hasEvidence = false
        for name in [".activation.lock", "account-setup.json"] {
            var info = stat()
            if lstat(directory.appendingPathComponent(name).path, &info) == 0 { hasEvidence = true }
            else if errno != ENOENT { return false }
        }
        guard hasEvidence else { return true }
        do {
            let transaction = SetupTransactionStore(configPath: selectedConfiguration)
            guard try transaction.inspectLease() == .absent else { return false }
            return try transaction.load().map { $0.phase == .complete } ?? true
        } catch { return false }
    }
    private func readAssignmentEvidence(_ value: Inspection) async -> AssignmentState? {
        // A temporary provider/setup lease removes editing authority. Observing
        // it must not import another operation's lease as relaunch uncertainty.
        assignmentStorageSafe = assignmentStorageIsSafe()
        assignmentPortEmpty = false
        guard let assignments = backend as? any ProjectAssignmentBackend, let context = value.context,
              context.configPath == selectedConfiguration?.path else { return nil }
        // An unselected stopped read supplies source/port proof for editor
        // eligibility, including configured-only rows, without selecting a sheet.
        let requestedProjectID = selectedAssignmentProjectID ?? (ownedRouter == nil
            ? value.catalog.entries.first(where: { AssignmentWire.uuid($0.id) })?.id : nil)
        do {
            let state: AssignmentState
            if let child = ownedRouter, child.process.isRunning, child.context == context {
                // Pipe ownership, rather than matching HTTP health, authorizes observation.
                state = try await assignments.readAssignment(child, projectID: requestedProjectID,
                    operationID: pendingAssignmentOperationID)
                guard ownedRouter === child, child.process.isRunning else { return nil }
                assignmentChild = child
            } else {
                guard ownedRouter == nil, let projectID = requestedProjectID else { return nil }
                state = try await assignments.readStoppedAssignment(context: context, projectID: projectID,
                    operationID: pendingAssignmentOperationID)
                guard ownedRouter == nil else { return nil }
                assignmentChild = nil
                assignmentPortEmpty = await assignments.probeAssignmentPort(context) == .empty
                guard ownedRouter == nil else { return nil }
            }
            guard state.context == context, state.projectId == requestedProjectID else { return nil }
            return state
        } catch {
            assignmentError = safe(error)
            return nil
        }
    }
    private func installAssignmentEvidence(_ state: AssignmentState?, value: Inspection) {
        assignmentInspection = value; assignmentBaseline = state
        if let state, let projectID = selectedAssignmentProjectID, state.projectId == projectID { selectedAssignment = state }
        if !assignmentRequiresReconciliation {
            assignmentStatus = state.map {
                let runtimeMatches = ownedRouter == nil || ($0.savedRevision == $0.runningRevision &&
                    $0.savedIdentity == $0.runningIdentity && $0.savedFingerprint == $0.runningFingerprint)
                return assignmentEvidenceMatches($0, value: value) && runtimeMatches ? .ready : .diverged
            } ?? .unavailable
            if assignmentStatus == .ready { assignmentError = nil }
            else if assignmentStatus == .diverged { assignmentError = CompanionError.assignmentConflict.rawValue }
        }
    }
    private func continuity(_ pending: PendingAssignment, value: Inspection, state: AssignmentState, commit: AssignmentCommit?) -> Bool {
        let change = pending.change
        guard sameAssignmentChild(pending.child), state.projectId == change.projectId,
              assignmentStorageSafe, !configurationLockRequiresResolution, uncertainSetupOperationID == nil, !backend.mutationRequiresReconciliation,
              value.context == pending.before.context,
              value.configuration == pending.before.configuration, value.catalog.revision == pending.before.catalog.revision,
              value.recoveryRevision != nil, value.recoveryRevision == pending.before.recoveryRevision,
              value.provider == pending.before.provider, assignmentProviderSafe(value), assignmentEvidenceMatches(state, value: value) else { return false }
        let candidateRevision: String, candidateIdentity: String
        if let commit {
            guard commit.context == change.expectedContext, commit.operationId == change.operationId, commit.projectId == change.projectId,
                  commit.beforeRevision == change.expectedSavedRevision, commit.beforeIdentity == change.expectedConfigurationIdentity,
                  commit.candidateRevision == commit.savedRevision, commit.candidateIdentity == commit.savedIdentity,
                  state.savedAssignment == commit.after,
                  pending.child == nil || state.runningAssignment == commit.after,
                  change.accountId.map({ commit.after.kind == "override" && commit.after.account?.id == $0 }) ?? (commit.after.kind != "override") else { return false }
            candidateRevision = commit.candidateRevision; candidateIdentity = commit.candidateIdentity
            if pending.child != nil {
                guard commit.runningRevision == candidateRevision, commit.runningIdentity == candidateIdentity,
                      commit.runningFingerprint == state.runningFingerprint else { return false }
            }
        } else if let intent = state.intent {
            guard intent.operationId == change.operationId, intent.projectId == change.projectId, intent.accountId == change.accountId,
                  intent.context == change.expectedContext, intent.beforeRevision == change.expectedSavedRevision,
                  intent.beforeIdentity == change.expectedConfigurationIdentity else { return false }
            candidateRevision = intent.candidateRevision; candidateIdentity = intent.candidateIdentity
        } else {
            // A later exact before-pair observation establishes no persisted transition.
            candidateRevision = change.expectedSavedRevision; candidateIdentity = change.expectedConfigurationIdentity
        }
        guard state.savedRevision == candidateRevision, state.savedIdentity == candidateIdentity else { return false }
        if pending.child != nil {
            return value.provider.proxyReady == true && state.runningRevision == candidateRevision &&
                state.runningIdentity == candidateIdentity && state.runningFingerprint == state.savedFingerprint
        }
        return state.runningRevision == nil && ownedRouter == nil
    }
    private func inspectAssignmentTransition(_ pending: PendingAssignment, commit: AssignmentCommit?, allowSettlement: Bool) async -> Bool {
        inspectionSequence &+= 1
        let sequence = inspectionSequence, currentGeneration = generation
        do {
            let value = try await backend.inspect(configPath: selectedConfiguration, browseHome: browseHome)
            let state = await readAssignmentEvidence(value)
            guard sequence == inspectionSequence, currentGeneration == generation else { return false }
            let verified = allowSettlement && state.map { continuity(pending, value: value, state: $0, commit: commit) } == true
            reconcile(value, preservingAssignmentConfirmation: verified && desktopConfirmation == pending.confirmation)
            installAssignmentEvidence(state, value: value)
            if verified {
                pendingAssignment = nil; pendingAssignmentOperationID = nil
                assignmentRequiresReconciliation = false; assignmentStatus = .ready; assignmentError = nil
                if assignmentEditor?.projectID == pending.change.projectId, let state {
                    assignmentEditor = .init(projectID: pending.change.projectId, state: state, inspection: value, child: ownedRouter)
                }
            } else {
                assignmentRequiresReconciliation = true
                let diverged = state.map {
                    $0.savedState == "conflict" || ($0.savedState == "ready" &&
                        (!AssignmentWire.reconciles($0, change: pending.change, live: pending.child != nil) ||
                         value.context != pending.before.context || value.recoveryRevision != pending.before.recoveryRevision ||
                         value.provider.state != pending.before.provider.state || value.provider.recordPhase != pending.before.provider.recordPhase))
                } ?? false
                assignmentStatus = diverged ? .diverged : .uncertain
                assignmentError = CompanionError.assignmentUncertain.rawValue
            }
            return verified
        } catch {
            inspectionFailed(error)
            assignmentRequiresReconciliation = true; assignmentStatus = .uncertain
            assignmentError = CompanionError.assignmentUncertain.rawValue
            return false
        }
    }

    public func stop() async {
        guard begin() else { return }
        defer { finish() }
        await stopOwnedChild()
    }
    public func requestQuit() async {
        guard !secondInstance && !initializationFailed else { quitRequested = true; return }
        guard begin() else { return }
        defer { finish() }
        let inspected: Bool
        if ownedRouter != nil { await stopOwnedChild(); inspected = false }
        else { inspected = await inspectNow() }
        guard !mutationRequiresReconciliation, !backend.mutationRequiresReconciliation, !assignmentRequiresReconciliation, ownedRouter == nil else { reject(); return }
        let normalPermission = !recoveryObligation && journal.pending == nil
        guard normalPermission || (inspected && authorizeIdleDirectQuit()) else { reject(); return }
        quitRequested = true
    }

    private var hasIdleDirectQuitContext: Bool {
        guard usable, ownedRouter == nil, !mutationRequiresReconciliation, !backend.mutationRequiresReconciliation,
              recoveryObligation, let pending = journal.pending, let context = matchingContext,
              pending.context == context, dependencyContext == context, journal.selectedConfigurationPath == context.configPath,
              let revision, !revision.isEmpty else { return false }
        return cleanDirect(context)
    }
    private func authorizeIdleDirectQuit() -> Bool {
        // A memory-only obligation cannot be discarded, even when fresh provider evidence is direct.
        if recoveryObligation && journal.pending == nil {
            idleQuitJournalUnavailable = true; self.error = CompanionError.privateState.rawValue
            return false
        }
        guard hasIdleDirectQuitContext else { return false }
        do {
            guard try store.readExisting() == journal else { throw CompanionError.privateState }
            idleQuitAuthorized = true
            return true
        } catch {
            idleQuitJournalUnavailable = true; self.error = CompanionError.privateState.rawValue
            return false
        }
    }

    private var matchingContext: ActivationContext? {
        guard let value = inspection, value.configuration.state == "valid", let context = value.context,
              context.configPath == selectedConfiguration?.path, value.configuration.path == context.configPath else { return nil }
        if recoveryObligation, let dependencyContext, context != dependencyContext { return nil }
        if let child = ownedRouter, context != child.context { return nil }
        return context
    }
    private var routingModeChild: OwnedRouter? {
        guard let child = ownedRouter, child.process.isRunning, matchingContext == child.context,
              inspection?.provider.proxyReady == true, revision != nil else { return nil }
        return child
    }
    private func modeEvidenceIsCurrent(_ child: OwnedRouter, generation: UInt64, sequence: UInt64) -> Bool {
        self.generation == generation && inspectionSequence == sequence && routingModeChild === child
    }
    private func discardRoutingMode() {
        if ownedRouter == nil && !needsManualListenerCleanup {
            projectRoutingStatus = .notRunning; routingModeError = nil
        } else {
            projectRoutingStatus = .unavailable; routingModeError = CompanionError.routingModeUnavailable.rawValue
        }
    }
    private func routingModeFailed(_ failure: Error) {
        let uncertain = (failure as? CompanionError) == .routingModeUncertain
        projectRoutingStatus = uncertain ? .uncertain : .unavailable
        routingModeError = uncertain ? CompanionError.routingModeUncertain.rawValue : CompanionError.routingModeUnavailable.rawValue
    }
    private func reconcileRoutingMode(generation: UInt64, sequence: UInt64, query: Bool) async {
        guard let child = routingModeChild else { discardRoutingMode(); return }
        guard query, !backend.mutationRequiresReconciliation else { return }
        do {
            let mode = try await backend.readRoutingMode(child)
            guard modeEvidenceIsCurrent(child, generation: generation, sequence: sequence) else { return }
            projectRoutingStatus = .known(mode); routingModeError = nil
        } catch {
            guard modeEvidenceIsCurrent(child, generation: generation, sequence: sequence) else { return }
            routingModeFailed(error)
        }
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
        guard usable, !busy, uncertainSetupOperationID == nil, !configurationLockRequiresResolution else { if !busy { reject() }; return false }
        busy = true; error = nil; generation &+= 1; quitRequested = false
        idleQuitAuthorized = false; idleQuitJournalUnavailable = false
        return true
    }
    private func finish() { generation &+= 1; busy = false }
    private func reject() { if error == nil { error = "The action is unavailable until the current context is reconciled." } }
    private func safe(_ error: Error) -> String { (error as? CompanionError)?.rawValue ?? CompanionError.commandFailed.rawValue }
    private func persist(_ value: CompanionJournal) throws {
        if value != journal { idleQuitAuthorized = false }
        try store.save(value); journal = value
    }
    private func setPending(_ context: ActivationContext, _ phase: CompanionJournal.Phase) throws {
        // Memory retains conservative authority even if persistence fails after a provider write.
        idleQuitAuthorized = false
        dependencyContext = context; recoveryObligation = true
        var next = journal; next.selectedConfigurationPath = context.configPath; next.pending = .init(context: context, phase: phase)
        try persist(next)
    }
    private func acquireInspectionSlot() async {
        if inspectionInFlight {
            await withCheckedContinuation { inspectionWaiters.append($0) }
        } else { inspectionInFlight = true }
    }
    private func releaseInspectionSlot() {
        if inspectionWaiters.isEmpty { inspectionInFlight = false }
        else { inspectionWaiters.removeFirst().resume() }
    }
    @discardableResult private func inspectNow(queryRoutingMode: Bool = false) async -> Bool {
        // Actions must inspect after prior work ends; a pre-action snapshot cannot authorize them.
        // Awaited guidance refreshes share the action/poll queue instead of returning through refresh coalescing.
        await acquireInspectionSlot()
        defer { releaseInspectionSlot() }
        return await inspectInSlot(queryRoutingMode: queryRoutingMode)
    }
    private func inspectInSlot(queryRoutingMode: Bool) async -> Bool {
        // Only a started inspection can produce newer evidence. A queued timer cannot supersede an action.
        inspectionSequence &+= 1
        let requestSequence = inspectionSequence
        let requestGeneration = generation
        defer { mutationRequiresReconciliation = backend.mutationRequiresReconciliation || uncertainSetupOperationID != nil || configurationLockRequiresResolution }
        do {
            let value = try await backend.inspect(configPath: selectedConfiguration, browseHome: browseHome)
            guard requestGeneration == generation, requestSequence == inspectionSequence else { return false }
            let state = await readAssignmentEvidence(value)
            guard requestGeneration == generation, requestSequence == inspectionSequence else { return false }
            var verified = false
            let priorConfirmation = pendingAssignment?.confirmation
            if let pending = pendingAssignment, let state {
                verified = continuity(pending, value: value, state: state, commit: nil)
                // Exact exited-child settlement proves saved persistence only. It
                // cannot preserve a confirmation from the previous live process.
                if !verified, let exitedChild = pending.child, !exitedChild.process.isRunning, ownedRouter == nil, state.runningRevision == nil,
                   assignmentEvidenceMatches(state, value: value), AssignmentWire.reconciles(state, change: pending.change, live: false) {
                    pendingAssignment = nil; pendingAssignmentOperationID = nil
                    assignmentRequiresReconciliation = false; assignmentError = nil
                } else if verified {
                    pendingAssignment = nil; pendingAssignmentOperationID = nil
                    assignmentRequiresReconciliation = false; assignmentError = nil
                }
            }
            reconcile(value, preservingAssignmentConfirmation: verified && desktopConfirmation == priorConfirmation)
            installAssignmentEvidence(state, value: value)
            // Mode reads share the disk slot, but recovery actions retain their own evidence authority.
            await reconcileRoutingMode(generation: requestGeneration, sequence: requestSequence, query: !busy || queryRoutingMode)
            guard requestGeneration == generation, requestSequence == inspectionSequence else { return false }
            return true
        } catch {
            guard requestGeneration == generation, requestSequence == inspectionSequence else { return false }
            inspectionFailed(error)
            return false
        }
    }
    private func inspectionFailed(_ failure: Error) {
        idleQuitAuthorized = false
        revision = nil
        assignmentInspection = nil; assignmentBaseline = nil; assignmentPortEmpty = false; assignmentStatus = assignmentRequiresReconciliation ? .uncertain : .unavailable
        if let value = inspection {
            inspection = Inspection(configuration: .init(state: "unavailable"), context: value.context,
                provider: .init(state: "unavailable", recoveryRequired: recoveryObligation, proxyReady: nil, recordPhase: "unavailable"),
                catalog: .init(state: "unavailable", entries: []))
        }
        invalidateConfirmation()
        discardRoutingMode()
        error = safe(failure)
    }
    private func reconcile(_ value: Inspection, preservingAssignmentConfirmation: Bool = false) {
        if revision != value.revision || inspection?.configuration != value.configuration ||
            inspection?.context != value.context || inspection?.provider != value.provider {
            idleQuitAuthorized = false
        }
        let compoundChanged = assignmentInspection.map { previous in
            (previous.configurationRevision != nil && previous.configurationRevision != value.configurationRevision) ||
            (previous.configurationIdentity != nil && previous.configurationIdentity != value.configurationIdentity) ||
            (previous.recoveryRevision != nil && previous.recoveryRevision != value.recoveryRevision)
        } ?? false
        let changed = (revision != nil && revision != value.revision) || compoundChanged
        let readinessLost = inspection?.provider.proxyReady == true && value.provider.proxyReady != true
        if stoppingID != nil, readinessLost { deferredReadinessLoss = true }
        revision = value.revision
        var presentation = value
        presentation.revision = nil; presentation.configurationRevision = nil; presentation.configurationIdentity = nil
        presentation.routingFingerprint = nil; presentation.recoveryRevision = nil; presentation.catalog.revision = nil
        inspection = presentation
        if (!preservingAssignmentConfirmation && (changed || (readinessLost && stoppingID == nil))) || matchingContext == nil { invalidateConfirmation() }
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
        idleQuitAuthorized = false
        generation &+= 1; ownedRouter = nil; directOnlyChild = nil
        assignmentBaseline = nil; assignmentChild = nil; assignmentPortEmpty = false
        projectRoutingStatus = .notRunning; routingModeError = nil
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
        deferredReadinessLoss = false
        stoppingID = child.id
        defer {
            stoppingID = nil
            // A failed teardown has not consumed observed readiness loss.
            if deferredReadinessLoss, ownedRouter != nil { invalidateConfirmation() }
            deferredReadinessLoss = false
        }
        do {
            let outcome = try await backend.stop(child)
            lastStopOutcome = outcome
            if outcome.childExited && !child.process.isRunning {
                ownedRouter = nil; directOnlyChild = nil
                // The requested teardown consumed this readiness observation. The port result
                // remains independent; neither occupied nor unknown means matching readiness.
                inspection?.provider.proxyReady = nil
                projectRoutingStatus = outcome.portState == .occupied ? .unavailable : .notRunning
                routingModeError = outcome.portState == .occupied ? CompanionError.routingModeUnavailable.rawValue : nil
            }
            if !outcome.childExited || ownedRouter != nil { error = "The owned router has not been confirmed stopped." }
            else if outcome.portState == .occupied { error = "The owned router exited, but another listener remains. Manual cleanup is required." }
            else if outcome.portState == .unknown { error = "The owned router exited; the listener port could not be verified." }
        } catch { self.error = safe(error) }
    }
}
