import AppKit
import SwiftUI

@MainActor
final class PanelSettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: PanelSettingsModel
    var onClose: (() -> Void)?

    init(model: PanelSettingsModel, view: PanelSettingsView) {
        self.model = model
        let hosting = NSHostingController(rootView: view)
        let window = NSPanel(contentViewController: hosting)
        window.title = "面板设置"
        window.styleMask = [.titled, .closable]
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.level = .floating
        window.setContentSize(NSSize(width: 280, height: 280))
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bringForward() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
