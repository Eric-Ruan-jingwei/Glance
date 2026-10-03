import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(environment: AppEnvironment) {
        let root = environment.applicationSupportRoot
        let view = SettingsView(
            dataFolderURL: root,
            versionText: GlanceConstants.versionDisplay,
            onRevealData: {
                NSWorkspace.shared.open(root)
            },
            shortcuts: environment.shortcutCoordinator
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "设置"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 540))
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}
