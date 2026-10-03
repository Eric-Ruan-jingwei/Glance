import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelFrameTests: XCTestCase {
    func testInitAndEquality() {
        let frame = PanelFrame(x: 12, y: 34, width: 320, height: 220)
        XCTAssertEqual(frame.x, 12)
        XCTAssertEqual(frame.y, 34)
        XCTAssertEqual(frame.width, 320)
        XCTAssertEqual(frame.height, 220)
        XCTAssertEqual(frame, PanelFrame(x: 12, y: 34, width: 320, height: 220))
        XCTAssertNotEqual(frame, PanelFrame(x: 0, y: 34, width: 320, height: 220))
    }

    func testEdges() {
        let frame = PanelFrame(x: 10, y: 20, width: 100, height: 50)
        XCTAssertEqual(frame.minX, 10)
        XCTAssertEqual(frame.minY, 20)
        XCTAssertEqual(frame.maxX, 110)
        XCTAssertEqual(frame.maxY, 70)
        XCTAssertEqual(frame.midX, 60)
        XCTAssertEqual(frame.midY, 45)
    }

    func testCodableRoundTrip() throws {
        let frame = PanelFrame(x: -1920, y: 80.5, width: 400, height: 300)
        let data = try JSONEncoder().encode(frame)
        let decoded = try JSONDecoder().decode(PanelFrame.self, from: data)
        XCTAssertEqual(decoded, frame)
    }

    func testRecordEncodesFlatGeometryKeys() throws {
        let record = GlanceTestFixtures.sampleRecord()
        let data = try PanelDatabaseCodec.encode(
            PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: [record])
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let panels = try XCTUnwrap(root["panels"] as? [[String: Any]])
        let panel = try XCTUnwrap(panels.first)
        XCTAssertEqual((panel["x"] as? NSNumber)?.doubleValue, 100)
        XCTAssertEqual((panel["y"] as? NSNumber)?.doubleValue, 200)
        XCTAssertEqual((panel["width"] as? NSNumber)?.doubleValue, 320)
        XCTAssertEqual((panel["height"] as? NSNumber)?.doubleValue, 220)
        XCTAssertNil(panel["frame"])
        XCTAssertEqual(root["schemaVersion"] as? Int, PanelDatabase.currentSchemaVersion)
        XCTAssertEqual(panel["isHidden"] as? Bool, false)
    }
}

#if canImport(AppKit)
import AppKit

final class PanelFrameAppKitAdapterTests: XCTestCase {
    func testNSRectRoundTrip() {
        let rect = NSRect(x: 10.5, y: 20.25, width: 300, height: 180)
        let converted = PanelFrame(rect).nsRect
        XCTAssertEqual(converted.origin.x, rect.origin.x, accuracy: 0.0001)
        XCTAssertEqual(converted.origin.y, rect.origin.y, accuracy: 0.0001)
        XCTAssertEqual(converted.size.width, rect.size.width, accuracy: 0.0001)
        XCTAssertEqual(converted.size.height, rect.size.height, accuracy: 0.0001)
    }
}
#endif
