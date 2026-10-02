import AppKit
import Foundation

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

enum GlanceTestFixtures {
    static func sampleRecord(
        id: UUID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> PanelRecord {
        PanelRecord(
            id: id,
            kindIdentifier: PanelKind.text,
            frame: NSRect(x: 100, y: 200, width: 320, height: 220),
            displayIdentifier: "1",
            payloadPath: "Panels/\(id.uuidString)",
            payloadVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_699_000_000),
            updatedAt: updatedAt
        )
    }

    static let legacyArrayJSON = """
    [
      {
        "createdAt" : "2026-10-02T15:32:51Z",
        "displayIdentifier" : "1",
        "height" : 220,
        "id" : "0D74D7D4-33F4-4795-A657-D40F456187A7",
        "isCollapsed" : false,
        "isLocked" : false,
        "isPassThrough" : false,
        "isPinned" : true,
        "kindIdentifier" : "com.glance.panel.text",
        "opacity" : 1,
        "payloadPath" : "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7",
        "payloadVersion" : 1,
        "themeIdentifier" : "system",
        "updatedAt" : "2026-10-02T15:32:51Z",
        "width" : 320,
        "x" : 1130,
        "y" : 683
      }
    ]
    """

    static let minimalRecordJSON = """
    [
      {
        "createdAt" : "2026-10-02T15:32:51Z",
        "displayIdentifier" : "1",
        "height" : 220,
        "id" : "0D74D7D4-33F4-4795-A657-D40F456187A7",
        "kindIdentifier" : "com.glance.panel.text",
        "payloadPath" : "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7",
        "updatedAt" : "2026-10-02T15:32:51Z",
        "width" : 320,
        "x" : 10,
        "y" : 20
      }
    ]
    """

    static let futureSchemaJSON = """
    {
      "experimentalField" : true,
      "panels" : [
        {
          "createdAt" : "2026-10-02T15:32:51Z",
          "displayIdentifier" : "1",
          "futureOnly" : "keep-me",
          "height" : 220,
          "id" : "0D74D7D4-33F4-4795-A657-D40F456187A7",
          "kindIdentifier" : "com.glance.panel.markdown",
          "payloadPath" : "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7",
          "updatedAt" : "2026-10-02T15:32:51Z",
          "width" : 320,
          "x" : 10,
          "y" : 20
        }
      ],
      "schemaVersion" : 2
    }
    """
}
