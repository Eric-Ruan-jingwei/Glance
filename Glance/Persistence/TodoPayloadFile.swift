import Foundation

enum TodoPayloadFile {
    static let fileName = "todo.json"

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

    /// `nil` means the file is absent (empty new panel). Existing unreadable files throw.
    static func readDocument(from directory: URL) throws -> TodoDocument? {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            let document = try makeDecoder().decode(TodoDocument.self, from: data)
            guard document.version == TodoDocument.currentVersion else {
                throw PayloadLoadError.unreadable(url)
            }
            return document
        } catch {
            throw PayloadLoadError.unreadable(url)
        }
    }

    static func writeDocument(_ document: TodoDocument, to directory: URL) throws {
        let url = directory.appendingPathComponent(fileName)
        do {
            let data = try makeEncoder().encode(document)
            try data.write(to: url, options: .atomic)
        } catch {
            throw PayloadStoreError.writeFailed(url, error)
        }
    }
}
