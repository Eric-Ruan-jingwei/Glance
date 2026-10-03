import Foundation

enum SnippetStoreError: Error, Equatable, LocalizedError {
    case unreadable
    case unsupportedFutureSchema(Int)
    case writeFailed
    case notWritable

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "snippets.json is not readable"
        case .unsupportedFutureSchema(let version):
            return "snippets.json uses schema \(version); this app supports schema \(SnippetDatabase.currentSchemaVersion)"
        case .writeFailed:
            return "unable to write snippets"
        case .notWritable:
            return "snippets are not writable"
        }
    }
}

private struct SnippetSchemaPeek: Decodable {
    var schemaVersion: Int
}

enum SnippetCodec {
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

    static func decode(from data: Data) throws -> SnippetDatabase {
        let decoder = makeDecoder()
        if let peek = try? decoder.decode(SnippetSchemaPeek.self, from: data) {
            if peek.schemaVersion > SnippetDatabase.currentSchemaVersion {
                throw SnippetStoreError.unsupportedFutureSchema(peek.schemaVersion)
            }
            if peek.schemaVersion == SnippetDatabase.currentSchemaVersion {
                return try decoder.decode(SnippetDatabase.self, from: data)
            }
        }
        throw SnippetStoreError.unreadable
    }
}

final class SnippetStore {
    typealias MetadataWriter = (Data, URL) throws -> Void
    typealias ItemMover = (URL, URL) throws -> Void

    let root: URL
    let metadataURL: URL
    private let fileManager: FileManager
    private let writePrimaryMetadata: MetadataWriter
    private let moveItem: ItemMover
    private(set) var lastLoadOutcome: SnippetLoadOutcome = .missing
    private(set) var isWritable = true

    init(
        root: URL,
        fileManager: FileManager = .default,
        writePrimaryMetadata: MetadataWriter? = nil,
        moveItem: ItemMover? = nil
    ) {
        self.root = root
        self.metadataURL = root.appendingPathComponent("snippets.json")
        self.fileManager = fileManager
        self.writePrimaryMetadata = writePrimaryMetadata ?? { data, url in
            try data.write(to: url, options: .atomic)
        }
        self.moveItem = moveItem ?? { from, to in
            try fileManager.moveItem(at: from, to: to)
        }
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            lastLoadOutcome = .unavailable
            isWritable = false
        }
    }

    func load() -> [SnippetRecord] {
        guard isWritable || lastLoadOutcome != .unavailable else { return [] }
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            lastLoadOutcome = .missing
            isWritable = true
            return []
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            let database = try SnippetCodec.decode(from: data)
            lastLoadOutcome = .loaded
            isWritable = true
            return database.items
        } catch SnippetStoreError.unsupportedFutureSchema(let version) {
            lastLoadOutcome = .unsupportedFutureSchema(version)
            isWritable = false
            NSLog(
                "Glance snippets: snippets.json uses schema %d; this app supports schema %d. Leaving the file untouched.",
                version,
                SnippetDatabase.currentSchemaVersion
            )
            return []
        } catch {
            if quarantineCorruptMetadata() {
                lastLoadOutcome = .recoveredFromCorruption
                isWritable = true
            } else {
                lastLoadOutcome = .corruptUnquarantined
                isWritable = false
                NSLog("Glance snippets: corrupt snippets.json could not be quarantined; leaving the file untouched")
            }
            return []
        }
    }

    func save(_ records: [SnippetRecord]) throws {
        guard isWritable else { throw SnippetStoreError.notWritable }
        let database = SnippetDatabase(items: records)
        let data = try SnippetCodec.makeEncoder().encode(database)
        do {
            try writePrimaryMetadata(data, metadataURL)
        } catch {
            throw SnippetStoreError.writeFailed
        }
    }

    private func quarantineCorruptMetadata() -> Bool {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = root.appendingPathComponent("snippets.corrupted-\(stamp).json")
        let relocated = MetadataQuarantine.relocate(
            from: metadataURL,
            to: destination,
            moveItem: moveItem,
            fileExists: { fileManager.fileExists(atPath: $0.path) }
        )
        if relocated {
            NSLog("Glance snippets: quarantined corrupt snippets.json as %@", destination.lastPathComponent)
        } else {
            NSLog("Glance snippets: failed to quarantine corrupt snippets.json")
        }
        return relocated
    }
}
