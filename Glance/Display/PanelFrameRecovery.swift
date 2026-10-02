import Foundation

struct DisplaySnapshot: Equatable {
    var identifier: String
    var visibleFrame: PanelFrame
    var isMain: Bool
}

struct RecoveredFrame: Equatable {
    var frame: PanelFrame
    var displayIdentifier: String
    var migrated: Bool
}

enum PanelFrameRecovery {
    static func recover(
        frame: PanelFrame,
        displayIdentifier: String,
        displays: [DisplaySnapshot]
    ) -> RecoveredFrame {
        let original = displays.first { $0.identifier == displayIdentifier }
        let fallback = displays.first(where: \.isMain) ?? displays.first
        guard let screen = original ?? fallback else {
            return RecoveredFrame(frame: clamp(frame, to: frame), displayIdentifier: displayIdentifier, migrated: false)
        }

        var recovered = frame
        let migrated = original == nil
        if migrated {
            recovered.x = screen.visibleFrame.maxX - recovered.width - GlanceLayout.spawnMargin
            recovered.y = screen.visibleFrame.maxY - recovered.height - GlanceLayout.spawnMargin
        }

        recovered = clamp(recovered, to: screen.visibleFrame)
        return RecoveredFrame(
            frame: recovered,
            displayIdentifier: screen.identifier,
            migrated: migrated
        )
    }

    static func clamp(_ frame: PanelFrame, to visible: PanelFrame) -> PanelFrame {
        var result = frame
        if visible.width > 0 {
            result.width = min(max(result.width, 80), visible.width)
        }
        if visible.height > 0 {
            result.height = min(max(result.height, 80), visible.height)
        }
        if visible.width > 0 {
            result.x = min(max(result.x, visible.minX), visible.maxX - result.width)
        }
        if visible.height > 0 {
            result.y = min(max(result.y, visible.minY), visible.maxY - result.height)
        }
        return result
    }
}
