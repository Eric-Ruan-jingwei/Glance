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
            [.saveSnippet, .createTextPanel, .createTodoPanel]
        )
        XCTAssertEqual(QuickCapturePolicy.defaultAction(for: content), .saveSnippet)
    }

    func testURLActionsAndDefault() {
        let content = QuickCaptureContent.url("https://openai.com")
        let actions = QuickCapturePolicy.actions(for: content)
        XCTAssertEqual(actions, [.saveLink, .createTextPanel, .saveSnippet])
        XCTAssertFalse(actions.contains(.createTodoPanel))
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

    func testSingleSupportedImageAndPDFCanCreatePanel() {
        let pdf = URL(fileURLWithPath: "/tmp/report.pdf")
        let png = URL(fileURLWithPath: "/tmp/photo.png")
        XCTAssertEqual(
            QuickCapturePolicy.actions(
                for: .files([pdf]),
                fileSupportsPanel: { $0.pathExtension.lowercased() == "pdf" }
            ),
            [.addToFileShelf, .createFilePanel]
        )
        XCTAssertEqual(
            QuickCapturePolicy.actions(
                for: .files([png]),
                fileSupportsPanel: { $0.pathExtension.lowercased() == "png" }
            ),
            [.addToFileShelf, .createFilePanel]
        )
    }

    func testMultipleFilesNeverOfferCreatePanel() {
        let pdf = URL(fileURLWithPath: "/tmp/report.pdf")
        let otherPDF = URL(fileURLWithPath: "/tmp/notes.pdf")
        let png = URL(fileURLWithPath: "/tmp/photo.png")
        let zip = URL(fileURLWithPath: "/tmp/archive.zip")
        let supportsAll: (URL) -> Bool = { _ in true }
        XCTAssertEqual(
            QuickCapturePolicy.actions(for: .files([pdf, otherPDF]), fileSupportsPanel: supportsAll),
            [.addToFileShelf]
        )
        XCTAssertEqual(
            QuickCapturePolicy.actions(for: .files([pdf, png]), fileSupportsPanel: supportsAll),
            [.addToFileShelf]
        )
        XCTAssertEqual(
            QuickCapturePolicy.actions(
                for: .files([pdf, zip]),
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

    func testCreateTextPanelCallsOnlyTextPanelAPI() {
        var panels: [String] = []
        let destinations = trackingDestinations(
            createTextPanel: { panels.append($0); return true }
        )
        let result = QuickCaptureExecutor.perform(
            .createTextPanel,
            content: .text("pin me"),
            destinations: destinations
        )
        XCTAssertEqual(result, .succeeded)
        XCTAssertEqual(panels, ["pin me"])
    }

    func testCreateTodoPanelCallsOnlyTodoPanelAPI() {
        var todos: [String] = []
        let destinations = trackingDestinations(
            createTodoPanel: { todos.append($0); return true }
        )
        XCTAssertEqual(
            QuickCaptureExecutor.perform(
                .createTodoPanel,
                content: .text("Send email"),
                destinations: destinations
            ),
            .succeeded
        )
        XCTAssertEqual(todos, ["Send email"])
    }

    func testMultilineTodoIsRejectedWithoutCallingTodoAPI() {
        let destinations = trackingDestinations()
        XCTAssertEqual(
            QuickCaptureExecutor.perform(
                .createTodoPanel,
                content: .text("Line 1\nLine 2"),
                destinations: destinations
            ),
            .failed(QuickCaptureCopy.todoMustBeSingleLine)
        )
    }

    func testCarriageReturnAndCRLFTodosAreRejected() {
        let destinations = trackingDestinations()
        XCTAssertEqual(
            QuickCaptureExecutor.perform(
                .createTodoPanel,
                content: .text("Line 1\rLine 2"),
                destinations: destinations
            ),
            .failed(QuickCaptureCopy.todoMustBeSingleLine)
        )
        XCTAssertEqual(
            QuickCaptureExecutor.perform(
                .createTodoPanel,
                content: .text("Line 1\r\nLine 2"),
                destinations: destinations
            ),
            .failed(QuickCaptureCopy.todoMustBeSingleLine)
        )
    }

    func testCreateTodoPanelForURLDoesNotCallDestinations() {
        let destinations = trackingDestinations()
        XCTAssertEqual(
            QuickCaptureExecutor.perform(
                .createTodoPanel,
                content: .url("https://example.com"),
                destinations: destinations
            ),
            .failed(GlanceNoticeCopy.cannotSave)
        )
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
            QuickCaptureExecutor.perform(.createFilePanel, content: .files([url]), destinations: destinations),
            .succeeded
        )
        XCTAssertEqual(pdfs, [url])
    }

    func testCreateFilePanelForMultipleFilesFailsWithoutCallingPanelAPIs() {
        let pdf1 = URL(fileURLWithPath: "/tmp/one.pdf")
        let pdf2 = URL(fileURLWithPath: "/tmp/two.pdf")
        let destinations = trackingDestinations()
        XCTAssertEqual(
            QuickCaptureExecutor.perform(
                .createFilePanel,
                content: .files([pdf1, pdf2]),
                destinations: destinations
            ),
            .failed(GlanceNoticeCopy.panelCreateFailed)
        )
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
        createTodoPanel: @escaping (String) -> Bool = { _ in
            XCTFail("todo panel"); return false
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
            createTodoPanel: createTodoPanel,
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
            createTodoPanel: { _ in false },
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
            createTodoPanel: { _ in false },
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

    func testTodoActionDisallowsNewline() {
        let model = QuickCaptureModel()
        model.setText("Buy milk")
        model.select(.createTodoPanel)
        XCTAssertEqual(model.selectedAction, .createTodoPanel)
        XCTAssertFalse(model.allowsNewline)
    }

    func testSnippetAndTextPanelAllowNewline() {
        let model = QuickCaptureModel()
        model.setText("Buy milk")
        XCTAssertEqual(model.selectedAction, .saveSnippet)
        XCTAssertTrue(model.allowsNewline)
        model.select(.createTextPanel)
        XCTAssertTrue(model.allowsNewline)
    }

    func testNewlinePermissionFollowsActionSwitching() {
        let model = QuickCaptureModel()
        model.setText("Buy milk")
        XCTAssertEqual(model.selectedAction, .saveSnippet)
        XCTAssertTrue(model.allowsNewline)
        model.moveAction(1)
        XCTAssertEqual(model.selectedAction, .createTextPanel)
        XCTAssertTrue(model.allowsNewline)
        model.moveAction(1)
        XCTAssertEqual(model.selectedAction, .createTodoPanel)
        XCTAssertFalse(model.allowsNewline)
        model.moveAction(1)
        XCTAssertEqual(model.selectedAction, .saveSnippet)
        XCTAssertTrue(model.allowsNewline)
    }

    func testMultilineTodoSubmitKeepsOriginalText() {
        let model = QuickCaptureModel()
        model.setText("Line 1\nLine 2")
        model.select(.createTodoPanel)
        let destinations = QuickCaptureDestinations(
            saveSnippet: { _ in .failed("snippet") },
            saveLink: { _ in .failed("link") },
            addToFileShelf: { _ in .failed("files") },
            createTextPanel: { _ in false },
            createTodoPanel: { _ in XCTFail("todo panel"); return false },
            createImagePanel: { _ in false },
            createPDFPanel: { _ in false }
        )
        XCTAssertFalse(model.submit(using: destinations))
        XCTAssertFalse(model.didComplete)
        XCTAssertEqual(model.text, "Line 1\nLine 2")
        XCTAssertEqual(model.content, .text("Line 1\nLine 2"))
        XCTAssertEqual(model.selectedAction, .createTodoPanel)
        XCTAssertEqual(model.error, QuickCaptureCopy.todoMustBeSingleLine)
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
            createTodoPanel: { _ in false },
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
        XCTAssertEqual(model.selectedAction, .createTextPanel)
        model.moveAction(1)
        XCTAssertEqual(model.selectedAction, .saveSnippet)
        XCTAssertEqual(model.content, .url("https://example.com"))
    }

    func testFileShelfPartialFailureKeepsFilesAndDoesNotComplete() {
        let model = QuickCaptureModel()
        let first = URL(fileURLWithPath: "/tmp/a.txt")
        let second = URL(fileURLWithPath: "/tmp/b.txt")
        let third = URL(fileURLWithPath: "/tmp/c.txt")
        model.setFiles([first, second, third])
        let failed = QuickCaptureDestinations(
            saveSnippet: { _ in .failed("snippet") },
            saveLink: { _ in .failed("link") },
            addToFileShelf: { urls in
                QuickCaptureFileShelfAddPolicy.outcome(
                    for: FileShelfAddResult(
                        addedIDs: [UUID(), UUID()],
                        failed: 1
                    ),
                    inputCount: urls.count
                )
            },
            createTextPanel: { _ in false },
            createTodoPanel: { _ in false },
            createImagePanel: { _ in false },
            createPDFPanel: { _ in false }
        )
        XCTAssertFalse(model.submit(using: failed))
        XCTAssertEqual(model.content, .files([
            URL(fileURLWithPath: FileShelfIdentity.standardizedPath(for: first)),
            URL(fileURLWithPath: FileShelfIdentity.standardizedPath(for: second)),
            URL(fileURLWithPath: FileShelfIdentity.standardizedPath(for: third))
        ]))
        XCTAssertEqual(model.error, GlanceNoticeCopy.fileShelfPartialAddFailed)
        XCTAssertFalse(model.didComplete)
    }
}

final class QuickCaptureFileShelfAddPolicyTests: XCTestCase {
    func testAddedAndUpdatedCountAsCompleteSuccess() {
        XCTAssertEqual(
            QuickCaptureFileShelfAddPolicy.outcome(
                for: FileShelfAddResult(
                    addedIDs: [UUID()],
                    updatedIDs: [UUID()]
                ),
                inputCount: 2
            ),
            .succeeded
        )
    }

    func testPartialFailureWhenSomeAddsFail() {
        XCTAssertEqual(
            QuickCaptureFileShelfAddPolicy.outcome(
                for: FileShelfAddResult(
                    addedIDs: [UUID(), UUID()],
                    failed: 1
                ),
                inputCount: 3
            ),
            .failed(GlanceNoticeCopy.fileShelfPartialAddFailed)
        )
    }

    func testRejectedDirectoryIsPartialFailure() {
        XCTAssertEqual(
            QuickCaptureFileShelfAddPolicy.outcome(
                for: FileShelfAddResult(
                    addedIDs: [UUID()],
                    rejectedDirectories: 1
                ),
                inputCount: 2
            ),
            .failed(GlanceNoticeCopy.fileShelfPartialAddFailed)
        )
    }

    func testCompleteFailureUsesGenericMessage() {
        XCTAssertEqual(
            QuickCaptureFileShelfAddPolicy.outcome(
                for: FileShelfAddResult(failed: 2),
                inputCount: 2
            ),
            .failed(GlanceNoticeCopy.fileShelfAddFailed)
        )
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

    func testShiftReturnSubmitsWhenNewlineIsDisallowed() {
        XCTAssertEqual(
            QuickCaptureKeyPolicy.intent(
                keyCode: 36,
                command: false,
                shift: true,
                isComposing: false,
                allowsNewline: false
            ),
            .submit
        )
        XCTAssertEqual(
            QuickCaptureReturn.action(isComposing: false, shift: true, allowsNewline: false),
            .submit
        )
    }
}
