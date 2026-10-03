import AppKit

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

enum GlanceMenuQuery {
    static func item(titled title: String, in menu: NSMenu) -> NSMenuItem? {
        if let match = menu.items.first(where: { $0.title == title }) {
            return match
        }
        for item in menu.items {
            if let submenu = item.submenu, let match = Self.item(titled: title, in: submenu) {
                return match
            }
        }
        return nil
    }

    static func panelMenu(in menu: NSMenu) -> NSMenu? {
        menu.items.first { $0.title == "面板" }?.submenu
    }

    static func newPanelMenu(in menu: NSMenu) -> NSMenu? {
        panelMenu(in: menu)?.items.first { $0.title == "新建面板" }?.submenu
    }

    static func workspaceMenu(in menu: NSMenu) -> NSMenu? {
        panelMenu(in: menu)?.items.first { $0.title == "工作区" }?.submenu
    }

    static func rootTitles(in menu: NSMenu) -> [String] {
        menu.items.map(\.title).filter { !$0.isEmpty }
    }
}

enum GlanceMenuFixtures {
    static func populate(
        _ menu: NSMenu,
        allHidden: Bool = false,
        clipboardCaptureEnabled: Bool = true,
        workspaces: [WorkspaceMenuItem] = [],
        shortcuts: [ShortcutAction: GlanceShortcut] = ShortcutDefaults.all,
        diagnostic: PersistenceDiagnostic? = nil,
        onQuickCapture: @escaping () -> Void = {},
        onShowClipboardHistory: @escaping () -> Void = {},
        onShowFileShelf: @escaping () -> Void = {},
        onCaptureClipboard: @escaping () -> Void = {},
        onSelectWorkspace: @escaping (String) -> Void = { _ in },
        onCreateWorkspace: @escaping () -> Void = {},
        onManagePanels: @escaping () -> Void = {},
        onToggleVisibility: @escaping () -> Void = {},
        onSettings: @escaping () -> Void = {},
        onOpenGuide: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        StatusMenuBuilder.populate(
            menu,
            allHidden: allHidden,
            clipboardCaptureEnabled: clipboardCaptureEnabled,
            workspaces: workspaces,
            onQuickCapture: onQuickCapture,
            onShowClipboardHistory: onShowClipboardHistory,
            onShowFileShelf: onShowFileShelf,
            onCaptureClipboard: onCaptureClipboard,
            onSelectWorkspace: onSelectWorkspace,
            onCreateWorkspace: onCreateWorkspace,
            onManagePanels: onManagePanels,
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onNewPDF: {},
            onToggleVisibility: onToggleVisibility,
            onSettings: onSettings,
            onOpenGuide: onOpenGuide,
            onQuit: onQuit,
            shortcuts: shortcuts,
            diagnostic: diagnostic
        )
    }
}
