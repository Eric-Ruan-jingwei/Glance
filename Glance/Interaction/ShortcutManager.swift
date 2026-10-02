import Foundation

/// V0.2: bind ⌥⌘H to global hide/show without requiring Accessibility
/// permission for the hide action itself. Registration stays local to the app.
@MainActor
final class ShortcutManager {
    func registerDefaults() {
        // Intentionally empty in V0.1. Global hotkeys arrive in V0.2.
    }
}
