import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class GlanceUXConsistencyTests: XCTestCase {
    func testSharedActionSymbolsAreStableAndNonEmpty() {
        let symbols: [(String, String)] = [
            ("open", GlanceActionSymbol.open),
            ("openFile", GlanceActionSymbol.openFile),
            ("copy", GlanceActionSymbol.copy),
            ("edit", GlanceActionSymbol.edit),
            ("delete", GlanceActionSymbol.delete),
            ("favorite", GlanceActionSymbol.favorite),
            ("unfavorite", GlanceActionSymbol.unfavorite),
            ("pin", GlanceActionSymbol.pin),
            ("unpin", GlanceActionSymbol.unpin),
            ("reveal", GlanceActionSymbol.reveal),
            ("preview", GlanceActionSymbol.preview),
            ("relink", GlanceActionSymbol.relink),
            ("hide", GlanceActionSymbol.hide),
            ("show", GlanceActionSymbol.show)
        ]
        for (name, symbol) in symbols {
            XCTAssertFalse(symbol.isEmpty, name)
            XCTAssertFalse(symbol.contains(" "), name)
        }

        XCTAssertEqual(GlanceActionSymbol.open, "arrow.up.right.square")
        XCTAssertEqual(GlanceActionSymbol.openFile, FileShelfQuickAction.openSymbol)
        XCTAssertEqual(GlanceActionSymbol.openFile, "arrow.up.forward.app")
        XCTAssertEqual(GlanceActionSymbol.copy, "doc.on.doc")
        XCTAssertEqual(GlanceActionSymbol.edit, "pencil")
        XCTAssertEqual(GlanceActionSymbol.delete, "trash")
        XCTAssertEqual(GlanceActionSymbol.favorite, "star")
        XCTAssertEqual(GlanceActionSymbol.unfavorite, "star.slash")
        XCTAssertEqual(GlanceActionSymbol.pin, "pin")
        XCTAssertEqual(GlanceActionSymbol.unpin, "pin.slash")
        XCTAssertEqual(GlanceActionSymbol.reveal, "folder")
        XCTAssertEqual(GlanceActionSymbol.preview, "eye")
        XCTAssertEqual(GlanceActionSymbol.relink, FileShelfQuickAction.relinkSymbol)
        XCTAssertEqual(GlanceActionSymbol.hide, "eye.slash")
        XCTAssertEqual(GlanceActionSymbol.show, "eye")
        XCTAssertEqual(
            GlanceActionSymbol.visibility(isHidden: false),
            PanelLibraryQuickAction.visibilitySymbol(isHidden: false)
        )
        XCTAssertEqual(
            GlanceActionSymbol.visibility(isHidden: true),
            PanelLibraryQuickAction.visibilitySymbol(isHidden: true)
        )
        XCTAssertEqual(GlanceActionSymbol.favorite(isOn: false), GlanceActionSymbol.favorite)
        XCTAssertEqual(GlanceActionSymbol.favorite(isOn: true), GlanceActionSymbol.unfavorite)
        XCTAssertEqual(GlanceActionSymbol.pin(isOn: false), GlanceActionSymbol.pin)
        XCTAssertEqual(GlanceActionSymbol.pin(isOn: true), GlanceActionSymbol.unpin)
    }

    func testGlanceItemActionSymbolsArePresentationOnlyAndMatchQuickCapture() {
        XCTAssertEqual(GlanceItemAction.createTextPanel.symbolName, "doc.text")
        XCTAssertEqual(GlanceItemAction.createTodoPanel.symbolName, "checklist")
        XCTAssertEqual(GlanceItemAction.createImagePanel.symbolName, "photo")
        XCTAssertEqual(GlanceItemAction.createPDFPanel.symbolName, "doc.richtext")
        XCTAssertEqual(GlanceItemAction.saveAsSnippet.symbolName, "text.quote")
        XCTAssertEqual(GlanceItemAction.saveAsLink.symbolName, "link")

        XCTAssertEqual(
            GlanceItemAction.createTextPanel.symbolName,
            QuickCaptureActionPresentation.symbolName(for: .createTextPanel)
        )
        XCTAssertEqual(
            GlanceItemAction.createTodoPanel.symbolName,
            QuickCaptureActionPresentation.symbolName(for: .createTodoPanel)
        )
        XCTAssertEqual(
            GlanceItemAction.saveAsSnippet.symbolName,
            QuickCaptureActionPresentation.symbolName(for: .saveSnippet)
        )
        XCTAssertEqual(
            GlanceItemAction.saveAsLink.symbolName,
            QuickCaptureActionPresentation.symbolName(for: .saveLink)
        )
        XCTAssertEqual(
            GlanceItemAction.createImagePanel.symbolName,
            PanelKindSymbol.name(for: PanelKind.image)
        )
        XCTAssertEqual(
            GlanceItemAction.createPDFPanel.symbolName,
            PanelKindSymbol.name(for: PanelKind.pdf)
        )

        XCTAssertEqual(GlanceItemAction.createTextPanel.identifier, "createTextPanel")
        XCTAssertEqual(GlanceItemAction.createTextPanel.title, "创建文字面板")
        XCTAssertTrue(GlanceItemAction.createTextPanel.createsPanel)
        XCTAssertFalse(GlanceItemAction.saveAsSnippet.createsPanel)
    }

    func testClipboardMenuOrderUsesUnifiedActionsThenFavoriteAndDelete() {
        let text = ClipboardHistoryRecord(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            lastCopiedAt: Date(),
            isFavorite: false,
            favoritedAt: nil,
            contentHash: "a",
            text: "https://example.com",
            assetPath: nil
        )
        let actions = GlanceItemActionPolicy.actions(for: .clipboard(text))
        XCTAssertEqual(actions, [.createTextPanel, .saveAsSnippet, .saveAsLink])
        XCTAssertEqual(
            actions.map(\.symbolName),
            [
                GlanceItemAction.createTextPanel.symbolName,
                GlanceActionSymbol.snippet,
                GlanceActionSymbol.link
            ]
        )
        XCTAssertEqual(GlanceActionSymbol.favorite(isOn: false), "star")
        XCTAssertEqual(GlanceActionSymbol.delete, "trash")
        XCTAssertEqual(ClipboardHistoryCopy.deleteLabel, "删除")
        XCTAssertNotEqual(ClipboardHistoryCopy.deleteLabel, "删除…")
    }

    func testSnippetAndLinkMenuOrderKeepCopyEditCreateThenPinAndDestructiveDelete() {
        XCTAssertEqual(SnippetCopy.copyLabel, GlanceRowActionCopy.copy)
        XCTAssertEqual(SnippetCopy.editLabel, "编辑…")
        XCTAssertEqual(SnippetCopy.deleteLabel, "删除…")
        XCTAssertEqual(GlanceActionSymbol.copy, "doc.on.doc")
        XCTAssertEqual(GlanceActionSymbol.edit, "pencil")
        XCTAssertEqual(SnippetRowQuickAction.leadingSymbol, GlanceActionSymbol.snippet)

        XCTAssertEqual(LinkCopy.openLabel, GlanceRowActionCopy.open)
        XCTAssertEqual(LinkCopy.copyLabel, "复制链接")
        XCTAssertEqual(LinkCopy.editLabel, "编辑…")
        XCTAssertEqual(LinkCopy.deleteLabel, "删除…")
        XCTAssertEqual(GlanceActionSymbol.open, "arrow.up.right.square")
    }

    func testPanelLibraryAndWorkspaceMenuSymbols() {
        XCTAssertEqual(WorkspaceRowMenu.actions(for: "alpha"), [.rename, .delete])
        XCTAssertEqual(WorkspaceRowMenuAction.rename.symbolName, GlanceActionSymbol.edit)
        XCTAssertEqual(WorkspaceRowMenuAction.delete.symbolName, GlanceActionSymbol.delete)
        XCTAssertTrue(WorkspaceRowMenuAction.delete.isDestructive)
        XCTAssertFalse(WorkspaceRowMenuAction.rename.isDestructive)
        XCTAssertEqual(WorkspaceRowMenuAction.rename.title, "重命名…")
        XCTAssertEqual(WorkspaceRowMenuAction.delete.title, "删除工作区")

        XCTAssertEqual(
            PanelLibraryQuickAction.visibilitySymbol(isHidden: false),
            GlanceActionSymbol.hide
        )
        XCTAssertEqual(
            PanelLibraryQuickAction.visibilitySymbol(isHidden: true),
            GlanceActionSymbol.show
        )
        XCTAssertEqual(PanelLibraryQuickAction.deleteSymbol, GlanceActionSymbol.delete)
        XCTAssertEqual(GlanceActionSymbol.move, "folder")
        XCTAssertEqual(GlanceActionSymbol.tags, "tag")
    }

    func testGlobalSearchMenuOrderRevealThenUnifiedActions() {
        let items = GlobalSearchResultMenu.items { [.createTextPanel, .saveAsSnippet] }
        XCTAssertEqual(
            items,
            [.reveal, .divider, .action(.createTextPanel), .action(.saveAsSnippet)]
        )
        XCTAssertEqual(items[0].symbolName, GlanceActionSymbol.revealInSource)
        XCTAssertNil(items[1].symbolName)
        XCTAssertEqual(items[2].symbolName, "doc.text")
        XCTAssertEqual(items[3].symbolName, "text.quote")
        XCTAssertFalse(
            GlobalSearchResultMenu.items { GlanceItemAction.allCases }.contains { item in
                if case .action(let action) = item {
                    return action.symbolName == GlanceActionSymbol.delete
                }
                return false
            }
        )
    }

    func testDestructiveHierarchyKeepsConfirmationsAndFileShelfRemoveIsNotTrash() {
        XCTAssertTrue(PanelLibraryQuickAction.deleteUsesConfirmation)
        XCTAssertEqual(PanelLibraryQuickAction.deleteSymbol, "trash")
        XCTAssertEqual(FileShelfQuickAction.removeSymbol, GlanceActionSymbol.remove)
        XCTAssertEqual(FileShelfQuickAction.removeSymbol, "minus.circle")
        XCTAssertNotEqual(FileShelfQuickAction.removeSymbol, GlanceActionSymbol.delete)
        XCTAssertFalse(FileShelfQuickAction.removeDeletesFinderFile)
        XCTAssertEqual(FileShelfCopy.removeLabel, "从文件架移除")
        XCTAssertNotEqual(FileShelfCopy.removeLabel, "删除文件")
        XCTAssertEqual(GlanceActionSymbol.openFile, "arrow.up.forward.app")
        XCTAssertEqual(GlanceActionSymbol.reveal, "folder")
        XCTAssertEqual(GlanceActionSymbol.preview, "eye")
    }

    func testShortcutHintPresentationAndAccessibility() {
        XCTAssertEqual(GlanceShortcutHint.spokenKey("↩"), "回车")
        XCTAssertEqual(GlanceShortcutHint.spokenKey("⌘↩"), "Command 回车")
        XCTAssertEqual(GlanceShortcutHint.spokenKey("⌘N"), "Command N")
        XCTAssertEqual(GlanceShortcutHint.spokenKey("Esc"), "Escape")
        XCTAssertEqual(GlanceShortcutHint.spokenKey("↑↓"), "上下方向键")
        XCTAssertEqual(GlanceShortcutHint.spokenKey("Space"), "空格")
        XCTAssertEqual(
            GlanceShortcutHint.accessibilityLabel(keys: ["↩"], label: "复制"),
            "回车，复制"
        )
        XCTAssertEqual(
            GlanceShortcutHint.accessibilityLabel(keys: ["⌘↩"], label: "编辑"),
            "Command 回车，编辑"
        )
        XCTAssertEqual(
            GlanceShortcutHint.accessibilityLabel(keys: ["⌘N"], label: "新建"),
            "Command N，新建"
        )
        XCTAssertEqual(
            GlanceShortcutHint.accessibilityLabel(keys: ["Esc"], label: "关闭"),
            "Escape，关闭"
        )
        XCTAssertEqual(
            GlanceShortcutHint.accessibilityLabel(keys: ["↑↓"], label: "选择"),
            "上下方向键，选择"
        )
        XCTAssertEqual(
            GlanceShortcutHint.accessibilityLabel(keys: ["Space"], label: "预览"),
            "空格，预览"
        )

        XCTAssertEqual(
            GlanceShortcutFooter.clipboard.map(\.label),
            ["复制", "创建面板", "关闭"]
        )
        XCTAssertEqual(
            GlanceShortcutFooter.fileShelf.map(\.label),
            ["打开", "在 Finder 中显示", "预览", "关闭"]
        )
        XCTAssertEqual(
            GlanceShortcutFooter.snippet.map(\.label),
            ["复制", "编辑", "新建", "关闭"]
        )
        XCTAssertEqual(
            GlanceShortcutFooter.link.map(\.label),
            ["打开", "编辑", "新建", "关闭"]
        )
        XCTAssertEqual(
            GlanceShortcutFooter.globalSearch.map(\.label),
            ["选择", "执行", "在来源中显示", "关闭"]
        )
        XCTAssertEqual(GlanceShortcutFooter.clipboard.map(\.keys), [["↩"], ["⌘↩"], ["Esc"]])
        XCTAssertEqual(GlanceShortcutFooter.fileShelf.map(\.keys), [["↩"], ["⌘↩"], ["Space"], ["Esc"]])
        XCTAssertEqual(GlanceShortcutFooter.snippet.map(\.keys), [["↩"], ["⌘↩"], ["⌘N"], ["Esc"]])
        XCTAssertEqual(GlanceShortcutFooter.link.map(\.keys), [["↩"], ["⌘↩"], ["⌘N"], ["Esc"]])
        XCTAssertEqual(
            GlanceShortcutFooter.globalSearch.map(\.keys),
            [["↑↓"], ["↩"], ["⌘↩"], ["Esc"]]
        )
        XCTAssertEqual(GlanceShortcutHintBar.spacing, GlanceTheme.Space.shortcutHint)
        XCTAssertEqual(GlanceTheme.Space.shortcutHint, 12, accuracy: 0.1)
    }

    func testWindowMinimumSizesDidNotGrowForKeycaps() {
        XCTAssertEqual(GlanceConstants.clipboardHistorySize.width, 520, accuracy: 0.1)
        XCTAssertEqual(GlanceConstants.fileShelfSize.width, 560, accuracy: 0.1)
        XCTAssertEqual(GlanceConstants.snippetLibrarySize.width, 560, accuracy: 0.1)
        XCTAssertEqual(GlanceConstants.linkLibrarySize.width, 560, accuracy: 0.1)
        XCTAssertEqual(GlanceConstants.globalSearchSize.width, 640, accuracy: 0.1)
    }

    func testIconButtonChromeUsesSemanticHoverFill() {
        XCTAssertEqual(GlanceIconButtonChrome.side, 26, accuracy: 0.1)
        XCTAssertEqual(GlanceIconButtonChrome.side, GlanceRowQuickActionLayout.buttonSide)
        XCTAssertEqual(GlanceIconButtonChrome.cornerRadius, GlanceTheme.Radius.control)
        XCTAssertEqual(GlanceIconButtonChrome.backgroundColor(isHovered: false), .clear)
        XCTAssertEqual(
            GlanceIconButtonChrome.backgroundColor(isHovered: true).alphaComponent,
            GlanceTheme.Fill.rowHover.alphaComponent,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(GlanceIconButtonChrome.backgroundColor(isHovered: true).alphaComponent, 0)
    }

    func testMoreHelpUsesChineseQuotes() {
        XCTAssertEqual(GlanceRowActionCopy.more, "更多操作")
        XCTAssertEqual(
            GlanceRowActionCopy.moreHelp(for: "项目 Alpha"),
            "“项目 Alpha”的更多操作"
        )
        XCTAssertEqual(
            WorkspaceRowQuickAction.moreHelp(name: "项目 Alpha"),
            GlanceRowActionCopy.moreHelp(for: "项目 Alpha")
        )
        XCTAssertEqual(
            GlobalSearchRowActionPresentation.moreHelp(title: "项目计划"),
            "“项目计划”的更多操作"
        )
        XCTAssertFalse(GlanceRowActionCopy.moreHelp(for: "项目 Alpha").contains("\u{22}"))
        XCTAssertEqual(GlanceRowActionCopy.moreHelp(for: "  "), GlanceRowActionCopy.more)
    }

    func testAppKitMenuItemUsesSystemDestructiveFlagAndTemplateImage() {
        let target = MenuProbe()
        let deleteItem = GlanceNSMenuItem.make(
            title: "删除工作区",
            symbol: GlanceActionSymbol.delete,
            action: #selector(MenuProbe.act),
            target: target,
            destructive: true
        )
        XCTAssertEqual(deleteItem.title, "删除工作区")
        XCTAssertNotNil(deleteItem.image)
        if deleteItem.responds(to: NSSelectorFromString("isDestructive")) {
            XCTAssertTrue(GlanceNSMenuItem.isSystemDestructive(deleteItem))
        }

        let renameItem = GlanceNSMenuItem.make(
            title: "重命名…",
            symbol: GlanceActionSymbol.edit,
            action: #selector(MenuProbe.act),
            target: target
        )
        XCTAssertFalse(GlanceNSMenuItem.isSystemDestructive(renameItem))
        XCTAssertNotNil(renameItem.image)

        let removeItem = GlanceNSMenuItem.make(
            title: FileShelfCopy.removeLabel,
            symbol: GlanceActionSymbol.remove,
            action: #selector(MenuProbe.act),
            target: target
        )
        XCTAssertFalse(GlanceNSMenuItem.isSystemDestructive(removeItem))
        XCTAssertEqual(GlanceActionSymbol.remove, "minus.circle")
    }

    @MainActor
    func testHoverIconButtonIntrinsicSizeIs26() {
        let button = GlanceHoverIconButton(frame: .zero)
        XCTAssertEqual(button.intrinsicContentSize.width, 26, accuracy: 0.1)
        XCTAssertEqual(button.intrinsicContentSize.height, 26, accuracy: 0.1)
        XCTAssertFalse(button.isBordered)
        XCTAssertFalse(button.isPointerInside)
    }
}

private final class MenuProbe: NSObject {
    @objc func act() {}
}
