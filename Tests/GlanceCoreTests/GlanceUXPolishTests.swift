import AppKit
import SwiftUI
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class GlanceUXPolishTests: XCTestCase {
    func testRowQuickActionVisibilityPolicy() {
        XCTAssertFalse(
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: false, isSelected: false)
        )
        XCTAssertTrue(
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: true, isSelected: false)
        )
        XCTAssertTrue(
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: false, isSelected: true)
        )
        XCTAssertTrue(
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: true, isSelected: true)
        )

        XCTAssertFalse(
            GlanceRowQuickActionVisibility.showsPersistentMark(
                isActive: false,
                isHovered: false,
                isSelected: false
            )
        )
        XCTAssertTrue(
            GlanceRowQuickActionVisibility.showsPersistentMark(
                isActive: true,
                isHovered: false,
                isSelected: false
            )
        )
        XCTAssertTrue(
            GlanceRowQuickActionVisibility.showsPersistentMark(
                isActive: false,
                isHovered: true,
                isSelected: false
            )
        )
        XCTAssertTrue(
            GlanceRowQuickActionVisibility.showsPersistentMark(
                isActive: false,
                isHovered: false,
                isSelected: true
            )
        )
        XCTAssertEqual(GlanceRowQuickActionVisibility.buttonSide, GlanceRowQuickActionLayout.buttonSide)
        XCTAssertEqual(GlanceRowQuickActionLayout.buttonSide, 26, accuracy: 0.1)
    }

    func testTrailingSlotWidthsStayStableAcrossHoverSelectionAndActive() {
        XCTAssertEqual(GlanceRowQuickActionLayout.clipboardButtons, ClipboardRowQuickAction.actionCount)
        XCTAssertEqual(GlanceRowQuickActionLayout.fileShelfButtons, FileShelfRowQuickAction.actionCount)
        XCTAssertEqual(GlanceRowQuickActionLayout.snippetButtons, SnippetRowQuickAction.actionCount)
        XCTAssertEqual(GlanceRowQuickActionLayout.linkButtons, LinkRowQuickAction.actionCount)
        XCTAssertEqual(GlanceRowQuickActionLayout.panelLibraryButtons, PanelLibraryRowQuickAction.actionCount)

        XCTAssertEqual(ClipboardRowQuickAction.actionCount, 3)
        XCTAssertEqual(FileShelfRowQuickAction.actionCount, 4)
        XCTAssertEqual(SnippetRowQuickAction.actionCount, 4)
        XCTAssertEqual(LinkRowQuickAction.actionCount, 4)
        XCTAssertEqual(PanelLibraryRowQuickAction.actionCount, 3)
        XCTAssertEqual(GlanceRowQuickActionLayout.globalSearchButtons, 1)
        XCTAssertEqual(GlanceRowQuickActionLayout.workspaceButtons, 1)
        XCTAssertEqual(WorkspaceRowQuickAction.actionCount, 1)
        XCTAssertEqual(GlobalSearchRowActionPresentation.trailingWidth, 26, accuracy: 0.1)
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .workspace),
            26,
            accuracy: 0.1
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .workspace, isHovered: true, isSelected: true),
            GlanceRowQuickActionLayout.slotWidth(for: .workspace)
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .globalSearch),
            26,
            accuracy: 0.1
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .globalSearch, isHovered: true, isSelected: true),
            GlanceRowQuickActionLayout.slotWidth(for: .globalSearch)
        )

        XCTAssertEqual(
            GlanceRowQuickActionLayout.width(for: GlanceRowQuickActionLayout.clipboardButtons),
            78,
            accuracy: 0.1
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.width(for: GlanceRowQuickActionLayout.fileShelfButtons),
            104,
            accuracy: 0.1
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.width(for: GlanceRowQuickActionLayout.snippetButtons),
            104,
            accuracy: 0.1
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.width(for: GlanceRowQuickActionLayout.linkButtons),
            104,
            accuracy: 0.1
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.width(for: GlanceRowQuickActionLayout.panelLibraryButtons),
            78,
            accuracy: 0.1
        )

        for kind in GlanceRowQuickActionLayout.Kind.allCases {
            let expected = GlanceRowQuickActionLayout.width(for: kind.buttonCount)
            let hovered = GlanceRowQuickActionLayout.slotWidth(for: kind, isHovered: true)
            let selected = GlanceRowQuickActionLayout.slotWidth(for: kind, isSelected: true)
            let active = GlanceRowQuickActionLayout.slotWidth(for: kind, isActive: true)
            let idle = GlanceRowQuickActionLayout.slotWidth(
                for: kind,
                isHovered: false,
                isSelected: false,
                isActive: false
            )
            XCTAssertEqual(idle, expected)
            XCTAssertEqual(hovered, idle)
            XCTAssertEqual(selected, idle)
            XCTAssertEqual(active, idle)
        }

        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .clipboard, isActive: false),
            GlanceRowQuickActionLayout.slotWidth(for: .clipboard, isActive: true)
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .snippet, isActive: false),
            GlanceRowQuickActionLayout.slotWidth(for: .snippet, isActive: true)
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .fileShelf),
            GlanceRowQuickActionLayout.slotWidth(for: .fileShelf, isHovered: true, isSelected: true)
        )
        XCTAssertEqual(FileShelfQuickAction.primary(missing: true), .relink)
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .fileShelf),
            GlanceRowQuickActionLayout.width(for: FileShelfRowQuickAction.actionCount)
        )
    }

    func testClipboardQuickActionsCallExistingCallbacks() {
        let id = UUID()
        var favorite: UUID?
        var deleted: UUID?
        ClipboardRowQuickAction.toggleFavorite(id, using: { favorite = $0 })
        ClipboardRowQuickAction.delete(id, using: { deleted = $0 })
        XCTAssertEqual(favorite, id)
        XCTAssertEqual(deleted, id)
        XCTAssertEqual(ClipboardHistoryCopy.deleteLabel, GlanceRowActionCopy.delete)
        XCTAssertEqual(ClipboardHistoryCopy.favoriteLabel, "收藏")
        XCTAssertEqual(ClipboardHistoryCopy.unfavoriteLabel, "取消收藏")
        XCTAssertEqual(GlanceRowActionCopy.more, "更多操作")
    }

    func testFileShelfPrimaryAndRemoveDoNotDeleteFinderFiles() {
        XCTAssertEqual(FileShelfQuickAction.primary(missing: false), .open)
        XCTAssertEqual(FileShelfQuickAction.primary(missing: true), .relink)
        XCTAssertEqual(FileShelfQuickAction.primarySymbol(missing: false), "arrow.up.forward.app")
        XCTAssertEqual(FileShelfQuickAction.primarySymbol(missing: true), "link.badge.plus")
        XCTAssertEqual(FileShelfQuickAction.removeSymbol, "minus.circle")
        XCTAssertNotEqual(FileShelfQuickAction.removeSymbol, "trash")
        XCTAssertFalse(FileShelfQuickAction.removeDeletesFinderFile)
        XCTAssertEqual(FileShelfQuickAction.primaryHelp(missing: false), FileShelfCopy.openLabel)
        XCTAssertEqual(FileShelfCopy.removeLabel, "从文件架移除")

        let id = UUID()
        var opened: UUID?
        var relinked: UUID?
        var removed: UUID?
        FileShelfRowQuickAction.performPrimary(
            missing: false,
            id: id,
            onOpen: { opened = $0 },
            onRelink: { relinked = $0 }
        )
        XCTAssertEqual(opened, id)
        XCTAssertNil(relinked)

        FileShelfRowQuickAction.performPrimary(
            missing: true,
            id: id,
            onOpen: { _ in opened = UUID() },
            onRelink: { relinked = $0 }
        )
        XCTAssertEqual(relinked, id)
        FileShelfRowQuickAction.remove(id, using: { removed = $0 })
        XCTAssertEqual(removed, id)
    }

    @MainActor
    func testFileShelfRemoveKeepsOriginalFinderFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceUXPolishShelf-\(UUID().uuidString)", isDirectory: true)
        let files = root.appendingPathComponent("UserFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = files.appendingPathComponent("keep-me.txt")
        try Data("safe".utf8).write(to: original)
        let store = FileShelfStore(root: root.appendingPathComponent("FileShelf", isDirectory: true))
        let service = FileShelfService(store: store, bookmarks: FakeFileShelfBookmarks())
        let added = service.add(paths: [original.path]).addedIDs.first
        let recordID = try XCTUnwrap(added)
        FileShelfRowQuickAction.remove(recordID, using: { service.remove(id: $0) })
        XCTAssertTrue(service.records.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
    }

    func testSnippetQuickActionsKeepDoubleClickEdit() {
        XCTAssertTrue(SnippetRowQuickAction.doubleClickPerformsEdit)
        XCTAssertEqual(SnippetRowQuickAction.leadingSymbol, "text.quote")
        XCTAssertEqual(GlanceRowActionCopy.leadingSnippet, "片段")
        XCTAssertEqual(SnippetCopy.copyLabel, GlanceRowActionCopy.copy)
        XCTAssertEqual(SnippetCopy.pinLabel, "置顶")
        XCTAssertEqual(SnippetCopy.unpinLabel, "取消置顶")

        let id = UUID()
        var copied: UUID?
        var pinned: UUID?
        var deleted: UUID?
        var edited: UUID?
        SnippetRowQuickAction.copy(id, using: { copied = $0 })
        SnippetRowQuickAction.togglePin(id, using: { pinned = $0 })
        SnippetRowQuickAction.delete(id, using: { deleted = $0 })
        if SnippetRowQuickAction.doubleClickPerformsEdit {
            edited = id
        }
        XCTAssertEqual(copied, id)
        XCTAssertEqual(pinned, id)
        XCTAssertEqual(deleted, id)
        XCTAssertEqual(edited, id)
    }

    func testLinkQuickActionsKeepDoubleClickOpen() {
        XCTAssertTrue(LinkRowQuickAction.doubleClickPerformsOpen)
        XCTAssertEqual(LinkCopy.openLabel, GlanceRowActionCopy.open)
        XCTAssertEqual(LinkCopy.pinLabel, "置顶")
        XCTAssertEqual(LinkCopy.unpinLabel, "取消置顶")

        let id = UUID()
        var opened: UUID?
        var pinned: UUID?
        var deleted: UUID?
        var doubleClicked: UUID?
        LinkRowQuickAction.open(id, using: { opened = $0 })
        LinkRowQuickAction.togglePin(id, using: { pinned = $0 })
        LinkRowQuickAction.delete(id, using: { deleted = $0 })
        if LinkRowQuickAction.doubleClickPerformsOpen {
            doubleClicked = id
        }
        XCTAssertEqual(opened, id)
        XCTAssertEqual(pinned, id)
        XCTAssertEqual(deleted, id)
        XCTAssertEqual(doubleClicked, id)
    }

    func testPanelLibraryQuickActionsUseConfirmDelete() {
        XCTAssertTrue(PanelLibraryQuickAction.deleteUsesConfirmation)
        XCTAssertEqual(PanelLibraryQuickAction.deleteSymbol, "trash")
        XCTAssertEqual(PanelLibraryQuickAction.visibilitySymbol(isHidden: false), "eye.slash")
        XCTAssertEqual(PanelLibraryQuickAction.visibilitySymbol(isHidden: true), "eye")
        XCTAssertEqual(PanelLibraryQuickAction.visibilityHelp(isHidden: false), GlanceRowActionCopy.hidePanel)
        XCTAssertEqual(PanelLibraryQuickAction.visibilityHelp(isHidden: true), GlanceRowActionCopy.showPanel)

        let id = UUID()
        var hidden: UUID?
        var revealed: UUID?
        var confirmed: UUID?
        var deleted: UUID?
        PanelLibraryRowQuickAction.toggleVisibility(
            isHidden: false,
            id: id,
            hide: { hidden = $0 },
            reveal: { revealed = $0 }
        )
        XCTAssertEqual(hidden, id)
        XCTAssertNil(revealed)

        PanelLibraryRowQuickAction.toggleVisibility(
            isHidden: true,
            id: id,
            hide: { _ in hidden = UUID() },
            reveal: { revealed = $0 }
        )
        XCTAssertEqual(revealed, id)

        PanelLibraryRowQuickAction.requestDelete(
            id,
            confirmDelete: { confirmed = $0 },
            delete: { deleted = $0 }
        )
        XCTAssertEqual(confirmed, id)
        XCTAssertNil(deleted)
        XCTAssertEqual(GlanceRowActionCopy.createPanel, "新建面板…")
        XCTAssertEqual(GlanceRowActionCopy.delete, "删除")
    }

    func testFloatingPanelCloseHidesAndDoesNotDelete() {
        let id = UUID()
        var hidden: UUID?
        var deleted: UUID?
        PanelChromeCloseRouting.close(
            id: id,
            hide: { hidden = $0 },
            delete: { deleted = $0 }
        )
        XCTAssertEqual(hidden, id)
        XCTAssertNil(deleted)
        XCTAssertEqual(GlanceRowActionCopy.hidePanel, "隐藏面板")
    }

    func testPanelChromeKindIconReusesPanelKindSymbol() {
        let kinds = [
            PanelKind.text,
            PanelKind.markdown,
            PanelKind.todo,
            PanelKind.image,
            PanelKind.pdf
        ]
        for kind in kinds {
            XCTAssertEqual(
                PanelChromeCloseRouting.kindSymbolName(for: kind),
                PanelKindSymbol.name(for: kind)
            )
        }
        XCTAssertEqual(PanelCreationKind.text.symbolName, PanelKindSymbol.name(for: PanelKind.text))
        XCTAssertEqual(PanelCreationKind.markdown.symbolName, PanelKindSymbol.name(for: PanelKind.markdown))
        XCTAssertEqual(PanelCreationKind.todo.symbolName, PanelKindSymbol.name(for: PanelKind.todo))
        XCTAssertEqual(PanelCreationKind.image.symbolName, PanelKindSymbol.name(for: PanelKind.image))
        XCTAssertEqual(PanelCreationKind.pdf.symbolName, PanelKindSymbol.name(for: PanelKind.pdf))
    }

    func testPanelLibraryCreateRoutingUsesInjectedPanelManagerHooks() {
        var created: [String] = []
        let hooks = PanelLibraryCreateHooks(
            createText: { created.append("text") },
            createMarkdown: { created.append("markdown") },
            createTodo: { created.append("todo") },
            createImage: { created.append("image") },
            createPDF: { created.append("pdf") }
        )
        for kind in PanelCreationKind.allCases {
            PanelLibraryCreateRouting.perform(kind, into: hooks)
        }
        XCTAssertEqual(created, ["text", "markdown", "todo", "image", "pdf"])
        XCTAssertEqual(PanelCreationKind.allCases.map(\.title), ["文字", "Markdown", "待办", "图片", "PDF…"])
    }

    @MainActor
    func testPanelLibraryModelCreatePanelUsesSingleCallback() {
        let model = PanelLibraryModel()
        var kinds: [PanelCreationKind] = []
        model.createPanel = { kinds.append($0) }
        model.createPanel(.todo)
        model.createPanel(.pdf)
        XCTAssertEqual(kinds, [.todo, .pdf])
    }

    func testEmptyWorkspaceCTAPolicy() {
        XCTAssertTrue(PanelLibraryCreatePresentation.showsCreateCTA(for: .emptyWorkspace))
        XCTAssertFalse(PanelLibraryCreatePresentation.showsCreateCTA(for: .noSearchResults))
        XCTAssertFalse(PanelLibraryCreatePresentation.showsCreateCTA(for: .noFilterMatches))
        XCTAssertFalse(PanelLibraryCreatePresentation.showsCreateCTA(for: .loading))
        XCTAssertFalse(PanelLibraryCreatePresentation.showsCreateCTA(for: .none))
        XCTAssertEqual(GlanceEmptyCopy.workspaceDetail, "新建一个面板，开始使用这个工作区。")
        XCTAssertEqual(GlanceEmptyCopy.searchTitle, "没有找到匹配的面板")
        XCTAssertEqual(GlanceEmptyCopy.searchDetail, "试试其他关键词。")
        XCTAssertEqual(GlanceEmptyCopy.filterTitle, "没有符合筛选条件的面板")
        XCTAssertEqual(GlanceEmptyCopy.filterDetail, "调整类型或标签筛选后再试。")
    }

    @MainActor
    func testTrailingSlotOccupiesStableLayoutWidthBesideLongTitles() {
        let titles = [
            "这是一个非常非常非常非常长的剪贴板内容……",
            "2026年度产品规划最终最终最终修改版v18.pdf",
            "这是一个非常长的项目会议纪要模板名称",
            "https://very-long-domain.example.com/path/to/a-very-long-article"
        ]
        for title in titles {
            let idle104 = measureTrailingSlot(width: 104, showsActions: false, title: title, rowWidth: 400)
            let hover104 = measureTrailingSlot(width: 104, showsActions: true, title: title, rowWidth: 400)
            XCTAssertEqual(idle104.slot, 104, accuracy: 0.5, "slot \(title)")
            XCTAssertEqual(hover104.slot, 104, accuracy: 0.5)
            XCTAssertEqual(idle104.title, hover104.title, accuracy: 0.5)
            XCTAssertGreaterThan(idle104.title, 80)
            XCTAssertLessThanOrEqual(idle104.title + idle104.slot + GlanceTheme.Space.md, 401)

            let idle78 = measureTrailingSlot(width: 78, showsActions: false, title: title, rowWidth: 360)
            let selected78 = measureTrailingSlot(width: 78, showsActions: true, title: title, rowWidth: 360)
            XCTAssertEqual(idle78.slot, 78, accuracy: 0.5)
            XCTAssertEqual(selected78.slot, 78, accuracy: 0.5)
            XCTAssertEqual(idle78.title, selected78.title, accuracy: 0.5)

            let idle26 = measureTrailingSlot(width: 26, showsActions: false, title: title, rowWidth: 320)
            let hover26 = measureTrailingSlot(width: 26, showsActions: true, title: title, rowWidth: 320)
            XCTAssertEqual(idle26.slot, 26, accuracy: 0.5)
            XCTAssertEqual(hover26.slot, 26, accuracy: 0.5)
            XCTAssertEqual(idle26.title, hover26.title, accuracy: 0.5)
        }
    }

    @MainActor
    private func measureTrailingSlot(
        width: CGFloat,
        showsActions: Bool,
        title: String,
        rowWidth: CGFloat
    ) -> (title: CGFloat, slot: CGFloat) {
        let box = LayoutWidthBox()
        let root = TrailingSlotLayoutProbe(
            slotWidth: width,
            showsActions: showsActions,
            title: title,
            box: box
        )
        .frame(width: rowWidth, height: 36)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: rowWidth, height: 36)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        return (box.title, box.slot)
    }
}

private final class LayoutWidthBox {
    var title: CGFloat = 0
    var slot: CGFloat = 0
}

private struct TitleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SlotWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TrailingSlotLayoutProbe: View {
    var slotWidth: CGFloat
    var showsActions: Bool
    var title: String
    var box: LayoutWidthBox

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            Text(title)
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: TitleWidthKey.self, value: geo.size.width)
                    }
                }
            GlanceRowTrailingAccessory(width: slotWidth, showsActions: showsActions) {
                Text("3分钟前")
            } actions: {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 26, height: 26)
                    Color.clear.frame(width: 26, height: 26)
                    Color.clear.frame(width: 26, height: 26)
                    Color.clear.frame(width: 26, height: 26)
                }
            }
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: SlotWidthKey.self, value: geo.size.width)
                }
            }
        }
        .onPreferenceChange(TitleWidthKey.self) { box.title = $0 }
        .onPreferenceChange(SlotWidthKey.self) { box.slot = $0 }
    }
}
