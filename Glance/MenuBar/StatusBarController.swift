import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let manager: PanelManager
    private let onSettings: () -> Void
    private var statusItem: NSStatusItem?

    init(manager: PanelManager, onSettings: @escaping () -> Void) {
        self.manager = manager
        self.onSettings = onSettings
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Glance")
            image?.isTemplate = true
            button.image = image
            button.toolTip = GlanceConstants.slogan
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        StatusMenuBuilder.populate(
            menu,
            allHidden: manager.allHidden,
            onNewText: { [weak self] in self?.manager.createTextPanel() },
            onNewMarkdown: { [weak self] in self?.manager.createMarkdownPanel() },
            onNewImage: { [weak self] in self?.manager.createImagePanel() },
            onToggleVisibility: { [weak self] in self?.manager.toggleGlobalVisibility() },
            onSettings: { [weak self] in self?.onSettings() },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }
}
