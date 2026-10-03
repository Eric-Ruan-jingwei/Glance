import CoreGraphics
import Foundation

enum PDFDocumentInspector {
    static func inspect(_ url: URL) throws -> PDFDocumentMetadata {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw PDFImportError.unreadable
        }
        if document.isEncrypted, !document.isUnlocked {
            throw PDFImportError.passwordProtected
        }
        let pageCount = document.numberOfPages
        guard pageCount > 0 else {
            throw PDFImportError.emptyDocument
        }
        return PDFDocumentMetadata(
            version: PDFDocumentMetadata.currentVersion,
            displayName: url.lastPathComponent,
            pageCount: pageCount
        )
    }
}
