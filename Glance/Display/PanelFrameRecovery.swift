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
    static let minimumOperableWidth: Double = 80
    static let minimumOperableHeight: Double = 48

    static func recover(
        frame: PanelFrame,
        displayIdentifier: String,
        displays: [DisplaySnapshot]
    ) -> RecoveredFrame {
        guard !displays.isEmpty else {
            return RecoveredFrame(frame: frame, displayIdentifier: displayIdentifier, migrated: false)
        }

        if let operable = operableDisplay(for: frame, displays: displays) {
            let oversized = frame.width > operable.visibleFrame.width
                || frame.height > operable.visibleFrame.height
            let recovered = oversized ? clamp(frame, to: operable.visibleFrame) : frame
            return RecoveredFrame(
                frame: recovered,
                displayIdentifier: operable.identifier,
                migrated: operable.identifier != displayIdentifier
            )
        }

        let target = displays.first { $0.identifier == displayIdentifier }
            ?? nearestDisplay(to: frame, displays: displays)
            ?? displays.first(where: \.isMain)
            ?? displays[0]
        let recovered = clamp(frame, to: target.visibleFrame)
        return RecoveredFrame(
            frame: recovered,
            displayIdentifier: target.identifier,
            migrated: target.identifier != displayIdentifier
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

    static func isOperable(_ overlap: PanelFrame) -> Bool {
        overlap.width >= minimumOperableWidth && overlap.height >= minimumOperableHeight
    }

    static func operableDisplay(for frame: PanelFrame, displays: [DisplaySnapshot]) -> DisplaySnapshot? {
        var best: (DisplaySnapshot, Double)?
        for display in displays {
            guard let overlap = frame.intersection(display.visibleFrame), isOperable(overlap) else {
                continue
            }
            let area = overlap.width * overlap.height
            if best == nil || area > best!.1 {
                best = (display, area)
            }
        }
        return best?.0
    }

    private static func nearestDisplay(to frame: PanelFrame, displays: [DisplaySnapshot]) -> DisplaySnapshot? {
        displays.min { lhs, rhs in
            centerDistance(frame, lhs.visibleFrame) < centerDistance(frame, rhs.visibleFrame)
        }
    }

    private static func centerDistance(_ lhs: PanelFrame, _ rhs: PanelFrame) -> Double {
        let dx = lhs.midX - rhs.midX
        let dy = lhs.midY - rhs.midY
        return dx * dx + dy * dy
    }
}
