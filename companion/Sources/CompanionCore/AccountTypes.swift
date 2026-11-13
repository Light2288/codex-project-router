import Foundation
import Darwin

public enum AccountValidationError: Error, LocalizedError {
    case invalidUpstreamURL
    public var errorDescription: String? { "Enter a canonical HTTPS endpoint without credentials, a query or a fragment." }
}

public struct CredentialReference: Codable, Equatable, Hashable {
    public var keychainPath: String; public var service: String; public var account: String
    public init(keychainPath: String, service: String, account: String) { self.keychainPath = keychainPath; self.service = service; self.account = account }
    var isValid: Bool { [keychainPath, service, account].allSatisfy { !$0.isEmpty && $0.utf16.count <= 1024 && !$0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } } && keychainPath.hasPrefix("/") }
}

public struct AccountRecord: Codable, Equatable {
    public var id: String; public var displayName: String; public var upstreamBaseUrl: String; public var credential: CredentialReference
    public init(id: String, displayName: String, upstreamBaseUrl: String, credential: CredentialReference) { self.id = id; self.displayName = displayName; self.upstreamBaseUrl = upstreamBaseUrl; self.credential = credential }
    /// Normalize form input before constructing the account/receipt shared with Node.
    public static func normalizedUpstreamBaseURL(_ value: String) throws -> String {
        let authority = value.split(separator: "/", maxSplits: 3, omittingEmptySubsequences: false).prefix(3)
        guard !value.contains("\\"), !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              authority.allSatisfy({ $0.utf8.allSatisfy({ $0 < 128 }) }),
              value.range(of: "%(?![0-9A-Fa-f]{2})", options: .regularExpression) == nil,
              let url = URLComponents(string: value), url.scheme?.lowercased() == "https", let rawHost = url.encodedHost, !rawHost.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || (0...65535).contains(url.port!) else { throw AccountValidationError.invalidUpstreamURL }
        var host = rawHost.lowercased()
        if host.hasPrefix("["), host.hasSuffix("]") {
            var address = in6_addr(), bytes = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard String(host.dropFirst().dropLast()).withCString({ inet_pton(AF_INET6, $0, &address) }) == 1,
                  inet_ntop(AF_INET6, &address, &bytes, socklen_t(bytes.count)) != nil else { throw AccountValidationError.invalidUpstreamURL }
            let literal = String(cString: bytes)
            // inet_ntop and WHATWG spell mapped IPv4 addresses differently; never guess.
            guard !literal.contains(".") else { throw AccountValidationError.invalidUpstreamURL }
            host = "[\(literal)]"
        } else {
            guard host.range(of: "^[a-z0-9._-]+$", options: .regularExpression) != nil else { throw AccountValidationError.invalidUpstreamURL }
            let labels = host.split(separator: ".", omittingEmptySubsequences: false)
            let last = host.split(separator: ".").last ?? ""
            if last.allSatisfy({ $0.isNumber }) || last.hasPrefix("0x") {
                guard labels.count == 4, labels.allSatisfy({ label in
                    guard let byte = UInt8(label) else { return false }; return String(byte) == label
                }) else { throw AccountValidationError.invalidUpstreamURL }
            }
        }
        var path = url.percentEncodedPath
        // Reject parser-dependent dot traversal and repeated trailing separators; keep all other prefix bytes.
        guard !path.hasSuffix("//"), !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: {
            let segment = $0.lowercased().replacingOccurrences(of: "%2e", with: "."); return segment == "." || segment == ".."
        }) else { throw AccountValidationError.invalidUpstreamURL }
        if path.hasSuffix("/") { path.removeLast() }
        let port = url.port.flatMap { $0 == 443 ? nil : ":\($0)" } ?? ""
        return "https://\(host)\(port)\(path)"
    }
    var isValid: Bool {
        guard UUID(uuidString: id) != nil, credential.isValid, !displayName.isEmpty, displayName.unicodeScalars.count <= 80,
              displayName == displayName.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              (try? Self.normalizedUpstreamBaseURL(upstreamBaseUrl)) == upstreamBaseUrl else { return false }
        return true
    }
}

public struct SetupPreview: Codable, Equatable {
    public struct Account: Codable, Equatable {
        public var id: String; public var displayName: String; public var upstreamBaseUrl: String
        public var credential: CredentialReference?; public var sourceAlias: String?
        public init(id: String, displayName: String, upstreamBaseUrl: String, credential: CredentialReference?, sourceAlias: String?) { self.id = id; self.displayName = displayName; self.upstreamBaseUrl = upstreamBaseUrl; self.credential = credential; self.sourceAlias = sourceAlias }
        enum CodingKeys: String, CodingKey { case id, displayName, upstreamBaseUrl, credential, sourceAlias }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id); try c.encode(displayName, forKey: .displayName); try c.encode(upstreamBaseUrl, forKey: .upstreamBaseUrl)
            try c.encode(credential, forKey: .credential); try c.encode(sourceAlias, forKey: .sourceAlias)
        }
    }
    public struct IncomingHint: Codable, Equatable {
        public var service: String; public var account: String; public var keychainPath: String?
        public init(service: String, account: String, keychainPath: String? = nil) { self.service = service; self.account = account; self.keychainPath = keychainPath }
    }
    public var context: ActivationContext; public var configurationRevision: String; public var setupState: String; public var sourceKind: String
    public var accounts: [Account]; public var routeAccounts: [String: String?]; public var incomingCredential: CredentialReference?; public var defaultAccountId: String?
    public var incomingHint: IncomingHint?; public var originalDirect: Account
    public init(context: ActivationContext, configurationRevision: String, setupState: String, sourceKind: String, accounts: [Account], routeAccounts: [String: String?], incomingCredential: CredentialReference?, defaultAccountId: String?, incomingHint: IncomingHint?, originalDirect: Account) {
        self.context = context; self.configurationRevision = configurationRevision; self.setupState = setupState; self.sourceKind = sourceKind; self.accounts = accounts; self.routeAccounts = routeAccounts; self.incomingCredential = incomingCredential; self.defaultAccountId = defaultAccountId; self.incomingHint = incomingHint; self.originalDirect = originalDirect
    }
    enum CodingKeys: String, CodingKey { case context, configurationRevision, setupState, sourceKind, accounts, routeAccounts, incomingCredential, defaultAccountId, incomingHint, originalDirect }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(context, forKey: .context); try c.encode(configurationRevision, forKey: .configurationRevision); try c.encode(setupState, forKey: .setupState); try c.encode(sourceKind, forKey: .sourceKind)
        try c.encode(accounts, forKey: .accounts); try c.encode(routeAccounts, forKey: .routeAccounts); try c.encode(incomingCredential, forKey: .incomingCredential); try c.encode(defaultAccountId, forKey: .defaultAccountId); try c.encode(incomingHint, forKey: .incomingHint); try c.encode(originalDirect, forKey: .originalDirect)
    }
}

public enum SetupChange: Codable, Equatable {
    case createConfiguration(account: AccountRecord, incomingCredential: CredentialReference?, defaultAccountId: String?)
    case migrate(accounts: [AccountRecord], incomingCredential: CredentialReference?, defaultAccountId: String?)
    case addAccount(account: AccountRecord, incomingCredential: CredentialReference? = nil)
    case setDefault(defaultAccountId: String?, incomingCredential: CredentialReference? = nil)
    enum CodingKeys: String, CodingKey { case kind, account, accounts, incomingCredential, defaultAccountId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "create_configuration": self = .createConfiguration(account: try c.decode(AccountRecord.self, forKey: .account), incomingCredential: try c.decodeIfPresent(CredentialReference.self, forKey: .incomingCredential), defaultAccountId: try c.decodeIfPresent(String.self, forKey: .defaultAccountId))
        case "migrate": self = .migrate(accounts: try c.decode([AccountRecord].self, forKey: .accounts), incomingCredential: try c.decodeIfPresent(CredentialReference.self, forKey: .incomingCredential), defaultAccountId: try c.decodeIfPresent(String.self, forKey: .defaultAccountId))
        case "add_account": self = .addAccount(account: try c.decode(AccountRecord.self, forKey: .account), incomingCredential: try c.decodeIfPresent(CredentialReference.self, forKey: .incomingCredential))
        case "set_default": self = .setDefault(defaultAccountId: try c.decodeIfPresent(String.self, forKey: .defaultAccountId), incomingCredential: try c.decodeIfPresent(CredentialReference.self, forKey: .incomingCredential))
        default: throw CompanionError.protocolFailure
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .createConfiguration(account, incoming, defaultID):
            try c.encode("create_configuration", forKey: .kind); try c.encode(account, forKey: .account); try c.encode(incoming, forKey: .incomingCredential); try c.encode(defaultID, forKey: .defaultAccountId)
        case let .migrate(accounts, incoming, defaultID):
            try c.encode("migrate", forKey: .kind); try c.encode(accounts, forKey: .accounts); try c.encode(incoming, forKey: .incomingCredential); try c.encode(defaultID, forKey: .defaultAccountId)
        case let .addAccount(account, incoming):
            try c.encode("add_account", forKey: .kind); try c.encode(account, forKey: .account); try c.encodeIfPresent(incoming, forKey: .incomingCredential)
        case let .setDefault(defaultID, incoming):
            try c.encode("set_default", forKey: .kind); try c.encode(defaultID, forKey: .defaultAccountId); try c.encodeIfPresent(incoming, forKey: .incomingCredential)
        }
    }
}

public struct SetupCommitResult: Codable, Equatable {
    public var context: ActivationContext; public var operationId: String; public var setupState: String; public var configurationRevision: String; public var checkpointPath: String?; public var changed: Bool
    public init(context: ActivationContext, operationId: String, setupState: String, configurationRevision: String, checkpointPath: String?, changed: Bool) { self.context = context; self.operationId = operationId; self.setupState = setupState; self.configurationRevision = configurationRevision; self.checkpointPath = checkpointPath; self.changed = changed }
    enum CodingKeys: String, CodingKey { case context, operationId, setupState, configurationRevision, checkpointPath, changed }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(context, forKey: .context); try c.encode(operationId, forKey: .operationId); try c.encode(setupState, forKey: .setupState); try c.encode(configurationRevision, forKey: .configurationRevision); try c.encode(checkpointPath, forKey: .checkpointPath); try c.encode(changed, forKey: .changed)
    }
}

public struct SetupReceipt: Codable, Equatable {
    public enum Phase: String, Codable { case prepared, itemCreated = "item_created", committing, complete }
    public var schemaVersion: Int = 1
    public var operationId: String; public var accountId: String; public var reference: CredentialReference; public var account: AccountRecord; public var context: ActivationContext; public var phase: Phase
    public init(operationId: String, account: AccountRecord, context: ActivationContext, phase: Phase = .prepared) { self.operationId = operationId; self.accountId = account.id; self.reference = account.credential; self.account = account; self.context = context; self.phase = phase }
    var isValid: Bool { schemaVersion == 1 && UUID(uuidString: operationId) != nil && accountId == account.id && reference == account.credential && account.isValid }
}
