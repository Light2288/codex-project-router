import Foundation
import Darwin

public final class PrivateStore {
    public let directory: URL
    private var lockFD: Int32 = -1
    public init(directory: URL) { self.directory = directory }
    deinit { releaseInstanceLock() }

    public func load() throws -> CompanionJournal {
        let fd = try openDirectory(); defer { close(fd) }
        if let journal = try readJournal(fd) { return journal }
        let journal = CompanionJournal()
        try writeJournal(journal, directoryFD: fd)
        return journal
    }
    public func save(_ journal: CompanionJournal) throws {
        guard valid(journal) else { throw CompanionError.privateState }
        let fd = try openDirectory(); defer { close(fd) }
        _ = try readJournal(fd) // Existing corrupt/unsafe evidence must never be overwritten.
        try writeJournal(journal, directoryFD: fd)
    }
    public func acquireInstanceLock() throws {
        if lockFD >= 0 { return }
        let directoryFD = try openDirectory(); defer { close(directoryFD) }
        let fd = openat(directoryFD, "instance.lock", O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0o600)
        guard fd >= 0 else { throw CompanionError.privateState }
        do {
            try checkFile(fd)
            guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
                if errno == EWOULDBLOCK { throw CompanionError.instanceRunning }
                throw CompanionError.privateState
            }
            lockFD = fd
        } catch { close(fd); throw error }
    }
    public func releaseInstanceLock() {
        if lockFD >= 0 { close(lockFD); lockFD = -1 }
    }
    private func openDirectory() throws -> Int32 {
        guard directory.isFileURL, directory.path.hasPrefix("/") else { throw CompanionError.privateState }
        if mkdir(directory.path, 0o700) != 0, errno != EEXIST {
            guard errno == ENOENT else { throw CompanionError.privateState }
            do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
            catch { throw CompanionError.privateState }
        }
        let fd = open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw CompanionError.privateState }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(), info.st_mode & 0o7777 == 0o700 else {
            close(fd); throw CompanionError.privateState
        }
        return fd
    }
    private func checkFile(_ fd: Int32) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == geteuid(), info.st_nlink == 1, info.st_mode & 0o7777 == 0o600 else { throw CompanionError.privateState }
    }
    private func readJournal(_ directoryFD: Int32) throws -> CompanionJournal? {
        let fd = openat(directoryFD, "state.json", O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        if fd < 0 {
            guard errno == ENOENT else { throw CompanionError.privateState }
            return nil
        }
        defer { close(fd) }
        try checkFile(fd)
        var bytes = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0 { if errno == EINTR { continue }; throw CompanionError.privateState }
            if count == 0 { break }
            guard bytes.count + count <= 64 * 1024 else { throw CompanionError.privateState }
            bytes.append(buffer, count: count)
        }
        do {
            guard let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  Set(object.keys).isSubset(of: ["schemaVersion", "selectedConfigurationPath", "nodeExecutablePath", "pending"]) else { throw CompanionError.privateState }
            if let pending = object["pending"] as? [String: Any] {
                guard Set(pending.keys) == ["context", "phase"], let context = pending["context"] as? [String: Any],
                      Set(context.keys) == ["configPath", "codexHome", "providerId", "listenPort"] else { throw CompanionError.privateState }
            }
            let journal = try JSONDecoder().decode(CompanionJournal.self, from: bytes)
            guard valid(journal) else { throw CompanionError.privateState }
            return journal
        } catch { throw CompanionError.privateState }
    }
    private func valid(_ journal: CompanionJournal) -> Bool {
        func absolute(_ value: String?) -> Bool { value == nil || (value!.hasPrefix("/") && !value!.contains("\0")) }
        guard journal.schemaVersion == 1, absolute(journal.selectedConfigurationPath), absolute(journal.nodeExecutablePath) else { return false }
        if let pending = journal.pending {
            let context = pending.context
            guard context.configPath == journal.selectedConfigurationPath, absolute(context.configPath), absolute(context.codexHome),
                  (1...65535).contains(context.listenPort), context.providerId.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else { return false }
        }
        return true
    }
    private func writeJournal(_ journal: CompanionJournal, directoryFD: Int32) throws {
        let bytes: Data
        do { bytes = try JSONEncoder().encode(journal) } catch { throw CompanionError.privateState }
        let name = ".state-\(UUID().uuidString).tmp"
        let fd = openat(directoryFD, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw CompanionError.privateState }
        defer { close(fd); unlinkat(directoryFD, name, 0) }
        try checkFile(fd)
        let written = bytes.withUnsafeBytes { raw -> Bool in
            var offset = 0
            while offset < bytes.count {
                let count = write(fd, raw.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 { if errno == EINTR { continue }; return false }
                if count == 0 { return false }
                offset += count
            }
            return true
        }
        guard written, fsync(fd) == 0, renameat(directoryFD, name, directoryFD, "state.json") == 0,
              fsync(directoryFD) == 0 else { throw CompanionError.privateState }
    }
}
