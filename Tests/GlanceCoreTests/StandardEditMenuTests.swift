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
    }

    func testInstallOnApplicationIsIdempotent() {
        let application = NSApplication.shared
        let previous = application.mainMenu
        defer { application.mainMenu = previous }

        application.mainMenu = NSMenu()
        GlanceStandardEditMenu.install(on: application)
        GlanceStandardEditMenu.install(on: application)
        let editMenus = application.mainMenu?.items.compactMap(\.submenu).filter {
            $0.title == GlanceStandardEditMenu.title
        } ?? []
        XCTAssertEqual(editMenus.count, 1)
        XCTAssertEqual(
            editMenus.first?.items.filter { $0.action == GlanceStandardEditMenu.paste }.count,
            1
        )
    }

    func testStandardEditActionsDispatchToExplicitResponder() {
        let recorder = RecordingEditResponder()
        let commands: [Selector] = [
            GlanceStandardEditMenu.paste,
            GlanceStandardEditMenu.copy,
            GlanceStandardEditMenu.cut,
            GlanceStandardEditMenu.selectAll,
            GlanceStandardEditMenu.undo,
            GlanceStandardEditMenu.redo
        ]
        for action in commands {
            XCTAssertTrue(
                NSApp.sendAction(action, to: recorder, from: nil),
                "\(action) should reach a responder that implements the standard selector"
            )
        }
        XCTAssertEqual(recorder.received, commands)
    }

    func testMenuKeyEquivalentsMatchStandardActionsWithoutSendingThem() {
        let mainMenu = NSMenu()
        GlanceStandardEditMenu.install(into: mainMenu)
        let expected: [(Selector, String, NSEvent.ModifierFlags)] = [
            (GlanceStandardEditMenu.paste, "v", .command),
            (GlanceStandardEditMenu.copy, "c", .command),
            (GlanceStandardEditMenu.cut, "x", .command),
            (GlanceStandardEditMenu.selectAll, "a", .command),
            (GlanceStandardEditMenu.undo, "z", .command),
            (GlanceStandardEditMenu.redo, "z", [.command, .shift])
        ]
        for (action, key, modifiers) in expected {
            let item = tryUnwrapItem(action, in: mainMenu)
            XCTAssertNil(item.target)
            XCTAssertEqual(item.keyEquivalent, key)
            XCTAssertEqual(item.keyEquivalentModifierMask, modifiers)
            XCTAssertEqual(item.action, action)
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

/// Records standard AppKit edit selectors without touching NSPasteboard.general.
private final class RecordingEditResponder: NSObject {
    var received: [Selector] = []

    @objc func paste(_ sender: Any?) {
        received.append(#selector(NSText.paste(_:)))
    }

    @objc func copy(_ sender: Any?) {
        received.append(#selector(NSText.copy(_:)))
    }

    @objc func cut(_ sender: Any?) {
        received.append(#selector(NSText.cut(_:)))
    }

    @objc func selectAll(_ sender: Any?) {
        received.append(#selector(NSText.selectAll(_:)))
    }

    @objc func undo(_ sender: Any?) {
        received.append(NSSelectorFromString("undo:"))
    }

    @objc func redo(_ sender: Any?) {
        received.append(NSSelectorFromString("redo:"))
    }
}
