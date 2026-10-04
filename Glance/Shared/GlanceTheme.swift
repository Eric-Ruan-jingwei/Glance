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
        static let formatBarHeight: CGFloat = 28
        static let todoRowHeight: CGFloat = 32
        static let chipHorizontalPadding: CGFloat = 7
        static let chipVerticalPadding: CGFloat = 2
        static let sidebarIdeal: CGFloat = 176
        static let menuSymbol: CGFloat = 13
        static let chromeSymbol: CGFloat = 11
        static let readingInset = NSSize(width: 16, height: 12)
        static let mediaInset: CGFloat = 6
    }

    enum Typography {
        static let chromeTitle = NSFont.systemFont(ofSize: 11, weight: .medium)
        static let body = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let bodyEmphasized = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let secondary = NSFont.systemFont(ofSize: 12, weight: .regular)
        static let tertiary = NSFont.systemFont(ofSize: 11, weight: .regular)
        static let chip = NSFont.systemFont(ofSize: 11, weight: .medium)
        static let markdownEdit = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        static let code = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        static let placeholder = NSFont.systemFont(ofSize: 13, weight: .regular)

        static func heading(_ level: Int) -> NSFont {
            let sizes: [CGFloat] = [22, 17, 15, 13, 13, 13]
            let size = sizes[max(0, min(level - 1, sizes.count - 1))]
            let weight: NSFont.Weight = level <= 2 ? .semibold : .medium
            return .systemFont(ofSize: size, weight: weight)
        }
    }

    enum Reading {
        static let lineHeightMultiple: CGFloat = 1.28
        static let paragraphSpacing: CGFloat = 7

        static func bodyParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = lineHeightMultiple
            style.paragraphSpacing = paragraphSpacing
            style.lineBreakMode = .byWordWrapping
            return style
        }

        static func headingParagraphStyle(level: Int) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = 1.15
            style.paragraphSpacingBefore = level == 1 ? 14 : (level == 2 ? 12 : 10)
            style.paragraphSpacing = 6
            style.lineBreakMode = .byWordWrapping
            return style
        }

        static func quoteParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = lineHeightMultiple
            style.paragraphSpacing = paragraphSpacing
            style.headIndent = 14
            style.firstLineHeadIndent = 14
            style.lineBreakMode = .byWordWrapping
            return style
        }

        static func listParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = lineHeightMultiple
            style.paragraphSpacing = 4
            style.headIndent = 18
            style.firstLineHeadIndent = 0
            style.lineBreakMode = .byWordWrapping
            return style
        }

        static func codeParagraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = 1.2
            style.paragraphSpacing = 8
            style.paragraphSpacingBefore = 4
            style.lineBreakMode = .byWordWrapping
            return style
        }
    }

    enum Fill {
        static var panelBorder: NSColor { .separatorColor }
        static var panelBorderHover: NSColor { NSColor.labelColor.withAlphaComponent(0.14) }
        static var chromeForeground: NSColor { .secondaryLabelColor }
        static var chromeForegroundQuiet: NSColor { .tertiaryLabelColor }
        static var grip: NSColor { NSColor.labelColor.withAlphaComponent(0.2) }
        static var panelMaterial: NSVisualEffectView.Material { .contentBackground }
        static var floatingMaterial: NSVisualEffectView.Material { .headerView }
        static var rowHover: NSColor { NSColor.labelColor.withAlphaComponent(0.05) }
        static var rowSelected: NSColor { NSColor.controlAccentColor.withAlphaComponent(0.14) }
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

struct GlanceEmptyState<Footer: View>: View {
    var symbol: String
    var title: String
    var detail: String
    var footer: Footer

    init(
        symbol: String,
        title: String,
        detail: String = "",
        @ViewBuilder footer: () -> Footer
    ) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: GlanceTheme.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            if !detail.isEmpty {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            footer
        }
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(GlanceTheme.Space.xl)
    }
}

extension GlanceEmptyState where Footer == EmptyView {
    init(symbol: String, title: String, detail: String = "") {
        self.init(symbol: symbol, title: title, detail: detail) {
            EmptyView()
        }
    }
}

struct GlanceEmptyCTA: View {
    var title: String
    var accessibilityText: String? = nil
    var systemImage: String? = "plus"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .controlSize(.small)
        .buttonStyle(.borderless)
        .padding(.top, GlanceTheme.Space.xs)
        .accessibilityLabel(accessibilityText ?? title)
    }
}

enum PanelLibraryEmptyKind: Equatable {
    case none
    case loading
    case emptyWorkspace
    case noSearchResults
    case noFilterMatches
}
