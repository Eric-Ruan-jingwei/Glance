import Foundation

struct PDFDocumentMetadata: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var displayName: String
    var pageCount: Int
}
