import AppKit

enum PanelFrameRecovery {
    static func recover(frame: NSRect, displayIdentifier: String) -> RecoveredFrame {
        let original = DisplayManager.screen(forIdentifier: displayIdentifier)
        let screen = original ?? NSScreen.main ?? NSScreen.screens[0]
        var recovered = frame

        if original == nil {
            let visible = screen.visibleFrame
            recovered.origin = NSPoint(
                x: visible.maxX - recovered.width - GlanceConstants.spawnMargin,
                y: visible.maxY - recovered.height - GlanceConstants.spawnMargin
            )
        }

        recovered = clamp(recovered, to: screen.visibleFrame)
        return RecoveredFrame(
            frame: recovered,
            displayIdentifier: DisplayManager.identifier(for: screen),
            migrated: original == nil
        )
    }

    static func clamp(_ frame: NSRect, to visible: NSRect) -> NSRect {
        var result = frame
        result.size.width = min(max(result.size.width, 80), visible.width)
        result.size.height = min(max(result.size.height, 80), visible.height)
        result.origin.x = min(max(result.origin.x, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.origin.y, visible.minY), visible.maxY - result.height)
        return result
    }
}

struct RecoveredFrame {
    var frame: NSRect
    var displayIdentifier: String
    var migrated: Bool
}
