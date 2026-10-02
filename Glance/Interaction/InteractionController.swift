import AppKit

enum InteractionMode {
    case normal
    case passThrough
}

/// Owns click-through behavior so it never leaks into individual panel views.
/// V0.1 keeps the API; the menu is reserved for V0.2.
@MainActor
final class InteractionController {
    func apply(_ mode: InteractionMode, to window: NSWindow) {
        switch mode {
        case .normal:
            window.ignoresMouseEvents = false
        case .passThrough:
            window.ignoresMouseEvents = true
        }
    }

    func temporaryOverrideIfNeeded(window: NSWindow, passThrough: Bool) {
        guard passThrough else {
            window.ignoresMouseEvents = false
            return
        }
        window.ignoresMouseEvents = !ModifierKeyController.optionIsPressed
    }
}
