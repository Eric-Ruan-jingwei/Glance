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
final class AppDelegate: NSObject, NSApplicationDelegate, GlanceWindowHost {
    private var environment: AppEnvironment?
    private var panelManager: PanelManager?
    private var actionCoordinator: GlanceActionCoordinator?
    private var statusBar: StatusBarController?
    private var settingsWindow: SettingsWindowController?
    private var panelLibrary: PanelLibraryWindowController?
    private var quickCapture: QuickCaptureWindowController?
    private var clipboardWindow: ClipboardHistoryWindowController?
    private var fileShelfWindow: FileShelfWindowController?
    private var snippetWindow: SnippetLibraryWindowController?
    private var linkWindow: LinkLibraryWindowController?
    private var searchWindow: GlobalSearchWindowController?
    private var guideWindow: GuideWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment.live()
            let manager = PanelManager(environment: environment)
            self.environment = environment
            self.panelManager = manager
            let coordinator = GlanceActionCoordinator(
                environment: environment,
                panelManager: manager,
                windowHost: self
            )
            self.actionCoordinator = coordinator
            let statusBar = StatusBarController(
                manager: manager,
                onSettings: { [weak self] in self?.showSettings() },
                onManagePanels: { [weak self] in self?.showPanelLibrary() },
                onOpenGuide: { [weak self] in self?.showGuide() },
                onShowClipboardHistory: { [weak self] in self?.toggleClipboardHistory() },
                onShowFileShelf: { [weak self] in self?.toggleFileShelf() },
                onShowSnippets: { [weak self] in self?.toggleSnippets() },
                onShowLinks: { [weak self] in self?.toggleLinks() },
                onShowGlobalSearch: { [weak self] in self?.toggleGlobalSearch() },
                shortcutSnapshot: { [weak environment] in
                    environment?.shortcutCoordinator.shortcuts ?? [:]
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
            environment.shortcuts.onShowLinks = { [weak self] in
                self?.toggleLinks()
            }
            environment.shortcuts.onShowGlobalSearch = { [weak self] in
                self?.toggleGlobalSearch()
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

    func presentClipboard(selecting id: UUID) -> Bool {
        clipboardHistoryWindow().present(selecting: id)
    }

    func presentFileShelf(selecting id: UUID) -> Bool {
        fileShelfLibraryWindow().present(selecting: id)
    }

    func presentSnippets(selecting id: UUID) -> Bool {
        snippetLibraryWindow().present(selecting: id)
    }

    func presentLinks(selecting id: UUID) -> Bool {
        linkLibraryWindow().present(selecting: id)
    }

    func presentPanelLibrary(selecting id: UUID) -> Bool {
        panelLibraryWindow().present(selecting: id)
    }

    func presentSnippetEditor(prefilled text: String) {
        snippetLibraryWindow().presentEditor(prefilled: text)
    }

    func presentLinkEditor(prefilledURL urlString: String) {
        linkLibraryWindow().presentEditor(prefilledURL: urlString)
    }

    func dismissClipboardIfVisible() {
        if clipboardWindow?.isShelfVisible == true {
            clipboardWindow?.dismiss(deactivate: false)
        }
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
        panelLibraryWindow().present()
    }

    private func toggleClipboardHistory() {
        clipboardHistoryWindow().toggle()
    }

    private func toggleSnippets() {
        snippetLibraryWindow().toggle()
    }

    private func toggleLinks() {
        linkLibraryWindow().toggle()
    }

    private func toggleGlobalSearch() {
        globalSearchWindow().toggle()
    }

    private func toggleFileShelf() {
        fileShelfLibraryWindow().toggle()
    }

    private func panelLibraryWindow() -> PanelLibraryWindowController {
        if let panelLibrary {
            return panelLibrary
        }
        let window = PanelLibraryWindowController(panelManager: panelManager!)
        panelLibrary = window
        return window
    }

    private func clipboardHistoryWindow() -> ClipboardHistoryWindowController {
        if let clipboardWindow {
            return clipboardWindow
        }
        let environment = environment!
        let window = ClipboardHistoryWindowController(
            service: environment.clipboardHistoryService,
            monitor: environment.clipboardHistoryMonitor
        )
        window.onCreatePanel = { [weak self] content, screen in
            self?.actionCoordinator?.createPanel(fromClipboard: content, screen: screen) ?? false
        }
        window.onSaveAsSnippet = { [weak self] text in
            self?.actionCoordinator?.saveClipboardTextAsSnippet(text)
        }
        window.onSaveAsLink = { [weak self] url in
            self?.actionCoordinator?.saveClipboardTextAsLink(url)
        }
        clipboardWindow = window
        return window
    }

    private func snippetLibraryWindow() -> SnippetLibraryWindowController {
        if let snippetWindow {
            return snippetWindow
        }
        let environment = environment!
        let window = SnippetLibraryWindowController(
            service: environment.snippetService,
            monitor: environment.clipboardHistoryMonitor
        )
        window.onCreatePanel = { [weak self] record, screen in
            self?.actionCoordinator?.createPanel(from: record, screen: screen) ?? .failed(GlanceNoticeCopy.panelCreateFailed)
        }
        snippetWindow = window
        return window
    }

    private func linkLibraryWindow() -> LinkLibraryWindowController {
        if let linkWindow {
            return linkWindow
        }
        let environment = environment!
        let window = LinkLibraryWindowController(
            service: environment.linkService,
            monitor: environment.clipboardHistoryMonitor
        )
        window.onCreatePanel = { [weak self] record, screen in
            self?.actionCoordinator?.createPanel(from: record, screen: screen) ?? .failed(GlanceNoticeCopy.panelCreateFailed)
        }
        linkWindow = window
        return window
    }

    private func fileShelfLibraryWindow() -> FileShelfWindowController {
        if let fileShelfWindow {
            return fileShelfWindow
        }
        let window = FileShelfWindowController(service: environment!.fileShelfService)
        window.onCreatePanel = { [weak self] id, screen in
            self?.actionCoordinator?.createPanel(fromFileShelfID: id, screen: screen)
                ?? .failed(GlanceNoticeCopy.panelCreateFailed)
        }
        fileShelfWindow = window
        return window
    }

    private func globalSearchWindow() -> GlobalSearchWindowController {
        if let searchWindow {
            return searchWindow
        }
        let window = GlobalSearchWindowController(
            environment: environment!,
            panelManager: panelManager!
        )
        window.onRevealInSource = { [weak self] id in
            self?.actionCoordinator?.revealInSource(id) ?? .failed(GlanceNoticeCopy.staleItem)
        }
        searchWindow = window
        return window
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
