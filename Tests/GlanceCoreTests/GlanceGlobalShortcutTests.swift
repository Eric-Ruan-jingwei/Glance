import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class GlanceGlobalShortcutTests: XCTestCase {
    func testHideShowShortcutIsOptionCommandG() {
        XCTAssertEqual(GlanceConstants.hideShowKeyEquivalent, "g")
        XCTAssertEqual(GlanceConstants.hideShowShortcutDisplay, "⌥⌘G")
        XCTAssertNotEqual(GlanceConstants.hideShowKeyEquivalent, "h")
        XCTAssertFalse(GlanceConstants.hideShowShortcutDisplay.contains("H"))
    }

    func testQuickCaptureShortcutIsOptionCommandSpace() {
        XCTAssertEqual(GlanceConstants.quickCaptureKeyEquivalent, " ")
        XCTAssertEqual(GlanceConstants.quickCaptureShortcutDisplay, "⌥⌘Space")
        XCTAssertNotEqual(GlanceConstants.quickCaptureKeyEquivalent, GlanceConstants.hideShowKeyEquivalent)
        XCTAssertNotEqual(GlanceHotKeyID.quickCapture, GlanceHotKeyID.hideShow)
    }

    func testMenuBarVisibilityItemUsesOptionCommandG() {
        assertVisibilityShortcut(allHidden: false, title: "隐藏全部")
        assertVisibilityShortcut(allHidden: true, title: "显示全部")
    }

    func testMenuBarQuickCaptureItemUsesOptionCommandSpace() {
        let menu = NSMenu()
        populate(menu, allHidden: false)
        let item = menu.items.first { $0.title == "快速记录…" }
        XCTAssertEqual(item?.keyEquivalent, " ")
        XCTAssertEqual(item?.keyEquivalentModifierMask, [.option, .command])
        XCTAssertEqual(menu.items.first?.title, "快速记录…")
    }

    func testPassThroughHintMentionsLockLimit() {
        XCTAssertEqual(PassThroughHint.title, "按住 Option 可临时操作此面板")
        XCTAssertTrue(PassThroughHint.body.contains("鼠标事件会传递给后面的窗口"))
        XCTAssertTrue(PassThroughHint.body.contains("已锁定的面板仍不会被移动、缩放或编辑"))
        XCTAssertFalse(PassThroughHint.body.contains("临时拖动、右键或编辑"))
    }

    private func assertVisibilityShortcut(allHidden: Bool, title: String) {
        let menu = NSMenu()
        populate(menu, allHidden: allHidden)
        let item = menu.items.first { $0.title == title }
        XCTAssertEqual(item?.keyEquivalent, "g")
        XCTAssertEqual(item?.keyEquivalentModifierMask, [.option, .command])
    }

    private func populate(_ menu: NSMenu, allHidden: Bool) {
        StatusMenuBuilder.populate(
            menu,
            allHidden: allHidden,
            onQuickCapture: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
    }
}
