import SwiftUI
import AppKit
import CompanionCore

@main struct RouterApp: App {
    @NSApplicationDelegateAdaptor(RouterAppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            Button("Open controls…") { delegate.openControls() }.keyboardShortcut("o")
            Button("Refresh") { Task { await delegate.controller.refresh() } }
            Divider()
            Button("Quit Codex Project Router") { delegate.requestQuit() }.keyboardShortcut("q")
        } label: {
            Group {
                if let icon = NSImage(named: "MenuBarIconTemplate") {
                    Image(nsImage: icon).renderingMode(.template)
                } else {
                    Image(systemName: "arrow.triangle.branch")
                        .onAppear { NSLog("Menu-bar artwork unavailable; using the routing symbol.") }
                }
            }
            .accessibilityLabel("Codex Project Router")
        }
    }
}

@MainActor final class RouterAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let controller: RouterController
    let accountSetup: AccountSetupController?
    let navigation: QuitGuidanceNavigation
    private var controlsWindow: NSWindow?
    private var polling: Timer?
    private var quitInProgress = false
    private var terminationApproved = false
    private let presentQuitAlert: @MainActor (NSAlert) async -> NSApplication.ModalResponse
    private let showControls: (@MainActor () -> Void)?
    private let terminate: @MainActor () -> Void

    override convenience init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let resources = (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("router")
        let backend = ProcessBackend(resourcesURL: resources, nodeExecutable: nil)
        let controller = RouterController(backend: backend,
            store: PrivateStore(directory: home.appendingPathComponent(".codex-project-router/companion")),
            browseHome: home.appendingPathComponent(".codex"))
        let setup = AccountSetupController(router: controller, backend: backend, keychain: KeychainStore(), browseHome: home.appendingPathComponent(".codex"))
        self.init(controller: controller, accountSetup: setup)
    }
    init(controller: RouterController,
         accountSetup: AccountSetupController? = nil,
         navigation: QuitGuidanceNavigation? = nil,
         presentQuitAlert: @escaping @MainActor (NSAlert) async -> NSApplication.ModalResponse = {
             NSApp.activate(ignoringOtherApps: true)
             return $0.runModal()
         },
         showControls: (@MainActor () -> Void)? = nil,
         terminate: @escaping @MainActor () -> Void = { NSApp.terminate(nil) }) {
        self.controller = controller; self.accountSetup = accountSetup
        self.navigation = navigation ?? QuitGuidanceNavigation()
        self.presentQuitAlert = presentQuitAlert
        self.showControls = showControls
        self.terminate = terminate
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        openControls()
    }
    private func scheduleRefresh(windowVisible: Bool) {
        polling?.invalidate()
        let interval = TimeInterval(ControlsPresentation.refreshInterval(windowVisible: windowVisible))
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.controller.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        polling = timer
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { accountSetup?.canDismiss ?? true }
    func windowWillClose(_ notification: Notification) {
        navigation.clear()
        scheduleRefresh(windowVisible: false)
    }
    func windowDidMiniaturize(_ notification: Notification) { scheduleRefresh(windowVisible: false) }
    func windowDidDeminiaturize(_ notification: Notification) {
        scheduleRefresh(windowVisible: true)
        Task { await controller.refresh() }
    }

    func openControls() {
        showControlsWindow()
        Task { await controller.refresh() }
    }
    private func showControlsWindow() {
        if controlsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Codex Project Router"
            window.contentView = NSHostingView(rootView: ControlsView(controller: controller, navigation: navigation, accountSetup: accountSetup))
            window.minSize = NSSize(width: 760, height: 680)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            controlsWindow = window
        }
        controlsWindow?.deminiaturize(nil)
        controlsWindow?.makeKeyAndOrderFront(nil)
        scheduleRefresh(windowVisible: true)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openControls(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationApproved && controller.canQuit { return .terminateNow }
        requestQuit()
        return .terminateCancel
    }
    @discardableResult func requestQuit() -> Task<Void, Never>? {
        guard !quitInProgress else { return nil }
        // Claim before scheduling, and hold through the modal run loop and its response.
        quitInProgress = true
        return Task {
            defer { quitInProgress = false }
            await controller.requestQuit()
            if controller.quitRequested && controller.canQuit {
                terminationApproved = true
                terminate()
            } else {
                let reason = controller.quitBlockReason ?? .contextUnavailable
                let response = await presentQuitAlert(QuitAlert.make(reason: reason, ownsRouter: controller.ownedRouter != nil))
                if response == .alertFirstButtonReturn {
                    let token = navigation.beginRequest()
                    if let showControls { showControls() }
                    else { showControlsWindow() }
                    await controller.refreshAndWait()
                    navigation.present(token)
                }
            }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { polling?.invalidate() }
}
