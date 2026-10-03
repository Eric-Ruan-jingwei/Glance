import AppKit

enum StatusMenuBuilder {
    static func populate(
        _ menu: NSMenu,
        allHidden: Bool,
        clipboardCaptureEnabled: Bool = true,
        workspaces: [WorkspaceMenuItem] = [],
        onQuickCapture: @escaping () -> Void,
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
        onQuit: @escaping () -> Void,
        shortcuts: [ShortcutAction: GlanceShortcut] = ShortcutDefaults.all,
        diagnostic: PersistenceDiagnostic? = nil,
        onShowDiagnostic: @escaping () -> Void = {}
    ) {
        menu.removeAllItems()

        let quickCapture = shortcuts[.quickCapture] ?? ShortcutDefaults.quickCapture
        let clipboardCapture = shortcuts[.clipboardCapture] ?? ShortcutDefaults.clipboardCapture
        let hideShow = shortcuts[.hideShow] ?? ShortcutDefaults.hideShow

        menu.addItem(
            actionItem(
                "快速记录…",
                onQuickCapture,
                keyEquivalent: ShortcutDisplayFormatter.keyEquivalent(quickCapture),
                modifiers: MacShortcutAdapter.menuModifierMask(for: quickCapture)
            )
        )
        menu.addItem(
            actionItem(
                "从剪贴板创建…",
                onCaptureClipboard,
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
        menu.addItem(actionItem("管理面板…", onManagePanels))
        menu.addItem(.separator())
        menu.addItem(actionItem("新建文字面板", onNewText))
        menu.addItem(actionItem("新建 Markdown 面板", onNewMarkdown))
        menu.addItem(actionItem("新建待办面板", onNewTodo))
        menu.addItem(actionItem("新建图片面板", onNewImage))
        menu.addItem(actionItem("新建 PDF 面板…", onNewPDF))
        menu.addItem(.separator())
        menu.addItem(
            actionItem(
                allHidden ? "显示全部" : "隐藏全部",
                onToggleVisibility,
                keyEquivalent: ShortcutDisplayFormatter.keyEquivalent(hideShow),
                modifiers: MacShortcutAdapter.menuModifierMask(for: hideShow)
            )
        )
        if let diagnostic {
            menu.addItem(.separator())
            menu.addItem(actionItem(diagnostic.menuTitle, onShowDiagnostic))
        }
        menu.addItem(.separator())
        menu.addItem(actionItem("设置…", onSettings))
        menu.addItem(actionItem("退出", onQuit))
    }

    static func workspaceMenu(
        items: [WorkspaceMenuItem],
        onSelect: @escaping (String) -> Void,
        onCreate: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: "工作区", action: nil, keyEquivalent: "")
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
        submenu.addItem(actionItem("新建工作区…", onCreate))
        item.submenu = submenu
        return item
    }

    private static func actionItem(
        _ title: String,
        _ handler: @escaping () -> Void,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        enabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = modifiers
        }
        item.isEnabled = enabled
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
