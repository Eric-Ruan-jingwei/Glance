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
        XCTAssertNotEqual(GlanceConstants.quickCaptureKeyEquivalent, GlanceConstants.hideShowKeyEquivalent)
        XCTAssertEqual(GlanceConstants.quickCaptureKeyEquivalent, "j")
        XCTAssertEqual(GlanceConstants.quickCaptureShortcutDisplay, "⌥⌘J")
    }
}
