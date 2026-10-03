import Foundation
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class QuickCaptureClassifierTests: XCTestCase {
    func testPlainTextIsText() {
        XCTAssertEqual(
            QuickCaptureClassifier.classify(text: "  hello glance  "),
            .text("hello glance")
        )
    }

    func testHTTPSURLIsLink() {
        XCTAssertEqual(
            QuickCaptureClassifier.classify(text: "  https://example.com  "),
            .url("https://example.com")
        )
    }

    func testHTTPURLIsLink() {
        XCTAssertEqual(
            QuickCaptureClassifier.classify(text: "http://example.com"),
            .url("http://example.com")
        )
    }

    func testBareDomainStaysText() {
        XCTAssertEqual(
            QuickCaptureClassifier.classify(text: "example.com"),
            .text("example.com")
        )
    }

    func testFTPAndFileSchemesStayText() {
        XCTAssertEqual(
            QuickCaptureClassifier.classify(text: "ftp://example.com"),
            .text("ftp://example.com")
        )
        XCTAssertEqual(
            QuickCaptureClassifier.classify(text: "file:///tmp/report.pdf"),
            .text("file:///tmp/report.pdf")
        )
    }

    func testLocalFileURLsAreFiles() {
        let pdf = URL(fileURLWithPath: "/tmp/report.pdf")
        let zip = URL(fileURLWithPath: "/tmp/archive.zip")
        XCTAssertEqual(
            QuickCaptureClassifier.classify(text: "ignored", fileURLs: [pdf, zip]),
            .files([
                URL(fileURLWithPath: FileShelfIdentity.standardizedPath(for: pdf)),
                URL(fileURLWithPath: FileShelfIdentity.standardizedPath(for: zip))
            ])
        )
    }

    func testEmptyAndWhitespaceAreEmpty() {
        XCTAssertEqual(QuickCaptureClassifier.classify(text: ""), .empty)
        XCTAssertEqual(QuickCaptureClassifier.classify(text: " \n\t "), .empty)
    }

    func testPrivacyPrefillIsEmpty() {
        XCTAssertEqual(
            QuickCapturePasteboardCandidate.content(
                fileURLs: [URL(fileURLWithPath: "/tmp/a.pdf")],
                text: "https://example.com",
                skipPrivacy: true
            ),
            .empty
        )
    }
}

final class QuickCapturePolicyTests: XCTestCase {
    func testTextActionsAndDefault() {
        let content = QuickCaptureContent.text("note")
        XCTAssertEqual(
            QuickCapturePolicy.actions(for: content),
            [.saveSnippet, .createPanel]
        )
        XCTAssertEqual(QuickCapturePolicy.defaultAction(for: content), .saveSnippet)
    }

    func testURLActionsAndDefault() {
        let content = QuickCaptureContent.url("https://openai.com")
        XCTAssertEqual(
            QuickCapturePolicy.actions(for: content),
            [.saveLink, .createPanel, .saveSnippet]
        )
        XCTAssertEqual(QuickCapturePolicy.defaultAction(for: content), .saveLink)
    }

    func testGenericFileActionsAndDefault() {
        let zip = URL(fileURLWithPath: "/tmp/archive.zip")
        let content = QuickCaptureContent.files([zip])
        XCTAssertEqual(
            QuickCapturePolicy.actions(for: content, fileSupportsPanel: { _ in false }),
            [.addToFileShelf]
        )
        XCTAssertEqual(
            QuickCapturePolicy.defaultAction(for: content, fileSupportsPanel: { _ in false }),
            .addToFileShelf
        )
    }

    func testSupportedImageAndPDFCanCreatePanel() {
        let pdf = URL(fileURLWithPath: "/tmp/report.pdf")
        let png = URL(fileURLWithPath: "/tmp/photo.png")
        XCTAssertEqual(
            QuickCapturePolicy.actions(
                for: .files([pdf]),
                fileSupportsPanel: { $0.pathExtension.lowercased() == "pdf" }
            ),
            [.addToFileShelf, .createPanel]
        )
        XCTAssertEqual(
            QuickCapturePolicy.actions(
                for: .files([png]),
                fileSupportsPanel: { $0.pathExtension.lowercased() == "png" }
            ),
            [.addToFileShelf, .createPanel]
        )
        XCTAssertEqual(
            QuickCapturePolicy.actions(
                for: .files([pdf, URL(fileURLWithPath: "/tmp/archive.zip")]),
                fileSupportsPanel: { $0.pathExtension.lowercased() == "pdf" }
            ),
            [.addToFileShelf]
        )
    }

    func testPanelFileSupportUsesExistingKinds() {
        XCTAssertEqual(
            QuickCapturePanelFileSupport.kind(for: URL(fileURLWithPath: "/tmp/a.pdf")),
            .pdf
        )
        XCTAssertEqual(
            QuickCapturePanelFileSupport.kind(for: URL(fileURLWithPath: "/tmp/a.png")),
            .image
        )
        XCTAssertNil(QuickCapturePanelFileSupport.kind(for: URL(fileURLWithPath: "/tmp/a.zip")))
    }
}

final class QuickCaptureExecutorTests: XCTestCase {
    func testSaveSnippetCallsOnlySnippetAPI() {
        var snippets: [String] = []
        let destinations = trackingDestinations(
            saveSnippet: { snippets.append($0); return .succeeded }
        )
        let result = QuickCaptureExecutor.perform(
            .saveSnippet,
            content: .text("keep this"),
            destinations: destinations
        )
        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(snippets, ["keep this"])
    }

    func testSaveLinkCallsOnlyLinkAPI() {
        var links: [String] = []
        let destinations = trackingDestinations(
            saveLink: { links.append($0); return .succeeded }
        )
        let result = QuickCaptureExecutor.perform(
            .saveLink,
            content: .url("https://example.com"),
            destinations: destinations
        )
        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(links, ["https://example.com"])
    }

    func testAddToFileShelfCallsOnlyFileShelfAPI() {
        var files: [[URL]] = []
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        let destinations = trackingDestinations(
            addToFileShelf: { files.append($0); return .succeeded }
        )
        let result = QuickCaptureExecutor.perform(
            .addToFileShelf,
            content: .files([url]),
            destinations: destinations
        )
        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(files, [[url]])
    }

    func testCreatePanelCallsOnlyPanelAPI() {
        var panels: [String] = []
        let destinations = trackingDestinations(
            createTextPanel: { panels.append($0); return true }
        )
        let result = QuickCaptureExecutor.perform(
            .createPanel,
            content: .text("pin me"),
            destinations: destinations
        )
        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(panels, ["pin me"])
    }

    func testSaveURLAsSnippetCallsOnlySnippetAPI() {
        var snippets: [String] = []
        let destinations = trackingDestinations(
            saveSnippet: { snippets.append($0); return .succeeded }
        )
        XCTAssertEqual(
            QuickCaptureExecutor.perform(
                .saveSnippet,
                content: .url("https://example.com"),
                destinations: destinations
            ),
            .succeeded
        )
        XCTAssertEqual(snippets, ["https://example.com"])
    }

    func testCreatePanelForPDFCallsPDFImport() {
        var pdfs: [URL] = []
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        let destinations = trackingDestinations(
            createPDFPanel: { pdfs.append($0); return true }
        )
        XCTAssertEqual(
            QuickCaptureExecutor.perform(.createPanel, content: .files([url]), destinations: destinations),
            .succeeded
        )
        XCTAssertEqual(pdfs, [url])
    }

    private func trackingDestinations(
        saveSnippet: @escaping (String) -> GlanceActionOutcome = { _ in
            XCTFail("snippet"); return .failed("snippet")
        },
        saveLink: @escaping (String) -> GlanceActionOutcome = { _ in
            XCTFail("link"); return .failed("link")
        },
        addToFileShelf: @escaping ([URL]) -> GlanceActionOutcome = { _ in
            XCTFail("files"); return .failed("files")
        },
        createTextPanel: @escaping (String) -> Bool = { _ in
            XCTFail("text panel"); return false
        },
        createImagePanel: @escaping (URL) -> Bool = { _ in
            XCTFail("image panel"); return false
        },
        createPDFPanel: @escaping (URL) -> Bool = { _ in
            XCTFail("pdf panel"); return false
        }
    ) -> QuickCaptureDestinations {
        QuickCaptureDestinations(
            saveSnippet: saveSnippet,
            saveLink: saveLink,
            addToFileShelf: addToFileShelf,
            createTextPanel: createTextPanel,
            createImagePanel: createImagePanel,
            createPDFPanel: createPDFPanel
        )
    }
}

@MainActor
final class QuickCaptureModelTests: XCTestCase {
    func testSnippetFailureKeepsDraftAndDoesNotComplete() {
        let model = QuickCaptureModel()
        model.setText("keep me")
        XCTAssertEqual(model.selectedAction, .saveSnippet)
        let failed = QuickCaptureDestinations(
            saveSnippet: { _ in .failed("无法保存片段") },
            saveLink: { _ in .failed("link") },
            addToFileShelf: { _ in .failed("files") },
            createTextPanel: { _ in false },
            createImagePanel: { _ in false },
            createPDFPanel: { _ in false }
        )
        XCTAssertFalse(model.submit(using: failed))
        XCTAssertEqual(model.text, "keep me")
        XCTAssertEqual(model.content, .text("keep me"))
        XCTAssertEqual(model.error, "无法保存片段")
        XCTAssertFalse(model.didComplete)
        XCTAssertEqual(model.selectedAction, .saveSnippet)
    }

    func testFileShelfFailureKeepsFilesAndDoesNotComplete() {
        let model = QuickCaptureModel()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        model.setFiles([url])
        XCTAssertEqual(model.selectedAction, .addToFileShelf)
        let failed = QuickCaptureDestinations(
            saveSnippet: { _ in .failed("snippet") },
            saveLink: { _ in .failed("link") },
            addToFileShelf: { _ in .failed("无法加入文件架") },
            createTextPanel: { _ in false },
            createImagePanel: { _ in false },
            createPDFPanel: { _ in false }
        )
        XCTAssertFalse(model.submit(using: failed))
        XCTAssertEqual(
            model.content,
            .files([URL(fileURLWithPath: FileShelfIdentity.standardizedPath(for: url))])
        )
        XCTAssertEqual(model.error, "无法加入文件架")
        XCTAssertFalse(model.didComplete)
        XCTAssertEqual(model.selectedAction, .addToFileShelf)
    }

    func testSuccessfulSubmitMarksComplete() {
        let model = QuickCaptureModel()
        model.setText("https://example.com")
        XCTAssertEqual(model.selectedAction, .saveLink)
        let ok = QuickCaptureDestinations(
            saveSnippet: { _ in .failed("snippet") },
            saveLink: { _ in .succeeded },
            addToFileShelf: { _ in .failed("files") },
            createTextPanel: { _ in false },
            createImagePanel: { _ in false },
            createPDFPanel: { _ in false }
        )
        XCTAssertTrue(model.submit(using: ok))
        XCTAssertTrue(model.didComplete)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.content, .url("https://example.com"))
    }

    func testArrowKeysMoveActionWithoutChangingContent() {
        let model = QuickCaptureModel()
        model.setText("https://example.com")
        XCTAssertEqual(model.selectedAction, .saveLink)
        model.moveAction(1)
        XCTAssertEqual(model.selectedAction, .createPanel)
        model.moveAction(1)
        XCTAssertEqual(model.selectedAction, .saveSnippet)
        XCTAssertEqual(model.content, .url("https://example.com"))
    }
}

final class QuickCaptureKeyPolicyTests: XCTestCase {
    func testArrowsMoveWhenIdle() {
        XCTAssertEqual(
            QuickCaptureKeyPolicy.intent(
                keyCode: 125,
                command: false,
                shift: false,
                isComposing: false,
                allowsNewline: true
            ),
            .moveAction(1)
        )
        XCTAssertEqual(
            QuickCaptureKeyPolicy.intent(
                keyCode: 126,
                command: false,
                shift: false,
                isComposing: false,
                allowsNewline: true
            ),
            .moveAction(-1)
        )
    }

    func testArrowsAreIgnoredWhileComposing() {
        XCTAssertEqual(
            QuickCaptureKeyPolicy.intent(
                keyCode: 125,
                command: false,
                shift: false,
                isComposing: true,
                allowsNewline: true
            ),
            .none
        )
    }

    func testCommandReturnSubmits() {
        XCTAssertEqual(
            QuickCaptureKeyPolicy.intent(
                keyCode: 36,
                command: true,
                shift: false,
                isComposing: false,
                allowsNewline: true
            ),
            .submit
        )
    }
}
