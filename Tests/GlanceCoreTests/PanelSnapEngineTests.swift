import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelSnapEngineTests: XCTestCase {
    private let visible = PanelFrame(x: 0, y: 0, width: 1440, height: 900)
    private let size = (width: 420.0, height: 320.0)
    private let margin = GlanceLayout.snapMargin
    private let threshold = GlanceLayout.snapThreshold

    func testLeftSnap() {
        let panel = frame(x: 3, y: 200)
        let snapped = PanelSnapEngine.snappedFrame(panel, in: visible)
        XCTAssertEqual(snapped.x, visible.minX + margin)
        XCTAssertEqual(snapped.y, 200)
        XCTAssertEqual(snapped.width, size.width)
        XCTAssertEqual(snapped.height, size.height)
    }

    func testRightSnap() {
        let panel = frame(x: visible.maxX - size.width - 3, y: 180)
        let snapped = PanelSnapEngine.snappedFrame(panel, in: visible)
        XCTAssertEqual(snapped.maxX, visible.maxX - margin)
        XCTAssertEqual(snapped.y, 180)
        XCTAssertEqual(snapped.width, size.width)
        XCTAssertEqual(snapped.height, size.height)
    }

    func testBottomSnap() {
        let panel = frame(x: 200, y: 4)
        let snapped = PanelSnapEngine.snappedFrame(panel, in: visible)
        XCTAssertEqual(snapped.y, visible.minY + margin)
        XCTAssertEqual(snapped.x, 200)
    }

    func testTopSnap() {
        let panel = frame(x: 200, y: visible.maxY - size.height - 2)
        let snapped = PanelSnapEngine.snappedFrame(panel, in: visible)
        XCTAssertEqual(snapped.maxY, visible.maxY - margin)
        XCTAssertEqual(snapped.x, 200)
    }

    func testCornerSnapTopRight() {
        let panel = frame(
            x: visible.maxX - size.width - 5,
            y: visible.maxY - size.height - 4
        )
        let snapped = PanelSnapEngine.snappedFrame(panel, in: visible)
        XCTAssertEqual(snapped.x, visible.maxX - margin - size.width)
        XCTAssertEqual(snapped.y, visible.maxY - margin - size.height)
        XCTAssertEqual(snapped.width, size.width)
        XCTAssertEqual(snapped.height, size.height)
    }

    func testOutsideThresholdIsUnchanged() {
        let panel = frame(x: threshold + 1, y: 200)
        XCTAssertEqual(PanelSnapEngine.snappedFrame(panel, in: visible), panel)
    }

    func testNearestEdgeWinsWhenBothAreClose() {
        let wide = PanelFrame(x: 2, y: 100, width: visible.width - 5, height: 200)
        let snapped = PanelSnapEngine.snappedFrame(wide, in: visible)
        XCTAssertEqual(snapped.x, visible.minX + margin)
        XCTAssertEqual(snapped.width, wide.width)
        XCTAssertEqual(snapped.height, wide.height)
    }

    func testTiePrefersMinEdge() {
        let panel = PanelFrame(x: 8, y: 8, width: visible.width - 16, height: visible.height - 16)
        XCTAssertEqual(abs(panel.minX - visible.minX), abs(panel.maxX - visible.maxX))
        XCTAssertEqual(abs(panel.minY - visible.minY), abs(panel.maxY - visible.maxY))
        let snapped = PanelSnapEngine.snappedFrame(panel, in: visible)
        XCTAssertEqual(snapped.x, visible.minX + margin)
        XCTAssertEqual(snapped.y, visible.minY + margin)
    }

    func testDisabledSnapLeavesFrameUnchanged() {
        let panel = frame(x: 3, y: 4)
        let snapped = PanelSnapEngine.snappedFrame(panel, in: visible, enabled: false)
        XCTAssertEqual(snapped, panel)
    }

    func testPresetsKeepSize() {
        let panel = frame(x: 80, y: 90)
        for preset in PanelLayoutPreset.allCases {
            let result = PanelSnapEngine.frame(for: preset, panelFrame: panel, visibleFrame: visible)
            XCTAssertEqual(result.width, panel.width, "\(preset)")
            XCTAssertEqual(result.height, panel.height, "\(preset)")
        }
    }

    func testTopLeftPreset() {
        let result = PanelSnapEngine.frame(for: .topLeft, panelFrame: frame(x: 80, y: 90), visibleFrame: visible)
        XCTAssertEqual(result.x, visible.minX + margin)
        XCTAssertEqual(result.y, visible.maxY - margin - size.height)
    }

    func testTopRightPreset() {
        let result = PanelSnapEngine.frame(for: .topRight, panelFrame: frame(x: 80, y: 90), visibleFrame: visible)
        XCTAssertEqual(result.x, visible.maxX - margin - size.width)
        XCTAssertEqual(result.y, visible.maxY - margin - size.height)
    }

    func testBottomLeftPreset() {
        let result = PanelSnapEngine.frame(for: .bottomLeft, panelFrame: frame(x: 80, y: 90), visibleFrame: visible)
        XCTAssertEqual(result.x, visible.minX + margin)
        XCTAssertEqual(result.y, visible.minY + margin)
    }

    func testBottomRightPreset() {
        let result = PanelSnapEngine.frame(for: .bottomRight, panelFrame: frame(x: 80, y: 90), visibleFrame: visible)
        XCTAssertEqual(result.x, visible.maxX - margin - size.width)
        XCTAssertEqual(result.y, visible.minY + margin)
    }

    func testCenterPreset() {
        let result = PanelSnapEngine.frame(for: .center, panelFrame: frame(x: 80, y: 90), visibleFrame: visible)
        XCTAssertEqual(result.x, visible.midX - size.width / 2)
        XCTAssertEqual(result.y, visible.midY - size.height / 2)
    }

    func testSnapIsIdempotent() {
        let panel = frame(x: 3, y: visible.maxY - size.height - 2)
        let once = PanelSnapEngine.snappedFrame(panel, in: visible)
        let twice = PanelSnapEngine.snappedFrame(once, in: visible)
        XCTAssertEqual(once, twice)
    }

    func testPresetThenSnapIsIdempotent() {
        let laidOut = PanelSnapEngine.frame(
            for: .topRight,
            panelFrame: frame(x: 80, y: 90),
            visibleFrame: visible
        )
        XCTAssertEqual(PanelSnapEngine.snappedFrame(laidOut, in: visible), laidOut)
    }

    func testOversizedPresetThenClampStaysOnscreen() {
        let huge = PanelFrame(x: 10, y: 10, width: 2000, height: 1600)
        let laidOut = PanelSnapEngine.frame(for: .topLeft, panelFrame: huge, visibleFrame: visible)
        let clamped = PanelFrameRecovery.clamp(laidOut, to: visible)
        XCTAssertGreaterThanOrEqual(clamped.minX, visible.minX)
        XCTAssertGreaterThanOrEqual(clamped.minY, visible.minY)
        XCTAssertLessThanOrEqual(clamped.maxX, visible.maxX)
        XCTAssertLessThanOrEqual(clamped.maxY, visible.maxY)
        XCTAssertFalse(clamped.x.isNaN)
        XCTAssertFalse(clamped.y.isNaN)
    }

    func testUsesDestinationVisibleFrameForSecondDisplay() {
        let second = PanelFrame(x: -1920, y: 0, width: 1920, height: 1080)
        let panel = PanelFrame(
            x: second.maxX - size.width - 4,
            y: second.maxY - size.height - 3,
            width: size.width,
            height: size.height
        )
        let snapped = PanelSnapEngine.snappedFrame(panel, in: second)
        XCTAssertEqual(snapped.x, second.maxX - margin - size.width)
        XCTAssertEqual(snapped.y, second.maxY - margin - size.height)
    }

    func testRecoveryDoesNotSnapNearEdge() {
        let panel = frame(x: 3, y: 100)
        let recovered = PanelFrameRecovery.recover(
            frame: panel,
            displayIdentifier: "main",
            displays: [DisplaySnapshot(identifier: "main", visibleFrame: visible, isMain: true)]
        )
        XCTAssertEqual(recovered.frame, panel)
        XCTAssertNotEqual(PanelSnapEngine.snappedFrame(panel, in: visible).x, panel.x)
    }

    func testLayoutMenuTitles() {
        XCTAssertEqual(
            PanelLayoutPreset.allCases.map(\.menuTitle),
            ["左上角", "右上角", "左下角", "右下角", "居中"]
        )
    }

    private func frame(x: Double, y: Double) -> PanelFrame {
        PanelFrame(x: x, y: y, width: size.width, height: size.height)
    }
}

#if canImport(AppKit)
import AppKit

final class PanelLayoutMenuTests: XCTestCase {
    func testLayoutSubmenuItems() {
        let item = PanelLayoutMenu.makeItem(target: nil, action: #selector(NSObject.description), enabled: true)
        XCTAssertEqual(item.title, "布局")
        XCTAssertTrue(item.isEnabled)
        let titles = item.submenu?.items.map(\.title)
        XCTAssertEqual(titles, ["左上角", "右上角", "左下角", "右下角", "居中"])
        XCTAssertEqual(
            item.submenu?.items.compactMap { $0.representedObject as? String },
            PanelLayoutPreset.allCases.map(\.rawValue)
        )
    }

    func testLayoutMenuDisabledWhenLocked() {
        let item = PanelLayoutMenu.makeItem(target: nil, action: #selector(NSObject.description), enabled: false)
        XCTAssertFalse(item.isEnabled)
        XCTAssertTrue(item.submenu?.items.allSatisfy { !$0.isEnabled } ?? false)
    }
}
#endif
