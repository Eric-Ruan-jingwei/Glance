import Foundation

enum PanelInteractionState: Equatable {
    case reading
    case editing
    case passThrough

    var allowsKeyWindow: Bool {
        self == .editing
    }
}

enum PanelModeTransition {
    static func canBeginEditing(from state: PanelInteractionState) -> Bool {
        switch state {
        case .reading, .passThrough:
            return true
        case .editing:
            return false
        }
    }

    static func stateAfterLeavingEditing(persistedPassThrough: Bool) -> PanelInteractionState {
        persistedPassThrough ? .passThrough : .reading
    }
}
