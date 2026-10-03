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

    weak var panelManager: PanelManager?

    let applicationSupportRoot: URL

    static func live() throws -> AppEnvironment {
        try AppEnvironment()
    }

    private init() throws {
        let environment = ProcessInfo.processInfo.environment
        let root = ApplicationDataLocation.resolve(environment: environment)
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
    }
}
