import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let manager: PanelManager
    private let onSettings: () -> Void
    private let onManagePanels: () -> Void
    private let onOpenGuide: () -> Void
    private let onShowClipboardHistory: () -> Void
    private let onShowFileShelf: () -> Void
    private let onShowSnippets: () -> Void
    private let shortcutSnapshot: () -> [ShortcutAction: GlanceShortcut]
    private var statusItem: NSStatusItem?

    init(
        manager: PanelManager,
        onSettings: @escaping () -> Void,
        onManagePanels: @escaping () -> Void,
        onOpenGuide: @escaping () -> Void = {},
        onShowClipboardHistory: @escaping () -> Void = {},
        onShowFileShelf: @escaping () -> Void = {},
        onShowSnippets: @escaping () -> Void = {},
        shortcutSnapshot: @escaping () -> [ShortcutAction: GlanceShortcut] = { ShortcutDefaults.all }
    ) {
        self.manager = manager
        self.onSettings = onSettings
        self.onManagePanels = onManagePanels
        self.onOpenGuide = onOpenGuide
        self.onShowClipboardHistory = onShowClipboardHistory
        self.onShowFileShelf = onShowFileShelf
        self.onShowSnippets = onShowSnippets
        self.shortcutSnapshot = shortcutSnapshot
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
            clipboardCaptureEnabled: MacClipboardReader.hasSupportedContent(),
            workspaces: manager.workspaceMenuItems(),
            onQuickCapture: { [weak self] in self?.manager.toggleQuickCapture() },
            onShowClipboardHistory: { [weak self] in self?.onShowClipboardHistory() },
            onShowFileShelf: { [weak self] in self?.onShowFileShelf() },
            onShowSnippets: { [weak self] in self?.onShowSnippets() },
            onCaptureClipboard: { [weak self] in self?.manager.captureClipboard() },
            onSelectWorkspace: { [weak self] id in
                _ = self?.manager.switchWorkspace(id: id)
            },
            onCreateWorkspace: { [weak self] in
                self?.manager.promptCreateWorkspace()
            },
            onManagePanels: { [weak self] in self?.onManagePanels() },
            onNewText: { [weak self] in self?.manager.createTextPanel() },
            onNewMarkdown: { [weak self] in self?.manager.createMarkdownPanel() },
            onNewTodo: { [weak self] in self?.manager.createTodoPanel() },
            onNewImage: { [weak self] in self?.manager.createImagePanel() },
            onNewPDF: { [weak self] in self?.manager.createPDFPanel() },
            onToggleVisibility: { [weak self] in self?.manager.toggleGlobalVisibility() },
            onSettings: { [weak self] in self?.onSettings() },
            onOpenGuide: { [weak self] in self?.onOpenGuide() },
            onQuit: {
                NSApp.terminate(nil)
            },
            shortcuts: shortcutSnapshot(),
            diagnostic: manager.persistenceDiagnostic(),
            onShowDiagnostic: { [weak self] in self?.presentPersistenceDiagnostic() }
        )
    }

    private func presentPersistenceDiagnostic() {
        guard let diagnostic = manager.persistenceDiagnostic() else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = diagnostic.alertMessage
        alert.informativeText = diagnostic.alertInformative
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
