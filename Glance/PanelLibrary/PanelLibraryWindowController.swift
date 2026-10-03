import AppKit
import SwiftUI

final class PanelLibraryWindowController: NSWindowController, NSWindowDelegate {
    private let model: PanelLibraryModel

    convenience init(panelManager: PanelManager) {
        let model = PanelLibraryModel()
        model.loadSummaryInputs = { panelManager.summaryInputs() }
        model.summaryLoader = PanelSummaryLoader()
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
        model.setTags = { id, tags in
            try panelManager.setTags(id: id, tags: tags)
        }
        model.loadTagCatalog = { panelManager.allTagNames() }
        model.setHiddenMany = { ids, hidden in
            try panelManager.setPanelsHidden(ids: ids, hidden: hidden)
        }
        model.movePanels = { ids, workspaceID in
            try panelManager.movePanels(ids: ids, toWorkspaceID: workspaceID)
        }
        model.addTagsToPanels = { ids, tags in
            try panelManager.addTags(ids: ids, tags: tags)
        }
        model.removeTagsFromPanels = { ids, tags in
            try panelManager.removeTags(ids: ids, tags: tags)
        }
        let hosting = NSHostingController(rootView: PanelLibraryView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Glance"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 920, height: 580))
        window.minSize = NSSize(width: 720, height: 420)
        window.backgroundColor = .windowBackgroundColor
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

    @discardableResult
    func present(selecting id: UUID) -> Bool {
        present()
        model.revealInLibrary(id)
        return true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.reload()
    }

    func windowWillClose(_ notification: Notification) {
        model.cancelSummaryLoading()
    }
}
