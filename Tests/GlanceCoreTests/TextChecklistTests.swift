import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class TextChecklistToggleTests: XCTestCase {
    func testMarkIndexFindsBoxAndFollowingSpace() {
        XCTAssertEqual(TextChecklistToggle.markIndex(in: "☐ 你好" as NSString, at: 0), 0)
        XCTAssertEqual(TextChecklistToggle.markIndex(in: "☐ 你好" as NSString, at: 1), 0)
        XCTAssertNil(TextChecklistToggle.markIndex(in: "☐ 你好" as NSString, at: 2))
        XCTAssertNil(TextChecklistToggle.markIndex(in: "你好" as NSString, at: 0))
    }

    func testSpansCoverTheLineAfterTheBox() {
        let spans = TextChecklistToggle.spans(in: "☐ 你好" as NSString, markIndex: 0)
        XCTAssertEqual(spans?.markRange, NSRange(location: 0, length: 1))
        XCTAssertEqual(spans?.contentRange, NSRange(location: 1, length: 3))
        XCTAssertEqual(spans?.usesCheckedGlyph, false)
    }

    func testCheckedGlyphCountsAsCompleted() {
        XCTAssertTrue(TextChecklistToggle.isCompleted(usesCheckedGlyph: true, contentHasStrikethrough: false))
        XCTAssertTrue(TextChecklistToggle.isCompleted(usesCheckedGlyph: false, contentHasStrikethrough: true))
        XCTAssertFalse(TextChecklistToggle.isCompleted(usesCheckedGlyph: false, contentHasStrikethrough: false))
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
    func testClickingBoxStrikesThroughTheItem() throws {
        let view = try makeChecklistView(reading: false, text: "☐ 你好")
        XCTAssertTrue(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 0)))
        XCTAssertTrue(view.string.hasPrefix("☐"))
        XCTAssertFalse(view.string.hasPrefix("☑"))
        XCTAssertTrue(hasStrikethrough(in: view, at: 2))
        XCTAssertFalse(hasStrikethrough(in: view, at: 0))
    }

    func testClickingBoxAgainClearsTheStrike() throws {
        let view = try makeChecklistView(reading: false, text: "☐ 你好")
        XCTAssertTrue(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 0)))
        view.layoutManager?.ensureLayout(for: try XCTUnwrap(view.textContainer))
        XCTAssertTrue(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 0)))
        XCTAssertTrue(view.string.hasPrefix("☐"))
        XCTAssertFalse(hasStrikethrough(in: view, at: 2))
    }

    func testClickingBoxInReadingModeStrikesThrough() throws {
        let view = try makeChecklistView(reading: true, text: "☐ 你好")
        XCTAssertTrue(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 0)))
        XCTAssertTrue(hasStrikethrough(in: view, at: 2))
    }

    func testLegacyCheckedGlyphConvertsToStrike() throws {
        let view = try makeChecklistView(reading: false, text: "☑ 你好")
        view.refreshChecklistMarks()
        XCTAssertTrue(view.string.hasPrefix("☐"))
        XCTAssertTrue(hasStrikethrough(in: view, at: 2))
    }

    func testClickingTheLabelDoesNotToggle() throws {
        let view = try makeChecklistView(reading: false, text: "☐ 你好")
        XCTAssertFalse(view.toggleChecklist(atViewPoint: glyphCenter(in: view, glyphIndex: 2)))
        XCTAssertTrue(view.string.hasPrefix("☐"))
        XCTAssertFalse(hasStrikethrough(in: view, at: 2))
    }

    func testInsertedChecklistMarkIsLargerThanBody() {
        let view = GlanceTextView(usingTextLayoutManager: false)
        view.font = GlanceConstants.textBodyFont
        view.string = "hello"
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.insertChecklist()
        let font = view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, TextChecklistToggle.markSize)
        XCTAssertGreaterThan(TextChecklistToggle.markSize, GlanceConstants.textBodyFont.pointSize)
        XCTAssertTrue(view.string.hasPrefix("☐"))
    }

    private func makeChecklistView(reading: Bool, text: String) throws -> GlanceTextView {
        let view = GlanceTextView(usingTextLayoutManager: false)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainerInset = GlanceTheme.Size.readingInset
        view.textContainer?.widthTracksTextView = false
        view.font = GlanceConstants.textBodyFont
        view.string = text
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

    private func hasStrikethrough(in view: GlanceTextView, at index: Int) -> Bool {
        guard let storage = view.textStorage, index < storage.length else { return false }
        let value = storage.attribute(.strikethroughStyle, at: index, effectiveRange: nil)
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let style = value as? Int { return style != 0 }
        return false
    }
}

final class PanelReadingClickTests: XCTestCase {
    func testTextContentClickBeginsEditing() {
        XCTAssertEqual(
            PanelReadingClick.textAction(hitsChecklist: false, allowsContentMutation: true),
            .beginEditing
        )
    }

    func testTextChecklistClickTogglesInsteadOfEditing() {
        XCTAssertEqual(
            PanelReadingClick.textAction(hitsChecklist: true, allowsContentMutation: true),
            .toggleChecklist
        )
    }

    func testTextPaddingClickBeginsEditing() {
        XCTAssertEqual(
            PanelReadingClick.textAction(hitsChecklist: false, allowsContentMutation: true),
            .beginEditing
        )
    }

    func testLockedTextClickSelects() {
        XCTAssertEqual(
            PanelReadingClick.textAction(hitsChecklist: false, allowsContentMutation: false),
            .selectText
        )
    }

    func testMarkdownLinkClickOpensTheLink() {
        XCTAssertEqual(
            PanelReadingClick.markdownAction(hitsLink: true, allowsContentMutation: true),
            .followLink
        )
    }

    func testMarkdownContentClickBeginsEditing() {
        XCTAssertEqual(
            PanelReadingClick.markdownAction(hitsLink: false, allowsContentMutation: true),
            .beginEditing
        )
    }
}
