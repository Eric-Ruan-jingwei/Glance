import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelPlacementEngineTests: XCTestCase {
    private let engine = PanelPlacementEngine()
    private let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = NSSize(width: 320, height: 220)

    func testDefaultTopRight() {
        let frame = engine.frameForNewPanel(size: size, existingFrames: [], visibleFrame: visible)
        XCTAssertEqual(frame.origin.x, visible.maxX - size.width - GlanceConstants.spawnMargin)
        XCTAssertEqual(frame.origin.y, visible.maxY - size.height - GlanceConstants.spawnMargin)
        XCTAssertEqual(frame.size, size)
    }

    func testCascadeOffset() {
        let first = engine.frameForNewPanel(size: size, existingFrames: [], visibleFrame: visible)
        let second = engine.frameForNewPanel(size: size, existingFrames: [first], visibleFrame: visible)
        XCTAssertEqual(second.origin.x, first.origin.x - GlanceConstants.cascadeOffset)
        XCTAssertEqual(second.origin.y, first.origin.y - GlanceConstants.cascadeOffset)
    }

    func testClampWhenCascadeWouldLeaveScreen() {
        let crowding = (0..<40).map { index in
            NSRect(
                x: visible.maxX - size.width - GlanceConstants.spawnMargin - CGFloat(index) * GlanceConstants.cascadeOffset,
                y: visible.maxY - size.height - GlanceConstants.spawnMargin - CGFloat(index) * GlanceConstants.cascadeOffset,
                width: size.width,
                height: size.height
            )
        }
        let frame = engine.frameForNewPanel(size: size, existingFrames: crowding, visibleFrame: visible)
        XCTAssertGreaterThanOrEqual(frame.minX, visible.minX)
        XCTAssertGreaterThanOrEqual(frame.minY, visible.minY)
        XCTAssertLessThanOrEqual(frame.maxX, visible.maxX)
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)
    }

    func testExistingFrameCollisionTriggersCascade() {
        let origin = NSPoint(
            x: visible.maxX - size.width - GlanceConstants.spawnMargin,
            y: visible.maxY - size.height - GlanceConstants.spawnMargin
        )
        let frame = engine.frameForNewPanel(
            size: size,
            existingFrames: [NSRect(origin: origin, size: size)],
            visibleFrame: visible
        )
        XCTAssertNotEqual(frame.origin, origin)
    }
}
