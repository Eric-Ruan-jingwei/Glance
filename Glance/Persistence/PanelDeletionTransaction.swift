import Foundation

enum PanelDeletionTransaction {
    /// Deletes metadata first. Controller and payload cleanup run only after that succeeds.
    static func perform(
        deleteMetadata: () throws -> Void,
        removeController: () -> Void,
        deletePayload: () -> Void
    ) throws {
        try deleteMetadata()
        removeController()
        deletePayload()
    }
}
