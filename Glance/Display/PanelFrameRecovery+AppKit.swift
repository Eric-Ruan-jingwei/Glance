import AppKit

extension PanelFrameRecovery {
    static func currentDisplays() -> [DisplaySnapshot] {
        let mainID = NSScreen.main.map { DisplayManager.identifier(for: $0) }
        return NSScreen.screens.map { screen in
            let identifier = DisplayManager.identifier(for: screen)
            return DisplaySnapshot(
                identifier: identifier,
                visibleFrame: PanelFrame(screen.visibleFrame),
                isMain: identifier == mainID
            )
        }
    }

    static func recover(frame: PanelFrame, displayIdentifier: String) -> RecoveredFrame {
        recover(frame: frame, displayIdentifier: displayIdentifier, displays: currentDisplays())
    }

    static func recover(frame: NSRect, displayIdentifier: String) -> RecoveredFrame {
        recover(frame: PanelFrame(frame), displayIdentifier: displayIdentifier)
    }

    static func clamp(_ frame: NSRect, to visible: NSRect) -> NSRect {
        clamp(PanelFrame(frame), to: PanelFrame(visible)).nsRect
    }
}
