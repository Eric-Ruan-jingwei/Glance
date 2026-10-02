import Foundation

enum PanelDatabaseLoadOutcome: Equatable {
    case missing
    case loaded(migratedFromLegacy: Bool)
    case recoveredFromBackup
    case quarantinedCorruptAndEmpty
    case unsupportedFutureSchema(Int)
}

private enum PanelDatabaseApplyResult {
    case ok(migratedFromLegacy: Bool)
    case unsupportedFutureSchema(Int)
    case unreadable
}

@MainActor
final class PanelRepository {
    private var records: [UUID: PanelRecord] = [:]
    private let fileURL: URL
    private let fileManager: FileManager
    private(set) var lastLoadOutcome: PanelDatabaseLoadOutcome = .missing

    var backupURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("panels.backup.json")
    }

    init(fileURL: URL, fileManager: FileManager = .default) throws {
        self.fileURL = fileURL
        self.fileManager = fileManager
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        loadRecovering()
    }

    func all() throws -> [PanelRecord] {
        records.values.sorted { $0.createdAt < $1.createdAt }
    }

    func record(id: UUID) throws -> PanelRecord? {
        records[id]
    }

    func insert(_ record: PanelRecord) throws {
        try assertMetadataWritable()
        records[record.id] = record
        try save()
    }

    func delete(id: UUID) throws {
        try assertMetadataWritable()
        records[id] = nil
        try save()
    }

    func save() throws {
        if case .unsupportedFutureSchema(let version) = lastLoadOutcome {
            NSLog(
                "Glance persistence: refusing to write panels.json because it uses unsupported schema %d (this app writes schema %d)",
                version,
                PanelDatabase.currentSchemaVersion
            )
            return
        }
        let database = PanelDatabase(
            schemaVersion: PanelDatabase.currentSchemaVersion,
            panels: records.values.sorted { $0.createdAt < $1.createdAt }
        )
        let data = try PanelDatabaseCodec.encode(database)
        try data.write(to: fileURL, options: .atomic)
        do {
            try data.write(to: backupURL, options: .atomic)
        } catch {
            NSLog("Glance persistence: primary metadata saved but backup failed: %@", error.localizedDescription)
        }
    }

    func touch(_ record: PanelRecord) {
        record.updatedAt = Date()
    }

    private func loadRecovering() {
        let primaryExisted = fileManager.fileExists(atPath: fileURL.path)

        if primaryExisted {
            switch apply(dataAt: fileURL) {
            case .ok:
                if case .loaded(let migrated) = lastLoadOutcome, migrated {
                    NSLog(
                        "Glance persistence: migrated legacy panels.json array to schema %d",
                        PanelDatabase.currentSchemaVersion
                    )
                    rewriteRecoveredMetadata()
                }
                return
            case .unsupportedFutureSchema:
                return
            case .unreadable:
                quarantineCorruptFile(at: fileURL)
            }
        }

        if fileManager.fileExists(atPath: backupURL.path) {
            switch apply(dataAt: backupURL) {
            case .ok:
                lastLoadOutcome = .recoveredFromBackup
                NSLog("Glance persistence: restored metadata from %@", backupURL.path)
                rewriteRecoveredMetadata()
                return
            case .unsupportedFutureSchema:
                return
            case .unreadable:
                break
            }
        }

        records = [:]
        lastLoadOutcome = primaryExisted ? .quarantinedCorruptAndEmpty : .missing
        if lastLoadOutcome == .quarantinedCorruptAndEmpty {
            NSLog("Glance persistence: starting with empty database after corrupt metadata")
        }
    }

    private func rewriteRecoveredMetadata() {
        do {
            try save()
        } catch {
            NSLog("Glance persistence: failed to rewrite recovered metadata: %@", error.localizedDescription)
        }
    }

    private func apply(dataAt url: URL) -> PanelDatabaseApplyResult {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try PanelDatabaseCodec.decode(from: data)
            let deduped = PanelDatabaseCodec.deduplicate(decoded.database.panels)
            if deduped.duplicateCount > 0 {
                NSLog(
                    "Glance persistence: dropped %d duplicate panel UUID(s), keeping newest updatedAt",
                    deduped.duplicateCount
                )
            }
            records = Dictionary(uniqueKeysWithValues: deduped.panels.map { ($0.id, $0) })
            lastLoadOutcome = .loaded(migratedFromLegacy: decoded.migratedFromLegacy)
            return .ok(migratedFromLegacy: decoded.migratedFromLegacy)
        } catch PanelDatabaseError.unsupportedFutureSchema(let version) {
            records = [:]
            lastLoadOutcome = .unsupportedFutureSchema(version)
            NSLog(
                "Glance persistence: %@ uses schema %d; this app supports schema %d. Leaving the file untouched and skipping write-back.",
                url.lastPathComponent,
                version,
                PanelDatabase.currentSchemaVersion
            )
            return .unsupportedFutureSchema(version)
        } catch {
            NSLog("Glance persistence: could not decode %@: %@", url.lastPathComponent, error.localizedDescription)
            return .unreadable
        }
    }

    private func assertMetadataWritable() throws {
        if case .unsupportedFutureSchema(let version) = lastLoadOutcome {
            throw PanelDatabaseError.unsupportedFutureSchema(version)
        }
    }

    private func quarantineCorruptFile(at url: URL) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        let name = "panels.corrupted-\(formatter.string(from: Date())).json"
        let destination = url.deletingLastPathComponent().appendingPathComponent(name)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: url, to: destination)
            NSLog("Glance persistence: preserved corrupt database at %@", destination.path)
        } catch {
            NSLog("Glance persistence: failed to preserve corrupt database: %@", error.localizedDescription)
            do {
                try fileManager.copyItem(at: url, to: destination)
                NSLog("Glance persistence: copied corrupt database to %@", destination.path)
            } catch {
                NSLog("Glance persistence: failed to copy corrupt database: %@", error.localizedDescription)
            }
        }
    }
}
