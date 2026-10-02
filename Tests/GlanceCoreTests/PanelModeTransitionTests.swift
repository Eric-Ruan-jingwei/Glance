import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelModeTransitionTests: XCTestCase {
    func testReadingAllowsEditing() {
        XCTAssertTrue(PanelModeTransition.canBeginEditing(from: .reading))
    }

    func testPassThroughAllowsEditing() {
        XCTAssertTrue(PanelModeTransition.canBeginEditing(from: .passThrough))
    }

    func testEditingDoesNotReenter() {
        XCTAssertFalse(PanelModeTransition.canBeginEditing(from: .editing))
    }

    func testExitEditingReturnsToReading() {
        XCTAssertEqual(
            PanelModeTransition.stateAfterLeavingEditing(persistedPassThrough: false),
            .reading
        )
    }

    func testExitEditingReturnsToPassThrough() {
        XCTAssertEqual(
            PanelModeTransition.stateAfterLeavingEditing(persistedPassThrough: true),
            .passThrough
        )
    }

    func testPersistedPreferenceUnchangedByTemporaryEdit() {
        let persistedPassThrough = true
        XCTAssertTrue(PanelModeTransition.canBeginEditing(from: .passThrough))
        let restored = PanelModeTransition.stateAfterLeavingEditing(persistedPassThrough: persistedPassThrough)
        XCTAssertTrue(persistedPassThrough)
        XCTAssertEqual(restored, .passThrough)
    }
}
