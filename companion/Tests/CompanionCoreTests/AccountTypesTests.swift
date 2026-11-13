import XCTest
@testable import CompanionCore

final class AccountTypesTests: XCTestCase {
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
