import AppKit

enum PanelLayoutMenu {
    static let title = "布局"

    static func makeItem(target: AnyObject?, action: Selector, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for preset in PanelLayoutPreset.allCases {
            let child = NSMenuItem(title: preset.menuTitle, action: action, keyEquivalent: "")
            child.target = target
            child.representedObject = preset.rawValue
            child.isEnabled = enabled
            menu.addItem(child)
        }
        item.submenu = menu
        item.isEnabled = enabled
        return item
    }
}
