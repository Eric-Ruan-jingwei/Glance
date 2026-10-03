import Foundation

enum PanelPlacementOccupancy {
    static func shouldOccupy(
        workspaceID: String,
        isHidden: Bool,
        activeWorkspaceID: String
    ) -> Bool {
        workspaceID == activeWorkspaceID && !isHidden
    }
}

struct PanelPlacementEngine {
    func frameForNewPanel(
        width: Double,
        height: Double,
        existingFrames: [PanelFrame],
        visibleFrame: PanelFrame
    ) -> PanelFrame {
        var x = visibleFrame.maxX - width - GlanceLayout.spawnMargin
        var y = visibleFrame.maxY - height - GlanceLayout.spawnMargin
        let offset = GlanceLayout.cascadeOffset
        var guardCount = 0
        while existingFrames.contains(where: { abs($0.x - x) < 1 && abs($0.y - y) < 1 }),
              guardCount < 40 {
            x -= offset
            y -= offset
            guardCount += 1
        }
        return PanelFrameRecovery.clamp(
            PanelFrame(x: x, y: y, width: width, height: height),
            to: visibleFrame
        )
    }
}
