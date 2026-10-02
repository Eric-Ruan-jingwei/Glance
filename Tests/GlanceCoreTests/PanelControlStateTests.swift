import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelInteractionPolicyTests: XCTestCase {
    func testUnlockedReadingAllowsMoveResizeAndEdit() {
        let policy = PanelInteractionPolicy(
            isLocked: false,
            isPassThrough: false,
            isOptionPressed: false,
            interactionState: .reading
        )
        XCTAssertTrue(policy.allowsMove)
        XCTAssertTrue(policy.allowsResize)
        XCTAssertTrue(policy.allowsEdit)
        XCTAssertTrue(policy.allowsContentMutation)
    }

    func testLockedReadingBlocksMoveResizeAndEdit() {
        let policy = PanelInteractionPolicy(
            isLocked: true,
            isPassThrough: false,
            isOptionPressed: false,
            interactionState: .reading
        )
        XCTAssertFalse(policy.allowsMove)
        XCTAssertFalse(policy.allowsResize)
        XCTAssertFalse(policy.allowsEdit)
        XCTAssertFalse(policy.allowsContentMutation)
        XCTAssertTrue(policy.mouseEventsReachPanel)
    }

    func testLockedPassThroughWithOptionStillCannotEdit() {
        let policy = PanelInteractionPolicy(
            isLocked: true,
            isPassThrough: true,
            isOptionPressed: true,
            interactionState: .passThrough
        )
        XCTAssertTrue(policy.mouseEventsReachPanel)
        XCTAssertFalse(policy.allowsMove)
        XCTAssertFalse(policy.allowsResize)
        XCTAssertFalse(policy.allowsEdit)
        XCTAssertFalse(policy.allowsContentMutation)
    }

    func testPassThroughWithoutOptionDoesNotAdmitMouse() {
        let policy = PanelInteractionPolicy(
            isLocked: false,
            isPassThrough: true,
            isOptionPressed: false,
            interactionState: .passThrough
        )
        XCTAssertFalse(policy.mouseEventsReachPanel)
        XCTAssertFalse(policy.allowsMove)
        XCTAssertFalse(policy.allowsResize)
        XCTAssertFalse(policy.allowsEdit)
        XCTAssertFalse(policy.allowsContentMutation)
    }

    func testPassThroughWithOptionAllowsTemporaryEditWhenUnlocked() {
        let policy = PanelInteractionPolicy(
            isLocked: false,
            isPassThrough: true,
            isOptionPressed: true,
            interactionState: .passThrough
        )
        XCTAssertTrue(policy.mouseEventsReachPanel)
        XCTAssertTrue(policy.allowsMove)
        XCTAssertTrue(policy.allowsResize)
        XCTAssertTrue(policy.allowsEdit)
        XCTAssertTrue(policy.allowsContentMutation)
    }

    func testEditingAlwaysReceivesMouseEvenWithPassThrough() {
        let policy = PanelInteractionPolicy(
            isLocked: false,
            isPassThrough: true,
            isOptionPressed: false,
            interactionState: .editing
        )
        XCTAssertTrue(policy.mouseEventsReachPanel)
        XCTAssertTrue(policy.allowsMove)
        XCTAssertFalse(policy.allowsEdit)
    }
}

final class PanelOpacityTests: XCTestCase {
    func testClampsBelowMinimum() {
        XCTAssertEqual(PanelOpacity.clamp(0), 0.30, accuracy: 0.0001)
        XCTAssertEqual(PanelOpacity.clamp(0.29), 0.30, accuracy: 0.0001)
    }

    func testClampsAboveMaximum() {
        XCTAssertEqual(PanelOpacity.clamp(1.01), 1.0, accuracy: 0.0001)
        XCTAssertEqual(PanelOpacity.clamp(2), 1.0, accuracy: 0.0001)
    }

    func testPreservesInRangeValue() {
        XCTAssertEqual(PanelOpacity.clamp(0.65), 0.65, accuracy: 0.0001)
        XCTAssertEqual(PanelOpacity.clamp(0.30), 0.30, accuracy: 0.0001)
        XCTAssertEqual(PanelOpacity.clamp(1.0), 1.0, accuracy: 0.0001)
    }
}

final class PanelRecordControlStateTests: XCTestCase {
    func testControlFlagsSurviveEncodeDecode() throws {
        let record = PanelRecord(
            id: UUID(uuidString: "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            kindIdentifier: PanelKind.image,
            frame: NSRect(x: 40, y: 80, width: 200, height: 160),
            displayIdentifier: "2",
            payloadPath: "Panels/BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            payloadVersion: 1,
            isPinned: false,
            isLocked: true,
            isPassThrough: true,
            opacity: 0.5,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let data = try PanelDatabaseCodec.encode(
            PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: [record])
        )
        let decoded = try PanelDatabaseCodec.decode(from: data)
        let panel = try XCTUnwrap(decoded.database.panels.first)
        XCTAssertFalse(panel.isPinned)
        XCTAssertTrue(panel.isLocked)
        XCTAssertTrue(panel.isPassThrough)
        XCTAssertEqual(panel.opacity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(panel.kindIdentifier, PanelKind.image)
    }

    func testDecodedOpacityIsClamped() throws {
        let json = """
        {
          "schemaVersion" : 1,
          "panels" : [
            {
              "createdAt" : "2026-10-02T15:32:51Z",
              "displayIdentifier" : "1",
              "height" : 220,
              "id" : "0D74D7D4-33F4-4795-A657-D40F456187A7",
              "isLocked" : true,
              "isPassThrough" : true,
              "isPinned" : false,
              "kindIdentifier" : "com.glance.panel.text",
              "opacity" : 0.1,
              "payloadPath" : "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7",
              "payloadVersion" : 1,
              "themeIdentifier" : "system",
              "updatedAt" : "2026-10-02T15:32:51Z",
              "width" : 320,
              "x" : 10,
              "y" : 20
            }
          ]
        }
        """
        let decoded = try PanelDatabaseCodec.decode(from: Data(json.utf8))
        let panel = try XCTUnwrap(decoded.database.panels.first)
        XCTAssertEqual(panel.opacity, 0.30, accuracy: 0.0001)
        XCTAssertTrue(panel.isLocked)
        XCTAssertTrue(panel.isPassThrough)
        XCTAssertFalse(panel.isPinned)
    }

    func testInitClampsOpacityAboveOne() {
        let record = PanelRecord(
            kindIdentifier: PanelKind.text,
            frame: NSRect(x: 0, y: 0, width: 320, height: 220),
            displayIdentifier: "1",
            payloadPath: "Panels/x",
            payloadVersion: 1,
            opacity: 1.8
        )
        XCTAssertEqual(record.opacity, 1.0, accuracy: 0.0001)
    }
}
