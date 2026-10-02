import Foundation

/// Tracks whether panel payload bytes need to be written.
/// Load/init/layout never mark dirty; only user edits do.
final class PayloadDirtyFlag {
    private(set) var isDirty = false

    func markUserEdit() {
        isDirty = true
    }

    func markSaved() {
        isDirty = false
    }

    var shouldPersist: Bool { isDirty }
}

enum PayloadPersistence {
    /// Writes only when dirty. Success clears the flag; failure leaves it dirty.
    @discardableResult
    static func persistIfDirty(_ flag: PayloadDirtyFlag, save: () throws -> Void) rethrows -> Bool {
        guard flag.shouldPersist else { return false }
        try save()
        flag.markSaved()
        return true
    }
}
