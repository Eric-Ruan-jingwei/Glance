import Foundation

@MainActor
final class AppEnvironment {
    let repository: PanelRepository
    let payloadStore: PayloadStore
    let mediaStore = MediaStore()
    let visibility = GlobalVisibilityController()
    let debouncer = SaveDebouncer()
    let interaction = InteractionController()
    let shortcuts = ShortcutManager()

    weak var panelManager: PanelManager?

    let applicationSupportRoot: URL

    static func live() throws -> AppEnvironment {
        try AppEnvironment()
    }

    private init() throws {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glance", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        self.applicationSupportRoot = root
        self.payloadStore = try PayloadStore(applicationSupportRoot: root)
        self.repository = try PanelRepository(fileURL: payloadStore.metadataURL)
    }
}
