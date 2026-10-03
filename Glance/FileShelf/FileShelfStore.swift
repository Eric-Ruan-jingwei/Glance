import Foundation

enum FileShelfStoreError: Error, Equatable, LocalizedError {
    case unreadable
    case unsupportedFutureSchema(Int)
    case writeFailed
    case notWritable
    case bookmarkFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "file shelf.json is not readable"
        case .unsupportedFutureSchema(let version):
            return "file shelf.json uses schema \(version); this app supports schema \(FileShelfDatabase.currentSchemaVersion)"
        case .writeFailed:
            return "unable to write file shelf"
        case .notWritable:
            return "file shelf is not writable"
        case .bookmarkFailed:
            return "unable to create a file bookmark"
        }
    }
}

private struct FileShelfSchemaPeek: Decodable {
    var schemaVersion: Int
}

enum FileShelfCodec {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func decode(from data: Data) throws -> FileShelfDatabase {
        let decoder = makeDecoder()
        if let peek = try? decoder.decode(FileShelfSchemaPeek.self, from: data) {
            if peek.schemaVersion > FileShelfDatabase.currentSchemaVersion {
                throw FileShelfStoreError.unsupportedFutureSchema(peek.schemaVersion)
            }
            if peek.schemaVersion == FileShelfDatabase.currentSchemaVersion {
                return try decoder.decode(FileShelfDatabase.self, from: data)
            }
        }
        throw FileShelfStoreError.unreadable
    }
}

final class FileShelfStore {
    typealias MetadataWriter = (Data, URL) throws -> Void
    typealias ItemMover = (URL, URL) throws -> Void

    let root: URL
    let metadataURL: URL
    let bookmarksDirectory: URL
    private let fileManager: FileManager
    private let writePrimaryMetadata: MetadataWriter
    private let moveItem: ItemMover
    private(set) var lastLoadOutcome: FileShelfLoadOutcome = .missing
    private(set) var isWritable = true

    init(
        root: URL,
        fileManager: FileManager = .default,
        writePrimaryMetadata: MetadataWriter? = nil,
        moveItem: ItemMover? = nil
    ) {
        self.root = root
        self.metadataURL = root.appendingPathComponent("shelf.json")
        self.bookmarksDirectory = root.appendingPathComponent("Bookmarks", isDirectory: true)
        self.fileManager = fileManager
        self.writePrimaryMetadata = writePrimaryMetadata ?? { data, url in
            try data.write(to: url, options: .atomic)
        }
        self.moveItem = moveItem ?? { from, to in
            try fileManager.moveItem(at: from, to: to)
        }
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: bookmarksDirectory, withIntermediateDirectories: true)
        } catch {
            lastLoadOutcome = .unavailable
            isWritable = false
        }
    }

    func load() -> [FileShelfRecord] {
        guard isWritable || lastLoadOutcome != .unavailable else { return [] }
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            lastLoadOutcome = .missing
            isWritable = true
            cleanupOrphanBookmarks(referenced: [])
            return []
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            let database = try FileShelfCodec.decode(from: data)
            lastLoadOutcome = .loaded
            isWritable = true
            cleanupOrphanBookmarks(referenced: Set(database.items.map(\.id)))
            return database.items
        } catch FileShelfStoreError.unsupportedFutureSchema(let version) {
            lastLoadOutcome = .unsupportedFutureSchema(version)
            isWritable = false
            NSLog(
                "Glance file shelf: shelf.json uses schema %d; this app supports schema %d. Leaving the file untouched.",
                version,
                FileShelfDatabase.currentSchemaVersion
            )
            return []
        } catch {
            if quarantineCorruptMetadata() {
                lastLoadOutcome = .recoveredFromCorruption
                isWritable = true
            } else {
                lastLoadOutcome = .corruptUnquarantined
                isWritable = false
                NSLog("Glance file shelf: corrupt shelf.json could not be quarantined; leaving the file untouched")
            }
            return []
        }
    }

    func save(_ records: [FileShelfRecord]) throws {
        guard isWritable else { throw FileShelfStoreError.notWritable }
        let database = FileShelfDatabase(items: records)
        let data = try FileShelfCodec.makeEncoder().encode(database)
        do {
            try writePrimaryMetadata(data, metadataURL)
        } catch {
            throw FileShelfStoreError.writeFailed
        }
    }

    func bookmarkURL(for id: UUID) -> URL {
        bookmarksDirectory.appendingPathComponent("\(id.uuidString).bookmark")
    }

    func writeBookmark(id: UUID, data: Data) throws {
        guard isWritable else { throw FileShelfStoreError.notWritable }
        try fileManager.createDirectory(at: bookmarksDirectory, withIntermediateDirectories: true)
        do {
            try data.write(to: bookmarkURL(for: id), options: .atomic)
        } catch {
            throw FileShelfStoreError.writeFailed
        }
    }

    func readBookmark(id: UUID) -> Data? {
        let url = bookmarkURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func deleteBookmark(id: UUID) {
        let url = bookmarkURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            NSLog("Glance file shelf: left orphan bookmark %@", url.path)
        }
    }

    private func cleanupOrphanBookmarks(referenced: Set<UUID>) {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: bookmarksDirectory.path) else {
            return
        }
        for name in contents where name.hasSuffix(".bookmark") {
            let stem = String(name.dropLast(".bookmark".count))
            guard let id = UUID(uuidString: stem), !referenced.contains(id) else { continue }
            deleteBookmark(id: id)
        }
    }

    private func quarantineCorruptMetadata() -> Bool {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = root.appendingPathComponent("shelf.corrupted-\(stamp).json")
        let relocated = MetadataQuarantine.relocate(
            from: metadataURL,
            to: destination,
            moveItem: moveItem,
            fileExists: { fileManager.fileExists(atPath: $0.path) }
        )
        if relocated {
            NSLog("Glance file shelf: quarantined corrupt shelf.json as %@", destination.lastPathComponent)
        } else {
            NSLog("Glance file shelf: failed to quarantine corrupt shelf.json")
        }
        return relocated
    }
}
