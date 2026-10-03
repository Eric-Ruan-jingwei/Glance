import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(
        environment: AppEnvironment,
        onOpenGuideShortcuts: @escaping () -> Void = {}
    ) {
        let root = environment.applicationSupportRoot
        let view = SettingsView(
            dataFolderURL: root,
            versionText: GlanceConstants.versionDisplay,
            onRevealData: {
                NSWorkspace.shared.open(root)
            },
            onOpenGuideShortcuts: onOpenGuideShortcuts,
            shortcuts: environment.shortcutCoordinator,
            clipboard: environment.clipboardHistoryService,
            onRecordingChange: { enabled in
                environment.setClipboardRecordingEnabled(enabled)
            }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "设置"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 680))
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}
