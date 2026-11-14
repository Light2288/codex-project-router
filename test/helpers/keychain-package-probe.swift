import Foundation
import Security
import Darwin

// Test-only executable: no product switch or test credential crosses a process boundary.
private enum ProbeFailure: Error { case failed, nativeStatus(OSStatus) }
private func require(_ condition: @autoclosure () throws -> Bool) throws {
    guard try condition() else { throw ProbeFailure.failed }
}
private func check(_ status: OSStatus) throws {
    guard status == errSecSuccess else { throw ProbeFailure.nativeStatus(status) }
}
private func keychainPath(_ keychain: SecKeychain) throws -> String {
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1), length = UInt32(PATH_MAX)
    try check(SecKeychainGetPath(keychain, &length, &buffer))
    try require(length > 0 && length <= PATH_MAX)
    return String(cString: buffer)
}
private func resolvedPath(_ path: String) throws -> String {
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) + 1)
    try require(path.withCString { realpath($0, &buffer) } != nil)
    return String(cString: buffer)
}
private func identity(_ path: String, directory: Bool) throws -> stat {
    var info = stat()
    try require(lstat(path, &info) == 0 && info.st_uid == geteuid())
    try require(info.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG))
    try require(directory ? info.st_mode & 0o777 == 0o700 : info.st_nlink == 1)
    try require(try resolvedPath(path) == path)
    return info
}
private func sameIdentity(_ path: String, _ expected: stat, directory: Bool) throws {
    let current = try identity(path, directory: directory)
    try require(current.st_dev == expected.st_dev && current.st_ino == expected.st_ino)
}
private func searchList() throws -> [SecKeychain] {
    var list: CFArray?
    try check(SecKeychainCopySearchList(&list))
    guard let result = list as? [SecKeychain] else { throw ProbeFailure.failed }
    return result
}
private func defaultKeychain() throws -> (OSStatus, SecKeychain?) {
    var value: SecKeychain?
    let status = SecKeychainCopyDefault(&value)
    try require(status == errSecSuccess || status == errSecNoDefaultKeychain)
    return (status, value)
}

private final class OwnedScratchKeychain {
    let directory: String
    private(set) var path: String
    private let directoryIdentity: stat
    private var keychain: SecKeychain?
    private var fileIdentity: stat?
    private(set) var stage = "scratch-directory"

    init(parent: String) throws {
        try require(parent.hasPrefix("/") && !parent.contains("\0"))
        let nativeParent = try resolvedPath(parent)
        _ = try identity(nativeParent, directory: true)
        directory = nativeParent + "/owned-keychain-" + UUID().uuidString
        path = directory + "/probe.keychain"
        try require(mkdir(directory, 0o700) == 0)
        directoryIdentity = try identity(directory, directory: true)
    }

    func create() throws {
        stage = "scratch-validation"
        try sameIdentity(directory, directoryIdentity, directory: true)
        try require((try FileManager.default.contentsOfDirectory(atPath: directory)).isEmpty)
        // Observe membership only, never query any existing item's attributes or data.
        stage = "scratch-search-list"
        for entry in try searchList() { try require(try keychainPath(entry) != path) }
        var password = (0..<48).map { UInt8(65 + $0 % 26) }
        defer { password.withUnsafeMutableBytes { if let base = $0.baseAddress { _ = memset_s(base, $0.count, 0, $0.count) } } }
        var created: SecKeychain?
        stage = "scratch-create"
        let status = path.withCString { destination in
            password.withUnsafeBytes { SecKeychainCreate(destination, UInt32($0.count), $0.baseAddress, false, nil, &created) }
        }
        // Retain a returned handle even on failure so cleanup never loses known owned state.
        keychain = created
        if let created {
            // Capture the returned native file identity before secondary checks;
            // modern Security may append -db to the requested filename.
            path = try keychainPath(created)
            fileIdentity = try identity(path, directory: false)
            stage = "scratch-created-path"
            try require(URL(fileURLWithPath: path).deletingLastPathComponent().path == directory)
            try require(["probe.keychain", "probe.keychain-db"].contains(URL(fileURLWithPath: path).lastPathComponent))
        }
        try check(status)
        try require(keychain != nil && fileIdentity != nil)
    }

    func cleanup() throws {
        stage = "cleanup-ownership"
        try sameIdentity(directory, directoryIdentity, directory: true)
        if let keychain {
            guard let fileIdentity else { throw ProbeFailure.failed }
            try require(URL(fileURLWithPath: path).deletingLastPathComponent().path == directory)
            try require(["probe.keychain", "probe.keychain-db"].contains(URL(fileURLWithPath: path).lastPathComponent))
            stage = "cleanup-file-identity"
            try sameIdentity(path, fileIdentity, directory: false)
            stage = "cleanup-handle-path"
            try require(try keychainPath(keychain) == path)
            // SecKeychainCreate can append the owned keychain. Filter the current
            // list; restoring a snapshot would discard unrelated concurrent edits.
            let current = try searchList()
            stage = "cleanup-search-list"
            var filtered: [SecKeychain] = []
            for entry in current where try keychainPath(entry) != path { filtered.append(entry) }
            if filtered.count != current.count { try check(SecKeychainSetSearchList(filtered as CFArray)) }
            for entry in try searchList() { try require(try keychainPath(entry) != path) }
            try sameIdentity(path, fileIdentity, directory: false)
            stage = "cleanup-native-delete"
            try check(SecKeychainDelete(keychain))
            self.keychain = nil
            var info = stat()
            try require(lstat(path, &info) == -1 && errno == ENOENT)
        }
        try sameIdentity(directory, directoryIdentity, directory: true)
        stage = "cleanup-sidecars"
        // After native deletion, some systems leave a legacy placeholder or .fl
        // lock. Reject any unexpected entry rather than removing a tree.
        let sidecars = try FileManager.default.contentsOfDirectory(atPath: directory).map { name -> (String, stat) in
            try require(name == "probe.keychain" || name.range(of: "^\\.fl[0-9A-Fa-f]{8}$", options: .regularExpression) != nil)
            let candidate = directory + "/" + name
            return (candidate, try identity(candidate, directory: false))
        }
        for (candidate, expected) in sidecars {
            try sameIdentity(directory, directoryIdentity, directory: true)
            try sameIdentity(candidate, expected, directory: false)
            try require(unlink(candidate) == 0)
        }
        stage = "cleanup-directory"
        try require((try FileManager.default.contentsOfDirectory(atPath: directory)).isEmpty)
        try require(rmdir(directory) == 0)
    }

    func captureCompletedOwnedAdd() throws {
        // The observed file-backed add atomically replaces the DB inode. Accept
        // that completed native write only while the exact handle/path and owned
        // directory still match; all later cleanup checks retain this identity.
        try sameIdentity(directory, directoryIdentity, directory: true)
        guard let keychain else { throw ProbeFailure.failed }
        try require(try keychainPath(keychain) == path)
        fileIdentity = try identity(path, directory: false)
    }
}

@main private enum KeychainPackageProbe {
    static func main() async {
        var scratch: OwnedScratchKeychain?
        var passed = false
        var readerReaped = true
        var stage = "arguments"
        var originalDefault: (OSStatus, SecKeychain?)?
        do {
            let args = CommandLine.arguments
            try require(args.count == 5)
            // Compare opaque native default handles only; never inspect that keychain's items.
            originalDefault = try defaultKeychain()
            stage = "scratch"
            let owned = try OwnedScratchKeychain(parent: args[1]); scratch = owned
            try owned.create()
            stage = "metadata-before"
            let reference = CredentialReference(keychainPath: owned.path, service: "codex-router-owned-package-probe", account: "synthetic-package-account")
            let store = KeychainStore()
            let before = try await store.listMetadata(keychainPath: owned.path)
            try require(before.isEmpty)
            var fixture = String(bytes: (0..<48).map { UInt8(33 + $0 * 7 % 94) }, encoding: .ascii)!
            let secret = try KeychainSecret(fixture); fixture.removeAll(keepingCapacity: false)
            stage = "native-add"
            try await store.createGenericPassword(reference: reference, secret: secret)
            try owned.captureCompletedOwnedAdd()
            try require(secret.isDiscarded)
            stage = "metadata-after"
            let metadata = try await store.listMetadata(keychainPath: owned.path)
            try require(metadata == [reference])
            let exact = try await store.lookup(reference: reference)
            try require(exact == reference)
            // The add-only boundary rejects a duplicate; the reader later proves the original value survived.
            let duplicate = try KeychainSecret("duplicate-public-fixture")
            stage = "duplicate-add"
            do {
                try await store.createGenericPassword(reference: reference, secret: duplicate)
                throw ProbeFailure.failed
            } catch KeychainError.nativeStatus(let status) { try require(status == errSecDuplicateItem) }
            try require(duplicate.isDiscarded)
            let afterDuplicate = try await store.listMetadata(keychainPath: owned.path)
            try require(afterDuplicate == [reference])

            stage = "bundled-reader"
            let output = Pipe(), errors = Pipe()
            defer { output.fileHandleForReading.closeFile(); errors.fileHandleForReading.closeFile() }
            var actions: posix_spawn_file_actions_t?
            try require(posix_spawn_file_actions_init(&actions) == 0)
            defer { posix_spawn_file_actions_destroy(&actions) }
            try require(posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) == 0)
            try require(posix_spawn_file_actions_adddup2(&actions, output.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) == 0)
            try require(posix_spawn_file_actions_adddup2(&actions, errors.fileHandleForWriting.fileDescriptor, STDERR_FILENO) == 0)
            var attributes: posix_spawnattr_t?
            try require(posix_spawnattr_init(&attributes) == 0)
            defer { posix_spawnattr_destroy(&attributes) }
            // Foundation Process creates a separate group on macOS. Inherit the
            // Node owner's retained group, closing all unrelated descriptors.
            try require(posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0)
            let arguments = [args[2], args[3], args[4], reference.keychainPath, reference.service, reference.account].map { $0.withCString { strdup($0) } } + [nil]
            let environment = ["PATH=/usr/bin:/bin", "LANG=en_US.UTF-8"].map { $0.withCString { strdup($0) } } + [nil]
            defer { arguments.forEach { free($0) }; environment.forEach { free($0) } }
            var readerPID: pid_t = 0
            let launched = arguments.withUnsafeBufferPointer { argv in
                environment.withUnsafeBufferPointer { env in
                    posix_spawn(&readerPID, args[2], &actions, &attributes, argv.baseAddress!, env.baseAddress!)
                }
            }
            output.fileHandleForWriting.closeFile(); errors.fileHandleForWriting.closeFile()
            try require(launched == 0)
            readerReaped = false
            var status: Int32 = 0
            func reapReader(before deadline: Double) async throws -> Bool {
                repeat {
                    let result = waitpid(readerPID, &status, WNOHANG)
                    if result == readerPID { readerReaped = true; return true }
                    try require(result == 0 || result == -1 && errno == EINTR)
                    try await Task.sleep(nanoseconds: 25_000_000)
                } while ProcessInfo.processInfo.systemUptime < deadline
                return false
            }
            // Keep cleanup reachable on reader stalls; the longer Node deadline
            // also covers blocked native operations and the whole reader group.
            if try await !reapReader(before: ProcessInfo.processInfo.systemUptime + 8) {
                try require(kill(readerPID, SIGTERM) == 0 || errno == ESRCH)
                if try await !reapReader(before: ProcessInfo.processInfo.systemUptime + 1) {
                    try require(kill(readerPID, SIGKILL) == 0 || errno == ESRCH)
                    let reaped = try await reapReader(before: ProcessInfo.processInfo.systemUptime + 2)
                    try require(reaped)
                }
                throw ProbeFailure.failed
            }
            let bytes = output.fileHandleForReading.readDataToEndOfFile()
            let errorBytes = errors.fileHandleForReading.readDataToEndOfFile()
            try require(status == 0)
            try require(bytes == Data("package-reader-pass\n".utf8) && errorBytes.isEmpty)
            passed = true
        } catch {
            passed = false
            // Fixed stage/status diagnostics contain neither paths nor item attributes/data.
            fputs("native-probe-failed-\(stage == "scratch" ? scratch?.stage ?? stage : stage)\n", stderr)
            if case KeychainError.nativeStatus(let status) = error { fputs("native-probe-status-\(status)\n", stderr) }
            if case ProbeFailure.nativeStatus(let status) = error { fputs("native-probe-status-\(status)\n", stderr) }
        }
        do {
            // A reader with unknown lifecycle may still use the scratch state.
            // Preserve it for inspection rather than claim cleanup completed.
            try require(readerReaped)
            if let scratch { try scratch.cleanup(); print("native-keychain-cleanup-pass") }
        } catch {
            passed = false
            fputs("native-probe-failed-\(scratch?.stage ?? "cleanup")\n", stderr)
            if case ProbeFailure.nativeStatus(let status) = error { fputs("native-probe-status-\(status)\n", stderr) }
        }
        do {
            if let originalDefault {
                let current = try defaultKeychain()
                try require(current.0 == originalDefault.0)
                if let before = originalDefault.1, let after = current.1 { try require(CFEqual(before, after)) }
                else { try require(originalDefault.1 == nil && current.1 == nil) }
            }
        } catch { passed = false; fputs("native-probe-default-changed-or-unavailable\n", stderr) }
        print(passed ? "native-keychain-package-pass" : "native-keychain-package-fail")
        if !passed { exit(1) }
    }
}
