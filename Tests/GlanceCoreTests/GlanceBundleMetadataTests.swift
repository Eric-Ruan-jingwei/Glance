import Foundation
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class GlanceBundleMetadataTests: XCTestCase {
    func testSourceInfoPlistIsCanonicalAppVersion() throws {
        let plist = try loadSourceInfoPlist()
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.27.0")
        XCTAssertEqual(plist["CFBundleVersion"] as? String, "50")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.glance.app")
        XCTAssertEqual(plist["LSMultipleInstancesProhibited"] as? Bool, true)
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
    }

    func testAppVersionIsIndependentOfDatabaseSchemas() {
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(LinkDatabase.currentSchemaVersion, 1)
    }

    private func loadSourceInfoPlist() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Glance/Info.plist")
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(object as? [String: Any])
    }
}
