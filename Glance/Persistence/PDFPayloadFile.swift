import Foundation

enum PDFPayloadFile {
    static let documentFileName = "document.pdf"
    static let metadataFileName = "pdf.json"

    static func documentURL(in directory: URL) -> URL {
        directory.appendingPathComponent(documentFileName)
    }

    static func metadataURL(in directory: URL) -> URL {
        directory.appendingPathComponent(metadataFileName)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    static func documentExists(in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: documentURL(in: directory).path)
    }

    /// `nil` means `pdf.json` is absent. Existing unreadable or unsupported files throw.
    static func readMetadata(from directory: URL) throws -> PDFDocumentMetadata? {
        let url = metadataURL(in: directory)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            let metadata = try makeDecoder().decode(PDFDocumentMetadata.self, from: data)
            guard metadata.version == PDFDocumentMetadata.currentVersion else {
                throw PayloadLoadError.unreadable(url)
            }
            return metadata
        } catch {
            throw PayloadLoadError.unreadable(url)
        }
    }

    static func writeMetadata(_ metadata: PDFDocumentMetadata, to directory: URL) throws {
        guard metadata.version == PDFDocumentMetadata.currentVersion else {
            throw PDFImportError.invalidMetadata
        }
        let url = metadataURL(in: directory)
        do {
            let data = try makeEncoder().encode(metadata)
            try data.write(to: url, options: .atomic)
        } catch {
            throw PDFImportError.invalidMetadata
        }
    }

    static func copyDocument(from source: URL, to directory: URL) throws {
        let destination = documentURL(in: directory)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw PDFImportError.copyFailed
        }
    }

    static func importDocument(
        from source: URL,
        metadata: PDFDocumentMetadata,
        to directory: URL
    ) throws {
        try copyDocument(from: source, to: directory)
        try writeMetadata(metadata, to: directory)
    }
}
