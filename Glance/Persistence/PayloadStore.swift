import Foundation

final class PayloadStore {
    let applicationSupportRoot: URL
    let databaseDirectory: URL
    let panelsRoot: URL

    init(applicationSupportRoot: URL) throws {
        self.applicationSupportRoot = applicationSupportRoot
        self.databaseDirectory = applicationSupportRoot.appendingPathComponent("Database", isDirectory: true)
        self.panelsRoot = applicationSupportRoot.appendingPathComponent("Panels", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: panelsRoot, withIntermediateDirectories: true)
    }

    func directory(for id: UUID) throws -> URL {
        let dir = panelsRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func relativePath(for id: UUID) -> String {
        "Panels/\(id.uuidString)"
    }

    func delete(id: UUID) {
        let dir = panelsRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    var metadataURL: URL {
        databaseDirectory.appendingPathComponent("panels.json")
    }
}
