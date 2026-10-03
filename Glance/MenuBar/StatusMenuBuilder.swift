import AppKit

enum StatusMenuBuilder {
    static func populate(
        _ menu: NSMenu,
        allHidden: Bool,
        clipboardCaptureEnabled: Bool = true,
        workspaces: [WorkspaceMenuItem] = [],
        onQuickCapture: @escaping () -> Void,
        onShowClipboardHistory: @escaping () -> Void = {},
        onCaptureClipboard: @escaping () -> Void = {},
        onSelectWorkspace: @escaping (String) -> Void = { _ in },
        onCreateWorkspace: @escaping () -> Void = {},
        onManagePanels: @escaping () -> Void,
        onNewText: @escaping () -> Void,
        onNewMarkdown: @escaping () -> Void,
        onNewTodo: @escaping () -> Void,
        onNewImage: @escaping () -> Void,
        onNewPDF: @escaping () -> Void = {},
        onToggleVisibility: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onOpenGuide: @escaping () -> Void = {},
        onQuit: @escaping () -> Void,
        shortcuts: [ShortcutAction: GlanceShortcut] = ShortcutDefaults.all,
        diagnostic: PersistenceDiagnostic? = nil,
        onShowDiagnostic: @escaping () -> Void = {}
    ) {
        menu.removeAllItems()

        let quickCapture = shortcuts[.quickCapture] ?? ShortcutDefaults.quickCapture
        let clipboardHistory = shortcuts[.clipboardHistory] ?? ShortcutDefaults.clipboardHistory
        let clipboardCapture = shortcuts[.clipboardCapture] ?? ShortcutDefaults.clipboardCapture
        let hideShow = shortcuts[.hideShow] ?? ShortcutDefaults.hideShow

        menu.addItem(
            actionItem(
                "快速记录…",
                onQuickCapture,
                symbol: "square.and.pencil",
                keyEquivalent: ShortcutDisplayFormatter.keyEquivalent(quickCapture),
                modifiers: MacShortcutAdapter.menuModifierMask(for: quickCapture)
            )
        )
        menu.addItem(
            actionItem(
                "剪贴板…",
                onShowClipboardHistory,
                symbol: "list.clipboard",
                keyEquivalent: ShortcutDisplayFormatter.keyEquivalent(clipboardHistory),
                modifiers: MacShortcutAdapter.menuModifierMask(for: clipboardHistory)
            )
        )
        menu.addItem(
            actionItem(
                "从当前剪贴板创建…",
                onCaptureClipboard,
                symbol: "doc.on.clipboard",
                keyEquivalent: ShortcutDisplayFormatter.keyEquivalent(clipboardCapture),
                modifiers: MacShortcutAdapter.menuModifierMask(for: clipboardCapture),
                enabled: clipboardCaptureEnabled
            )
        )
        menu.addItem(.separator())
        menu.addItem(workspaceMenu(
            items: workspaces,
            onSelect: onSelectWorkspace,
            onCreate: onCreateWorkspace
        ))
        menu.addItem(.separator())
        menu.addItem(actionItem("管理面板…", onManagePanels, symbol: "square.stack"))
        menu.addItem(newPanelMenu(
            onNewText: onNewText,
            onNewMarkdown: onNewMarkdown,
            onNewTodo: onNewTodo,
            onNewImage: onNewImage,
            onNewPDF: onNewPDF
        ))
        menu.addItem(NSMenuItem.sectionHeader(title: "状态"))
        menu.addItem(
            actionItem(
                allHidden ? "显示全部" : "隐藏全部",
                onToggleVisibility,
                symbol: allHidden ? "eye" : "eye.slash",
                keyEquivalent: ShortcutDisplayFormatter.keyEquivalent(hideShow),
                modifiers: MacShortcutAdapter.menuModifierMask(for: hideShow)
            )
        )
        if let diagnostic {
            menu.addItem(.separator())
            menu.addItem(actionItem(diagnostic.menuTitle, onShowDiagnostic, symbol: "exclamationmark.triangle"))
        }
        menu.addItem(.separator())
        menu.addItem(actionItem(GlanceGuideEntry.menuTitle, onOpenGuide, symbol: "questionmark.circle"))
        menu.addItem(actionItem("设置…", onSettings, symbol: "gearshape"))
        menu.addItem(actionItem("退出", onQuit, symbol: "power"))
    }

    static func workspaceMenu(
        items: [WorkspaceMenuItem],
        onSelect: @escaping (String) -> Void,
        onCreate: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: "工作区", action: nil, keyEquivalent: "")
        item.image = GlanceTheme.menuSymbol("square.on.square")
        let submenu = NSMenu()
        for workspace in items {
            let entry = NSMenuItem(title: workspace.name, action: nil, keyEquivalent: "")
            entry.state = workspace.isActive ? .on : .off
            entry.representedObject = ClosureBox { onSelect(workspace.id) }
            entry.target = MenuActionRelay.shared
            entry.action = #selector(MenuActionRelay.invoke(_:))
            submenu.addItem(entry)
        }
        if !items.isEmpty {
            submenu.addItem(.separator())
        }
        submenu.addItem(actionItem("新建工作区…", onCreate, symbol: "plus"))
        item.submenu = submenu
        return item
    }

    static func newPanelMenu(
        onNewText: @escaping () -> Void,
        onNewMarkdown: @escaping () -> Void,
        onNewTodo: @escaping () -> Void,
        onNewImage: @escaping () -> Void,
        onNewPDF: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: "新建面板", action: nil, keyEquivalent: "")
        item.image = GlanceTheme.menuSymbol("plus")
        let submenu = NSMenu()
        submenu.addItem(actionItem("文字", onNewText, symbol: PanelKindSymbol.name(for: PanelKind.text)))
        submenu.addItem(actionItem("Markdown", onNewMarkdown, symbol: PanelKindSymbol.name(for: PanelKind.markdown)))
        submenu.addItem(actionItem("待办", onNewTodo, symbol: PanelKindSymbol.name(for: PanelKind.todo)))
        submenu.addItem(actionItem("图片", onNewImage, symbol: PanelKindSymbol.name(for: PanelKind.image)))
        submenu.addItem(actionItem("PDF…", onNewPDF, symbol: PanelKindSymbol.name(for: PanelKind.pdf)))
        item.submenu = submenu
        return item
    }

    private static func actionItem(
        _ title: String,
        _ handler: @escaping () -> Void,
        symbol: String? = nil,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        enabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = modifiers
        }
        item.isEnabled = enabled
        if let symbol {
            item.image = GlanceTheme.menuSymbol(symbol)
        }
        item.representedObject = ClosureBox(handler)
        item.target = MenuActionRelay.shared
        item.action = #selector(MenuActionRelay.invoke(_:))
        return item
    }
}

private final class ClosureBox {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }
}

private final class MenuActionRelay: NSObject {
    static let shared = MenuActionRelay()

    @objc func invoke(_ sender: NSMenuItem) {
        (sender.representedObject as? ClosureBox)?.handler()
    }
}
