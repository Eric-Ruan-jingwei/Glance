import Foundation

struct PanelDatabase: Codable, Equatable {
    var schemaVersion: Int
    var panels: [PanelRecord]

    static let currentSchemaVersion = 1
}

enum PanelDatabaseLoadError: Error {
    case unreadable
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

    /// Accepts schema 1 envelopes and V0.1 raw arrays (schema 0).
    static func decode(from data: Data, decoder: JSONDecoder = makeDecoder()) throws -> (database: PanelDatabase, migratedFromLegacy: Bool) {
        if let envelope = try? decoder.decode(PanelDatabase.self, from: data) {
            return (
                PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: envelope.panels),
                false
            )
        }
        if let panels = try? decoder.decode([PanelRecord].self, from: data) {
            return (
                PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: panels),
                true
            )
        }
        throw PanelDatabaseLoadError.unreadable
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

extension PanelRecord: Equatable {
    static func == (lhs: PanelRecord, rhs: PanelRecord) -> Bool {
        lhs.id == rhs.id
            && lhs.kindIdentifier == rhs.kindIdentifier
            && lhs.x == rhs.x
            && lhs.y == rhs.y
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.displayIdentifier == rhs.displayIdentifier
            && lhs.isPinned == rhs.isPinned
            && lhs.isLocked == rhs.isLocked
            && lhs.isCollapsed == rhs.isCollapsed
            && lhs.isPassThrough == rhs.isPassThrough
            && lhs.opacity == rhs.opacity
            && lhs.themeIdentifier == rhs.themeIdentifier
            && lhs.payloadPath == rhs.payloadPath
            && lhs.payloadVersion == rhs.payloadVersion
            && lhs.createdAt == rhs.createdAt
            && lhs.updatedAt == rhs.updatedAt
    }
}
