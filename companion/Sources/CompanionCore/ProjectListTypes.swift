import Foundation

/// Display evidence only; a known state requires the complete supported wire combination.
public struct ChatActivity: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case unarchived, noActiveChats = "no_active_chats", unknown
    }
    public enum Reason: String, Codable, Sendable {
        case metadataUnavailable = "metadata_unavailable", incompleteMetadata = "incomplete_metadata"
        case missingRecord = "missing_record", conflictingMembership = "conflicting_membership"
        case unsupportedMetadata = "unsupported_metadata", changedDuringRead = "changed_during_read"
        case projectUnresolved = "project_unresolved"
    }
    public let state: State
    public let reason: Reason?
    public init(state: State, reason: Reason? = nil) {
        if (state == .unknown) == (reason != nil) { self.state = state; self.reason = reason }
        else { self.state = .unknown; self.reason = .unsupportedMetadata }
    }
    private struct Key: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
        static let state = Key(stringValue: "state")!, reason = Key(stringValue: "reason")!
    }
    public init(from decoder: Decoder) throws {
        guard let values = try? decoder.container(keyedBy: Key.self),
              Set(values.allKeys.map(\.stringValue)) == ["state", "reason"],
              let state = try? values.decode(State.self, forKey: .state) else {
            self.init(state: .unknown, reason: .unsupportedMetadata); return
        }
        if state == .unknown, let reason = try? values.decode(Reason.self, forKey: .reason) {
            self.init(state: state, reason: reason)
        } else if state != .unknown, (try? values.decodeNil(forKey: .reason)) == true {
            self.init(state: state)
        } else { self.init(state: .unknown, reason: .unsupportedMetadata) }
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: Key.self)
        try values.encode(state, forKey: .state)
        if let reason { try values.encode(reason, forKey: .reason) }
        else { try values.encodeNil(forKey: .reason) }
    }
    var isValid: Bool { (state == .unknown) == (reason != nil) }
}


/// Comparison evidence for core consumers; display state must not expose these tokens.
public struct ProjectListSnapshotToken: Codable, Equatable, Sendable {
    public let runningRevision: String
    public let runningIdentity: String
    public let runningFingerprint: String
    public let mode: ProjectRoutingMode
    public init(runningRevision: String, runningIdentity: String, runningFingerprint: String, mode: ProjectRoutingMode) {
        self.runningRevision = runningRevision; self.runningIdentity = runningIdentity
        self.runningFingerprint = runningFingerprint; self.mode = mode
    }
}

public struct RunningProjectListPage: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let projectId: String
        public let assignment: AssignmentSummary
        public init(projectId: String, assignment: AssignmentSummary) { self.projectId = projectId; self.assignment = assignment }
    }
    public let context: ActivationContext
    public let runningRevision: String
    public let runningIdentity: String
    public let runningFingerprint: String
    public let mode: ProjectRoutingMode
    public let defaultAccount: AccountSummary
    public let entries: [Entry]
    public var snapshot: ProjectListSnapshotToken {
        ProjectListSnapshotToken(runningRevision: runningRevision, runningIdentity: runningIdentity, runningFingerprint: runningFingerprint, mode: mode)
    }
    public init(context: ActivationContext, runningRevision: String, runningIdentity: String, runningFingerprint: String,
                mode: ProjectRoutingMode, defaultAccount: AccountSummary, entries: [Entry]) {
        self.context = context; self.runningRevision = runningRevision; self.runningIdentity = runningIdentity
        self.runningFingerprint = runningFingerprint; self.mode = mode; self.defaultAccount = defaultAccount; self.entries = entries
    }
}

public struct RunningProjectListObservation: Equatable, Sendable {
    public let context: ActivationContext
    public let snapshot: ProjectListSnapshotToken
    public let defaultAccount: AccountSummary
    public let assignments: [String: AssignmentSummary]
    public init(context: ActivationContext, snapshot: ProjectListSnapshotToken, defaultAccount: AccountSummary, assignments: [String: AssignmentSummary]) {
        self.context = context; self.snapshot = snapshot; self.defaultAccount = defaultAccount; self.assignments = assignments
    }
}

/// Runtime display evidence with all comparison metadata removed.
public struct ProjectListRunningAssignments: Equatable, Sendable {
    public let mode: ProjectRoutingMode
    public let defaultAccount: AccountSummary
    public let assignments: [String: AssignmentSummary]
    public init(mode: ProjectRoutingMode, defaultAccount: AccountSummary, assignments: [String: AssignmentSummary]) {
        self.mode = mode; self.defaultAccount = defaultAccount; self.assignments = assignments
    }
}

public enum ProjectListRuntimeState: Equatable, Sendable {
    case unconfirmed, notRunning
    case observed(ProjectListRunningAssignments)
}

@MainActor public protocol ProjectListBackend: AnyObject {
    func readRunningProjectList(_ child: OwnedRouter, projectIDs: [String], deadline: Date) async throws -> RunningProjectListObservation
}

internal enum ProjectListWire {
    static func selection(_ ids: [String]) -> Bool {
        ids.count <= 8 && ids.allSatisfy(AssignmentWire.uuid) && Set(ids.map { $0.lowercased() }).count == ids.count
    }
    static func token(_ value: ProjectListSnapshotToken) -> Bool {
        [value.runningRevision, value.runningIdentity, value.runningFingerprint].allSatisfy(AssignmentWire.token)
    }
    static func page(_ object: Any, context: ActivationContext, projectIDs: [String]?, expectedSnapshot: ProjectListSnapshotToken?) -> RunningProjectListPage? {
        guard AssignmentWire.exact(object, ["context", "runningRevision", "runningIdentity", "runningFingerprint", "mode", "defaultAccount", "entries"]),
              let raw = object as? [String: Any], AssignmentWire.contextShape(raw["context"]!),
              AssignmentWire.exact(raw["defaultAccount"]!, ["id", "displayName"]),
              let entries = raw["entries"] as? [[String: Any]],
              entries.allSatisfy({ AssignmentWire.exact($0, ["projectId", "assignment"]) && AssignmentWire.summaryShape($0["assignment"]!) }),
              let value = AssignmentWire.decode(RunningProjectListPage.self, object), value.context == context, AssignmentWire.context(value.context),
              token(value.snapshot), AssignmentWire.uuid(value.defaultAccount.id), AssignmentWire.name(value.defaultAccount.displayName),
              selection(value.entries.map(\.projectId)), projectIDs.map({ value.entries.map(\.projectId) == $0 }) ?? true,
              expectedSnapshot.map({ value.snapshot == $0 }) ?? true else { return nil }
        var names = [value.defaultAccount.id.lowercased(): value.defaultAccount.displayName]
        for entry in value.entries {
            let summary = entry.assignment
            if ["inherited", "legacy_inherited"].contains(summary.kind), summary.account != value.defaultAccount { return nil }
            if let account = summary.account {
                let id = account.id.lowercased()
                if let name = names[id], name != account.displayName { return nil }
                names[id] = account.displayName
            }
        }
        return value
    }
}
