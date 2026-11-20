import XCTest
import Security
@testable import CompanionCore

@MainActor final class AccountSetupControllerTests: XCTestCase {
    var root: URL!, context: ActivationContext!, backend: SetupBackendFixture!, router: RouterController!, setup: AccountSetupController!
    var native: FakeKeychainSecurity!, keychain: KeychainStore!, account: AccountRecord!
    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("setup-controller-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        context = ActivationContext(configPath: root.appendingPathComponent("router.json").path, codexHome: root.appendingPathComponent("codex").path, providerId: "synthetic", listenPort: 43123)
        backend = SetupBackendFixture(context: context)
        let store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(.init(selectedConfigurationPath: context.configPath))
        router = RouterController(backend: backend, store: store, browseHome: URL(fileURLWithPath: context.codexHome))
        native = FakeKeychainSecurity(); keychain = KeychainStore(security: native, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        account = AccountRecord(id: "22222222-2222-4222-8222-222222222222", displayName: "New", upstreamBaseUrl: "https://EXAMPLE.invalid/api/", credential: .init(keychainPath: "/private/synthetic.keychain-db", service: "synthetic", account: "new"))
        native.rows = [[kSecAttrService as String: account.credential.service, kSecAttrAccount as String: account.credential.account]]
        setup = AccountSetupController(router: router, backend: backend, keychain: keychain, browseHome: URL(fileURLWithPath: context.codexHome))
        await router.refresh(); await setup.refresh()
    }
    override func tearDown() async throws { setup = nil; router = nil; backend = nil; keychain = nil; native = nil; try FileManager.default.removeItem(at: root) }
    var change: SetupChange { .addAccount(account: account) }

    func testCredentialBrowsingReturnsOmissionsWithoutMutation() async throws {
        let before = try XCTUnwrap(setup.preview)
        native.rows.append([:])
        let listing = try await setup.listCredentials()
        XCTAssertEqual(listing.references, [account.credential])
        XCTAssertEqual(listing.omittedItemCount, 1)
        XCTAssertEqual(setup.preview, before); XCTAssertEqual(setup.state, .ready)
        XCTAssertEqual(backend.commits, 0); XCTAssertEqual(backend.starts, 0); XCTAssertTrue(native.added.isEmpty)
        XCTAssertNil(try SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)).load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: context.configPath))
    }
    func testIncomingSuggestionRejectsMalformedExactEvidence() async throws {
        backend.preview.incomingHint = .init(service: account.credential.service, account: account.credential.account)
        await setup.refresh()
        native.rows = [[:]]
        do { _ = try await setup.suggestedIncomingCredential(); XCTFail("Suggestions cannot omit unsupported exact evidence") }
        catch { XCTAssertEqual(error as? KeychainError, .unsupported) }
        XCTAssertEqual(backend.commits, 0); XCTAssertTrue(native.added.isEmpty)
    }
    func testRecoveryMalformedMetadataRetainsReceiptAndBlocksRetry() async throws {
        let record = AccountRecord(id: account.id, displayName: account.displayName, upstreamBaseUrl: "https://example.invalid/api", credential: account.credential)
        let receipt = SetupReceipt(operationId: UUID().uuidString, account: record, context: context)
        let transaction = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try transaction.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        let lock = root.appendingPathComponent(".activation.lock")
        let lockBytes = try Data(contentsOf: lock)
        native.rows = [[:]]
        await setup.refresh()
        XCTAssertEqual(setup.state, .recoveryRequired)
        XCTAssertNil(setup.observedCreatedItem); XCTAssertNotNil(setup.error)
        XCTAssertEqual(try transaction.load(), receipt)
        XCTAssertEqual(try Data(contentsOf: lock), lockBytes)
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC_NOT_CREATED"))
        XCTAssertEqual(backend.commits, 0); XCTAssertTrue(native.added.isEmpty)
        XCTAssertEqual(try transaction.load(), receipt)
    }

    func testInitialInspectionAndLeaseChecksAreFreshAndSerialized() async throws {
        let inspectionGate = SetupGate<Inspection>(); backend.inspectionGate = inspectionGate
        let secret = try KeychainSecret("SYNTHETIC")
        let save = Task { await setup.save(change, creatingCredentialFor: account.id, secret: secret) }
        await waitUntil { inspectionGate.waiting }
        backend.port = .occupied
        let refresh = Task { await router.refresh() }
        inspectionGate.release(backend.snapshot)
        await save.value; await refresh.value
        XCTAssertTrue(native.added.isEmpty); XCTAssertEqual(backend.commits, 0)
        XCTAssertFalse(router.busy)
    }
    func testListenerAppearingAfterLeaseAcquisitionRejectsBeforePreparation() async throws {
        backend.onPreview = { _ in if FileManager.default.fileExists(atPath: self.root.appendingPathComponent(".activation.lock").path) { self.backend.port = .occupied } }
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
        XCTAssertTrue(native.added.isEmpty); XCTAssertEqual(backend.commits, 0)
        XCTAssertNil(try SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)).load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
    }
    func testRelaunchMetadataOnlyLeaseRequiresManualResolutionWithoutReceipt() async throws {
        let transaction = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)), op = UUID().uuidString
        try transaction.begin(context: context, operationID: op, receipt: nil)
        setup = nil; router = nil
        let store = PrivateStore(directory: root.appendingPathComponent("companion"))
        router = RouterController(backend: backend, store: store, browseHome: URL(fileURLWithPath: context.codexHome))
        setup = AccountSetupController(router: router, backend: backend, keychain: keychain, browseHome: URL(fileURLWithPath: context.codexHome))
        await router.refresh(); await setup.refresh(); await router.requestQuit()
        XCTAssertEqual(router.uncertainSetupOperationID, op); XCTAssertFalse(router.quitRequested)
        XCTAssertEqual(setup.state, .recoveryRequired); XCTAssertNil(setup.pendingReceipt)
        XCTAssertTrue(native.added.isEmpty); XCTAssertEqual(backend.commits, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
    }
    func testRelaunchCannotQuitOrStartWithPreparedReceipt() async throws {
        let a = AccountRecord(id: account.id, displayName: account.displayName, upstreamBaseUrl: "https://example.invalid/api", credential: account.credential)
        let receipt = SetupReceipt(operationId: UUID().uuidString, account: a, context: context)
        let transaction = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try transaction.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        setup = nil; router = nil
        let store = PrivateStore(directory: root.appendingPathComponent("companion"))
        router = RouterController(backend: backend, store: store, browseHome: URL(fileURLWithPath: context.codexHome))
        await router.refresh(); await router.start(); await router.requestQuit()
        XCTAssertNotNil(router.uncertainSetupOperationID); XCTAssertFalse(router.canQuit); XCTAssertFalse(router.quitRequested)
        XCTAssertEqual(backend.starts, 0); XCTAssertTrue(native.added.isEmpty)
    }
    func testChangedFileDuringHeldInspectionRejectsBeforeNativeCreation() async throws {
        let gate = SetupGate<Inspection>()
        backend.onPreview = { _ in
            if FileManager.default.fileExists(atPath: self.root.appendingPathComponent(".activation.lock").path), !gate.waiting {
                self.backend.inspectionGate = gate
            }
        }
        let secret = try KeychainSecret("SYNTHETIC")
        let save = Task { await setup.save(change, creatingCredentialFor: account.id, secret: secret) }
        await waitUntil { gate.waiting }
        backend.preview.configurationRevision = String(repeating: "d", count: 64)
        gate.release(backend.snapshot); await save.value
        XCTAssertTrue(native.added.isEmpty); XCTAssertEqual(backend.commits, 0)
    }
    func testReplacedLeaseDuringFreshCheckRetainsEvidenceAndBlocksQuit() async throws {
        var replaced = false
        backend.onPreview = { _ in
            let lock = self.root.appendingPathComponent(".activation.lock")
            guard !replaced, FileManager.default.fileExists(atPath: lock.path) else { return }
            replaced = true
            try! FileManager.default.moveItem(at: lock, to: self.root.appendingPathComponent("held-lease"))
            try! Data("replacement".utf8).write(to: lock)
            try! FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: lock.path)
            self.backend.port = .occupied
        }
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
        XCTAssertTrue(native.added.isEmpty); XCTAssertNotNil(router.uncertainSetupOperationID)
        XCTAssertFalse(router.canQuit)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(".activation.lock")), "replacement")
    }
    func testSetupRequiresFreshStoppedDirectSettledContext() async throws {
        // Fresh port/direct/recovery evidence must veto a previously browsable form.
        for bad in ["listener", "router", "pending", "helper", "context"] {
            backend = SetupBackendFixture(context: context)
            let privateStore = PrivateStore(directory: root.appendingPathComponent("companion-\(bad)"))
            try privateStore.save(.init(selectedConfigurationPath: context.configPath))
            router = RouterController(backend: backend, store: privateStore, browseHome: URL(fileURLWithPath: context.codexHome))
            setup = AccountSetupController(router: router, backend: backend, keychain: keychain, browseHome: URL(fileURLWithPath: context.codexHome))
            await router.refresh(); await setup.refresh()
            backend.port = bad == "listener" ? .occupied : .empty
            backend.snapshot.provider.state = bad == "router" ? "router" : "direct"
            backend.snapshot.provider.recoveryRequired = bad == "pending"
            backend.mutationRequiresReconciliation = bad == "helper"
            if bad == "context" { backend.preview.context.codexHome += "-changed" }
            await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
            XCTAssertTrue(native.added.isEmpty, bad); XCTAssertEqual(backend.commits, 0, bad)
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path), bad)
        }
    }
    func testPreviewCannotAuthorizeLaterSave() async throws {
        backend.preview.configurationRevision = String(repeating: "b", count: 64)
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
        XCTAssertTrue(native.added.isEmpty); XCTAssertEqual(backend.commits, 0)
        XCTAssertNotNil(setup.error)
    }
    func testReceiptPrecedesNativeAndBlocksBackgroundReentry() async throws {
        let entered = expectation(description: "native"), gate = DispatchSemaphore(value: 0)
        native.onCreate = { entered.fulfill(); _ = gate.wait(timeout: .now() + 4) }
        let secret = try KeychainSecret("SYNTHETIC")
        let task = Task { await setup.save(change, creatingCredentialFor: account.id, secret: secret) }
        await fulfillment(of: [entered], timeout: 2)
        let receipt = try XCTUnwrap(SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)).load())
        XCTAssertEqual(receipt.phase, .prepared); XCTAssertEqual(receipt.account.upstreamBaseUrl, "https://example.invalid/api")
        XCTAssertTrue(router.busy); XCTAssertFalse(router.canStart); XCTAssertFalse(router.canQuit)
        await router.requestQuit(); await router.start()
        XCTAssertFalse(router.quitRequested); XCTAssertEqual(backend.starts, 0)
        let refresh = Task { await router.refresh() }
        gate.signal(); await task.value; await refresh.value
        XCTAssertEqual(setup.state, .saved); XCTAssertEqual(native.added.count, 1)
        XCTAssertEqual(try SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)).load()?.phase, .complete)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
        XCTAssertNotEqual(router.desktopConfirmation, .confirmedDirect)
    }
    func testContextChangeDuringNativeConsentRetainsCreatedButUnlinkedReceipt() async throws {
        let entered = expectation(description: "consent"), gate = DispatchSemaphore(value: 0)
        native.onCreate = { entered.fulfill(); _ = gate.wait(timeout: .now() + 4) }
        let secret = try KeychainSecret("SYNTHETIC")
        let save = Task { await setup.save(change, creatingCredentialFor: account.id, secret: secret) }
        await fulfillment(of: [entered], timeout: 2)
        backend.snapshot.context?.codexHome += "-changed"
        gate.signal(); await save.value
        XCTAssertEqual(native.added.count, 1); XCTAssertEqual(backend.commits, 0)
        XCTAssertEqual(try SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)).load()?.phase, .itemCreated)
        await setup.reconcile()
        XCTAssertEqual(setup.state, .recoveryRequired); XCTAssertEqual(setup.observedCreatedItem, account.credential)
        XCTAssertFalse(router.canQuit); XCTAssertNotNil(router.uncertainSetupOperationID)
    }
    func testHelperTimeoutRetainsLeaseAndReconcilesCommittedAccount() async throws {
        backend.loseReply = true
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
        XCTAssertEqual(setup.state, .uncertain); XCTAssertNotNil(router.uncertainSetupOperationID)
        XCTAssertFalse(router.canQuit); XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
        await router.refresh(); await setup.reconcile()
        XCTAssertEqual(setup.state, .uncertain); XCTAssertNotNil(router.uncertainSetupOperationID)
        backend.setupHelperIsRunning = false
        await setup.reconcile()
        XCTAssertEqual(setup.state, .saved); XCTAssertNil(router.uncertainSetupOperationID)
        XCTAssertFalse(backend.mutationRequiresReconciliation); XCTAssertEqual(backend.commits, 1); XCTAssertEqual(native.added.count, 1)
    }
    func testDirectInspectionAloneCannotClearSetupUncertainty() async throws {
        backend.loseReply = true
        await setup.save(change)
        backend.setupHelperIsRunning = false
        backend.preview.accounts = []
        await router.refresh(); await setup.reconcile(); await router.requestQuit()
        XCTAssertEqual(setup.state, .uncertain); XCTAssertNotNil(router.uncertainSetupOperationID)
        XCTAssertFalse(router.quitRequested); XCTAssertEqual(backend.commits, 1)
    }
    func testInaccessiblePreparedItemStillShowsDurableReceipt() async throws {
        let a = AccountRecord(id: account.id, displayName: account.displayName, upstreamBaseUrl: "https://example.invalid/api", credential: account.credential)
        let receipt = SetupReceipt(operationId: UUID().uuidString, account: a, context: context)
        let transaction = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try transaction.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        native.failure = .nativeStatus(errSecInteractionNotAllowed)
        await setup.refresh()
        XCTAssertEqual(setup.state, .recoveryRequired); XCTAssertEqual(setup.pendingReceipt, receipt)
        XCTAssertNotNil(setup.error); XCTAssertTrue(native.added.isEmpty); XCTAssertEqual(try transaction.load(), receipt)
    }
    func testPreparedReceiptNeverRetriesKeychainCreation() async throws {
        let normalized = AccountRecord(id: account.id, displayName: account.displayName, upstreamBaseUrl: "https://example.invalid/api", credential: account.credential)
        let receipt = SetupReceipt(operationId: UUID().uuidString, account: normalized, context: context)
        let old = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try old.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        native.rows = [[kSecAttrService as String: account.credential.service, kSecAttrAccount as String: account.credential.account]]
        await setup.refresh()
        XCTAssertEqual(setup.pendingReceipt, receipt); XCTAssertEqual(setup.state, .recoveryRequired)
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC")); await setup.reconcile()
        XCTAssertEqual(native.added.count, 0); XCTAssertEqual(backend.commits, 0)
        XCTAssertEqual(try old.load()?.phase, .prepared)
    }
    func testIncompleteAccountsKeepBrowsingAndOriginalRecovery() async throws {
        backend.snapshot.configuration.setupState = "required"
        backend.snapshot.catalog.entries = [.init(id: "project", name: "Project", routeAlias: nil, routeState: "unmapped")]
        await router.refresh(); await router.start(); await router.activate()
        XCTAssertFalse(router.canStart); XCTAssertEqual(backend.starts, 0); XCTAssertEqual(backend.controls, 0)
        XCTAssertEqual(router.inspection?.catalog.entries.count, 1)
        XCTAssertTrue(router.canRestoreDirect)
        await router.restoreDirect(); XCTAssertEqual(backend.controls, 1)
        backend.snapshot.configuration.setupState = "migration_required"
        await router.refresh(); await router.start(); XCTAssertEqual(backend.starts, 0)
    }
    func testValidationRejectsDuplicateNamesAndInvalidDefaultBeforeNativeCreation() async throws {
        account.displayName = "Existing"
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
        account.displayName = "New"
        await setup.save(.createConfiguration(account: account, incomingCredential: nil, defaultAccountId: UUID().uuidString), creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
        XCTAssertTrue(native.added.isEmpty); XCTAssertEqual(backend.commits, 0)
    }
    func testMissingConfigurationWithExistingCredentialUsesNoManufacturedReceipt() async throws {
        backend.preview.sourceKind = "missing"; backend.preview.accounts = []; backend.preview.setupState = "required"
        backend.preview.incomingCredential = nil; backend.preview.defaultAccountId = nil
        backend.snapshot.configuration = .init(state: "missing")
        backend.snapshot.context = nil; backend.snapshot.provider.state = "unavailable"; backend.snapshot.provider.proxyReady = nil
        await setup.refresh()
        await setup.save(.createConfiguration(account: account, incomingCredential: account.credential, defaultAccountId: account.id))
        XCTAssertEqual(setup.state, .saved); XCTAssertEqual(backend.commits, 1); XCTAssertTrue(native.added.isEmpty)
        XCTAssertEqual(router.inspection?.configuration.setupState, "ready")
        XCTAssertTrue(router.canStart)
        XCTAssertNil(try SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)).load())
    }
    func testVerifiedCompleteReceiptSurvivesMetadataOnlySave() async throws {
        await setup.save(change, creatingCredentialFor: account.id, secret: try KeychainSecret("SYNTHETIC"))
        let path = root.appendingPathComponent("account-setup.json"), before = try Data(contentsOf: path)
        let inode = try FileManager.default.attributesOfItem(atPath: path.path)[.systemFileNumber] as? NSNumber
        await setup.save(.setDefault(defaultAccountId: account.id))
        XCTAssertEqual(setup.state, .saved); XCTAssertEqual(try Data(contentsOf: path), before)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: path.path)[.systemFileNumber] as? NSNumber, inode)
        XCTAssertEqual(native.added.count, 1)
    }
    func testMetadataOnlySaveCreatesNoReceipt() async throws {
        await setup.save(.setDefault(defaultAccountId: backend.preview.accounts[0].id))
        XCTAssertEqual(setup.state, .saved); XCTAssertTrue(native.added.isEmpty)
        XCTAssertNil(try SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath)).load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
    }
    func testNewerFormRefreshWins() async throws {
        let gate = SetupGate<SetupPreview>(); backend.previewGate = gate
        let old = Task { await setup.refresh() }
        await waitUntil { gate.waiting }
        backend.preview.accounts[0].displayName = "Latest"
        await setup.refresh()
        gate.release(SetupBackendFixture.makePreview(context))
        await old.value
        XCTAssertEqual(setup.preview?.accounts.first?.displayName, "Latest")
    }
    private func waitUntil(_ predicate: () -> Bool) async { for _ in 0..<1000 { if predicate() { return }; await Task.yield() }; XCTFail("Missing barrier") }
}

@MainActor final class SetupGate<T> {
    var waiting = false; var continuation: CheckedContinuation<T, Never>?
    func wait() async -> T { await withCheckedContinuation { continuation = $0; waiting = true } }
    func release(_ value: T) { continuation?.resume(returning: value); continuation = nil }
}
@MainActor final class SetupBackendFixture: CompanionBackend, AccountSetupBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false, setupHelperIsRunning = false
    var uncertainSetupOperationID: String?
    var snapshot: Inspection, preview: SetupPreview
    var port: StopOutcome.PortState = .empty
    var commits = 0, starts = 0, controls = 0, loseReply = false
    var previewGate: SetupGate<SetupPreview>?
    var inspectionGate: SetupGate<Inspection>?
    var onPreview: ((Int) -> Void)?, previews = 0
    init(context: ActivationContext) {
        snapshot = .init(configuration: .init(state: "valid", path: context.configPath, mode: "accounts", setupState: "ready"), context: context, revision: "operational", provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"), catalog: .init(state: "ready", entries: []))
        preview = Self.makePreview(context)
    }
    static func makePreview(_ context: ActivationContext) -> SetupPreview {
        let ref = CredentialReference(keychainPath: "/private/synthetic.keychain-db", service: "synthetic", account: "existing")
        let a = SetupPreview.Account(id: "11111111-1111-4111-8111-111111111111", displayName: "Existing", upstreamBaseUrl: "https://existing.invalid", credential: ref, sourceAlias: nil)
        return .init(context: context, configurationRevision: String(repeating: "a", count: 64), setupState: "ready", sourceKind: "accounts", accounts: [a], routeAccounts: [:], incomingCredential: ref, defaultAccountId: a.id, incomingHint: nil, originalDirect: a)
    }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection { if let gate = inspectionGate { inspectionGate = nil; return await gate.wait() }; return snapshot }
    func previewSetup(configPath: URL, browseHome: URL) async throws -> SetupPreview { previews += 1; onPreview?(previews); if let gate = previewGate { previewGate = nil; return await gate.wait() }; return preview }
    func commitSetup(_ change: SetupChange, context: ActivationContext, revision: String, operationID: String) async throws -> SetupCommitResult {
        commits += 1
        switch change {
        case let .addAccount(a, incoming): preview.accounts.append(.init(id: a.id, displayName: a.displayName, upstreamBaseUrl: a.upstreamBaseUrl, credential: a.credential, sourceAlias: nil)); if let incoming { preview.incomingCredential = incoming }
        case let .setDefault(id, incoming): preview.defaultAccountId = id; if let incoming { preview.incomingCredential = incoming }
        case let .createConfiguration(a, incoming, id): preview.accounts = [.init(id: a.id, displayName: a.displayName, upstreamBaseUrl: a.upstreamBaseUrl, credential: a.credential, sourceAlias: nil)]; preview.defaultAccountId = id; preview.incomingCredential = incoming
        case let .migrate(accounts, incoming, id): preview.accounts = accounts.map { .init(id: $0.id, displayName: $0.displayName, upstreamBaseUrl: $0.upstreamBaseUrl, credential: $0.credential, sourceAlias: nil) }; preview.defaultAccountId = id; preview.incomingCredential = incoming
        }
        preview.setupState = preview.incomingCredential != nil && preview.defaultAccountId != nil && !preview.accounts.isEmpty ? "ready" : "required"
        preview.sourceKind = "accounts"; preview.configurationRevision = String(repeating: "c", count: 64)
        snapshot.configuration = .init(state: "valid", path: context.configPath, mode: "accounts", setupState: preview.setupState)
        snapshot.context = context; snapshot.provider.state = "direct"; snapshot.provider.proxyReady = false
        snapshot.revision = "saved-operational"
        if loseReply { setupHelperIsRunning = true; mutationRequiresReconciliation = true; uncertainSetupOperationID = operationID; throw CompanionError.mutationUncertain }
        return .init(context: context, operationId: operationID, setupState: "ready", configurationRevision: preview.configurationRevision, checkpointPath: nil, changed: true)
    }
    func probeSetupPort(_ context: ActivationContext) async -> StopOutcome.PortState { port }
    func finishSetupReconciliation(operationID: String) throws { guard !setupHelperIsRunning, uncertainSetupOperationID == operationID else { throw CompanionError.mutationBusy }; uncertainSetupOperationID = nil; mutationRequiresReconciliation = false }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ path: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter { starts += 1; throw CompanionError.startupFailed }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult { controls += 1; return .init(state: "direct", changed: false, restartRequired: false) }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode { .off }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode { mode }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome { throw CompanionError.unownedChild }
}
