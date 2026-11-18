import Foundation

public struct AssignmentSummary: Codable, Equatable, Sendable {
    public var kind: String
    public var account: AccountSummary?
    public var routeAlias: String?

}

public struct AssignmentChange: Codable, Equatable, Sendable {
    public var configPath: String
    public var expectedContext: ActivationContext
    public var expectedSavedRevision: String
    public var expectedConfigurationIdentity: String
    public var expectedRunningRevision: String?
    public var expectedCatalogRevision: String
    public var operationId: String
    public var projectId: String
    public var accountId: String?
    public init(configPath: String, expectedContext: ActivationContext, expectedSavedRevision: String, expectedConfigurationIdentity: String, expectedRunningRevision: String? = nil, expectedCatalogRevision: String, operationId: String, projectId: String, accountId: String? = nil) {
        self.configPath = configPath
        self.expectedContext = expectedContext
        self.expectedSavedRevision = expectedSavedRevision
        self.expectedConfigurationIdentity = expectedConfigurationIdentity
        self.expectedRunningRevision = expectedRunningRevision
        self.expectedCatalogRevision = expectedCatalogRevision
        self.operationId = operationId
        self.projectId = projectId
        self.accountId = accountId
    }
    private enum CodingKeys: String, CodingKey { case configPath, expectedContext, expectedSavedRevision, expectedConfigurationIdentity, expectedRunningRevision, expectedCatalogRevision, operationId, projectId, accountId }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(configPath, forKey: .configPath)
        try values.encode(expectedContext, forKey: .expectedContext)
        try values.encode(expectedSavedRevision, forKey: .expectedSavedRevision)
        try values.encode(expectedConfigurationIdentity, forKey: .expectedConfigurationIdentity)
        try values.encodeIfPresent(expectedRunningRevision, forKey: .expectedRunningRevision)
        try values.encode(expectedCatalogRevision, forKey: .expectedCatalogRevision)
        try values.encode(operationId, forKey: .operationId)
        try values.encode(projectId, forKey: .projectId)
        try values.encode(accountId, forKey: .accountId)
    }
}

public struct AssignmentIntent: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var operationId: String
    public var context: ActivationContext
    public var projectId: String
    public var accountId: String?
    public var checkpointName: String
    public var beforeRevision: String
    public var beforeIdentity: String
    public var candidateRevision: String
    public var candidateIdentity: String
    private enum CodingKeys: String, CodingKey { case schemaVersion, operationId, context, projectId, accountId, checkpointName, beforeRevision, beforeIdentity, candidateRevision, candidateIdentity }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(operationId, forKey: .operationId)
        try values.encode(context, forKey: .context)
        try values.encode(projectId, forKey: .projectId)
        try values.encode(accountId, forKey: .accountId)
        try values.encode(checkpointName, forKey: .checkpointName)
        try values.encode(beforeRevision, forKey: .beforeRevision)
        try values.encode(beforeIdentity, forKey: .beforeIdentity)
        try values.encode(candidateRevision, forKey: .candidateRevision)
        try values.encode(candidateIdentity, forKey: .candidateIdentity)
    }
}

public struct AssignmentAttempt: Codable, Equatable, Sendable {
    public var operationId: String
    public var projectId: String
    public var outcome: String
    public var code: String?
    public var beforeRevision: String?
    public var beforeIdentity: String?
    public var candidateRevision: String?
    public var candidateIdentity: String?
    private enum CodingKeys: String, CodingKey { case operationId, projectId, outcome, code, beforeRevision, beforeIdentity, candidateRevision, candidateIdentity }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(operationId, forKey: .operationId)
        try values.encode(projectId, forKey: .projectId)
        try values.encode(outcome, forKey: .outcome)
        try values.encode(code, forKey: .code)
        try values.encode(beforeRevision, forKey: .beforeRevision)
        try values.encode(beforeIdentity, forKey: .beforeIdentity)
        try values.encode(candidateRevision, forKey: .candidateRevision)
        try values.encode(candidateIdentity, forKey: .candidateIdentity)
    }
}

public struct AssignmentState: Codable, Equatable, Sendable {
    public var context: ActivationContext
    public var savedState: String
    public var savedRevision: String?
    public var savedIdentity: String?
    public var savedFingerprint: String?
    public var catalogRevision: String?
    public var runningRevision: String?
    public var runningIdentity: String?
    public var runningFingerprint: String?
    public var mode: ProjectRoutingMode?
    public var projectId: String?
    public var savedAssignment: AssignmentSummary?
    public var runningAssignment: AssignmentSummary?
    public var intent: AssignmentIntent?
    public var lastAttempt: AssignmentAttempt?
    private enum CodingKeys: String, CodingKey { case context, savedState, savedRevision, savedIdentity, savedFingerprint, catalogRevision, runningRevision, runningIdentity, runningFingerprint, mode, projectId, savedAssignment, runningAssignment, intent, lastAttempt }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(context, forKey: .context)
        try values.encode(savedState, forKey: .savedState)
        try values.encode(savedRevision, forKey: .savedRevision)
        try values.encode(savedIdentity, forKey: .savedIdentity)
        try values.encode(savedFingerprint, forKey: .savedFingerprint)
        try values.encode(catalogRevision, forKey: .catalogRevision)
        try values.encode(runningRevision, forKey: .runningRevision)
        try values.encode(runningIdentity, forKey: .runningIdentity)
        try values.encode(runningFingerprint, forKey: .runningFingerprint)
        try values.encode(mode, forKey: .mode)
        try values.encode(projectId, forKey: .projectId)
        try values.encode(savedAssignment, forKey: .savedAssignment)
        try values.encode(runningAssignment, forKey: .runningAssignment)
        try values.encode(intent, forKey: .intent)
        try values.encode(lastAttempt, forKey: .lastAttempt)
    }
}

public struct AssignmentCommit: Codable, Equatable, Sendable {
    public var context: ActivationContext
    public var operationId: String
    public var projectId: String
    public var changed: Bool
    public var beforeRevision: String
    public var candidateRevision: String
    public var savedRevision: String
    public var beforeIdentity: String
    public var candidateIdentity: String
    public var savedIdentity: String
    public var before: AssignmentSummary
    public var after: AssignmentSummary
    public var checkpointPath: String?
    public var intent: AssignmentIntent?
    public var runningRevision: String?
    public var runningIdentity: String?
    public var runningFingerprint: String?
    private enum CodingKeys: String, CodingKey { case context, operationId, projectId, changed, beforeRevision, candidateRevision, savedRevision, beforeIdentity, candidateIdentity, savedIdentity, before, after, checkpointPath, intent, runningRevision, runningIdentity, runningFingerprint }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(context, forKey: .context)
        try values.encode(operationId, forKey: .operationId)
        try values.encode(projectId, forKey: .projectId)
        try values.encode(changed, forKey: .changed)
        try values.encode(beforeRevision, forKey: .beforeRevision)
        try values.encode(candidateRevision, forKey: .candidateRevision)
        try values.encode(savedRevision, forKey: .savedRevision)
        try values.encode(beforeIdentity, forKey: .beforeIdentity)
        try values.encode(candidateIdentity, forKey: .candidateIdentity)
        try values.encode(savedIdentity, forKey: .savedIdentity)
        try values.encode(before, forKey: .before)
        try values.encode(after, forKey: .after)
        try values.encode(checkpointPath, forKey: .checkpointPath)
        try values.encode(intent, forKey: .intent)
        try values.encode(runningRevision, forKey: .runningRevision)
        try values.encode(runningIdentity, forKey: .runningIdentity)
        try values.encode(runningFingerprint, forKey: .runningFingerprint)
    }
}

@MainActor public protocol ProjectAssignmentBackend: AnyObject {
    func readAssignment(_ child: OwnedRouter, projectID: String?, operationID: String?) async throws -> AssignmentState
    func applyAssignment(_ change: AssignmentChange, to child: OwnedRouter) async throws -> AssignmentCommit
    func readStoppedAssignment(context: ActivationContext, projectID: String, operationID: String?) async throws -> AssignmentState
    func saveStoppedAssignment(_ change: AssignmentChange) async throws -> AssignmentCommit
    func probeAssignmentPort(_ context: ActivationContext) async -> StopOutcome.PortState
}

// Tokens and immutable evidence are compared privately, never formatted into user-facing errors.
internal enum AssignmentWire {
    static let codes: Set<String> = ["ASSIGNMENT_INVALID", "ASSIGNMENT_CONFLICT", "ASSIGNMENT_UNAVAILABLE", "ASSIGNMENT_UNCERTAIN"]
    static func uuid(_ value: String) -> Bool { value.range(of: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", options: .regularExpression) != nil }
    static func token(_ value: String) -> Bool { value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil }
    static func name(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.count <= 80 && value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
        !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
    static func context(_ value: ActivationContext) -> Bool {
        [value.configPath, value.codexHome].allSatisfy { $0.hasPrefix("/") && !$0.contains("\0") } &&
        (1...65535).contains(value.listenPort) && value.providerId.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }
    static func change(_ value: AssignmentChange, live: Bool) -> Bool {
        context(value.expectedContext) && value.configPath == value.expectedContext.configPath &&
        [value.expectedSavedRevision, value.expectedConfigurationIdentity, value.expectedCatalogRevision].allSatisfy(token) &&
        uuid(value.operationId) && uuid(value.projectId) && (value.accountId.map(uuid) ?? true) &&
        (!live || value.expectedRunningRevision.map(token) == true)
    }
    static func exact(_ value: Any, _ required: Set<String>, optional: Set<String> = []) -> Bool {
        guard let object = value as? [String: Any] else { return false }
        return required.isSubset(of: Set(object.keys)) && Set(object.keys).isSubset(of: required.union(optional))
    }
    static func decode<T: Decodable>(_ type: T.Type, _ object: Any) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func summary(_ value: AssignmentSummary) -> Bool {
        let accountValid = value.account.map { uuid($0.id) && name($0.displayName) } ?? true
        guard accountValid, value.routeAlias.map({ $0.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$", options: .regularExpression) != nil }) ?? true else { return false }
        switch value.kind {
        case "inherited": return value.account != nil && value.routeAlias == nil
        case "legacy_inherited", "override": return value.account != nil && value.routeAlias != nil
        case "target_missing": return value.account == nil && value.routeAlias != nil
        default: return false
        }
    }
    static func summaryShape(_ object: Any) -> Bool {
        guard exact(object, ["kind"], optional: ["account", "routeAlias"]), let value = object as? [String: Any] else { return false }
        if let account = value["account"], !exact(account, ["id", "displayName"]) { return false }
        if let alias = value["routeAlias"], !(alias is String) { return false }
        return decode(AssignmentSummary.self, object).map(summary) == true
    }
    static func intentShape(_ object: Any) -> Bool {
        guard exact(object, ["schemaVersion", "operationId", "context", "projectId", "accountId", "checkpointName", "beforeRevision", "beforeIdentity", "candidateRevision", "candidateIdentity"]),
              let value = decode(AssignmentIntent.self, object), contextShape((object as! [String: Any])["context"]!) else { return false }
        return value.schemaVersion == 1 && context(value.context) && uuid(value.operationId) && uuid(value.projectId) &&
            (value.accountId.map(uuid) ?? true) && value.checkpointName == "assignment-checkpoint-\(value.operationId.lowercased()).json" &&
            [value.beforeRevision, value.beforeIdentity, value.candidateRevision, value.candidateIdentity].allSatisfy(token)
    }
    static func contextShape(_ object: Any) -> Bool { exact(object, ["configPath", "codexHome", "providerId", "listenPort"]) }
    static func nullableShape(_ object: Any, _ check: (Any) -> Bool) -> Bool { object is NSNull || check(object) }
    static func attemptShape(_ object: Any) -> Bool {
        guard exact(object, ["operationId", "projectId", "outcome", "code", "beforeRevision", "beforeIdentity", "candidateRevision", "candidateIdentity"]),
              let value = decode(AssignmentAttempt.self, object) else { return false }
        return uuid(value.operationId) && uuid(value.projectId) && ["applied", "rejected", "uncertain"].contains(value.outcome) &&
            (value.code.map { codes.contains($0) } ?? (value.outcome == "applied")) &&
            [value.beforeRevision, value.beforeIdentity, value.candidateRevision, value.candidateIdentity].allSatisfy { $0.map(token) ?? true } &&
            ((value.beforeRevision == nil) == (value.beforeIdentity == nil)) && ((value.candidateRevision == nil) == (value.candidateIdentity == nil)) &&
            (value.candidateRevision == nil || value.beforeRevision != nil) &&
            (value.outcome != "rejected" || value.code != "ASSIGNMENT_UNCERTAIN") &&
            (value.outcome != "applied" || (value.code == nil && value.beforeRevision != nil && value.candidateRevision != nil)) &&
            (value.outcome != "uncertain" || value.code == "ASSIGNMENT_UNCERTAIN")
    }
    static func state(_ object: Any, context expected: ActivationContext, projectID: String?, operationID: String?, live: Bool) -> AssignmentState? {
        guard exact(object, ["context", "savedState", "savedRevision", "savedIdentity", "savedFingerprint", "catalogRevision", "runningRevision", "runningIdentity", "runningFingerprint", "mode", "projectId", "savedAssignment", "runningAssignment", "intent", "lastAttempt"]),
              let raw = object as? [String: Any], contextShape(raw["context"]!),
              nullableShape(raw["savedAssignment"]!, summaryShape), nullableShape(raw["runningAssignment"]!, summaryShape),
              nullableShape(raw["intent"]!, intentShape), nullableShape(raw["lastAttempt"]!, attemptShape),
              let value = decode(AssignmentState.self, object), value.context == expected, context(value.context), value.projectId == projectID,
              projectID.map(uuid) ?? true, ["ready", "unavailable", "conflict"].contains(value.savedState),
              [value.savedRevision, value.savedIdentity, value.savedFingerprint, value.catalogRevision, value.runningRevision, value.runningIdentity, value.runningFingerprint].allSatisfy({ $0.map(token) ?? true }) else { return nil }
        if value.savedState == "ready" {
            guard value.savedRevision != nil, value.savedIdentity != nil, value.savedFingerprint != nil,
                  (projectID == nil) == (value.savedAssignment == nil) else { return nil }
        } else if value.savedRevision != nil || value.savedIdentity != nil || value.savedFingerprint != nil || value.catalogRevision != nil || value.savedAssignment != nil || value.intent != nil { return nil }
        if live {
            guard value.runningRevision != nil, value.runningIdentity != nil, value.runningFingerprint != nil, value.mode != nil,
                  (projectID == nil) == (value.runningAssignment == nil) else { return nil }
        } else if value.runningRevision != nil || value.runningIdentity != nil || value.runningFingerprint != nil || value.mode != nil || value.runningAssignment != nil || value.lastAttempt != nil { return nil }
        if let intent = value.intent {
            guard intent.context == expected, intent.operationId == operationID, projectID == nil || intent.projectId == projectID else { return nil }
        }
        if let attempt = value.lastAttempt {
            guard attempt.operationId == operationID, projectID == nil || attempt.projectId == projectID else { return nil }
            if let intent = value.intent {
                guard attempt.beforeRevision == intent.beforeRevision, attempt.beforeIdentity == intent.beforeIdentity,
                      attempt.candidateRevision == intent.candidateRevision, attempt.candidateIdentity == intent.candidateIdentity else { return nil }
            }
        }
        return value
    }
    static func commitShape(_ object: Any, live: Bool) -> Bool {
        guard exact(object, ["context", "operationId", "projectId", "changed", "beforeRevision", "candidateRevision", "savedRevision", "beforeIdentity", "candidateIdentity", "savedIdentity", "before", "after", "checkpointPath", "intent", "runningRevision", "runningIdentity", "runningFingerprint"]),
              let raw = object as? [String: Any], contextShape(raw["context"]!), summaryShape(raw["before"]!), summaryShape(raw["after"]!), nullableShape(raw["intent"]!, intentShape),
              let value = decode(AssignmentCommit.self, object), context(value.context), uuid(value.operationId), uuid(value.projectId),
              ["inherited", "override"].contains(value.after.kind),
              value.savedRevision == value.candidateRevision, value.savedIdentity == value.candidateIdentity,
              [value.beforeRevision, value.beforeIdentity, value.candidateRevision, value.candidateIdentity, value.savedRevision, value.savedIdentity].allSatisfy(token),
              [value.runningRevision, value.runningIdentity, value.runningFingerprint].allSatisfy({ $0.map(token) ?? true }) else { return false }
        if live {
            guard value.runningRevision == value.candidateRevision, value.runningIdentity == value.candidateIdentity, value.runningFingerprint != nil else { return false }
        } else if value.runningRevision != nil || value.runningIdentity != nil || value.runningFingerprint != nil { return false }
        if value.changed {
            guard let intent = value.intent, intent.context == value.context, intent.operationId == value.operationId,
                  intent.projectId == value.projectId,
                  intent.accountId == (value.after.kind == "override" ? value.after.account?.id : nil),
                  intent.beforeRevision == value.beforeRevision, intent.beforeIdentity == value.beforeIdentity,
                  intent.candidateRevision == value.candidateRevision, intent.candidateIdentity == value.candidateIdentity,
                  value.checkpointPath == URL(fileURLWithPath: value.context.configPath).deletingLastPathComponent().appendingPathComponent(intent.checkpointName).path else { return false }
        } else {
            guard value.intent == nil, value.checkpointPath == nil, value.beforeRevision == value.candidateRevision,
                  value.beforeIdentity == value.candidateIdentity, value.before == value.after else { return false }
        }
        return true
    }
    static func commit(_ object: Any, change: AssignmentChange, live: Bool) -> AssignmentCommit? {
        guard commitShape(object, live: live), let value = decode(AssignmentCommit.self, object),
              value.context == change.expectedContext, value.operationId == change.operationId, value.projectId == change.projectId,
              value.beforeRevision == change.expectedSavedRevision, value.beforeIdentity == change.expectedConfigurationIdentity else { return nil }
        if let accountID = change.accountId {
            guard value.after.kind == "override", value.after.account?.id == accountID else { return nil }
        } else if value.after.kind != "inherited" { return nil }
        return value
    }
    static func reconciles(_ state: AssignmentState, change: AssignmentChange, live: Bool) -> Bool {
        guard state.context == change.expectedContext, state.projectId == change.projectId, state.savedState == "ready" else { return false }
        let before = state.savedRevision == change.expectedSavedRevision && state.savedIdentity == change.expectedConfigurationIdentity
        var candidate = false
        if let intent = state.intent {
            guard intent.operationId == change.operationId, intent.projectId == change.projectId, intent.accountId == change.accountId,
                  intent.beforeRevision == change.expectedSavedRevision, intent.beforeIdentity == change.expectedConfigurationIdentity else { return false }
            candidate = state.savedRevision == intent.candidateRevision && state.savedIdentity == intent.candidateIdentity
        } else if let attempt = state.lastAttempt {
            guard attempt.operationId == change.operationId, attempt.projectId == change.projectId,
                  attempt.beforeRevision == nil || (attempt.beforeRevision == change.expectedSavedRevision && attempt.beforeIdentity == change.expectedConfigurationIdentity) else { return false }
            if attempt.beforeRevision == change.expectedSavedRevision && attempt.beforeIdentity == change.expectedConfigurationIdentity {
                candidate = state.savedRevision == attempt.candidateRevision && state.savedIdentity == attempt.candidateIdentity
            }
        }
        guard before || candidate else { return false }
        return !live || (state.runningRevision == state.savedRevision && state.runningIdentity == state.savedIdentity && state.runningFingerprint == state.savedFingerprint)
    }
}
