import AppKit
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
        try PDFDocumentInspector.inspect(url)
    }
}
