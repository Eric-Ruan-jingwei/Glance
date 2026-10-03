import AppKit
import PDFKit
import UniformTypeIdentifiers

enum MacPDFImporter {
    static func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.pdf]
        panel.title = "选择 PDF"
        panel.prompt = "导入"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func inspect(_ url: URL) throws -> PDFDocumentMetadata {
        guard let document = PDFDocument(url: url) else {
            throw PDFImportError.unreadable
        }
        if document.isLocked {
            throw PDFImportError.passwordProtected
        }
        let pageCount = document.pageCount
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
