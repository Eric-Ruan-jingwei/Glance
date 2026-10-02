import AppKit

enum StatusMenuBuilder {
    static func populate(
        _ menu: NSMenu,
        allHidden: Bool,
        onNewText: @escaping () -> Void,
        onNewMarkdown: @escaping () -> Void,
        onNewImage: @escaping () -> Void,
        onToggleVisibility: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        menu.removeAllItems()

        menu.addItem(actionItem("新建文字面板", onNewText))
        menu.addItem(actionItem("新建 Markdown 面板", onNewMarkdown))
        menu.addItem(actionItem("新建图片面板", onNewImage))
        menu.addItem(.separator())
        menu.addItem(
            actionItem(
                allHidden ? "显示全部" : "隐藏全部",
                onToggleVisibility,
                keyEquivalent: GlanceConstants.hideShowKeyEquivalent,
                modifiers: [.option, .command]
            )
        )
        menu.addItem(.separator())
        menu.addItem(actionItem("设置…", onSettings))
        menu.addItem(actionItem("退出", onQuit))
    }

    private static func actionItem(
        _ title: String,
        _ handler: @escaping () -> Void,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = modifiers
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
