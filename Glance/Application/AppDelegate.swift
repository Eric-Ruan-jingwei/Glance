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
    private var clipboardWindow: ClipboardHistoryWindowController?
    private var fileShelfWindow: FileShelfWindowController?
    private var snippetWindow: SnippetLibraryWindowController?
    private var guideWindow: GuideWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment.live()
            let manager = PanelManager(environment: environment)
            self.environment = environment
            self.panelManager = manager
            let statusBar = StatusBarController(
                manager: manager,
                onSettings: { [weak self] in self?.showSettings() },
                onManagePanels: { [weak self] in self?.showPanelLibrary() },
                onOpenGuide: { [weak self] in self?.showGuide() },
                onShowClipboardHistory: { [weak self] in self?.toggleClipboardHistory() },
                onShowFileShelf: { [weak self] in self?.toggleFileShelf() },
                onShowSnippets: { [weak self] in self?.toggleSnippets() },
                shortcutSnapshot: { [weak environment] in
                    environment?.shortcutCoordinator.shortcuts ?? ShortcutDefaults.all
                }
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
            environment.shortcuts.onShowClipboardHistory = { [weak self] in
                self?.toggleClipboardHistory()
            }
            environment.shortcuts.onShowFileShelf = { [weak self] in
                self?.toggleFileShelf()
            }
            environment.shortcuts.onShowSnippets = { [weak self] in
                self?.toggleSnippets()
            }
            environment.shortcutCoordinator.start()
            environment.startClipboardMonitoringIfNeeded()
            manager.restoreAll()
            scheduleOnboardingIfNeeded()
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

    private func scheduleOnboardingIfNeeded() {
        guard OnboardingState().shouldPresent else { return }
        DispatchQueue.main.async { [weak self] in
            self?.showGuide(onboarding: true)
        }
    }

    private func showGuide(section: GuideSection = .gettingStarted, onboarding: Bool = false) {
        guard let environment else { return }
        if guideWindow == nil {
            guideWindow = GuideWindowController(
                coordinator: environment.shortcutCoordinator,
                onOpenSettings: { [weak self] in self?.showSettings() }
            )
        }
        guideWindow?.present(section: section, onboarding: onboarding)
    }

    private func showPanelLibrary() {
        if panelLibrary == nil, let panelManager {
            panelLibrary = PanelLibraryWindowController(panelManager: panelManager)
        }
        panelLibrary?.present()
    }

    private func toggleClipboardHistory() {
        guard let environment else { return }
        if clipboardWindow == nil {
            let window = ClipboardHistoryWindowController(
                service: environment.clipboardHistoryService,
                monitor: environment.clipboardHistoryMonitor
            )
            window.onCreatePanel = { [weak self] content, screen in
                self?.panelManager?.createPanel(fromClipboardContent: content, preferredScreen: screen) ?? false
            }
            window.onSaveAsSnippet = { [weak self] text in
                self?.saveClipboardTextAsSnippet(text)
            }
            clipboardWindow = window
        }
        clipboardWindow?.toggle()
    }

    private func toggleSnippets() {
        guard let environment else { return }
        if snippetWindow == nil {
            snippetWindow = SnippetLibraryWindowController(
                service: environment.snippetService,
                monitor: environment.clipboardHistoryMonitor
            )
        }
        snippetWindow?.toggle()
    }

    private func saveClipboardTextAsSnippet(_ text: String) {
        guard let environment else { return }
        if snippetWindow == nil {
            snippetWindow = SnippetLibraryWindowController(
                service: environment.snippetService,
                monitor: environment.clipboardHistoryMonitor
            )
        }
        if clipboardWindow?.isShelfVisible == true {
            clipboardWindow?.dismiss()
        }
        snippetWindow?.presentEditor(prefilled: text)
    }

    private func toggleFileShelf() {
        guard let environment else { return }
        if fileShelfWindow == nil {
            fileShelfWindow = FileShelfWindowController(service: environment.fileShelfService)
        }
        fileShelfWindow?.toggle()
    }

    private func showSettings() {
        guard let environment else { return }
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                environment: environment,
                onOpenGuideShortcuts: { [weak self] in
                    self?.showGuide(section: .shortcuts)
                }
            )
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
