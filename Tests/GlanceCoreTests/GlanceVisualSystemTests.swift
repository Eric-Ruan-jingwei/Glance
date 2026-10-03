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
        XCTAssertEqual(titles[0], "快速记录…")
        XCTAssertEqual(titles[1], "从剪贴板创建…")
        XCTAssertEqual(titles[3], "工作区")
        XCTAssertEqual(titles[5], "管理面板…")
        XCTAssertEqual(titles[6], "新建")
        XCTAssertEqual(titles[7], "新建文字面板")
        XCTAssertEqual(titles[8], "新建 Markdown 面板")
        XCTAssertEqual(titles[9], "新建待办面板")
        XCTAssertEqual(titles[10], "新建图片面板")
        XCTAssertEqual(titles[11], "新建 PDF 面板…")
        XCTAssertEqual(titles[12], "状态")
        XCTAssertEqual(titles[13], "隐藏全部")
        XCTAssertEqual(titles.last, "退出")
        XCTAssertNotNil(menu.items[0].image)
        XCTAssertNotNil(menu.items[5].image)
        XCTAssertNotNil(menu.items[7].image)
        XCTAssertTrue(menu.items[6].isSectionHeader)
        XCTAssertTrue(menu.items[12].isSectionHeader)
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
