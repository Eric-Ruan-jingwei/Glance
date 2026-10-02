import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class TodoPanelProviderTests: XCTestCase {
    func testKindAndPayloadVersion() {
        XCTAssertEqual(TodoPanelProvider.kindIdentifier, "com.glance.panel.todo")
        XCTAssertEqual(TodoPanelProvider.payloadVersion, 1)
        XCTAssertEqual(GlanceConstants.payloadVersionTodo, 1)
        XCTAssertEqual(PanelKind.todo, "com.glance.panel.todo")
    }

    func testDefaultSize() {
        XCTAssertEqual(TodoPanelProvider.defaultSize.width, 320)
        XCTAssertEqual(TodoPanelProvider.defaultSize.height, 300)
        XCTAssertEqual(TodoPanelProvider.minimumSize.width, 220)
        XCTAssertEqual(TodoPanelProvider.minimumSize.height, 140)
        XCTAssertEqual(TodoPanelProvider.defaultSize, GlanceConstants.todoDefaultSize)
        XCTAssertEqual(TodoPanelProvider.minimumSize, GlanceConstants.todoMinSize)
    }

    func testTodoRecordKeepsFlatGeometry() throws {
        let record = PanelRecord(
            kindIdentifier: PanelKind.todo,
            frame: PanelFrame(x: 40, y: 80, width: 320, height: 300),
            displayIdentifier: "1",
            payloadPath: "Panels/todo-id",
            payloadVersion: 1
        )
        let data = try PanelDatabaseCodec.encode(
            PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: [record])
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let panel = try XCTUnwrap((root["panels"] as? [[String: Any]])?.first)
        XCTAssertEqual(panel["kindIdentifier"] as? String, PanelKind.todo)
        XCTAssertEqual((panel["x"] as? NSNumber)?.doubleValue, 40)
        XCTAssertEqual((panel["width"] as? NSNumber)?.doubleValue, 320)
        XCTAssertNil(panel["frame"])
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)

        let decoded = try PanelDatabaseCodec.decode(from: data)
        let restored = try XCTUnwrap(decoded.database.panels.first)
        XCTAssertEqual(restored.kindIdentifier, PanelKind.todo)
        XCTAssertEqual(restored.frame, record.frame)
        XCTAssertEqual(restored.payloadVersion, 1)
    }

    func testMenuInsertsTodoBetweenMarkdownAndImage() {
        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
        let titles = menu.items.map(\.title)
        XCTAssertEqual(titles[0], "新建文字面板")
        XCTAssertEqual(titles[1], "新建 Markdown 面板")
        XCTAssertEqual(titles[2], "新建待办面板")
        XCTAssertEqual(titles[3], "新建图片面板")
    }
}
