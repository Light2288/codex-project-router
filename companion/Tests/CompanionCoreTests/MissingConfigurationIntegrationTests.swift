import XCTest
import Security
@testable import CompanionCore

/// Exercise the actual Node inspection envelope and native authorization together.
@MainActor final class MissingConfigurationIntegrationTests: XCTestCase {
    private var root: URL!, home: URL!, directory: URL!, config: URL!, backend: ProcessBackend!
    private var router: RouterController!, setup: AccountSetupController!, native: FakeKeychainSecurity!
    private var account: AccountRecord!, originalProvider: Data!

    override func setUp() async throws {
        root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/missing-setup-integration-\(UUID())")
        home = root.appendingPathComponent("codex"); directory = root.appendingPathComponent("router"); config = directory.appendingPathComponent("config.json")
        for path in [root!, home!, directory!] {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        originalProvider = Data("""
        model_provider = "synthetic"
        [model_providers.synthetic]
        base_url = "https://synthetic.invalid/v1"
        wire_api = "responses"
        supports_websockets = false
        [model_providers.synthetic.auth]
        command = "/synthetic/auth-must-not-run"
        args = []
        """.utf8)
        try originalProvider.write(to: home.appendingPathComponent("config.toml"))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: home.appendingPathComponent("config.toml").path)
        try Data("{\"local-projects\":{}}".utf8).write(to: home.appendingPathComponent(".codex-global-state.json"))
        let environment = ProcessInfo.processInfo.environment
        let candidates = [environment["npm_node_execpath"]].compactMap { $0 } + (environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/node" }
        let node = try XCTUnwrap(candidates.first { FileManager.default.isExecutableFile(atPath: $0) })
        var repository = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { repository.deleteLastPathComponent() }
        backend = ProcessBackend(resourcesURL: repository, nodeExecutable: URL(fileURLWithPath: node).resolvingSymlinksInPath())
        native = FakeKeychainSecurity()
        account = AccountRecord(id: "22222222-2222-4222-8222-222222222222", displayName: "Synthetic native account", upstreamBaseUrl: "https://synthetic.invalid/v1/account", credential: .init(keychainPath: "/private/synthetic.keychain-db", service: "synthetic", account: "created"))
        native.rows = [[kSecAttrService as String: account.credential.service, kSecAttrAccount as String: account.credential.account]]
        try makeControllers()
    }
    override func tearDown() async throws {
        setup = nil; router = nil; backend = nil; native = nil
        try FileManager.default.removeItem(at: root)
    }
    private func makeControllers() throws {
        setup = nil; router = nil
        let store = PrivateStore(directory: root.appendingPathComponent("companion-\(UUID())"))
        try store.save(.init(selectedConfigurationPath: config.path))
        router = RouterController(backend: backend, store: store, browseHome: home)
        setup = AccountSetupController(router: router, backend: backend, keychain: KeychainStore(security: native, companionPath: "/Synthetic.app/Contents/MacOS/Companion"), browseHome: home)
    }
    func testRealMissingBridgeAuthorizesNativeCreationAndOwnPreparedRevalidation() async throws {
        await router.refresh(); await setup.refresh()
        XCTAssertEqual(router.inspection?.configuration.state, "missing")
        XCTAssertTrue(router.canBeginAccountSetup)
        let secret = try KeychainSecret("PUBLIC_SYNTHETIC")
        await setup.save(.createConfiguration(account: account, incomingCredential: nil, defaultAccountId: nil), creatingCredentialFor: account.id, secret: secret)
        XCTAssertEqual(setup.state, .saved, setup.error ?? "No setup error")
        guard setup.state == .saved else { return }
        XCTAssertEqual(native.added, [account.credential]); XCTAssertTrue(secret.isDiscarded)
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as? [String: Any]
        XCTAssertEqual(saved?["schemaVersion"] as? Int, 2)
        XCTAssertEqual(router.inspection?.configuration.setupState, "required"); XCTAssertFalse(router.canStart)
        let receipt = try SetupTransactionStore(configPath: config).load()
        XCTAssertEqual(receipt?.phase, .complete); XCTAssertEqual(receipt?.account, account)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(".activation.lock").path))
        XCTAssertEqual(try Data(contentsOf: home.appendingPathComponent("config.toml")), originalProvider)
    }
    func testRealMissingBridgeKeepsProviderRecoveryEvidenceBlockingBeforeNativeCreation() async throws {
        for name in ["activation.json", "codex-config-11111111-1111-4111-8111-111111111111.toml", "account-setup-checkpoint-synthetic.json"] {
            let evidence = directory.appendingPathComponent(name)
            try Data("unsafe-recovery-evidence".utf8).write(to: evidence)
            let inspection = try await backend.inspect(configPath: config, browseHome: home)
            XCTAssertTrue(inspection.provider.recoveryRequired, name)
            await router.refresh(); await setup.refresh()
            await setup.save(.createConfiguration(account: account, incomingCredential: nil, defaultAccountId: nil), creatingCredentialFor: account.id, secret: try KeychainSecret("PUBLIC_SYNTHETIC"))
            XCTAssertTrue(native.added.isEmpty); XCTAssertFalse(FileManager.default.fileExists(atPath: config.path))
            XCTAssertEqual(try Data(contentsOf: evidence), Data("unsafe-recovery-evidence".utf8))
            try FileManager.default.removeItem(at: evidence)
        }
    }
    func testRealMissingBridgeKeepsAbandonedAndUnsafeNativeEvidenceBlocking() async throws {
        let preview = try await backend.previewSetup(configPath: config, browseHome: home)
        let operation = UUID().uuidString, transaction = SetupTransactionStore(configPath: config)
        try transaction.begin(context: preview.context, operationID: operation, receipt: nil)
        try transaction.prepare(.init(operationId: operation, account: account, context: preview.context))
        try makeControllers(); await router.refresh(); await setup.refresh()
        XCTAssertFalse(router.canBeginAccountSetup); XCTAssertEqual(setup.state, .recoveryRequired)
        await setup.save(.createConfiguration(account: account, incomingCredential: nil, defaultAccountId: nil), creatingCredentialFor: account.id, secret: try KeychainSecret("PUBLIC_SYNTHETIC"))
        XCTAssertTrue(native.added.isEmpty); XCTAssertFalse(FileManager.default.fileExists(atPath: config.path))
        let receiptPath = directory.appendingPathComponent("account-setup.json"), lockPath = directory.appendingPathComponent(".activation.lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: receiptPath.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: lockPath.path))
        // Receipt-only and lease-only interruption must each retain their own authority.
        let leaseBytes = try Data(contentsOf: lockPath)
        try FileManager.default.removeItem(at: lockPath)
        try makeControllers(); await setup.refresh()
        XCTAssertFalse(router.canBeginAccountSetup); XCTAssertEqual(setup.state, .recoveryRequired); XCTAssertTrue(native.added.isEmpty)
        try FileManager.default.removeItem(at: receiptPath)
        try leaseBytes.write(to: lockPath)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: lockPath.path)
        try makeControllers(); await setup.refresh()
        XCTAssertFalse(router.canBeginAccountSetup); XCTAssertEqual(setup.state, .recoveryRequired); XCTAssertTrue(native.added.isEmpty)
        // The remaining cases alter only this test's owned evidence after observing refusal.
        try FileManager.default.removeItem(at: lockPath)
        try FileManager.default.createSymbolicLink(at: receiptPath, withDestinationURL: home.appendingPathComponent("config.toml"))
        try makeControllers(); await setup.refresh()
        XCTAssertFalse(router.canBeginAccountSetup); XCTAssertEqual(setup.state, .recoveryRequired); XCTAssertTrue(native.added.isEmpty)
        try FileManager.default.removeItem(at: receiptPath)
        try Data("malformed-lease".utf8).write(to: lockPath)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: lockPath.path)
        try makeControllers(); await setup.refresh()
        XCTAssertFalse(router.canBeginAccountSetup); XCTAssertEqual(setup.state, .recoveryRequired); XCTAssertTrue(native.added.isEmpty)
    }
}
