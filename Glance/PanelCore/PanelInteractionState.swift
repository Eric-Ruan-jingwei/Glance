import Foundation

enum PanelInteractionState: Equatable {
    case reading
    case editing
    case passThrough

    var allowsKeyWindow: Bool {
        self == .editing
    }
}
