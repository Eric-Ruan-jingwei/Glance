import AppKit
import Foundation

final class PanelRecord: Codable, Identifiable {
    var id: UUID
    var kindIdentifier: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
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

    init(
        id: UUID = UUID(),
        kindIdentifier: String,
        frame: NSRect,
        displayIdentifier: String,
        payloadPath: String,
        payloadVersion: Int,
        isPinned: Bool = true,
        isLocked: Bool = false,
        isCollapsed: Bool = false,
        isPassThrough: Bool = false,
        opacity: Double = 1,
        themeIdentifier: String = "system",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kindIdentifier = kindIdentifier
        self.x = frame.origin.x
        self.y = frame.origin.y
        self.width = frame.size.width
        self.height = frame.size.height
        self.displayIdentifier = displayIdentifier
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isCollapsed = isCollapsed
        self.isPassThrough = isPassThrough
        self.opacity = PanelOpacity.clamp(opacity)
        self.themeIdentifier = themeIdentifier
        self.payloadPath = payloadPath
        self.payloadVersion = payloadVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var frame: NSRect {
        get { NSRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.origin.x
            y = newValue.origin.y
            width = newValue.size.width
            height = newValue.size.height
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, kindIdentifier, x, y, width, height, displayIdentifier
        case isPinned, isLocked, isCollapsed, isPassThrough
        case opacity, themeIdentifier, payloadPath, payloadVersion
        case createdAt, updatedAt
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kindIdentifier = try container.decode(String.self, forKey: .kindIdentifier)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kindIdentifier, forKey: .kindIdentifier)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(displayIdentifier, forKey: .displayIdentifier)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(isPassThrough, forKey: .isPassThrough)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(themeIdentifier, forKey: .themeIdentifier)
        try container.encode(payloadPath, forKey: .payloadPath)
        try container.encode(payloadVersion, forKey: .payloadVersion)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
