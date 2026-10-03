import Foundation

final class WorkspacePreferenceStore {
    static let activeIDKey = "com.glance.workspace.activeID"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activeWorkspaceID() -> String? {
        let value = defaults.string(forKey: Self.activeIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    func setActiveWorkspaceID(_ id: String) {
        defaults.set(id, forKey: Self.activeIDKey)
    }
}
