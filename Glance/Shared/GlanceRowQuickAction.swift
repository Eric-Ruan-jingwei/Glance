import SwiftUI

enum GlanceRowQuickActionVisibility {
    static let buttonSide: CGFloat = 26

    static func showsSecondary(isHovered: Bool, isSelected: Bool) -> Bool {
        isHovered || isSelected
    }

    static func showsPersistentMark(isActive: Bool, isHovered: Bool, isSelected: Bool) -> Bool {
        isActive || isHovered || isSelected
    }

    static func dateTrailingPadding(isActive: Bool, showsSecondary: Bool) -> CGFloat {
        (isActive && !showsSecondary) ? buttonSide : 0
    }
}

enum GlanceRowActionCopy {
    static let more = "更多操作"
    static let copy = "复制"
    static let open = "打开"
    static let delete = "删除"
    static let hidePanel = "隐藏面板"
    static let showPanel = "显示面板"
    static let createPanel = "新建面板…"
    static let leadingSnippet = "片段"
}

struct GlanceRowIconButton: View {
    var systemName: String
    var help: String
    var isActive: Bool = false
    var visible: Bool = true
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(
                    width: GlanceRowQuickActionVisibility.buttonSide,
                    height: GlanceRowQuickActionVisibility.buttonSide
                )
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: GlanceTheme.Radius.control, style: .continuous)
                        .fill(isHovered ? Color.glanceHoverFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .onHover { isHovered = $0 }
    }
}

struct GlanceRowQuickActionOverlay<Persistent: View, Secondary: View>: View {
    var showsPersistent: Bool
    var showsSecondary: Bool
    @ViewBuilder var persistent: () -> Persistent
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        ZStack(alignment: .trailing) {
            if showsPersistent && !showsSecondary {
                persistent()
            }
            if showsSecondary {
                secondary()
            }
        }
    }
}

struct GlanceRowMoreButton<Content: View>: View {
    var visible: Bool
    @ViewBuilder var menu: () -> Content

    var body: some View {
        Menu(content: menu) {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(
                    width: GlanceRowQuickActionVisibility.buttonSide,
                    height: GlanceRowQuickActionVisibility.buttonSide
                )
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
        .help(GlanceRowActionCopy.more)
        .accessibilityLabel(GlanceRowActionCopy.more)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
    }
}

enum FileShelfQuickAction {
    enum Primary: Equatable {
        case open
        case relink
    }

    static let removeSymbol = "minus.circle"
    static let openSymbol = "arrow.up.forward.app"
    static let relinkSymbol = "link.badge.plus"
    static let removeDeletesFinderFile = false

    static func primary(missing: Bool) -> Primary {
        missing ? .relink : .open
    }

    static func primarySymbol(missing: Bool) -> String {
        missing ? relinkSymbol : openSymbol
    }

    static func primaryHelp(missing: Bool) -> String {
        missing ? FileShelfCopy.relinkLabel : FileShelfCopy.openLabel
    }
}

enum PanelCreationKind: String, CaseIterable, Equatable, Hashable {
    case text
    case markdown
    case todo
    case image
    case pdf

    var title: String {
        switch self {
        case .text: return "文字"
        case .markdown: return "Markdown"
        case .todo: return "待办"
        case .image: return "图片"
        case .pdf: return "PDF…"
        }
    }

    var kindIdentifier: String {
        switch self {
        case .text: return PanelKind.text
        case .markdown: return PanelKind.markdown
        case .todo: return PanelKind.todo
        case .image: return PanelKind.image
        case .pdf: return PanelKind.pdf
        }
    }

    var symbolName: String {
        PanelKindSymbol.name(for: kindIdentifier)
    }
}

struct PanelLibraryCreateHooks {
    var createText: () -> Void
    var createMarkdown: () -> Void
    var createTodo: () -> Void
    var createImage: () -> Void
    var createPDF: () -> Void
}

enum PanelLibraryCreateRouting {
    static func perform(_ kind: PanelCreationKind, into hooks: PanelLibraryCreateHooks) {
        switch kind {
        case .text: hooks.createText()
        case .markdown: hooks.createMarkdown()
        case .todo: hooks.createTodo()
        case .image: hooks.createImage()
        case .pdf: hooks.createPDF()
        }
    }
}

enum PanelLibraryCreatePresentation {
    static func showsCreateCTA(for emptyKind: PanelLibraryEmptyKind) -> Bool {
        emptyKind == .emptyWorkspace
    }
}

enum PanelLibraryQuickAction {
    static let deleteUsesConfirmation = true
    static let deleteSymbol = "trash"

    static func visibilitySymbol(isHidden: Bool) -> String {
        isHidden ? "eye" : "eye.slash"
    }

    static func visibilityHelp(isHidden: Bool) -> String {
        isHidden ? GlanceRowActionCopy.showPanel : GlanceRowActionCopy.hidePanel
    }
}

enum PanelChromeCloseRouting {
    static func close(id: UUID, hide: (UUID) -> Void, delete _: (UUID) -> Void) {
        hide(id)
    }

    static func kindSymbolName(for kindIdentifier: String) -> String {
        PanelKindSymbol.name(for: kindIdentifier)
    }
}

enum ClipboardRowQuickAction {
    static func toggleFavorite(_ id: UUID, using onToggleFavorite: (UUID) -> Void) {
        onToggleFavorite(id)
    }

    static func delete(_ id: UUID, using onDelete: (UUID) -> Void) {
        onDelete(id)
    }
}

enum FileShelfRowQuickAction {
    static func performPrimary(
        missing: Bool,
        id: UUID,
        onOpen: (UUID) -> Void,
        onRelink: (UUID) -> Void
    ) {
        switch FileShelfQuickAction.primary(missing: missing) {
        case .open:
            onOpen(id)
        case .relink:
            onRelink(id)
        }
    }

    static func remove(_ id: UUID, using onRemove: (UUID) -> Void) {
        onRemove(id)
    }
}

enum SnippetRowQuickAction {
    static let doubleClickPerformsEdit = true
    static let leadingSymbol = "text.quote"

    static func copy(_ id: UUID, using onCopy: (UUID) -> Void) {
        onCopy(id)
    }

    static func togglePin(_ id: UUID, using onTogglePin: (UUID) -> Void) {
        onTogglePin(id)
    }

    static func delete(_ id: UUID, using onDelete: (UUID) -> Void) {
        onDelete(id)
    }
}

enum LinkRowQuickAction {
    static let doubleClickPerformsOpen = true

    static func open(_ id: UUID, using onOpen: (UUID) -> Void) {
        onOpen(id)
    }

    static func togglePin(_ id: UUID, using onTogglePin: (UUID) -> Void) {
        onTogglePin(id)
    }

    static func delete(_ id: UUID, using onDelete: (UUID) -> Void) {
        onDelete(id)
    }
}

enum PanelLibraryRowQuickAction {
    static func toggleVisibility(
        isHidden: Bool,
        id: UUID,
        hide: (UUID) -> Void,
        reveal: (UUID) -> Void
    ) {
        if isHidden {
            reveal(id)
        } else {
            hide(id)
        }
    }

    static func requestDelete(
        _ id: UUID,
        confirmDelete: (UUID) -> Void,
        delete _: (UUID) -> Void
    ) {
        confirmDelete(id)
    }
}
