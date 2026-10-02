import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(environment: AppEnvironment?) {
        let root = environment?.applicationSupportRoot
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Glance", isDirectory: true)
        let view = SettingsView(dataFolderURL: root) {
            NSWorkspace.shared.open(root)
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "设置"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 280))
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}
