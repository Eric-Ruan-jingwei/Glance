import Foundation
@testable import GlanceCore

enum PanelFrameRecoveryChecks {
    private static let main = DisplaySnapshot(
        identifier: "main",
        visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
        isMain: true
    )

    private static let left = DisplaySnapshot(
        identifier: "left",
        visibleFrame: NSRect(x: -1920, y: 0, width: 1920, height: 1080),
        isMain: false
    )

    static func run() {
        panelFullyOnscreenUnchanged()
        clampLeft()
        clampRight()
        clampTop()
        clampBottom()
        panelLargerThanVisibleFrame()
        missingDisplayMigratesToMain()
        negativeCoordinateSecondDisplay()
    }

    private static func panelFullyOnscreenUnchanged() {
        let frame = NSRect(x: 100, y: 100, width: 320, height: 220)
        let recovered = PanelFrameRecovery.recover(frame: frame, displayIdentifier: "main", displays: [main])
        CheckRun.equal(recovered.frame, frame, "onscreen frame")
        CheckRun.equal(recovered.displayIdentifier, "main", "onscreen display")
        CheckRun.expect(!recovered.migrated, "onscreen not migrated")
    }

    private static func clampLeft() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: -400, y: 100, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        CheckRun.equal(recovered.frame.origin.x, 0, "clamp left x")
        CheckRun.equal(recovered.frame.origin.y, 100, "clamp left y")
    }

    private static func clampRight() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 1400, y: 100, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        CheckRun.equal(recovered.frame.maxX, main.visibleFrame.maxX, "clamp right")
    }

    private static func clampTop() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 100, y: 880, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        CheckRun.equal(recovered.frame.maxY, main.visibleFrame.maxY, "clamp top")
    }

    private static func clampBottom() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 100, y: -80, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        CheckRun.equal(recovered.frame.origin.y, 0, "clamp bottom")
    }

    private static func panelLargerThanVisibleFrame() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: -50, y: -50, width: 4000, height: 3000),
            displayIdentifier: "main",
            displays: [main]
        )
        CheckRun.equal(recovered.frame.size.width, main.visibleFrame.width, "fit width")
        CheckRun.equal(recovered.frame.size.height, main.visibleFrame.height, "fit height")
        CheckRun.equal(recovered.frame.origin, main.visibleFrame.origin, "fit origin")
    }

    private static func missingDisplayMigratesToMain() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 50, y: 50, width: 320, height: 220),
            displayIdentifier: "gone",
            displays: [main, left]
        )
        CheckRun.expect(recovered.migrated, "missing display migrates")
        CheckRun.equal(recovered.displayIdentifier, "main", "fallback main")
        CheckRun.equal(
            recovered.frame.origin.x,
            main.visibleFrame.maxX - 320 - GlanceConstants.spawnMargin,
            "migrated x"
        )
        CheckRun.equal(
            recovered.frame.origin.y,
            main.visibleFrame.maxY - 220 - GlanceConstants.spawnMargin,
            "migrated y"
        )
    }

    private static func negativeCoordinateSecondDisplay() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: -4000, y: 40, width: 320, height: 220),
            displayIdentifier: "left",
            displays: [main, left]
        )
        CheckRun.expect(!recovered.migrated, "left display exists")
        CheckRun.equal(recovered.displayIdentifier, "left", "keep left")
        CheckRun.equal(recovered.frame.origin.x, left.visibleFrame.minX, "clamp to left minX")
        CheckRun.equal(recovered.frame.origin.y, 40, "keep y")
    }
}
