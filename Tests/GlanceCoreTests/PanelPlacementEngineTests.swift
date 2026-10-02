import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelPlacementEngineTests: XCTestCase {
    private let engine = PanelPlacementEngine()
    private let visible = PanelFrame(x: 0, y: 0, width: 1440, height: 900)
    private let width: Double = 320
    private let height: Double = 220

    func testDefaultTopRight() {
        let frame = engine.frameForNewPanel(
            width: width,
            height: height,
            existingFrames: [],
            visibleFrame: visible
        )
        XCTAssertEqual(frame.x, visible.maxX - width - GlanceLayout.spawnMargin)
        XCTAssertEqual(frame.y, visible.maxY - height - GlanceLayout.spawnMargin)
        XCTAssertEqual(frame.width, width)
        XCTAssertEqual(frame.height, height)
    }

    func testCascadeOffset() {
        let first = engine.frameForNewPanel(
            width: width,
            height: height,
            existingFrames: [],
            visibleFrame: visible
        )
        let second = engine.frameForNewPanel(
            width: width,
            height: height,
            existingFrames: [first],
            visibleFrame: visible
        )
        XCTAssertEqual(second.x, first.x - GlanceLayout.cascadeOffset)
        XCTAssertEqual(second.y, first.y - GlanceLayout.cascadeOffset)
    }

    func testClampWhenCascadeWouldLeaveScreen() {
        let crowding = (0..<40).map { index in
            PanelFrame(
                x: visible.maxX - width - GlanceLayout.spawnMargin - Double(index) * GlanceLayout.cascadeOffset,
                y: visible.maxY - height - GlanceLayout.spawnMargin - Double(index) * GlanceLayout.cascadeOffset,
                width: width,
                height: height
            )
        }
        let frame = engine.frameForNewPanel(
            width: width,
            height: height,
            existingFrames: crowding,
            visibleFrame: visible
        )
        XCTAssertGreaterThanOrEqual(frame.minX, visible.minX)
        XCTAssertGreaterThanOrEqual(frame.minY, visible.minY)
        XCTAssertLessThanOrEqual(frame.maxX, visible.maxX)
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)
    }

    func testExistingFrameCollisionTriggersCascade() {
        let first = PanelFrame(
            x: visible.maxX - width - GlanceLayout.spawnMargin,
            y: visible.maxY - height - GlanceLayout.spawnMargin,
            width: width,
            height: height
        )
        let frame = engine.frameForNewPanel(
            width: width,
            height: height,
            existingFrames: [first],
            visibleFrame: visible
        )
        XCTAssertNotEqual(frame.x, first.x)
        XCTAssertNotEqual(frame.y, first.y)
    }
}
