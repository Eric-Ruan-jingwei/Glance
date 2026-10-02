import AppKit

struct PanelPlacementEngine {
    func frameForNewPanel(
        size: NSSize,
        existingFrames: [NSRect],
        on screen: NSScreen
    ) -> NSRect {
        let visible = screen.visibleFrame
        var origin = NSPoint(
            x: visible.maxX - size.width - GlanceConstants.spawnMargin,
            y: visible.maxY - size.height - GlanceConstants.spawnMargin
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
        return PanelFrameRecovery.clamp(proposed, to: visible)
    }
}
