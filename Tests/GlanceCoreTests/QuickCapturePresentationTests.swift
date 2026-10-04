import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class QuickCapturePresentationTests: XCTestCase {
    func testActionSymbolsAreStableAndNonEmpty() {
        let mappings: [(QuickCaptureAction, String)] = [
            (.saveSnippet, QuickCaptureActionPresentation.saveSnippetSymbol),
            (.saveLink, QuickCaptureActionPresentation.saveLinkSymbol),
            (.addToFileShelf, QuickCaptureActionPresentation.addToFileShelfSymbol),
            (.createTextPanel, PanelKindSymbol.name(for: PanelKind.text)),
            (.createTodoPanel, PanelKindSymbol.name(for: PanelKind.todo)),
            (.createFilePanel, QuickCaptureActionPresentation.genericFilePanelSymbol)
        ]
        for (action, expected) in mappings {
            let symbol = QuickCaptureActionPresentation.symbolName(for: action)
            XCTAssertFalse(symbol.isEmpty, action.identifier)
            XCTAssertEqual(symbol, expected, action.identifier)
        }
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.text), "doc.text")
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.todo), "checklist")
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.image), "photo")
        XCTAssertEqual(PanelKindSymbol.name(for: PanelKind.pdf), "doc.richtext")
    }

    func testCreateFilePanelReusesPanelKindSymbolsWhenTypeIsKnown() {
        let image = URL(fileURLWithPath: "/tmp/photo.png")
        let pdf = URL(fileURLWithPath: "/tmp/brief.pdf")
        let zip = URL(fileURLWithPath: "/tmp/archive.zip")
        XCTAssertEqual(
            QuickCaptureActionPresentation.symbolName(
                for: .createFilePanel,
                content: .files([image])
            ),
            PanelKindSymbol.name(for: PanelKind.image)
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.symbolName(
                for: .createFilePanel,
                content: .files([pdf])
            ),
            PanelKindSymbol.name(for: PanelKind.pdf)
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.symbolName(
                for: .createFilePanel,
                content: .files([zip])
            ),
            QuickCaptureActionPresentation.genericFilePanelSymbol
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.symbolName(
                for: .createFilePanel,
                content: .files([image, pdf])
            ),
            QuickCaptureActionPresentation.genericFilePanelSymbol
        )
    }

    func testDestinationLabelsAreChineseToolNames() {
        XCTAssertEqual(
            QuickCaptureActionPresentation.destinationLabel(for: .saveSnippet),
            "片段库"
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.destinationLabel(for: .saveLink),
            "链接库"
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.destinationLabel(for: .addToFileShelf),
            "文件架"
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.destinationLabel(for: .createTextPanel),
            "面板"
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.destinationLabel(for: .createTodoPanel),
            "面板"
        )
        XCTAssertEqual(
            QuickCaptureActionPresentation.destinationLabel(for: .createFilePanel),
            "面板"
        )
    }

    func testSelectedStateFollowsModel() {
        XCTAssertTrue(
            QuickCaptureActionPresentation.isSelected(.saveSnippet, selectedAction: .saveSnippet)
        )
        XCTAssertFalse(
            QuickCaptureActionPresentation.isSelected(.createTextPanel, selectedAction: .saveSnippet)
        )
        XCTAssertFalse(
            QuickCaptureActionPresentation.isSelected(.saveLink, selectedAction: nil)
        )
        XCTAssertEqual(
            QuickCapturePolicy.defaultAction(for: .text("明天上午整理产品需求")),
            .saveSnippet
        )
        XCTAssertEqual(
            QuickCapturePolicy.defaultAction(for: .url("https://example.com")),
            .saveLink
        )
        XCTAssertEqual(
            QuickCapturePolicy.defaultAction(
                for: .files([URL(fileURLWithPath: "/tmp/photo.png")])
            ),
            .addToFileShelf
        )
    }

    func testDetectedSymbolsDoNotReuseDestinationIconsForText() {
        XCTAssertNil(QuickCaptureDetectedPresentation.symbolName(for: .empty))
        XCTAssertEqual(
            QuickCaptureDetectedPresentation.symbolName(for: .text("hello")),
            "text.alignleft"
        )
        XCTAssertEqual(
            QuickCaptureDetectedPresentation.symbolName(for: .url("https://example.com")),
            "link"
        )
        XCTAssertEqual(
            QuickCaptureDetectedPresentation.symbolName(
                for: .files([URL(fileURLWithPath: "/tmp/photo.png")])
            ),
            "doc.on.doc"
        )
        XCTAssertNotEqual(
            QuickCaptureDetectedPresentation.symbolName(for: .text("hello")),
            QuickCaptureActionPresentation.symbolName(for: .saveSnippet)
        )
        XCTAssertNotEqual(
            QuickCaptureDetectedPresentation.symbolName(
                for: .files([URL(fileURLWithPath: "/tmp/photo.png")])
            ),
            QuickCaptureActionPresentation.symbolName(for: .addToFileShelf)
        )
    }

    func testActionOrderIsUnchanged() {
        XCTAssertEqual(
            QuickCapturePolicy.actions(for: .text("明天上午整理产品需求")),
            [.saveSnippet, .createTextPanel, .createTodoPanel]
        )
        XCTAssertEqual(
            QuickCapturePolicy.actions(for: .url("https://example.com")),
            [.saveLink, .createTextPanel, .saveSnippet]
        )
        XCTAssertEqual(
            QuickCapturePolicy.actions(
                for: .files([URL(fileURLWithPath: "/tmp/photo.png")])
            ),
            [.addToFileShelf, .createFilePanel]
        )
    }
}

@MainActor
final class QuickCaptureActionRowAccessibilityTests: XCTestCase {
    func testSelectedRowExposesTitleDestinationAndSelectedValue() {
        let row = QuickCaptureActionRowView(
            action: .saveSnippet,
            content: .text("明天上午整理产品需求"),
            isSelected: true
        )
        XCTAssertEqual(row.accessibilityLabel(), "保存为片段")
        XCTAssertEqual(row.accessibilityHelp(), "片段库")
        XCTAssertEqual(row.accessibilityValue() as? String, "已选择")
        XCTAssertEqual(row.accessibilityRole(), .button)
        row.isSelected = false
        XCTAssertNil(row.accessibilityValue())
    }
}
