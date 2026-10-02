import AppKit

enum PanelKind {
    static let text = "com.glance.panel.text"
    static let image = "com.glance.panel.image"
}

enum GlanceConstants {
    static let appName = "Glance"
    static let version = "0.1.1"
    static let bundleIdentifier = "com.glance.app"
    static let slogan = "Pin what matters. Keep it in sight."

    static let textDefaultSize = NSSize(width: 320, height: 220)
    static let textMinSize = NSSize(width: 180, height: 100)
    static let imageMinSize = NSSize(width: 100, height: 100)
    static let imageMaxEdge: CGFloat = 400

    static let cornerRadius: CGFloat = 11
    static let spawnMargin: CGFloat = 20
    static let cascadeOffset: CGFloat = 24
    static let resizeEdge: CGFloat = 7

    static let frameSaveDelay: TimeInterval = 0.25
    static let textSaveDelay: TimeInterval = 0.4

    static let payloadVersionRTF = 1
    static let payloadVersionImage = 1

    static let textBodyFont = NSFont.systemFont(ofSize: 13)
    static let textBodyColor = NSColor.labelColor
}
