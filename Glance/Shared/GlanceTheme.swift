import AppKit
import SwiftUI

enum GlanceTheme {
    enum Radius {
        static let chip: CGFloat = 8
        static let control: CGFloat = 6
        static let card: CGFloat = 12
        static let panel: CGFloat = 16
        static let grip: CGFloat = 1.5
    }

    enum Space {
        static let xxs: CGFloat = 3
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Size {
        static let hairline: CGFloat = 1
        static let panelChromeHeight: CGFloat = 28
        static let chromeButton: CGFloat = 18
        static let controlHeight: CGFloat = 28
        static let chipHorizontalPadding: CGFloat = 7
        static let chipVerticalPadding: CGFloat = 2
        static let sidebarIdeal: CGFloat = 176
        static let menuSymbol: CGFloat = 13
        static let chromeSymbol: CGFloat = 11
    }

    enum Typography {
        static let chromeTitle = NSFont.systemFont(ofSize: 11, weight: .medium)
        static let body = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let bodyEmphasized = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let secondary = NSFont.systemFont(ofSize: 12, weight: .regular)
        static let tertiary = NSFont.systemFont(ofSize: 11, weight: .regular)
        static let chip = NSFont.systemFont(ofSize: 11, weight: .medium)
    }

    enum Fill {
        static var panelBorder: NSColor { .separatorColor }
        static var panelBorderHover: NSColor { NSColor.labelColor.withAlphaComponent(0.14) }
        static var chromeForeground: NSColor { .secondaryLabelColor }
        static var chromeForegroundQuiet: NSColor { .tertiaryLabelColor }
        static var grip: NSColor { NSColor.labelColor.withAlphaComponent(0.2) }
        static var panelMaterial: NSVisualEffectView.Material { .contentBackground }
        static var floatingMaterial: NSVisualEffectView.Material { .headerView }
    }

    static func menuSymbol(_ name: String) -> NSImage? {
        symbol(name, pointSize: Size.menuSymbol)
    }

    static func chromeSymbol(_ name: String, accessibilityDescription: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
        image?.isTemplate = true
        return image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: Size.chromeSymbol, weight: .medium)
        )
    }

    static func symbol(_ name: String, pointSize: CGFloat) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        )
    }
}

enum PanelKindSymbol {
    static func name(for kindIdentifier: String, unreadable: Bool = false) -> String {
        if unreadable { return "exclamationmark.triangle" }
        switch kindIdentifier {
        case PanelKind.text: return "doc.text"
        case PanelKind.markdown: return "text.alignleft"
        case PanelKind.todo: return "checklist"
        case PanelKind.image: return "photo"
        case PanelKind.pdf: return "doc.richtext"
        default: return "square.dashed"
        }
    }
}

extension Color {
    static var glanceChipFill: Color { Color.primary.opacity(0.06) }
    static var glanceChipForeground: Color { Color.secondary }
    static var glanceHoverFill: Color { Color.primary.opacity(0.05) }
    static var glanceSelectedFill: Color { Color.accentColor.opacity(0.14) }
}

struct GlanceChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, GlanceTheme.Size.chipHorizontalPadding)
            .padding(.vertical, GlanceTheme.Size.chipVerticalPadding)
            .foregroundStyle(Color.glanceChipForeground)
            .background(Color.glanceChipFill)
            .clipShape(RoundedRectangle(cornerRadius: GlanceTheme.Radius.chip, style: .continuous))
    }
}

extension View {
    func glanceChipStyle() -> some View {
        modifier(GlanceChipStyle())
    }
}
