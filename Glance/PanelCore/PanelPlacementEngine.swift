import AppKit

struct PanelPlacementEngine {
    func frameForNewPanel(
        size: NSSize,
        existingFrames: [NSRect],
        on screen: NSScreen
    ) -> NSRect {
        frameForNewPanel(size: size, existingFrames: existingFrames, visibleFrame: screen.visibleFrame)
    }

    func frameForNewPanel(
        size: NSSize,
        existingFrames: [NSRect],
        visibleFrame: NSRect
    ) -> NSRect {
        var origin = NSPoint(
            x: visibleFrame.maxX - size.width - GlanceConstants.spawnMargin,
            y: visibleFrame.maxY - size.height - GlanceConstants.spawnMargin
        )

        let offset = GlanceConstants.cascadeOffset
        var guardCount = 0
        while existingFrames.contains(where: { abs($0.origin.x - origin.x) < 1 && abs($0.origin.y - origin.y) < 1 }),
              guardCount < 40 {
            origin.x -= offset
            origin.y -= offset
            guardCount += 1
        }

        let proposed = NSRect(origin: origin, size: size)
        return PanelFrameRecovery.clamp(proposed, to: visibleFrame)
    }
}
