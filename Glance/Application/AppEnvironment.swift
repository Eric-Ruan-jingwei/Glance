import AppKit
import Foundation

@MainActor
final class AppEnvironment {
    let repository: PanelRepository
    let payloadStore: PayloadStore
    let mediaStore = MediaStore()
    let visibility = GlobalVisibilityController()
    let debouncer = SaveDebouncer()
    let interaction = InteractionController()
    let shortcuts: ShortcutManager
    let shortcutStore: ShortcutStore
    let shortcutCoordinator: ShortcutCoordinator
    let workspacePreferences: WorkspacePreferenceStore
    let clipboardHistoryPreferences: ClipboardHistoryPreferenceStore
    let clipboardHistoryStore: ClipboardHistoryStore
    let clipboardHistoryService: ClipboardHistoryService
    let clipboardHistoryMonitor: ClipboardHistoryMonitor
    let fileShelfStore: FileShelfStore
    let fileShelfService: FileShelfService
    let snippetStore: SnippetStore
    let snippetService: SnippetService
    let linkStore: LinkStore
    let linkService: LinkService

    weak var panelManager: PanelManager?

    let applicationSupportRoot: URL

    static func live() throws -> AppEnvironment {
        try AppEnvironment(processEnvironment: ProcessInfo.processInfo.environment)
    }

    static func isolatedForTesting(root: URL) throws -> AppEnvironment {
        try AppEnvironment(processEnvironment: [
            ApplicationDataLocation.environmentKey: root.path
        ])
    }

    private init(processEnvironment environment: [String: String]) throws {
        var root = ApplicationDataLocation.resolve(environment: environment)
        if environment[ApplicationDataLocation.environmentKey] != nil,
           environment["XCTestConfigurationFilePath"] != nil {
            root = root.appendingPathComponent(
                "run-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)",
                isDirectory: true
            )
        }
        try ApplicationDataLocation.prepare(root, environment: environment)
        if environment[ApplicationDataLocation.environmentKey] != nil {
            NSLog("Glance: using isolated data root %@", root.path)
        }
        self.applicationSupportRoot = root
        self.payloadStore = try PayloadStore(applicationSupportRoot: root)
        self.repository = try PanelRepository(fileURL: payloadStore.metadataURL)
        let shortcuts = ShortcutManager()
        let store = ShortcutStore()
        self.shortcuts = shortcuts
        self.shortcutStore = store
        self.shortcutCoordinator = ShortcutCoordinator(store: store, manager: shortcuts)
        self.workspacePreferences = WorkspacePreferenceStore()
        let clipboardPreferences = ClipboardHistoryPreferenceStore()
        let clipboardStore = ClipboardHistoryStore(
            root: root.appendingPathComponent("Clipboard", isDirectory: true)
        )
        let clipboardService = ClipboardHistoryService(
            store: clipboardStore,
            preferences: clipboardPreferences
        )
        let clipboardMonitor = ClipboardHistoryMonitor(
            isEnabled: { clipboardService.isRecordingEnabled }
        )
        clipboardMonitor.onCapture = { content in
            _ = clipboardService.record(content)
        }
        self.clipboardHistoryPreferences = clipboardPreferences
        self.clipboardHistoryStore = clipboardStore
        self.clipboardHistoryService = clipboardService
        self.clipboardHistoryMonitor = clipboardMonitor
        let fileShelfStore = FileShelfStore(
            root: root.appendingPathComponent("FileShelf", isDirectory: true)
        )
        self.fileShelfStore = fileShelfStore
        self.fileShelfService = FileShelfService(
            store: fileShelfStore,
            bookmarks: MacFileReferenceAdapter.shared
        )
        let snippetStore = SnippetStore(
            root: root.appendingPathComponent("Snippets", isDirectory: true)
        )
        self.snippetStore = snippetStore
        self.snippetService = SnippetService(store: snippetStore)
        let linkStore = LinkStore(
            root: root.appendingPathComponent("Links", isDirectory: true)
        )
        self.linkStore = linkStore
        self.linkService = LinkService(store: linkStore)
    }

    func startClipboardMonitoringIfNeeded() {
        guard clipboardHistoryService.isRecordingEnabled else { return }
        clipboardHistoryMonitor.start(baselineChangeCount: NSPasteboard.general.changeCount)
    }

    func setClipboardRecordingEnabled(_ enabled: Bool) {
        clipboardHistoryPreferences.isRecordingEnabled = enabled
        if enabled {
            clipboardHistoryMonitor.start(baselineChangeCount: NSPasteboard.general.changeCount)
        } else {
            clipboardHistoryMonitor.stop()
        }
    }
}
