import AppKit
import SwiftUI
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class GlobalSearchDirectActionTests: XCTestCase {
    func testResultIDsMapToActionSourceIDsExceptPanels() {
        let id = UUID()
        XCTAssertEqual(
            GlobalSearchItemActionBridge.sourceID(for: GlobalSearchResultID(source: .clipboard, itemID: id)),
            .clipboard(id)
        )
        XCTAssertEqual(
            GlobalSearchItemActionBridge.sourceID(for: GlobalSearchResultID(source: .fileShelf, itemID: id)),
            .fileShelf(id)
        )
        XCTAssertEqual(
            GlobalSearchItemActionBridge.sourceID(for: GlobalSearchResultID(source: .snippets, itemID: id)),
            .snippet(id)
        )
        XCTAssertEqual(
            GlobalSearchItemActionBridge.sourceID(for: GlobalSearchResultID(source: .links, itemID: id)),
            .link(id)
        )
        XCTAssertNil(
            GlobalSearchItemActionBridge.sourceID(for: GlobalSearchResultID(source: .panels, itemID: id))
        )
    }

    func testClipboardPlainTextSearchActions() {
        let record = clipboardText("hello world")
        assertSearchActions(
            resultID: GlobalSearchResultID(source: .clipboard, itemID: record.id),
            coordinator: coordinator(log: ActionCallLog(), clipboard: record),
            itemActions: [.createTextPanel, .saveAsSnippet]
        )
    }

    func testClipboardURLSearchActions() {
        let record = clipboardText("https://example.com")
        assertSearchActions(
            resultID: GlobalSearchResultID(source: .clipboard, itemID: record.id),
            coordinator: coordinator(log: ActionCallLog(), clipboard: record),
            itemActions: [.createTextPanel, .saveAsSnippet, .saveAsLink]
        )
    }

    func testSnippetSearchActions() {
        let record = snippetRecord()
        assertSearchActions(
            resultID: GlobalSearchResultID(source: .snippets, itemID: record.id),
            coordinator: coordinator(log: ActionCallLog(), snippet: record),
            itemActions: [.createTextPanel]
        )
    }

    func testLinkSearchActions() {
        let record = linkRecord()
        assertSearchActions(
            resultID: GlobalSearchResultID(source: .links, itemID: record.id),
            coordinator: coordinator(log: ActionCallLog(), link: record),
            itemActions: [.createTextPanel]
        )
    }

    func testValidFileShelfPDFSearchActions() {
        let record = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        assertSearchActions(
            resultID: GlobalSearchResultID(source: .fileShelf, itemID: record.id),
            coordinator: coordinator(log: ActionCallLog(), file: record, resolvedPath: record.originalPath),
            itemActions: [.createPDFPanel]
        )
    }

    func testMissingFileShelfPDFSearchActionsAreRevealOnly() {
        let record = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        assertSearchActions(
            resultID: GlobalSearchResultID(source: .fileShelf, itemID: record.id),
            coordinator: coordinator(log: ActionCallLog(), file: record, fileMissing: true),
            itemActions: []
        )
    }

    func testPanelSearchActionsAreRevealOnly() {
        let resultID = GlobalSearchResultID(source: .panels, itemID: UUID())
        let composed = GlobalSearchResultActions.compose(resultID: resultID) { _ in
            XCTFail("panel results must not request item actions")
            return [.createTextPanel]
        }
        XCTAssertTrue(composed.canReveal)
        XCTAssertEqual(composed.itemActions, [])
    }

    func testContextMenuUsesCoordinatorAvailabilityAndStableIdentifiers() {
        let record = clipboardText("https://example.com")
        let coordinator = coordinator(log: ActionCallLog(), clipboard: record)
        let resultID = GlobalSearchResultID(source: .clipboard, itemID: record.id)
        let composed = GlobalSearchResultActions.compose(resultID: resultID) {
            coordinator.availableActions(for: $0)
        }
        XCTAssertEqual(composed.itemActions.map(\.identifier), ["createTextPanel", "saveAsSnippet", "saveAsLink"])
        XCTAssertEqual(
            composed.itemActions.map { GlanceItemAction(identifier: $0.identifier) },
            composed.itemActions
        )
        XCTAssertEqual(composed.itemActions[0].title, GlanceItemAction.createTextPanel.title)
    }

    func testSearchSnippetCreateTextPanelOnlyCallsPanelAPI() throws {
        let record = snippetRecord()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, snippet: record)
        let resultID = GlobalSearchResultID(source: .snippets, itemID: record.id)
        let sourceID = try XCTUnwrap(GlobalSearchItemActionBridge.sourceID(for: resultID))
        XCTAssertEqual(
            coordinator.perform(.createTextPanel, sourceID: sourceID, screen: nil),
            .succeeded
        )
        XCTAssertEqual(log.createTextPanel, 1)
        XCTAssertEqual(log.createFromClipboard, 0)
        XCTAssertEqual(log.presentSnippetEditor, 0)
        XCTAssertEqual(log.importPDF, 0)
    }

    func testSearchLinkCreateTextPanelOnlyCallsPanelAPI() throws {
        let record = linkRecord()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, link: record)
        let sourceID = try XCTUnwrap(
            GlobalSearchItemActionBridge.sourceID(
                for: GlobalSearchResultID(source: .links, itemID: record.id)
            )
        )
        XCTAssertEqual(
            coordinator.perform(.createTextPanel, sourceID: sourceID, screen: nil),
            .succeeded
        )
        XCTAssertEqual(log.createTextPanel, 1)
        XCTAssertEqual(log.presentLinkEditor, 0)
        XCTAssertEqual(log.importImage, 0)
    }

    func testSearchClipboardURLSaveAsLinkUsesEditorPath() throws {
        let record = clipboardText("https://example.com")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: record)
        let sourceID = try XCTUnwrap(
            GlobalSearchItemActionBridge.sourceID(
                for: GlobalSearchResultID(source: .clipboard, itemID: record.id)
            )
        )
        XCTAssertEqual(
            coordinator.perform(.saveAsLink, sourceID: sourceID, screen: nil),
            .succeeded
        )
        XCTAssertEqual(log.presentLinkEditor, 1)
        XCTAssertEqual(log.linkEditorURLs, ["https://example.com"])
        XCTAssertEqual(log.createFromClipboard, 0)
        XCTAssertEqual(log.createTextPanel, 0)
    }

    func testSearchFileShelfPDFCreatePanelResolvesAndImports() throws {
        let record = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: record, resolvedPath: record.originalPath)
        let sourceID = try XCTUnwrap(
            GlobalSearchItemActionBridge.sourceID(
                for: GlobalSearchResultID(source: .fileShelf, itemID: record.id)
            )
        )
        XCTAssertEqual(
            coordinator.perform(.createPDFPanel, sourceID: sourceID, screen: nil),
            .succeeded
        )
        XCTAssertEqual(log.resolveFile, 1)
        XCTAssertEqual(log.importPDF, 1)
        XCTAssertEqual(log.importImage, 0)
    }

    func testStaleSnippetPerformFailsAndDoesNotCallPanelAPI() throws {
        let log = ActionCallLog()
        let coordinator = coordinator(log: log)
        let resultID = GlobalSearchResultID(source: .snippets, itemID: UUID())
        let sourceID = try XCTUnwrap(GlobalSearchItemActionBridge.sourceID(for: resultID))
        XCTAssertEqual(
            coordinator.perform(.createTextPanel, sourceID: sourceID, screen: nil),
            .failed(GlanceNoticeCopy.staleItem)
        )
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertFalse(
            GlobalSearchItemActionSessionPolicy.shouldDismiss(
                after: .createTextPanel,
                outcome: .failed(GlanceNoticeCopy.staleItem)
            )
        )
    }

    func testForcedMissingPDFCreatePanelDoesNotImport() throws {
        let record = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: record, fileMissing: true)
        let sourceID = try XCTUnwrap(
            GlobalSearchItemActionBridge.sourceID(
                for: GlobalSearchResultID(source: .fileShelf, itemID: record.id)
            )
        )
        XCTAssertEqual(coordinator.availableActions(for: sourceID), [])
        XCTAssertEqual(
            coordinator.perform(.createPDFPanel, sourceID: sourceID, screen: nil),
            .failed(GlanceNoticeCopy.fileMissing)
        )
        XCTAssertEqual(log.importPDF, 0)
    }

    func testPanelCreateSuccessDismissesSearchAndFailureDoesNot() {
        XCTAssertTrue(
            GlobalSearchItemActionSessionPolicy.shouldDismiss(
                after: .createTextPanel,
                outcome: .succeeded
            )
        )
        XCTAssertTrue(
            GlobalSearchItemActionSessionPolicy.shouldDismiss(
                after: .createPDFPanel,
                outcome: .succeeded
            )
        )
        XCTAssertFalse(
            GlobalSearchItemActionSessionPolicy.shouldDismiss(
                after: .saveAsSnippet,
                outcome: .succeeded
            )
        )
        XCTAssertFalse(
            GlobalSearchItemActionSessionPolicy.shouldDismiss(
                after: .createTextPanel,
                outcome: .failed(GlanceNoticeCopy.staleItem)
            )
        )
    }

    func testFailedDirectActionKeepsQuerySelectionAndShowsNotice() {
        let snippet = snippetRecord()
        let model = GlobalSearchViewModel()
        model.applyImmediateSnapshot(
            GlobalSearchImmediateSnapshot(
                clipboard: [],
                clipboardUnavailable: false,
                files: [],
                filesUnavailable: false,
                snippets: [snippet],
                snippetsUnavailable: false,
                links: [],
                linksUnavailable: false,
                panelInputs: [],
                panelsUnavailable: false,
                workspaceNames: [:]
            )
        )
        model.query = "公司"
        model.selection = GlobalSearchResultID(source: .snippets, itemID: snippet.id)
        model.showNotice(GlanceNoticeCopy.staleItem)
        XCTAssertEqual(model.query, "公司")
        XCTAssertEqual(model.selection?.itemID, snippet.id)
        XCTAssertEqual(model.notice, GlanceNoticeCopy.staleItem)
        XCTAssertFalse(
            GlobalSearchItemActionSessionPolicy.shouldDismiss(
                after: .createTextPanel,
                outcome: .failed(GlanceNoticeCopy.staleItem)
            )
        )
    }

    func testReturnStillActivatesRatherThanRunningCrossToolAction() {
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 36), .activate)
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 36, command: true), .revealInSource)
        XCTAssertEqual(GlobalSearchCopy.revealInSourceLabel, "在来源中显示")
    }

    func testEllipsisVisibilityMatchesRowQuickActionPolicy() {
        XCTAssertFalse(
            GlobalSearchRowActionPresentation.showsEllipsis(isHovered: false, isSelected: false)
        )
        XCTAssertTrue(
            GlobalSearchRowActionPresentation.showsEllipsis(isHovered: true, isSelected: false)
        )
        XCTAssertTrue(
            GlobalSearchRowActionPresentation.showsEllipsis(isHovered: false, isSelected: true)
        )
        XCTAssertEqual(
            GlobalSearchRowActionPresentation.showsEllipsis(isHovered: false, isSelected: false),
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: false, isSelected: false)
        )
        XCTAssertEqual(
            GlobalSearchRowActionPresentation.showsEllipsis(isHovered: true, isSelected: false),
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: true, isSelected: false)
        )
        XCTAssertEqual(
            GlobalSearchRowActionPresentation.showsEllipsis(isHovered: false, isSelected: true),
            GlanceRowQuickActionVisibility.showsSecondary(isHovered: false, isSelected: true)
        )
    }

    func testTrailingSlotWidthStaysFixedAtOneIcon() {
        XCTAssertEqual(GlobalSearchRowActionPresentation.trailingWidth, 26, accuracy: 0.1)
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .globalSearch),
            GlanceRowQuickActionLayout.slotWidth(for: .globalSearch, isHovered: true)
        )
        XCTAssertEqual(
            GlanceRowQuickActionLayout.slotWidth(for: .globalSearch),
            GlanceRowQuickActionLayout.slotWidth(for: .globalSearch, isSelected: true)
        )
    }

    func testPanelEllipsisMenuIsRevealOnly() {
        let resultID = GlobalSearchResultID(source: .panels, itemID: UUID())
        var availabilityCalls = 0
        let items = GlobalSearchResultMenu.items {
            availabilityCalls += 1
            return GlobalSearchResultActions.compose(resultID: resultID) { _ in
                XCTFail("panel results must not request item actions")
                return [.createTextPanel]
            }.itemActions
        }
        XCTAssertEqual(availabilityCalls, 1)
        XCTAssertEqual(items, [.reveal])
    }

    func testClipboardURLEllipsisMenuReusesAvailability() {
        let record = clipboardText("https://example.com")
        let coordinator = coordinator(log: ActionCallLog(), clipboard: record)
        let resultID = GlobalSearchResultID(source: .clipboard, itemID: record.id)
        let composed = GlobalSearchResultActions.compose(resultID: resultID) {
            coordinator.availableActions(for: $0)
        }
        XCTAssertEqual(
            GlobalSearchResultMenu.items { composed.itemActions },
            [
                .reveal,
                .divider,
                .action(.createTextPanel),
                .action(.saveAsSnippet),
                .action(.saveAsLink)
            ]
        )
    }

    func testFileShelfAvailabilityStaysLazyUntilMenuBuilds() {
        let record = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: record, resolvedPath: record.originalPath)
        let resultID = GlobalSearchResultID(source: .fileShelf, itemID: record.id)
        XCTAssertEqual(log.resolveFile, 0)
        XCTAssertEqual(
            GlobalSearchRowActionPresentation.showsEllipsis(isHovered: true, isSelected: false),
            true
        )
        XCTAssertEqual(log.resolveFile, 0)
        let items = GlobalSearchResultMenu.items {
            guard let sourceID = GlobalSearchItemActionBridge.sourceID(for: resultID) else {
                return []
            }
            return coordinator.availableActions(for: sourceID)
        }
        XCTAssertEqual(log.resolveFile, 1)
        XCTAssertEqual(items, [.reveal, .divider, .action(.createPDFPanel)])
    }

    func testSearchViewRenderDoesNotCallItemActions() {
        let record = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let model = GlobalSearchViewModel()
        model.applyImmediateSnapshot(
            GlobalSearchImmediateSnapshot(
                clipboard: [],
                clipboardUnavailable: false,
                files: [record],
                filesUnavailable: false,
                snippets: [],
                snippetsUnavailable: false,
                links: [],
                linksUnavailable: false,
                panelInputs: [],
                panelsUnavailable: false,
                workspaceNames: [:]
            )
        )
        model.selection = GlobalSearchResultID(source: .fileShelf, itemID: record.id)
        var calls = 0
        let view = GlobalSearchView(
            model: model,
            onActivate: { _ in XCTFail("render must not activate") },
            onRevealInSource: { _ in XCTFail("render must not reveal") },
            onPerformItemAction: { _, _ in XCTFail("render must not perform") },
            onItemActions: { _ in
                calls += 1
                return [.createPDFPanel]
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: GlanceConstants.globalSearchSize)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(model.selection?.itemID, record.id)
        XCTAssertEqual(model.query, "")
    }

    func testStaleEllipsisActionKeepsSearchAndDoesNotDismiss() {
        let snippet = snippetRecord()
        let model = GlobalSearchViewModel()
        model.applyImmediateSnapshot(
            GlobalSearchImmediateSnapshot(
                clipboard: [],
                clipboardUnavailable: false,
                files: [],
                filesUnavailable: false,
                snippets: [snippet],
                snippetsUnavailable: false,
                links: [],
                linksUnavailable: false,
                panelInputs: [],
                panelsUnavailable: false,
                workspaceNames: [:]
            )
        )
        model.query = "公司"
        model.selection = GlobalSearchResultID(source: .snippets, itemID: snippet.id)
        let items = GlobalSearchResultMenu.items { [.createTextPanel] }
        XCTAssertEqual(items, [.reveal, .divider, .action(.createTextPanel)])
        let outcome = GlanceActionOutcome.failed(GlanceNoticeCopy.staleItem)
        XCTAssertFalse(
            GlobalSearchItemActionSessionPolicy.shouldDismiss(
                after: .createTextPanel,
                outcome: outcome
            )
        )
        model.showNotice(GlanceNoticeCopy.staleItem)
        XCTAssertEqual(model.query, "公司")
        XCTAssertEqual(model.selection?.itemID, snippet.id)
        XCTAssertEqual(model.notice, GlanceNoticeCopy.staleItem)
    }

    func testMoreHelpUsesTitleContext() {
        XCTAssertEqual(
            GlobalSearchRowActionPresentation.moreHelp(title: "项目计划"),
            "“项目计划”的更多操作"
        )
        XCTAssertEqual(
            GlobalSearchRowActionPresentation.moreHelp(title: "  "),
            GlanceRowActionCopy.more
        )
    }

    private func assertSearchActions(
        resultID: GlobalSearchResultID,
        coordinator: GlanceActionCoordinator,
        itemActions: [GlanceItemAction]
    ) {
        let composed = GlobalSearchResultActions.compose(resultID: resultID) {
            coordinator.availableActions(for: $0)
        }
        XCTAssertTrue(composed.canReveal)
        XCTAssertEqual(composed.itemActions, itemActions)
    }

    private func coordinator(
        log: ActionCallLog,
        clipboard: ClipboardHistoryRecord? = nil,
        snippet: SnippetRecord? = nil,
        link: LinkRecord? = nil,
        file: FileShelfRecord? = nil,
        resolvedPath: String? = nil,
        fileMissing: Bool = false
    ) -> GlanceActionCoordinator {
        if let clipboard { log.clipboards[clipboard.id] = clipboard }
        if let snippet { log.snippets[snippet.id] = snippet }
        if let link { log.links[link.id] = link }
        if let file { log.files[file.id] = file }
        return GlanceActionCoordinator(
            dependencies: GlanceActionDependencies(
                createTextPanel: { _, _, _ in
                    log.createTextPanel += 1
                    return true
                },
                importImage: { _, _, _ in
                    log.importImage += 1
                    return true
                },
                importPDF: { _, _, _ in
                    log.importPDF += 1
                    return true
                },
                createFromClipboard: { _, _ in
                    log.createFromClipboard += 1
                    return true
                },
                snippet: { log.snippets[$0] },
                link: { log.links[$0] },
                fileRecord: { log.files[$0] },
                resolveFile: { _ in
                    log.resolveFile += 1
                    if fileMissing { return .missing }
                    guard let path = resolvedPath else { return .missing }
                    return FileShelfResolvedReference(
                        urlPath: path,
                        isMissing: false,
                        isStale: false,
                        bookmarkDataToRefresh: nil
                    )
                },
                clipboardRecord: { log.clipboards[$0] },
                clipboardContent: { id in
                    guard let record = log.clipboards[id] else { return nil }
                    if let text = record.text { return .text(text) }
                    return .png(Data([0x89]))
                },
                clipboardExists: { log.clipboards[$0] != nil },
                panelExists: { _ in false },
                presentClipboard: { _ in false },
                presentFileShelf: { _ in false },
                presentSnippets: { _ in false },
                presentLinks: { _ in false },
                presentPanelLibrary: { _ in false },
                presentSnippetEditor: { _ in log.presentSnippetEditor += 1 },
                presentLinkEditor: { url in
                    log.presentLinkEditor += 1
                    log.linkEditorURLs.append(url)
                },
                dismissClipboard: { log.dismissClipboard += 1 }
            )
        )
    }
}

@MainActor
private final class ActionCallLog {
    var createTextPanel = 0
    var importImage = 0
    var importPDF = 0
    var createFromClipboard = 0
    var presentSnippetEditor = 0
    var presentLinkEditor = 0
    var dismissClipboard = 0
    var resolveFile = 0
    var linkEditorURLs: [String] = []
    var clipboards: [UUID: ClipboardHistoryRecord] = [:]
    var snippets: [UUID: SnippetRecord] = [:]
    var links: [UUID: LinkRecord] = [:]
    var files: [UUID: FileShelfRecord] = [:]
}

private func clipboardText(_ text: String) -> ClipboardHistoryRecord {
    ClipboardHistoryRecord(
        id: UUID(),
        kind: .text,
        createdAt: Date(),
        lastCopiedAt: Date(),
        isFavorite: false,
        favoritedAt: nil,
        contentHash: ClipboardHistoryHasher.hash(text: text),
        text: text,
        assetPath: nil
    )
}

private func snippetRecord() -> SnippetRecord {
    SnippetRecord(
        id: UUID(),
        title: "公司简介",
        content: "body",
        createdAt: Date(),
        updatedAt: Date(),
        lastUsedAt: Date(),
        isPinned: false
    )
}

private func linkRecord() -> LinkRecord {
    LinkRecord(
        id: UUID(),
        title: "Glance",
        urlString: "https://example.com",
        createdAt: Date(),
        updatedAt: Date(),
        lastOpenedAt: Date(),
        isPinned: false
    )
}

private func fileRecord(name: String, path: String, type: String) -> FileShelfRecord {
    FileShelfRecord(
        id: UUID(),
        originalPath: path,
        displayName: name,
        fileSize: 12,
        contentTypeIdentifier: type,
        createdAt: Date(),
        lastUsedAt: Date(),
        isFavorite: false,
        favoritedAt: nil
    )
}
