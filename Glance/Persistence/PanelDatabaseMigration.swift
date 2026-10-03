import Foundation

/// Schema 1 envelope. Missing `isHidden` and `workspaceID`.
struct PanelDatabaseV1: Decodable {
    var schemaVersion: Int
    var panels: [PanelRecordV1]

    func migrated(now: Date = Date()) -> PanelDatabase {
        PanelDatabaseMigrator.makeCurrent(
            panels: panels.map { $0.migrated() },
            now: now
        )
    }
}

/// Schema 2 envelope. Has `isHidden`, missing `workspaces` and `workspaceID`.
struct PanelDatabaseV2: Decodable {
    var schemaVersion: Int
    var panels: [PanelRecordV2]

    func migrated(now: Date = Date()) -> PanelDatabase {
        PanelDatabaseMigrator.makeCurrent(
            panels: panels.map { $0.migrated() },
            now: now
        )
    }
}

struct PanelRecordV1: Decodable {
    var id: UUID
    var kindIdentifier: String
    var frame: PanelFrame
    var displayIdentifier: String
    var isPinned: Bool
    var isLocked: Bool
    var isCollapsed: Bool
    var isPassThrough: Bool
    var opacity: Double
    var themeIdentifier: String
    var payloadPath: String
    var payloadVersion: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kindIdentifier, x, y, width, height, displayIdentifier
        case isPinned, isLocked, isCollapsed, isPassThrough
        case opacity, themeIdentifier, payloadPath, payloadVersion
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kindIdentifier = try container.decode(String.self, forKey: .kindIdentifier)
        frame = PanelFrame(
            x: try container.decode(Double.self, forKey: .x),
            y: try container.decode(Double.self, forKey: .y),
            width: try container.decode(Double.self, forKey: .width),
            height: try container.decode(Double.self, forKey: .height)
        )
        displayIdentifier = try container.decode(String.self, forKey: .displayIdentifier)
        payloadPath = try container.decode(String.self, forKey: .payloadPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        isPassThrough = try container.decodeIfPresent(Bool.self, forKey: .isPassThrough) ?? false
        opacity = PanelOpacity.clamp(try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1)
        themeIdentifier = try container.decodeIfPresent(String.self, forKey: .themeIdentifier) ?? "system"
        payloadVersion = try container.decodeIfPresent(Int.self, forKey: .payloadVersion) ?? 1
    }

    func migrated() -> PanelRecord {
        PanelRecord(
            id: id,
            kindIdentifier: kindIdentifier,
            frame: frame,
            displayIdentifier: displayIdentifier,
            payloadPath: payloadPath,
            payloadVersion: payloadVersion,
            isPinned: isPinned,
            isLocked: isLocked,
            isCollapsed: isCollapsed,
            isPassThrough: isPassThrough,
            isHidden: false,
            workspaceID: WorkspaceRecord.defaultID,
            opacity: opacity,
            themeIdentifier: themeIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct PanelRecordV2: Decodable {
    var id: UUID
    var kindIdentifier: String
    var frame: PanelFrame
    var displayIdentifier: String
    var isPinned: Bool
    var isLocked: Bool
    var isCollapsed: Bool
    var isPassThrough: Bool
    var isHidden: Bool
    var opacity: Double
    var themeIdentifier: String
    var payloadPath: String
    var payloadVersion: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kindIdentifier, x, y, width, height, displayIdentifier
        case isPinned, isLocked, isCollapsed, isPassThrough, isHidden
        case opacity, themeIdentifier, payloadPath, payloadVersion
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kindIdentifier = try container.decode(String.self, forKey: .kindIdentifier)
        frame = PanelFrame(
            x: try container.decode(Double.self, forKey: .x),
            y: try container.decode(Double.self, forKey: .y),
            width: try container.decode(Double.self, forKey: .width),
            height: try container.decode(Double.self, forKey: .height)
        )
        displayIdentifier = try container.decode(String.self, forKey: .displayIdentifier)
        payloadPath = try container.decode(String.self, forKey: .payloadPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        isPassThrough = try container.decodeIfPresent(Bool.self, forKey: .isPassThrough) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        opacity = PanelOpacity.clamp(try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1)
        themeIdentifier = try container.decodeIfPresent(String.self, forKey: .themeIdentifier) ?? "system"
        payloadVersion = try container.decodeIfPresent(Int.self, forKey: .payloadVersion) ?? 1
    }

    func migrated() -> PanelRecord {
        PanelRecord(
            id: id,
            kindIdentifier: kindIdentifier,
            frame: frame,
            displayIdentifier: displayIdentifier,
            payloadPath: payloadPath,
            payloadVersion: payloadVersion,
            isPinned: isPinned,
            isLocked: isLocked,
            isCollapsed: isCollapsed,
            isPassThrough: isPassThrough,
            isHidden: isHidden,
            workspaceID: WorkspaceRecord.defaultID,
            opacity: opacity,
            themeIdentifier: themeIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
