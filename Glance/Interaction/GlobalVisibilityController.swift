import Foundation

@MainActor
final class GlobalVisibilityController {
    private(set) var isConcealed = false

    func toggle() {
        isConcealed.toggle()
    }

    func setConcealed(_ concealed: Bool) {
        isConcealed = concealed
    }
}
