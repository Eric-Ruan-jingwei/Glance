import Foundation

@MainActor
final class PanelRepository {
    private var records: [UUID: PanelRecord] = [:]
    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        try load()
    }

    func all() throws -> [PanelRecord] {
        records.values.sorted { $0.createdAt < $1.createdAt }
    }

    func record(id: UUID) throws -> PanelRecord? {
        records[id]
    }

    func insert(_ record: PanelRecord) throws {
        records[record.id] = record
        try save()
    }

    func delete(id: UUID) throws {
        records[id] = nil
        try save()
    }

    func save() throws {
        let payload = records.values.sorted { $0.createdAt < $1.createdAt }
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }

    func touch(_ record: PanelRecord) {
        record.updatedAt = Date()
    }

    private func load() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        let items = try decoder.decode([PanelRecord].self, from: data)
        records = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }
}
