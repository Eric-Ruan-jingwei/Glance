import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelTagChipAccessibilityTests: XCTestCase {
    func testReadOnlyTagHasInformationalSemantics() {
        let kind = PanelTagChipAccessibility.kind(onRemove: false, onAdd: false)
        XCTAssertEqual(kind, .readOnly)
        XCTAssertEqual(kind.label(for: "具身智能"), "标签：具身智能")
        XCTAssertFalse(kind.isButton)
        var called = false
        kind.activate(onRemove: { called = true }, onAdd: { called = true })
        XCTAssertFalse(called)
    }

    func testRemovableTagExposesRemoveSemantics() {
        let kind = PanelTagChipAccessibility.kind(onRemove: true, onAdd: false)
        XCTAssertEqual(kind, .remove)
        XCTAssertEqual(kind.label(for: "API"), "移除标签：API")
        XCTAssertTrue(kind.isButton)
    }

    func testRemovableAccessibilityActionReachesOnRemove() {
        let session = PanelTagEditorSession(tags: ["API", "论文"], catalog: [])
        let kind = PanelTagChipAccessibility.kind(onRemove: true, onAdd: false)
        kind.activate(
            onRemove: { session.remove("API") },
            onAdd: { XCTFail("remove must not invoke add") }
        )
        XCTAssertEqual(session.draft, ["论文"])
        kind.activate(onRemove: { session.remove("论文") }, onAdd: nil)
        XCTAssertTrue(session.draft.isEmpty)
    }

    func testSuggestionTagExposesAddSemantics() {
        let kind = PanelTagChipAccessibility.kind(onRemove: false, onAdd: true)
        XCTAssertEqual(kind, .addSuggestion)
        XCTAssertEqual(kind.label(for: "具身智能"), "添加标签：具身智能")
        XCTAssertTrue(kind.isButton)
    }

    func testSuggestionAccessibilityActionReachesAddCallback() {
        let session = PanelTagEditorSession(tags: ["API"], catalog: ["API", "论文", "必读"])
        XCTAssertEqual(session.suggestions, ["论文", "必读"])
        let kind = PanelTagChipAccessibility.kind(onRemove: false, onAdd: true)
        kind.activate(
            onRemove: { XCTFail("add must not invoke remove") },
            onAdd: { session.addSuggestion("论文") }
        )
        XCTAssertEqual(session.draft, ["API", "论文"])
        XCTAssertFalse(session.suggestions.contains("论文"))
    }

    func testRemoveTakesPrecedenceOverAddWhenBothArePresent() {
        let kind = PanelTagChipAccessibility.kind(onRemove: true, onAdd: true)
        XCTAssertEqual(kind, .remove)
        var removed = false
        var added = false
        kind.activate(onRemove: { removed = true }, onAdd: { added = true })
        XCTAssertTrue(removed)
        XCTAssertFalse(added)
    }
}
