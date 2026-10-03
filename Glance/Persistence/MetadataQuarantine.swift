import Foundation

enum MetadataQuarantine {
    /// Relocates a corrupt metadata file. Returns `true` only when `primary` no longer exists.
    static func relocate(
        from primary: URL,
        to destination: URL,
        moveItem: (URL, URL) throws -> Void,
        fileExists: (URL) -> Bool
    ) -> Bool {
        do {
            try moveItem(primary, destination)
        } catch {
            return !fileExists(primary)
        }
        return !fileExists(primary)
    }
}
