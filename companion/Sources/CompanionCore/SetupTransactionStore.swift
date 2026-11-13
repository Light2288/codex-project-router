import Foundation
import Darwin

/// A lease belongs only to this live store. Relaunch may inspect evidence, never adopt a recorded PID.
public final class SetupTransactionStore {
    public let configPath: URL
    private let receiptName = "account-setup.json", leaseName = ".activation.lock"
    private var directoryFD: Int32 = -1, leaseFD: Int32 = -1
    private var operationID: String?, context: ActivationContext?, currentReceipt: SetupReceipt?
    private var receiptIdentity: stat?, phase: SetupReceipt.Phase?
    public init(configPath: URL) { self.configPath = configPath }
    deinit {
        // Closing this process's descriptors does not discard uncertain persistent evidence.
        if leaseFD >= 0 { close(leaseFD) }; if directoryFD >= 0 { close(directoryFD) }
    }

    public func begin(context: ActivationContext, operationID: String, receipt: SetupReceipt?, verifiedPreviousAccount: AccountRecord? = nil) throws {
        guard leaseFD < 0, UUID(uuidString: operationID) != nil, valid(context), context.configPath == configPath.path,
              receipt == nil || (receipt!.isValid && receipt!.operationId == operationID && receipt!.context == context && receipt!.phase == .prepared) else { throw CompanionError.privateState }
        let dir = try openDirectory(); var retained = false
        defer { if !retained { close(dir) } }
        let previous = try readReceipt(dir)
        if let previous {
            guard previous.phase == .complete, previous.context == context else { throw CompanionError.privateState }
            if receipt != nil { guard let verifiedPreviousAccount, verifiedPreviousAccount == previous.account else { throw CompanionError.privateState } }
        }
        let fd = openat(dir, leaseName, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0o600)
        guard fd >= 0 else { throw CompanionError.privateState }
        directoryFD = dir; leaseFD = fd; retained = true; self.operationID = operationID; self.context = context
        try checkFile(fd)
        let lease = Lease(pid: getpid(), setupOperationId: operationID, configPath: context.configPath)
        try writeAll(try JSONEncoder().encode(lease), fd: fd)
        guard fsync(fd) == 0, fsync(dir) == 0 else { throw CompanionError.privateState }
        try validateLease()
        currentReceipt = previous
        receiptIdentity = try identity(dir, receiptName)
        phase = nil
        if let receipt { try prepare(receipt, verifiedPreviousAccount: verifiedPreviousAccount) }
    }

    /// Use after acquiring a metadata-only lease and rechecking freshness, before native creation.
    public func prepare(_ receipt: SetupReceipt, verifiedPreviousAccount: AccountRecord? = nil) throws {
        try validateLease(); try validateReceiptIdentity()
        guard phase == nil, receipt.isValid, receipt.phase == .prepared, receipt.operationId == operationID, receipt.context == context else { throw CompanionError.privateState }
        if let previous = currentReceipt {
            guard previous.phase == .complete, previous.account == verifiedPreviousAccount else { throw CompanionError.privateState }
        }
        try writeReceipt(receipt)
        currentReceipt = receipt; phase = .prepared
    }

    public func load() throws -> SetupReceipt? {
        let fd = try openDirectory(); defer { close(fd) }
        return try readReceipt(fd)
    }

    /// The caller advances only after observing the corresponding native/helper outcome.
    public func advance(_ next: SetupReceipt.Phase) throws {
        try validateLease(); try validateReceiptIdentity()
        let allowed: Bool
        switch (phase, next) {
        case (.prepared?, .itemCreated), (.itemCreated?, .committing), (.committing?, .complete), (nil, .committing): allowed = true
        default: allowed = false
        }
        guard allowed else { throw CompanionError.privateState }
        if var receipt = currentReceipt, receipt.operationId == operationID {
            receipt.phase = next; try writeReceipt(receipt); currentReceipt = receipt
        }
        phase = next
    }

    /// Call only after exact saved-account/default reconciliation and exact helper exit.
    /// A prepared receipt or a relaunched instance cannot authorize releasing a lease.
    public func finishVerified() throws {
        guard phase == .complete else { throw CompanionError.privateState }
        try validateLease(); try validateReceiptIdentity()
        guard unlinkat(directoryFD, leaseName, 0) == 0, fsync(directoryFD) == 0 else { throw CompanionError.privateState }
        close(leaseFD); leaseFD = -1; close(directoryFD); directoryFD = -1
        operationID = nil; context = nil; phase = nil
    }

    private struct Lease: Codable, Equatable { var pid: Int32; var setupOperationId: String; var configPath: String }
    private func valid(_ context: ActivationContext) -> Bool {
        [context.configPath, context.codexHome].allSatisfy { $0.hasPrefix("/") && !$0.contains("\0") } && (1...65535).contains(context.listenPort) && context.providerId.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }
    private func openDirectory() throws -> Int32 {
        guard configPath.isFileURL, configPath.path.hasPrefix("/"), !configPath.path.contains("\0"), configPath.path == configPath.standardizedFileURL.path else { throw CompanionError.privateState }
        let directory = configPath.deletingLastPathComponent()
        guard directory.resolvingSymlinksInPath().path == directory.path else { throw CompanionError.privateState }
        let fd = open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw CompanionError.privateState }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(), info.st_mode & 0o7777 == 0o700 else { close(fd); throw CompanionError.privateState }
        return fd
    }
    private func checkFile(_ fd: Int32) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(), info.st_nlink == 1, info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o7777 == 0o600 else { throw CompanionError.privateState }
    }
    private func same(_ a: stat, _ b: stat) -> Bool { a.st_dev == b.st_dev && a.st_ino == b.st_ino }
    private func identity(_ dir: Int32, _ name: String) throws -> stat? {
        let fd = openat(dir, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        if fd < 0 { guard errno == ENOENT else { throw CompanionError.privateState }; return nil }
        defer { close(fd) }; try checkFile(fd)
        var info = stat(); guard fstat(fd, &info) == 0 else { throw CompanionError.privateState }; return info
    }
    private func validateLease() throws {
        guard leaseFD >= 0, directoryFD >= 0, let operationID, let context else { throw CompanionError.privateState }
        let actualDirectory = try openDirectory(); defer { close(actualDirectory) }
        var held = stat(), actual = stat(), lease = stat()
        guard fstat(directoryFD, &held) == 0, fstat(actualDirectory, &actual) == 0, same(held, actual) else { throw CompanionError.privateState }
        try checkFile(leaseFD)
        guard fstat(leaseFD, &lease) == 0, let current = try identity(directoryFD, leaseName), same(lease, current) else { throw CompanionError.privateState }
        guard let data = try readBytes(directoryFD, leaseName),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == ["pid", "setupOperationId", "configPath"],
              let decoded = try? JSONDecoder().decode(Lease.self, from: data), decoded == Lease(pid: getpid(), setupOperationId: operationID, configPath: context.configPath) else { throw CompanionError.privateState }
    }
    private func validateReceiptIdentity() throws {
        let actual = try identity(directoryFD, receiptName)
        switch (receiptIdentity, actual) {
        case (nil, nil): break
        case let (a?, b?): guard same(a, b), try readReceipt(directoryFD) == currentReceipt else { throw CompanionError.privateState }
        default: throw CompanionError.privateState
        }
    }
    private func readBytes(_ dir: Int32, _ name: String) throws -> Data? {
        let fd = openat(dir, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        if fd < 0 { guard errno == ENOENT else { throw CompanionError.privateState }; return nil }
        defer { close(fd) }; try checkFile(fd)
        var result = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fd, &buffer, buffer.count)
            if n < 0 { if errno == EINTR { continue }; throw CompanionError.privateState }
            if n == 0 { break }
            guard result.count + n <= 64 * 1024 else { throw CompanionError.privateState }; result.append(buffer, count: n)
        }
        return result
    }
    private func readReceipt(_ dir: Int32) throws -> SetupReceipt? {
        guard let data = try readBytes(dir, receiptName) else { return nil }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == ["schemaVersion", "operationId", "accountId", "reference", "account", "context", "phase"],
                  let account = object["account"] as? [String: Any], Set(account.keys) == ["id", "displayName", "upstreamBaseUrl", "credential"],
                  let reference = object["reference"] as? [String: Any], Set(reference.keys) == ["keychainPath", "service", "account"],
                  let credential = account["credential"] as? [String: Any], Set(credential.keys) == ["keychainPath", "service", "account"],
                  let context = object["context"] as? [String: Any], Set(context.keys) == ["configPath", "codexHome", "providerId", "listenPort"] else { throw CompanionError.privateState }
            let receipt = try JSONDecoder().decode(SetupReceipt.self, from: data)
            guard receipt.isValid, valid(receipt.context), receipt.context.configPath == configPath.path else { throw CompanionError.privateState }
            return receipt
        } catch { throw CompanionError.privateState }
    }
    private func writeAll(_ data: Data, fd: Int32) throws {
        let ok = data.withUnsafeBytes { bytes -> Bool in
            var offset = 0
            while offset < bytes.count {
                let n = write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if n < 0 { if errno == EINTR { continue }; return false }; if n == 0 { return false }; offset += n
            }
            return true
        }
        guard ok else { throw CompanionError.privateState }
    }
    private func writeReceipt(_ receipt: SetupReceipt) throws {
        try validateLease(); try validateReceiptIdentity()
        let name = ".account-setup-\(UUID().uuidString).tmp"
        let fd = openat(directoryFD, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw CompanionError.privateState }
        defer { close(fd); unlinkat(directoryFD, name, 0) }
        try checkFile(fd); try writeAll(try JSONEncoder().encode(receipt), fd: fd)
        guard fsync(fd) == 0 else { throw CompanionError.privateState }
        try validateLease(); try validateReceiptIdentity()
        guard renameat(directoryFD, name, directoryFD, receiptName) == 0, fsync(directoryFD) == 0 else { throw CompanionError.privateState }
        receiptIdentity = try identity(directoryFD, receiptName)
    }
}
