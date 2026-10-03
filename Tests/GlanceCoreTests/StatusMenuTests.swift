import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class StatusMenuTests: XCTestCase {
    func testRootExposesUtilityHubNotPanelInternals() {
        let menu = NSMenu()
        GlanceMenuFixtures.populate(menu)
        let titles = GlanceMenuQuery.rootTitles(in: menu)
        XCTAssertEqual(titles.first, "快速记录…")
        XCTAssertEqual(menu.items.first { $0.title == "剪贴板…" }?.title, "剪贴板…")
        XCTAssertNotNil(menu.items.first { $0.title == "面板" }?.submenu)
        XCTAssertNotNil(menu.items.first { $0.title == GlanceGuideEntry.menuTitle })
        XCTAssertNotNil(menu.items.first { $0.title == "设置…" })
        XCTAssertEqual(titles.last, "退出")

        let rootForbidden = [
            "工作区",
            "管理面板…",
            "新建面板",
            "隐藏全部",
            "显示全部",
            "从当前剪贴板创建…",
            "状态"
        ]
        for title in rootForbidden {
            XCTAssertNil(menu.items.first { $0.title == title }, "\(title) must not stay at root")
        }
        XCTAssertFalse(titles.contains("状态"))
    }

    func testPanelSubmenuHoldsCreateManageOrganizeAndVisibility() throws {
        let menu = NSMenu()
        GlanceMenuFixtures.populate(menu, allHidden: false)
        let panel = try XCTUnwrap(GlanceMenuQuery.panelMenu(in: menu))
        let titles = panel.items.map(\.title)
        XCTAssertEqual(titles.first, "新建面板")
        XCTAssertNotNil(panel.items.first { $0.title == "从当前剪贴板创建…" })
        XCTAssertNotNil(panel.items.first { $0.title == "管理面板…" })
        XCTAssertNotNil(panel.items.first { $0.title == "工作区" })
        XCTAssertNotNil(panel.items.first { $0.title == "隐藏全部" })
        XCTAssertNil(panel.items.first { $0.title == "显示全部" })
        XCTAssertLessThan(
            panel.items.firstIndex(where: { $0.title == "新建面板" }) ?? .max,
            panel.items.firstIndex(where: { $0.title == "从当前剪贴板创建…" }) ?? .min
        )
        XCTAssertLessThan(
            panel.items.firstIndex(where: { $0.title == "从当前剪贴板创建…" }) ?? .max,
            panel.items.firstIndex(where: { $0.title == "管理面板…" }) ?? .min
        )
        XCTAssertLessThan(
            panel.items.firstIndex(where: { $0.title == "管理面板…" }) ?? .max,
            panel.items.firstIndex(where: { $0.title == "工作区" }) ?? .min
        )
        XCTAssertLessThan(
            panel.items.firstIndex(where: { $0.title == "工作区" }) ?? .max,
            panel.items.firstIndex(where: { $0.title == "隐藏全部" }) ?? .min
        )
    }

    func testNewPanelKindsRemainNested() {
        let menu = NSMenu()
        GlanceMenuFixtures.populate(menu)
        XCTAssertEqual(
            GlanceMenuQuery.newPanelMenu(in: menu)?.items.map(\.title),
            ["文字", "Markdown", "待办", "图片", "PDF…"]
        )
    }

    func testWorkspaceSubmenuKeepsCheckmarkAndCreate() throws {
        var selected: String?
        var created = false
        let workspaces = [
            WorkspaceMenuItem(id: WorkspaceRecord.defaultID, name: "默认", isActive: false),
            WorkspaceMenuItem(id: "work", name: "Work", isActive: true)
        ]
        let menu = NSMenu()
        GlanceMenuFixtures.populate(
            menu,
            workspaces: workspaces,
            onSelectWorkspace: { selected = $0 },
            onCreateWorkspace: { created = true }
        )
        let workspace = try XCTUnwrap(GlanceMenuQuery.workspaceMenu(in: menu))
        XCTAssertEqual(workspace.items.first { $0.title == "Work" }?.state, .on)
        XCTAssertEqual(workspace.items.first { $0.title == "默认" }?.state, .off)
        XCTAssertEqual(workspace.items.last?.title, "新建工作区…")
        invoke(workspace.items.first { $0.title == "Work" })
        invoke(workspace.items.first { $0.title == "新建工作区…" })
        XCTAssertEqual(selected, "work")
        XCTAssertTrue(created)
    }

    func testClipboardCaptureNestedItemCanDisable() {
        let menu = NSMenu()
        GlanceMenuFixtures.populate(menu, clipboardCaptureEnabled: false)
        let item = GlanceMenuQuery.item(titled: "从当前剪贴板创建…", in: menu)
        XCTAssertNil(menu.items.first { $0.title == "从当前剪贴板创建…" })
        XCTAssertEqual(item?.isEnabled, false)
        XCTAssertEqual(item?.keyEquivalent, "b")
        XCTAssertEqual(item?.keyEquivalentModifierMask, [.option, .command])
    }

    func testHideShowTitleFollowsVisibilityAndKeepsShortcut() {
        let hidden = NSMenu()
        GlanceMenuFixtures.populate(hidden, allHidden: false)
        let hide = GlanceMenuQuery.item(titled: "隐藏全部", in: hidden)
        XCTAssertEqual(hide?.keyEquivalent, "g")
        XCTAssertEqual(hide?.keyEquivalentModifierMask, [.option, .command])
        XCTAssertNil(hidden.items.first { $0.title == "隐藏全部" })

        let shown = NSMenu()
        GlanceMenuFixtures.populate(shown, allHidden: true)
        XCTAssertNotNil(GlanceMenuQuery.item(titled: "显示全部", in: shown))
        XCTAssertNil(GlanceMenuQuery.item(titled: "隐藏全部", in: shown))
    }

    func testNestedItemsUseLiveShortcuts() {
        var shortcuts = ShortcutDefaults.all
        shortcuts[.clipboardHistory] = GlanceShortcut(
            key: "v",
            command: false,
            option: true,
            control: true,
            shift: false
        )
        shortcuts[.hideShow] = GlanceShortcut(
            key: "h",
            command: true,
            option: true,
            control: false,
            shift: false
        )
        let menu = NSMenu()
        GlanceMenuFixtures.populate(menu, shortcuts: shortcuts)
        let clipboard = menu.items.first { $0.title == "剪贴板…" }
        XCTAssertEqual(clipboard?.keyEquivalent, "v")
        XCTAssertEqual(clipboard?.keyEquivalentModifierMask, [.control, .option])
        let hide = GlanceMenuQuery.item(titled: "隐藏全部", in: menu)
        XCTAssertEqual(hide?.keyEquivalent, "h")
        XCTAssertEqual(hide?.keyEquivalentModifierMask, [.option, .command])
        let capture = GlanceMenuQuery.item(titled: "从当前剪贴板创建…", in: menu)
        XCTAssertEqual(capture?.keyEquivalent, "b")
    }

    func testCallbacksSurviveMenuNesting() {
        var clipboard = false
        var manage = false
        var capture = false
        var visibility = false
        let menu = NSMenu()
        GlanceMenuFixtures.populate(
            menu,
            onShowClipboardHistory: { clipboard = true },
            onCaptureClipboard: { capture = true },
            onManagePanels: { manage = true },
            onToggleVisibility: { visibility = true }
        )
        invoke(menu.items.first { $0.title == "剪贴板…" })
        invoke(GlanceMenuQuery.item(titled: "管理面板…", in: menu))
        invoke(GlanceMenuQuery.item(titled: "从当前剪贴板创建…", in: menu))
        invoke(GlanceMenuQuery.item(titled: "隐藏全部", in: menu))
        XCTAssertTrue(clipboard)
        XCTAssertTrue(manage)
        XCTAssertTrue(capture)
        XCTAssertTrue(visibility)
    }

    func testDiagnosticStaysAtRootWhenPresent() {
        let clean = NSMenu()
        GlanceMenuFixtures.populate(clean)
        XCTAssertFalse(GlanceMenuQuery.rootTitles(in: clean).contains { $0.contains("数据恢复提示") })

        let recovered = NSMenu()
        GlanceMenuFixtures.populate(recovered, diagnostic: .recoveredFromBackup)
        XCTAssertEqual(
            recovered.items.first { $0.title.contains("数据恢复提示") }?.title,
            "⚠ 数据恢复提示…"
        )
        XCTAssertEqual(recovered.items.last?.title, "退出")
    }

    private func invoke(_ item: NSMenuItem?) {
        guard let item, let action = item.action else {
            XCTFail("Missing menu action")
            return
        }
        _ = item.target?.perform(action, with: item)
    }
}
