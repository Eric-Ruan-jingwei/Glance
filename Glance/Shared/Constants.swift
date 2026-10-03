import AppKit

enum PanelKind {
    static let text = "com.glance.panel.text"
    static let markdown = "com.glance.panel.markdown"
    static let todo = "com.glance.panel.todo"
    static let image = "com.glance.panel.image"
    static let pdf = "com.glance.panel.pdf"
}

enum GlanceConstants {
    static let appName = "Glance"
    static let bundleIdentifier = "com.glance.app"
    static let slogan = "Pin what matters. Keep it in sight."
    static var hideShowShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.hideShow)
    }
    static var hideShowKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.hideShow)
    }
    static var quickCaptureShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.quickCapture)
    }
    static var quickCaptureKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.quickCapture)
    }
    static var clipboardHistoryShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.clipboardHistory)
    }
    static var clipboardHistoryKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.clipboardHistory)
    }
    static var fileShelfShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.fileShelf)
    }
    static var fileShelfKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.fileShelf)
    }
    static var snippetsShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.snippets)
    }
    static var snippetsKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.snippets)
    }
    static var linksShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.links)
    }
    static var linksKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.links)
    }
    static var globalSearchShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.globalSearch)
    }
    static var globalSearchKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.globalSearch)
    }
    static var clipboardCaptureShortcutDisplay: String {
        ShortcutDisplayFormatter.display(ShortcutDefaults.clipboardCapture)
    }
    static var clipboardCaptureKeyEquivalent: String {
        ShortcutDisplayFormatter.keyEquivalent(ShortcutDefaults.clipboardCapture)
    }

    static var versionDisplay: String {
        let short = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if short.isEmpty {
            return appName
        }
        return "\(appName) \(short)"
    }

    static let textDefaultSize = NSSize(width: 320, height: 220)
    static let textMinSize = NSSize(width: 180, height: 100)
    static let markdownDefaultSize = NSSize(width: 420, height: 320)
    static let markdownMinSize = NSSize(width: 220, height: 140)
    static let todoDefaultSize = NSSize(width: 320, height: 300)
    static let todoMinSize = NSSize(width: 220, height: 140)
    static let imageMinSize = NSSize(width: 100, height: 100)
    static let imageMaxEdge: CGFloat = 400
    static let pdfDefaultSize = NSSize(width: 480, height: 620)
    static let pdfMinSize = NSSize(width: 260, height: 260)

    static let cornerRadius: CGFloat = GlanceTheme.Radius.panel
    static let spawnMargin = CGFloat(GlanceLayout.spawnMargin)
    static let cascadeOffset = CGFloat(GlanceLayout.cascadeOffset)
    static let resizeEdge: CGFloat = 7
    static let panelDragStrip: CGFloat = GlanceTheme.Size.panelChromeHeight
    static let quickCaptureSize = NSSize(width: 520, height: 248)
    static let clipboardHistorySize = NSSize(width: 520, height: 420)
    static let fileShelfSize = NSSize(width: 560, height: 440)
    static let snippetLibrarySize = NSSize(width: 560, height: 460)
    static let linkLibrarySize = NSSize(width: 560, height: 460)
    static let globalSearchSize = NSSize(width: 640, height: 480)

    static let frameSaveDelay: TimeInterval = 0.25
    static let textSaveDelay: TimeInterval = 0.4

    static let payloadVersionRTF = 1
    static let payloadVersionImage = 1
    static let payloadVersionMarkdown = 1
    static let payloadVersionTodo = 1
    static let payloadVersionPDF = 1

    static let textBodyFont = GlanceTheme.Typography.body
    static let textBodyColor = NSColor.labelColor
}
