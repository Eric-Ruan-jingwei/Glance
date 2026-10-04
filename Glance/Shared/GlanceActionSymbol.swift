import AppKit
import SwiftUI

enum GlanceActionSymbol {
    static let open = "arrow.up.right.square"
    static let openFile = FileShelfQuickAction.openSymbol
    static let copy = "doc.on.doc"
    static let edit = "pencil"
    static let delete = "trash"
    static let favorite = "star"
    static let unfavorite = "star.slash"
    static let pin = "pin"
    static let unpin = "pin.slash"
    static let reveal = "folder"
    static let revealInSource = "arrow.uturn.backward"
    static let preview = "eye"
    static let relink = FileShelfQuickAction.relinkSymbol
    static let hide = "eye.slash"
    static let show = "eye"
    static let move = "folder"
    static let tags = "tag"
    static let create = "plus"
    static let snippet = "text.quote"
    static let link = "link"
    static let remove = FileShelfQuickAction.removeSymbol
    static let folder = "folder"

    static func favorite(isOn: Bool) -> String {
        isOn ? unfavorite : favorite
    }

    static func pin(isOn: Bool) -> String {
        isOn ? unpin : pin
    }

    static func visibility(isHidden: Bool) -> String {
        PanelLibraryQuickAction.visibilitySymbol(isHidden: isHidden)
    }
}

struct GlanceMenuButton: View {
    var title: String
    var systemImage: String
    var role: ButtonRole? = nil
    var identifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier ?? title)
    }
}

enum GlanceNSMenuItem {
    static func make(
        title: String,
        symbol: String,
        action: Selector,
        target: AnyObject?,
        representedObject: Any? = nil,
        identifier: String? = nil,
        destructive: Bool = false
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.image = GlanceTheme.menuSymbol(symbol)
        item.representedObject = representedObject
        if let identifier {
            item.identifier = NSUserInterfaceItemIdentifier(identifier)
        }
        applySystemDestructive(item, destructive)
        return item
    }

    static func applySystemDestructive(_ item: NSMenuItem, _ destructive: Bool) {
        guard destructive else { return }
        let setter = NSSelectorFromString("setDestructive:")
        guard item.responds(to: setter) else { return }
        item.setValue(true, forKey: "destructive")
    }

    static func isSystemDestructive(_ item: NSMenuItem) -> Bool {
        let getter = NSSelectorFromString("isDestructive")
        guard item.responds(to: getter) else { return false }
        return (item.value(forKey: "destructive") as? Bool) ?? false
    }
}
