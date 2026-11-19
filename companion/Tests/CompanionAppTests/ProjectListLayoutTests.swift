import XCTest
import SwiftUI
import AppKit
import ApplicationServices
@testable import CompanionCore
@testable import CodexProjectRouter

@MainActor final class ProjectListLayoutTests: XCTestCase {
    // Losing previews or filtering them a second time removes the only repair/disclosure actions while collapsed.
    func testCollapsePreviewsRetainEditAndDisclosureAccess() async throws {
        try await withProjectListFixture { controller, backend in
            backend.snapshot.catalog.entries = [Self.entry(1, "Archived repair", kind: "target_missing", inactive: true),
                Self.entry(2, "Archived healthy", inactive: true)]
            await controller.refresh()
            var opened: String?
            let host = NativeProjectHost(ScrollView {
                ProjectListView(controller: controller, editingProjectID: nil, canOpenEditor: true) { opened = $0.id }
                    .padding(20)
            })
            defer { host.close() }
            await host.settle()
            XCTAssertNotNil(host.find("project-edit-\(Self.id(1))"))
            XCTAssertNil(host.find("project-edit-\(Self.id(2))"))
            let details = try XCTUnwrap(host.find("project-details-\(Self.id(1))"))
            XCTAssertTrue(details.accessibilityLabel()?.contains("Archived repair") == true)
            XCTAssertTrue(details.accessibilityPerformPress())
            await host.settle()
            XCTAssertTrue(host.text.contains("Project ID: \(Self.id(1))"))
            try host.press("project-edit-\(Self.id(1))")
            XCTAssertEqual(opened, Self.id(1))
            try host.snapshot("collapsed-problems")
            try host.focus("project-section-noActive")
            try host.press("project-section-noActive")
            await host.settle()
            XCTAssertNotNil(host.find("project-edit-\(Self.id(2))"))
            XCTAssertEqual(host.matches("project-edit-\(Self.id(1))").count, 1)
            XCTAssertTrue(host.text.contains("Project ID: \(Self.id(1))"))
            try host.snapshot("expanded-inactive")
        }
    }

    // Query clearing must restore the chosen collapse, and @State must outlive unavailable/mode branches.
    func testSearchExpansionClearsWithoutLosingChosenDisclosure() async throws {
        try await withProjectListFixture { controller, backend in
            backend.snapshot.catalog.entries = [Self.entry(1, "Archived match", inactive: true),
                Self.entry(2, "Hidden repair", kind: "target_missing")]
            await controller.refresh()
            let host = NativeProjectHost(ScrollView {
                ProjectListView(controller: controller, editingProjectID: nil, canOpenEditor: true) { _ in }.padding(20)
            })
            defer { host.close() }
            await host.settle()
            let search = try XCTUnwrap(host.find("project-search"))
            XCTAssertEqual(search.accessibilityLabel(), "Search projects or accounts")
            try host.search("Archived")
            await host.settle()
            XCTAssertNotNil(host.find("project-edit-\(Self.id(1))"))
            XCTAssertTrue(host.text.contains("1 of 1"))
            XCTAssertFalse(try XCTUnwrap(host.find("project-section-noActive")).isAccessibilityEnabled())
            XCTAssertTrue(host.text.contains("1 project needing attention is hidden by search."))
            try host.press("project-details-\(Self.id(1))")
            await host.settle()
            try host.snapshot("search-counts")
            backend.snapshot.catalog.state = "unavailable"
            await controller.refresh(); await host.settle()
            XCTAssertEqual(host.find("project-search")?.accessibilityValue() as? String, "Archived")
            backend.snapshot.configuration.mode = "legacy"
            backend.snapshot.catalog.state = "ready"
            await controller.refresh(); await host.settle()
            backend.snapshot.configuration.mode = "accounts"
            await controller.refresh(); await host.settle()
            XCTAssertTrue(host.text.contains("Project ID: \(Self.id(1))"))
            try host.press("project-clear-search")
            await host.settle()
            XCTAssertNil(host.find("project-edit-\(Self.id(1))"))
            try host.press("project-section-noActive")
            await host.settle()
            XCTAssertTrue(host.text.contains("Project ID: \(Self.id(1))"))
            // The native responder can accept keyboard focus and edit search; controls expose usable frames.
            let currentSearch = try XCTUnwrap(host.find("project-search"))
            currentSearch.setAccessibilityFocused(true)
            XCTAssertTrue(currentSearch.isAccessibilityFocused())
            for key in ["project-search", "project-section-noActive", "project-edit-\(Self.id(1))", "project-details-\(Self.id(1))"] {
                try host.focus(key)
                let element = try XCTUnwrap(host.find(key))
                XCTAssertFalse(element.accessibilityLabel()?.isEmpty ?? true)
                XCTAssertGreaterThan(element.accessibilityFrame().width, 16)
                XCTAssertGreaterThan(element.accessibilityFrame().height, 12)
            }
        }
    }

    // Fixed-height/name layouts must not push repair/details outside the minimum width or lose the final row.
    func testLongNamesAnd200ProjectRowsPreserveActions() async throws {
        try await withProjectListFixture { controller, backend in
            backend.snapshot.catalog.entries = (1...200).map { Self.entry($0, $0 == 1 ? "A synthetic project with a very long name — アーカイブ研究 🧭 " + String(repeating: "wrapping text ", count: 9) : "Synthetic project \(String(format: "%03d", $0))") }
            await controller.refresh()
            let host = NativeProjectHost(ScrollView {
                ProjectListView(controller: controller, editingProjectID: nil, canOpenEditor: true) { _ in }.padding(20)
            })
            defer { host.close() }
            await host.settle()
            XCTAssertTrue(host.text.contains("200"))
            let edit = try XCTUnwrap(host.find("project-edit-\(Self.id(1))"))
            let details = try XCTUnwrap(host.find("project-details-\(Self.id(1))"))
            XCTAssertLessThanOrEqual(edit.accessibilityFrame().maxX, host.window.frame.maxX)
            XCTAssertLessThanOrEqual(details.accessibilityFrame().maxX, host.window.frame.maxX)
            XCTAssertGreaterThan(edit.accessibilityFrame().width, 25)
            try host.snapshot("long-name-200-projects")
            try host.search(Self.id(200)); await host.settle()
            XCTAssertNotNil(host.find("project-edit-\(Self.id(200))"))
            XCTAssertTrue(host.text.contains("1 of 200"))
            XCTAssertEqual(host.matches("project-edit-\(Self.id(200))").count, 1)
            try host.snapshot("last-of-200-search", width: 960, height: 720)
            XCTAssertTrue(backend.changes.isEmpty)
            XCTAssertEqual(backend.starts, 0)
        }
    }

    // Shared discrepancy notices cannot be hidden by search or repeated once per inherited row.
    func testRuntimeDefaultDiscrepanciesRemainVisibleWithNoSearchMatches() async throws {
        try await withProjectListFixture { controller, backend in
            backend.snapshot.catalog.entries = [Self.entry(1, "Synthetic active"), Self.entry(2, "Synthetic custom", kind: "override", account: backend.work)]
            await controller.start()
            backend.snapshot.configuration.defaultAccount = backend.work
            await controller.refresh()
            let host = NativeProjectHost(ScrollView {
                ProjectListView(controller: controller, editingProjectID: nil, canOpenEditor: true) { _ in }.padding(20)
            })
            defer { host.close() }
            await host.settle()
            XCTAssertTrue(host.text.contains("Saved and running default accounts differ."))
            XCTAssertTrue(host.text.contains("Running default:"))
            XCTAssertTrue(host.text.contains("Saved and running assignments differ."))
            try host.snapshot("runtime-default-discrepancies")
            try host.search("no synthetic match"); await host.settle()
            XCTAssertTrue(host.text.contains("Saved and running default accounts differ."))
            XCTAssertTrue(host.text.contains("Running default:"))
            XCTAssertTrue(host.text.contains("Off suspends project overrides"))
            XCTAssertTrue(host.text.contains("No matching projects."))
            try host.snapshot("no-matches-shared-notices")
        }
    }

    // Unknown chat evidence must remain neutral under known saved policy; unknown policy needs visible attention.
    func testUnknownActivityAndUnclassifiablePolicyRemainDistinct() async throws {
        try await withProjectListFixture { controller, backend in
            var known = Self.entry(1, "Synthetic known policy, unknown chats", kind: "override", account: backend.work)
            known.chatActivity = .init(state: .unknown, reason: .missingRecord)
            var unknown = Self.entry(2, "Synthetic unclassified policy")
            unknown.assignmentKind = nil
            unknown.chatActivity = .init(state: .unknown, reason: .unsupportedMetadata)
            backend.snapshot.catalog.entries = [known, unknown]
            await controller.refresh()
            let host = NativeProjectHost(ScrollView {
                ProjectListView(controller: controller, editingProjectID: nil, canOpenEditor: true) { _ in }.padding(20)
            })
            defer { host.close() }
            await host.settle()
            XCTAssertTrue(host.text.contains("Needs attention"))
            XCTAssertTrue(host.text.contains("Custom account"))
            XCTAssertFalse(host.text.contains("No active chats ("))
            XCTAssertEqual(host.elements().filter { $0.accessibilityValue() as? String == "Chat status unknown" }.count, 2)
            XCTAssertTrue(host.text.contains("Saved assignment policy is unavailable. Refresh to inspect it."))
            XCTAssertEqual(host.matches("project-edit-\(Self.id(1))").count, 1)
            XCTAssertEqual(host.matches("project-edit-\(Self.id(2))").count, 1)
            try host.press("project-details-\(Self.id(1))"); await host.settle()
            XCTAssertTrue(host.text.contains("A referenced chat record is missing. Its archive state cannot be confirmed."))
            try host.snapshot("unknown-chat-and-policy-states")
            XCTAssertTrue(backend.changes.isEmpty)
        }
    }

    static func id(_ index: Int) -> String { String(format: "11111111-1111-4111-8111-%012d", index) }
    static func entry(_ index: Int, _ name: String, kind: String = "inherited", inactive: Bool = false, account: AccountSummary? = nil) -> Inspection.Entry {
        .init(id: id(index), name: name, routeAlias: nil, routeState: "unmapped", account: account, assignmentKind: kind,
              chatActivity: .init(state: inactive ? .noActiveChats : .unarchived))
    }
}

@MainActor func withProjectListFixture(_ body: (RouterController, AssignmentDisplayBackend) async throws -> Void) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-list-\(UUID())")
    defer {
        do { try FileManager.default.removeItem(at: root) }
        catch { XCTFail("Synthetic list fixture cleanup failed: \(error)") }
    }
    let backend = AssignmentDisplayBackend(root: root)
    let store = PrivateStore(directory: root.appendingPathComponent("companion"))
    try store.save(.init(selectedConfigurationPath: backend.context.configPath))
    let controller = RouterController(backend: backend, store: store, browseHome: root)
    await controller.refresh()
    try await body(controller, backend)
}

extension AssignmentDisplayBackend: ProjectListBackend {
    func readRunningProjectList(_ child: OwnedRouter, projectIDs: [String], deadline: Date) async throws -> RunningProjectListObservation {
        .init(context: context, snapshot: .init(runningRevision: runningRevision, runningIdentity: runningIdentity, runningFingerprint: runningFingerprint, mode: mode),
              defaultAccount: personal, assignments: Dictionary(uniqueKeysWithValues: projectIDs.map { ($0, runningSummary) }))
    }
}

/// Native fixtures exercise production SwiftUI/AppKit controls; all persistence stays in a disposable synthetic root.
@MainActor final class NativeProjectHost {
    let window: NSWindow
    private let host: NSView
    init<V: View>(_ view: V) {
        _ = NSApplication.shared
        NSApplication.shared.finishLaunching()
        let app = AXUIElementCreateApplication(getpid())
        _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 720, height: 640), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
    }
    func close() { window.orderOut(nil); window.close() }
    func settle() async {
        for _ in 0..<12 {
            await Task.yield()
            pumpRunLoop()
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }
    }
    private func pumpRunLoop() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.015))
        while let event = NSApplication.shared.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) {
            NSApplication.shared.sendEvent(event)
        }
    }
    func elements(in target: NSWindow? = nil) -> [NativeAXElement] {
        var result: [NativeAXElement] = []
        var visited: Set<ObjectIdentifier> = []
        func walk(_ node: Any) {
            guard let object = node as? NSObject else { return }
            guard visited.insert(ObjectIdentifier(object)).inserted else { return }
            let element = NativeAXElement(object: object)
            result.append(element)
            for child in element.accessibilityChildren() ?? [] { walk(child) }
        }
        if let root = (target ?? window).contentView { walk(root) }
        return result
    }
    func matches(_ id: String) -> [NativeAXElement] { elements().filter { $0.accessibilityIdentifier() == id } }
    func find(_ id: String) -> NativeAXElement? { matches(id).first }
    var text: String {
        elements().flatMap { [$0.accessibilityLabel() ?? "", $0.accessibilityTitle() ?? "", $0.accessibilityValue() as? String ?? ""] }.joined(separator: "\n")
    }
    func press(_ id: String) throws {
        let element = try XCTUnwrap(find(id), "Missing accessible control \(id). Tree: \(text)")
        XCTAssertTrue(element.isAccessibilityEnabled(), "Disabled control \(id)")
        XCTAssertTrue(element.accessibilityPerformPress(), "Cannot press \(id)")
    }
    func focus(_ id: String) throws {
        let element = try XCTUnwrap(find(id))
        if let field = (element.object as? NSCell)?.controlView as? NSTextField {
            XCTAssertTrue(window.makeFirstResponder(field))
            let editor = try XCTUnwrap(field.currentEditor())
            XCTAssertTrue(window.firstResponder === editor, "Cannot focus \(id)")
        } else {
            XCTAssertTrue(window.makeFirstResponder(host))
            element.setAccessibilityFocused(true)
            XCTAssertTrue(element.isAccessibilityFocused(), "Cannot focus \(id)")
        }
        XCTAssertNotNil(window.firstResponder)
    }
    func press(title: String, in target: NSWindow) throws {
        let element = try XCTUnwrap(elements(in: target).first { $0.accessibilityRole() == .button && ($0.accessibilityTitle() == title || $0.accessibilityLabel() == title) }, "Missing button \(title)")
        _ = try XCTUnwrap(element.isAccessibilityEnabled() ? true : nil, "Disabled button \(title)")
        XCTAssertTrue(element.accessibilityPerformPress())
    }
    func search(_ query: String) throws {
        let search = try XCTUnwrap(find("project-search"))
        let field = try XCTUnwrap((search.object as? NSCell)?.controlView as? NSTextField)
        XCTAssertTrue(window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText(query, replacementRange: editor.selectedRange())
    }
    func snapshot(_ name: String, width: CGFloat = 720, height: CGFloat = 640) throws {
        window.setContentSize(NSSize(width: width, height: height))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/project-list-qa")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }
}

/// SwiftUI nodes expose the documented accessibility selectors without declaring NSAccessibility.
/// Keep this bridge in test code; production uses standard SwiftUI accessibility modifiers.
@MainActor struct NativeAXElement {
    let object: NSObject
    private var modern: (any NSAccessibilityProtocol)? { object as? any NSAccessibilityProtocol }
    private func attribute(_ name: String) -> Any? {
        let names = ["AXChildren": "accessibilityChildren", "AXIdentifier": "accessibilityIdentifier",
                     "AXDescription": "accessibilityLabel", "AXTitle": "accessibilityTitle",
                     "AXValue": "accessibilityValue", "AXRole": "accessibilityRole"]
        if let name = names[name] {
            let selector = NSSelectorFromString(name)
            if object.responds(to: selector) { return object.perform(selector)?.takeUnretainedValue() }
        }
        return nil
    }
    func accessibilityChildren() -> [Any]? { modern?.accessibilityChildren() ?? attribute("AXChildren") as? [Any] }
    func accessibilityIdentifier() -> String? { modern?.accessibilityIdentifier() ?? attribute("AXIdentifier") as? String }
    func accessibilityLabel() -> String? { modern?.accessibilityLabel() ?? attribute("AXDescription") as? String }
    func accessibilityTitle() -> String? { modern?.accessibilityTitle() ?? attribute("AXTitle") as? String }
    func accessibilityValue() -> Any? { modern?.accessibilityValue() ?? attribute("AXValue") }
    func accessibilityRole() -> NSAccessibility.Role? {
        modern?.accessibilityRole() ?? (attribute("AXRole") as? String).map(NSAccessibility.Role.init(rawValue:))
    }
    func isAccessibilityEnabled() -> Bool { boolean("isAccessibilityEnabled") }
    func isAccessibilityFocused() -> Bool { boolean("isAccessibilityFocused") }
    private func boolean(_ name: String) -> Bool {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector), let method = object.method(for: selector) else { return false }
        let get = unsafeBitCast(method, to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        return get(object, selector)
    }
    func setAccessibilityFocused(_ value: Bool) {
        if let modern { modern.setAccessibilityFocused(value); return }
        let selector = NSSelectorFromString("setAccessibilityFocused:")
        guard object.responds(to: selector), let method = object.method(for: selector) else { return }
        let set = unsafeBitCast(method, to: (@convention(c) (AnyObject, Selector, Bool) -> Void).self)
        set(object, selector, value)
    }
    func accessibilityFrame() -> NSRect {
        if let modern { return modern.accessibilityFrame() }
        let selector = NSSelectorFromString("accessibilityFrame")
        guard object.responds(to: selector), let method = object.method(for: selector) else { return .zero }
        let get = unsafeBitCast(method, to: (@convention(c) (AnyObject, Selector) -> CGRect).self)
        return get(object, selector)
    }
    func accessibilityPerformPress() -> Bool {
        if let modern { return modern.accessibilityPerformPress() }
        let selector = NSSelectorFromString("accessibilityPerformPress")
        guard object.responds(to: selector), let method = object.method(for: selector) else { return false }
        let press = unsafeBitCast(method, to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        return press(object, selector)
    }
}
