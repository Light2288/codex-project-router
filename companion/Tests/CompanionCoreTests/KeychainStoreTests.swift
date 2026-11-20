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

    func testBrowsingOmitsOnlyUnusableServiceAccountRows() async throws {
        let service = kSecAttrService as String, account = kSecAttrAccount as String
        let invalidRows: [[String: Any]] = [
            [:], [service: "x"], [account: "x"], [service: 42, account: "x"],
            [service: "x", account: NSNull()], [service: "", account: "x"],
            [service: "x", account: ""], [service: "bad\n", account: "x"],
            [service: "x", account: "bad\t"], [service: String(repeating: "s", count: 1025), account: "x"],
            [service: "x", account: String(repeating: "a", count: 1025)],
            [service: "", account: ""]
        ]
        let boundary = CredentialReference(keychainPath: reference.keychainPath,
            service: String(repeating: "🧭", count: 512), account: " preserved spaces ")
        let validRows: [[String: Any]] = [
            [service: reference.service, account: reference.account],
            [service: boundary.service, account: boundary.account]
        ]
        for rows in [invalidRows + validRows, validRows + Array(invalidRows.reversed())] {
            let fake = FakeKeychainSecurity(); fake.rows = rows
            let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
            let listing = try await store.browseMetadata()
            XCTAssertEqual(listing.references, [reference, boundary])
            XCTAssertEqual(listing.omittedItemCount, 12)
            XCTAssertTrue(fake.added.isEmpty)
        }
    }

    func testBrowsingDistinguishesEmptyAndAllOmitted() async throws {
        let fake = FakeKeychainSecurity()
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        let empty = try await store.browseMetadata()
        XCTAssertTrue(empty.references.isEmpty); XCTAssertEqual(empty.omittedItemCount, 0)
        fake.rows = [[:], [kSecAttrService as String: ""]]
        let omitted = try await store.browseMetadata()
        XCTAssertTrue(omitted.references.isEmpty); XCTAssertEqual(omitted.omittedItemCount, 2)
    }

    func testBrowsingHardFailuresTakePrecedenceOverOmission() async throws {
        let service = kSecAttrService as String, account = kSecAttrAccount as String
        let valid: [String: Any] = [service: reference.service, account: reference.account]
        let invalid: [[String: Any]] = [
            [kSecValueData as String: Data("PRIVATE_SYNTHETIC".utf8)],
            [kSecValueData as String: NSNull(), service: ""],
            [service: "wrong"], [account: "wrong"]
        ]
        for bad in invalid {
            for rows in [[valid, bad], [bad, valid]] {
                let fake = FakeKeychainSecurity(); fake.rows = rows
                let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
                do {
                    _ = try await store.browseMetadata(service: reference.service, account: reference.account)
                    XCTFail("Contradictory or secret-bearing evidence cannot be omitted")
                } catch {
                    XCTAssertEqual(error as? KeychainError, .unsupported)
                    XCTAssertFalse(error.localizedDescription.contains("PRIVATE_SYNTHETIC"))
                    XCTAssertFalse(error.localizedDescription.contains("wrong"))
                }
                XCTAssertTrue(fake.added.isEmpty)
            }
        }
    }

    func testBrowsingFailsWholeListingWhenLaterKeychainFails() async throws {
        let first = reference.keychainPath, second = "/private/second.keychain-db"
        for failure in [KeychainError.nativeStatus(errSecAuthFailed), .nativeStatus(errSecInteractionNotAllowed), .nativeStatus(errSecUserCanceled), .unsupported] {
            let fake = FakeKeychainSecurity(); fake.searchPaths = [first, second]
            fake.rowsByPath[first] = [[kSecAttrService as String: reference.service, kSecAttrAccount as String: reference.account], [:]]
            fake.metadataFailuresByPath[second] = failure
            let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
            do { _ = try await store.browseMetadata(); XCTFail("Later native failure must reject the entire listing") }
            catch { XCTAssertEqual(error as? KeychainError, failure) }
            XCTAssertEqual(fake.paths, [first, second]); XCTAssertTrue(fake.added.isEmpty)
        }
    }

    func testStrictLookupRejectsRowsThatBrowsingOmits() async throws {
        let fake = FakeKeychainSecurity(); fake.rows = [[:]]
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        let browsing = try await store.browseMetadata()
        XCTAssertEqual(browsing.omittedItemCount, 1)
        do { _ = try await store.listMetadata(); XCTFail("Strict listing cannot omit evidence") }
        catch { XCTAssertEqual(error as? KeychainError, .unsupported) }
        do { _ = try await store.lookup(reference: reference); XCTFail("Recovery cannot infer absence") }
        catch { XCTAssertEqual(error as? KeychainError, .unsupported) }
        do { _ = try await store.lookup(service: reference.service, account: reference.account); XCTFail("Suggestions remain strict") }
        catch { XCTAssertEqual(error as? KeychainError, .unsupported) }
        fake.rows = []
        let absent = try await store.lookup(reference: reference); XCTAssertNil(absent)
        let invalid = CredentialReference(keychainPath: "relative", service: "s", account: "a")
        do { _ = try await store.lookup(reference: invalid); XCTFail("Invalid exact reference") }
        catch { XCTAssertEqual(error as? KeychainError, .invalidReference) }
        fake.rows = [[kSecValueData as String: Data()]]
        do { _ = try await store.lookup(reference: reference); XCTFail("Unexpected data must fail exact lookup") }
        catch { XCTAssertEqual(error as? KeychainError, .unsupported) }
        fake.rows = [[kSecAttrService as String: "different", kSecAttrAccount as String: reference.account]]
        do { _ = try await store.lookup(reference: reference); XCTFail("Contradictory exact result") }
        catch { XCTAssertEqual(error as? KeychainError, .unsupported) }
    }

    func testBrowsingPreservesFilteredAndExactPathScope() async throws {
        let second = "/private/second.keychain-db"
        let fake = FakeKeychainSecurity(); fake.searchPaths = [reference.keychainPath, second, reference.keychainPath]
        fake.rows = [[kSecAttrService as String: reference.service, kSecAttrAccount as String: reference.account]]
        fake.rowsByPath[second] = fake.rows + [[:]]
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        let all = try await store.browseMetadata()
        XCTAssertEqual(all.references, [reference, .init(keychainPath: second, service: reference.service, account: reference.account)])
        XCTAssertEqual(all.omittedItemCount, 1)
        XCTAssertEqual(fake.paths, [reference.keychainPath, second])
        for (service, account) in [(Optional(reference.service), nil), (nil, Optional(reference.account)), (Optional(reference.service), Optional(reference.account))] {
            let listing = try await store.browseMetadata(service: service, account: account, keychainPath: reference.keychainPath)
            XCTAssertEqual(listing.references, [reference]); XCTAssertEqual(listing.omittedItemCount, 0)
            XCTAssertEqual(fake.paths.last, reference.keychainPath)
            XCTAssertEqual(fake.queries.last?[kSecAttrService as String] as? String, service)
            XCTAssertEqual(fake.queries.last?[kSecAttrAccount as String] as? String, account)
        }
        XCTAssertEqual(fake.searchListReads, 1)
        XCTAssertEqual(fake.searchPaths, [reference.keychainPath, second, reference.keychainPath])
    }

    func testBrowsingRejectsInvalidPathsAndSearchListFailures() async throws {
        let fake = FakeKeychainSecurity()
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        for path in ["relative", "/bad\0path", "/bad\npath", "/" + String(repeating: "p", count: 1024)] {
            do { _ = try await store.browseMetadata(keychainPath: path); XCTFail("Unsafe path cannot be an item omission") }
            catch { XCTAssertEqual(error as? KeychainError, .unsupported) }
        }
        XCTAssertTrue(fake.queries.isEmpty)
        fake.searchListFailure = .nativeStatus(errSecAuthFailed)
        do { _ = try await store.browseMetadata(); XCTFail("Search list failure must propagate") }
        catch { XCTAssertEqual(error as? KeychainError, .nativeStatus(errSecAuthFailed)) }
    }

    func testBrowsingQueriesNeverRequestSecretsAndRemainSerial() async throws {
        let fake = FakeKeychainSecurity()
        let store = KeychainStore(security: fake, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        _ = try await store.browseMetadata()
        let query = try XCTUnwrap(fake.queries.first)
        XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
        XCTAssertEqual(query[kSecReturnAttributes as String] as? Bool, true)
        XCTAssertEqual(query[kSecReturnData as String] as? Bool, false)
        XCTAssertEqual(query[kSecReturnRef as String] as? Bool, false)
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, false)
        XCTAssertEqual(query[kSecMatchLimit as String] as? String, kSecMatchLimitAll as String)
        XCTAssertEqual(fake.metadataOffMainThread, [true]); XCTAssertTrue(fake.added.isEmpty)
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
        let metadata = Task { try await store.browseMetadata() }
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
    var rowsByPath: [String: [[String: Any]]] = [:], metadataFailuresByPath: [String: KeychainError] = [:]
    var searchListFailure: KeychainError?, searchListReads = 0, metadataOffMainThread: [Bool] = []
    func searchListPaths() throws -> [String] {
        searchListReads += 1
        if let searchListFailure { throw searchListFailure }
        return searchPaths
    }
    func defaultKeychainPath() throws -> String { defaultPath }
    func metadata(keychainPath: String, query: [String: Any]) throws -> [[String: Any]] {
        onMetadata?(); queries.append(query); paths.append(keychainPath)
        metadataOffMainThread.append(!Thread.isMainThread)
        if let failure = metadataFailuresByPath[keychainPath] ?? failure { throw failure }
        return rowsByPath[keychainPath] ?? rows
    }
    func create(reference: CredentialReference, secret: UnsafeRawBufferPointer, trustedApplicationPaths: [String]) throws {
        added.append(reference); passwords.append(Array(secret)); readers.append(trustedApplicationPaths); callsOffMainThread.append(!Thread.isMainThread)
        onCreate?()
        if let failure { throw failure }
    }
}
