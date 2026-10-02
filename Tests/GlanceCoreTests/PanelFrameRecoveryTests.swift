import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelFrameRecoveryTests: XCTestCase {
    private let main = DisplaySnapshot(
        identifier: "main",
        visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 900),
        isMain: true
    )

    private let left = DisplaySnapshot(
        identifier: "left",
        visibleFrame: NSRect(x: -1920, y: 0, width: 1920, height: 1080),
        isMain: false
    )

    func testPanelFullyOnscreenUnchanged() {
        let frame = NSRect(x: 100, y: 100, width: 320, height: 220)
        let recovered = PanelFrameRecovery.recover(frame: frame, displayIdentifier: "main", displays: [main])
        XCTAssertEqual(recovered.frame, frame)
        XCTAssertEqual(recovered.displayIdentifier, "main")
        XCTAssertFalse(recovered.migrated)
    }

    func testClampLeft() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: -400, y: 100, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.origin.x, 0)
        XCTAssertEqual(recovered.frame.origin.y, 100)
    }

    func testClampRight() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 1400, y: 100, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.maxX, main.visibleFrame.maxX)
    }

    func testClampTop() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 100, y: 880, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.maxY, main.visibleFrame.maxY)
    }

    func testClampBottom() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 100, y: -80, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.origin.y, 0)
    }

    func testPanelLargerThanVisibleFrame() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: -50, y: -50, width: 4000, height: 3000),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.size.width, main.visibleFrame.width)
        XCTAssertEqual(recovered.frame.size.height, main.visibleFrame.height)
        XCTAssertEqual(recovered.frame.origin, main.visibleFrame.origin)
    }

    func testMissingDisplayMigratesToMain() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: 50, y: 50, width: 320, height: 220),
            displayIdentifier: "gone",
            displays: [main, left]
        )
        XCTAssertTrue(recovered.migrated)
        XCTAssertEqual(recovered.displayIdentifier, "main")
        XCTAssertEqual(
            recovered.frame.origin.x,
            main.visibleFrame.maxX - 320 - GlanceConstants.spawnMargin
        )
        XCTAssertEqual(
            recovered.frame.origin.y,
            main.visibleFrame.maxY - 220 - GlanceConstants.spawnMargin
        )
    }

    func testNegativeCoordinateSecondDisplay() {
        let recovered = PanelFrameRecovery.recover(
            frame: NSRect(x: -4000, y: 40, width: 320, height: 220),
            displayIdentifier: "left",
            displays: [main, left]
        )
        XCTAssertFalse(recovered.migrated)
        XCTAssertEqual(recovered.displayIdentifier, "left")
        XCTAssertEqual(recovered.frame.origin.x, left.visibleFrame.minX)
        XCTAssertEqual(recovered.frame.origin.y, 40)
    }
}
