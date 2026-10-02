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
        payloadVersion: Int
    ) {
        self.id = id
        self.kindIdentifier = kindIdentifier
        self.x = frame.origin.x
        self.y = frame.origin.y
        self.width = frame.size.width
        self.height = frame.size.height
        self.displayIdentifier = displayIdentifier
        self.isPinned = true
        self.isLocked = false
        self.isCollapsed = false
        self.isPassThrough = false
        self.opacity = 1
        self.themeIdentifier = "system"
        self.payloadPath = payloadPath
        self.payloadVersion = payloadVersion
        self.createdAt = Date()
        self.updatedAt = Date()
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
}
