import AppKit
import Foundation
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class QuickCaptureRequestTests: XCTestCase {
    func testTextRequestNormalizesAndMapsKind() {
        let request = QuickCaptureRequest(kind: .text, text: "  Hello Glance  ")
        XCTAssertEqual(request.normalizedText, "Hello Glance")
        XCTAssertTrue(request.isValid)
        XCTAssertEqual(request.kindIdentifier, PanelKind.text)
        XCTAssertEqual(request.initialContent(), .plainText("Hello Glance"))
    }

    func testTodoRequestMapsToSingleItemIntent() {
        let request = QuickCaptureRequest(kind: .todo, text: "\nSend email\n")
        XCTAssertEqual(request.normalizedText, "Send email")
        XCTAssertTrue(request.isValid)
        XCTAssertEqual(request.kindIdentifier, PanelKind.todo)
        XCTAssertEqual(request.initialContent(), .todoTitle("Send email"))
    }

    func testMultilineTextKeepsInnerNewlines() {
        let request = QuickCaptureRequest(kind: .text, text: "  Line 1\nLine 2\n  ")
        XCTAssertEqual(request.normalizedText, "Line 1\nLine 2")
        XCTAssertEqual(request.initialContent(), .plainText("Line 1\nLine 2"))
    }

    func testEmptyAndWhitespaceRequestsAreRejected() {
        for text in ["", "   ", "\n\t", " \n "] {
            let request = QuickCaptureRequest(kind: .text, text: text)
            XCTAssertEqual(request.normalizedText, "")
            XCTAssertFalse(request.isValid)
            XCTAssertNil(request.initialContent())
        }
    }

    func testHotKeyIdentifiersDoNotCollide() {
        XCTAssertNotEqual(GlanceHotKeyID.hideShow.rawValue, GlanceHotKeyID.quickCapture.rawValue)
        XCTAssertEqual(GlanceHotKeyID.hideShow.rawValue, 1)
        XCTAssertEqual(GlanceHotKeyID.quickCapture.rawValue, 2)
        XCTAssertEqual(GlanceHotKeyID.clipboardCapture.rawValue, 3)
        XCTAssertEqual(GlanceHotKeyID.fileShelf.rawValue, 5)
        XCTAssertNotEqual(GlanceConstants.quickCaptureKeyEquivalent, GlanceConstants.hideShowKeyEquivalent)
        XCTAssertNotEqual(GlanceConstants.clipboardCaptureKeyEquivalent, GlanceConstants.quickCaptureKeyEquivalent)
        XCTAssertEqual(GlanceConstants.quickCaptureKeyEquivalent, "j")
        XCTAssertEqual(GlanceConstants.quickCaptureShortcutDisplay, "⌥⌘J")
        XCTAssertEqual(GlanceConstants.clipboardCaptureShortcutDisplay, "⌥⌘B")
    }
}

@MainActor
final class QuickCaptureReturnTests: XCTestCase {
    func testReturnSubmitsWhenNotComposing() {
        XCTAssertEqual(
            QuickCaptureReturn.action(isComposing: false, shift: false, allowsNewline: true),
            .submit
        )
    }

    func testShiftReturnInsertsNewlineOnlyWhenAllowed() {
        XCTAssertEqual(
            QuickCaptureReturn.action(isComposing: false, shift: true, allowsNewline: true),
            .insertNewline
        )
        XCTAssertEqual(
            QuickCaptureReturn.action(isComposing: false, shift: true, allowsNewline: false),
            .submit
        )
    }

    func testComposingReturnConfirmsInputMethod() {
        XCTAssertEqual(
            QuickCaptureReturn.action(isComposing: true, shift: false, allowsNewline: true),
            .confirmComposition
        )
    }

    func testInsertNewlineSubmitsInsteadOfInserting() {
        let view = QuickCaptureTextView(usingTextLayoutManager: false)
        var submitted = 0
        view.onSubmit = { submitted += 1 }
        view.string = "hello"
        view.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        XCTAssertEqual(submitted, 1)
        XCTAssertEqual(view.string, "hello")
    }

    func testInsertLineBreakSubmits() {
        let view = QuickCaptureTextView(usingTextLayoutManager: false)
        var submitted = 0
        view.onSubmit = { submitted += 1 }
        view.doCommand(by: #selector(NSResponder.insertLineBreak(_:)))
        XCTAssertEqual(submitted, 1)
    }

    func testCapturePanelConsumesReturnAsKeyEquivalent() {
        let controller = QuickCaptureWindowController()
        var submitted = false
        controller.onSubmit = { request, _ in
            submitted = request.isValid
            return true
        }
        controller.present()
        defer { controller.cancel() }
        let view = controller.window?.initialFirstResponder as? QuickCaptureTextView
        view?.string = "from guide"
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: controller.window?.windowNumber ?? 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
        XCTAssertEqual(controller.window?.performKeyEquivalent(with: try XCTUnwrap(event)), true)
        XCTAssertTrue(submitted)
    }
}

final class QuickCapturePlaceholderTests: XCTestCase {
    func testPlaceholderDrawsOnlyWhenEmptyAndIdle() {
        XCTAssertTrue(QuickCapturePlaceholderLayout.shouldDraw(text: "", isComposing: false))
        XCTAssertFalse(QuickCapturePlaceholderLayout.shouldDraw(text: "", isComposing: true))
        XCTAssertFalse(QuickCapturePlaceholderLayout.shouldDraw(text: "hello", isComposing: false))
    }

    func testPlaceholderOriginFollowsTextContainerAndLinePadding() {
        let origin = QuickCapturePlaceholderLayout.origin(
            containerOrigin: NSPoint(x: 2, y: 4),
            extraLineFragment: NSRect(x: 0, y: 1, width: 100, height: 16),
            lineFragmentPadding: 5
        )
        XCTAssertEqual(origin, NSPoint(x: 7, y: 5))
    }

    @MainActor
    func testTextViewPlaceholderOriginMatchesInsertionLine() {
        let view = QuickCaptureTextView(usingTextLayoutManager: false)
        view.font = GlanceTheme.Typography.body
        view.textContainer?.lineFragmentPadding = 0
        view.textContainerInset = NSSize(width: 0, height: GlanceTheme.Space.xxs)
        view.frame = NSRect(x: 0, y: 0, width: 400, height: 88)
        view.textContainer?.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        view.string = ""
        let origin = view.placeholderOrigin
        XCTAssertEqual(origin.x, view.textContainerOrigin.x, accuracy: 0.5)
        XCTAssertEqual(origin.y, view.textContainerOrigin.y, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(origin.y, 0)
    }
}
