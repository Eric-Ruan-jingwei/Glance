import AppKit
import SwiftUI

final class PanelLibraryWindowController: NSWindowController, NSWindowDelegate {
    private let model: PanelLibraryModel

    convenience init(panelManager: PanelManager) {
        let model = PanelLibraryModel()
        model.loadSummaries = { panelManager.panelSummaries() }
        model.reveal = { panelManager.revealPanel(id: $0) }
        model.delete = { panelManager.deletePanel(id: $0) }
        model.openFolder = { panelManager.openPayloadFolder(id: $0) }
        let hosting = NSHostingController(rootView: PanelLibraryView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "管理面板"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 520))
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.isReleasedWhenClosed = false
        self.init(existingWindow: window, model: model)
        window.delegate = self
    }

    private init(existingWindow: NSWindow, model: PanelLibraryModel) {
        self.model = model
        super.init(window: existingWindow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        if window?.isVisible == true {
            model.reload()
        } else {
            model.resetSessionState()
            model.reload()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.reload()
    }
}
