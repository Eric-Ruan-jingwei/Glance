import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class PanelRepositoryTests: XCTestCase {
    func testCurrentSchemaRoundTrip() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(record)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(reloaded.lastLoadOutcome, .loaded(migratedFromLegacy: false))
            let panels = try reloaded.all()
            XCTAssertEqual(panels.count, 1)
            XCTAssertEqual(panels[0].id, record.id)
            let decoded = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            XCTAssertEqual(decoded.database.schemaVersion, PanelDatabase.currentSchemaVersion)
            XCTAssertTrue(FileManager.default.fileExists(atPath: reloaded.backupURL.path))
        }
    }

    func testLegacyRawArrayMigrates() throws {
        try withTempRepository { _, metadataURL in
            try Data(GlanceTestFixtures.legacyArrayJSON.utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .loaded(migratedFromLegacy: true))
            XCTAssertEqual(try repository.all().count, 1)
            XCTAssertTrue(try repository.all()[0].isPinned)
            let second = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(second.lastLoadOutcome, .loaded(migratedFromLegacy: false))
            let decoded = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            XCTAssertEqual(decoded.database.schemaVersion, 1)
        }
    }

    func testLegacyCodecDetectsRawArray() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.legacyArrayJSON.utf8))
        XCTAssertTrue(decoded.migratedFromLegacy)
        XCTAssertEqual(decoded.database.schemaVersion, 1)
        XCTAssertEqual(decoded.database.panels.count, 1)
    }

    func testMissingFieldsUseDefaults() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.minimalRecordJSON.utf8))
        let panel = try XCTUnwrap(decoded.database.panels.first)
        XCTAssertTrue(panel.isPinned)
        XCTAssertFalse(panel.isLocked)
        XCTAssertFalse(panel.isCollapsed)
        XCTAssertFalse(panel.isPassThrough)
        XCTAssertEqual(panel.opacity, 1)
        XCTAssertEqual(panel.themeIdentifier, "system")
        XCTAssertEqual(panel.payloadVersion, 1)
    }

    func testCorruptDatabaseDoesNotPreventLaunch() throws {
        try withTempRepository { directory, metadataURL in
            try Data("{ not-json".utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .quarantinedCorruptAndEmpty)
            XCTAssertTrue(try repository.all().isEmpty)
            let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            XCTAssertTrue(leftovers.contains { $0.hasPrefix("panels.corrupted-") && $0.hasSuffix(".json") })
        }
    }

    func testBackupRecovery() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            let first = try PanelRepository(fileURL: metadataURL)
            try first.insert(record)
            try Data("CORRUPT".utf8).write(to: metadataURL)
            let recovered = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(recovered.lastLoadOutcome, .recoveredFromBackup)
            XCTAssertEqual(try recovered.all().map(\.id), [record.id])
        }
    }

    func testDuplicateUUIDKeepsNewest() throws {
        try withTempRepository { _, metadataURL in
            let id = UUID(uuidString: "0D74D7D4-33F4-4795-A657-D40F456187A7")!
            let older = GlanceTestFixtures.sampleRecord(id: id, updatedAt: Date(timeIntervalSince1970: 100))
            older.frame.x = 10
            let newer = GlanceTestFixtures.sampleRecord(id: id, updatedAt: Date(timeIntervalSince1970: 200))
            newer.frame.x = 99
            let data = try PanelDatabaseCodec.encode(
                PanelDatabase(schemaVersion: 1, panels: [older, newer])
            )
            try data.write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            let panels = try repository.all()
            XCTAssertEqual(panels.count, 1)
            XCTAssertEqual(panels[0].frame.x, 99)
        }
    }

    func testAtomicSaveWritesPrimaryThenBackup() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(GlanceTestFixtures.sampleRecord())
            let primaryDB = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            let backupDB = try PanelDatabaseCodec.decode(from: Data(contentsOf: repository.backupURL))
            XCTAssertEqual(primaryDB.database.schemaVersion, 1)
            XCTAssertEqual(backupDB.database.schemaVersion, 1)
            XCTAssertEqual(primaryDB.database.panels.map(\.id), backupDB.database.panels.map(\.id))
        }
    }

    func testFutureSchemaIsRejectedByCodec() {
        XCTAssertThrowsError(try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.futureSchemaJSON.utf8))) { error in
            XCTAssertEqual(error as? PanelDatabaseError, .unsupportedFutureSchema(2))
        }
    }

    func testFutureSchemaDoesNotQuarantineOrOverwrite() throws {
        try withTempRepository { directory, metadataURL in
            let original = Data(GlanceTestFixtures.futureSchemaJSON.utf8)
            try original.write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .unsupportedFutureSchema(2))
            XCTAssertTrue(try repository.all().isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
            let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            XCTAssertFalse(leftovers.contains { $0.hasPrefix("panels.corrupted-") })
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
        }
    }

    func testFutureSchemaDoesNotWriteEmptyDatabase() throws {
        try withTempRepository { _, metadataURL in
            let original = Data(GlanceTestFixtures.futureSchemaJSON.utf8)
            try original.write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.save()
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
            XCTAssertThrowsError(try repository.insert(GlanceTestFixtures.sampleRecord())) { error in
                XCTAssertEqual(error as? PanelDatabaseError, .unsupportedFutureSchema(2))
            }
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: repository.backupURL.path))
        }
    }

    private func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceRepoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, directory.appendingPathComponent("panels.json"))
    }
}
