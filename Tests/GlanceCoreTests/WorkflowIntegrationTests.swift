import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class WorkflowIntegrationTests: XCTestCase {
    func testSchemasStayUnchangedAndSearchHasNone() {
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(LinkDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(GlobalSearchPolicy.maximumRecentResults, 20)
    }

    func testSnippetToPanelKeepsExactContentAndLeavesSnippetUntouched() throws {
        let harness = try SnippetFlowHarness()
        defer { harness.cleanup() }
        let content = "  hello\n\nworld\t "
        let created = try harness.create(title: "公司简介", content: content, at: Date(timeIntervalSince1970: 40))
        let before = created
        var createdPanels: [(String?, String)] = []
        let coordinator = GlanceActionCoordinator(
            dependencies: probeDependencies(
                createTextPanel: { title, body, _ in
                    createdPanels.append((title, body))
                    return true
                },
                snippet: { id in harness.service.records.first { $0.id == id } }
            )
        )
        XCTAssertEqual(
            coordinator.createPanel(from: created, screen: nil),
            .succeeded
        )
        XCTAssertEqual(createdPanels.count, 1)
        XCTAssertEqual(createdPanels[0].0, "公司简介")
        XCTAssertEqual(createdPanels[0].1, content)
        XCTAssertEqual(SnippetPanelHandoff.request(from: created).kindIdentifier, PanelKind.text)
        XCTAssertEqual(harness.service.records, [before])
        XCTAssertEqual(harness.service.records.first?.lastUsedAt, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(harness.service.records.first?.title, "公司简介")
        XCTAssertEqual(harness.service.records.first?.content, content)
    }

    func testSnippetToPanelWritesExactPayloadAndCustomTitle() throws {
        let content = "  hello\n\nworld\t "
        let request = SnippetPanelHandoff.request(
            from: SnippetRecord(
                id: UUID(),
                title: "公司简介",
                content: content,
                createdAt: Date(),
                updatedAt: Date(),
                lastUsedAt: Date(),
                isPinned: false
            )
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippetPanel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PayloadStore(applicationSupportRoot: root)
        let repository = try PanelRepository(fileURL: store.metadataURL)
        let id = UUID()
        let record = GlanceTestFixtures.sampleRecord(id: id)
        record.kindIdentifier = PanelKind.text
        record.customTitle = request.customTitle
        try PanelCreationSession.materialize(
            id: id,
            store: store,
            writePayload: { directory in
                try PanelInitialPayloadWriter.write(.plainText(request.content), to: directory)
            },
            insert: {
                try repository.insert(record)
            }
        )
        let stored = try XCTUnwrap(repository.record(id: id))
        XCTAssertEqual(stored.kindIdentifier, PanelKind.text)
        XCTAssertEqual(stored.customTitle, "公司简介")
        let directory = store.panelsRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        XCTAssertEqual(try TextPayloadFile.readAttributedString(from: directory)?.string, content)
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
    }

    func testSnippetToPanelFailureLeavesSnippetUnchanged() throws {
        let harness = try SnippetFlowHarness()
        defer { harness.cleanup() }
        let created = try harness.create(
            title: "公司简介",
            content: "keep me",
            at: Date(timeIntervalSince1970: 11)
        )
        let before = created
        let coordinator = GlanceActionCoordinator(
            dependencies: probeDependencies(
                createTextPanel: { _, _, _ in false },
                snippet: { id in harness.service.records.first { $0.id == id } }
            )
        )
        XCTAssertEqual(
            coordinator.createPanel(from: created, screen: nil),
            .failed(GlanceNoticeCopy.panelCreateFailed)
        )
        XCTAssertEqual(harness.service.records, [before])
    }

    func testLinkToPanelUsesExactURLAndDoesNotMarkOpened() throws {
        let harness = try LinkFlowHarness()
        defer { harness.cleanup() }
        let url = "https://example.com/a?x=1#section"
        let created = try harness.create(
            title: "Glance",
            urlString: url,
            at: Date(timeIntervalSince1970: 20)
        )
        let beforeOpened = created.lastOpenedAt
        var createdPanels: [(String?, String)] = []
        let coordinator = GlanceActionCoordinator(
            dependencies: probeDependencies(
                createTextPanel: { title, body, _ in
                    createdPanels.append((title, body))
                    return true
                },
                link: { id in harness.service.records.first { $0.id == id } }
            )
        )
        XCTAssertEqual(coordinator.createPanel(from: created, screen: nil), .succeeded)
        XCTAssertEqual(createdPanels.count, 1)
        XCTAssertEqual(createdPanels[0].0, "Glance")
        XCTAssertEqual(createdPanels[0].1, url)
        XCTAssertEqual(harness.service.records.first?.lastOpenedAt, beforeOpened)
        XCTAssertEqual(harness.service.records.first?.urlString, url)
        XCTAssertEqual(harness.service.records.first?.title, "Glance")
    }

    func testFileShelfImageAndPDFCreatePanelCopyIndependently() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFilePanel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageSource = root.appendingPathComponent("photo.png")
        try GlanceTestPNG.data(width: 32, height: 24).write(to: imageSource)
        let image = try XCTUnwrap(MediaStore().image(fromFileURL: imageSource))
        let png = try XCTUnwrap(MediaStore.pngData(from: image))
        let imagePanel = root.appendingPathComponent("image-panel", isDirectory: true)
        try FileManager.default.createDirectory(at: imagePanel, withIntermediateDirectories: true)
        try PanelInitialPayloadWriter.write(.imagePNG(png), to: imagePanel)
        try FileManager.default.removeItem(at: imageSource)
        let copiedImage = imagePanel.appendingPathComponent("image.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedImage.path))
        XCTAssertTrue(MediaStore.looksLikePNG(try Data(contentsOf: copiedImage)))

        let pdfSource = root.appendingPathComponent("brief.pdf")
        try GlanceTestPDF.data(pageCount: 2).write(to: pdfSource)
        let metadata = try PDFDocumentInspector.inspect(pdfSource)
        let pdfPanel = root.appendingPathComponent("pdf-panel", isDirectory: true)
        try FileManager.default.createDirectory(at: pdfPanel, withIntermediateDirectories: true)
        try PDFPayloadFile.importDocument(from: pdfSource, metadata: metadata, to: pdfPanel)
        try FileManager.default.removeItem(at: pdfSource)
        XCTAssertTrue(FileManager.default.fileExists(atPath: PDFPayloadFile.documentURL(in: pdfPanel).path))
        XCTAssertEqual(try PDFPayloadFile.readMetadata(from: pdfPanel)?.pageCount, 2)
    }

    func testFileShelfCreatePanelUsesExistingImportAndDoesNotTouchShelf() {
        let imageID = UUID()
        let pdfID = UUID()
        let used = Date(timeIntervalSince1970: 50)
        let imageRecord = fileRecord(
            id: imageID,
            name: "shot.png",
            path: "/tmp/shot.png",
            type: "png",
            used: used,
            favorite: true
        )
        let pdfRecord = fileRecord(
            id: pdfID,
            name: "spec.pdf",
            path: "/tmp/spec.pdf",
            type: "com.adobe.pdf",
            used: used,
            favorite: false
        )
        var importedImages: [URL] = []
        var importedPDFs: [URL] = []
        let coordinator = GlanceActionCoordinator(
            dependencies: probeDependencies(
                importImage: { url, title, _ in
                    importedImages.append(url)
                    XCTAssertEqual(title, "shot.png")
                    return true
                },
                importPDF: { url, title, _ in
                    importedPDFs.append(url)
                    XCTAssertEqual(title, "spec.pdf")
                    return true
                },
                fileRecord: { id in
                    [imageRecord, pdfRecord].first { $0.id == id }
                },
                resolveFile: { id in
                    let record = [imageRecord, pdfRecord].first { $0.id == id }!
                    return FileShelfResolvedReference(
                        urlPath: record.originalPath,
                        isMissing: false,
                        isStale: false,
                        bookmarkDataToRefresh: nil
                    )
                }
            )
        )
        XCTAssertEqual(coordinator.createPanel(fromFileShelfID: imageID, screen: nil), .succeeded)
        XCTAssertEqual(coordinator.createPanel(fromFileShelfID: pdfID, screen: nil), .succeeded)
        XCTAssertEqual(importedImages, [URL(fileURLWithPath: "/tmp/shot.png")])
        XCTAssertEqual(importedPDFs, [URL(fileURLWithPath: "/tmp/spec.pdf")])
        XCTAssertEqual(imageRecord.lastUsedAt, used)
        XCTAssertTrue(imageRecord.isFavorite)
        XCTAssertEqual(pdfRecord.lastUsedAt, used)
    }

    func testUnsupportedFileDoesNotOfferCreatePanel() {
        let zip = fileRecord(
            id: UUID(),
            name: "archive.zip",
            path: "/tmp/archive.zip",
            type: "zip",
            used: Date()
        )
        let text = fileRecord(
            id: UUID(),
            name: "notes.txt",
            path: "/tmp/notes.txt",
            type: "txt",
            used: Date()
        )
        XCTAssertNil(FileShelfPanelSupport.kind(for: zip))
        XCTAssertNil(FileShelfPanelSupport.kind(for: text))
        XCTAssertFalse(FileShelfPanelSupport.isAvailable(for: zip, missing: false))
        XCTAssertEqual(FileShelfPanelSupport.kind(for: fileRecord(
            id: UUID(),
            name: "photo.heic",
            path: "/tmp/photo.heic",
            type: "public.heic",
            used: Date()
        )), .image)
        XCTAssertEqual(FileShelfPanelSupport.kind(for: fileRecord(
            id: UUID(),
            name: "deck.pdf",
            path: "/tmp/deck.pdf",
            type: "pdf",
            used: Date()
        )), .pdf)
        XCTAssertFalse(FileShelfPanelSupport.isAvailable(for: zip, missing: true))
    }

    func testSourceRevealSelectsFiveDomainsAndClearsQuery() {
        let snippetID = UUID()
        let linkID = UUID()
        let fileID = UUID()
        let clipboardID = UUID()
        let panelID = UUID()
        var presented: [String] = []
        let coordinator = GlanceActionCoordinator(
            dependencies: probeDependencies(
                snippet: { id in id == snippetID ? snippetRecord(id: snippetID) : nil },
                link: { id in id == linkID ? linkRecord(id: linkID) : nil },
                fileRecord: { id in id == fileID ? fileRecord(id: fileID, name: "gone.pdf", path: "/missing.pdf", type: "pdf", used: Date()) : nil },
                clipboardExists: { $0 == clipboardID },
                panelExists: { $0 == panelID },
                presentClipboard: { id in
                    presented.append("clipboard:\(id)")
                    return true
                },
                presentFileShelf: { id in
                    presented.append("file:\(id)")
                    return true
                },
                presentSnippets: { id in
                    presented.append("snippet:\(id)")
                    return true
                },
                presentLinks: { id in
                    presented.append("link:\(id)")
                    return true
                },
                presentPanelLibrary: { id in
                    presented.append("panel:\(id)")
                    return true
                }
            )
        )
        XCTAssertEqual(
            coordinator.revealInSource(GlobalSearchResultID(source: .clipboard, itemID: clipboardID)),
            .succeeded
        )
        XCTAssertEqual(
            coordinator.revealInSource(GlobalSearchResultID(source: .fileShelf, itemID: fileID)),
            .succeeded
        )
        XCTAssertEqual(
            coordinator.revealInSource(GlobalSearchResultID(source: .snippets, itemID: snippetID)),
            .succeeded
        )
        XCTAssertEqual(
            coordinator.revealInSource(GlobalSearchResultID(source: .links, itemID: linkID)),
            .succeeded
        )
        XCTAssertEqual(
            coordinator.revealInSource(GlobalSearchResultID(source: .panels, itemID: panelID)),
            .succeeded
        )
        XCTAssertEqual(
            presented,
            [
                "clipboard:\(clipboardID)",
                "file:\(fileID)",
                "snippet:\(snippetID)",
                "link:\(linkID)",
                "panel:\(panelID)"
            ]
        )
        XCTAssertEqual(
            GlobalSearchActionPlanner.plan(source: .panels, globallyConcealed: false),
            .run(.revealPanel, deactivateApp: false)
        )
        XCTAssertNotEqual(
            GlobalSearchActionPolicy.action(keyCode: 36),
            GlobalSearchActionPolicy.action(keyCode: 36, command: true)
        )
    }

    func testStaleRevealKeepsSearchAndDoesNotPresent() {
        var presented = 0
        let coordinator = GlanceActionCoordinator(
            dependencies: probeDependencies(
                presentSnippets: { _ in
                    presented += 1
                    return true
                }
            )
        )
        XCTAssertEqual(
            coordinator.revealInSource(GlobalSearchResultID(source: .snippets, itemID: UUID())),
            .failed(GlanceNoticeCopy.staleItem)
        )
        XCTAssertEqual(presented, 0)
    }

    func testMissingFileStillRevealsInFileShelf() {
        let id = UUID()
        var presented: UUID?
        let coordinator = GlanceActionCoordinator(
            dependencies: probeDependencies(
                fileRecord: { item in
                    item == id
                        ? fileRecord(id: id, name: "old.pdf", path: "/moved/old.pdf", type: "pdf", used: Date())
                        : nil
                },
                resolveFile: { _ in .missing },
                presentFileShelf: { item in
                    presented = item
                    return true
                }
            )
        )
        XCTAssertEqual(
            coordinator.revealInSource(GlobalSearchResultID(source: .fileShelf, itemID: id)),
            .succeeded
        )
        XCTAssertEqual(presented, id)
        XCTAssertEqual(
            coordinator.createPanel(fromFileShelfID: id, screen: nil),
            .failed(GlanceNoticeCopy.fileMissing)
        )
    }

    func testLibrarySelectForRevealClearsQuery() throws {
        let snippetHarness = try SnippetFlowHarness()
        defer { snippetHarness.cleanup() }
        let first = try snippetHarness.create(title: "Alpha", content: "one", at: Date(timeIntervalSince1970: 1))
        let target = try snippetHarness.create(title: "Project Alpha", content: "two", at: Date(timeIntervalSince1970: 2))
        let model = SnippetLibraryViewModel(service: snippetHarness.service)
        model.query = "zzz"
        model.selection = first.id
        XCTAssertTrue(model.selectForReveal(target.id))
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.selection, target.id)

        let linkHarness = try LinkFlowHarness()
        defer { linkHarness.cleanup() }
        let keep = try linkHarness.create(title: "Keep", urlString: "https://example.com/keep", at: Date())
        let wanted = try linkHarness.create(title: "Wanted", urlString: "https://example.com/wanted", at: Date())
        let links = LinkLibraryViewModel(service: linkHarness.service)
        links.query = "nope"
        links.selection = keep.id
        XCTAssertTrue(links.selectForReveal(wanted.id))
        XCTAssertEqual(links.query, "")
        XCTAssertEqual(links.selection, wanted.id)
    }

    func testClipboardAndFileShelfSelectForRevealUseRecent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboardReveal-\(UUID().uuidString)", isDirectory: true)
        let defaultsName = "GlanceClipboardReveal-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let service = ClipboardHistoryService(
            store: ClipboardHistoryStore(root: root),
            preferences: ClipboardHistoryPreferenceStore(defaults: defaults)
        )
        let older = try XCTUnwrap(service.record(.text("older"), at: Date(timeIntervalSince1970: 1)))
        let favorite = try XCTUnwrap(service.record(.text("favorite"), at: Date(timeIntervalSince1970: 2)))
        service.toggleFavorite(id: favorite.id)
        let model = ClipboardHistoryViewModel(service: service)
        model.tab = .favorites
        model.query = "zzz"
        XCTAssertTrue(model.selectForReveal(older.id))
        XCTAssertEqual(model.tab, .recent)
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.selection, older.id)
        XCTAssertTrue(model.selectForReveal(favorite.id))
        XCTAssertEqual(model.selection, favorite.id)
    }

    func testPanelLibraryRevealSelectsOtherWorkspaceWithoutSwitchingActive() {
        let target = UUID()
        var switched: [String] = []
        let model = PanelLibraryModel()
        model.loadActiveWorkspaceID = { WorkspaceRecord.defaultID }
        model.switchWorkspace = { id in switched.append(id) }
        model.summaries = [
            panelSummary(id: UUID(), workspaceID: WorkspaceRecord.defaultID),
            panelSummary(id: target, workspaceID: "project")
        ]
        XCTAssertTrue(model.selectForReveal(target))
        XCTAssertEqual(model.selectedWorkspaceID, "project")
        XCTAssertEqual(model.selectedPanelIDs, [target])
        XCTAssertEqual(model.pendingScrollID, target)
        XCTAssertEqual(model.query, "")
        XCTAssertTrue(switched.isEmpty)
    }

    func testUtilityWindowToggleBringsForwardWhenVisibleButNotKey() {
        XCTAssertEqual(
            UtilityWindowPresentation.toggleAction(isVisible: false, isKey: false),
            .present
        )
        XCTAssertEqual(
            UtilityWindowPresentation.toggleAction(isVisible: true, isKey: true),
            .dismiss
        )
        XCTAssertEqual(
            UtilityWindowPresentation.toggleAction(isVisible: true, isKey: false),
            .bringForward
        )
    }

    func testFileShelfPathCopyAdoptsClipboardMonitor() {
        let pasteboard = NSPasteboard.withUniqueName()
        let monitor = ClipboardHistoryMonitor(pasteboard: pasteboard, interval: 30, isEnabled: { true })
        var captured = 0
        monitor.onCapture = { _ in captured += 1 }
        monitor.start(baselineChangeCount: pasteboard.changeCount)
        let writer = GlanceClipboardWriter(monitor: monitor, pasteboard: pasteboard)
        XCTAssertTrue(writer.write(.text("/tmp/report.pdf")))
        monitor.tick()
        XCTAssertEqual(captured, 0)
        XCTAssertEqual(pasteboard.string(forType: .string), "/tmp/report.pdf")
        writer.adoptCurrent()
        pasteboard.clearContents()
        pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/report.pdf") as NSURL])
        writer.adoptCurrent()
        monitor.tick()
        XCTAssertEqual(captured, 0)
        monitor.stop()
    }

    func testWindowHandoffDoesNotDeactivateWhenOpeningGlanceSource() {
        XCTAssertTrue(UtilityWindowHandoffPolicy.afterCopy().shouldDeactivate)
        XCTAssertFalse(UtilityWindowHandoffPolicy.afterRevealInSource().shouldDeactivate)
        XCTAssertFalse(UtilityWindowHandoffPolicy.afterCreatePanel().shouldDeactivate)
        XCTAssertFalse(UtilityWindowHandoffPolicy.afterPrimarySearchAction(source: .panels).shouldDeactivate)
        XCTAssertTrue(UtilityWindowHandoffPolicy.afterPrimarySearchAction(source: .snippets).shouldDeactivate)
        XCTAssertFalse(UtilityWindowHandoffPolicy.afterPrimarySearchAction(source: .links).shouldDeactivate)
    }

    func testClipboardWriterAdoptsOnlyAfterSuccessfulWrite() {
        let pasteboard = NSPasteboard.withUniqueName()
        let monitor = ClipboardHistoryMonitor(pasteboard: pasteboard, interval: 30, isEnabled: { true })
        var captured = 0
        monitor.onCapture = { _ in captured += 1 }
        monitor.start(baselineChangeCount: pasteboard.changeCount)

        let success = GlanceClipboardWriter(monitor: monitor, pasteboard: pasteboard)
        XCTAssertTrue(success.write(.text("owned")))
        monitor.tick()
        XCTAssertEqual(captured, 0)
        XCTAssertEqual(monitor.adoptedChangeCount, pasteboard.changeCount)

        var adopted = 0
        let failingMonitor = ClipboardHistoryMonitor(pasteboard: pasteboard, interval: 30, isEnabled: { true })
        failingMonitor.start(baselineChangeCount: pasteboard.changeCount)
        let baseline = failingMonitor.adoptedChangeCount
        let failing = GlanceClipboardWriter(
            monitor: failingMonitor,
            pasteboard: pasteboard,
            performWrite: { _, _ in
                adopted += 1
                return nil
            }
        )
        XCTAssertFalse(failing.write(.text("nope")))
        XCTAssertEqual(adopted, 1)
        XCTAssertEqual(failingMonitor.adoptedChangeCount, baseline)
    }
}

@MainActor
private func probeDependencies(
    createTextPanel: @escaping (String?, String, NSScreen?) -> Bool = { _, _, _ in false },
    importImage: @escaping (URL, String?, NSScreen?) -> Bool = { _, _, _ in false },
    importPDF: @escaping (URL, String?, NSScreen?) -> Bool = { _, _, _ in false },
    createFromClipboard: @escaping (ClipboardCaptureContent, NSScreen?) -> Bool = { _, _ in false },
    snippet: @escaping (UUID) -> SnippetRecord? = { _ in nil },
    link: @escaping (UUID) -> LinkRecord? = { _ in nil },
    fileRecord: @escaping (UUID) -> FileShelfRecord? = { _ in nil },
    resolveFile: @escaping (UUID) -> FileShelfResolvedReference = { _ in .missing },
    clipboardRecord: @escaping (UUID) -> ClipboardHistoryRecord? = { _ in nil },
    clipboardContent: @escaping (UUID) -> ClipboardCaptureContent? = { _ in nil },
    clipboardExists: @escaping (UUID) -> Bool = { _ in false },
    panelExists: @escaping (UUID) -> Bool = { _ in false },
    presentClipboard: @escaping (UUID) -> Bool = { _ in false },
    presentFileShelf: @escaping (UUID) -> Bool = { _ in false },
    presentSnippets: @escaping (UUID) -> Bool = { _ in false },
    presentLinks: @escaping (UUID) -> Bool = { _ in false },
    presentPanelLibrary: @escaping (UUID) -> Bool = { _ in false },
    presentSnippetEditor: @escaping (String) -> Void = { _ in },
    presentLinkEditor: @escaping (String) -> Void = { _ in },
    dismissClipboard: @escaping () -> Void = {}
) -> GlanceActionDependencies {
    GlanceActionDependencies(
        createTextPanel: createTextPanel,
        importImage: importImage,
        importPDF: importPDF,
        createFromClipboard: createFromClipboard,
        snippet: snippet,
        link: link,
        fileRecord: fileRecord,
        resolveFile: resolveFile,
        clipboardRecord: clipboardRecord,
        clipboardContent: clipboardContent,
        clipboardExists: clipboardExists,
        panelExists: panelExists,
        presentClipboard: presentClipboard,
        presentFileShelf: presentFileShelf,
        presentSnippets: presentSnippets,
        presentLinks: presentLinks,
        presentPanelLibrary: presentPanelLibrary,
        presentSnippetEditor: presentSnippetEditor,
        presentLinkEditor: presentLinkEditor,
        dismissClipboard: dismissClipboard
    )
}

@MainActor
private final class SnippetFlowHarness {
    let root: URL
    let service: SnippetService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippetFlow-\(UUID().uuidString)", isDirectory: true)
        service = SnippetService(store: SnippetStore(root: root.appendingPathComponent("Snippets", isDirectory: true)))
    }

    func create(title: String, content: String, at date: Date) throws -> SnippetRecord {
        switch service.create(SnippetDraft(title: title, content: content), at: date) {
        case .success(let record):
            return record
        case .failure(let error):
            XCTFail("unexpected \(error)")
            throw error
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

@MainActor
private final class LinkFlowHarness {
    let root: URL
    let service: LinkService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinkFlow-\(UUID().uuidString)", isDirectory: true)
        service = LinkService(store: LinkStore(root: root.appendingPathComponent("Links", isDirectory: true)))
    }

    func create(title: String, urlString: String, at date: Date) throws -> LinkRecord {
        switch service.create(LinkDraft(title: title, urlString: urlString), at: date) {
        case .success(let record):
            return record
        case .failure(let error):
            XCTFail("unexpected \(error)")
            throw error
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func fileRecord(
    id: UUID,
    name: String,
    path: String,
    type: String,
    used: Date,
    favorite: Bool = false
) -> FileShelfRecord {
    FileShelfRecord(
        id: id,
        originalPath: path,
        displayName: name,
        fileSize: 12,
        contentTypeIdentifier: type,
        createdAt: used,
        lastUsedAt: used,
        isFavorite: favorite,
        favoritedAt: favorite ? used : nil
    )
}

private func snippetRecord(id: UUID) -> SnippetRecord {
    SnippetRecord(
        id: id,
        title: "Project Alpha",
        content: "body",
        createdAt: Date(),
        updatedAt: Date(),
        lastUsedAt: Date(),
        isPinned: false
    )
}

private func linkRecord(id: UUID) -> LinkRecord {
    LinkRecord(
        id: id,
        title: "Glance",
        urlString: "https://example.com",
        createdAt: Date(),
        updatedAt: Date(),
        lastOpenedAt: Date(),
        isPinned: false
    )
}

private func panelSummary(id: UUID, workspaceID: String) -> PanelSummary {
    PanelSummary(
        id: id,
        kindIdentifier: PanelKind.text,
        title: "Target",
        subtitle: "文字",
        preview: "body",
        createdAt: Date(),
        updatedAt: Date(),
        isLocked: false,
        isPassThrough: false,
        isPinned: false,
        isHidden: false,
        workspaceID: workspaceID,
        automaticTitle: "Target",
        customTitle: "Target",
        tags: [],
        isUnreadable: false
    )
}
