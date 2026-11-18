import XCTest
@testable import CompanionCore

final class AssignmentTypesTests: XCTestCase {
    func testAssignmentTypesEncodeExplicitInheritanceNull() throws {
        let change = AssignmentFixtures.change()
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(change)) as? [String: Any])
        XCTAssertTrue(command.keys.contains("accountId"))
        XCTAssertTrue(command["accountId"] is NSNull)
        let intent = try JSONDecoder().decode(AssignmentIntent.self, from: AssignmentFixtures.data(AssignmentFixtures.intent(change)))
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(intent)) as? [String: Any])
        XCTAssertTrue(encoded["accountId"] is NSNull)
    }
    func testSummaryRejectsMalformedAliasesAndUnboundedNames() throws {
        let account: [String: Any] = ["id": AssignmentFixtures.account, "displayName": "Synthetic"]
        for alias in ["bad/alias", "_leading", String(repeating: "a", count: 65)] {
            XCTAssertFalse(AssignmentWire.summaryShape(["kind": "override", "account": account, "routeAlias": alias]), alias)
        }
        for name in ["", " trailing ", "line\nfeed", String(repeating: "a", count: 81)] {
            XCTAssertFalse(AssignmentWire.summaryShape(["kind": "inherited", "account": ["id": AssignmentFixtures.account, "displayName": name]]))
        }
        XCTAssertTrue(AssignmentWire.summaryShape(["kind": "override", "account": account, "routeAlias": "Route_1-a"]))
    }

    func testAssignmentStatePreservesRequiredNullFields() throws {
        let change = AssignmentFixtures.change()
        let state = try JSONDecoder().decode(AssignmentState.self, from: AssignmentFixtures.data(AssignmentFixtures.state(change, stopped: true)))
        let encoded = try AssignmentFixtures.object(state)
        for key in ["runningRevision", "runningIdentity", "runningFingerprint", "runningAssignment", "mode", "intent", "lastAttempt"] {
            XCTAssertTrue(encoded[key] is NSNull, key)
        }
        let commit = try JSONDecoder().decode(AssignmentCommit.self, from: AssignmentFixtures.data(AssignmentFixtures.commit(change, stopped: true)))
        let encodedCommit = try AssignmentFixtures.object(commit)
        for key in ["runningRevision", "runningIdentity", "runningFingerprint"] { XCTAssertTrue(encodedCommit[key] is NSNull, key) }
    }

    func testAttemptRequiresConsistentOutcomeAndCompletePairs() {
        let base: [String: Any] = ["operationId": UUID().uuidString, "projectId": AssignmentFixtures.project,
            "outcome": "uncertain", "code": "ASSIGNMENT_UNCERTAIN", "beforeRevision": NSNull(), "beforeIdentity": NSNull(),
            "candidateRevision": NSNull(), "candidateIdentity": NSNull()]
        XCTAssertTrue(AssignmentWire.attemptShape(base))
        var rejected = base; rejected["outcome"] = "rejected"
        XCTAssertFalse(AssignmentWire.attemptShape(rejected))
        var candidateWithoutBefore = base
        candidateWithoutBefore["candidateRevision"] = AssignmentFixtures.candidate
        candidateWithoutBefore["candidateIdentity"] = AssignmentFixtures.candidateIdentity
        XCTAssertFalse(AssignmentWire.attemptShape(candidateWithoutBefore))
    }

    func testAssignmentSafeErrorMessages() {
        XCTAssertEqual(CompanionError.assignmentUnavailable.localizedDescription, "Project assignment editing is unavailable.")
        XCTAssertEqual(CompanionError.assignmentUncertain.localizedDescription, "The assignment outcome is unconfirmed. Refresh to check its state.")
        XCTAssertEqual(CompanionError.assignmentConflict.localizedDescription, "Project assignment information changed. Refresh before editing.")
    }
}

enum AssignmentFixtures {
    static let project = "22222222-2222-4222-8222-222222222222"
    static let account = "11111111-1111-4111-8111-111111111111"
    static let token = String(repeating: "a", count: 64)
    static let identity = String(repeating: "b", count: 64)
    static let candidate = String(repeating: "c", count: 64)
    static let candidateIdentity = String(repeating: "d", count: 64)
    static let fingerprint = String(repeating: "e", count: 64)
    static let catalog = String(repeating: "f", count: 64)
    static let context = ActivationContext(configPath: "/synthetic/config.json", codexHome: "/synthetic/home", providerId: "fixture", listenPort: 43129)
    static func data(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
    static func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    static func change(context: ActivationContext = context) -> AssignmentChange {
        AssignmentChange(configPath: context.configPath, expectedContext: context, expectedSavedRevision: token,
            expectedConfigurationIdentity: identity, expectedRunningRevision: token, expectedCatalogRevision: catalog,
            operationId: UUID().uuidString, projectId: project, accountId: nil)
    }
    static let summary: [String: Any] = ["kind": "inherited", "account": ["id": account, "displayName": "Synthetic"]]
    static func state(_ change: AssignmentChange, applied: Bool = false, stopped: Bool = false) throws -> [String: Any] {
        let revision = applied ? candidate : token, id = applied ? candidateIdentity : identity
        return ["context": try object(change.expectedContext), "savedState": "ready", "savedRevision": revision,
            "savedIdentity": id, "savedFingerprint": fingerprint, "catalogRevision": catalog,
            "runningRevision": stopped ? NSNull() : revision, "runningIdentity": stopped ? NSNull() : id,
            "runningFingerprint": stopped ? NSNull() : fingerprint, "mode": stopped ? NSNull() : "off",
            "projectId": change.projectId, "savedAssignment": summary, "runningAssignment": stopped ? NSNull() : summary,
            "intent": applied ? intent(change) : NSNull(), "lastAttempt": NSNull()]
    }
    static func intent(_ change: AssignmentChange) -> [String: Any] {
        ["schemaVersion": 1, "operationId": change.operationId, "context": try! object(change.expectedContext),
         "projectId": change.projectId, "accountId": change.accountId as Any? ?? NSNull(),
         "checkpointName": "assignment-checkpoint-\(change.operationId.lowercased()).json", "beforeRevision": token,
         "beforeIdentity": identity, "candidateRevision": candidate, "candidateIdentity": candidateIdentity]
    }
    static func commit(_ change: AssignmentChange, stopped: Bool = false) throws -> [String: Any] {
        ["context": try object(change.expectedContext), "operationId": change.operationId, "projectId": change.projectId,
         "changed": true, "beforeRevision": token, "candidateRevision": candidate, "savedRevision": candidate,
         "beforeIdentity": identity, "candidateIdentity": candidateIdentity, "savedIdentity": candidateIdentity,
         "before": summary, "after": summary, "checkpointPath": "/synthetic/assignment-checkpoint-\(change.operationId.lowercased()).json",
         "intent": intent(change), "runningRevision": stopped ? NSNull() : candidate,
         "runningIdentity": stopped ? NSNull() : candidateIdentity, "runningFingerprint": stopped ? NSNull() : fingerprint]
    }
}
