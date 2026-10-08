import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class StandardEditMenuTests: XCTestCase {
    func testInstallRegistersResponderChainEditCommands() {
        let mainMenu = NSMenu()
        GlanceStandardEditMenu.install(into: mainMenu)

        let paste = tryUnwrapItem(GlanceStandardEditMenu.paste, in: mainMenu)
        XCTAssertEqual(paste.title, "粘贴")
        XCTAssertEqual(paste.keyEquivalent, "v")
        XCTAssertEqual(paste.keyEquivalentModifierMask, .command)
        XCTAssertNil(paste.target)
        XCTAssertEqual(paste.action, #selector(NSText.paste(_:)))
        XCTAssertEqual(paste.action, NSSelectorFromString("paste:"))

        assertCommand(
            GlanceStandardEditMenu.cut,
            title: "剪切",
            key: "x",
            modifiers: .command,
            in: mainMenu
        )
        assertCommand(
            GlanceStandardEditMenu.copy,
            title: "复制",
            key: "c",
            modifiers: .command,
            in: mainMenu
        )
        assertCommand(
            GlanceStandardEditMenu.selectAll,
            title: "全选",
            key: "a",
            modifiers: .command,
            in: mainMenu
        )
        assertCommand(
            GlanceStandardEditMenu.undo,
            title: "撤销",
            key: "z",
            modifiers: .command,
            in: mainMenu
        )
        assertCommand(
            GlanceStandardEditMenu.redo,
            title: "重做",
            key: "z",
            modifiers: [.command, .shift],
            in: mainMenu
        )

        XCTAssertTrue(mainMenu.performKeyEquivalent(with: commandKey("v", keyCode: 9)))
    }

    func testInstallOnApplicationIsIdempotent() {
        let application = NSApplication.shared
        let previous = application.mainMenu
        defer { application.mainMenu = previous }

        application.mainMenu = NSMenu()
        GlanceStandardEditMenu.install(on: application)
        GlanceStandardEditMenu.install(on: application)
        let editMenus = application.mainMenu?.items.compactMap(\.submenu).filter { $0.title == GlanceStandardEditMenu.title } ?? []
        XCTAssertEqual(editMenus.count, 1)
        XCTAssertEqual(
            editMenus.first?.items.filter { $0.action == GlanceStandardEditMenu.paste }.count,
            1
        )
    }

    func testPasteReplacesSelectionThroughStandardAction() throws {
        try withTemporaryPasteboardString("https://example.com") {
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
            textView.string = "abCDef"
            textView.setSelectedRange(NSRange(location: 2, length: 2))

            XCTAssertTrue(NSApp.sendAction(#selector(NSText.paste(_:)), to: textView, from: nil))
            XCTAssertEqual(textView.string, "abhttps://example.comef")

            XCTAssertTrue(NSApp.sendAction(#selector(NSText.selectAll(_:)), to: textView, from: nil))
            XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: textView.string.count))

            XCTAssertTrue(NSApp.sendAction(#selector(NSText.copy(_:)), to: textView, from: nil))
            XCTAssertTrue(NSApp.sendAction(#selector(NSText.cut(_:)), to: textView, from: nil))
            XCTAssertEqual(textView.string, "")
        }
    }

    func testLibraryMonitorPassesEditorAndIMEEvents() {
        XCTAssertTrue(
            GlanceLibraryKeyMonitor.shouldDeliverToResponder(editorOpen: true, isComposingIME: false)
        )
        XCTAssertTrue(
            GlanceLibraryKeyMonitor.shouldDeliverToResponder(editorOpen: false, isComposingIME: true)
        )
        XCTAssertFalse(
            GlanceLibraryKeyMonitor.shouldDeliverToResponder(editorOpen: false, isComposingIME: false)
        )
    }

    func testLinkEditorDoesNotSwallowPasteAndRestoresListCopy() throws {
        try skipHostedAppKitWindows()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinks-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = LinkService(store: LinkStore(root: root.appendingPathComponent("Links", isDirectory: true)))
        _ = try unwrap(service.create(
            LinkDraft(title: "Docs", urlString: "https://example.com/docs")
        ))
        let monitor = ClipboardHistoryMonitor(
            pasteboard: NSPasteboard.withUniqueName(),
            interval: 30,
            isEnabled: { false }
        )
        let controller = LinkLibraryWindowController(service: service, monitor: monitor)
        controller.present()
        defer { controller.dismiss(deactivate: false) }

        let paste = commandKey("v", keyCode: 9)
        XCTAssertNotNil(controller.handleKey(paste))

        controller.presentEditor(prefilledURL: "https://example.com")
        XCTAssertNotNil(controller.handleKey(paste))
        XCTAssertNotNil(controller.handleKey(commandKey("c", keyCode: 8)))
        XCTAssertNotNil(controller.handleKey(commandKey("z", keyCode: 6)))

        controller.handleCancel()
        XCTAssertNotNil(controller.handleKey(paste))
        XCTAssertNil(controller.handleKey(commandKey("c", keyCode: 8)))
    }

    func testSnippetEditorDoesNotSwallowPaste() throws {
        try skipHostedAppKitWindows()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippets-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = SnippetService(store: SnippetStore(root: root.appendingPathComponent("Snippets", isDirectory: true)))
        let monitor = ClipboardHistoryMonitor(
            pasteboard: NSPasteboard.withUniqueName(),
            interval: 30,
            isEnabled: { false }
        )
        let controller = SnippetLibraryWindowController(service: service, monitor: monitor)
        controller.present()
        defer { controller.dismiss(deactivate: false) }
        controller.presentEditor(prefilled: "draft")
        XCTAssertNotNil(controller.handleKey(commandKey("v", keyCode: 9)))
        XCTAssertNotNil(controller.handleKey(commandKey("a", keyCode: 0)))
        controller.handleCancel()
        XCTAssertNotNil(controller.handleKey(commandKey("v", keyCode: 9)))
    }

    func testGlobalSearchAndQuickCapturePoliciesDoNotMapPaste() {
        XCTAssertNil(GlobalSearchActionPolicy.action(keyCode: 9, command: true))
        XCTAssertEqual(
            QuickCaptureKeyPolicy.intent(
                keyCode: 9,
                command: true,
                shift: false,
                isComposing: false,
                allowsNewline: true
            ),
            .none
        )
        XCTAssertEqual(
            QuickCaptureKeyPolicy.intent(
                keyCode: 9,
                command: true,
                shift: false,
                isComposing: true,
                allowsNewline: true
            ),
            .none
        )
    }

    private func skipHostedAppKitWindows() throws {
        try XCTSkipIf(
            Bundle.main.bundleIdentifier == "com.glance.app",
            "Hosted Glance.app TEST_HOST deadlocks extra NSPanel key-window work"
        )
    }

    private func tryUnwrapItem(_ action: Selector, in mainMenu: NSMenu) -> NSMenuItem {
        let item = GlanceStandardEditMenu.commandItem(action: action, in: mainMenu)
        XCTAssertNotNil(item)
        return item ?? NSMenuItem()
    }

    private func assertCommand(
        _ action: Selector,
        title: String,
        key: String,
        modifiers: NSEvent.ModifierFlags,
        in mainMenu: NSMenu
    ) {
        let item = tryUnwrapItem(action, in: mainMenu)
        XCTAssertEqual(item.title, title)
        XCTAssertEqual(item.keyEquivalent, key)
        XCTAssertEqual(item.keyEquivalentModifierMask, modifiers)
        XCTAssertNil(item.target)
        XCTAssertEqual(item.action, action)
    }

    private func commandKey(_ characters: String, keyCode: UInt16, shift: Bool = false) -> NSEvent {
        var flags: NSEvent.ModifierFlags = .command
        if shift { flags.insert(.shift) }
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }

    private func withTemporaryPasteboardString(_ value: String, _ body: () throws -> Void) throws {
        let pasteboard = NSPasteboard.general
        let savedTypes = pasteboard.types ?? []
        let savedItems = savedTypes.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
            guard let data = pasteboard.data(forType: type) else { return nil }
            return (type, data)
        }
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        defer {
            pasteboard.clearContents()
            for (type, data) in savedItems {
                pasteboard.setData(data, forType: type)
            }
        }
        try body()
    }

    private func unwrap(_ result: Result<LinkRecord, LinkCommitError>) throws -> LinkRecord {
        switch result {
        case .success(let record):
            return record
        case .failure(let error):
            XCTFail("unexpected \(error)")
            throw error
        }
    }
}
