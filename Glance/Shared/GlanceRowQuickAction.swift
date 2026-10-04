import SwiftUI

enum GlanceRowQuickActionLayout {
    enum Kind: CaseIterable {
        case clipboard
        case fileShelf
        case snippet
        case link
        case panelLibrary
        case globalSearch
        case workspace

        var buttonCount: Int {
            switch self {
            case .clipboard: return GlanceRowQuickActionLayout.clipboardButtons
            case .fileShelf: return GlanceRowQuickActionLayout.fileShelfButtons
            case .snippet: return GlanceRowQuickActionLayout.snippetButtons
            case .link: return GlanceRowQuickActionLayout.linkButtons
            case .panelLibrary: return GlanceRowQuickActionLayout.panelLibraryButtons
            case .globalSearch: return GlanceRowQuickActionLayout.globalSearchButtons
            case .workspace: return GlanceRowQuickActionLayout.workspaceButtons
            }
        }

        var width: CGFloat {
            GlanceRowQuickActionLayout.width(for: buttonCount)
        }
    }

    static let buttonSide: CGFloat = 26
    static let clipboardButtons = 3
    static let fileShelfButtons = 4
    static let snippetButtons = 4
    static let linkButtons = 4
    static let panelLibraryButtons = 3
    static let globalSearchButtons = 1
    static let workspaceButtons = 1

    static func width(for buttons: Int) -> CGFloat {
        CGFloat(buttons) * buttonSide
    }

    static func slotWidth(
        for kind: Kind,
        isHovered: Bool = false,
        isSelected: Bool = false,
        isActive: Bool = false
    ) -> CGFloat {
        _ = (isHovered, isSelected, isActive)
        return kind.width
    }
}

enum GlanceRowQuickActionVisibility {
    static let buttonSide = GlanceRowQuickActionLayout.buttonSide

    static func showsSecondary(isHovered: Bool, isSelected: Bool) -> Bool {
        isHovered || isSelected
    }

    static func showsPersistentMark(isActive: Bool, isHovered: Bool, isSelected: Bool) -> Bool {
        isActive || isHovered || isSelected
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
                    width: GlanceRowQuickActionLayout.buttonSide,
                    height: GlanceRowQuickActionLayout.buttonSide
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

struct GlanceRowTrailingAccessory<Normal: View, Actions: View>: View {
    var width: CGFloat
    var showsActions: Bool
    @ViewBuilder var normal: () -> Normal
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ZStack(alignment: .trailing) {
            normal()
                .opacity(showsActions ? 0 : 1)
                .accessibilityHidden(showsActions)
                .allowsHitTesting(!showsActions)
            actions()
                .opacity(showsActions ? 1 : 0)
                .accessibilityHidden(!showsActions)
                .allowsHitTesting(showsActions)
        }
        .frame(width: width, alignment: .trailing)
        .layoutPriority(1)
    }
}

struct GlanceRowMoreButton<Content: View>: View {
    var visible: Bool
    var help: String = GlanceRowActionCopy.more
    @ViewBuilder var menu: () -> Content

    var body: some View {
        Menu(content: menu) {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(
                    width: GlanceRowQuickActionLayout.buttonSide,
                    height: GlanceRowQuickActionLayout.buttonSide
                )
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
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
    static let actionCount = GlanceRowQuickActionLayout.clipboardButtons

    static func toggleFavorite(_ id: UUID, using onToggleFavorite: (UUID) -> Void) {
        onToggleFavorite(id)
    }

    static func delete(_ id: UUID, using onDelete: (UUID) -> Void) {
        onDelete(id)
    }
}

enum FileShelfRowQuickAction {
    static let actionCount = GlanceRowQuickActionLayout.fileShelfButtons

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
    static let actionCount = GlanceRowQuickActionLayout.snippetButtons

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
    static let actionCount = GlanceRowQuickActionLayout.linkButtons

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

enum WorkspaceRowQuickAction {
    static let actionCount = GlanceRowQuickActionLayout.workspaceButtons
    static let renameLabel = "重命名…"
    static let deleteLabel = "删除工作区"
    static let more = "更多工作区操作"

    static func allowsManagement(_ workspaceID: String) -> Bool {
        workspaceID != WorkspaceRecord.defaultID
    }

    static func showsEllipsis(
        workspaceID: String,
        isHovered: Bool,
        isSelected: Bool
    ) -> Bool {
        allowsManagement(workspaceID)
            && GlanceRowQuickActionVisibility.showsSecondary(
                isHovered: isHovered,
                isSelected: isSelected
            )
    }

    static func moreHelp(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return more }
        return "\(trimmed)的更多操作"
    }
}

enum WorkspaceRowMenuAction: String, Equatable, CaseIterable {
    case rename
    case delete
}

enum WorkspaceRowMenu {
    static func actions(for workspaceID: String) -> [WorkspaceRowMenuAction] {
        guard WorkspaceRowQuickAction.allowsManagement(workspaceID) else { return [] }
        return [.rename, .delete]
    }

    static func perform(
        _ action: WorkspaceRowMenuAction,
        id: String,
        rename: (String) -> Void,
        delete: (String) -> Void
    ) {
        switch action {
        case .rename:
            rename(id)
        case .delete:
            delete(id)
        }
    }
}

enum PanelLibraryRowQuickAction {
    static let actionCount = GlanceRowQuickActionLayout.panelLibraryButtons

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
