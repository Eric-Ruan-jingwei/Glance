import Foundation

enum PanelRevealPolicy {
    /// Global hide/show applies to newly created panels. Quick Capture must not unconceal.
    static func shouldPresentNewlyCreatedPanel(isGloballyConcealed: Bool) -> Bool {
        !isGloballyConcealed
    }
}
