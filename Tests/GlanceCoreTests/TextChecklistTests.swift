import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class TextChecklistToggleTests: XCTestCase {
    func testUncheckedBoxBecomesChecked() {
        let change = TextChecklistToggle.replacement(in: "☐ 你好" as NSString, at: 0)
        XCTAssertEqual(change?.range, NSRange(location: 0, length: 1))
        XCTAssertEqual(change?.replacement, "☑")
    }

    func testCheckedBoxBecomesUnchecked() {
        let change = TextChecklistToggle.replacement(in: "☑ 你好" as NSString, at: 0)
        XCTAssertEqual(change?.range, NSRange(location: 0, length: 1))
        XCTAssertEqual(change?.replacement, "☐")
    }

    func testSpaceAfterBoxStillTogglesTheMark() {
        let change = TextChecklistToggle.replacement(in: "☐ 你好" as NSString, at: 1)
        XCTAssertEqual(change?.range, NSRange(location: 0, length: 1))
        XCTAssertEqual(change?.replacement, "☑")
    }

    func testOrdinaryTextDoesNotToggle() {
        XCTAssertNil(TextChecklistToggle.replacement(in: "☐ 你好" as NSString, at: 2))
        XCTAssertNil(TextChecklistToggle.replacement(in: "你好" as NSString, at: 0))
    }

    func testContainerPointSubtractsTextOrigin() {
        let point = TextChecklistToggle.containerPoint(
            viewPoint: NSPoint(x: 21, y: 16),
            containerOrigin: NSPoint(x: 16, y: 12)
        )
        XCTAssertEqual(point, NSPoint(x: 5, y: 4))
    }

    func testHitSlopIncludesPaddingAroundGlyph() {
        let bounds = NSRect(x: 10, y: 10, width: 12, height: 14)
        XCTAssertTrue(
            TextChecklistToggle.hitsGlyph(
                containerPoint: NSPoint(x: 9, y: 9),
                glyphBounds: bounds
            )
        )
        XCTAssertFalse(
            TextChecklistToggle.hitsGlyph(
                containerPoint: NSPoint(x: 40, y: 10),
                glyphBounds: bounds
            )
        )
    }
}

@MainActor
final class TextChecklistClickTests: XCTestCase {
    func testClickingBoxInEditingModeChecksTheItem() throws {
        let view = try makeChecklistView(reading: false)
        XCTAssertTrue(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 0)))
        XCTAssertTrue(view.string.hasPrefix("☑"))
    }

    func testClickingBoxInReadingModeChecksTheItem() throws {
        let view = try makeChecklistView(reading: true)
        XCTAssertTrue(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 0)))
        XCTAssertTrue(view.string.hasPrefix("☑"))
    }

    func testClickingTheLabelDoesNotToggle() throws {
        let view = try makeChecklistView(reading: false)
        XCTAssertFalse(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 2)))
        XCTAssertTrue(view.string.hasPrefix("☐"))
    }

    private func makeChecklistView(reading: Bool) throws -> GlanceTextView {
        let view = GlanceTextView(usingTextLayoutManager: false)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainerInset = GlanceTheme.Size.readingInset
        view.textContainer?.widthTracksTextView = false
        view.font = GlanceConstants.textBodyFont
        view.string = "☐ 你好"
        view.isReadingMode = reading
        view.isEditable = !reading
        view.allowsContentMutation = true
        view.frame = NSRect(x: 0, y: 0, width: 320, height: 200)
        let textContainer = try XCTUnwrap(view.textContainer)
        textContainer.containerSize = NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
        view.layoutManager?.ensureLayout(for: textContainer)
        return view
    }

    private func glyphCenter(in view: GlanceTextView, glyphIndex: Int) -> NSPoint {
        let layoutManager = try! XCTUnwrap(view.layoutManager)
        let textContainer = try! XCTUnwrap(view.textContainer)
        layoutManager.ensureLayout(for: textContainer)
        XCTAssertGreaterThan(layoutManager.numberOfGlyphs, glyphIndex)
        let bounds = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        let origin = view.textContainerOrigin
        return NSPoint(x: origin.x + bounds.midX, y: origin.y + bounds.midY)
    }
}

final class PanelReadingClickTests: XCTestCase {
    func testTextContentClickBeginsEditing() {
        XCTAssertEqual(
            PanelReadingClick.textAction(isInText: true, hitsChecklist: false, allowsContentMutation: true),
            .beginEditing
        )
    }

    func testTextChecklistClickTogglesInsteadOfEditing() {
        XCTAssertEqual(
            PanelReadingClick.textAction(isInText: true, hitsChecklist: true, allowsContentMutation: true),
            .toggleChecklist
        )
    }

    func testTextPaddingClickMovesThePanel() {
        XCTAssertEqual(
            PanelReadingClick.textAction(isInText: false, hitsChecklist: false, allowsContentMutation: true),
            .movePanel
        )
    }

    func testLockedTextClickSelects() {
        XCTAssertEqual(
            PanelReadingClick.textAction(isInText: true, hitsChecklist: false, allowsContentMutation: false),
            .selectText
        )
    }

    func testMarkdownLinkClickOpensTheLink() {
        XCTAssertEqual(
            PanelReadingClick.markdownAction(isInText: true, hitsLink: true, allowsContentMutation: true),
            .followLink
        )
    }

    func testMarkdownContentClickBeginsEditing() {
        XCTAssertEqual(
            PanelReadingClick.markdownAction(isInText: true, hitsLink: false, allowsContentMutation: true),
            .beginEditing
        )
    }
}
