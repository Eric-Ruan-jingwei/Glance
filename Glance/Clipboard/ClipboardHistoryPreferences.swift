import Foundation

@MainActor
final class ClipboardHistoryPreferenceStore: ObservableObject {
    static let enabledKey = "com.glance.clipboardHistory.enabled"

    private let defaults: UserDefaults

    @Published var isRecordingEnabled: Bool {
        didSet {
            defaults.set(isRecordingEnabled, forKey: Self.enabledKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isRecordingEnabled = defaults.bool(forKey: Self.enabledKey)
    }
}
