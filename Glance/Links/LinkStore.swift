import Foundation

enum LinkStoreError: Error, Equatable, LocalizedError {
    case unreadable
    case unsupportedFutureSchema(Int)
    case writeFailed
    case notWritable

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "links.json is not readable"
        case .unsupportedFutureSchema(let version):
            return "links.json uses schema \(version); this app supports schema \(LinkDatabase.currentSchemaVersion)"
        case .writeFailed:
            return "unable to write links"
        case .notWritable:
            return "links are not writable"
        }
    }
}

private struct LinkSchemaPeek: Decodable {
    var schemaVersion: Int
}

enum LinkCodec {
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

    static func decode(from data: Data) throws -> LinkDatabase {
        let decoder = makeDecoder()
        if let peek = try? decoder.decode(LinkSchemaPeek.self, from: data) {
            if peek.schemaVersion > LinkDatabase.currentSchemaVersion {
                throw LinkStoreError.unsupportedFutureSchema(peek.schemaVersion)
            }
            if peek.schemaVersion == LinkDatabase.currentSchemaVersion {
                return try decoder.decode(LinkDatabase.self, from: data)
            }
        }
        throw LinkStoreError.unreadable
    }
}

final class LinkStore {
    typealias MetadataWriter = (Data, URL) throws -> Void
    typealias ItemMover = (URL, URL) throws -> Void

    let root: URL
    let metadataURL: URL
    private let fileManager: FileManager
    private let writePrimaryMetadata: MetadataWriter
    private let moveItem: ItemMover
    private(set) var lastLoadOutcome: LinkLoadOutcome = .missing
    private(set) var isWritable = true

    init(
        root: URL,
        fileManager: FileManager = .default,
        writePrimaryMetadata: MetadataWriter? = nil,
        moveItem: ItemMover? = nil
    ) {
        self.root = root
        self.metadataURL = root.appendingPathComponent("links.json")
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

    func load() -> [LinkRecord] {
        guard isWritable || lastLoadOutcome != .unavailable else { return [] }
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            lastLoadOutcome = .missing
            isWritable = true
            return []
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            let database = try LinkCodec.decode(from: data)
            lastLoadOutcome = .loaded
            isWritable = true
            return database.items
        } catch LinkStoreError.unsupportedFutureSchema(let version) {
            lastLoadOutcome = .unsupportedFutureSchema(version)
            isWritable = false
            NSLog(
                "Glance links: links.json uses schema %d; this app supports schema %d. Leaving the file untouched.",
                version,
                LinkDatabase.currentSchemaVersion
            )
            return []
        } catch {
            if quarantineCorruptMetadata() {
                lastLoadOutcome = .recoveredFromCorruption
                isWritable = true
            } else {
                lastLoadOutcome = .corruptUnquarantined
                isWritable = false
                NSLog("Glance links: corrupt links.json could not be quarantined; leaving the file untouched")
            }
            return []
        }
    }

    func save(_ records: [LinkRecord]) throws {
        guard isWritable else { throw LinkStoreError.notWritable }
        let database = LinkDatabase(items: records)
        let data = try LinkCodec.makeEncoder().encode(database)
        do {
            try writePrimaryMetadata(data, metadataURL)
        } catch {
            throw LinkStoreError.writeFailed
        }
    }

    private func quarantineCorruptMetadata() -> Bool {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = root.appendingPathComponent("links.corrupted-\(stamp).json")
        let relocated = MetadataQuarantine.relocate(
            from: metadataURL,
            to: destination,
            moveItem: moveItem,
            fileExists: { fileManager.fileExists(atPath: $0.path) }
        )
        if relocated {
            NSLog("Glance links: quarantined corrupt links.json as %@", destination.lastPathComponent)
        } else {
            NSLog("Glance links: failed to quarantine corrupt links.json")
        }
        return relocated
    }
}
