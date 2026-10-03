import Foundation

final class ShortcutStore {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func shortcut(for action: ShortcutAction) -> GlanceShortcut {
        explicitShortcut(for: action) ?? ShortcutDefaults.shortcut(for: action)
    }

    /// Preference actually stored, decoded, and valid. Missing or invalid payload is `nil`.
    func explicitShortcut(for action: ShortcutAction) -> GlanceShortcut? {
        guard let data = storedData(for: action) else { return nil }
        do {
            let decoded = try decoder.decode(GlanceShortcut.self, from: data)
            if ShortcutValidator.problem(with: decoded) != nil {
                return nil
            }
            return decoded
        } catch {
            return nil
        }
    }

    func setShortcut(_ shortcut: GlanceShortcut, for action: ShortcutAction) {
        guard ShortcutValidator.problem(with: shortcut) == nil,
              let data = try? encoder.encode(shortcut) else { return }
        defaults.set(data, forKey: action.preferenceKey)
    }

    func resetShortcut(for action: ShortcutAction) {
        defaults.removeObject(forKey: action.preferenceKey)
    }

    func resetAll() {
        ShortcutAction.allCases.forEach(resetShortcut(for:))
    }

    func all() -> [ShortcutAction: GlanceShortcut] {
        Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, shortcut(for: $0)) })
    }

    private func storedData(for action: ShortcutAction) -> Data? {
        if let data = defaults.data(forKey: action.preferenceKey) {
            return data
        }
        if let string = defaults.string(forKey: action.preferenceKey) {
            return Data(string.utf8)
        }
        return nil
    }
}
