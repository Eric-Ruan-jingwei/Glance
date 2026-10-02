import Foundation

enum PanelOpacity {
    static let minimum: Double = 0.30
    static let maximum: Double = 1.00

    static func clamp(_ value: Double) -> Double {
        min(maximum, max(minimum, value))
    }
}

struct PanelInteractionPolicy: Equatable {
    var isLocked: Bool
    var isPassThrough: Bool
    var isOptionPressed: Bool
    var interactionState: PanelInteractionState

    var mouseEventsReachPanel: Bool {
        if interactionState == .editing {
            return true
        }
        if !isPassThrough {
            return true
        }
        return isOptionPressed
    }

    var allowsMove: Bool {
        mouseEventsReachPanel && !isLocked
    }

    var allowsResize: Bool {
        mouseEventsReachPanel && !isLocked
    }

    var allowsEdit: Bool {
        mouseEventsReachPanel
            && !isLocked
            && PanelModeTransition.canBeginEditing(from: interactionState)
    }

    var allowsContentMutation: Bool {
        mouseEventsReachPanel && !isLocked
    }
}
