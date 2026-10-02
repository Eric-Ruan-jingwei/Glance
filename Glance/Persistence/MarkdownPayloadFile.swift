import Foundation

enum MarkdownPayloadFile {
    static let fileName = "content.md"

    /// `nil` means the file is absent (empty new panel). Existing non-UTF-8 files throw.
    static func readSource(from directory: URL) throws -> String? {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard let source = String(data: data, encoding: .utf8) else {
            throw PayloadLoadError.unreadable(url)
        }
        return source
    }

    static func writeSource(_ source: String, to directory: URL) throws {
        let url = directory.appendingPathComponent(fileName)
        let data = Data(source.utf8)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PayloadStoreError.writeFailed(url, error)
        }
    }
}
