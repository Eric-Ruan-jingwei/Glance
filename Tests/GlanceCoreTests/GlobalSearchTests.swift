import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class GlobalSearchProjectionTests: XCTestCase {
    func testClipboardTextUsesFirstLineTitleAndExactBodyFields() {
        let record = clipboardText("  标题行  \n第二行内容", copied: 10)
        let document = GlobalSearchSnapshotBuilder.document(from: record)
        XCTAssertEqual(document.source, .clipboard)
        XCTAssertEqual(document.title, "标题行")
        XCTAssertEqual(document.searchableTitle, "标题行")
        XCTAssertEqual(document.searchableFields, ["  标题行  \n第二行内容"])
        XCTAssertEqual(document.activityAt, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(document.rowSymbol, "list.clipboard")
        XCTAssertEqual(document.preview, GlobalSearchPreview.display("  标题行  \n第二行内容"))
        XCTAssertFalse(document.preview?.contains("\n") == true)
    }

    func testClipboardImageUsesMetadataOnly() {
        let record = clipboardImage(copied: 20)
        let document = GlobalSearchSnapshotBuilder.document(from: record)
        XCTAssertEqual(document.title, "剪贴板图片")
        XCTAssertEqual(document.searchableFields, ["图片"])
        XCTAssertEqual(document.rowSymbol, "photo")
        XCTAssertNil(document.preview)
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [document], query: "report").map(\.id),
            []
        )
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [document], query: "图片").map(\.id),
            [document.id]
        )
    }

    func testFileShelfSearchesNameExtensionAndPathWithoutFileBody() {
        let record = fileRecord(
            name: "Project Alpha.pdf",
            path: "/Users/me/Documents/项目/Project Alpha.pdf",
            used: 30
        )
        let document = GlobalSearchSnapshotBuilder.document(from: record)
        XCTAssertEqual(document.title, "Project Alpha.pdf")
        XCTAssertTrue(document.searchableFields.contains(record.originalPath))
        XCTAssertTrue(document.searchableFields.contains("pdf"))
        XCTAssertFalse(document.searchableFields.contains("PDF BODY"))
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [document], query: "Documents").map(\.title),
            ["Project Alpha.pdf"]
        )
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [document], query: "pdf").map(\.title),
            ["Project Alpha.pdf"]
        )
    }

    func testSnippetAndLinkProjection() {
        let snippet = snippetRecord(title: "公司简介", content: "Rethos 是一个……", used: 40, pinned: true)
        let link = linkRecord(title: "Glance GitHub", url: "https://github.com/Eric-Ruan-jingwei/Glance", opened: 50, pinned: true)
        let snippetDoc = GlobalSearchSnapshotBuilder.document(from: snippet)
        let linkDoc = GlobalSearchSnapshotBuilder.document(from: link)
        XCTAssertEqual(snippetDoc.searchableFields, ["Rethos 是一个……"])
        XCTAssertEqual(snippetDoc.preview, "Rethos 是一个……")
        XCTAssertEqual(linkDoc.searchableFields.contains("https://github.com/Eric-Ruan-jingwei/Glance"), true)
        XCTAssertEqual(linkDoc.subtitle, LinkPreview.line(from: link.urlString))
        XCTAssertEqual(snippetDoc.activityAt, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(linkDoc.activityAt, Date(timeIntervalSince1970: 50))
    }

    func testPanelSummaryProjectionIncludesWorkspaceKindTagsAndUnreadablePreview() {
        let readable = panelSummary(
            title: "今日任务",
            automatic: "买牛奶",
            custom: "今日任务",
            subtitle: "工作 · 待办",
            preview: "买牛奶\n第二项",
            tags: ["项目A"],
            workspaceID: "work",
            kind: PanelKind.todo,
            updated: 60
        )
        let unreadable = panelSummary(
            title: "损坏面板",
            automatic: "损坏面板",
            preview: "secret payload",
            workspaceID: "work",
            kind: PanelKind.text,
            updated: 61,
            unreadable: true
        )
        let readableDoc = GlobalSearchSnapshotBuilder.document(from: readable, workspaceName: "工作")
        let unreadableDoc = GlobalSearchSnapshotBuilder.document(from: unreadable, workspaceName: "工作")
        XCTAssertEqual(readableDoc.subtitle, "工作 · 待办")
        XCTAssertTrue(readableDoc.searchableFields.contains("今日任务"))
        XCTAssertTrue(readableDoc.searchableFields.contains("买牛奶"))
        XCTAssertTrue(readableDoc.searchableFields.contains("工作"))
        XCTAssertTrue(readableDoc.searchableFields.contains("待办"))
        XCTAssertTrue(readableDoc.searchableFields.contains("项目A"))
        XCTAssertEqual(unreadableDoc.preview, PanelSummaryFallback.unreadable)
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [readableDoc], query: "项目A").map(\.title),
            ["今日任务"]
        )
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [readableDoc], query: "工作").map(\.title),
            ["今日任务"]
        )
    }

    func testFutureSchemaDropsOnlyThatSource() {
        XCTAssertTrue(GlobalSearchSnapshotBuilder.linksUnavailable(.unsupportedFutureSchema(2)))
        XCTAssertFalse(GlobalSearchSnapshotBuilder.clipboardUnavailable(.loaded))
        let docs = GlobalSearchSnapshotBuilder.links(
            [linkRecord(title: "Hidden", url: "https://example.com", opened: 1)],
            unavailable: true
        )
        XCTAssertTrue(docs.isEmpty)
    }
}

final class GlobalSearchRankingTests: XCTestCase {
    func testEmptyQueryIsRecentActivityIgnoringPinsAndFavorites() {
        let favoriteOld = clipboardText("old favorite", copied: 1, favorite: true)
        let pinnedOld = snippetRecord(title: "old pin", content: "body", used: 2, pinned: true)
        let file = fileRecord(name: "mid.pdf", path: "/tmp/mid.pdf", used: 3)
        let link = linkRecord(title: "newer link", url: "https://example.com", opened: 4)
        let panel = panelSummary(title: "newest panel", updated: 5)
        let docs =
            GlobalSearchSnapshotBuilder.clipboard([favoriteOld], unavailable: false)
            + GlobalSearchSnapshotBuilder.snippets([pinnedOld], unavailable: false)
            + GlobalSearchSnapshotBuilder.fileShelf([file], unavailable: false)
            + GlobalSearchSnapshotBuilder.links([link], unavailable: false)
            + GlobalSearchSnapshotBuilder.panels([panel], workspaceName: { _ in "默认" })
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: docs, query: "  ").map(\.title),
            ["newest panel", "newer link", "mid.pdf", "old pin", "old favorite"]
        )
    }

    func testRecentLimitIsTwenty() {
        let docs = (0..<25).map { index in
            GlobalSearchSnapshotBuilder.document(
                from: clipboardText("item \(index)", copied: TimeInterval(index))
            )
        }
        XCTAssertEqual(GlobalSearchEngine.results(documents: docs, query: "").count, 20)
        XCTAssertEqual(GlobalSearchEngine.results(documents: docs, query: "").first?.title, "item 24")
    }

    func testRankingPrefersTitleExactPrefixSubstringThenSecondary() {
        let exact = named("glance", activity: 1, fields: ["other"])
        let prefix = named("glance-app", activity: 40, fields: ["other"])
        let titleContains = named("use glance now", activity: 30, fields: ["other"])
        let secondary = named("other", activity: 50, fields: ["mentions glance in body"])
        let ranked = GlobalSearchEngine.results(
            documents: [secondary, titleContains, prefix, exact],
            query: "glance"
        )
        XCTAssertEqual(ranked.map(\.title), ["glance", "glance-app", "use glance now", "other"])
    }

    func testSameScoreBreaksTiesByActivityThenSourceThenTitle() {
        let older = named("Alpha", activity: 1, source: .snippets)
        let newer = named("Alpha", activity: 2, source: .clipboard)
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [older, newer], query: "alpha").map(\.source),
            [.clipboard, .snippets]
        )
    }

    func testCaseAndDiacriticInsensitiveMatch() {
        let cafe = named("Café", activity: 1)
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [cafe], query: "cafe").map(\.title),
            ["Café"]
        )
        XCTAssertEqual(
            GlobalSearchEngine.results(documents: [cafe], query: "CAFÉ").map(\.title),
            ["Café"]
        )
    }

    func testSearchLimitIsFifty() {
        let docs = (0..<100).map { index in
            named("glance \(index)", activity: TimeInterval(index))
        }
        XCTAssertEqual(GlobalSearchEngine.results(documents: docs, query: "glance").count, 50)
    }

    func testKeyboardMapping() {
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 126), .moveSelection(-1))
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 125), .moveSelection(1))
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 36), .activate)
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 36, command: true), .revealInSource)
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 76, command: true), .revealInSource)
        XCTAssertEqual(GlobalSearchActionPolicy.action(keyCode: 53), .dismiss)
        XCTAssertNil(GlobalSearchActionPolicy.action(keyCode: 18))
        XCTAssertEqual(GlobalSearchCopy.revealHint, "⌘↩ 在来源中显示")
        XCTAssertEqual(GlobalSearchCopy.actHint, "↩ 执行")
    }
}

final class GlobalSearchActionTests: XCTestCase {
    func testClipboardAndSnippetCopyDeactivateWhilePanelDoesNot() {
        if case .run(_, let deactivate) = GlobalSearchActionPlanner.plan(source: .clipboard, globallyConcealed: false) {
            XCTAssertTrue(deactivate)
        } else {
            XCTFail("clipboard should run")
        }
        if case .run(_, let deactivate) = GlobalSearchActionPlanner.plan(source: .snippets, globallyConcealed: false) {
            XCTAssertTrue(deactivate)
        } else {
            XCTFail("snippets should run")
        }
        if case .run(_, let deactivate) = GlobalSearchActionPlanner.plan(source: .fileShelf, globallyConcealed: false) {
            XCTAssertFalse(deactivate)
        } else {
            XCTFail("file shelf should run")
        }
        if case .run(_, let deactivate) = GlobalSearchActionPlanner.plan(source: .links, globallyConcealed: false) {
            XCTAssertFalse(deactivate)
        } else {
            XCTFail("links should run")
        }
        if case .run(_, let deactivate) = GlobalSearchActionPlanner.plan(source: .panels, globallyConcealed: false) {
            XCTAssertFalse(deactivate)
        } else {
            XCTFail("panel should run")
        }
        XCTAssertEqual(
            GlobalSearchActionPlanner.plan(source: .panels, globallyConcealed: true),
            .fail(GlobalSearchCopy.globallyHidden)
        )
        XCTAssertEqual(
            GlobalSearchActionPlanner.plan(source: .links, globallyConcealed: false),
            .run(.openLink, deactivateApp: UtilityWindowHandoffPolicy.afterPrimarySearchAction(source: .links).shouldDeactivate)
        )
    }

    func testRouterLooksUpLiveRecordsAndSurvivesStaleIDs() {
        let missingSnippet = UUID()
        var copied: [UUID] = []
        let result = GlobalSearchActionRouter.perform(
            id: GlobalSearchResultID(source: .snippets, itemID: missingSnippet),
            globallyConcealed: false,
            using: probeDependencies(
                copySnippet: { id in
                    copied.append(id)
                    return false
                }
            )
        )
        XCTAssertEqual(result, .failed(GlobalSearchCopy.snippetMissing))
        XCTAssertEqual(copied, [missingSnippet])
    }

    func testFileMissingKeepsFailedNotice() {
        let id = UUID()
        let result = GlobalSearchActionRouter.perform(
            id: GlobalSearchResultID(source: .fileShelf, itemID: id),
            globallyConcealed: false,
            using: probeDependencies(openFile: { _ in false })
        )
        XCTAssertEqual(result, .failed(GlobalSearchCopy.fileMissing))
    }

    func testLinkOpenUsesAdapter() {
        let id = UUID()
        var opened: [UUID] = []
        let result = GlobalSearchActionRouter.perform(
            id: GlobalSearchResultID(source: .links, itemID: id),
            globallyConcealed: false,
            using: probeDependencies(openLink: { item in
                opened.append(item)
                return true
            })
        )
        XCTAssertEqual(result, .succeeded(deactivateApp: false))
        XCTAssertEqual(opened, [id])
    }

    func testPanelSwitchesWorkspaceThenRevealsAndDoesNotToggleHide() {
        let panelID = UUID()
        var switched: [String] = []
        var revealed: [UUID] = []
        let result = GlobalSearchActionRouter.perform(
            id: GlobalSearchResultID(source: .panels, itemID: panelID),
            globallyConcealed: false,
            using: probeDependencies(
                lookupPanel: { id in
                    id == panelID ? GlobalSearchPanelLookup(workspaceID: "project") : nil
                },
                activeWorkspaceID: { WorkspaceRecord.defaultID },
                switchWorkspace: { id in
                    switched.append(id)
                    return true
                },
                revealPanel: { id in
                    revealed.append(id)
                    return true
                }
            )
        )
        XCTAssertEqual(result, .succeeded(deactivateApp: false))
        XCTAssertEqual(switched, ["project"])
        XCTAssertEqual(revealed, [panelID])
    }

    func testPanelGlobalHideDoesNotReveal() {
        var revealed = 0
        let result = GlobalSearchActionRouter.perform(
            id: GlobalSearchResultID(source: .panels, itemID: UUID()),
            globallyConcealed: true,
            using: probeDependencies(revealPanel: { _ in
                revealed += 1
                return true
            })
        )
        XCTAssertEqual(result, .failed(GlobalSearchCopy.globallyHidden))
        XCTAssertEqual(revealed, 0)
    }
}

@MainActor
final class GlobalSearchClipboardAdoptTests: XCTestCase {
    func testClipboardRestoreAndSnippetCopyAdoptPattern() {
        let pasteboard = NSPasteboard.withUniqueName()
        let text = "exact snippet body"
        let written = MacClipboardWriter.write(.text(text), to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), text)
        var captured = 0
        let monitor = ClipboardHistoryMonitor(pasteboard: pasteboard, interval: 30, isEnabled: { true })
        monitor.onCapture = { _ in captured += 1 }
        monitor.start(baselineChangeCount: written)
        monitor.adopt(changeCount: written)
        monitor.tick()
        XCTAssertEqual(captured, 0)
    }
}

@MainActor
final class GlobalSearchViewModelTests: XCTestCase {
    func testSelectionIsKeptWhenStillPresentOtherwiseFirst() {
        let first = named("alpha", activity: 2)
        let second = named("alphabet", activity: 1)
        let model = GlobalSearchViewModel(summaryLoader: CountingSummaryLoader())
        model.immediateDocuments = [first, second]
        model.query = "alpha"
        model.selection = second.id
        model.reconcileSelection()
        XCTAssertEqual(model.selection, second.id)
        model.query = "alphabet"
        model.reconcileSelection()
        XCTAssertEqual(model.selection, second.id)
        model.query = "missing"
        model.reconcileSelection()
        XCTAssertNil(model.selection)
    }

    func testPartialSourceFailureStillReturnsOtherDocuments() {
        let model = GlobalSearchViewModel(summaryLoader: CountingSummaryLoader())
        model.applyImmediateSnapshot(
            GlobalSearchImmediateSnapshot(
                clipboard: [clipboardText("keep", copied: 2)],
                clipboardUnavailable: false,
                files: [fileRecord(name: "keep.pdf", path: "/tmp/keep.pdf", used: 3)],
                filesUnavailable: false,
                snippets: [snippetRecord(title: "keep snippet", content: "body", used: 4)],
                snippetsUnavailable: false,
                links: [linkRecord(title: "gone", url: "https://example.com", opened: 5)],
                linksUnavailable: true,
                panelInputs: [],
                panelsUnavailable: false,
                workspaceNames: [:]
            )
        )
        XCTAssertTrue(model.showsPartialUnavailable)
        XCTAssertEqual(Set(model.displayed.map(\.source)), [.clipboard, .fileShelf, .snippets])
        XCTAssertFalse(model.displayed.contains { $0.source == .links })
    }

    func testQueryChangesDoNotReloadPanelPayloads() async {
        let summary = panelSummary(title: "Panel A", updated: 1)
        let loader = CountingSummaryLoader(summaries: [summary])
        let model = GlobalSearchViewModel(summaryLoader: loader)
        model.applyImmediateSnapshot(snapshotWithPanelInput(id: summary.id))
        await waitUntil { !model.isLoadingPanels && !model.panelDocuments.isEmpty }
        XCTAssertEqual(loader.count, 1)
        model.query = "a"
        model.reconcileSelection()
        model.query = "ab"
        model.reconcileSelection()
        model.query = "abc"
        model.reconcileSelection()
        XCTAssertEqual(loader.count, 1)
    }

    func testStalePanelGenerationIsIgnored() async {
        let first = panelSummary(title: "Old Session", updated: 1)
        let second = panelSummary(title: "New Session", updated: 2)
        let startedFirst = LoadGate()
        let holdFirst = LoadGate()
        let startedSecond = LoadGate()
        let loader = ScriptedSummaryLoader(steps: [
            .init(delayNanoseconds: 0, summaries: [first], gate: holdFirst, started: startedFirst),
            .init(delayNanoseconds: 0, summaries: [second], gate: nil, started: startedSecond)
        ])
        let model = GlobalSearchViewModel(summaryLoader: loader)
        model.applyImmediateSnapshot(snapshotWithPanelInput(id: first.id))
        await startedFirst.wait()
        model.resetPresentation()
        model.applyImmediateSnapshot(snapshotWithPanelInput(id: second.id))
        await startedSecond.wait()
        await waitUntil { model.panelDocuments.first?.title == "New Session" }
        await holdFirst.open()
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(model.panelDocuments.map(\.title), ["New Session"])
    }

    func testSchemasStayUnchangedAndSearchHasNone() {
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(LinkDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(GlobalSearchPolicy.maximumRecentResults, 20)
        XCTAssertEqual(GlobalSearchPolicy.maximumSearchResults, 50)
        XCTAssertEqual(ShortcutAction.globalSearch.title, "搜索 Glance")
        XCTAssertEqual(ShortcutDefaults.globalSearch.key, "k")
        XCTAssertEqual(GlanceHotKeyID.globalSearch.rawValue, 8)
        XCTAssertEqual(GlanceConstants.globalSearchSize, NSSize(width: 640, height: 480))
    }

    func testMarkUnavailableFlagsFileShelfRow() throws {
        let id = UUID()
        let record = FileShelfRecord(
            id: id,
            originalPath: "/tmp/report.pdf",
            displayName: "report.pdf",
            fileSize: 1,
            contentTypeIdentifier: "pdf",
            createdAt: Date(timeIntervalSince1970: 1),
            lastUsedAt: Date(timeIntervalSince1970: 2),
            isFavorite: false,
            favoritedAt: nil
        )
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
        model.markUnavailable(GlobalSearchResultID(source: .fileShelf, itemID: id))
        let row = try XCTUnwrap(model.immediateDocuments.first)
        XCTAssertTrue(row.isUnavailable)
        XCTAssertEqual(row.preview, GlobalSearchCopy.fileMissingRow)
    }

    func testStressCorpusHonorsLimitsWithoutReloadingDocuments() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let clipboard = (0..<100).map { index in
            ClipboardHistoryRecord(
                id: UUID(),
                kind: .text,
                createdAt: start,
                lastCopiedAt: start.addingTimeInterval(TimeInterval(index)),
                isFavorite: false,
                favoritedAt: nil,
                contentHash: "c-\(index)",
                text: "clipboard \(index)",
                assetPath: nil
            )
        }
        let files = (0..<100).map { index in
            FileShelfRecord(
                id: UUID(),
                originalPath: "/tmp/file-\(index).txt",
                displayName: "file-\(index).txt",
                fileSize: 1,
                contentTypeIdentifier: "txt",
                createdAt: start,
                lastUsedAt: start.addingTimeInterval(TimeInterval(index)),
                isFavorite: false,
                favoritedAt: nil
            )
        }
        let snippets = (0..<500).map { index in
            SnippetRecord(
                id: UUID(),
                title: index == 17 ? "unique-token-xyz" : "snippet \(index)",
                content: "body \(index)",
                createdAt: start,
                updatedAt: start,
                lastUsedAt: start.addingTimeInterval(TimeInterval(index)),
                isPinned: false
            )
        }
        let links = (0..<500).map { index in
            LinkRecord(
                id: UUID(),
                title: "link \(index)",
                urlString: "https://example.com/\(index)",
                createdAt: start,
                updatedAt: start,
                lastOpenedAt: start.addingTimeInterval(TimeInterval(index)),
                isPinned: false
            )
        }
        let panels = (0..<100).map { index in
            panelSummary(title: "panel \(index)", updated: TimeInterval(index))
        }
        let documents =
            GlobalSearchSnapshotBuilder.clipboard(clipboard, unavailable: false)
            + GlobalSearchSnapshotBuilder.fileShelf(files, unavailable: false)
            + GlobalSearchSnapshotBuilder.snippets(snippets, unavailable: false)
            + GlobalSearchSnapshotBuilder.links(links, unavailable: false)
            + GlobalSearchSnapshotBuilder.panels(panels, workspaceName: { _ in "默认" })
        XCTAssertEqual(documents.count, 1300)
        let recent = GlobalSearchEngine.results(documents: documents, query: "")
        XCTAssertEqual(recent.count, GlobalSearchPolicy.maximumRecentResults)
        let hits = GlobalSearchEngine.results(documents: documents, query: "unique-token-xyz")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.title, "unique-token-xyz")
        let crowded = GlobalSearchEngine.results(documents: documents, query: "snippet")
        XCTAssertEqual(crowded.count, GlobalSearchPolicy.maximumSearchResults)
        XCTAssertTrue(documents.allSatisfy { $0.foldedFields.count == $0.searchableFields.count })
    }
}

private final class CountingSummaryLoader: PanelSummaryLoading, @unchecked Sendable {
    private(set) var count = 0
    var summaries: [PanelSummary]

    init(summaries: [PanelSummary] = []) {
        self.summaries = summaries
    }

    func loadSummaries(inputs: [PanelSummaryInput]) async -> [PanelSummary] {
        count += 1
        return summaries
    }
}

private func waitUntil(_ condition: @escaping () -> Bool) async {
    for _ in 0..<80 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 25_000_000)
    }
}

private func named(
    _ title: String,
    activity: TimeInterval,
    fields: [String] = [],
    source: GlobalSearchSource = .snippets
) -> GlobalSearchDocument {
    GlobalSearchDocument(
        id: GlobalSearchResultID(source: source, itemID: UUID()),
        source: source,
        title: title,
        searchableTitle: title,
        searchableFields: fields,
        activityAt: Date(timeIntervalSince1970: activity)
    )
}

private func clipboardText(_ text: String, copied: TimeInterval, favorite: Bool = false) -> ClipboardHistoryRecord {
    ClipboardHistoryRecord(
        id: UUID(),
        kind: .text,
        createdAt: Date(timeIntervalSince1970: copied),
        lastCopiedAt: Date(timeIntervalSince1970: copied),
        isFavorite: favorite,
        favoritedAt: favorite ? Date(timeIntervalSince1970: copied) : nil,
        contentHash: text,
        text: text,
        assetPath: nil
    )
}

private func clipboardImage(copied: TimeInterval) -> ClipboardHistoryRecord {
    ClipboardHistoryRecord(
        id: UUID(),
        kind: .image,
        createdAt: Date(timeIntervalSince1970: copied),
        lastCopiedAt: Date(timeIntervalSince1970: copied),
        isFavorite: false,
        favoritedAt: nil,
        contentHash: "image",
        text: nil,
        assetPath: "Assets/x.png"
    )
}

private func fileRecord(name: String, path: String, used: TimeInterval) -> FileShelfRecord {
    FileShelfRecord(
        id: UUID(),
        originalPath: path,
        displayName: name,
        fileSize: 12,
        contentTypeIdentifier: "com.adobe.pdf",
        createdAt: Date(timeIntervalSince1970: used),
        lastUsedAt: Date(timeIntervalSince1970: used),
        isFavorite: false,
        favoritedAt: nil
    )
}

private func snippetRecord(title: String, content: String, used: TimeInterval, pinned: Bool = false) -> SnippetRecord {
    SnippetRecord(
        id: UUID(),
        title: title,
        content: content,
        createdAt: Date(timeIntervalSince1970: used),
        updatedAt: Date(timeIntervalSince1970: used),
        lastUsedAt: Date(timeIntervalSince1970: used),
        isPinned: pinned
    )
}

private func linkRecord(title: String, url: String, opened: TimeInterval, pinned: Bool = false) -> LinkRecord {
    LinkRecord(
        id: UUID(),
        title: title,
        urlString: url,
        createdAt: Date(timeIntervalSince1970: opened),
        updatedAt: Date(timeIntervalSince1970: opened),
        lastOpenedAt: Date(timeIntervalSince1970: opened),
        isPinned: pinned
    )
}

private func panelSummary(
    title: String,
    automatic: String? = nil,
    custom: String? = nil,
    subtitle: String? = nil,
    preview: String = "",
    tags: [String] = [],
    workspaceID: String = WorkspaceRecord.defaultID,
    kind: String = PanelKind.text,
    updated: TimeInterval,
    unreadable: Bool = false
) -> PanelSummary {
    PanelSummary(
        id: UUID(),
        kindIdentifier: kind,
        title: title,
        subtitle: subtitle,
        preview: preview,
        createdAt: Date(timeIntervalSince1970: updated),
        updatedAt: Date(timeIntervalSince1970: updated),
        isLocked: false,
        isPassThrough: false,
        isPinned: false,
        isHidden: false,
        workspaceID: workspaceID,
        automaticTitle: automatic ?? title,
        customTitle: custom,
        tags: tags,
        isUnreadable: unreadable
    )
}

private func snapshotWithPanelInput(id: UUID) -> GlobalSearchImmediateSnapshot {
    GlobalSearchImmediateSnapshot(
        clipboard: [],
        clipboardUnavailable: false,
        files: [],
        filesUnavailable: false,
        snippets: [],
        snippetsUnavailable: false,
        links: [],
        linksUnavailable: false,
        panelInputs: [
            PanelSummaryInput(
                id: id,
                kindIdentifier: PanelKind.text,
                customTitle: nil,
                workspaceID: WorkspaceRecord.defaultID,
                tags: [],
                createdAt: Date(),
                updatedAt: Date(),
                isLocked: false,
                isPassThrough: false,
                isPinned: false,
                isHidden: false,
                payloadDirectory: URL(fileURLWithPath: "/tmp")
            )
        ],
        panelsUnavailable: false,
        workspaceNames: [WorkspaceRecord.defaultID: WorkspaceRecord.defaultName]
    )
}

private func probeDependencies(
    restoreClipboard: @escaping (UUID) -> Bool = { _ in false },
    openFile: @escaping (UUID) -> Bool = { _ in false },
    copySnippet: @escaping (UUID) -> Bool = { _ in false },
    openLink: @escaping (UUID) -> Bool = { _ in false },
    lookupPanel: @escaping (UUID) -> GlobalSearchPanelLookup? = { _ in nil },
    activeWorkspaceID: @escaping () -> String = { WorkspaceRecord.defaultID },
    switchWorkspace: @escaping (String) -> Bool = { _ in false },
    revealPanel: @escaping (UUID) -> Bool = { _ in false }
) -> GlobalSearchActionDependencies {
    GlobalSearchActionDependencies(
        restoreClipboard: restoreClipboard,
        openFile: openFile,
        copySnippet: copySnippet,
        openLink: openLink,
        lookupPanel: lookupPanel,
        activeWorkspaceID: activeWorkspaceID,
        switchWorkspace: switchWorkspace,
        revealPanel: revealPanel
    )
}
