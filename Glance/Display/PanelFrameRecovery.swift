import AppKit

struct DisplaySnapshot: Equatable {
    var identifier: String
    var visibleFrame: NSRect
    var isMain: Bool
}

struct RecoveredFrame: Equatable {
    var frame: NSRect
    var displayIdentifier: String
    var migrated: Bool
}

enum PanelFrameRecovery {
    static func currentDisplays() -> [DisplaySnapshot] {
        let mainID = NSScreen.main.map { DisplayManager.identifier(for: $0) }
        return NSScreen.screens.map { screen in
            let identifier = DisplayManager.identifier(for: screen)
            return DisplaySnapshot(
                identifier: identifier,
                visibleFrame: screen.visibleFrame,
                isMain: identifier == mainID
            )
        }
    }

    static func recover(frame: NSRect, displayIdentifier: String) -> RecoveredFrame {
        recover(frame: frame, displayIdentifier: displayIdentifier, displays: currentDisplays())
    }

    static func recover(
        frame: NSRect,
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
            recovered.origin = NSPoint(
                x: screen.visibleFrame.maxX - recovered.width - GlanceConstants.spawnMargin,
                y: screen.visibleFrame.maxY - recovered.height - GlanceConstants.spawnMargin
            )
        }

        recovered = clamp(recovered, to: screen.visibleFrame)
        return RecoveredFrame(
            frame: recovered,
            displayIdentifier: screen.identifier,
            migrated: migrated
        )
    }

    static func clamp(_ frame: NSRect, to visible: NSRect) -> NSRect {
        var result = frame
        if visible.width > 0 {
            result.size.width = min(max(result.size.width, 80), visible.width)
        }
        if visible.height > 0 {
            result.size.height = min(max(result.size.height, 80), visible.height)
        }
        if visible.width > 0 {
            result.origin.x = min(max(result.origin.x, visible.minX), visible.maxX - result.width)
        }
        if visible.height > 0 {
            result.origin.y = min(max(result.origin.y, visible.minY), visible.maxY - result.height)
        }
        return result
    }
}
