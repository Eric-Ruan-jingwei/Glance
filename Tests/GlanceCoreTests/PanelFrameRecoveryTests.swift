import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelFrameRecoveryTests: XCTestCase {
    private let main = DisplaySnapshot(
        identifier: "main",
        visibleFrame: PanelFrame(x: 0, y: 0, width: 1440, height: 900),
        isMain: true
    )

    private let left = DisplaySnapshot(
        identifier: "left",
        visibleFrame: PanelFrame(x: -1920, y: 0, width: 1920, height: 1080),
        isMain: false
    )

    func testPanelFullyOnscreenUnchanged() {
        let frame = PanelFrame(x: 100, y: 100, width: 320, height: 220)
        let recovered = PanelFrameRecovery.recover(frame: frame, displayIdentifier: "main", displays: [main])
        XCTAssertEqual(recovered.frame, frame)
        XCTAssertEqual(recovered.displayIdentifier, "main")
        XCTAssertFalse(recovered.migrated)
    }

    func testPartiallyVisibleUsableFrameIsNotMoved() {
        let frame = PanelFrame(x: 100, y: -80, width: 320, height: 220)
        let recovered = PanelFrameRecovery.recover(frame: frame, displayIdentifier: "main", displays: [main])
        XCTAssertEqual(recovered.frame, frame)
        XCTAssertFalse(recovered.migrated)
    }

    func testFullyOffscreenMovesOnscreenPreservingSize() {
        let recovered = PanelFrameRecovery.recover(
            frame: PanelFrame(x: -400, y: 100, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.x, 0)
        XCTAssertEqual(recovered.frame.y, 100)
        XCTAssertEqual(recovered.frame.width, 320)
        XCTAssertEqual(recovered.frame.height, 220)
    }

    func testAlmostUnusableRightEdgeIsRecovered() {
        let recovered = PanelFrameRecovery.recover(
            frame: PanelFrame(x: 1400, y: 100, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.maxX, main.visibleFrame.maxX)
        XCTAssertEqual(recovered.frame.width, 320)
    }

    func testAlmostUnusableTopEdgeIsRecovered() {
        let recovered = PanelFrameRecovery.recover(
            frame: PanelFrame(x: 100, y: 880, width: 320, height: 220),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.maxY, main.visibleFrame.maxY)
        XCTAssertEqual(recovered.frame.height, 220)
    }

    func testPanelLargerThanVisibleFrame() {
        let recovered = PanelFrameRecovery.recover(
            frame: PanelFrame(x: -50, y: -50, width: 4000, height: 3000),
            displayIdentifier: "main",
            displays: [main]
        )
        XCTAssertEqual(recovered.frame.width, main.visibleFrame.width)
        XCTAssertEqual(recovered.frame.height, main.visibleFrame.height)
        XCTAssertEqual(recovered.frame.x, main.visibleFrame.x)
        XCTAssertEqual(recovered.frame.y, main.visibleFrame.y)
    }

    func testMissingDisplayKeepsFrameIfStillOperableOnMain() {
        let frame = PanelFrame(x: 50, y: 50, width: 320, height: 220)
        let recovered = PanelFrameRecovery.recover(
            frame: frame,
            displayIdentifier: "gone",
            displays: [main, left]
        )
        XCTAssertTrue(recovered.migrated)
        XCTAssertEqual(recovered.displayIdentifier, "main")
        XCTAssertEqual(recovered.frame, frame)
    }

    func testUnpluggedDisplayOffscreenFrameMovesOntoMain() {
        let recovered = PanelFrameRecovery.recover(
            frame: PanelFrame(x: -4000, y: 40, width: 320, height: 220),
            displayIdentifier: "gone",
            displays: [main]
        )
        XCTAssertTrue(recovered.migrated)
        XCTAssertEqual(recovered.displayIdentifier, "main")
        XCTAssertEqual(recovered.frame.width, 320)
        XCTAssertEqual(recovered.frame.height, 220)
        XCTAssertEqual(recovered.frame.x, main.visibleFrame.minX)
        XCTAssertGreaterThanOrEqual(recovered.frame.y, main.visibleFrame.minY)
        XCTAssertLessThanOrEqual(recovered.frame.maxY, main.visibleFrame.maxY)
    }

    func testNegativeCoordinateSecondDisplay() {
        let recovered = PanelFrameRecovery.recover(
            frame: PanelFrame(x: -4000, y: 40, width: 320, height: 220),
            displayIdentifier: "left",
            displays: [main, left]
        )
        XCTAssertFalse(recovered.migrated)
        XCTAssertEqual(recovered.displayIdentifier, "left")
        XCTAssertEqual(recovered.frame.x, left.visibleFrame.minX)
        XCTAssertEqual(recovered.frame.y, 40)
        XCTAssertEqual(recovered.frame.width, 320)
    }
}
