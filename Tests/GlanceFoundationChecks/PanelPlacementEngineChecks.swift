import Foundation
@testable import GlanceCore

enum PanelPlacementEngineChecks {
    private static let engine = PanelPlacementEngine()
    private static let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private static let size = NSSize(width: 320, height: 220)

    static func run() {
        defaultTopRight()
        cascadeOffset()
        clampWhenCascadeWouldLeaveScreen()
        existingFrameCollisionTriggersCascade()
    }

    private static func defaultTopRight() {
        let frame = engine.frameForNewPanel(size: size, existingFrames: [], visibleFrame: visible)
        CheckRun.equal(frame.origin.x, visible.maxX - size.width - GlanceConstants.spawnMargin, "default x")
        CheckRun.equal(frame.origin.y, visible.maxY - size.height - GlanceConstants.spawnMargin, "default y")
        CheckRun.equal(frame.size, size, "default size")
    }

    private static func cascadeOffset() {
        let first = engine.frameForNewPanel(size: size, existingFrames: [], visibleFrame: visible)
        let second = engine.frameForNewPanel(size: size, existingFrames: [first], visibleFrame: visible)
        CheckRun.equal(second.origin.x, first.origin.x - GlanceConstants.cascadeOffset, "cascade x")
        CheckRun.equal(second.origin.y, first.origin.y - GlanceConstants.cascadeOffset, "cascade y")
    }

    private static func clampWhenCascadeWouldLeaveScreen() {
        let crowding = (0..<40).map { index in
            NSRect(
                x: visible.maxX - size.width - GlanceConstants.spawnMargin - CGFloat(index) * GlanceConstants.cascadeOffset,
                y: visible.maxY - size.height - GlanceConstants.spawnMargin - CGFloat(index) * GlanceConstants.cascadeOffset,
                width: size.width,
                height: size.height
            )
        }
        let frame = engine.frameForNewPanel(size: size, existingFrames: crowding, visibleFrame: visible)
        CheckRun.expect(frame.minX >= visible.minX, "cascade clamp minX")
        CheckRun.expect(frame.minY >= visible.minY, "cascade clamp minY")
        CheckRun.expect(frame.maxX <= visible.maxX, "cascade clamp maxX")
        CheckRun.expect(frame.maxY <= visible.maxY, "cascade clamp maxY")
    }

    private static func existingFrameCollisionTriggersCascade() {
        let origin = NSPoint(
            x: visible.maxX - size.width - GlanceConstants.spawnMargin,
            y: visible.maxY - size.height - GlanceConstants.spawnMargin
        )
        let frame = engine.frameForNewPanel(
            size: size,
            existingFrames: [NSRect(origin: origin, size: size)],
            visibleFrame: visible
        )
        CheckRun.expect(frame.origin != origin, "collision cascades")
    }
}
