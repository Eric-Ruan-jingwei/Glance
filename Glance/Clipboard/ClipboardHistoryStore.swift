import Foundation

enum ClipboardHistoryStoreError: Error, Equatable, LocalizedError {
    case unreadable
    case unsupportedFutureSchema(Int)
    case writeFailed
    case notWritable

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "clipboard history.json is not readable"
        case .unsupportedFutureSchema(let version):
            return "clipboard history.json uses schema \(version); this app supports schema \(ClipboardHistoryDatabase.currentSchemaVersion)"
        case .writeFailed:
            return "unable to write clipboard history"
        case .notWritable:
            return "clipboard history is not writable"
        }
    }
}

private struct ClipboardHistorySchemaPeek: Decodable {
    var schemaVersion: Int
}

enum ClipboardHistoryCodec {
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

    static func decode(from data: Data) throws -> ClipboardHistoryDatabase {
        let decoder = makeDecoder()
        if let peek = try? decoder.decode(ClipboardHistorySchemaPeek.self, from: data) {
            if peek.schemaVersion > ClipboardHistoryDatabase.currentSchemaVersion {
                throw ClipboardHistoryStoreError.unsupportedFutureSchema(peek.schemaVersion)
            }
            if peek.schemaVersion == ClipboardHistoryDatabase.currentSchemaVersion {
                return try decoder.decode(ClipboardHistoryDatabase.self, from: data)
            }
        }
        throw ClipboardHistoryStoreError.unreadable
    }
}

final class ClipboardHistoryStore {
    typealias MetadataWriter = (Data, URL) throws -> Void

    let root: URL
    let metadataURL: URL
    let assetsDirectory: URL
    private let fileManager: FileManager
    private let writePrimaryMetadata: MetadataWriter
    private(set) var lastLoadOutcome: ClipboardHistoryLoadOutcome = .missing
    private(set) var isWritable = true

    init(
        root: URL,
        fileManager: FileManager = .default,
        writePrimaryMetadata: MetadataWriter? = nil
    ) {
        self.root = root
        self.metadataURL = root.appendingPathComponent("history.json")
        self.assetsDirectory = root.appendingPathComponent("Assets", isDirectory: true)
        self.fileManager = fileManager
        self.writePrimaryMetadata = writePrimaryMetadata ?? { data, url in
            try data.write(to: url, options: .atomic)
        }
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
        } catch {
            lastLoadOutcome = .unavailable
            isWritable = false
        }
    }

    func load() -> [ClipboardHistoryRecord] {
        guard isWritable || lastLoadOutcome != .unavailable else { return [] }
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            lastLoadOutcome = .missing
            isWritable = true
            return []
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            let database = try ClipboardHistoryCodec.decode(from: data)
            lastLoadOutcome = .loaded
            isWritable = true
            let cleaned = cleanup(database.items)
            if cleaned != database.items {
                try? save(cleaned)
            }
            return cleaned
        } catch ClipboardHistoryStoreError.unsupportedFutureSchema(let version) {
            lastLoadOutcome = .unsupportedFutureSchema(version)
            isWritable = false
            NSLog(
                "Glance clipboard: history.json uses schema %d; this app supports schema %d. Leaving the file untouched.",
                version,
                ClipboardHistoryDatabase.currentSchemaVersion
            )
            return []
        } catch {
            quarantineCorruptMetadata()
            lastLoadOutcome = .recoveredFromCorruption
            isWritable = true
            return []
        }
    }

    func save(_ records: [ClipboardHistoryRecord]) throws {
        guard isWritable else { throw ClipboardHistoryStoreError.notWritable }
        let database = ClipboardHistoryDatabase(items: records)
        let data = try ClipboardHistoryCodec.makeEncoder().encode(database)
        do {
            try writePrimaryMetadata(data, metadataURL)
        } catch {
            throw ClipboardHistoryStoreError.writeFailed
        }
    }

    func assetURL(for record: ClipboardHistoryRecord) -> URL? {
        guard let assetPath = record.assetPath, !assetPath.isEmpty else { return nil }
        return root.appendingPathComponent(assetPath)
    }

    func writeAsset(id: UUID, png: Data) throws -> String {
        guard isWritable else { throw ClipboardHistoryStoreError.notWritable }
        try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
        let relative = "Assets/\(id.uuidString).png"
        let url = root.appendingPathComponent(relative)
        do {
            try png.write(to: url, options: .atomic)
        } catch {
            throw ClipboardHistoryStoreError.writeFailed
        }
        return relative
    }

    func deleteAsset(relativePath: String) {
        let url = root.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            NSLog("Glance clipboard: left orphan asset %@", url.path)
        }
    }

    func removeAllAssets() {
        guard fileManager.fileExists(atPath: assetsDirectory.path) else { return }
        do {
            try fileManager.removeItem(at: assetsDirectory)
            try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("Glance clipboard: failed to reset assets directory")
        }
    }

    private func cleanup(_ records: [ClipboardHistoryRecord]) -> [ClipboardHistoryRecord] {
        let existingAssets = Set(records.compactMap(\.assetPath))
        if let contents = try? fileManager.contentsOfDirectory(atPath: assetsDirectory.path) {
            for name in contents {
                let relative = "Assets/\(name)"
                if !existingAssets.contains(relative) {
                    deleteAsset(relativePath: relative)
                }
            }
        }
        return records.filter { record in
            guard record.kind == .image else { return true }
            guard let url = assetURL(for: record) else { return false }
            return fileManager.fileExists(atPath: url.path)
        }
    }

    private func quarantineCorruptMetadata() {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = root.appendingPathComponent("history.corrupted-\(stamp).json")
        do {
            try fileManager.moveItem(at: metadataURL, to: destination)
            NSLog("Glance clipboard: quarantined corrupt history.json as %@", destination.lastPathComponent)
        } catch {
            NSLog("Glance clipboard: failed to quarantine corrupt history.json")
        }
    }
}
