import AppKit
import SwiftUI

final class PanelLibraryWindowController: NSWindowController, NSWindowDelegate {
    private let model: PanelLibraryModel

    convenience init(panelManager: PanelManager) {
        let model = PanelLibraryModel()
        model.loadSummaries = { panelManager.panelSummaries() }
        model.loadWorkspaces = { panelManager.workspaces() }
        model.loadActiveWorkspaceID = { panelManager.activeWorkspaceID }
        model.switchWorkspace = { id in
            _ = panelManager.switchWorkspace(id: id)
        }
        model.createWorkspace = { name in
            try panelManager.createWorkspace(name: name)
        }
        model.renameWorkspace = { id, name in
            try panelManager.renameWorkspace(id: id, name: name)
        }
        model.deleteWorkspace = { id in
            try panelManager.deleteWorkspace(id: id)
        }
        model.movePanel = { id, workspaceID in
            panelManager.movePanel(id: id, toWorkspaceID: workspaceID)
        }
        model.reveal = { panelManager.revealPanel(id: $0) }
        model.hide = { _ = panelManager.hidePanel(id: $0) }
        model.delete = { panelManager.deletePanel(id: $0) }
        model.openFolder = { panelManager.openPayloadFolder(id: $0) }
        model.rename = { id, title in
            try panelManager.setCustomTitle(id: id, title: title)
        }
        let hosting = NSHostingController(rootView: PanelLibraryView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "管理面板"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 880, height: 540))
        window.minSize = NSSize(width: 720, height: 420)
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
