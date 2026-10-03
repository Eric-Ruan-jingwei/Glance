import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class MarkdownPanelProviderTests: XCTestCase {
    func testKindAndPayloadVersion() {
        XCTAssertEqual(MarkdownPanelProvider.kindIdentifier, "com.glance.panel.markdown")
        XCTAssertEqual(MarkdownPanelProvider.payloadVersion, 1)
        XCTAssertEqual(GlanceConstants.payloadVersionMarkdown, 1)
        XCTAssertEqual(PanelKind.markdown, "com.glance.panel.markdown")
    }

    func testDefaultSize() {
        XCTAssertEqual(MarkdownPanelProvider.defaultSize.width, 420)
        XCTAssertEqual(MarkdownPanelProvider.defaultSize.height, 320)
        XCTAssertEqual(MarkdownPanelProvider.minimumSize.width, 220)
        XCTAssertEqual(MarkdownPanelProvider.minimumSize.height, 140)
        XCTAssertEqual(MarkdownPanelProvider.defaultSize, GlanceConstants.markdownDefaultSize)
        XCTAssertEqual(MarkdownPanelProvider.minimumSize, GlanceConstants.markdownMinSize)
    }

    func testMarkdownRecordKeepsFlatGeometry() throws {
        let record = PanelRecord(
            kindIdentifier: PanelKind.markdown,
            frame: PanelFrame(x: 40, y: 80, width: 420, height: 320),
            displayIdentifier: "1",
            payloadPath: "Panels/markdown-id",
            payloadVersion: 1
        )
        let data = try PanelDatabaseCodec.encode(
            PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: [record])
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let panel = try XCTUnwrap((root["panels"] as? [[String: Any]])?.first)
        XCTAssertEqual(panel["kindIdentifier"] as? String, PanelKind.markdown)
        XCTAssertEqual((panel["x"] as? NSNumber)?.doubleValue, 40)
        XCTAssertEqual((panel["width"] as? NSNumber)?.doubleValue, 420)
        XCTAssertNil(panel["frame"])
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)

        let decoded = try PanelDatabaseCodec.decode(from: data)
        let restored = try XCTUnwrap(decoded.database.panels.first)
        XCTAssertEqual(restored.kindIdentifier, PanelKind.markdown)
        XCTAssertEqual(restored.frame, record.frame)
        XCTAssertEqual(restored.payloadVersion, 1)
    }

    func testMenuInsertsMarkdownBetweenTextAndImage() {
        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            onQuickCapture: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
        let titles = menu.items.map(\.title)
        XCTAssertEqual(titles[0], "快速记录…")
        XCTAssertEqual(titles[1], "从剪贴板创建…")
        XCTAssertEqual(titles[3], "管理面板…")
        XCTAssertEqual(titles[5], "新建文字面板")
        XCTAssertEqual(titles[6], "新建 Markdown 面板")
        XCTAssertEqual(titles[7], "新建待办面板")
        XCTAssertEqual(titles[8], "新建图片面板")
        XCTAssertEqual(titles[9], "新建 PDF 面板…")
    }
}
