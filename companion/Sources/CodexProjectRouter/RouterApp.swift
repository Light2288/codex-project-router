import SwiftUI
import AppKit
import CompanionCore

@main struct RouterApp: App {
    @NSApplicationDelegateAdaptor(RouterAppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra("Codex Project Router", systemImage: "arrow.triangle.branch") {
            Button("Open controls…") { delegate.openControls() }.keyboardShortcut("o")
            Button("Refresh") { Task { await delegate.controller.refresh() } }
            Divider()
            Button("Quit Codex Project Router") { delegate.requestQuit() }.keyboardShortcut("q")
        }
    }
}

@MainActor final class RouterAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let controller: RouterController
    private var controlsWindow: NSWindow?
    private var polling: Timer?
    private var quitInProgress = false
    private var terminationApproved = false

    override convenience init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let resources = (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("router")
        let controller = RouterController(backend: ProcessBackend(resourcesURL: resources, nodeExecutable: nil),
            store: PrivateStore(directory: home.appendingPathComponent(".codex-project-router/companion")),
            browseHome: home.appendingPathComponent(".codex"))
        self.init(controller: controller)
    }
    init(controller: RouterController) {
        self.controller = controller
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
    func windowWillClose(_ notification: Notification) { scheduleRefresh(windowVisible: false) }
    func windowDidMiniaturize(_ notification: Notification) { scheduleRefresh(windowVisible: false) }
    func windowDidDeminiaturize(_ notification: Notification) {
        scheduleRefresh(windowVisible: true)
        Task { await controller.refresh() }
    }

    func openControls() {
        if controlsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Codex Project Router"
            window.contentView = NSHostingView(rootView: ControlsView(controller: controller))
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
        Task { await controller.refresh() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openControls(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationApproved && controller.canQuit { return .terminateNow }
        requestQuit()
        return .terminateCancel
    }
    func requestQuit() {
        guard !quitInProgress else { return }
        quitInProgress = true
        Task {
            await controller.requestQuit()
            quitInProgress = false
            if controller.quitRequested && controller.canQuit {
                terminationApproved = true
                NSApp.terminate(nil)
            } else { openControls() }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { polling?.invalidate() }
}
