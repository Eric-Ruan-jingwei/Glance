import AppKit

extension PanelPlacementEngine {
    func frameForNewPanel(
        size: NSSize,
        existingFrames: [NSRect],
        on screen: NSScreen
    ) -> NSRect {
        frameForNewPanel(
            width: size.width,
            height: size.height,
            existingFrames: existingFrames.map(PanelFrame.init),
            visibleFrame: PanelFrame(screen.visibleFrame)
        ).nsRect
    }
}
