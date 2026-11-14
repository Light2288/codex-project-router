import XCTest
import AppKit
import CompanionCore
@testable import CodexProjectRouter

@MainActor final class AccountSetupActionTests: XCTestCase {
    private func withSetup(_ body: (RouterController, AccountSetupController, AppAccountBackend) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("account-app-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { XCTFail("Synthetic account app cleanup failed: \(error)") }
        }
        let backend = AppAccountBackend(root: root), store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(.init(selectedConfigurationPath: backend.preview.context.configPath))
        let router = RouterController(backend: backend, store: store, browseHome: root)
        // No Keychain method is invoked: all saves here select existing synthetic references.
        let setup = AccountSetupController(router: router, backend: backend, keychain: KeychainStore(), browseHome: root)
        await router.refresh(); await setup.refresh()
        try await body(router, setup, backend)
    }
    func testAddingThroughFormPreservesDefaultAndBindingsWithoutActivation() async throws {
        try await withSetup { router, setup, backend in
            var form = AccountSetupForm(preview: try XCTUnwrap(setup.preview), intent: .add)
            form.accounts[0].displayName = "Work"; form.accounts[0].upstreamBaseUrl = "https://work.example/api"
            form.accounts[0].credential = .init(keychainPath: "/synthetic/items.keychain-db", service: "Work", account: "Work")
            var entry = AccountSecretEntry(); entry.value = "SYNTHETIC_UNUSED"
            let submission = try form.prepareSave(entry: &entry)
            XCTAssertEqual(entry.value, ""); XCTAssertNil(submission.secret)
            let bindings = backend.preview.routeAccounts
            await setup.save(submission.change, creatingCredentialFor: submission.accountID, secret: submission.secret)
            XCTAssertEqual(setup.state, .saved)
            XCTAssertEqual(setup.preview?.defaultAccountId, "11111111-1111-4111-8111-111111111111")
            XCTAssertEqual(setup.preview?.routeAccounts, bindings)
            XCTAssertEqual(setup.preview?.accounts.map(\.displayName), ["Personal", "Work"])
            XCTAssertNil(router.ownedRouter); XCTAssertEqual(backend.starts, 0); XCTAssertEqual(backend.activations, 0)
            XCTAssertEqual(router.desktopConfirmation, .unknown)
            XCTAssertTrue(AccountSetupPresentation(state: setup.state, routerCanSave: router.canBeginAccountSetup, createdItem: false).guidance.contains("unverified"))
        }
    }
    func testOpeningFormWhileRunningIsReadOnlyAndSaveExplainsStop() async throws {
        try await withSetup { router, setup, backend in
            await router.start()
            let saved = backend.preview
            await setup.refresh()
            XCTAssertEqual(setup.state, .ready)
            let presentation = AccountSetupPresentation(state: setup.state, routerCanSave: router.canBeginAccountSetup, createdItem: false)
            XCTAssertFalse(presentation.canSave); XCTAssertTrue(presentation.guidance.contains("Stop"))
            XCTAssertEqual(backend.preview, saved); XCTAssertEqual(backend.commits, 0); XCTAssertEqual(backend.starts, 1)
            XCTAssertEqual(backend.activations, 0)
            let delegate = RouterAppDelegate(controller: router, accountSetup: setup)
            XCTAssertTrue(delegate.windowShouldClose(NSWindow()), "Read-only browsing preserves ordinary Controls close")
            XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
        }
    }
    func testSavingKeepsControlsAndSheetAvailableUntilOutcome() async throws {
        try await withSetup { router, setup, backend in
            var policies: [NSApplication.ActivationPolicy] = []
            let delegate = RouterAppDelegate(controller: router, accountSetup: setup,
                setActivationPolicy: { policies.append($0); return true })
            defer {
                delegate.controlsWindow?.close()
                delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
            delegate.openControls()
            let window = try XCTUnwrap(delegate.controlsWindow)
            await router.refreshAndWait()
            backend.holdCommit = true
            var form = AccountSetupForm(preview: try XCTUnwrap(setup.preview), intent: .setDefault)
            form.defaultSelection = AccountSetupForm.noDefault
            let change = try form.change()
            let saving = Task { await setup.save(change) }
            await backend.waitForCommit()
            XCTAssertEqual(setup.state, .saving); XCTAssertFalse(setup.canDismiss)
            XCTAssertFalse(delegate.windowShouldClose(window))
            window.performClose(nil)
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(policies, [.regular])
            XCTAssertFalse(AccountSetupPresentation(state: setup.state, routerCanSave: router.canBeginAccountSetup, createdItem: false).canSave)
            XCTAssertEqual(QuitGuidance.current(for: router).destination, .status)
            backend.releaseCommit(); await saving.value
            XCTAssertEqual(setup.state, .saved); XCTAssertTrue(setup.canDismiss)
            XCTAssertTrue(delegate.windowShouldClose(window))
            window.performClose(nil)
            XCTAssertFalse(window.isVisible)
            XCTAssertEqual(policies, [.regular, .accessory])
            XCTAssertNil(setup.preview?.defaultAccountId); XCTAssertFalse(router.canStart)
            XCTAssertEqual(backend.activations, 0); XCTAssertEqual(backend.starts, 0)
        }
    }
}

@MainActor private final class AppAccountBackend: CompanionBackend, AccountSetupBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false
    var setupHelperIsRunning = false
    var uncertainSetupOperationID: String?
    var preview: SetupPreview
    var snapshot: Inspection
    var starts = 0, activations = 0, commits = 0
    var holdCommit = false
    private var commitWaiter: CheckedContinuation<Void, Never>?
    private var commitStarted: CheckedContinuation<Void, Never>?
    private var isCommitting = false
    init(root: URL) {
        let context = ActivationContext(configPath: root.appendingPathComponent("config.json").path, codexHome: root.appendingPathComponent("codex").path, providerId: "synthetic", listenPort: 43123)
        let account = SetupPreview.Account(id: "11111111-1111-4111-8111-111111111111", displayName: "Personal", upstreamBaseUrl: "https://personal.example/api", credential: .init(keychainPath: "/synthetic/items.keychain-db", service: "Personal", account: "Personal"), sourceAlias: nil)
        preview = .init(context: context, configurationRevision: "initial-synthetic-revision", setupState: "ready", sourceKind: "accounts", accounts: [account], routeAccounts: ["saved": account.id, "legacy": nil], incomingCredential: .init(keychainPath: "/synthetic/items.keychain-db", service: "Incoming", account: "Desktop"), defaultAccountId: account.id, incomingHint: nil, originalDirect: account)
        snapshot = .init(configuration: .init(state: "valid", path: context.configPath, mode: "accounts", setupState: "ready", defaultAccount: .init(id: account.id, displayName: account.displayName)), context: context, revision: "operational-revision", provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"), catalog: .init(state: "ready", entries: [.init(id: "saved-id", name: "Saved", routeAlias: "saved", routeState: "mapped"), .init(id: "missing-id", name: "", routeAlias: "legacy", routeState: "catalog_missing")]))
    }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection { snapshot }
    func previewSetup(configPath: URL, browseHome: URL) async throws -> SetupPreview { preview }
    func commitSetup(_ change: SetupChange, context: ActivationContext, revision: String, operationID: String) async throws -> SetupCommitResult {
        commits += 1; isCommitting = true; commitStarted?.resume(); commitStarted = nil
        if holdCommit { await withCheckedContinuation { commitWaiter = $0 } }
        guard context == preview.context, revision == preview.configurationRevision else { throw CompanionError.protocolFailure }
        switch change {
        case let .addAccount(account, incoming):
            preview.accounts.append(.init(id: account.id, displayName: account.displayName, upstreamBaseUrl: account.upstreamBaseUrl, credential: account.credential, sourceAlias: nil))
            if let incoming { preview.incomingCredential = incoming }
        case let .setDefault(id, incoming):
            preview.defaultAccountId = id; if let incoming { preview.incomingCredential = incoming }
        default: throw CompanionError.protocolFailure
        }
        preview.configurationRevision = "saved-synthetic-revision"; preview.setupState = preview.defaultAccountId == nil ? "required" : "ready"
        snapshot.configuration.setupState = preview.setupState
        snapshot.configuration.defaultAccount = preview.accounts.first(where: { $0.id == preview.defaultAccountId }).map { .init(id: $0.id, displayName: $0.displayName) }
        return .init(context: context, operationId: operationID, setupState: preview.setupState, configurationRevision: preview.configurationRevision, checkpointPath: nil, changed: true)
    }
    func waitForCommit() async { if !isCommitting { await withCheckedContinuation { commitStarted = $0 } } }
    func releaseCommit() { commitWaiter?.resume(); commitWaiter = nil }
    func probeSetupPort(_ context: ActivationContext) async -> StopOutcome.PortState { .empty }
    func finishSetupReconciliation(operationID: String) throws { throw CompanionError.mutationUncertain }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ validatedPath: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter { starts += 1; snapshot.provider.proxyReady = true; return .init(process: AppAccountProcess(), context: preview.context) }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult { activations += 1; throw CompanionError.commandFailed }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode { .off }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode { mode }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome { throw CompanionError.unownedChild }
}
private final class AppAccountProcess: Process, @unchecked Sendable {
    override var isRunning: Bool { true }
}
