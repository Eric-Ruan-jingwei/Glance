import AppKit

enum StatusMenuBuilder {
    static func populate(
        _ menu: NSMenu,
        allHidden: Bool,
        clipboardCaptureEnabled: Bool = true,
        workspaces: [WorkspaceMenuItem] = [],
        onQuickCapture: @escaping () -> Void,
        onShowGlobalSearch: @escaping () -> Void = {},
        onShowClipboardHistory: @escaping () -> Void = {},
        onShowFileShelf: @escaping () -> Void = {},
        onShowSnippets: @escaping () -> Void = {},
        onShowLinks: @escaping () -> Void = {},
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
        shortcuts: [ShortcutAction: GlanceShortcut] = [:],
        diagnostic: PersistenceDiagnostic? = nil,
        onShowDiagnostic: @escaping () -> Void = {},
        homeSnapshot: GlanceHomeSnapshot = .empty,
        onRevealHomeItem: @escaping (GlobalSearchResultID) -> GlanceActionOutcome = { _ in
            .failed(GlanceNoticeCopy.staleItem)
        }
    ) {
        menu.removeAllItems()

        let quickCapture = menuKey(shortcuts[.quickCapture])
        let globalSearch = menuKey(shortcuts[.globalSearch])
        let clipboardHistory = menuKey(shortcuts[.clipboardHistory])
        let fileShelf = menuKey(shortcuts[.fileShelf])
        let snippets = menuKey(shortcuts[.snippets])
        let links = menuKey(shortcuts[.links])

        menu.addItem(
            actionItem(
                "快速记录…",
                onQuickCapture,
                symbol: "square.and.pencil",
                keyEquivalent: quickCapture.keyEquivalent,
                modifiers: quickCapture.modifiers
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            homeMenu(
                title: GlanceHomeCopy.preferred,
                symbol: "star",
                items: homeSnapshot.preferred,
                emptyTitle: GlanceHomeCopy.emptyPreferred,
                onReveal: onRevealHomeItem
            )
        )
        menu.addItem(
            homeMenu(
                title: GlanceHomeCopy.recent,
                symbol: "clock",
                items: homeSnapshot.recent,
                emptyTitle: GlanceHomeCopy.emptyRecent,
                onReveal: onRevealHomeItem
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            actionItem(
                GlanceHomeCopy.panel,
                onManagePanels,
                symbol: GlobalSearchSource.panels.symbol
            )
        )
        menu.addItem(
            actionItem(
                "剪贴板…",
                onShowClipboardHistory,
                symbol: "list.clipboard",
                keyEquivalent: clipboardHistory.keyEquivalent,
                modifiers: clipboardHistory.modifiers
            )
        )
        menu.addItem(
            actionItem(
                "文件架…",
                onShowFileShelf,
                symbol: "tray",
                keyEquivalent: fileShelf.keyEquivalent,
                modifiers: fileShelf.modifiers
            )
        )
        menu.addItem(
            actionItem(
                "片段库…",
                onShowSnippets,
                symbol: "text.quote",
                keyEquivalent: snippets.keyEquivalent,
                modifiers: snippets.modifiers
            )
        )
        menu.addItem(
            actionItem(
                "链接库…",
                onShowLinks,
                symbol: "link",
                keyEquivalent: links.keyEquivalent,
                modifiers: links.modifiers
            )
        )
        menu.addItem(
            actionItem(
                "搜索 Glance…",
                onShowGlobalSearch,
                symbol: "magnifyingglass",
                keyEquivalent: globalSearch.keyEquivalent,
                modifiers: globalSearch.modifiers
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            panelMenu(
                allHidden: allHidden,
                clipboardCaptureEnabled: clipboardCaptureEnabled,
                workspaces: workspaces,
                shortcuts: shortcuts,
                onCaptureClipboard: onCaptureClipboard,
                onSelectWorkspace: onSelectWorkspace,
                onCreateWorkspace: onCreateWorkspace,
                onNewText: onNewText,
                onNewMarkdown: onNewMarkdown,
                onNewTodo: onNewTodo,
                onNewImage: onNewImage,
                onNewPDF: onNewPDF,
                onToggleVisibility: onToggleVisibility
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

    static func panelMenu(
        allHidden: Bool,
        clipboardCaptureEnabled: Bool,
        workspaces: [WorkspaceMenuItem],
        shortcuts: [ShortcutAction: GlanceShortcut],
        onCaptureClipboard: @escaping () -> Void,
        onSelectWorkspace: @escaping (String) -> Void,
        onCreateWorkspace: @escaping () -> Void,
        onNewText: @escaping () -> Void,
        onNewMarkdown: @escaping () -> Void,
        onNewTodo: @escaping () -> Void,
        onNewImage: @escaping () -> Void,
        onNewPDF: @escaping () -> Void,
        onToggleVisibility: @escaping () -> Void
    ) -> NSMenuItem {
        let clipboardCapture = menuKey(shortcuts[.clipboardCapture])
        let hideShow = menuKey(shortcuts[.hideShow])

        let item = NSMenuItem(title: GlanceHomeCopy.panelOperations, action: nil, keyEquivalent: "")
        item.image = GlanceTheme.menuSymbol("ellipsis.circle")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.addItem(newPanelMenu(
            onNewText: onNewText,
            onNewMarkdown: onNewMarkdown,
            onNewTodo: onNewTodo,
            onNewImage: onNewImage,
            onNewPDF: onNewPDF
        ))
        submenu.addItem(
            actionItem(
                "从当前剪贴板创建…",
                onCaptureClipboard,
                symbol: "doc.on.clipboard",
                keyEquivalent: clipboardCapture.keyEquivalent,
                modifiers: clipboardCapture.modifiers,
                enabled: clipboardCaptureEnabled
            )
        )
        submenu.addItem(workspaceMenu(
            items: workspaces,
            onSelect: onSelectWorkspace,
            onCreate: onCreateWorkspace
        ))
        submenu.addItem(.separator())
        submenu.addItem(
            actionItem(
                allHidden ? "显示全部" : "隐藏全部",
                onToggleVisibility,
                symbol: allHidden ? "eye" : "eye.slash",
                keyEquivalent: hideShow.keyEquivalent,
                modifiers: hideShow.modifiers
            )
        )
        item.submenu = submenu
        return item
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

    private static func homeMenu(
        title: String,
        symbol: String,
        items: [GlanceHomeItem],
        emptyTitle: String,
        onReveal: @escaping (GlobalSearchResultID) -> GlanceActionOutcome
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = GlanceTheme.menuSymbol(symbol)
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        if items.isEmpty {
            let empty = NSMenuItem(title: emptyTitle, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for homeItem in items {
                submenu.addItem(
                    actionItem(
                        homeItem.title,
                        {
                            if case .failed = onReveal(homeItem.id) {
                                NSSound.beep()
                            }
                        },
                        symbol: homeItem.source.symbol
                    )
                )
            }
        }
        item.submenu = submenu
        return item
    }

    private static func menuKey(_ shortcut: GlanceShortcut?) -> (keyEquivalent: String, modifiers: NSEvent.ModifierFlags) {
        guard let shortcut else { return ("", []) }
        return (
            ShortcutDisplayFormatter.keyEquivalent(shortcut),
            MacShortcutAdapter.menuModifierMask(for: shortcut)
        )
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
