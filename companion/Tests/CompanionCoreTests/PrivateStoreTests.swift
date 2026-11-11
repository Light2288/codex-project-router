import XCTest
import Darwin
@testable import CompanionCore

final class PrivateStoreTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("companion store \(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testJournalRejectsCorruptionAndUnsafeFiles() throws {
        // Removing safe-file validation would allow corrupt/symlinked or foreign state to become authority.
        let directory = root.appendingPathComponent("private")
        let store = PrivateStore(directory: directory)
        XCTAssertEqual(try store.load(), CompanionJournal())
        let journal = CompanionJournal(selectedConfigurationPath: "/synthetic/router.json", nodeExecutablePath: "/synthetic/node")
        try store.save(journal)
        XCTAssertEqual(try store.load(), journal)
        let state = directory.appendingPathComponent("state.json")
        XCTAssertEqual(try mode(directory), 0o700); XCTAssertEqual(try mode(state), 0o600)
        let bytes = try Data(contentsOf: state)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertNil(json["pid"]); XCTAssertNil(json["process"]); XCTAssertNil(json["ownership"])
        try Data("{broken SENTINEL_PRIVATE".utf8).write(to: state)
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(journal))
        XCTAssertEqual(try String(contentsOf: state), "{broken SENTINEL_PRIVATE")
        try FileManager.default.removeItem(at: state)
        let target = root.appendingPathComponent("target"); try bytes.write(to: target)
        try FileManager.default.createSymbolicLink(at: state, withDestinationURL: target)
        XCTAssertThrowsError(try store.load()); XCTAssertThrowsError(try store.save(journal))
        try FileManager.default.removeItem(at: state); try bytes.write(to: state)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: state.path)
        XCTAssertThrowsError(try store.load())
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: state.path)
        // A multiply-linked state file is not a private replaceable journal.
        XCTAssertEqual(link(state.path, root.appendingPathComponent("hardlink").path), 0)
        XCTAssertThrowsError(try store.load())
        let linkedDirectory = root.appendingPathComponent("linked-dir")
        try FileManager.default.createSymbolicLink(at: linkedDirectory, withDestinationURL: directory)
        XCTAssertThrowsError(try PrivateStore(directory: linkedDirectory).load())
    }
    func testSecondInstanceCannotAcquireLock() throws {
        // A per-object flag instead of a kernel lock would allow a second process/instance.
        let a = PrivateStore(directory: root), b = PrivateStore(directory: root)
        try a.acquireInstanceLock()
        XCTAssertThrowsError(try b.acquireInstanceLock())
        a.releaseInstanceLock(); try b.acquireInstanceLock(); b.releaseInstanceLock()
    }
    func testLockReleasesAfterOwnerExitAndDoesNotSurviveExec() throws {
        // Omitting CLOEXEC would leave a companion child holding the instance lock after app exit.
        let store = PrivateStore(directory: root)
        try store.acquireInstanceLock()
        var lockInfo = stat()
        XCTAssertEqual(stat(root.appendingPathComponent("instance.lock").path, &lockInfo), 0)
        var lockDescriptors = 0
        for fd in Int32(0)..<Int32(1024) {
            var info = stat()
            if fstat(fd, &info) == 0, info.st_ino == lockInfo.st_ino, info.st_dev == lockInfo.st_dev {
                lockDescriptors += 1; XCTAssertNotEqual(fcntl(fd, F_GETFD) & FD_CLOEXEC, 0)
            }
        }
        XCTAssertEqual(lockDescriptors, 1)
        let child = Process(); child.executableURL = URL(fileURLWithPath: "/bin/sleep"); child.arguments = ["1"]
        try child.run(); defer { if child.isRunning { child.terminate(); child.waitUntilExit() } }
        store.releaseInstanceLock()
        let next = PrivateStore(directory: root); try next.acquireInstanceLock(); next.releaseInstanceLock()
        // Verify kernel cleanup after a separate owner process exits without explicit unlock.
        let lockPath = root.appendingPathComponent("instance.lock").path
        let owner = Process(); owner.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        owner.arguments = ["-c", "import fcntl,sys; f=open(sys.argv[1],'r+'); fcntl.flock(f,fcntl.LOCK_EX); print('locked',flush=True)", lockPath]
        let output = Pipe(); owner.standardOutput = output; try owner.run(); owner.waitUntilExit()
        XCTAssertEqual(owner.terminationStatus, 0)
        try next.acquireInstanceLock(); next.releaseInstanceLock()
    }
    func testAtomicReplacementAndUnknownRecoveryDataRejection() throws {
        // In-place writes expose partial state and mutate an already-open previous snapshot.
        let store = PrivateStore(directory: root)
        try store.save(CompanionJournal(selectedConfigurationPath: "/synthetic/first"))
        let state = root.appendingPathComponent("state.json")
        let old = try FileHandle(forReadingFrom: state); defer { try? old.close() }
        try store.save(CompanionJournal(selectedConfigurationPath: "/synthetic/second"))
        let previous = try JSONDecoder().decode(CompanionJournal.self, from: old.readToEnd()!)
        XCTAssertEqual(previous.selectedConfigurationPath, "/synthetic/first")
        XCTAssertEqual(try store.load().selectedConfigurationPath, "/synthetic/second")
        let unknown = Data(#"{"schemaVersion":1,"pid":12345,"destination":"SENTINEL_PRIVATE"}"#.utf8)
        try unknown.write(to: state)
        XCTAssertThrowsError(try store.load()); XCTAssertThrowsError(try store.save(CompanionJournal()))
        XCTAssertEqual(try Data(contentsOf: state), unknown)
    }
    private func mode(_ url: URL) throws -> Int { (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as! NSNumber).intValue }
}
