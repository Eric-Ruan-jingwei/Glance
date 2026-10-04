import AppKit
import UniformTypeIdentifiers
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class GlanceItemDragTests: XCTestCase {
    func testPayloadRoundTripsEachSourceIdentity() {
        let clipboardID = UUID()
        let snippetID = UUID()
        let linkID = UUID()
        let fileID = UUID()
        assertRoundTrip(.clipboard(clipboardID), source: "clipboard", id: clipboardID)
        assertRoundTrip(.snippet(snippetID), source: "snippet", id: snippetID)
        assertRoundTrip(.link(linkID), source: "link", id: linkID)
        assertRoundTrip(.fileShelf(fileID), source: "fileShelf", id: fileID)
    }

    func testPayloadCarriesOnlyVersionSourceAndItemID() throws {
        let payload = GlanceItemDragPayload(sourceID: .snippet(UUID()))
        let data = try XCTUnwrap(GlanceItemDragCodec.encode(payload))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["version", "source", "itemID"])
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertNil(object["availableActions"])
        XCTAssertNil(object["resolvedFileURL"])
        XCTAssertNil(object["isMissing"])
        XCTAssertNil(object["text"])
        XCTAssertNil(object["urlString"])
    }

    func testInvalidPayloadsFailClosed() {
        XCTAssertNil(GlanceItemDragCodec.decode(Data()))
        XCTAssertNil(GlanceItemDragCodec.decode(Data("not-json".utf8)))
        XCTAssertNil(GlanceItemDragCodec.decode(Data(#"{"version":1,"source":"clipboard"}"#.utf8)))
        XCTAssertNil(GlanceItemDragCodec.decode(Data(
            #"{"version":1,"source":"clipboard","itemID":"not-a-uuid"}"#.utf8
        )))
        XCTAssertNil(GlanceItemDragCodec.decode(Data(
            #"{"version":2,"source":"clipboard","itemID":"\#(UUID().uuidString)"}"#.utf8
        )))
        XCTAssertNil(GlanceItemDragCodec.decode(Data(
            #"{"version":1,"source":"panel","itemID":"\#(UUID().uuidString)"}"#.utf8
        )))
        XCTAssertNil(GlanceItemDragCodec.decode(Data(
            #"{"version":1,"source":"unknown","itemID":"\#(UUID().uuidString)"}"#.utf8
        )))
    }

    func testDropPolicySnippetsPrefersSaveAsSnippetOverPanelAction() {
        let sourceID = GlanceActionSourceID.clipboard(UUID())
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .snippets,
                availableActions: [.createTextPanel, .saveAsSnippet]
            ),
            .saveAsSnippet
        )
        XCTAssertNil(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .snippets,
                availableActions: [.createTextPanel]
            )
        )
    }

    func testDropPolicyLinksRequiresSaveAsLink() {
        let sourceID = GlanceActionSourceID.clipboard(UUID())
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .links,
                availableActions: [.createTextPanel, .saveAsSnippet, .saveAsLink]
            ),
            .saveAsLink
        )
        XCTAssertNil(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .links,
                availableActions: [.createTextPanel, .saveAsSnippet]
            )
        )
    }

    func testDropPolicyPanelsUsesExplicitPanelActions() {
        let sourceID = GlanceActionSourceID.snippet(UUID())
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .panels,
                availableActions: [.createTextPanel]
            ),
            .createTextPanel
        )
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .panels,
                availableActions: [.createImagePanel]
            ),
            .createImagePanel
        )
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .panels,
                availableActions: [.createPDFPanel]
            ),
            .createPDFPanel
        )
        XCTAssertNil(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .panels,
                availableActions: [.saveAsSnippet]
            )
        )
        XCTAssertNil(
            GlanceItemDropPolicy.action(
                for: sourceID,
                destination: .panels,
                availableActions: [.createTodoPanel]
            )
        )
    }

    func testClipboardPlainTextDropAvailability() {
        let record = clipboardText("hello world")
        let coordinator = coordinator(log: ActionCallLog(), clipboard: record)
        let available = coordinator.availableActions(for: .clipboard(record.id))
        XCTAssertEqual(
            GlanceItemDropPolicy.action(for: .clipboard(record.id), destination: .snippets, availableActions: available),
            .saveAsSnippet
        )
        XCTAssertNil(
            GlanceItemDropPolicy.action(for: .clipboard(record.id), destination: .links, availableActions: available)
        )
        XCTAssertNil(drop(.clipboard(record.id), to: .links, coordinator: coordinator))
        XCTAssertEqual(
            GlanceItemDropPolicy.action(for: .clipboard(record.id), destination: .panels, availableActions: available),
            .createTextPanel
        )
    }

    func testClipboardURLDropAvailability() {
        let record = clipboardText("https://example.com")
        let coordinator = coordinator(log: ActionCallLog(), clipboard: record)
        let available = coordinator.availableActions(for: .clipboard(record.id))
        XCTAssertEqual(
            GlanceItemDropPolicy.action(for: .clipboard(record.id), destination: .links, availableActions: available),
            .saveAsLink
        )
        XCTAssertEqual(
            GlanceItemDropPolicy.action(for: .clipboard(record.id), destination: .snippets, availableActions: available),
            .saveAsSnippet
        )
    }

    func testSnippetAndLinkDropToPanelsCreateTextPanel() {
        let snippet = snippetRecord()
        let link = linkRecord()
        let coordinator = coordinator(log: ActionCallLog(), snippet: snippet, link: link)
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: .snippet(snippet.id),
                destination: .panels,
                availableActions: coordinator.availableActions(for: .snippet(snippet.id))
            ),
            .createTextPanel
        )
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: .link(link.id),
                destination: .panels,
                availableActions: coordinator.availableActions(for: .link(link.id))
            ),
            .createTextPanel
        )
    }

    func testValidPDFDropToPanelsIsCreatePDFPanel() {
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let coordinator = coordinator(log: ActionCallLog(), file: pdf, resolvedPath: pdf.originalPath)
        XCTAssertEqual(
            GlanceItemDropPolicy.action(
                for: .fileShelf(pdf.id),
                destination: .panels,
                availableActions: coordinator.availableActions(for: .fileShelf(pdf.id))
            ),
            .createPDFPanel
        )
    }

    func testMissingPDFDropToPanelsIsRejected() {
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: pdf, fileMissing: true)
        XCTAssertEqual(coordinator.availableActions(for: .fileShelf(pdf.id)), [])
        let session = GlanceItemDropSession()
        let outcome = GlanceItemDropRunner.drop(
            sourceID: .fileShelf(pdf.id),
            destination: .panels,
            session: session,
            availableActions: { coordinator.availableActions(for: $0) },
            perform: { coordinator.perform($0, sourceID: $1, screen: $2) },
            screen: nil
        )
        XCTAssertNil(outcome)
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.files[pdf.id]?.id, pdf.id)
    }

    func testDropClipboardTextToSnippetsUsesSaveAsSnippetPath() {
        let record = clipboardText("keep this")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: record)
        let outcome = drop(
            .clipboard(record.id),
            to: .snippets,
            coordinator: coordinator
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.presentSnippetEditor, 1)
        XCTAssertEqual(log.snippetEditorTexts, ["keep this"])
        XCTAssertEqual(log.dismissClipboard, 1)
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertEqual(log.createFromClipboard, 0)
        XCTAssertEqual(log.clipboards[record.id]?.id, record.id)
    }

    func testDropClipboardURLToLinksUsesSaveAsLinkPath() {
        let record = clipboardText("https://example.com")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: record)
        let outcome = drop(
            .clipboard(record.id),
            to: .links,
            coordinator: coordinator
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.presentLinkEditor, 1)
        XCTAssertEqual(log.linkEditorURLs, ["https://example.com"])
        XCTAssertEqual(log.dismissClipboard, 1)
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertEqual(log.clipboards[record.id]?.id, record.id)
    }

    func testDropSnippetToPanelsOnlyCreatesTextPanel() {
        let snippet = snippetRecord()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, snippet: snippet)
        let outcome = drop(
            .snippet(snippet.id),
            to: .panels,
            coordinator: coordinator
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.createTextPanel, 1)
        XCTAssertEqual(log.textPanelBodies, ["body"])
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.importImage, 0)
        XCTAssertEqual(log.presentSnippetEditor, 0)
        XCTAssertEqual(log.snippets[snippet.id]?.id, snippet.id)
    }

    func testDropLinkToPanelsOnlyCreatesTextPanel() {
        let link = linkRecord()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, link: link)
        let outcome = drop(
            .link(link.id),
            to: .panels,
            coordinator: coordinator
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.createTextPanel, 1)
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.importImage, 0)
        XCTAssertEqual(log.presentLinkEditor, 0)
        XCTAssertEqual(log.links[link.id]?.id, link.id)
        XCTAssertEqual(log.links[link.id]?.urlString, "https://example.com")
    }

    func testDropPDFToPanelsResolvesAndImports() {
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: pdf, resolvedPath: pdf.originalPath)
        let outcome = drop(
            .fileShelf(pdf.id),
            to: .panels,
            coordinator: coordinator
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.resolveFile, 2)
        XCTAssertEqual(log.importPDF, 1)
        XCTAssertEqual(log.importedPDFURLs, [URL(fileURLWithPath: "/tmp/brief.pdf")])
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertEqual(log.files[pdf.id]?.id, pdf.id)
    }

    func testDropDoesNotMoveSources() {
        let clipboard = clipboardText("plain")
        let snippet = snippetRecord()
        let link = linkRecord()
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(
            log: log,
            clipboard: clipboard,
            snippet: snippet,
            link: link,
            file: pdf,
            resolvedPath: pdf.originalPath
        )
        _ = drop(.clipboard(clipboard.id), to: .snippets, coordinator: coordinator)
        _ = drop(.snippet(snippet.id), to: .panels, coordinator: coordinator)
        _ = drop(.link(link.id), to: .panels, coordinator: coordinator)
        _ = drop(.fileShelf(pdf.id), to: .panels, coordinator: coordinator)
        XCTAssertEqual(log.clipboards[clipboard.id]?.id, clipboard.id)
        XCTAssertEqual(log.snippets[snippet.id]?.id, snippet.id)
        XCTAssertEqual(log.links[link.id]?.id, link.id)
        XCTAssertEqual(log.files[pdf.id]?.id, pdf.id)
    }

    func testStaleSourceAfterHoverUsesCachedActionAndFailsClosed() {
        let snippet = snippetRecord()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, snippet: snippet)
        let session = GlanceItemDropSession()
        XCTAssertEqual(
            session.plannedAction(
                sourceID: .snippet(snippet.id),
                destination: .panels,
                availableActions: { coordinator.availableActions(for: $0) }
            ),
            .createTextPanel
        )
        log.snippets.removeValue(forKey: snippet.id)
        let outcome = GlanceItemDropRunner.drop(
            sourceID: .snippet(snippet.id),
            destination: .panels,
            session: session,
            availableActions: { coordinator.availableActions(for: $0) },
            perform: { coordinator.perform($0, sourceID: $1, screen: $2) },
            screen: nil
        )
        XCTAssertEqual(outcome, .failed(GlanceNoticeCopy.staleItem))
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertNil(log.snippets[snippet.id])
    }

    func testHoverCachesFileShelfResolveForSamePayload() {
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: pdf, resolvedPath: pdf.originalPath)
        let session = GlanceItemDropSession()
        let sourceID = GlanceActionSourceID.fileShelf(pdf.id)
        XCTAssertEqual(
            session.plannedAction(
                sourceID: sourceID,
                destination: .panels,
                availableActions: { coordinator.availableActions(for: $0) }
            ),
            .createPDFPanel
        )
        XCTAssertEqual(
            session.plannedAction(
                sourceID: sourceID,
                destination: .panels,
                availableActions: { coordinator.availableActions(for: $0) }
            ),
            .createPDFPanel
        )
        XCTAssertEqual(log.resolveFile, 1)
        let other = fileRecord(name: "other.pdf", path: "/tmp/other.pdf", type: "pdf")
        log.files[other.id] = other
        _ = session.plannedAction(
            sourceID: .fileShelf(other.id),
            destination: .panels,
            availableActions: { coordinator.availableActions(for: $0) }
        )
        XCTAssertEqual(log.resolveFile, 2)
        session.reset()
        _ = session.plannedAction(
            sourceID: sourceID,
            destination: .panels,
            availableActions: { coordinator.availableActions(for: $0) }
        )
        XCTAssertEqual(log.resolveFile, 3)
    }

    func testNativeDragOffersKeepURLAndFileRepresentations() {
        let linkID = UUID()
        let fileID = UUID()
        let web = URL(string: "https://example.com")!
        let file = URL(fileURLWithPath: "/tmp/brief.pdf")
        XCTAssertEqual(
            GlanceDragOffer.typeIdentifiers(nativeURL: web),
            [GlanceDragType.identifier, UTType.url.identifier]
        )
        XCTAssertEqual(
            GlanceDragOffer.typeIdentifiers(nativeURL: file),
            [GlanceDragType.identifier, UTType.fileURL.identifier]
        )
        let linkProvider = GlanceDragOffer.itemProvider(sourceID: .link(linkID), nativeURL: web)
        XCTAssertTrue(linkProvider.hasItemConformingToTypeIdentifier(GlanceDragType.identifier))
        XCTAssertTrue(linkProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier))
        let fileProvider = GlanceDragOffer.itemProvider(sourceID: .fileShelf(fileID), nativeURL: file)
        XCTAssertTrue(fileProvider.hasItemConformingToTypeIdentifier(GlanceDragType.identifier))
        XCTAssertTrue(fileProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        XCTAssertEqual(GlanceDragType.identifier, "\(GlanceConstants.bundleIdentifier).item")
        XCTAssertEqual(GlanceDragType.identifier, "com.glance.app.item")
    }

    func testClipboardAndSnippetNativeTextOffers() {
        XCTAssertEqual(
            GlanceDragOffer.typeIdentifiers(nativeText: "hello"),
            [GlanceDragType.identifier, UTType.utf8PlainText.identifier]
        )
        let provider = GlanceDragOffer.itemProvider(
            sourceID: .snippet(UUID()),
            nativeText: "hello"
        )
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(GlanceDragType.identifier))
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier))
    }

    func testDropClipboardImageToPanelsCreatesImagePanel() {
        let record = clipboardImage()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: record)
        let outcome = drop(
            .clipboard(record.id),
            to: .panels,
            coordinator: coordinator
        )
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(log.createFromClipboard, 1)
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertEqual(log.presentSnippetEditor, 0)
        XCTAssertEqual(log.clipboards[record.id]?.id, record.id)
    }

    func testDropClipboardImageToSnippetsIsRejected() {
        let record = clipboardImage()
        let coordinator = coordinator(log: ActionCallLog(), clipboard: record)
        XCTAssertNil(drop(.clipboard(record.id), to: .snippets, coordinator: coordinator))
    }

    func testHandleProvidersRejectsClipboardPlainTextOnLinks() {
        let record = clipboardText("hello world")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: record)
        var performs = 0
        XCTAssertFalse(
            handleAccepted(
                sourceID: .clipboard(record.id),
                destination: .links,
                coordinator: coordinator,
                nativeText: record.text,
                performCount: &performs
            )
        )
        XCTAssertEqual(performs, 0)
        XCTAssertEqual(log.presentLinkEditor, 0)
        XCTAssertEqual(log.presentSnippetEditor, 0)
        XCTAssertEqual(log.createTextPanel, 0)
        XCTAssertEqual(log.clipboards[record.id]?.id, record.id)
    }

    func testHandleProvidersRejectsClipboardImageOnSnippets() {
        let record = clipboardImage()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: record)
        var performs = 0
        XCTAssertFalse(
            handleAccepted(
                sourceID: .clipboard(record.id),
                destination: .snippets,
                coordinator: coordinator,
                performCount: &performs
            )
        )
        XCTAssertEqual(performs, 0)
        XCTAssertEqual(log.presentSnippetEditor, 0)
    }

    func testHandleProvidersRejectsSnippetOnLinks() {
        let snippet = snippetRecord()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, snippet: snippet)
        var performs = 0
        XCTAssertFalse(
            handleAccepted(
                sourceID: .snippet(snippet.id),
                destination: .links,
                coordinator: coordinator,
                nativeText: snippet.content,
                performCount: &performs
            )
        )
        XCTAssertEqual(performs, 0)
        XCTAssertEqual(log.snippets[snippet.id]?.id, snippet.id)
    }

    func testHandleProvidersRejectsLinkOnLinksWithoutExternalFallback() {
        let link = linkRecord()
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, link: link)
        let url = URL(string: link.urlString)!
        let providers = [
            GlanceDragOffer.itemProvider(sourceID: .link(link.id), nativeURL: url)
        ]
        XCTAssertTrue(GlanceItemDragCodec.hasInternalPayload(providers))
        XCTAssertTrue(providers[0].hasItemConformingToTypeIdentifier(UTType.url.identifier))
        var performs = 0
        var ingestedExternally = 0
        let accepted = handleAccepted(
            sourceID: .link(link.id),
            destination: .links,
            coordinator: coordinator,
            nativeURL: url,
            performCount: &performs
        )
        XCTAssertFalse(accepted)
        if !GlanceItemDragCodec.hasInternalPayload(providers) || accepted {
            ingestedExternally += 1
        }
        XCTAssertEqual(performs, 0)
        XCTAssertEqual(ingestedExternally, 0)
        XCTAssertEqual(log.links.count, 1)
        XCTAssertEqual(log.presentLinkEditor, 0)
    }

    func testHandleProvidersRejectsMissingPDFOnPanels() {
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: pdf, fileMissing: true)
        var performs = 0
        XCTAssertFalse(
            handleAccepted(
                sourceID: .fileShelf(pdf.id),
                destination: .panels,
                coordinator: coordinator,
                nativeURL: URL(fileURLWithPath: pdf.originalPath),
                performCount: &performs
            )
        )
        XCTAssertEqual(performs, 0)
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.files[pdf.id]?.id, pdf.id)
    }

    func testHandleProvidersRejectsInvalidInternalPayloads() {
        let coordinator = coordinator(log: ActionCallLog())
        let payloads: [Data] = [
            Data("not-json".utf8),
            Data(#"{"version":2,"source":"clipboard","itemID":"\#(UUID().uuidString)"}"#.utf8),
            Data(#"{"version":1,"source":"panel","itemID":"\#(UUID().uuidString)"}"#.utf8),
            Data(#"{"version":1,"source":"clipboard","itemID":"not-a-uuid"}"#.utf8)
        ]
        for data in payloads {
            var performs = 0
            let session = GlanceItemDropSession()
            let accepted = GlanceItemDropRunner.handleProviders(
                [invalidInternalProvider(data)],
                destination: .links,
                session: session,
                availableActions: { coordinator.availableActions(for: $0) },
                perform: { action, sourceID, screen in
                    performs += 1
                    return coordinator.perform(action, sourceID: sourceID, screen: screen)
                },
                screen: nil,
                onFailed: { _ in },
                pasteboard: isolatedPasteboard(data)
            )
            XCTAssertFalse(accepted, "payload should be rejected: \(String(data: data, encoding: .utf8) ?? "")")
            XCTAssertEqual(performs, 0)
        }
    }

    func testHoverAndAcceptanceStayConsistent() {
        let plain = clipboardText("hello world")
        let url = clipboardText("https://example.com")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: plain)
        log.clipboards[url.id] = url

        assertHoverMatchesAcceptance(
            sourceID: .clipboard(url.id),
            destination: .links,
            coordinator: coordinator,
            nativeText: url.text,
            expected: true
        )
        assertHoverMatchesAcceptance(
            sourceID: .clipboard(plain.id),
            destination: .links,
            coordinator: coordinator,
            nativeText: plain.text,
            expected: false
        )
    }

    func testValidPDFBecomingMissingAfterHoverDoesNotImport() {
        let pdf = fileRecord(name: "brief.pdf", path: "/tmp/brief.pdf", type: "pdf")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, file: pdf, resolvedPath: pdf.originalPath)
        let session = GlanceItemDropSession()
        XCTAssertEqual(
            session.plannedAction(
                sourceID: .fileShelf(pdf.id),
                destination: .panels,
                availableActions: { coordinator.availableActions(for: $0) }
            ),
            .createPDFPanel
        )
        log.fileMissing = true
        let outcome = GlanceItemDropRunner.drop(
            sourceID: .fileShelf(pdf.id),
            destination: .panels,
            session: session,
            availableActions: { coordinator.availableActions(for: $0) },
            perform: { coordinator.perform($0, sourceID: $1, screen: $2) },
            screen: nil
        )
        XCTAssertNotEqual(outcome, .succeeded)
        XCTAssertEqual(outcome, .failed(GlanceNoticeCopy.fileMissing))
        XCTAssertEqual(log.importPDF, 0)
        XCTAssertEqual(log.files[pdf.id]?.id, pdf.id)
    }

    func testHandleProvidersAcceptsClipboardTextToSnippets() {
        let record = clipboardText("keep this")
        let log = ActionCallLog()
        let coordinator = coordinator(log: log, clipboard: record)
        var performs = 0
        XCTAssertTrue(
            handleAccepted(
                sourceID: .clipboard(record.id),
                destination: .snippets,
                coordinator: coordinator,
                nativeText: record.text,
                performCount: &performs
            )
        )
    }

    func testProductionURLDragItemExportsInternalAndPublicURL() {
        let id = UUID()
        let url = URL(string: "https://example.com")!
        let item = GlanceURLDragItem(
            payload: GlanceItemDragPayload(sourceID: .link(id)),
            url: url
        )
        let provider = NSItemProvider()
        provider.register(item)
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(GlanceDragType.identifier))
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.url.identifier))
        let internalReady = expectation(description: "internal")
        provider.loadDataRepresentation(forTypeIdentifier: GlanceDragType.identifier) { data, _ in
            XCTAssertEqual(GlanceItemDragCodec.sourceID(from: data ?? Data()), .link(id))
            internalReady.fulfill()
        }
        let urlReady = expectation(description: "url")
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
            let loaded: URL?
            if let value = value as? URL {
                loaded = value
            } else if let value = value as? NSURL {
                loaded = value as URL
            } else if let data = value as? Data {
                loaded = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                loaded = nil
            }
            XCTAssertEqual(loaded?.absoluteString, url.absoluteString)
            urlReady.fulfill()
        }
        wait(for: [internalReady, urlReady], timeout: 2)
    }

    func testProductionFileURLDragItemExportsInternalAndFileURL() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/brief.pdf")
        let item = GlanceURLDragItem(
            payload: GlanceItemDragPayload(sourceID: .fileShelf(id)),
            url: url
        )
        let provider = NSItemProvider()
        provider.register(item)
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(GlanceDragType.identifier))
        XCTAssertTrue(
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        )
        let internalReady = expectation(description: "internal-file")
        provider.loadDataRepresentation(forTypeIdentifier: GlanceDragType.identifier) { data, _ in
            XCTAssertEqual(GlanceItemDragCodec.sourceID(from: data ?? Data()), .fileShelf(id))
            internalReady.fulfill()
        }
        let fileReady = expectation(description: "file-url")
        let type = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            ? UTType.fileURL.identifier
            : UTType.url.identifier
        provider.loadItem(forTypeIdentifier: type, options: nil) { value, _ in
            let loaded: URL?
            if let value = value as? URL {
                loaded = value
            } else if let value = value as? NSURL {
                loaded = value as URL
            } else if let data = value as? Data {
                loaded = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                loaded = nil
            }
            XCTAssertEqual(loaded?.isFileURL, true)
            XCTAssertEqual(loaded?.path, url.path)
            fileReady.fulfill()
        }
        wait(for: [internalReady, fileReady], timeout: 2)
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
    }

    func testProductionTextDragItemExportsInternalAndPlainText() {
        let id = UUID()
        let item = GlanceTextDragItem(
            payload: GlanceItemDragPayload(sourceID: .snippet(id)),
            text: "hello"
        )
        let provider = NSItemProvider()
        provider.register(item)
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(GlanceDragType.identifier))
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier))
        let internalReady = expectation(description: "internal-text")
        provider.loadDataRepresentation(forTypeIdentifier: GlanceDragType.identifier) { data, _ in
            XCTAssertEqual(GlanceItemDragCodec.sourceID(from: data ?? Data()), .snippet(id))
            internalReady.fulfill()
        }
        let textReady = expectation(description: "plain-text")
        provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
            XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "hello")
            textReady.fulfill()
        }
        wait(for: [internalReady, textReady], timeout: 2)
    }

    private func assertRoundTrip(_ sourceID: GlanceActionSourceID, source: String, id: UUID) {
        let payload = GlanceItemDragPayload(sourceID: sourceID)
        XCTAssertEqual(payload.version, 1)
        XCTAssertEqual(payload.source, source)
        XCTAssertEqual(payload.itemID, id)
        let data = GlanceItemDragCodec.encode(payload)
        XCTAssertEqual(GlanceItemDragCodec.decode(data ?? Data())?.sourceID, sourceID)
    }

    private func drop(
        _ sourceID: GlanceActionSourceID,
        to destination: GlanceItemDropDestination,
        coordinator: GlanceActionCoordinator
    ) -> GlanceActionOutcome? {
        GlanceItemDropRunner.drop(
            sourceID: sourceID,
            destination: destination,
            session: GlanceItemDropSession(),
            availableActions: { coordinator.availableActions(for: $0) },
            perform: { coordinator.perform($0, sourceID: $1, screen: $2) },
            screen: nil
        )
    }

    @discardableResult
    private func handleAccepted(
        sourceID: GlanceActionSourceID,
        destination: GlanceItemDropDestination,
        coordinator: GlanceActionCoordinator,
        nativeText: String? = nil,
        nativeURL: URL? = nil,
        performCount: inout Int
    ) -> Bool {
        let session = GlanceItemDropSession()
        _ = session.plannedAction(
            sourceID: sourceID,
            destination: destination,
            availableActions: { coordinator.availableActions(for: $0) }
        )
        var performs = 0
        let accepted = GlanceItemDropRunner.handleProviders(
            [GlanceDragOffer.itemProvider(
                sourceID: sourceID,
                nativeText: nativeText,
                nativeURL: nativeURL
            )],
            destination: destination,
            session: session,
            availableActions: { coordinator.availableActions(for: $0) },
            perform: { action, droppedID, screen in
                performs += 1
                return coordinator.perform(action, sourceID: droppedID, screen: screen)
            },
            screen: nil,
            onFailed: { _ in },
            pasteboard: isolatedPasteboard(
                GlanceItemDragCodec.encode(GlanceItemDragPayload(sourceID: sourceID))
            )
        )
        performCount = performs
        return accepted
    }

    private func assertHoverMatchesAcceptance(
        sourceID: GlanceActionSourceID,
        destination: GlanceItemDropDestination,
        coordinator: GlanceActionCoordinator,
        nativeText: String?,
        expected: Bool
    ) {
        let session = GlanceItemDropSession()
        let pasteboard = isolatedPasteboard(
            GlanceItemDragCodec.encode(GlanceItemDragPayload(sourceID: sourceID))
        )
        let highlight = GlanceItemDropRunner.hoverHighlight(
            targeted: true,
            destination: destination,
            session: session,
            availableActions: { coordinator.availableActions(for: $0) },
            pasteboard: pasteboard
        )
        let accepted = GlanceItemDropRunner.accepts(
            providers: [
                GlanceDragOffer.itemProvider(sourceID: sourceID, nativeText: nativeText)
            ],
            destination: destination,
            session: session,
            availableActions: { coordinator.availableActions(for: $0) },
            pasteboard: pasteboard
        )
        XCTAssertEqual(highlight, expected)
        XCTAssertEqual(accepted, expected)
        XCTAssertEqual(highlight, accepted)
    }

    private func isolatedPasteboard(_ data: Data?) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("glance.test.\(UUID().uuidString)"))
        pasteboard.clearContents()
        if let data {
            pasteboard.setData(data, forType: GlanceDragType.pasteboardType)
        }
        return pasteboard
    }

    private func invalidInternalProvider(_ data: Data) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: GlanceDragType.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(data, nil)
            return nil
        }
        return provider
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
        log.fileMissing = fileMissing
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
                    if log.fileMissing {
                        return .missing
                    }
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
    var fileMissing = false
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
