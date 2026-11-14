import XCTest
import Security
@testable import CompanionCore

final class KeychainStoreTests: XCTestCase {
    let reference = CredentialReference(keychainPath: "/private/synthetic.keychain-db", service: "synthetic-service", account: "synthetic-account")

    func testMetadataQueriesNeverRequestSecretData() async throws {
        let fake = FakeKeychainSecurity(); fake.rows = [[kSecAttrService as String: reference.service, kSecAttrAccount as String: reference.account]]
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        let found = try await store.lookup(reference: reference)
        XCTAssertEqual(found, reference)
        XCTAssertEqual(fake.queries.count, 1)
        let query = fake.queries[0]
        XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
        XCTAssertEqual(query[kSecReturnAttributes as String] as? Bool, true)
        XCTAssertEqual(query[kSecReturnData as String] as? Bool, false)
        XCTAssertEqual(query[kSecReturnRef as String] as? Bool, false)
        XCTAssertNil(query[kSecValueData as String])
        XCTAssertEqual(fake.paths, [reference.keychainPath])
        XCTAssertEqual(fake.added.count, 0)
    }

    func testCreateUsesExactPrivateItemAndNarrowReaderACL() async throws {
        let fake = FakeKeychainSecurity(), secret = try KeychainSecret("SYNTHETIC_123!~")
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        try await store.createGenericPassword(reference: reference, secret: secret)
        XCTAssertEqual(fake.added, [reference]); XCTAssertEqual(fake.passwords, [Array("SYNTHETIC_123!~".utf8)])
        XCTAssertEqual(fake.readers, [["/Synthetic.app/Contents/MacOS/Companion", "/usr/bin/security"]])
        XCTAssertTrue(secret.isDiscarded)
        XCTAssertThrowsError(try secret.withBytes { _ in () })
        XCTAssertEqual(fake.callsOffMainThread, [true])
    }

    func testDuplicateDeniedLockedAndCancelledItemsStayVisible() async throws {
        for status in [errSecDuplicateItem, errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled] {
            let fake = FakeKeychainSecurity(); fake.failure = KeychainError.nativeStatus(status)
            let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
            let secret = try KeychainSecret("SYNTHETIC")
            do { try await store.createGenericPassword(reference: reference, secret: secret); XCTFail("Expected visible native failure") }
            catch { XCTAssertEqual(error as? KeychainError, .nativeStatus(status)); XCTAssertFalse(error.localizedDescription.contains("SYNTHETIC")) }
            XCTAssertEqual(fake.added.count, 1); XCTAssertTrue(secret.isDiscarded)
        }
    }

    func testTokenBoundsRejectWithoutTrimmingAndPreserveSearchListChoice() async throws {
        for invalid in ["", " leading", "trailing ", "line\n", "tab\t", "é", String(repeating: "a", count: 8193)] { XCTAssertThrowsError(try KeychainSecret(invalid)) }
        let maximum = try KeychainSecret(String(repeating: "~", count: 8192)); XCTAssertEqual(try maximum.withBytes { $0.count }, 8192)
        let fake = FakeKeychainSecurity(); fake.searchPaths = ["/private/first.keychain-db", reference.keychainPath]; fake.defaultPath = reference.keychainPath
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        let selected = try await store.defaultKeychainPath(); XCTAssertEqual(selected, reference.keychainPath)
        _ = try await store.listMetadata()
        XCTAssertEqual(fake.paths, fake.searchPaths); XCTAssertEqual(fake.added.count, 0)
    }

    func testAmbiguousMetadataFailsWithoutFallbackOrAdd() async throws {
        let fake = FakeKeychainSecurity(); fake.rows = Array(repeating: [kSecAttrService as String: reference.service, kSecAttrAccount as String: reference.account], count: 2)
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        do { _ = try await store.lookup(reference: reference); XCTFail("Ambiguity must remain visible") }
        catch { XCTAssertEqual(error as? KeychainError, .ambiguous) }
        XCTAssertTrue(fake.added.isEmpty)
    }

    func testHintWithoutPathRejectsMatchesAcrossSearchList() async throws {
        let fake = FakeKeychainSecurity(); fake.searchPaths = ["/private/first.keychain-db", "/private/second.keychain-db"]
        fake.rows = [[kSecAttrService as String: reference.service, kSecAttrAccount as String: reference.account]]
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        do { _ = try await store.lookup(service: reference.service, account: reference.account); XCTFail("A helper hint cannot pick among different Keychains") }
        catch { XCTAssertEqual(error as? KeychainError, .ambiguous) }
        XCTAssertEqual(fake.paths, fake.searchPaths); XCTAssertTrue(fake.added.isEmpty)
    }

    func testNativeConsentRemainsSerialAndOwnsSecretThroughCancellation() async throws {
        let fake = FakeKeychainSecurity(), entered = expectation(description: "Native creation entered"), gate = DispatchSemaphore(value: 0)
        let earlyMetadata = expectation(description: "Metadata must wait for native consent"); earlyMetadata.isInverted = true
        fake.onCreate = { entered.fulfill(); _ = gate.wait(timeout: .now() + 5) }
        fake.onMetadata = { earlyMetadata.fulfill() }
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion"), secret = try KeychainSecret("SYNTHETIC_CANCEL")
        let creation = Task { try await store.createGenericPassword(reference: reference, secret: secret) }
        await fulfillment(of: [entered], timeout: 2)
        creation.cancel()
        let metadata = Task { try await store.listMetadata() }
        await fulfillment(of: [earlyMetadata], timeout: 0.05)
        gate.signal()
        try await creation.value; _ = try await metadata.value
        XCTAssertTrue(secret.isDiscarded); XCTAssertEqual(fake.added.count, 1); XCTAssertEqual(fake.queries.count, 1)
        XCTAssertFalse(String(reflecting: secret).contains("SYNTHETIC_CANCEL"))
    }

    func testExplicitFileBackedPathDoesNotRequireChangingUserSearchList() async throws {
        let fake = FakeKeychainSecurity(); fake.searchPaths = ["/private/user-selected.keychain-db"]
        fake.rows = [[kSecAttrService as String: reference.service, kSecAttrAccount as String: reference.account]]
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        let found = try await store.lookup(reference: reference); XCTAssertEqual(found, reference)
        try await store.createGenericPassword(reference: reference, secret: KeychainSecret("SYNTHETIC_EXPLICIT"))
        XCTAssertEqual(fake.paths, [reference.keychainPath]); XCTAssertEqual(fake.added, [reference])
        let selected = try await store.defaultKeychainPath(); XCTAssertEqual(selected, fake.defaultPath)
        XCTAssertEqual(fake.searchPaths, ["/private/user-selected.keychain-db"])
    }
}

final class FakeKeychainSecurity: KeychainSecurity {
    var rows: [[String: Any]] = [], queries: [[String: Any]] = [], paths: [String] = []
    var added: [CredentialReference] = [], passwords: [[UInt8]] = [], readers: [[String]] = [], callsOffMainThread: [Bool] = []
    var failure: KeychainError?, searchPaths = ["/private/synthetic.keychain-db"], defaultPath = "/private/synthetic.keychain-db"
    var onCreate: (() -> Void)?, onMetadata: (() -> Void)?
    func searchListPaths() throws -> [String] { searchPaths }
    func defaultKeychainPath() throws -> String { defaultPath }
    func metadata(keychainPath: String, query: [String: Any]) throws -> [[String: Any]] { onMetadata?(); queries.append(query); paths.append(keychainPath); if let failure { throw failure }; return rows }
    func create(reference: CredentialReference, secret: UnsafeRawBufferPointer, trustedApplicationPaths: [String]) throws {
        added.append(reference); passwords.append(Array(secret)); readers.append(trustedApplicationPaths); callsOffMainThread.append(!Thread.isMainThread)
        onCreate?()
        if let failure { throw failure }
    }
}
