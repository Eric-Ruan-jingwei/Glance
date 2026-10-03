import AppKit

@MainActor
public enum GlanceMain {
    private static var delegate: AppDelegate?

    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var panelManager: PanelManager?
    private var statusBar: StatusBarController?
    private var settingsWindow: SettingsWindowController?
    private var panelLibrary: PanelLibraryWindowController?
    private var quickCapture: QuickCaptureWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment.live()
            let manager = PanelManager(environment: environment)
            self.environment = environment
            self.panelManager = manager
            let statusBar = StatusBarController(
                manager: manager,
                onSettings: { [weak self] in self?.showSettings() },
                onManagePanels: { [weak self] in self?.showPanelLibrary() }
            )
            statusBar.install()
            self.statusBar = statusBar
            let capture = QuickCaptureWindowController()
            capture.onSubmit = { [weak manager] request, screen in
                manager?.createPanel(from: request, preferredScreen: screen) ?? false
            }
            self.quickCapture = capture
            manager.onToggleQuickCapture = { [weak capture] in
                capture?.toggle()
            }
            environment.shortcuts.onToggleVisibility = { [weak manager] in
                manager?.toggleGlobalVisibility()
            }
            environment.shortcuts.onQuickCapture = { [weak capture] in
                capture?.toggle()
            }
            environment.shortcuts.onCaptureClipboard = { [weak manager] in
                manager?.captureClipboard()
            }
            environment.shortcuts.registerDefaults()
            manager.restoreAll()
        } catch {
            presentStartupFailure(error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLifecycle.handleTerminate(manager: panelManager, environment: environment)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showPanelLibrary() {
        if panelLibrary == nil, let panelManager {
            panelLibrary = PanelLibraryWindowController(panelManager: panelManager)
        }
        panelLibrary?.present()
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(environment: environment)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    private func presentStartupFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Glance 无法启动"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }
}
