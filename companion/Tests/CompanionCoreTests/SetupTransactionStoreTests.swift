import XCTest
import Darwin
import Security
@testable import CompanionCore

final class SetupTransactionStoreTests: XCTestCase {
    var root: URL!, context: ActivationContext!, account: AccountRecord!, receipt: SetupReceipt!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("setup-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        context = ActivationContext(configPath: root.appendingPathComponent("router.json").path, codexHome: "/private/synthetic-codex", providerId: "synthetic", listenPort: 43123)
        let ref = CredentialReference(keychainPath: "/private/synthetic.keychain-db", service: "synthetic", account: UUID().uuidString)
        account = AccountRecord(id: UUID().uuidString, displayName: "Synthetic", upstreamBaseUrl: "https://example.invalid/api", credential: ref)
        receipt = SetupReceipt(operationId: UUID().uuidString, account: account, context: context)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testReceiptPrecedesCreationAndSurvivesRelaunch() async throws {
        let store = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try store.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        let fake = FakeKeychainSecurity(), keychain = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        XCTAssertEqual(try store.load(), receipt)
        try await keychain.createGenericPassword(reference: account.credential, secret: KeychainSecret("SYNTHETIC_CREATE"))
        // Simulate success immediately before the durable item_created advance.
        let relaunched = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        fake.rows = [[kSecAttrService as String: account.credential.service, kSecAttrAccount as String: account.credential.account]]
        let found = try await keychain.lookup(reference: try XCTUnwrap(relaunched.load()).reference)
        XCTAssertEqual(found, account.credential); XCTAssertEqual(fake.added.count, 1)
        XCTAssertThrowsError(try relaunched.begin(context: context, operationID: receipt.operationId, receipt: receipt))
        XCTAssertThrowsError(try relaunched.finishVerified())
        XCTAssertEqual(try store.load()?.phase, .prepared)
        try store.advance(.itemCreated); try store.advance(.committing); try store.advance(.complete); try store.finishVerified()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
        XCTAssertEqual(try store.load()?.phase, .complete)
        let bytes = try Data(contentsOf: root.appendingPathComponent("account-setup.json"))
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("SYNTHETIC_CREATE"))
        XCTAssertEqual(try mode(root), 0o700); XCTAssertEqual(try mode(root.appendingPathComponent("account-setup.json")), 0o600)
    }
    func testReplacedUnsafeLeaseIsPreserved() throws {
        let store = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try store.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        let lease = root.appendingPathComponent(".activation.lock"), moved = root.appendingPathComponent("old-lock")
        try FileManager.default.moveItem(at: lease, to: moved)
        let replacement = Data("replacement".utf8); try replacement.write(to: lease)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: lease.path)
        XCTAssertThrowsError(try store.advance(.itemCreated)); XCTAssertThrowsError(try store.finishVerified())
        XCTAssertEqual(try Data(contentsOf: lease), replacement)
        XCTAssertEqual(try store.load()?.phase, .prepared)
    }
    func testUnsafeEvidenceAndStaleLeaseNeverRepairOrDelete() throws {
        for fixture in ["symlink", "hardlink", "permissions", "unknown", "stale"] {
            let dir = root.appendingPathComponent(fixture); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let config = dir.appendingPathComponent("router.json"), path = dir.appendingPathComponent(fixture == "stale" ? ".activation.lock" : "account-setup.json")
            let bytes = fixture == "stale" ? Data(#"{"pid":99999999,"setupOperationId":"11111111-1111-4111-8111-111111111111","configPath":"/synthetic"}"#.utf8) : Data("{\"unknown\":true}".utf8)
            let target = dir.appendingPathComponent("target")
            if fixture == "symlink" { try bytes.write(to: target); try FileManager.default.createSymbolicLink(at: path, withDestinationURL: target) }
            else { try bytes.write(to: path); try FileManager.default.setAttributes([.posixPermissions: fixture == "permissions" ? 0o644 : 0o600], ofItemAtPath: path.path) }
            if fixture == "hardlink" { XCTAssertEqual(link(path.path, target.path), 0) }
            let candidateContext = ActivationContext(configPath: config.path, codexHome: context.codexHome, providerId: context.providerId, listenPort: context.listenPort)
            let store = SetupTransactionStore(configPath: config)
            XCTAssertThrowsError(try store.begin(context: candidateContext, operationID: UUID().uuidString, receipt: nil), fixture)
            XCTAssertEqual(try Data(contentsOf: path), bytes, fixture)
        }
    }
    func testLeaseWireAndPhaseTransitionsRequireOwnedEvidence() throws {
        let store = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try store.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        let lease = root.appendingPathComponent(".activation.lock")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: lease)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["pid", "setupOperationId", "configPath"])
        XCTAssertEqual(json["pid"] as? Int, Int(getpid())); XCTAssertEqual(json["setupOperationId"] as? String, receipt.operationId)
        XCTAssertEqual(try mode(lease), 0o600)
        XCTAssertThrowsError(try store.advance(.complete)); XCTAssertThrowsError(try store.finishVerified())
        try store.advance(.itemCreated)
        let receiptPath = root.appendingPathComponent("account-setup.json"), moved = root.appendingPathComponent("old-receipt")
        try FileManager.default.moveItem(at: receiptPath, to: moved)
        try Data(contentsOf: moved).write(to: receiptPath); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: receiptPath.path)
        XCTAssertThrowsError(try store.advance(.committing))
    }

    func testCompletedReceiptReplacementRequiresExactFreshSavedAccount() throws {
        let config = URL(fileURLWithPath: context.configPath)
        let first = SetupTransactionStore(configPath: config)
        try first.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        try first.advance(.itemCreated); try first.advance(.committing); try first.advance(.complete); try first.finishVerified()
        let completedBytes = try Data(contentsOf: root.appendingPathComponent("account-setup.json"))
        let nextAccount = AccountRecord(id: UUID().uuidString, displayName: "Next", upstreamBaseUrl: account.upstreamBaseUrl, credential: CredentialReference(keychainPath: account.credential.keychainPath, service: "next", account: UUID().uuidString))
        let next = SetupReceipt(operationId: UUID().uuidString, account: nextAccount, context: context)
        let store = SetupTransactionStore(configPath: config)
        XCTAssertThrowsError(try store.begin(context: context, operationID: next.operationId, receipt: next))
        var mismatched = account!; mismatched.displayName = "Changed"
        XCTAssertThrowsError(try store.begin(context: context, operationID: next.operationId, receipt: next, verifiedPreviousAccount: mismatched))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("account-setup.json")), completedBytes)
        try store.begin(context: context, operationID: next.operationId, receipt: nil)
        XCTAssertThrowsError(try store.prepare(next))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("account-setup.json")), completedBytes)
        try store.prepare(next, verifiedPreviousAccount: account)
        XCTAssertEqual(try store.load(), next)
    }

    func testMetadataOnlyOperationPreservesCompletedReceiptAndInode() throws {
        let config = URL(fileURLWithPath: context.configPath), first = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try first.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        try first.advance(.itemCreated); try first.advance(.committing); try first.advance(.complete); try first.finishVerified()
        let path = root.appendingPathComponent("account-setup.json"), old = try Data(contentsOf: path)
        var before = stat(); XCTAssertEqual(lstat(path.path, &before), 0)
        let metadataOnly = SetupTransactionStore(configPath: config)
        try metadataOnly.begin(context: context, operationID: UUID().uuidString, receipt: nil)
        try metadataOnly.advance(.committing); try metadataOnly.advance(.complete); try metadataOnly.finishVerified()
        var after = stat(); XCTAssertEqual(lstat(path.path, &after), 0)
        XCTAssertEqual(before.st_ino, after.st_ino); XCTAssertEqual(try Data(contentsOf: path), old)
    }

    func testDeinitDoesNotReleaseUncertainLeaseOrReceipt() throws {
        let config = URL(fileURLWithPath: context.configPath)
        var store: SetupTransactionStore? = SetupTransactionStore(configPath: config)
        try store!.begin(context: context, operationID: receipt.operationId, receipt: receipt)
        store = nil
        let relaunched = SetupTransactionStore(configPath: config)
        XCTAssertEqual(try relaunched.load(), receipt)
        XCTAssertThrowsError(try relaunched.begin(context: context, operationID: UUID().uuidString, receipt: nil))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
    }

    func testUnsafeDirectoryAndNonregularReceiptRemainUnmodified() throws {
        let config = URL(fileURLWithPath: context.configPath)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        XCTAssertThrowsError(try SetupTransactionStore(configPath: config).begin(context: context, operationID: UUID().uuidString, receipt: nil))
        XCTAssertEqual(try mode(root), 0o755)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        let path = root.appendingPathComponent("account-setup.json")
        XCTAssertEqual(mkfifo(path.path, 0o600), 0)
        XCTAssertThrowsError(try SetupTransactionStore(configPath: config).load())
        var info = stat(); XCTAssertEqual(lstat(path.path, &info), 0); XCTAssertEqual(info.st_mode & S_IFMT, S_IFIFO)
    }

    func testSymlinkAncestorCannotCreateEvidenceAtNoncanonicalContext() throws {
        let parent = root.appendingPathComponent("parent"), actual = parent.appendingPathComponent("private")
        try FileManager.default.createDirectory(at: actual, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let alias = root.appendingPathComponent("alias"); try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: parent)
        let config = alias.appendingPathComponent("private/router.json")
        let aliasedContext = ActivationContext(configPath: config.path, codexHome: context.codexHome, providerId: context.providerId, listenPort: context.listenPort)
        XCTAssertThrowsError(try SetupTransactionStore(configPath: config).begin(context: aliasedContext, operationID: UUID().uuidString, receipt: nil))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: actual.path).isEmpty)
    }

    func testUnsafeOrReplacedCompletedLeaseNeverGetsReleased() throws {
        for fixture in ["symlink", "hardlink", "permissions", "content", "missing"] {
            let dir = root.appendingPathComponent(fixture)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let config = dir.appendingPathComponent("router.json"), lease = dir.appendingPathComponent(".activation.lock"), saved = dir.appendingPathComponent("saved-lock")
            let c = ActivationContext(configPath: config.path, codexHome: context.codexHome, providerId: context.providerId, listenPort: context.listenPort)
            let r = SetupReceipt(operationId: UUID().uuidString, account: account, context: c), store = SetupTransactionStore(configPath: config)
            try store.begin(context: c, operationID: r.operationId, receipt: r)
            try store.advance(.itemCreated); try store.advance(.committing); try store.advance(.complete)
            let original = try Data(contentsOf: lease)
            switch fixture {
            case "symlink": try FileManager.default.moveItem(at: lease, to: saved); try FileManager.default.createSymbolicLink(at: lease, withDestinationURL: saved)
            case "hardlink": XCTAssertEqual(link(lease.path, saved.path), 0)
            case "permissions": try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: lease.path)
            case "content": try Data("changed operation".utf8).write(to: lease)
            default: try FileManager.default.removeItem(at: lease)
            }
            XCTAssertThrowsError(try store.finishVerified(), fixture)
            if fixture == "missing" { XCTAssertFalse(FileManager.default.fileExists(atPath: lease.path)) }
            else { XCTAssertEqual(try Data(contentsOf: lease), fixture == "content" ? Data("changed operation".utf8) : original, fixture) }
            XCTAssertEqual(try store.load()?.phase, .complete)
        }
    }

    func testLeaseCanPrecedeFreshPreviewAndDurablePreparation() throws {
        let store = SetupTransactionStore(configPath: URL(fileURLWithPath: context.configPath))
        try store.begin(context: context, operationID: receipt.operationId, receipt: nil)
        XCTAssertNil(try store.load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
        // The controller checks context/revision/direct state/port here, under the lease.
        var wrongOperation = receipt!; wrongOperation.operationId = UUID().uuidString
        XCTAssertThrowsError(try store.prepare(wrongOperation))
        XCTAssertNil(try store.load())
        try store.prepare(receipt)
        XCTAssertEqual(try store.load(), receipt)
        XCTAssertThrowsError(try store.prepare(receipt))
        try store.advance(.itemCreated); try store.advance(.committing); try store.advance(.complete); try store.finishVerified()
    }
    private func mode(_ path: URL) throws -> Int { (try FileManager.default.attributesOfItem(atPath: path.path)[.posixPermissions] as! NSNumber).intValue }
}
