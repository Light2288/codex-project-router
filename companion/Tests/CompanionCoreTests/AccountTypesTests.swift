import XCTest
@testable import CompanionCore

final class AccountTypesTests: XCTestCase {
    func testNoncanonicalEndpointIsRejectedBeforeReceiptPreparation() {
        let reference = CredentialReference(keychainPath: "/private/synthetic.keychain-db", service: "synthetic", account: "test")
        let account = AccountRecord(id: UUID().uuidString, displayName: "Synthetic", upstreamBaseUrl: "https://EXAMPLE.invalid/api/", credential: reference)
        XCTAssertFalse(account.isValid)
    }

    func testEndpointNormalizationMatchesNodeAndPreservesAPIPrefixes() throws {
        // Expected strings are Node new URL(value).href.replace(/\/$/, "") results.
        let fixtures = [
            ("https://EXAMPLE.invalid/api/", "https://example.invalid/api"),
            ("HTTPS://EXAMPLE.invalid:443/v1/", "https://example.invalid/v1"),
            ("https://example.invalid:00443/v1/", "https://example.invalid/v1"),
            ("https://example.invalid", "https://example.invalid"),
            ("https://example.invalid/", "https://example.invalid"),
            ("https://EXAMPLE.invalid:8443/provider/v1/", "https://example.invalid:8443/provider/v1"),
            ("https://example.invalid/v1%2Faccount/", "https://example.invalid/v1%2Faccount"),
            ("https://example.invalid/provider%2froot/%25token/", "https://example.invalid/provider%2froot/%25token"),
            ("https://example.invalid/v1//account/", "https://example.invalid/v1//account"),
            ("https://example.invalid/v1 path/", "https://example.invalid/v1%20path"),
            ("https://127.0.0.1:8443/api/", "https://127.0.0.1:8443/api"),
            ("https://[0:0:0:0:0:0:0:1]:8443/api/", "https://[::1]:8443/api")
        ]
        let reference = CredentialReference(keychainPath: "/private/synthetic.keychain-db", service: "synthetic", account: "test")
        for (raw, expected) in fixtures {
            let normalized = try AccountRecord.normalizedUpstreamBaseURL(raw)
            XCTAssertEqual(normalized, expected)
            XCTAssertEqual(try AccountRecord.normalizedUpstreamBaseURL(normalized), normalized)
            XCTAssertTrue(AccountRecord(id: UUID().uuidString, displayName: "Synthetic", upstreamBaseUrl: normalized, credential: reference).isValid)
        }
        for unsupported in ["http://example.invalid/v1", "https://user:password@example.invalid/v1", "https://example.invalid/v1?query", "https://example.invalid/v1#fragment", "https://example.invalid/a/../v1", "https://example.invalid/a/%2e%2E/v1", "https://127.1/api", "https://0127.0.0.1/api", "https://example.invalid/v1//", "https://example.invalid/bad%path", "https://example.invalid/back\\slash", "https://example.invalid/line\nend", "https://bücher.invalid/v1", "https://example.invalid:65536/api", "https://[::ffff:192.0.2.1]/api"] {
            XCTAssertThrowsError(try AccountRecord.normalizedUpstreamBaseURL(unsupported), unsupported) {
                XCTAssertEqual($0.localizedDescription, "Enter a canonical HTTPS endpoint without credentials, a query or a fragment.")
            }
        }
    }
    func testPreviewAndResultPreserveExplicitNulls() throws {
        let json = #"{"context":{"configPath":"/private/router.json","codexHome":"/private/codex","providerId":"synthetic","listenPort":43123},"configurationRevision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","setupState":"required","sourceKind":"missing","accounts":[],"routeAccounts":{"legacy":null},"incomingCredential":null,"defaultAccountId":null,"incomingHint":{"service":"synthetic","account":"desktop"},"originalDirect":{"id":"11111111-1111-4111-8111-111111111111","displayName":"Default","upstreamBaseUrl":"https://example.invalid/api","credential":null,"sourceAlias":null}}"#
        let preview = try JSONDecoder().decode(SetupPreview.self, from: Data(json.utf8))
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preview)) as? [String: Any])
        XCTAssertTrue(encoded["incomingCredential"] is NSNull)
        XCTAssertTrue(encoded["defaultAccountId"] is NSNull)
        XCTAssertTrue((encoded["routeAccounts"] as? [String: Any])?["legacy"] is NSNull)
        XCTAssertNil((encoded["incomingHint"] as? [String: Any])?["keychainPath"])
        let original = try XCTUnwrap(encoded["originalDirect"] as? [String: Any])
        XCTAssertTrue(original["credential"] is NSNull); XCTAssertTrue(original["sourceAlias"] is NSNull)
        let result = SetupCommitResult(context: preview.context, operationId: UUID().uuidString, setupState: "required", configurationRevision: preview.configurationRevision, checkpointPath: nil, changed: true)
        let resultJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        XCTAssertTrue(resultJSON["checkpointPath"] is NSNull)
    }

    func testChangesKeepRequiredNullAndOptionalAbsenceDistinct() throws {
        let reference = CredentialReference(keychainPath: "/private/synthetic.keychain-db", service: "synthetic", account: "test")
        let account = AccountRecord(id: UUID().uuidString, displayName: "Synthetic", upstreamBaseUrl: "https://example.invalid/api", credential: reference)
        let changes: [SetupChange] = [.createConfiguration(account: account, incomingCredential: nil, defaultAccountId: nil), .migrate(accounts: [account], incomingCredential: nil, defaultAccountId: nil), .addAccount(account: account), .setDefault(defaultAccountId: nil)]
        for change in changes {
            let bytes = try JSONEncoder().encode(change)
            XCTAssertEqual(try JSONDecoder().decode(SetupChange.self, from: bytes), change)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            if object["kind"] as? String == "create_configuration" || object["kind"] as? String == "migrate" { XCTAssertTrue(object["incomingCredential"] is NSNull) }
            else { XCTAssertNil(object["incomingCredential"]) }
        }
    }
}
