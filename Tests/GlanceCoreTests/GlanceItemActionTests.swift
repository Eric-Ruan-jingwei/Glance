import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class GlanceItemActionTests: XCTestCase {
    func testIdentifiersAreStableAndRoundTripIndependentlyOfTitle() {
        for action in GlanceItemAction.allCases {
            XCTAssertEqual(GlanceItemAction(identifier: action.identifier), action)
            XCTAssertNotEqual(action.identifier, action.title)
        }
        XCTAssertEqual(GlanceItemAction.createTextPanel.identifier, "createTextPanel")
        XCTAssertEqual(GlanceItemAction.createTodoPanel.identifier, "createTodoPanel")
        XCTAssertEqual(GlanceItemAction.createImagePanel.identifier, "createImagePanel")
        XCTAssertEqual(GlanceItemAction.createPDFPanel.identifier, "createPDFPanel")
        XCTAssertEqual(GlanceItemAction.saveAsSnippet.identifier, "saveAsSnippet")
        XCTAssertEqual(GlanceItemAction.saveAsLink.identifier, "saveAsLink")
        XCTAssertNil(GlanceItemAction(identifier: "创建文字面板"))
        XCTAssertNil(GlanceItemAction(identifier: "Create Panel"))
    }

    func testClipboardPlainTextActionsExcludeSaveAsLink() {
        let source = GlanceActionSource.clipboard(clipboardText("hello world"))
        XCTAssertEqual(
            GlanceItemActionPolicy.actions(for: source),
            [.createTextPanel, .saveAsSnippet]
        )
        XCTAssertFalse(GlanceItemActionPolicy.allows(.saveAsLink, for: source))
        XCTAssertEqual(
            GlanceItemActionPolicy.secondaryActions(for: source).map(\.identifier),
            ["saveAsSnippet"]
        )
    }

    func testClipboardURLTextActionsIncludeSaveAsLink() {
        let source = GlanceActionSource.clipboard(clipboardText("https://example.com"))
        XCTAssertEqual(
            GlanceItemActionPolicy.actions(for: source),
            [.createTextPanel, .saveAsSnippet, .saveAsLink]
        )
        XCTAssertEqual(
            GlanceItemActionPolicy.secondaryActions(for: source).map(\.identifier),
            ["saveAsSnippet", "saveAsLink"]
        )
    }

    func testClipboardImageOffersCreateImagePanel() {
        let source = GlanceActionSource.clipboard(clipboardImage())
        XCTAssertEqual(GlanceItemActionPolicy.actions(for: source), [.createImagePanel])
        XCTAssertEqual(GlanceItemActionPolicy.panelAction(for: source), .createImagePanel)
        XCTAssertTrue(GlanceItemActionPolicy.secondaryActions(for: source).isEmpty)
    }

    func testSnippetAndLinkOfferCreateTextPanelOnly() {
        XCTAssertEqual(
            GlanceItemActionPolicy.actions(for: .snippet(snippetRecord())),
            [.createTextPanel]
        )
        XCTAssertEqual(
            GlanceItemActionPolicy.actions(for: .link(linkRecord())),
            [.createTextPanel]
        )
        XCTAssertFalse(
            GlanceItemActionPolicy.allows(.saveAsLink, for: .snippet(snippetRecord()))
        )
        XCTAssertFalse(
            GlanceItemActionPolicy.allows(.createTodoPanel, for: .link(linkRecord()))
        )
    }

    func testFileShelfPanelAvailability() {
        let image = fileRecord(name: "shot.png", path: "/tmp/shot.png", type: "png")
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "com.adobe.pdf")
        let zip = fileRecord(name: "archive.zip", path: "/tmp/archive.zip", type: "zip")
        XCTAssertEqual(
            GlanceItemActionPolicy.actions(for: .fileShelf(image, resolvedURL: nil)),
            [.createImagePanel]
        )
        XCTAssertEqual(
            GlanceItemActionPolicy.actions(for: .fileShelf(pdf, resolvedURL: nil)),
            [.createPDFPanel]
        )
        XCTAssertEqual(
            GlanceItemActionPolicy.actions(for: .fileShelf(zip, resolvedURL: nil)),
            []
        )
        XCTAssertNil(
            GlanceItemActionPolicy.panelAction(for: .fileShelf(zip, resolvedURL: URL(fileURLWithPath: "/tmp/archive.zip")))
        )
    }

    func testClipboardTextCreateTextPanelOnlyCallsPanelAPI() {
        let record = clipboardText("plain")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, clipboard: record).perform(
            .createTextPanel,
            sourceID: .clipboard(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.createFromClipboard, 1)
        XCTAssertEqual(log.clipboardContents, [.text("plain")])
        log.assertUnusedExceptClipboardPanel()
    }

    func testClipboardImageCreateImagePanelOnlyCallsPanelAPI() {
        let record = clipboardImage()
        let log = ActionCallLog()
        let outcome = coordinator(log: log, clipboard: record).perform(
            .createImagePanel,
            sourceID: .clipboard(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.createFromClipboard, 1)
        XCTAssertEqual(log.clipboardContents, [.png(Data([0x89, 0x50, 0x4E, 0x47]))])
        log.assertUnusedExceptClipboardPanel()
    }

    func testClipboardTextSaveAsSnippetOnlyPresentsSnippetEditor() {
        let record = clipboardText("keep this")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, clipboard: record).perform(
            .saveAsSnippet,
            sourceID: .clipboard(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.presentSnippetEditor, 1)
        XCTAssertEqual(log.snippetEditorTexts, ["keep this"])
        XCTAssertEqual(log.dismissClipboard, 1)
        log.assertUnusedExceptSnippetEditor()
    }

    func testClipboardURLSaveAsLinkOnlyPresentsLinkEditor() {
        let record = clipboardText("https://example.com")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, clipboard: record).perform(
            .saveAsLink,
            sourceID: .clipboard(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.presentLinkEditor, 1)
        XCTAssertEqual(log.linkEditorURLs, ["https://example.com"])
        XCTAssertEqual(log.dismissClipboard, 1)
        XCTAssertEqual(log.createFromClipboard, 0)
        XCTAssertEqual(log.presentSnippetEditor, 0)
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertEqual(log.importImage, 0)
        XCTAssertEqual(log.importPDF, 0)
    }

    func testSnippetCreateTextPanelOnlyCallsPanelAPI() {
        let record = snippetRecord()
        let log = ActionCallLog()
        let outcome = coordinator(log: log, snippet: record).perform(
            .createTextPanel,
            sourceID: .snippet(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.createTextPanel, 1)
        XCTAssertEqual(log.textPanelBodies, ["body"])
        XCTAssertEqual(log.createFromClipboard, 0)
        XCTAssertEqual(log.presentSnippetEditor, 0)
        XCTAssertEqual(log.importImage, 0)
        XCTAssertEqual(log.importPDF, 0)
    }

    func testLinkCreateTextPanelOnlyCallsPanelAPI() {
        let record = linkRecord()
        let log = ActionCallLog()
        let outcome = coordinator(log: log, link: record).perform(
            .createTextPanel,
            sourceID: .link(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.createTextPanel, 1)
        XCTAssertEqual(log.textPanelBodies, ["https://example.com"])
        XCTAssertEqual(log.createFromClipboard, 0)
        XCTAssertEqual(log.presentLinkEditor, 0)
        XCTAssertEqual(log.importPDF, 0)
    }

    func testFileShelfPDFCreatePDFPanelUsesResolveAndImport() {
        let record = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, file: record, resolvedPath: record.originalPath).perform(
            .createPDFPanel,
            sourceID: .fileShelf(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.resolveFile, 1)
        XCTAssertEqual(log.importPDF, 1)
        XCTAssertEqual(log.importedPDFURLs, [URL(fileURLWithPath: "/tmp/brief.pdf")])
        XCTAssertEqual(log.importImage, 0)
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertEqual(log.createFromClipboard, 0)
    }

    func testFileShelfImageCreateImagePanelUsesResolveAndImport() {
        let record = fileRecord(name: "shot.png", path: "/tmp/shot.png", type: "png")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, file: record, resolvedPath: record.originalPath).perform(
            .createImagePanel,
            sourceID: .fileShelf(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.resolveFile, 1)
        XCTAssertEqual(log.importImage, 1)
        XCTAssertEqual(log.importedImageURLs, [URL(fileURLWithPath: "/tmp/shot.png")])
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.createTextPanel, 0)
    }

    func testPlainClipboardTextCannotSaveAsLink() {
        let record = clipboardText("not a url")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, clipboard: record).perform(
            .saveAsLink,
            sourceID: .clipboard(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .failed(GlanceNoticeCopy.cannotSave))
        XCTAssertEqual(log.presentLinkEditor, 0)
        XCTAssertEqual(log.dismissClipboard, 0)
        XCTAssertEqual(log.createFromClipboard, 0)
    }

    func testSnippetCannotSaveAsLink() {
        let record = snippetRecord()
        let log = ActionCallLog()
        let outcome = coordinator(log: log, snippet: record).perform(
            .saveAsLink,
            sourceID: .snippet(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .failed(GlanceNoticeCopy.cannotSave))
        XCTAssertEqual(log.presentLinkEditor, 0)
        XCTAssertEqual(log.createTextPanel, 0)
    }

    func testZipFileShelfCannotCreatePDFPanel() {
        let record = fileRecord(name: "archive.zip", path: "/tmp/archive.zip", type: "zip")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, file: record, resolvedPath: record.originalPath).perform(
            .createPDFPanel,
            sourceID: .fileShelf(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .failed(GlanceNoticeCopy.panelCreateFailed))
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.importImage, 0)
        XCTAssertEqual(log.createTextPanel, 0)
    }

    func testLinkCannotCreateTodoPanel() {
        let record = linkRecord()
        let log = ActionCallLog()
        let outcome = coordinator(log: log, link: record).perform(
            .createTodoPanel,
            sourceID: .link(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .failed(GlanceNoticeCopy.panelCreateFailed))
        XCTAssertEqual(log.createTextPanel, 0)
    }

    func testFileShelfImageCannotCreatePDFPanel() {
        let record = fileRecord(name: "shot.png", path: "/tmp/shot.png", type: "png")
        let log = ActionCallLog()
        let outcome = coordinator(log: log, file: record, resolvedPath: record.originalPath).perform(
            .createPDFPanel,
            sourceID: .fileShelf(record.id),
            screen: nil
        )
        XCTAssertEqual(outcome, .failed(GlanceNoticeCopy.panelCreateFailed))
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.importImage, 0)
    }

    func testSourceItemsAreNotMovedOrDeleted() {
        let snippet = snippetRecord()
        let link = linkRecord()
        let clipboard = clipboardText("stay")
        let file = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(
            log: log,
            clipboard: clipboard,
            snippet: snippet,
            link: link,
            file: file,
            resolvedPath: file.originalPath
        )
        XCTAssertEqual(
            coordinator.perform(.createTextPanel, sourceID: .snippet(snippet.id), screen: nil),
            .succeeded
        )
        XCTAssertEqual(
            coordinator.perform(.createTextPanel, sourceID: .link(link.id), screen: nil),
            .succeeded
        )
        XCTAssertEqual(
            coordinator.perform(.saveAsSnippet, sourceID: .clipboard(clipboard.id), screen: nil),
            .succeeded
        )
        XCTAssertEqual(
            coordinator.perform(.createPDFPanel, sourceID: .fileShelf(file.id), screen: nil),
            .succeeded
        )
        XCTAssertEqual(log.snippets[snippet.id]?.content, "body")
        XCTAssertEqual(log.links[link.id]?.urlString, "https://example.com")
        XCTAssertEqual(log.clipboards[clipboard.id]?.text, "stay")
        XCTAssertEqual(log.files[file.id]?.displayName, "brief.pdf")
    }

    func testClipboardKeyboardMappingUsesActionIdentifierNotTitle() {
        let text = clipboardText("hello")
        let url = clipboardText("https://example.com")
        let image = clipboardImage()
        XCTAssertEqual(
            GlanceItemActionPolicy.panelAction(for: .clipboard(text))?.identifier,
            "createTextPanel"
        )
        XCTAssertEqual(
            GlanceItemActionPolicy.panelAction(for: .clipboard(image))?.identifier,
            "createImagePanel"
        )
        let mapped = GlanceItemActionPolicy.secondaryActions(for: .clipboard(url)).compactMap {
            GlanceItemAction(identifier: $0.identifier)
        }
        XCTAssertEqual(mapped, [.saveAsSnippet, .saveAsLink])
        XCTAssertNotEqual(GlanceItemAction.saveAsSnippet.identifier, GlanceItemAction.saveAsSnippet.title)
    }

    func testAvailableActionsOnCoordinatorUseSamePolicy() {
        let record = clipboardText("https://example.com")
        let log = ActionCallLog()
        let actions = coordinator(log: log, clipboard: record).availableActions(for: .clipboard(record.id))
        XCTAssertEqual(actions, [.createTextPanel, .saveAsSnippet, .saveAsLink])
        XCTAssertEqual(
            coordinator(log: log).availableActions(for: .clipboard(UUID())),
            []
        )
    }

    private func coordinator(
        log: ActionCallLog,
        clipboard: ClipboardHistoryRecord? = nil,
        snippet: SnippetRecord? = nil,
        link: LinkRecord? = nil,
        file: FileShelfRecord? = nil,
        resolvedPath: String? = nil
    ) -> GlanceActionCoordinator {
        if let clipboard {
            log.clipboards[clipboard.id] = clipboard
        }
        if let snippet {
            log.snippets[snippet.id] = snippet
        }
        if let link {
            log.links[link.id] = link
        }
        if let file {
            log.files[file.id] = file
        }
        return GlanceActionCoordinator(
            dependencies: GlanceActionDependencies(
                createTextPanel: { _, body, _ in
                    log.createTextPanel += 1
                    log.textPanelBodies.append(body)
                    return true
                },
                importImage: { url, _, _ in
                    log.importImage += 1
                    log.importedImageURLs.append(url)
                    return true
                },
                importPDF: { url, _, _ in
                    log.importPDF += 1
                    log.importedPDFURLs.append(url)
                    return true
                },
                createFromClipboard: { content, _ in
                    log.createFromClipboard += 1
                    log.clipboardContents.append(content)
                    return true
                },
                snippet: { id in log.snippets[id] },
                link: { id in log.links[id] },
                fileRecord: { id in log.files[id] },
                resolveFile: { id in
                    log.resolveFile += 1
                    guard let path = resolvedPath ?? log.files[id]?.originalPath else {
                        return .missing
                    }
                    return FileShelfResolvedReference(
                        urlPath: path,
                        isMissing: false,
                        isStale: false,
                        bookmarkDataToRefresh: nil
                    )
                },
                clipboardRecord: { id in log.clipboards[id] },
                clipboardContent: { id in
                    guard let record = log.clipboards[id] else { return nil }
                    switch record.kind {
                    case .text:
                        return record.text.map { .text($0) }
                    case .image:
                        return .png(Data([0x89, 0x50, 0x4E, 0x47]))
                    }
                },
                clipboardExists: { log.clipboards[$0] != nil },
                panelExists: { _ in false },
                presentClipboard: { _ in false },
                presentFileShelf: { _ in false },
                presentSnippets: { _ in false },
                presentLinks: { _ in false },
                presentPanelLibrary: { _ in false },
                presentSnippetEditor: { text in
                    log.presentSnippetEditor += 1
                    log.snippetEditorTexts.append(text)
                },
                presentLinkEditor: { url in
                    log.presentLinkEditor += 1
                    log.linkEditorURLs.append(url)
                },
                dismissClipboard: {
                    log.dismissClipboard += 1
                }
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
    var textPanelBodies: [String] = []
    var clipboardContents: [ClipboardCaptureContent] = []
    var snippetEditorTexts: [String] = []
    var linkEditorURLs: [String] = []
    var importedImageURLs: [URL] = []
    var importedPDFURLs: [URL] = []
    var clipboards: [UUID: ClipboardHistoryRecord] = [:]
    var snippets: [UUID: SnippetRecord] = [:]
    var links: [UUID: LinkRecord] = [:]
    var files: [UUID: FileShelfRecord] = [:]

    func assertUnusedExceptClipboardPanel() {
        XCTAssertEqual(createTextPanel, 0)
        XCTAssertEqual(importImage, 0)
        XCTAssertEqual(importPDF, 0)
        XCTAssertEqual(presentSnippetEditor, 0)
        XCTAssertEqual(presentLinkEditor, 0)
        XCTAssertEqual(dismissClipboard, 0)
    }

    func assertUnusedExceptSnippetEditor() {
        XCTAssertEqual(createTextPanel, 0)
        XCTAssertEqual(importImage, 0)
        XCTAssertEqual(importPDF, 0)
        XCTAssertEqual(createFromClipboard, 0)
        XCTAssertEqual(presentLinkEditor, 0)
    }
}

private func clipboardText(_ text: String, id: UUID = UUID()) -> ClipboardHistoryRecord {
    ClipboardHistoryRecord(
        id: id,
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

private func clipboardImage(id: UUID = UUID()) -> ClipboardHistoryRecord {
    ClipboardHistoryRecord(
        id: id,
        kind: .image,
        createdAt: Date(),
        lastCopiedAt: Date(),
        isFavorite: false,
        favoritedAt: nil,
        contentHash: "image",
        text: nil,
        assetPath: "assets/\(id.uuidString).png"
    )
}

private func snippetRecord(id: UUID = UUID()) -> SnippetRecord {
    SnippetRecord(
        id: id,
        title: "公司简介",
        content: "body",
        createdAt: Date(),
        updatedAt: Date(),
        lastUsedAt: Date(),
        isPinned: false
    )
}

private func linkRecord(id: UUID = UUID()) -> LinkRecord {
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

private func fileRecord(
    id: UUID = UUID(),
    name: String,
    path: String,
    type: String
) -> FileShelfRecord {
    FileShelfRecord(
        id: id,
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
