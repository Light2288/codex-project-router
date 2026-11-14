import Foundation
import Security
import Darwin

public enum KeychainError: Error, Equatable, LocalizedError {
    case invalidReference, invalidSecret, discardedSecret, ambiguous, unsupported, nativeStatus(OSStatus)
    public var errorDescription: String? {
        switch self {
        case .invalidReference: return "The credential reference is invalid."
        case .invalidSecret: return "Enter a token of 1–8192 printable ASCII characters without whitespace."
        case .discardedSecret: return "The entered credential has already been discarded."
        case .ambiguous: return "More than one matching Keychain item was found. Select an exact item."
        case .unsupported: return "This Keychain or item is not supported by the configured reader."
        case .nativeStatus(let status): return "The Keychain operation did not complete (status \(status))."
        }
    }
}

/// The only native-memory owner of entered bytes. It cannot be encoded or interpolated as a token.
public final class KeychainSecret: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private var bytes: [UInt8]
    private let lock = NSLock()
    private var discarded = false
    public init(_ value: String) throws {
        guard (1...8192).contains(value.utf8.count), value.utf8.allSatisfy({ (33...126).contains($0) }) else { throw KeychainError.invalidSecret }
        bytes = Array(value.utf8)
    }
    deinit { discard() }
    public var description: String { "[private credential]" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
    public var isDiscarded: Bool { lock.lock(); defer { lock.unlock() }; return discarded }
    public func discard() {
        lock.lock(); defer { lock.unlock() }
        bytes.withUnsafeMutableBytes { raw in if let base = raw.baseAddress { _ = memset_s(base, raw.count, 0, raw.count) } }
        bytes.removeAll(keepingCapacity: false); discarded = true
    }
    func withBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        guard !discarded else { throw KeychainError.discardedSecret }
        return try bytes.withUnsafeBytes(body)
    }
}

protocol KeychainSecurity {
    func searchListPaths() throws -> [String]
    func defaultKeychainPath() throws -> String
    func metadata(keychainPath: String, query: [String: Any]) throws -> [[String: Any]]
    func create(reference: CredentialReference, secret: UnsafeRawBufferPointer, trustedApplicationPaths: [String]) throws
}

public final class KeychainStore {
    private let security: KeychainSecurity
    private let companionPath: String
    private let queue = DispatchQueue(label: "codex.router.keychain", qos: .userInitiated)
    public convenience init() { self.init(security: NativeKeychainSecurity(), companionPath: Bundle.main.executableURL?.path ?? "") }
    init(security: KeychainSecurity, companionPath: String) { self.security = security; self.companionPath = companionPath }

    public func defaultKeychainPath() async throws -> String {
        try await execute {
            let path = try self.security.defaultKeychainPath()
            guard path.hasPrefix("/"), !path.contains("\0") else { throw KeychainError.unsupported }
            return path
        }
    }
    public func listMetadata(service: String? = nil, account: String? = nil, keychainPath: String? = nil) async throws -> [CredentialReference] {
        try await execute { try self.metadata(service: service, account: account, keychainPath: keychainPath) }
    }
    public func lookup(reference: CredentialReference) async throws -> CredentialReference? {
        guard reference.isValid else { throw KeychainError.invalidReference }
        guard let found = try await lookup(service: reference.service, account: reference.account, keychainPath: reference.keychainPath) else { return nil }
        guard found == reference else { throw KeychainError.unsupported }
        return found
    }
    public func lookup(service: String, account: String, keychainPath: String? = nil) async throws -> CredentialReference? {
        let results = try await listMetadata(service: service, account: account, keychainPath: keychainPath)
        guard results.count <= 1 else { throw KeychainError.ambiguous }
        return results.first
    }
    public func createGenericPassword(reference: CredentialReference, secret: KeychainSecret) async throws {
        // Cancellation of the waiting task cannot cancel an already-entered native consent dialog.
        // Retain ownership until the exact native return, then erase bytes even for denied/uncertain results.
        try await execute {
            defer { secret.discard() }
            guard reference.isValid, self.companionPath.hasPrefix("/"), !self.companionPath.contains("\0") else { throw KeychainError.invalidReference }
            try secret.withBytes { try self.security.create(reference: reference, secret: $0, trustedApplicationPaths: [self.companionPath, "/usr/bin/security"]) }
        }
    }
    private func metadata(service: String?, account: String?, keychainPath: String?) throws -> [CredentialReference] {
        let selected: [String]
        if let keychainPath { selected = [keychainPath] }
        else {
            let paths = try security.searchListPaths()
            selected = Array(NSOrderedSet(array: paths)) as? [String] ?? []
        }
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecReturnAttributes as String: true, kSecReturnData as String: false, kSecReturnRef as String: false, kSecMatchLimit as String: kSecMatchLimitAll, kSecUseDataProtectionKeychain as String: false]
        if let service { guard !service.isEmpty, !service.contains("\0") else { throw KeychainError.invalidReference }; query[kSecAttrService as String] = service }
        if let account { guard !account.isEmpty, !account.contains("\0") else { throw KeychainError.invalidReference }; query[kSecAttrAccount as String] = account }
        var results: [CredentialReference] = []
        for path in selected {
            guard path.hasPrefix("/"), !path.contains("\0") else { throw KeychainError.unsupported }
            for row in try security.metadata(keychainPath: path, query: query) {
                guard row[kSecValueData as String] == nil, let s = row[kSecAttrService as String] as? String, let a = row[kSecAttrAccount as String] as? String else { throw KeychainError.unsupported }
                let reference = CredentialReference(keychainPath: path, service: s, account: a)
                guard reference.isValid, service == nil || service == s, account == nil || account == a else { throw KeychainError.unsupported }
                results.append(reference)
            }
        }
        return results
    }
    private func execute<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { do { continuation.resume(returning: try operation()) } catch { continuation.resume(throwing: error) } }
        }
    }
}

/// File-backed Keychain/ACL APIs deliberately preserve compatibility with the fixed path-based reader.
/// Their SDK deprecations remain visible; Data Protection/iCloud-only items are not silently substituted.
private final class NativeKeychainSecurity: KeychainSecurity {
    private func check(_ status: OSStatus) throws { guard status == errSecSuccess else { throw KeychainError.nativeStatus(status) } }
    private func path(_ keychain: SecKeychain) throws -> String {
        var bytes = [CChar](repeating: 0, count: Int(PATH_MAX) + 1), length = UInt32(PATH_MAX)
        try check(SecKeychainGetPath(keychain, &length, &bytes))
        guard length > 0, length <= PATH_MAX else { throw KeychainError.unsupported }
        let value = String(cString: bytes)
        guard value.hasPrefix("/") else { throw KeychainError.unsupported }
        return value
    }
    private func openKeychain(_ path: String) throws -> SecKeychain {
        guard path.hasPrefix("/"), !path.contains("\0") else { throw KeychainError.unsupported }
        var info = stat()
        guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == geteuid(), info.st_nlink == 1,
              URL(fileURLWithPath: path).resolvingSymlinksInPath().path == path else { throw KeychainError.unsupported }
        var keychain: SecKeychain?
        try check(path.withCString { SecKeychainOpen($0, &keychain) })
        guard let keychain, try self.path(keychain) == path else { throw KeychainError.unsupported }
        return keychain
    }
    func searchListPaths() throws -> [String] {
        var list: CFArray?; try check(SecKeychainCopySearchList(&list))
        guard let keychains = list as? [SecKeychain] else { throw KeychainError.unsupported }
        return try keychains.map(path)
    }
    func defaultKeychainPath() throws -> String {
        var keychain: SecKeychain?; try check(SecKeychainCopyDefault(&keychain))
        guard let keychain else { throw KeychainError.unsupported }; return try path(keychain)
    }
    func metadata(keychainPath: String, query: [String: Any]) throws -> [[String: Any]] {
        var query = query; query[kSecMatchSearchList as String] = [try openKeychain(keychainPath)]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        try check(status)
        guard let rows = result as? [[String: Any]] else { throw KeychainError.unsupported }
        return rows
    }
    func create(reference: CredentialReference, secret: UnsafeRawBufferPointer, trustedApplicationPaths: [String]) throws {
        let keychain = try openKeychain(reference.keychainPath)
        guard trustedApplicationPaths.count == 2, trustedApplicationPaths[1] == "/usr/bin/security" else { throw KeychainError.unsupported }
        let trusted = try trustedApplicationPaths.map { path -> SecTrustedApplication in
            var application: SecTrustedApplication?; try check(path.withCString { SecTrustedApplicationCreateFromPath($0, &application) })
            guard let application else { throw KeychainError.unsupported }; return application
        }
        var access: SecAccess?; try check(SecAccessCreate("Codex Project Router credential" as CFString, trusted as CFArray, &access))
        guard let access else { throw KeychainError.unsupported }
        var service = Array(reference.service.utf8), account = Array(reference.account.utf8)
        try service.withUnsafeMutableBytes { serviceBytes in
            try account.withUnsafeMutableBytes { accountBytes in
                var attributes = [SecKeychainAttribute(tag: SecItemAttr.serviceItemAttr.rawValue, length: UInt32(serviceBytes.count), data: serviceBytes.baseAddress), SecKeychainAttribute(tag: SecItemAttr.accountItemAttr.rawValue, length: UInt32(accountBytes.count), data: accountBytes.baseAddress)]
                try attributes.withUnsafeMutableBufferPointer { buffer in
                    var list = SecKeychainAttributeList(count: UInt32(buffer.count), attr: buffer.baseAddress)
                    // Pass the single owned secret buffer directly; no Data/dictionary copies survive the call.
                    try check(SecKeychainItemCreateFromContent(.genericPasswordItemClass, &list, UInt32(secret.count), secret.baseAddress, keychain, access, nil))
                }
            }
        }
    }
}
