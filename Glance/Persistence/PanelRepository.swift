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
    typealias PrimaryMetadataWriter = (Data, URL) throws -> Void

    private var records: [UUID: PanelRecord] = [:]
    private var workspaces: [String: WorkspaceRecord] = [:]
    private let fileURL: URL
    private let fileManager: FileManager
    private let writePrimaryMetadata: PrimaryMetadataWriter
    private(set) var lastLoadOutcome: PanelDatabaseLoadOutcome = .missing

    var backupURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("panels.backup.json")
    }

    init(
        fileURL: URL,
        fileManager: FileManager = .default,
        writePrimaryMetadata: PrimaryMetadataWriter? = nil
    ) throws {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.writePrimaryMetadata = writePrimaryMetadata ?? { data, url in
            try data.write(to: url, options: .atomic)
        }
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

    func allWorkspaces() throws -> [WorkspaceRecord] {
        WorkspaceCatalog.sorted(Array(workspaces.values))
    }

    func workspace(id: String) throws -> WorkspaceRecord? {
        workspaces[id]
    }

    func availableWorkspaceIDs() -> Set<String> {
        Set(workspaces.keys)
    }

    func insert(_ record: PanelRecord) throws {
        try assertMetadataWritable()
        let previous = records[record.id]
        records[record.id] = record
        do {
            try save()
        } catch {
            restore(id: record.id, previous: previous)
            throw error
        }
    }

    func delete(id: UUID) throws {
        try assertMetadataWritable()
        let previous = records[id]
        records[id] = nil
        do {
            try save()
        } catch {
            restore(id: id, previous: previous)
            throw error
        }
    }

    func createWorkspace(name: String) throws -> WorkspaceRecord {
        try assertMetadataWritable()
        let trimmed = try WorkspaceName.validate(name)
        let existing = try allWorkspaces()
        if WorkspaceName.isDuplicate(trimmed, among: existing) {
            throw WorkspaceError.duplicateName
        }
        let now = Date()
        let record = WorkspaceRecord(
            id: UUID().uuidString,
            name: trimmed,
            createdAt: now,
            updatedAt: now
        )
        workspaces[record.id] = record
        do {
            try save()
            return record
        } catch {
            workspaces.removeValue(forKey: record.id)
            throw error
        }
    }

    func renameWorkspace(id: String, name: String) throws {
        try assertMetadataWritable()
        guard id != WorkspaceRecord.defaultID else {
            throw WorkspaceError.cannotRenameDefault
        }
        guard var existing = workspaces[id] else {
            throw WorkspaceError.workspaceNotFound
        }
        let trimmed = try WorkspaceName.validate(name)
        if WorkspaceName.isDuplicate(trimmed, among: try allWorkspaces(), excluding: id) {
            throw WorkspaceError.duplicateName
        }
        let previous = existing
        existing.name = trimmed
        existing.updatedAt = Date()
        workspaces[id] = existing
        do {
            try save()
        } catch {
            workspaces[id] = previous
            throw error
        }
    }

    func deleteWorkspace(id: String) throws {
        try assertMetadataWritable()
        guard id != WorkspaceRecord.defaultID else {
            throw WorkspaceError.cannotDeleteDefault
        }
        guard let existing = workspaces[id] else {
            throw WorkspaceError.workspaceNotFound
        }
        let moved = records.values.filter { $0.workspaceID == id }
        let snapshots = moved.map { panel in
            PanelMembershipSnapshot(panel: panel, workspaceID: panel.workspaceID, updatedAt: panel.updatedAt)
        }
        for panel in moved {
            panel.workspaceID = WorkspaceRecord.defaultID
            touch(panel)
        }
        workspaces.removeValue(forKey: id)
        do {
            try save()
        } catch {
            workspaces[id] = existing
            for snapshot in snapshots {
                snapshot.panel.workspaceID = snapshot.workspaceID
                snapshot.panel.updatedAt = snapshot.updatedAt
            }
            throw error
        }
    }

    func movePanel(id: UUID, toWorkspaceID: String) throws {
        try assertMetadataWritable()
        guard let panel = records[id] else {
            throw WorkspaceError.panelNotFound
        }
        guard workspaces[toWorkspaceID] != nil else {
            throw WorkspaceError.workspaceNotFound
        }
        guard panel.workspaceID != toWorkspaceID else { return }
        let previousWorkspaceID = panel.workspaceID
        let previousUpdatedAt = panel.updatedAt
        panel.workspaceID = toWorkspaceID
        touch(panel)
        do {
            try save()
        } catch {
            panel.workspaceID = previousWorkspaceID
            panel.updatedAt = previousUpdatedAt
            throw error
        }
    }

    func setCustomTitle(id: UUID, title: String?) throws {
        try assertMetadataWritable()
        guard let panel = records[id] else {
            throw PanelTitleError.panelNotFound
        }
        let normalized = try PanelTitle.validated(title)
        guard panel.customTitle != normalized else { return }
        let previousTitle = panel.customTitle
        let previousUpdatedAt = panel.updatedAt
        panel.customTitle = normalized
        touch(panel)
        do {
            try save()
        } catch {
            panel.customTitle = previousTitle
            panel.updatedAt = previousUpdatedAt
            throw error
        }
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
        ensureDefaultWorkspace()
        let database = PanelDatabase(
            schemaVersion: PanelDatabase.currentSchemaVersion,
            workspaces: try allWorkspaces(),
            panels: records.values.sorted { $0.createdAt < $1.createdAt }
        )
        let data = try PanelDatabaseCodec.encode(database)
        try writePrimaryMetadata(data, fileURL)
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
                        "Glance persistence: migrated panels.json to schema %d",
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
        workspaces = [:]
        ensureDefaultWorkspace()
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
            let normalized = PanelDatabaseNormalizer.normalize(decoded.database)
            let deduped = PanelDatabaseCodec.deduplicate(normalized.panels)
            if deduped.duplicateCount > 0 {
                NSLog(
                    "Glance persistence: dropped %d duplicate panel UUID(s), keeping newest updatedAt",
                    deduped.duplicateCount
                )
            }
            records = Dictionary(uniqueKeysWithValues: deduped.panels.map { ($0.id, $0) })
            workspaces = Dictionary(
                normalized.workspaces.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            ensureDefaultWorkspace()
            lastLoadOutcome = .loaded(migratedFromLegacy: decoded.migratedFromLegacy)
            return .ok(migratedFromLegacy: decoded.migratedFromLegacy)
        } catch PanelDatabaseError.unsupportedFutureSchema(let version) {
            records = [:]
            workspaces = [:]
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

    private func restore(id: UUID, previous: PanelRecord?) {
        if let previous {
            records[id] = previous
        } else {
            records.removeValue(forKey: id)
        }
    }

    private func ensureDefaultWorkspace(at date: Date = Date()) {
        if workspaces[WorkspaceRecord.defaultID] == nil {
            workspaces[WorkspaceRecord.defaultID] = WorkspaceRecord.makeDefault(at: date)
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

private struct PanelMembershipSnapshot {
    let panel: PanelRecord
    let workspaceID: String
    let updatedAt: Date
}
