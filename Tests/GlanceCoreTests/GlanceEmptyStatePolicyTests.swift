import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class WorkspaceRowQuickActionTests: XCTestCase {
    func testDefaultWorkspaceNeverShowsEllipsis() {
        XCTAssertFalse(WorkspaceRowQuickAction.allowsManagement(WorkspaceRecord.defaultID))
        XCTAssertFalse(
            WorkspaceRowQuickAction.showsEllipsis(
                workspaceID: WorkspaceRecord.defaultID,
                isHovered: true,
                isSelected: true
            )
        )
        XCTAssertEqual(WorkspaceRowMenu.actions(for: WorkspaceRecord.defaultID), [])
    }

    func testCustomWorkspaceEllipsisFollowsHoverAndSelection() {
        XCTAssertFalse(
            WorkspaceRowQuickAction.showsEllipsis(
                workspaceID: "work",
                isHovered: false,
                isSelected: false
            )
        )
        XCTAssertTrue(
            WorkspaceRowQuickAction.showsEllipsis(
                workspaceID: "work",
                isHovered: true,
                isSelected: false
            )
        )
        XCTAssertTrue(
            WorkspaceRowQuickAction.showsEllipsis(
                workspaceID: "work",
                isHovered: false,
                isSelected: true
            )
        )
        XCTAssertEqual(
            WorkspaceRowQuickAction.showsEllipsis(
                workspaceID: "work",
                isHovered: true,
                isSelected: false
            ),
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: true, isSelected: false)
        )
    }

    func testWorkspaceSlotStays26Points() {
        XCTAssertEqual(GlanceRowQuickActionLayout.Kind.workspace.width, 26, accuracy: 0.1)
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .workspace),
            GlanceRowQuickActionLayout.slotWidth(for: .workspace, isHovered: true, isSelected: true)
        )
    }

    func testMenuRoutingUsesRenameAndConfirmDelete() {
        var renamed: [String] = []
        var deleted: [String] = []
        let id = "alpha"
        XCTAssertEqual(WorkspaceRowMenu.actions(for: id), [.rename, .delete])
        WorkspaceRowMenu.perform(
            .rename,
            id: id,
            rename: { renamed.append($0) },
            delete: { deleted.append($0) }
        )
        WorkspaceRowMenu.perform(
            .delete,
            id: id,
            rename: { renamed.append($0) },
            delete: { deleted.append($0) }
        )
        XCTAssertEqual(renamed, [id])
        XCTAssertEqual(deleted, [id])
        XCTAssertEqual(WorkspaceRowQuickAction.renameLabel, "重命名…")
        XCTAssertEqual(WorkspaceRowQuickAction.deleteLabel, "删除工作区")
        XCTAssertEqual(
            WorkspaceRowQuickAction.moreHelp(name: "项目 Alpha"),
            "“项目 Alpha”的更多操作"
        )
    }
}

final class GlanceEmptyStatePolicyTests: XCTestCase {
    func testClipboardEmptyHasNoCreateCTA() {
        XCTAssertFalse(ClipboardEmptyPresentation.showsCreateCTA)
        XCTAssertEqual(ClipboardHistoryCopy.emptyRecentTitle, "暂无剪贴板记录")
        XCTAssertEqual(ClipboardHistoryCopy.emptyRecentDetail, "复制文字或图片后，会出现在这里。")
        XCTAssertEqual(ClipboardEmptyPresentation.symbol, "doc.on.clipboard")
        XCTAssertEqual(ClipboardHistoryCopy.emptyFavoritesTitle, "还没有收藏")
        XCTAssertEqual(ClipboardHistoryCopy.emptySearch, "没有找到匹配的内容")
    }

    func testFileShelfEmptyCTAUsesAddCallback() {
        XCTAssertTrue(FileShelfEmptyPresentation.showsAddCTA(query: "", tab: .recent))
        XCTAssertFalse(FileShelfEmptyPresentation.showsAddCTA(query: "pdf", tab: .recent))
        XCTAssertFalse(FileShelfEmptyPresentation.showsAddCTA(query: "", tab: .favorites))
        var added = 0
        FileShelfEmptyPresentation.add { added += 1 }
        XCTAssertEqual(added, 1)
        XCTAssertEqual(FileShelfCopy.emptyTitle, "文件架是空的")
        XCTAssertEqual(FileShelfCopy.emptyCTA, "添加文件…")
        XCTAssertEqual(FileShelfCopy.addLabel, "添加文件")
        XCTAssertEqual(FileShelfEmptyPresentation.symbol, "tray")
    }

    func testSnippetEmptyCTAUsesCreateCallback() {
        XCTAssertTrue(SnippetEmptyPresentation.showsCreateCTA(query: "", canMutate: true))
        XCTAssertFalse(SnippetEmptyPresentation.showsCreateCTA(query: "hello", canMutate: true))
        XCTAssertFalse(SnippetEmptyPresentation.showsCreateCTA(query: "", canMutate: false))
        var created = 0
        SnippetEmptyPresentation.create { created += 1 }
        XCTAssertEqual(created, 1)
        XCTAssertEqual(SnippetCopy.emptyTitle, "还没有片段")
        XCTAssertEqual(SnippetCopy.emptyCTA, "新建片段…")
        XCTAssertEqual(SnippetCopy.addLabel, "新建片段")
        XCTAssertEqual(SnippetEmptyPresentation.symbol, "text.quote")
    }

    func testLinkEmptyCTAUsesCreateCallback() {
        XCTAssertTrue(LinkEmptyPresentation.showsCreateCTA(query: "", canMutate: true))
        XCTAssertFalse(LinkEmptyPresentation.showsCreateCTA(query: "https", canMutate: true))
        XCTAssertFalse(LinkEmptyPresentation.showsCreateCTA(query: "", canMutate: false))
        var created = 0
        LinkEmptyPresentation.create { created += 1 }
        XCTAssertEqual(created, 1)
        XCTAssertEqual(LinkCopy.emptyTitle, "还没有链接")
        XCTAssertEqual(LinkCopy.emptyCTA, "添加链接…")
        XCTAssertEqual(LinkCopy.emptyCTAAccessibility, "添加链接")
        XCTAssertEqual(LinkEmptyPresentation.symbol, "link")
    }

    func testGlobalSearchEmptyDiffersForRecentAndQuery() {
        XCTAssertEqual(
            GlobalSearchEmptyPresentation.symbol(query: ""),
            "clock.arrow.circlepath"
        )
        XCTAssertEqual(
            GlobalSearchEmptyPresentation.title(query: ""),
            GlobalSearchCopy.recentSection
        )
        XCTAssertEqual(
            GlobalSearchEmptyPresentation.detail(query: ""),
            GlobalSearchCopy.emptyRecentDetail
        )
        XCTAssertEqual(
            GlobalSearchEmptyPresentation.symbol(query: "missing"),
            "magnifyingglass"
        )
        XCTAssertEqual(
            GlobalSearchEmptyPresentation.title(query: "missing"),
            GlobalSearchCopy.emptySearch
        )
        XCTAssertEqual(
            GlobalSearchEmptyPresentation.detail(query: "missing"),
            GlobalSearchCopy.emptySearchDetail
        )
        XCTAssertFalse(GlobalSearchEmptyPresentation.showsCreateCTA)
        XCTAssertNotEqual(
            GlobalSearchEmptyPresentation.title(query: ""),
            GlobalSearchEmptyPresentation.title(query: "abc")
        )
    }

    func testOnlyContentCreationEmptyStatesExposeCTA() {
        XCTAssertTrue(FileShelfEmptyPresentation.showsAddCTA(query: "", tab: .recent))
        XCTAssertTrue(SnippetEmptyPresentation.showsCreateCTA(query: "", canMutate: true))
        XCTAssertTrue(LinkEmptyPresentation.showsCreateCTA(query: "", canMutate: true))
        XCTAssertTrue(PanelLibraryCreatePresentation.showsCreateCTA(for: .emptyWorkspace))
        XCTAssertFalse(ClipboardEmptyPresentation.showsCreateCTA)
        XCTAssertFalse(GlobalSearchEmptyPresentation.showsCreateCTA)
        XCTAssertFalse(PanelLibraryCreatePresentation.showsCreateCTA(for: .noSearchResults))
        XCTAssertFalse(PanelLibraryCreatePresentation.showsCreateCTA(for: .noFilterMatches))
        XCTAssertFalse(FileShelfEmptyPresentation.showsAddCTA(query: "", tab: .favorites))
    }
}
