import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class GlanceVisualSystemTests: XCTestCase {
    func testSharedRadiiMatchTheQuietCardLanguage() {
        XCTAssertEqual(GlanceTheme.Radius.chip, 8)
        XCTAssertEqual(GlanceTheme.Radius.control, 6)
        XCTAssertEqual(GlanceTheme.Radius.panel, 16)
        XCTAssertEqual(GlanceConstants.cornerRadius, 16)
        XCTAssertEqual(GlanceConstants.panelDragStrip, GlanceTheme.Size.panelChromeHeight)
        XCTAssertEqual(GlanceTheme.Size.hairline, 1)
        XCTAssertEqual(GlanceTheme.Size.panelChromeHeight, 28)
    }

    func testKindSymbolsStayStable() {
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.text), "doc.text")
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.todo), "checklist")
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.pdf), "doc.richtext")
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.image, unreadable: true), "exclamationmark.triangle")
    }

    func testStatusMenuKeepsActionsAndAddsNativeSections() {
        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            onQuickCapture: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onNewPDF: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
        let titles = menu.items.map(\.title)
        XCTAssertEqual(menu.items.first { $0.title == "快速记录…" }?.title, "快速记录…")
        XCTAssertEqual(menu.items.first { $0.title == "剪贴板…" }?.title, "剪贴板…")
        XCTAssertNotNil(menu.items.first { $0.title == "面板" }?.submenu)
        XCTAssertNil(menu.items.first { $0.title == "从当前剪贴板创建…" })
        XCTAssertNil(menu.items.first { $0.title == "工作区" })
        XCTAssertNil(menu.items.first { $0.title == "管理面板…" })
        XCTAssertNil(menu.items.first { $0.title == "状态" })
        XCTAssertNil(menu.items.first { $0.title == "隐藏全部" })
        let newPanel = GlanceMenuQuery.item(titled: "新建面板", in: menu)
        XCTAssertNotNil(newPanel)
        XCTAssertNotNil(GlanceMenuQuery.item(titled: "隐藏全部", in: menu))
        XCTAssertNotNil(menu.items.first { $0.title == GlanceGuideEntry.menuTitle })
        XCTAssertNotNil(menu.items.first { $0.title == "设置…" })
        XCTAssertEqual(titles.last, "退出")
        XCTAssertNotNil(menu.items.first { $0.title == "快速记录…" }?.image)
        XCTAssertNotNil(GlanceMenuQuery.item(titled: "管理面板…", in: menu)?.image)
        XCTAssertNotNil(newPanel?.image)
        XCTAssertEqual(
            GlanceMenuQuery.newPanelMenu(in: menu)?.items.map(\.title),
            ["文字", "Markdown", "待办", "图片", "PDF…"]
        )
    }

    func testWorkspacePanelCountIsDerivedFromSummaries() {
        let model = PanelLibraryModel()
        model.summaries = [
            dummySummary(workspaceID: WorkspaceRecord.defaultID),
            dummySummary(workspaceID: "work"),
            dummySummary(workspaceID: "work")
        ]
        XCTAssertEqual(model.panelCount(in: WorkspaceRecord.defaultID), 1)
        XCTAssertEqual(model.panelCount(in: "work"), 2)
        XCTAssertEqual(model.panelCount(in: "missing"), 0)
    }

    func testEmptyKindDistinguishesWorkspaceSearchAndFilter() {
        let model = PanelLibraryModel()
        XCTAssertEqual(model.emptyKind, .emptyWorkspace)

        model.summaries = [dummySummary(workspaceID: WorkspaceRecord.defaultID)]
        XCTAssertEqual(model.emptyKind, .none)

        model.query = "missing"
        XCTAssertEqual(model.emptyKind, .noSearchResults)

        model.query = ""
        model.filter = .pdf
        XCTAssertEqual(model.emptyKind, .noFilterMatches)

        model.isLoadingSummaries = true
        model.summaries = []
        XCTAssertEqual(model.emptyKind, .loading)
    }

    func testShowsBatchToolbarFollowsSelectionAndEmptyKind() {
        let model = PanelLibraryModel()
        XCTAssertFalse(model.showsBatchToolbar)

        let summary = dummySummary(workspaceID: WorkspaceRecord.defaultID)
        model.summaries = [summary]
        XCTAssertFalse(model.showsBatchToolbar)

        model.selectedPanelIDs = [summary.id]
        XCTAssertTrue(model.showsBatchToolbar)

        model.selectedPanelIDs = []
        XCTAssertFalse(model.showsBatchToolbar)

        model.selectedPanelIDs = [summary.id]
        model.summaries = []
        XCTAssertEqual(model.emptyKind, .emptyWorkspace)
        XCTAssertFalse(model.showsBatchToolbar)
    }

    func testMarkdownPreviewUsesHeadingHierarchy() {
        let rich = MarkdownPreviewAppearance.nsAttributedString(
            from: "# Title\n\n## Subtitle\n\nbody text\n\n> quoted\n\n`code`"
        )
        XCTAssertGreaterThan(rich.length, 0)
        var sizes = Set<CGFloat>()
        rich.enumerateAttribute(.font, in: NSRange(location: 0, length: rich.length)) { value, _, _ in
            if let font = value as? NSFont {
                sizes.insert(font.pointSize)
            }
        }
        XCTAssertTrue(sizes.contains(22))
        XCTAssertTrue(sizes.contains(17))
        XCTAssertTrue(sizes.contains(13))
        XCTAssertEqual(GlanceTheme.Size.readingInset.width, 16)
        XCTAssertEqual(GlanceTheme.Size.formatBarHeight, 28)
        XCTAssertEqual(GlanceTheme.Size.todoRowHeight, 32)
        XCTAssertEqual(GlanceTheme.Size.mediaInset, 6)
        XCTAssertEqual(GlanceEmptyCopy.workspaceTitle, "这个工作区还是空的")
        XCTAssertEqual(GlanceEmptyCopy.searchTitle, "没有找到面板")
        XCTAssertEqual(GlanceEmptyCopy.filterTitle, "没有符合筛选的面板")
        XCTAssertEqual(GlanceEmptyCopy.quickCapturePlaceholder, "记录点什么…")
        XCTAssertEqual(GlanceEmptyCopy.textPlaceholder, "单击编辑")
        XCTAssertEqual(GlanceEmptyCopy.markdownPlaceholder, "单击编辑 Markdown")
        XCTAssertEqual(PanelSummaryFallback.pdfUnreadable, "无法读取 PDF")
    }

    func testMarkdownPreviewStylesTaskListGlyphs() {
        let rich = MarkdownPreviewAppearance.nsAttributedString(from: "- [ ] Open\n- [x] Done")
        let text = rich.string as NSString
        let unchecked = text.range(of: "☐")
        let checked = text.range(of: "☑")
        XCTAssertNotEqual(unchecked.location, NSNotFound)
        XCTAssertNotEqual(checked.location, NSNotFound)
        var uncheckedColor: NSColor?
        var checkedColor: NSColor?
        rich.enumerateAttribute(.foregroundColor, in: unchecked) { value, _, _ in
            uncheckedColor = value as? NSColor
        }
        rich.enumerateAttribute(.foregroundColor, in: checked) { value, _, _ in
            checkedColor = value as? NSColor
        }
        XCTAssertEqual(uncheckedColor, NSColor.secondaryLabelColor)
        XCTAssertEqual(checkedColor, NSColor.tertiaryLabelColor)
    }

    func testChromeTitlePrefersCustomThenAutomaticThenKind() {
        XCTAssertEqual(
            PanelChromeTitle.resolved(
                customTitle: "工作笔记",
                automaticTitle: "项目计划",
                kindIdentifier: PanelKind.text
            ),
            "工作笔记"
        )
        XCTAssertEqual(
            PanelChromeTitle.resolved(
                customTitle: nil,
                automaticTitle: "产品规划",
                kindIdentifier: PanelKind.text
            ),
            "产品规划"
        )
        XCTAssertEqual(
            PanelChromeTitle.resolved(
                customTitle: "  ",
                automaticTitle: "VLA Training Notes",
                kindIdentifier: PanelKind.markdown
            ),
            "VLA Training Notes"
        )
        XCTAssertEqual(
            PanelChromeTitle.resolved(
                customTitle: nil,
                automaticTitle: "完成课程大纲",
                kindIdentifier: PanelKind.todo
            ),
            "完成课程大纲"
        )
        XCTAssertEqual(
            PanelChromeTitle.resolved(
                customTitle: "必读论文",
                automaticTitle: "Robot Learning Survey",
                kindIdentifier: PanelKind.pdf
            ),
            "必读论文"
        )
        XCTAssertEqual(
            PanelChromeTitle.resolved(
                customTitle: nil,
                automaticTitle: nil,
                kindIdentifier: PanelKind.image
            ),
            "图片"
        )
        XCTAssertEqual(
            PanelChromeTitle.resolved(
                customTitle: nil,
                automaticTitle: "Robot Learning Survey",
                kindIdentifier: PanelKind.pdf
            ),
            "Robot Learning Survey"
        )
    }

    func testTextFormatBarReservesOffsetOnlyWhileEditing() {
        XCTAssertEqual(TextFormatBarLayout.scrollTopInset(isEditing: false), 0)
        XCTAssertEqual(TextFormatBarLayout.scrollTopInset(isEditing: true), GlanceTheme.Size.formatBarHeight)
    }

    private func dummySummary(workspaceID: String) -> PanelSummary {
        PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.text,
            title: "Note",
            subtitle: nil,
            preview: "",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: false,
            isHidden: false,
            workspaceID: workspaceID,
            isUnreadable: false
        )
    }
}
