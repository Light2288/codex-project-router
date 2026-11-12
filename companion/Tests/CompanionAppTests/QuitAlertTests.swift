import XCTest
import AppKit
import CompanionCore
@testable import CodexProjectRouter

@MainActor final class QuitAlertTests: XCTestCase {
    private var root: URL!
    private var store: PrivateStore!
    private var backend: QuitBackend!
    private let sentinel = "SYNTHETIC_PRIVATE_SENTINEL"
    private let context = ActivationContext(configPath: "/synthetic/SYNTHETIC_PRIVATE_SENTINEL/config.json",
        codexHome: "/synthetic/SYNTHETIC_PRIVATE_SENTINEL/codex", providerId: "synthetic_provider", listenPort: 43129)

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("quit alert \(UUID())")
        store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(CompanionJournal(selectedConfigurationPath: context.configPath))
        backend = QuitBackend(context: context)
    }
    override func tearDown() async throws {
        backend = nil; store = nil
        try FileManager.default.removeItem(at: root)
    }
    private func makeController(pending: Bool = false) async throws -> RouterController {
        if pending {
            try store.save(CompanionJournal(selectedConfigurationPath: context.configPath,
                pending: .init(context: context, phase: .directConfirmation)))
        }
        let controller = RouterController(backend: backend, store: store, browseHome: root)
        await controller.refresh()
        return controller
    }

    func testFixedAlertCopyAndCancelBinding() async throws {
        // Wrong reason selection or raw backend/context interpolation must not reach native alert content.
        let cases: [(RouterController.QuitBlockReason, String)] = [
            (.directConfirmationPending, "Codex may still need the router. Check the direct connection before quitting."),
            (.operationInProgress, "A router operation is running or needs checking. Review its status before quitting."),
            (.directRecoveryRequired, "The app still needs to restore the direct connection before it can quit."),
            (.contextUnavailable, "The app cannot check that quitting is safe. Review its status and recovery instructions.")
        ]
        for (reason, message) in cases {
            let fixtureStore = PrivateStore(directory: root.appendingPathComponent(UUID().uuidString))
            try fixtureStore.save(CompanionJournal(selectedConfigurationPath: context.configPath,
                pending: .init(context: context, phase: .directConfirmation)))
            let backend = QuitBackend(context: context)
            let controller = RouterController(backend: backend, store: fixtureStore, browseHome: root)
            await controller.refresh(); await controller.start()
            XCTAssertNotNil(controller.ownedRouter)
            backend.mutationRequiresReconciliation = reason == .operationInProgress
            if reason == .directRecoveryRequired {
                backend.snapshot.provider = .init(state: "router", recoveryRequired: true, proxyReady: false, recordPhase: "active")
            }
            if reason == .contextUnavailable {
                backend.inspectionError = NSError(domain: sentinel, code: 1, userInfo: [NSLocalizedDescriptionKey: sentinel])
            }
            await controller.requestQuit()
            XCTAssertEqual(controller.quitBlockReason, reason)
            let alert = QuitAlert.make(reason: try XCTUnwrap(controller.quitBlockReason), ownsRouter: controller.ownedRouter != nil)
            XCTAssertEqual(alert.alertStyle, .warning)
            XCTAssertEqual(alert.messageText, "Cannot quit yet")
            XCTAssertEqual(alert.informativeText, message)
            XCTAssertEqual(alert.buttons.map(\.title), ["Show steps to quit", "Keep Running"])
            XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
            XCTAssertEqual(alert.buttons[1].keyEquivalent, "\u{1b}")
            XCTAssertFalse(([alert.messageText, alert.informativeText] + alert.buttons.map(\.title)).joined().contains(sentinel))
        }
    }

    func testPendingWithoutOwnedRouterRequestsFreshQuitCheck() async throws {
        // A pending result without ownership must request another Quit check rather than manual confirmation.
        let controller = try await makeController(pending: true)
        XCTAssertNil(controller.ownedRouter)
        XCTAssertEqual(controller.quitBlockReason, .directConfirmationPending)
        let alert = QuitAlert.make(reason: try XCTUnwrap(controller.quitBlockReason), ownsRouter: false)
        XCTAssertEqual(alert.messageText, "Cannot quit yet")
        XCTAssertEqual(alert.informativeText, "Quit needs a fresh check of the saved recovery information. Review the status, then try Quit again.")
        XCTAssertEqual(alert.buttons.map(\.title), ["Show steps to quit", "Keep Running"])
        XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
        XCTAssertEqual(alert.buttons[1].keyEquivalent, "\u{1b}")
        XCTAssertFalse(([alert.messageText, alert.informativeText] + alert.buttons.map(\.title)).joined().contains(sentinel))
    }

    func testDelegateUsesOwnershipAfterDeniedAttempt() async throws {
        // Ownership lost during the attempt must not retain the owned-router restart description.
        let controller = try await makeController(pending: true)
        await controller.start()
        let child = try XCTUnwrap(controller.ownedRouter)
        let inspection = QuitBarrier<Inspection>()
        backend.inspectBarrier = inspection
        var presentCount = 0
        let delegate = RouterAppDelegate(controller: controller, presentQuitAlert: { alert in
            presentCount += 1
            XCTAssertNil(controller.ownedRouter)
            XCTAssertEqual(controller.quitBlockReason, .directConfirmationPending)
            XCTAssertEqual(alert.informativeText, "Quit needs a fresh check of the saved recovery information. Review the status, then try Quit again.")
            return .alertSecondButtonReturn
        }, showControls: { XCTFail("Keep Running must not reveal controls") },
           terminate: { XCTFail("A denied attempt must not terminate") })
        let quit = try XCTUnwrap(delegate.requestQuit())
        try await waitUntil { inspection.waiting }
        backend.onChildExit?(child.id, 0)
        inspection.release(backend.snapshot)
        await quit.value
        XCTAssertEqual(presentCount, 1)
        XCTAssertFalse(controller.quitRequested)
        XCTAssertNotNil(try store.load().pending)
        XCTAssertEqual(backend.stopCount, 0)
    }

    func testOpenControlsAndKeepRunningActions() async throws {
        // Only the first response may reveal Controls; dismissal must not retry or mutate recovery.
        let controller = try await makeController(pending: true)
        await controller.start()
        XCTAssertNotNil(controller.ownedRouter)
        for (response, expectedOpenCount) in [(NSApplication.ModalResponse.alertFirstButtonReturn, 1),
                                             (.alertSecondButtonReturn, 0), (.abort, 0), (.cancel, 0)] {
            let navigation = QuitGuidanceNavigation()
            var showControlsCount = 0, terminateCount = 0, presentCount = 0
            var journalAfterDeniedAttempt: Result<CompanionJournal, Error>?
            var confirmationAfterDeniedAttempt: RouterController.DesktopConfirmation?
            var recoveryAfterDeniedAttempt: ActivationContext?
            var controlsAfterDeniedAttempt = -1, inspectionsAfterDeniedAttempt = -1, stopsAfterDeniedAttempt = -1
            let delegate = RouterAppDelegate(controller: controller, navigation: navigation, presentQuitAlert: { alert in
                presentCount += 1
                XCTAssertEqual(alert.informativeText, "Codex may still need the router. Check the direct connection before quitting.")
                journalAfterDeniedAttempt = Result { try self.store.load() }
                confirmationAfterDeniedAttempt = controller.desktopConfirmation
                recoveryAfterDeniedAttempt = controller.recoveryContext
                controlsAfterDeniedAttempt = self.backend.controls.count
                inspectionsAfterDeniedAttempt = self.backend.inspectCount
                stopsAfterDeniedAttempt = self.backend.stopCount
                return response
            }, showControls: { showControlsCount += 1 }, terminate: { terminateCount += 1 })
            defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
            let quit = try XCTUnwrap(delegate.requestQuit())
            await quit.value
            XCTAssertEqual(presentCount, 1)
            XCTAssertEqual(showControlsCount, expectedOpenCount)
            XCTAssertEqual(navigation.requestID != nil, expectedOpenCount == 1)
            XCTAssertEqual(terminateCount, 0)
            XCTAssertEqual(try store.load(), try XCTUnwrap(journalAfterDeniedAttempt).get())
            XCTAssertEqual(controller.desktopConfirmation, confirmationAfterDeniedAttempt)
            XCTAssertEqual(controller.recoveryContext, recoveryAfterDeniedAttempt)
            XCTAssertEqual(backend.controls.count, controlsAfterDeniedAttempt)
            XCTAssertEqual(backend.inspectCount, inspectionsAfterDeniedAttempt + expectedOpenCount)
            XCTAssertEqual(backend.stopCount, stopsAfterDeniedAttempt)
            XCTAssertFalse(controller.quitRequested)
        }
    }

    func testPrimaryGuidanceUsesStateAfterHeldAlert() async throws {
        // Replaying the alert's uncertainty instead of refreshing would miss idle Direct and safe Stop.
        for ownsRouter in [false, true] {
            let fixtureStore = PrivateStore(directory: root.appendingPathComponent(UUID().uuidString))
            try fixtureStore.save(CompanionJournal(selectedConfigurationPath: context.configPath,
                pending: ownsRouter ? nil : .init(context: context, phase: .directConfirmation)))
            let fixtureBackend = QuitBackend(context: context)
            let controller = RouterController(backend: fixtureBackend, store: fixtureStore, browseHome: root)
            await controller.refresh()
            if ownsRouter { await controller.start() }
            fixtureBackend.mutationRequiresReconciliation = true
            let navigation = QuitGuidanceNavigation(), alert = QuitBarrier<NSApplication.ModalResponse>()
            let inspectionsAfterSetup = fixtureBackend.inspectCount
            var showCount = 0, terminateCount = 0
            let delegate = RouterAppDelegate(controller: controller, navigation: navigation, presentQuitAlert: { presented in
                XCTAssertEqual(presented.informativeText, "A router operation is running or needs checking. Review its status before quitting.")
                return await alert.wait()
            }, showControls: { showCount += 1 }, terminate: { terminateCount += 1 })
            defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
            let quit = try XCTUnwrap(delegate.requestQuit())
            try await waitUntil { alert.waiting }
            let inspectionsAfterDeniedAttempt = fixtureBackend.inspectCount
            let journalAfterDeniedAttempt = try Data(contentsOf: fixtureStore.directory.appendingPathComponent("state.json"))
            let confirmationAfterDeniedAttempt = controller.desktopConfirmation
            XCTAssertEqual(inspectionsAfterDeniedAttempt, inspectionsAfterSetup + 1)
            XCTAssertNil(navigation.requestID)
            fixtureBackend.mutationRequiresReconciliation = false
            alert.release(.alertFirstButtonReturn)
            await quit.value
            XCTAssertNotNil(navigation.requestID)
            let expectedCurrentDestination: QuitGuidance.Destination = ownsRouter ? .stopRouter : .status
            XCTAssertEqual(QuitGuidance.current(for: controller).destination, expectedCurrentDestination)
            XCTAssertEqual(fixtureBackend.inspectCount, inspectionsAfterDeniedAttempt + 1)
            XCTAssertEqual(try Data(contentsOf: fixtureStore.directory.appendingPathComponent("state.json")), journalAfterDeniedAttempt)
            XCTAssertEqual(controller.desktopConfirmation, confirmationAfterDeniedAttempt)
            XCTAssertTrue(fixtureBackend.controls.isEmpty)
            XCTAssertEqual(fixtureBackend.stopCount, 0)
            XCTAssertEqual(showCount, 1)
            XCTAssertEqual(terminateCount, 0)
            XCTAssertFalse(controller.quitRequested)
        }
    }

    func testPrimaryGuidanceInspectionFailureUsesRecoveryFallback() async throws {
        // Publishing the old direct-response target after a failed refresh would direct users to a disabled action.
        let controller = try await makeController(pending: true)
        await controller.start()
        let navigation = QuitGuidanceNavigation()
        let baseline = backend.inspectCount
        var journalAfterDeniedAttempt: Result<Data, Error>?
        var terminateCount = 0
        let delegate = RouterAppDelegate(controller: controller, navigation: navigation, presentQuitAlert: { _ in
            journalAfterDeniedAttempt = Result { try Data(contentsOf: self.store.directory.appendingPathComponent("state.json")) }
            self.backend.inspectionError = CompanionError.commandFailed
            return .alertFirstButtonReturn
        }, showControls: {}, terminate: { terminateCount += 1 })
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        await delegate.requestQuit()?.value
        XCTAssertNotNil(navigation.requestID)
        XCTAssertEqual(QuitGuidance.current(for: controller).destination, .manualRecovery)
        XCTAssertFalse(controller.canConfirmDirectResponse)
        XCTAssertEqual(backend.inspectCount, baseline + 2)
        XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), try XCTUnwrap(journalAfterDeniedAttempt).get())
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertEqual(terminateCount, 0)
        XCTAssertFalse(controller.quitRequested)
    }

    func testWindowCloseCancelsPendingGuidance() async throws {
        // A late primary refresh must not resurrect navigation after close, and must retain the Quit guard.
        let controller = try await makeController(pending: true)
        await controller.start()
        let navigation = QuitGuidanceNavigation(), refresh = QuitBarrier<Inspection>()
        let baseline = backend.inspectCount
        var showCount = 0, terminateCount = 0
        var journalAfterDeniedAttempt: Result<Data, Error>?
        let delegate = RouterAppDelegate(controller: controller, navigation: navigation, presentQuitAlert: { _ in
            journalAfterDeniedAttempt = Result { try Data(contentsOf: self.store.directory.appendingPathComponent("state.json")) }
            self.backend.inspectBarrier = refresh
            return .alertFirstButtonReturn
        }, showControls: { showCount += 1 }, terminate: { terminateCount += 1 })
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        let quit = try XCTUnwrap(delegate.requestQuit())
        try await waitUntil { refresh.waiting }
        XCTAssertNil(navigation.requestID)
        XCTAssertEqual(showCount, 1)
        XCTAssertNil(delegate.requestQuit())
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        refresh.release(backend.snapshot)
        await quit.value
        XCTAssertNil(navigation.requestID)
        XCTAssertEqual(backend.inspectCount, baseline + 2)
        XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), try XCTUnwrap(journalAfterDeniedAttempt).get())
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertEqual(terminateCount, 0)
        XCTAssertFalse(controller.quitRequested)
    }

    func testRepeatedGuidanceRequestsHaveDistinctIdentity() async throws {
        // Reusing a destination as identity would prevent a later explicit request from navigating again.
        let controller = try await makeController(pending: true)
        await controller.start()
        let navigation = QuitGuidanceNavigation()
        let baseline = backend.inspectCount
        let journal = try Data(contentsOf: store.directory.appendingPathComponent("state.json"))
        var showCount = 0, terminateCount = 0
        let delegate = RouterAppDelegate(controller: controller, navigation: navigation,
            presentQuitAlert: { _ in .alertFirstButtonReturn }, showControls: { showCount += 1 },
            terminate: { terminateCount += 1 })
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        await delegate.requestQuit()?.value
        let firstRequestID = try XCTUnwrap(navigation.requestID)
        await controller.refresh()
        XCTAssertEqual(navigation.requestID, firstRequestID)
        await delegate.requestQuit()?.value
        let secondRequestID = try XCTUnwrap(navigation.requestID)
        XCTAssertNotEqual(firstRequestID, secondRequestID)
        await controller.refresh()
        XCTAssertEqual(navigation.requestID, secondRequestID)
        XCTAssertEqual(backend.inspectCount, baseline + 6)
        XCTAssertEqual(showCount, 2)
        XCTAssertEqual(terminateCount, 0)
        XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), journal)
        XCTAssertEqual(controller.desktopConfirmation, .unknown)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertEqual(backend.stopCount, 0)
    }

    func testWindowCloseClearsDisplayedGuidance() async throws {
        // Keeping a displayed token after close would restore obsolete emphasis on an ordinary reopen.
        let controller = try await makeController(pending: true)
        await controller.start()
        let navigation = QuitGuidanceNavigation()
        let delegate = RouterAppDelegate(controller: controller, navigation: navigation,
            presentQuitAlert: { _ in .alertFirstButtonReturn }, showControls: {}, terminate: { XCTFail("Guidance must not exit") })
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        await delegate.requestQuit()?.value
        XCTAssertNotNil(navigation.requestID)
        delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        XCTAssertNil(navigation.requestID)
        await controller.refresh()
        XCTAssertNil(navigation.requestID)
        XCTAssertFalse(controller.quitRequested)
    }

    func testCancellationPreservesExistingGuidance() async throws {
        // Clearing or replacing navigation on dismissal would change the existing window without a primary request.
        let controller = try await makeController(pending: true)
        await controller.start()
        let navigation = QuitGuidanceNavigation()
        let existing = navigation.beginRequest(); navigation.present(existing)
        for response in [NSApplication.ModalResponse.alertSecondButtonReturn, .abort, .cancel] {
            let baseline = backend.inspectCount
            let journal = try Data(contentsOf: store.directory.appendingPathComponent("state.json"))
            let delegate = RouterAppDelegate(controller: controller, navigation: navigation,
                presentQuitAlert: { _ in response }, showControls: { XCTFail("Dismissal must preserve window visibility") },
                terminate: { XCTFail("Dismissal must not exit") })
            defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
            await delegate.requestQuit()?.value
            XCTAssertEqual(navigation.requestID, existing)
            XCTAssertEqual(backend.inspectCount, baseline + 1)
            XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), journal)
            XCTAssertEqual(controller.desktopConfirmation, .unknown)
            XCTAssertTrue(backend.controls.isEmpty)
            XCTAssertEqual(backend.stopCount, 0)
            XCTAssertFalse(controller.quitRequested)
        }
    }

    func testQuitClaimsSynchronouslyAndIgnoresRepeatedRequests() async throws {
        // Moving the guard into the Task would admit a second request before either Task runs.
        let controller = try await makeController(pending: true)
        await controller.start()
        XCTAssertNotNil(controller.ownedRouter)
        var presentCount = 0, terminateCount = 0
        let baselineInspections = backend.inspectCount
        let delegate = RouterAppDelegate(controller: controller, presentQuitAlert: { _ in
            presentCount += 1; return .alertSecondButtonReturn
        }, showControls: {}, terminate: { terminateCount += 1 })
        let first = delegate.requestQuit()
        XCTAssertNotNil(first)
        XCTAssertNil(delegate.requestQuit())
        await first?.value
        XCTAssertEqual(presentCount, 1)
        XCTAssertEqual(backend.inspectCount, baselineInspections + 1)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertEqual(terminateCount, 0)
        // A later explicit request is permitted once the earlier response has completed.
        await delegate.requestQuit()?.value
        XCTAssertEqual(presentCount, 2)
        XCTAssertEqual(backend.inspectCount, baselineInspections + 2)
    }

    func testHeldQuitAndAlertRejectReentrantTermination() async throws {
        // Clearing the guard before stop or the modal response would queue duplicate cleanup/alerts.
        let controller = try await makeController()
        await controller.start()
        let baselineInspections = backend.inspectCount
        let inspection = QuitBarrier<Inspection>(), stop = QuitBarrier<StopOutcome>()
        let alert = QuitBarrier<NSApplication.ModalResponse>()
        backend.inspectBarrier = inspection; backend.stopBarrier = stop
        var presentCount = 0, terminateCount = 0, showControlsCount = 0
        let delegate = RouterAppDelegate(controller: controller, presentQuitAlert: { _ in
            presentCount += 1; return await alert.wait()
        }, showControls: { showControlsCount += 1 }, terminate: { terminateCount += 1 })
        let quit = try XCTUnwrap(delegate.requestQuit())
        try await waitUntil { inspection.waiting }
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertNil(delegate.requestQuit())
        inspection.release(backend.snapshot)
        try await waitUntil { stop.waiting }
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertNil(delegate.requestQuit())
        XCTAssertEqual(backend.stopCount, 1)
        stop.release(.init(childExited: false, portState: .unknown))
        try await waitUntil { alert.waiting }
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertNil(delegate.requestQuit())
        alert.release(.alertSecondButtonReturn)
        await quit.value
        XCTAssertEqual(presentCount, 1)
        XCTAssertEqual(backend.inspectCount, baselineInspections + 1)
        XCTAssertEqual(backend.stopCount, 1)
        XCTAssertEqual(terminateCount, 0)
        XCTAssertEqual(showControlsCount, 0)
        XCTAssertNotNil(controller.ownedRouter)
        XCTAssertFalse(controller.quitRequested)
    }

    func testStateChangeDuringAlertDoesNotRetryOrTerminate() async throws {
        // A newly safe state must require another explicit Quit after this alert is dismissed.
        let controller = try await makeController(pending: true)
        backend.mutationRequiresReconciliation = true
        let bytesBefore = try Data(contentsOf: store.directory.appendingPathComponent("state.json"))
        let alert = QuitBarrier<NSApplication.ModalResponse>()
        var presentCount = 0, terminateCount = 0, showControlsCount = 0
        let delegate = RouterAppDelegate(controller: controller, presentQuitAlert: { _ in
            presentCount += 1
            return presentCount == 1 ? await alert.wait() : .alertSecondButtonReturn
        }, showControls: { showControlsCount += 1 }, terminate: { terminateCount += 1 })
        let quit = try XCTUnwrap(delegate.requestQuit())
        try await waitUntil { alert.waiting }
        backend.mutationRequiresReconciliation = false
        await controller.refresh()
        XCTAssertTrue(controller.canConfirmDirectResponse)
        XCTAssertFalse(controller.canQuit)
        let inspectionsAfterRefresh = backend.inspectCount
        XCTAssertNil(delegate.requestQuit())
        alert.release(.alertSecondButtonReturn)
        await quit.value
        XCTAssertEqual(presentCount, 1)
        XCTAssertEqual(terminateCount, 0)
        XCTAssertEqual(showControlsCount, 0)
        XCTAssertFalse(controller.quitRequested)
        XCTAssertEqual(backend.inspectCount, inspectionsAfterRefresh)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertTrue(backend.controls.isEmpty)
        XCTAssertNotNil(try store.load().pending)
        XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), bytesBefore)
        await delegate.requestQuit()?.value
        XCTAssertTrue(controller.quitRequested)
        XCTAssertEqual(terminateCount, 1)
        XCTAssertEqual(presentCount, 1)
        XCTAssertEqual(backend.inspectCount, inspectionsAfterRefresh + 1)
        XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent("state.json")), bytesBefore)
    }

    func testIdlePendingQuitTerminatesWithoutAlert() async throws {
        // The real delegate must terminate after fresh idle permission without consuming recovery or presenting an alert.
        let controller = try await makeController(pending: true)
        let state = store.directory.appendingPathComponent("state.json")
        let bytesBefore = try Data(contentsOf: state)
        let baselineInspections = backend.inspectCount
        var terminateCount = 0, presentCount = 0
        let delegate = RouterAppDelegate(controller: controller, presentQuitAlert: { _ in
            presentCount += 1; return .alertSecondButtonReturn
        }, showControls: { XCTFail("Idle Quit must not open Controls") }, terminate: { terminateCount += 1 })
        await delegate.requestQuit()?.value
        XCTAssertEqual(terminateCount, 1)
        XCTAssertEqual(presentCount, 0)
        XCTAssertTrue(controller.quitRequested)
        XCTAssertTrue(controller.canQuit)
        XCTAssertNotEqual(controller.desktopConfirmation, .confirmedDirect)
        XCTAssertEqual(try Data(contentsOf: state), bytesBefore)
        XCTAssertEqual(backend.inspectCount, baselineInspections + 1)
        XCTAssertEqual(backend.stopCount, 0)
        XCTAssertTrue(backend.controls.isEmpty)
    }

    func testSuccessfulAndSafeExceptionQuitsSkipAlert() async throws {
        // Successful authorization, including pre-operation safe exceptions, must exit without a dialog.
        let normal = try await makeController()
        let secondBackend = QuitBackend(context: context)
        secondBackend.mutationRequiresReconciliation = true
        let second = RouterController(backend: secondBackend, store: PrivateStore(directory: store.directory), browseHome: root)
        let invalidStore = root.appendingPathComponent("invalid-store")
        try Data(sentinel.utf8).write(to: invalidStore)
        let failedBackend = QuitBackend(context: context)
        failedBackend.mutationRequiresReconciliation = true
        let failed = RouterController(backend: failedBackend, store: PrivateStore(directory: invalidStore), browseHome: root)
        XCTAssertEqual(second.error, CompanionError.instanceRunning.rawValue)
        XCTAssertEqual(failed.error, CompanionError.privateState.rawValue)
        for controller in [normal, failed, second] {
            var presentCount = 0, terminateCount = 0, showControlsCount = 0
            let delegate = RouterAppDelegate(controller: controller, presentQuitAlert: { _ in
                presentCount += 1; return .alertSecondButtonReturn
            }, showControls: { showControlsCount += 1 }, terminate: { terminateCount += 1 })
            await delegate.requestQuit()?.value
            XCTAssertTrue(controller.quitRequested)
            XCTAssertTrue(controller.canQuit)
            XCTAssertEqual(presentCount, 0)
            XCTAssertEqual(terminateCount, 1)
            XCTAssertEqual(showControlsCount, 0)
            XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        }
        XCTAssertEqual(secondBackend.inspectCount, 0)
        XCTAssertEqual(failedBackend.inspectCount, 0)
        XCTAssertEqual(try Data(contentsOf: invalidStore), Data(sentinel.utf8))
    }

    func testTerminationCallbackWaitsForExistingAuthorization() async throws {
        // A safe-looking cached state cannot return terminateNow before the controller's fresh attempt.
        let controller = try await makeController()
        let inspection = QuitBarrier<Inspection>()
        backend.inspectBarrier = inspection
        var terminateCount = 0, presentCount = 0
        let delegate = RouterAppDelegate(controller: controller, presentQuitAlert: { _ in
            presentCount += 1; return .alertSecondButtonReturn
        }, showControls: {}, terminate: {
            terminateCount += 1
        })
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        try await waitUntil { inspection.waiting }
        XCTAssertEqual(terminateCount, 0)
        XCTAssertFalse(controller.quitRequested)
        inspection.release(backend.snapshot)
        try await waitUntil { terminateCount == 1 }
        XCTAssertTrue(controller.quitRequested)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertEqual(presentCount, 0)
    }

    private func waitUntil(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        XCTFail("Quit did not reach its controlled boundary", file: file, line: line)
        throw QuitFixtureError.boundaryNotReached
    }
}

private enum QuitFixtureError: Error { case boundaryNotReached }
@MainActor private final class QuitBarrier<Value> {
    private var continuation: CheckedContinuation<Value, Never>?
    private(set) var waiting = false
    func wait() async -> Value {
        await withCheckedContinuation { continuation = $0; waiting = true }
    }
    func release(_ value: Value) { continuation?.resume(returning: value); continuation = nil }
}
private final class QuitSyntheticProcess: Process, @unchecked Sendable {
    override var isRunning: Bool { true }
}
@MainActor private final class QuitBackend: CompanionBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false
    var snapshot: Inspection
    var inspectionError: Error?
    var inspectBarrier: QuitBarrier<Inspection>?
    var stopBarrier: QuitBarrier<StopOutcome>?
    private(set) var inspectCount = 0
    private(set) var stopCount = 0
    private(set) var controls: [ControlAction] = []
    init(context: ActivationContext) {
        snapshot = Inspection(configuration: .init(state: "valid", path: context.configPath, mode: "legacy"),
            context: context, revision: "SYNTHETIC_PRIVATE_SENTINEL",
            provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"),
            catalog: .init(state: "ready", entries: []))
    }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection {
        inspectCount += 1
        if let barrier = inspectBarrier { inspectBarrier = nil; return await barrier.wait() }
        if let inspectionError { throw inspectionError }
        return snapshot
    }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ validatedPath: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter {
        let child = OwnedRouter(process: QuitSyntheticProcess(), context: snapshot.context!)
        snapshot.provider.proxyReady = true
        return child
    }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult {
        controls.append(action)
        throw CompanionError.commandFailed
    }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode { throw CompanionError.routingModeUnavailable }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode { throw CompanionError.routingModeUnavailable }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome {
        stopCount += 1
        if let barrier = stopBarrier { stopBarrier = nil; return await barrier.wait() }
        return StopOutcome(childExited: false, portState: .unknown)
    }
}
