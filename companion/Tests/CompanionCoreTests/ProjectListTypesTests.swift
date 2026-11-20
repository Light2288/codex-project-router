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

    func testRunningPageRejectsConflictingAccountNamesAndInheritance() throws {
        for kind in ["override", "inherited", "legacy_inherited"] {
            var raw = ProjectListFixtures.page([ProjectListFixtures.ids[0]])
            var summary: [String: Any] = ["kind": kind, "account": ["id": ProjectListFixtures.account, "displayName": "Conflicting name"]]
            if kind != "inherited" { summary["routeAlias"] = "selected" }
            raw["entries"] = [["projectId": ProjectListFixtures.ids[0], "assignment": summary]]
            XCTAssertNil(ProjectListWire.page(raw, context: ProjectListFixtures.context, projectIDs: nil, expectedSnapshot: nil))
        }
        var raw = ProjectListFixtures.page([ProjectListFixtures.ids[0]])
        raw["entries"] = [["projectId":ProjectListFixtures.ids[0], "assignment":["kind":"inherited", "account":["id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee", "displayName":"Different account"]]]]
        XCTAssertNil(ProjectListWire.page(raw, context: ProjectListFixtures.context, projectIDs: nil, expectedSnapshot: nil))
        let nondefault = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
        raw["entries"] = ProjectListFixtures.ids.prefix(2).enumerated().map { offset, id in
            ["projectId":id, "assignment":["kind":"override", "routeAlias":"selected", "account":["id":nondefault, "displayName":offset == 0 ? "One name" : "Different name"]]]
        }
        XCTAssertNil(ProjectListWire.page(raw, context: ProjectListFixtures.context, projectIDs: nil, expectedSnapshot: nil))
    }

    // A malformed account/token/context or mixed page must never become runtime evidence.
    func testRunningPageValidatesExactShapeCoverageAndSnapshot() throws {
        let context = ProjectListFixtures.context
        let ids = ProjectListFixtures.ids
        let raw = ProjectListFixtures.page(ids)
        let page = try XCTUnwrap(ProjectListWire.page(raw, context: context, projectIDs: ids, expectedSnapshot: nil))
        XCTAssertEqual(page.entries.map(\.projectId), ids)
        XCTAssertEqual(page.defaultAccount.displayName, String(repeating: "😀", count: 80))
        XCTAssertEqual(page.entries[0].assignment.kind, "override")
        XCTAssertEqual(page.entries[1].assignment.kind, "target_missing")
        XCTAssertEqual(page.mode, .off)
        XCTAssertNotNil(ProjectListWire.page(raw, context: context, projectIDs: ids, expectedSnapshot: page.snapshot))
        var changed = raw; changed["runningRevision"] = String(repeating: "d", count: 64)
        XCTAssertNil(ProjectListWire.page(changed, context: context, projectIDs: ids, expectedSnapshot: page.snapshot))
        for entries in [Array((raw["entries"] as! [[String: Any]]).reversed()),
                        Array((raw["entries"] as! [[String: Any]]).dropLast()),
                        (raw["entries"] as! [[String: Any]]) + [ProjectListFixtures.entry("ffffffff-ffff-4fff-8fff-ffffffffffff")]] {
            var invalid = raw; invalid["entries"] = entries
            XCTAssertNil(ProjectListWire.page(invalid, context: context, projectIDs: ids, expectedSnapshot: nil))
        }
        for (key, value): (String, Any) in [
            ("extra", true), ("runningIdentity", "invalid"), ("mode", "unknown"),
            ("defaultAccount", ["id": ProjectListFixtures.account, "displayName": String(repeating: "😀", count: 81)]),
            ("context", ["configPath":"/wrong", "codexHome":context.codexHome, "providerId":context.providerId, "listenPort":context.listenPort])
        ] {
            var invalid = raw; invalid[key] = value
            XCTAssertNil(ProjectListWire.page(invalid, context: context, projectIDs: ids, expectedSnapshot: nil))
        }
        var duplicate = raw; duplicate["entries"] = [ProjectListFixtures.entry(ids[0]), ProjectListFixtures.entry(ids[0].uppercased())]
        XCTAssertNil(ProjectListWire.page(duplicate, context: context, projectIDs: nil, expectedSnapshot: nil))
        XCTAssertNotNil(ProjectListWire.page(ProjectListFixtures.page([]), context: context, projectIDs: [], expectedSnapshot: nil))
        var worstCase = raw; worstCase["entries"] = ids.map { ProjectListFixtures.entry($0) }
        XCTAssertLessThanOrEqual(try AssignmentFixtures.data(worstCase).count + 1, 16_384)
    }

}


internal enum ProjectListFixtures {
    static let context = ActivationContext(configPath: "/synthetic/config.json", codexHome: "/synthetic/home", providerId: "fixture", listenPort: 43129)
    static let account = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
    static let ids = (0..<8).map { "aaaaaaaa-aaaa-4aaa-8aaa-" + String(format: "%012d", $0) }
    static func entry(_ id: String, missing: Bool = false) -> [String: Any] {
        ["projectId": id, "assignment": missing ? ["kind": "target_missing", "routeAlias": String(repeating: "a", count: 64)] :
            ["kind": "override", "routeAlias": String(repeating: "a", count: 64), "account": ["id": account, "displayName": String(repeating: "😀", count: 80)]]]
    }
    static func page(_ ids: [String]) -> [String: Any] {
        ["context": ["configPath": context.configPath, "codexHome": context.codexHome, "providerId": context.providerId, "listenPort": context.listenPort],
         "runningRevision": String(repeating: "a", count: 64), "runningIdentity": String(repeating: "b", count: 64),
         "runningFingerprint": String(repeating: "c", count: 64), "mode": "off",
         "defaultAccount": ["id": account, "displayName": String(repeating: "😀", count: 80)],
         "entries": ids.enumerated().map { entry($0.element, missing: $0.offset == 1) }]
    }
}
