import AppKit
import Quartz

enum MacFileShelfActions {
    @discardableResult
    static func open(path: String) -> Bool {
        withAccess(path) { url in
            NSWorkspace.shared.open(url)
        }
    }

    static func reveal(path: String) {
        withAccess(path) { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return true
        }
    }

    static func copyFile(path: String) {
        withAccess(path) { url in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.writeObjects([url as NSURL])
        }
    }

    static func copyPath(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }

    static func fileURL(from path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    private static func withAccess(_ path: String, _ body: (URL) -> Bool) -> Bool {
        let token = FileAccessToken(path: path)
        defer { token.end() }
        return body(URL(fileURLWithPath: path))
    }
}

final class FileShelfQuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var previewURL: URL?
    private var access: FileAccessToken?

    var isPreviewing: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared()?.isVisible == true
    }

    func show(path: String) {
        close()
        access = FileAccessToken(path: path)
        previewURL = URL(fileURLWithPath: path)
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        if QLPreviewPanel.sharedPreviewPanelExists() {
            QLPreviewPanel.shared()?.orderOut(nil)
        }
        previewURL = nil
        access?.end()
        access = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as QLPreviewItem?
    }
}

enum FileShelfOpenPanel {
    static func chooseFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "添加"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}
