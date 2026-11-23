import AppKit
import SwiftUI
import XCTest

/// Native copying necessarily uses the general pasteboard; restore its data without logging it.
@MainActor final class NativeClipboard {
    private let saved: [[NSPasteboard.PasteboardType: Data]]
    private let menu = NSApp.mainMenu

    init() {
        saved = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }
        // SwiftUI installs these standard commands for the real MenuBarExtra scene; XCTest does not.
        let root = NSMenu()
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        edit.submenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.submenu?.addItem(withTitle: title, action: NSSelectorFromString(action), keyEquivalent: key)
        }
        root.addItem(edit)
        NSApp.mainMenu = root
    }

    func restore() {
        NSPasteboard.general.clearContents()
        let items = saved.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values { XCTAssertTrue(item.setData(data, forType: type)) }
            return item
        }
        if !items.isEmpty { XCTAssertTrue(NSPasteboard.general.writeObjects(items)) }
        NSApp.mainMenu = menu
    }
}

@MainActor extension NativeProjectHost {
    func selectText(_ text: String, range: NSRange, in target: NSWindow? = nil) throws {
        let target = target ?? window
        target.makeKeyAndOrderFront(nil)
        let element = try XCTUnwrap(elements(in: target).first {
            $0.accessibilityValue() as? String == text || $0.accessibilityLabel() == text
        }, "Missing displayed text: \(text)")
        if let field = (element.object as? NSCell)?.controlView as? NSTextField ?? element.object as? NSTextField {
            XCTAssertTrue(field.isSelectable, "Displayed text must be selectable: \(text)")
            XCTAssertFalse(field.isEditable, "Informational text must stay read-only")
            XCTAssertTrue(target.makeFirstResponder(field))
            let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
            editor.setSelectedRange(range)
        } else {
            _ = target.makeFirstResponder(target.contentView)
            element.setAccessibilityFocused(true)
            let setter = NSSelectorFromString("setAccessibilitySelectedTextRange:")
            guard element.object.responds(to: setter), let method = element.object.method(for: setter) else {
                XCTFail("Displayed text has no native selection: \(text)")
                throw NativeSelectionError.unavailable
            }
            let set = unsafeBitCast(method, to: (@convention(c) (AnyObject, Selector, NSRange) -> Void).self)
            set(element.object, setter, range)
        }
    }

    func copySelection(in target: NSWindow? = nil) throws -> String {
        let target = target ?? window
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("COPY_DID_NOT_RUN", forType: .string)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: target.windowNumber,
            context: nil, characters: "c", charactersIgnoringModifiers: "c", isARepeat: false, keyCode: 8))
        // Keep native menu validation and responder copying, without requiring OS foreground ownership.
        let edit = try XCTUnwrap(NSApp.mainMenu?.items.first?.submenu)
        let copy = try XCTUnwrap(edit.items.first { $0.action == NSSelectorFromString("copy:") })
        copy.target = target.firstResponder
        _ = edit.performKeyEquivalent(with: event)
        return try XCTUnwrap(NSPasteboard.general.string(forType: .string))
    }
}

private enum NativeSelectionError: Error { case unavailable }

@MainActor final class NativeTextSelectionTests: XCTestCase {
    func testCopyFixtureUsesTheRenderedUnicodeSelection() async throws {
        let host = NativeProjectHost(Text("café 🧭\nstatus — ready").textSelection(.enabled).padding())
        let clipboard = NativeClipboard()
        defer { clipboard.restore(); host.close() }
        await host.settle()
        try host.selectText("café 🧭\nstatus — ready", range: NSRange(location: 5, length: 2))
        XCTAssertEqual(try host.copySelection(), "🧭")
    }
}
