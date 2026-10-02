import Foundation
@testable import GlanceCore

enum PanelRepositoryChecks {
    @MainActor
    static func run() {
        currentSchemaRoundTrip()
        legacyRawArrayMigrates()
        legacyCodecDetectsRawArray()
        missingFieldsUseDefaults()
        corruptDatabaseDoesNotPreventLaunch()
        backupRecovery()
        duplicateUUIDKeepsNewest()
        atomicSaveWritesPrimaryThenBackup()
    }

    @MainActor
    private static func withTempRepository(_ body: (URL, URL) throws -> Void) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceRepoTests-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            try body(directory, directory.appendingPathComponent("panels.json"))
        } catch {
            CheckRun.expect(false, "temp repository failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func currentSchemaRoundTrip() {
        withTempRepository { _, metadataURL in
            let record = sampleRecord()
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(record)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            CheckRun.equal(reloaded.lastLoadOutcome, .loaded(migratedFromLegacy: false), "round-trip load outcome")
            let panels = try reloaded.all()
            CheckRun.equal(panels.count, 1, "round-trip panel count")
            CheckRun.equal(panels[0].id, record.id, "round-trip id")
            let decoded = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            CheckRun.equal(decoded.database.schemaVersion, 1, "schema version")
            CheckRun.expect(FileManager.default.fileExists(atPath: reloaded.backupURL.path), "backup exists")
        }
    }

    @MainActor
    private static func legacyRawArrayMigrates() {
        withTempRepository { _, metadataURL in
            try Data(legacyArrayJSON.utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            CheckRun.equal(repository.lastLoadOutcome, .loaded(migratedFromLegacy: true), "legacy first load")
            CheckRun.equal(try repository.all().count, 1, "legacy panel count")
            CheckRun.expect(try repository.all()[0].isPinned, "legacy isPinned default/value")
            let second = try PanelRepository(fileURL: metadataURL)
            CheckRun.equal(second.lastLoadOutcome, .loaded(migratedFromLegacy: false), "second load is envelope")
            let decoded = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            CheckRun.equal(decoded.database.schemaVersion, 1, "migrated schema")
        }
    }

    @MainActor
    private static func legacyCodecDetectsRawArray() {
        do {
            let decoded = try PanelDatabaseCodec.decode(from: Data(legacyArrayJSON.utf8))
            CheckRun.expect(decoded.migratedFromLegacy, "codec detects legacy array")
            CheckRun.equal(decoded.database.schemaVersion, 1, "legacy becomes schema 1")
            CheckRun.equal(decoded.database.panels.count, 1, "legacy panel count")
        } catch {
            CheckRun.expect(false, "legacy codec threw \(error)")
        }
    }

    @MainActor
    private static func missingFieldsUseDefaults() {
        do {
            let decoded = try PanelDatabaseCodec.decode(from: Data(minimalRecordJSON.utf8))
            guard let panel = decoded.database.panels.first else {
                CheckRun.expect(false, "minimal JSON produced no panels")
                return
            }
            CheckRun.expect(panel.isPinned, "default isPinned")
            CheckRun.expect(!panel.isLocked, "default isLocked")
            CheckRun.expect(!panel.isCollapsed, "default isCollapsed")
            CheckRun.expect(!panel.isPassThrough, "default isPassThrough")
            CheckRun.equal(panel.opacity, 1, "default opacity")
            CheckRun.equal(panel.themeIdentifier, "system", "default theme")
            CheckRun.equal(panel.payloadVersion, 1, "default payloadVersion")
        } catch {
            CheckRun.expect(false, "minimal JSON threw \(error)")
        }
    }

    @MainActor
    private static func corruptDatabaseDoesNotPreventLaunch() {
        withTempRepository { directory, metadataURL in
            try Data("{ not-json".utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            CheckRun.equal(repository.lastLoadOutcome, .quarantinedCorruptAndEmpty, "corrupt outcome")
            CheckRun.expect(try repository.all().isEmpty, "corrupt starts empty")
            let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            CheckRun.expect(
                leftovers.contains { $0.hasPrefix("panels.corrupted-") && $0.hasSuffix(".json") },
                "corrupt file preserved"
            )
        }
    }

    @MainActor
    private static func backupRecovery() {
        withTempRepository { _, metadataURL in
            let record = sampleRecord()
            let first = try PanelRepository(fileURL: metadataURL)
            try first.insert(record)
            try Data("CORRUPT".utf8).write(to: metadataURL)
            let recovered = try PanelRepository(fileURL: metadataURL)
            CheckRun.equal(recovered.lastLoadOutcome, .recoveredFromBackup, "backup outcome")
            CheckRun.equal(try recovered.all().map(\.id), [record.id], "backup panel id")
        }
    }

    @MainActor
    private static func duplicateUUIDKeepsNewest() {
        withTempRepository { _, metadataURL in
            let id = UUID(uuidString: "0D74D7D4-33F4-4795-A657-D40F456187A7")!
            let older = sampleRecord(id: id, updatedAt: Date(timeIntervalSince1970: 100))
            older.x = 10
            let newer = sampleRecord(id: id, updatedAt: Date(timeIntervalSince1970: 200))
            newer.x = 99
            let data = try PanelDatabaseCodec.encode(
                PanelDatabase(schemaVersion: 1, panels: [older, newer])
            )
            try data.write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            let panels = try repository.all()
            CheckRun.equal(panels.count, 1, "duplicate collapsed to one")
            CheckRun.equal(panels[0].x, 99, "newest duplicate kept")
        }
    }

    @MainActor
    private static func atomicSaveWritesPrimaryThenBackup() {
        withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(sampleRecord())
            let primaryDB = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            let backupDB = try PanelDatabaseCodec.decode(from: Data(contentsOf: repository.backupURL))
            CheckRun.equal(primaryDB.database.schemaVersion, 1, "primary schema")
            CheckRun.equal(backupDB.database.schemaVersion, 1, "backup schema")
            CheckRun.equal(primaryDB.database.panels.map(\.id), backupDB.database.panels.map(\.id), "backup matches primary")
        }
    }
}

private func sampleRecord(
    id: UUID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
    updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> PanelRecord {
    PanelRecord(
        id: id,
        kindIdentifier: PanelKind.text,
        frame: NSRect(x: 100, y: 200, width: 320, height: 220),
        displayIdentifier: "1",
        payloadPath: "Panels/\(id.uuidString)",
        payloadVersion: 1,
        createdAt: Date(timeIntervalSince1970: 1_699_000_000),
        updatedAt: updatedAt
    )
}

private let legacyArrayJSON = """
[
  {
    "createdAt" : "2026-10-02T15:32:51Z",
    "displayIdentifier" : "1",
    "height" : 220,
    "id" : "0D74D7D4-33F4-4795-A657-D40F456187A7",
    "isCollapsed" : false,
    "isLocked" : false,
    "isPassThrough" : false,
    "isPinned" : true,
    "kindIdentifier" : "com.glance.panel.text",
    "opacity" : 1,
    "payloadPath" : "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7",
    "payloadVersion" : 1,
    "themeIdentifier" : "system",
    "updatedAt" : "2026-10-02T15:32:51Z",
    "width" : 320,
    "x" : 1130,
    "y" : 683
  }
]
"""

private let minimalRecordJSON = """
[
  {
    "createdAt" : "2026-10-02T15:32:51Z",
    "displayIdentifier" : "1",
    "height" : 220,
    "id" : "0D74D7D4-33F4-4795-A657-D40F456187A7",
    "kindIdentifier" : "com.glance.panel.text",
    "payloadPath" : "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7",
    "updatedAt" : "2026-10-02T15:32:51Z",
    "width" : 320,
    "x" : 10,
    "y" : 20
  }
]
"""
