import Foundation

enum ApplicationDataLocation {
    static let environmentKey = "GLANCE_DATA_ROOT"

    static func defaultRoot(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glance", isDirectory: true)
            .standardizedFileURL
    }

    /// Resolves the on-disk data root. `GLANCE_DATA_ROOT` overrides Application Support,
    /// but a value that points at the real user data directory is rejected.
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        let production = defaultRoot(fileManager: fileManager)
        guard let raw = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return production
        }

        let override = URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
            .standardizedFileURL
        if isUserDataLocation(override, fileManager: fileManager) {
            return fileManager.temporaryDirectory
                .appendingPathComponent("GlanceTests-rejected-production-override", isDirectory: true)
                .standardizedFileURL
        }
        return override
    }

    static func isUserDataLocation(_ url: URL, fileManager: FileManager = .default) -> Bool {
        let production = defaultRoot(fileManager: fileManager).path
        let path = url.standardizedFileURL.path
        return path == production || path.hasPrefix(production + "/")
    }

    static func isIsolatedFromUserData(_ url: URL, fileManager: FileManager = .default) -> Bool {
        !isUserDataLocation(url, fileManager: fileManager)
    }

    /// True only for throwaway roots such as `/tmp/...`. Never true for Application Support/Glance.
    static func isSafeToReset(_ url: URL, fileManager: FileManager = .default) -> Bool {
        if isUserDataLocation(url, fileManager: fileManager) {
            return false
        }
        let path = url.standardizedFileURL.path
        if path == "/tmp" || path.hasPrefix("/tmp/") {
            return true
        }
        let tmp = fileManager.temporaryDirectory.standardizedFileURL.path
        return path == tmp || path.hasPrefix(tmp + "/")
    }

    static func prepare(
        _ root: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws {
        let standardized = root.standardizedFileURL
        let overrideSet = !(environment[environmentKey] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if overrideSet, isSafeToReset(standardized, fileManager: fileManager), fileManager.fileExists(atPath: standardized.path) {
            try fileManager.removeItem(at: standardized)
        }
        try fileManager.createDirectory(at: standardized, withIntermediateDirectories: true)
    }
}
