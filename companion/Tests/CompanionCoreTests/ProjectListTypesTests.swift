import XCTest
@testable import CompanionCore

final class ProjectListTypesTests: XCTestCase {
    private func entry(_ activity: Any? = nil) throws -> Inspection.Entry {
        var payload: [String: Any] = ["id": "11111111-1111-4111-8111-111111111111", "name": "Synthetic", "routeAlias": NSNull(), "routeState": "unmapped"]
        if let activity { payload["chatActivity"] = activity }
        return try JSONDecoder().decode(Inspection.Entry.self, from: JSONSerialization.data(withJSONObject: payload))
    }
    func testLegacyPayloadAndMissingObservationRemainBrowseable() throws {
        XCTAssertNil(try entry().chatActivity)
        XCTAssertNil(try entry(NSNull()).chatActivity)
        XCTAssertEqual(try entry(["state":"unarchived", "reason":NSNull()]).chatActivity?.state, .unarchived)
        XCTAssertEqual(try entry(["state":"no_active_chats", "reason":NSNull()]).chatActivity?.state, .noActiveChats)
    }
    func testUnsupportedOrMalformedActivityCannotEstablishKnownState() throws {
        for value: Any in [[], 7, "unarchived", [:], ["state":"future", "reason":NSNull()],
                          ["state":"unarchived"], ["state":"unarchived", "reason":"missing_record"],
                          ["state":"no_active_chats", "reason":3], ["state":"unknown", "reason":NSNull()],
                          ["state":"unknown", "reason":"future"], ["state":"unarchived", "reason":NSNull(), "chatId":"private"]] {
            let decoded = try entry(value)
            XCTAssertEqual(decoded.name, "Synthetic")
            XCTAssertEqual(decoded.chatActivity?.state, .unknown)
            XCTAssertEqual(decoded.chatActivity?.reason, .unsupportedMetadata)
        }
    }
    func testAllSupportedUnknownReasonsAndKnownStatesRoundTrip() throws {
        for reason in ["metadata_unavailable", "incomplete_metadata", "missing_record", "conflicting_membership", "unsupported_metadata", "changed_during_read", "project_unresolved"] {
            let value = try XCTUnwrap(entry(["state":"unknown", "reason":reason]).chatActivity)
            XCTAssertEqual(value.state, .unknown)
            let roundTrip = try JSONDecoder().decode(ChatActivity.self, from: JSONEncoder().encode(value))
            XCTAssertEqual(roundTrip, value)
        }
        let known = try XCTUnwrap(entry(["state":"unarchived", "reason":NSNull()]).chatActivity)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(known)) as? [String: Any])
        XCTAssertTrue(json["reason"] is NSNull)
    }
    func testActivityToleranceDoesNotRelaxCatalogFields() throws {
        let malformed = Data(#"{"id":"id","name":7,"routeAlias":null,"routeState":"unmapped","chatActivity":[]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Inspection.Entry.self, from: malformed))
    }
    @MainActor func testMalformedObservationDoesNotBreakProcessBackendBrowsing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("activity browsing \(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let resources = root.appendingPathComponent("resources")
        try FileManager.default.createDirectory(at: resources.appendingPathComponent("src"), withIntermediateDirectories: true)
        for name in ["companion-cli.js", "cli.js", "managed-serve.js"] { try Data().write(to: resources.appendingPathComponent("src/\(name)")) }
        let node = root.appendingPathComponent("selected node")
        let script = """
        #!/usr/bin/python3
        import json,sys
        if sys.argv[1:] == ['--version']:
            print('v24.10.0');sys.exit(0)
        json.load(sys.stdin)
        print(json.dumps(dict(schemaVersion=1,ok=True,result=dict(configuration=dict(state='missing'),provider=dict(state='unavailable',recoveryRequired=False,proxyReady=None,recordPhase='none'),catalog=dict(state='ready',entries=[dict(id='11111111-1111-4111-8111-111111111111',name='Synthetic',routeAlias=None,routeState='unmapped',chatActivity=['invalid'])])))))
        """
        try script.write(to: node, atomically: false, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: node.path)
        let backend = ProcessBackend(resourcesURL: resources, nodeExecutable: node)
        let inspected = try await backend.inspect(configPath: nil, browseHome: root)
        XCTAssertEqual(inspected.catalog.state, "ready")
        XCTAssertEqual(inspected.catalog.entries.first?.chatActivity?.state, .unknown)
        XCTAssertFalse(backend.mutationRequiresReconciliation)
    }

}
