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
