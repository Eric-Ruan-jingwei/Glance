import Foundation

struct PanelDatabase: Codable, Equatable {
    var schemaVersion: Int
    var workspaces: [WorkspaceRecord]
    var panels: [PanelRecord]

    static let currentSchemaVersion = 5

    init(
        schemaVersion: Int = currentSchemaVersion,
        workspaces: [WorkspaceRecord] = [],
        panels: [PanelRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.workspaces = workspaces
        self.panels = panels
    }
}

enum PanelDatabaseError: Error, Equatable, LocalizedError {
    case unreadable
    case unsupportedFutureSchema(Int)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "panels.json is not a readable schema 0 array, schema 1 envelope, schema 2 envelope, schema 3 envelope, schema 4 envelope, or schema 5 envelope"
        case .unsupportedFutureSchema(let version):
            return "panels.json uses unsupported schema \(version); this app supports schema \(PanelDatabase.currentSchemaVersion)"
        }
    }
}

/// Reads `schemaVersion` without requiring current `PanelRecord` fields.
private struct PanelDatabaseSchemaPeek: Decodable {
    var schemaVersion: Int
}

enum PanelDatabaseCodec {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Accepts schema 5 envelopes, schema 4/3/2/1 envelopes, and V0.1 raw arrays (schema 0).
    /// Future envelopes are rejected without rewriting them as schema 5.
    static func decode(from data: Data, decoder: JSONDecoder = makeDecoder()) throws -> (database: PanelDatabase, migratedFromLegacy: Bool) {
        if let peek = try? decoder.decode(PanelDatabaseSchemaPeek.self, from: data) {
            switch peek.schemaVersion {
            case PanelDatabase.currentSchemaVersion:
                let envelope = try decoder.decode(PanelDatabase.self, from: data)
                return (envelope, false)

            case 4:
                let v4 = try decoder.decode(PanelDatabaseV4.self, from: data)
                return (v4.migrated(), true)

            case 3:
                let v3 = try decoder.decode(PanelDatabaseV3.self, from: data)
                return (v3.migrated(), true)

            case 2:
                let v2 = try decoder.decode(PanelDatabaseV2.self, from: data)
                return (v2.migrated(), true)

            case 1:
                let v1 = try decoder.decode(PanelDatabaseV1.self, from: data)
                return (v1.migrated(), true)

            case 0:
                let v1 = try decoder.decode(PanelDatabaseV1.self, from: data)
                return (v1.migrated(), true)

            case let version where version > PanelDatabase.currentSchemaVersion:
                throw PanelDatabaseError.unsupportedFutureSchema(version)

            default:
                throw PanelDatabaseError.unreadable
            }
        }
        if let panels = try? decoder.decode([PanelRecordV1].self, from: data) {
            return (
                PanelDatabaseMigrator.makeCurrent(
                    panels: panels.map { $0.migrated() }
                ),
                true
            )
        }
        throw PanelDatabaseError.unreadable
    }

    static func encode(_ database: PanelDatabase, encoder: JSONEncoder = makeEncoder()) throws -> Data {
        try encoder.encode(database)
    }

    static func deduplicate(_ panels: [PanelRecord]) -> (panels: [PanelRecord], duplicateCount: Int) {
        var best: [UUID: PanelRecord] = [:]
        var duplicateCount = 0
        for panel in panels {
            if let existing = best[panel.id] {
                duplicateCount += 1
                if panel.updatedAt >= existing.updatedAt {
                    best[panel.id] = panel
                }
            } else {
                best[panel.id] = panel
            }
        }
        let ordered = best.values.sorted { $0.createdAt < $1.createdAt }
        return (ordered, duplicateCount)
    }
}

enum PanelDatabaseNormalizer {
    /// In-memory repairs only. Callers must not treat this as a schema migration rewrite.
    static func normalize(_ database: PanelDatabase, now: Date = Date()) -> PanelDatabase {
        var workspaces = database.workspaces
        if !workspaces.contains(where: { $0.id == WorkspaceRecord.defaultID }) {
            NSLog("Glance persistence: inserting missing default workspace in memory")
            workspaces.insert(WorkspaceRecord.makeDefault(at: now), at: 0)
        }

        let knownIDs = Set(workspaces.map(\.id))
        for panel in database.panels {
            if !knownIDs.contains(panel.workspaceID) {
                NSLog(
                    "Glance persistence: panel %@ referenced missing workspace %@; falling back to default",
                    panel.id.uuidString,
                    panel.workspaceID
                )
                panel.workspaceID = WorkspaceRecord.defaultID
            }
        }

        return PanelDatabase(
            schemaVersion: PanelDatabase.currentSchemaVersion,
            workspaces: WorkspaceCatalog.sorted(workspaces),
            panels: database.panels
        )
    }
}

enum PanelDatabaseMigrator {
    static func makeCurrent(panels: [PanelRecord], now: Date = Date()) -> PanelDatabase {
        PanelDatabase(
            schemaVersion: PanelDatabase.currentSchemaVersion,
            workspaces: [WorkspaceRecord.makeDefault(at: now)],
            panels: panels
        )
    }
}

extension PanelRecord: Equatable {
    static func == (lhs: PanelRecord, rhs: PanelRecord) -> Bool {
        lhs.id == rhs.id
            && lhs.kindIdentifier == rhs.kindIdentifier
            && lhs.frame == rhs.frame
            && lhs.displayIdentifier == rhs.displayIdentifier
            && lhs.isPinned == rhs.isPinned
            && lhs.isLocked == rhs.isLocked
            && lhs.isCollapsed == rhs.isCollapsed
            && lhs.isPassThrough == rhs.isPassThrough
            && lhs.isHidden == rhs.isHidden
            && lhs.workspaceID == rhs.workspaceID
            && lhs.customTitle == rhs.customTitle
            && lhs.tags == rhs.tags
            && lhs.opacity == rhs.opacity
            && lhs.themeIdentifier == rhs.themeIdentifier
            && lhs.payloadPath == rhs.payloadPath
            && lhs.payloadVersion == rhs.payloadVersion
            && lhs.createdAt == rhs.createdAt
            && lhs.updatedAt == rhs.updatedAt
    }
}
