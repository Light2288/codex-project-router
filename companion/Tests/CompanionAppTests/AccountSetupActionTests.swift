import XCTest
import AppKit
import SwiftUI
import Security
import UniformTypeIdentifiers
@testable import CompanionCore
@testable import CodexProjectRouter

@MainActor final class AccountSetupActionTests: XCTestCase {
    func testDestinationInstructionsCopyWithoutChangingFileDialogActions() async throws {
        try await withSetup { router, setup, backend in
            backend.snapshot.configuration = .init(state: "missing")
            backend.snapshot.context = nil
            await router.refresh()
            let original = router.selectedConfiguration
            let host = NativeProjectHost(ControlsView(controller: router, navigation: QuitGuidanceNavigation(), accountSetup: setup))
            let clipboard = NativeClipboard()
            defer {
                for panel in NSApp.windows.compactMap({ $0 as? NSSavePanel }) where panel.isVisible { panel.cancel(nil) }
                clipboard.restore(); host.close()
            }
            await host.settle()
            let instructions = "Choose a new file in a private directory outside Git. The setup preview uses the compatible direct provider; this does not start routing or create the configuration."
            try host.press(title: "Create private configuration…", in: host.window)
            for _ in 0..<30 where !NSApp.windows.contains(where: { $0 is NSSavePanel && $0.isVisible }) { await host.settle() }
            let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? NSSavePanel }.first { $0.isVisible })
            let destination = URL(fileURLWithPath: backend.preview.context.configPath).deletingLastPathComponent().appendingPathComponent("selected-config.json")
            await host.settle()
            XCTAssertEqual(panel.allowedContentTypes, [.json])
            XCTAssertTrue(panel.canCreateDirectories)
            for _ in 0..<30 where panel.accessoryView?.window == nil { await host.settle() }
            let accessory = try XCTUnwrap(panel.accessoryView as? NSTextField)
            let accessoryWindow = try XCTUnwrap(accessory.window)
            XCTAssertGreaterThanOrEqual(accessory.bounds.height, accessory.fittingSize.height)
            // AppKit hosts our accessory in a local window alongside the remote file browser.
            try host.selectText(instructions, range: NSRange(location: 0, length: instructions.utf16.count), in: accessoryWindow)
            XCTAssertEqual(try host.copySelection(in: accessoryWindow), instructions)
            XCTAssertEqual(router.selectedConfiguration, original)
            XCTAssertEqual(backend.commits, 0)
            try host.snapshot("destination-selected-instructions", in: accessoryWindow)
            try host.pressKey("\u{1b}", keyCode: 53, in: panel)
            for _ in 0..<30 where panel.isVisible { await host.settle() }
            XCTAssertFalse(panel.isVisible)
            XCTAssertEqual(router.selectedConfiguration, original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            XCTAssertEqual(backend.commits, 0)
            XCTAssertEqual(backend.activations, 0)
            XCTAssertEqual(backend.starts, 0)
        }
    }

    func testNativeDestinationConfirmationInvokesExistingSelectionCallback() async throws {
        try await withSetup { router, setup, backend in
            backend.snapshot.configuration = .init(state: "missing")
            backend.snapshot.context = nil
            await router.refresh()
            let host = NativeProjectHost(ControlsView(controller: router, navigation: QuitGuidanceNavigation(), accountSetup: setup))
            defer {
                for panel in NSApp.windows.compactMap({ $0 as? NSSavePanel }) where panel.isVisible { panel.cancel(nil) }
                host.close()
            }
            await host.settle()
            try host.press(title: "Create private configuration…", in: host.window)
            for _ in 0..<30 where !NSApp.windows.contains(where: { $0 is NSSavePanel && $0.isVisible }) { await host.settle() }
            let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? NSSavePanel }.first { $0.isVisible })
            for _ in 0..<30 where panel.url == nil { await host.settle() }
            let directory = try XCTUnwrap(panel.url).deletingLastPathComponent()
            // Save only chooses a nonexistent destination; the synthetic backend never writes it.
            let destination = directory.appendingPathComponent("selection-check-\(UUID().uuidString).json")
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            backend.preview.context = .init(configPath: destination.path, codexHome: backend.preview.context.codexHome,
                providerId: backend.preview.context.providerId, listenPort: backend.preview.context.listenPort)
            backend.preview.sourceKind = "missing"
            backend.preview.defaultAccountId = nil
            backend.preview.incomingCredential = nil
            try await host.confirmDestination(destination)
            for _ in 0..<30 where router.selectedConfiguration != destination { await host.settle() }
            XCTAssertEqual(router.selectedConfiguration, destination)
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
            XCTAssertEqual(backend.commits, 0)
            XCTAssertEqual(backend.activations, 0)
            XCTAssertEqual(backend.starts, 0)
        }
    }

    func testInformationalTextCopiesAndNativeKeyRemainsConcealed() async throws {
        try await withMetadataBrowser { host, native, backend in
            let clipboard = NativeClipboard()
            defer { clipboard.restore() }
            let guidance = "Saving changes the private router configuration only. Credential access and upstream responses remain unverified. The next explicit Start uses these settings with project routing Off."
            try host.selectText(guidance, range: NSRange(location: 0, length: guidance.utf16.count))
            XCTAssertEqual(try host.copySelection(), guidance)
            try host.selectText("No metadata lookup yet.", range: NSRange(location: 0, length: 23))
            XCTAssertEqual(try host.copySelection(), "No metadata lookup yet.")
            try host.press(title: "Enter new key…", in: host.window)
            await host.settle()
            let secure = try XCTUnwrap(host.elements().compactMap {
                ($0.object as? NSCell)?.controlView as? NSSecureTextField ?? $0.object as? NSSecureTextField
            }.first)
            XCTAssertTrue(host.window.makeFirstResponder(secure))
            let editor = try XCTUnwrap(secure.currentEditor() as? NSTextView)
            editor.insertText("SYNTHETIC_SELECTION_KEY", replacementRange: editor.selectedRange())
            editor.selectAll(nil)
            XCTAssertFalse(try host.copySelection().contains("SYNTHETIC_SELECTION_KEY"))
            XCTAssertFalse(host.text.contains("SYNTHETIC_SELECTION_KEY"))
            let explanation = "The key is passed directly to native Keychain creation. No reveal control is provided."
            try host.selectText(explanation, range: NSRange(location: 0, length: explanation.utf16.count))
            XCTAssertEqual(try host.copySelection(), explanation)
            try host.press(title: "Use existing item instead", in: host.window)
            await host.settle()
            XCTAssertFalse(host.text.contains("SYNTHETIC_SELECTION_KEY"))
            XCTAssertEqual(native.creates, 0)
            XCTAssertEqual(backend.commits, 0)
            XCTAssertEqual(backend.activations, 0)
            try host.snapshot("selectable-account", width: 650, height: 690)
        }
    }

    private func withSetup(_ body: (RouterController, AccountSetupController, AppAccountBackend) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("account-app-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { XCTFail("Synthetic account app cleanup failed: \(error)") }
        }
        let backend = AppAccountBackend(root: root), store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(.init(selectedConfigurationPath: backend.preview.context.configPath))
        let router = RouterController(backend: backend, store: store, browseHome: root)
        // No Keychain method is invoked: all saves here select existing synthetic references.
        let setup = AccountSetupController(router: router, backend: backend, keychain: KeychainStore(), browseHome: root)
        await router.refresh(); await setup.refresh()
        try await body(router, setup, backend)
    }
    private func withMetadataBrowser(_ body: (NativeProjectHost, AccountMetadataSecurity, AppAccountBackend) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("metadata-app-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { XCTFail("Synthetic metadata fixture cleanup failed: \(error)") }
        }
        let backend = AppAccountBackend(root: root), store = PrivateStore(directory: root.appendingPathComponent("companion"))
        try store.save(.init(selectedConfigurationPath: backend.preview.context.configPath))
        let router = RouterController(backend: backend, store: store, browseHome: root)
        let native = AccountMetadataSecurity()
        let keychain = KeychainStore(security: native, companionPath: "/Synthetic.app/Contents/MacOS/Companion")
        let setup = AccountSetupController(router: router, backend: backend, keychain: keychain, browseHome: root)
        await router.refresh(); await setup.refresh()
        let host = NativeProjectHost(AccountSetupView(router: router, setup: setup, intent: .add))
        defer { native.gate?.signal(); host.close() }
        await host.settle()
        try host.press(title: "Choose existing item…", in: host.window)
        await host.settle()
        try await body(host, native, backend)
        XCTAssertEqual(native.creates, 0); XCTAssertEqual(backend.commits, 0); XCTAssertEqual(backend.starts, 0)
        XCTAssertEqual(backend.activations, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: backend.preview.context.configPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("account-setup.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".activation.lock").path))
    }
    private func waitForMetadata(_ text: String, host: NativeProjectHost) async {
        for _ in 0..<30 {
            await host.settle()
            if host.text.contains(text) { return }
        }
        XCTFail("Missing metadata status \(text). Tree: \(host.text)")
    }
    private func editMetadataField(_ element: NativeAXElement?, value: String, host: NativeProjectHost) throws {
        let element = try XCTUnwrap(element)
        let field = try XCTUnwrap((element.object as? NSCell)?.controlView as? NSTextField ?? element.object as? NSTextField)
        XCTAssertTrue(host.window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.selectAll(nil); editor.insertText(value, replacementRange: editor.selectedRange())
    }
    private func snapshotMetadata(_ name: String, host: NativeProjectHost) async throws {
        host.window.setContentSize(NSSize(width: 650, height: 690))
        await host.settle()
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let content = try XCTUnwrap(host.window.contentView)
        let scroll = try XCTUnwrap(descendants(content).compactMap { $0 as? NSScrollView }.first)
        let document = try XCTUnwrap(scroll.documentView)
        let status = try XCTUnwrap(host.find("keychain-lookup-status"))
        let first = try XCTUnwrap(host.find("keychain-service-filter"))
        let use = try XCTUnwrap(host.find("keychain-use-reference"))
        let target = first.accessibilityFrame().union(status.accessibilityFrame()).union(use.accessibilityFrame())
        let local = document.convert(host.window.convertFromScreen(target), from: nil)
        document.scrollToVisible(local.insetBy(dx: 0, dy: -20))
        await host.settle()
        let visible = host.window.convertToScreen(scroll.contentView.convert(scroll.contentView.bounds, to: nil))
        XCTAssertTrue(visible.contains(status.accessibilityFrame()), "Lookup explanation must be reachable through scrolling")
        XCTAssertTrue(visible.contains(use.accessibilityFrame()), "Use action must remain reachable")
        try host.snapshot(name, width: 650, height: 690)
    }
    func testMetadataBrowserClearsStaleEvidenceWithoutApplyingReferences() async throws {
        try await withMetadataBrowser { host, native, backend in
            let before = backend.preview
            let nameField = host.elements().first {
                let field = ($0.object as? NSCell)?.controlView as? NSTextField ?? $0.object as? NSTextField
                return field?.placeholderString == "Account display name"
            }
            try self.editMetadataField(nameField, value: "Draft preserved", host: host)
            native.rows = [[kSecAttrService as String: "Synthetic service", kSecAttrAccount as String: "Synthetic account"], [:]]
            try host.press("keychain-lookup")
            await self.waitForMetadata("1 unsupported item omitted", host: host)
            XCTAssertTrue(host.text.contains("1 match."))
            XCTAssertFalse(try XCTUnwrap(host.find("keychain-use-reference")).isAccessibilityEnabled())
            XCTAssertTrue(host.text.contains("No outgoing credential selected"))
            try await self.snapshotMetadata("keychain-mixed-results", host: host)
            native.rows = [[:], [:]]
            try host.press("keychain-lookup")
            await self.waitForMetadata("2 unsupported items omitted", host: host)
            XCTAssertTrue(host.text.contains("0 matches."))
            try await self.snapshotMetadata("keychain-omitted-only", host: host)
            native.rows = []
            try host.press("keychain-lookup")
            await self.waitForMetadata("completed: 0 matches", host: host)
            XCTAssertFalse(host.text.contains("unsupported items omitted"))
            native.rows = [[kSecAttrService as String: "Synthetic service", kSecAttrAccount as String: "Synthetic account"], [:]]
            try host.press("keychain-lookup")
            await self.waitForMetadata("1 unsupported item omitted", host: host)
            native.failure = .nativeStatus(errSecInteractionNotAllowed)
            try host.press("keychain-lookup")
            await self.waitForMetadata("Metadata lookup failed", host: host)
            XCTAssertTrue(host.text.contains("Entries supplied to Matching item: 0"))
            XCTAssertFalse(host.text.contains("unsupported item omitted"))
            XCTAssertFalse(try XCTUnwrap(host.find("keychain-use-reference")).isAccessibilityEnabled())
            XCTAssertTrue(host.text.contains("Draft preserved"))
            XCTAssertEqual(backend.preview, before)
            try await self.snapshotMetadata("keychain-failed", host: host)
        }
    }
    func testMetadataBrowserCapturesScopeWhileFiltersChange() async throws {
        try await withMetadataBrowser { host, native, backend in
            let entered = self.expectation(description: "Held metadata query")
            let gate = DispatchSemaphore(value: 0)
            native.gate = gate; native.entered = { entered.fulfill() }
            native.rows = [[:]]
            try host.press("keychain-lookup")
            await self.fulfillment(of: [entered], timeout: 3)
            await host.settle()
            XCTAssertTrue(host.text.contains("waiting for the result"))
            XCTAssertFalse(try XCTUnwrap(host.find("keychain-use-reference")).isAccessibilityEnabled())
            XCTAssertTrue(host.text.contains("Entries supplied to Matching item: 0"))
            try self.editMetadataField(host.find("keychain-service-filter"), value: "edited-during-query", host: host)
            try await self.snapshotMetadata("keychain-pending", host: host)
            gate.signal()
            await self.waitForMetadata("1 unsupported item omitted", host: host)
            XCTAssertTrue(host.text.contains("any service"))
            XCTAssertFalse(host.text.contains("service filter supplied"))
            XCTAssertNil(native.lastQuery?[kSecAttrService as String])
            XCTAssertEqual(backend.commits, 0)
        }
    }

    func testAddingThroughFormPreservesDefaultAndBindingsWithoutActivation() async throws {
        try await withSetup { router, setup, backend in
            var form = AccountSetupForm(preview: try XCTUnwrap(setup.preview), intent: .add)
            form.accounts[0].displayName = "Work"; form.accounts[0].upstreamBaseUrl = "https://work.example/api"
            form.accounts[0].credential = .init(keychainPath: "/synthetic/items.keychain-db", service: "Work", account: "Work")
            var entry = AccountSecretEntry(); entry.value = "SYNTHETIC_UNUSED"
            let submission = try form.prepareSave(entry: &entry)
            XCTAssertEqual(entry.value, ""); XCTAssertNil(submission.secret)
            let bindings = backend.preview.routeAccounts
            await setup.save(submission.change, creatingCredentialFor: submission.accountID, secret: submission.secret)
            XCTAssertEqual(setup.state, .saved)
            XCTAssertEqual(setup.preview?.defaultAccountId, "11111111-1111-4111-8111-111111111111")
            XCTAssertEqual(setup.preview?.routeAccounts, bindings)
            XCTAssertEqual(setup.preview?.accounts.map(\.displayName), ["Personal", "Work"])
            XCTAssertNil(router.ownedRouter); XCTAssertEqual(backend.starts, 0); XCTAssertEqual(backend.activations, 0)
            XCTAssertEqual(router.desktopConfirmation, .unknown)
            XCTAssertTrue(AccountSetupPresentation(state: setup.state, routerCanSave: router.canBeginAccountSetup, createdItem: false).guidance.contains("unverified"))
        }
    }
    func testOpeningFormWhileRunningIsReadOnlyAndSaveExplainsStop() async throws {
        try await withSetup { router, setup, backend in
            await router.start()
            let saved = backend.preview
            await setup.refresh()
            XCTAssertEqual(setup.state, .ready)
            let presentation = AccountSetupPresentation(state: setup.state, routerCanSave: router.canBeginAccountSetup, createdItem: false)
            XCTAssertFalse(presentation.canSave); XCTAssertTrue(presentation.guidance.contains("Stop"))
            XCTAssertEqual(backend.preview, saved); XCTAssertEqual(backend.commits, 0); XCTAssertEqual(backend.starts, 1)
            XCTAssertEqual(backend.activations, 0)
            let delegate = RouterAppDelegate(controller: router, accountSetup: setup)
            XCTAssertTrue(delegate.windowShouldClose(NSWindow()), "Read-only browsing preserves ordinary Controls close")
            XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
        }
    }
    func testSavingKeepsControlsAndSheetAvailableUntilOutcome() async throws {
        try await withSetup { router, setup, backend in
            var policies: [NSApplication.ActivationPolicy] = []
            let delegate = RouterAppDelegate(controller: router, accountSetup: setup,
                setActivationPolicy: { policies.append($0); return true })
            defer {
                delegate.controlsWindow?.close()
                delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
            delegate.openControls()
            let window = try XCTUnwrap(delegate.controlsWindow)
            await router.refreshAndWait()
            backend.holdCommit = true
            var form = AccountSetupForm(preview: try XCTUnwrap(setup.preview), intent: .setDefault)
            form.defaultSelection = AccountSetupForm.noDefault
            let change = try form.change()
            let saving = Task { await setup.save(change) }
            await backend.waitForCommit()
            XCTAssertEqual(setup.state, .saving); XCTAssertFalse(setup.canDismiss)
            XCTAssertFalse(delegate.windowShouldClose(window))
            window.performClose(nil)
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(policies, [.regular])
            XCTAssertFalse(AccountSetupPresentation(state: setup.state, routerCanSave: router.canBeginAccountSetup, createdItem: false).canSave)
            XCTAssertEqual(QuitGuidance.current(for: router).destination, .status)
            backend.releaseCommit(); await saving.value
            XCTAssertEqual(setup.state, .saved); XCTAssertTrue(setup.canDismiss)
            XCTAssertTrue(delegate.windowShouldClose(window))
            window.performClose(nil)
            XCTAssertFalse(window.isVisible)
            XCTAssertEqual(policies, [.regular, .accessory])
            XCTAssertNil(setup.preview?.defaultAccountId); XCTAssertFalse(router.canStart)
            XCTAssertEqual(backend.activations, 0); XCTAssertEqual(backend.starts, 0)
        }
    }
}

@MainActor private final class AppAccountBackend: CompanionBackend, AccountSetupBackend {
    var onChildExit: ((UUID, Int32) -> Void)?
    var mutationRequiresReconciliation = false
    var setupHelperIsRunning = false
    var uncertainSetupOperationID: String?
    var preview: SetupPreview
    var snapshot: Inspection
    var starts = 0, activations = 0, commits = 0
    var holdCommit = false
    private var commitWaiter: CheckedContinuation<Void, Never>?
    private var commitStarted: CheckedContinuation<Void, Never>?
    private var isCommitting = false
    init(root: URL) {
        let context = ActivationContext(configPath: root.appendingPathComponent("config.json").path, codexHome: root.appendingPathComponent("codex").path, providerId: "synthetic", listenPort: 43123)
        let account = SetupPreview.Account(id: "11111111-1111-4111-8111-111111111111", displayName: "Personal", upstreamBaseUrl: "https://personal.example/api", credential: .init(keychainPath: "/synthetic/items.keychain-db", service: "Personal", account: "Personal"), sourceAlias: nil)
        preview = .init(context: context, configurationRevision: "initial-synthetic-revision", setupState: "ready", sourceKind: "accounts", accounts: [account], routeAccounts: ["saved": account.id, "legacy": nil], incomingCredential: .init(keychainPath: "/synthetic/items.keychain-db", service: "Incoming", account: "Desktop"), defaultAccountId: account.id, incomingHint: nil, originalDirect: account)
        snapshot = .init(configuration: .init(state: "valid", path: context.configPath, mode: "accounts", setupState: "ready", defaultAccount: .init(id: account.id, displayName: account.displayName)), context: context, revision: "operational-revision", provider: .init(state: "direct", recoveryRequired: false, proxyReady: false, recordPhase: "none"), catalog: .init(state: "ready", entries: [.init(id: "saved-id", name: "Saved", routeAlias: "saved", routeState: "mapped"), .init(id: "missing-id", name: "", routeAlias: "legacy", routeState: "catalog_missing")]))
    }
    func inspect(configPath: URL?, browseHome: URL) async throws -> Inspection { snapshot }
    func previewSetup(configPath: URL, browseHome: URL) async throws -> SetupPreview { preview }
    func commitSetup(_ change: SetupChange, context: ActivationContext, revision: String, operationID: String) async throws -> SetupCommitResult {
        commits += 1; isCommitting = true; commitStarted?.resume(); commitStarted = nil
        if holdCommit { await withCheckedContinuation { commitWaiter = $0 } }
        guard context == preview.context, revision == preview.configurationRevision else { throw CompanionError.protocolFailure }
        switch change {
        case let .addAccount(account, incoming):
            preview.accounts.append(.init(id: account.id, displayName: account.displayName, upstreamBaseUrl: account.upstreamBaseUrl, credential: account.credential, sourceAlias: nil))
            if let incoming { preview.incomingCredential = incoming }
        case let .setDefault(id, incoming):
            preview.defaultAccountId = id; if let incoming { preview.incomingCredential = incoming }
        default: throw CompanionError.protocolFailure
        }
        preview.configurationRevision = "saved-synthetic-revision"; preview.setupState = preview.defaultAccountId == nil ? "required" : "ready"
        snapshot.configuration.setupState = preview.setupState
        snapshot.configuration.defaultAccount = preview.accounts.first(where: { $0.id == preview.defaultAccountId }).map { .init(id: $0.id, displayName: $0.displayName) }
        return .init(context: context, operationId: operationID, setupState: preview.setupState, configurationRevision: preview.configurationRevision, checkpointPath: nil, changed: true)
    }
    func waitForCommit() async { if !isCommitting { await withCheckedContinuation { commitStarted = $0 } } }
    func releaseCommit() { commitWaiter?.resume(); commitWaiter = nil }
    func probeSetupPort(_ context: ActivationContext) async -> StopOutcome.PortState { .empty }
    func finishSetupReconciliation(operationID: String) throws { throw CompanionError.mutationUncertain }
    func validateNode(_ path: URL) async throws -> URL { path }
    func setNodeExecutable(_ validatedPath: URL) {}
    func start(configPath: URL) async throws -> OwnedRouter { starts += 1; snapshot.provider.proxyReady = true; return .init(process: AppAccountProcess(), context: preview.context) }
    func control(action: ControlAction, configPath: URL, expectedContext: ActivationContext) async throws -> ControlResult { activations += 1; throw CompanionError.commandFailed }
    func readRoutingMode(_ child: OwnedRouter) async throws -> ProjectRoutingMode { .off }
    func setRoutingMode(_ mode: ProjectRoutingMode, for child: OwnedRouter) async throws -> ProjectRoutingMode { mode }
    func stop(_ child: OwnedRouter) async throws -> StopOutcome { throw CompanionError.unownedChild }
}
private final class AppAccountProcess: Process, @unchecked Sendable {
    override var isRunning: Bool { true }
}

// Only the native metadata boundary is faked; production store/controller/view behavior runs unchanged.
private final class AccountMetadataSecurity: KeychainSecurity {
    var rows: [[String: Any]] = [], failure: KeychainError?, gate: DispatchSemaphore?, entered: (() -> Void)?
    var lastQuery: [String: Any]?, creates = 0
    func searchListPaths() throws -> [String] { ["/synthetic/items.keychain-db"] }
    func defaultKeychainPath() throws -> String { "/synthetic/items.keychain-db" }
    func metadata(keychainPath: String, query: [String: Any]) throws -> [[String: Any]] {
        lastQuery = query
        let result = rows, error = failure, held = gate
        entered?()
        if let held, held.wait(timeout: .now() + 10) != .success { throw KeychainError.nativeStatus(errSecUserCanceled) }
        if let error { throw error }
        return result
    }
    func create(reference: CredentialReference, secret: UnsafeRawBufferPointer, trustedApplicationPaths: [String]) throws {
        creates += 1
        throw KeychainError.unsupported
    }
}
