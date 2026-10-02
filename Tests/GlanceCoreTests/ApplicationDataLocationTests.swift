import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class ApplicationDataLocationTests: XCTestCase {
    func testDefaultRootIsApplicationSupportGlance() {
        let root = ApplicationDataLocation.resolve(environment: [:])
        XCTAssertTrue(root.path.contains("Application Support"))
        XCTAssertTrue(root.path.hasSuffix("/Glance"))
        XCTAssertEqual(root, ApplicationDataLocation.defaultRoot())
        XCTAssertFalse(root.path.contains("/tmp/GlanceTests"))
    }

    func testOverrideUsesIsolatedTemporaryRoot() {
        let override = "/tmp/GlanceTests-\(UUID().uuidString)"
        let root = ApplicationDataLocation.resolve(
            environment: [ApplicationDataLocation.environmentKey: override]
        )
        XCTAssertEqual(
            root.path,
            URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL.path
        )
        XCTAssertTrue(ApplicationDataLocation.isIsolatedFromUserData(root))
        XCTAssertNotEqual(root, ApplicationDataLocation.defaultRoot())
    }

    func testEmptyOverrideFallsBackToApplicationSupport() {
        let root = ApplicationDataLocation.resolve(
            environment: [ApplicationDataLocation.environmentKey: "   "]
        )
        XCTAssertEqual(root, ApplicationDataLocation.defaultRoot())
    }

    func testProductionOverrideIsRejected() {
        let production = ApplicationDataLocation.defaultRoot()
        let root = ApplicationDataLocation.resolve(
            environment: [ApplicationDataLocation.environmentKey: production.path]
        )
        XCTAssertNotEqual(root, production)
        XCTAssertTrue(ApplicationDataLocation.isIsolatedFromUserData(root))
        XCTAssertTrue(root.path.contains("GlanceTests-rejected-production-override"))
    }

    func testNestedUserDataOverrideIsRejected() {
        let nested = ApplicationDataLocation.defaultRoot().appendingPathComponent("Database", isDirectory: true)
        let root = ApplicationDataLocation.resolve(
            environment: [ApplicationDataLocation.environmentKey: nested.path]
        )
        XCTAssertFalse(ApplicationDataLocation.isUserDataLocation(root))
    }

    func testUserDataDirectoryIsNeverSafeToReset() {
        XCTAssertFalse(ApplicationDataLocation.isSafeToReset(ApplicationDataLocation.defaultRoot()))
        XCTAssertFalse(
            ApplicationDataLocation.isSafeToReset(
                ApplicationDataLocation.defaultRoot().appendingPathComponent("Database")
            )
        )
    }

    func testTemporaryOverrideIsSafeToReset() {
        XCTAssertTrue(
            ApplicationDataLocation.isSafeToReset(URL(fileURLWithPath: "/tmp/GlanceTests", isDirectory: true))
        )
    }

    func testPrepareResetsTemporaryOverride() throws {
        let fileManager = FileManager.default
        let override = fileManager.temporaryDirectory
            .appendingPathComponent("GlanceTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: override) }

        try fileManager.createDirectory(at: override, withIntermediateDirectories: true)
        let leftover = override.appendingPathComponent("stale.txt")
        try Data("stale".utf8).write(to: leftover)

        let environment = [ApplicationDataLocation.environmentKey: override.path]
        let resolved = ApplicationDataLocation.resolve(environment: environment, fileManager: fileManager)
        XCTAssertTrue(ApplicationDataLocation.isIsolatedFromUserData(resolved, fileManager: fileManager))
        try ApplicationDataLocation.prepare(resolved, environment: environment, fileManager: fileManager)

        XCTAssertTrue(fileManager.fileExists(atPath: resolved.path))
        XCTAssertFalse(fileManager.fileExists(atPath: leftover.path))
    }
}
