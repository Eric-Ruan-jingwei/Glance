import AppKit

/// Minimal AppKit Edit menu so ⌘X/C/V/A/Z and ⇧⌘Z reach the field editor
/// through the responder chain. Accessory apps do not get this menu from a nib.
@MainActor
enum GlanceStandardEditMenu {
    static let title = "编辑"

    static let undo = NSSelectorFromString("undo:")
    static let redo = NSSelectorFromString("redo:")
    static let cut = #selector(NSText.cut(_:))
    static let copy = #selector(NSText.copy(_:))
    static let paste = #selector(NSText.paste(_:))
    static let selectAll = #selector(NSText.selectAll(_:))

    @discardableResult
    static func install(on application: NSApplication) -> NSMenu {
        let mainMenu = application.mainMenu ?? NSMenu()
        application.mainMenu = mainMenu
        return install(into: mainMenu)
    }

    @discardableResult
    static func install(into mainMenu: NSMenu) -> NSMenu {
        ensureApplicationMenuPlaceholder(in: mainMenu)
        if let existing = editMenu(in: mainMenu) {
            populate(existing)
            return existing
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        item.submenu = menu
        populate(menu)
        mainMenu.addItem(item)
        return menu
    }

    static func editMenu(in mainMenu: NSMenu) -> NSMenu? {
        mainMenu.items.compactMap(\.submenu).first { submenu in
            submenu.title == title || submenu.items.contains { $0.action == paste }
        }
    }

    static func commandItem(action: Selector, in mainMenu: NSMenu) -> NSMenuItem? {
        editMenu(in: mainMenu)?.items.first { $0.action == action }
    }

    private static func ensureApplicationMenuPlaceholder(in mainMenu: NSMenu) {
        guard mainMenu.items.isEmpty else { return }
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        mainMenu.addItem(appItem)
    }

    private static func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.title = title
        menu.addItem(command("撤销", action: undo, key: "z"))
        let redoItem = command("重做", action: redo, key: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redoItem)
        menu.addItem(.separator())
        menu.addItem(command("剪切", action: cut, key: "x"))
        menu.addItem(command("复制", action: copy, key: "c"))
        menu.addItem(command("粘贴", action: paste, key: "v"))
        menu.addItem(.separator())
        menu.addItem(command("全选", action: selectAll, key: "a"))
    }

    private static func command(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = nil
        item.keyEquivalentModifierMask = .command
        return item
    }
}

/// Library key monitors must not eat events that belong to a sheet editor or IME.
enum GlanceLibraryKeyMonitor {
    static func shouldDeliverToResponder(editorOpen: Bool, isComposingIME: Bool) -> Bool {
        editorOpen || isComposingIME
    }
}
