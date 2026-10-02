import AppKit
import UniformTypeIdentifiers

final class MediaStore {
    func writePNG(_ image: NSImage, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("image.png")
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw MediaStoreError.writeFailed
        }
        try png.write(to: url, options: .atomic)
        return url
    }

    func loadImage(from directory: URL) -> NSImage? {
        let url = directory.appendingPathComponent("image.png")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    func imageFromPasteboard(_ pasteboard: NSPasteboard = .general) -> NSImage? {
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            return image
        }
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            return NSImage(data: data)
        }
        return nil
    }

    func image(fromFileURL url: URL) -> NSImage? {
        NSImage(contentsOf: url)
    }

    func fittingSize(for image: NSImage, maxEdge: CGFloat = GlanceConstants.imageMaxEdge) -> NSSize {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return NSSize(width: maxEdge, height: maxEdge)
        }
        let scale = maxEdge / max(size.width, size.height)
        return NSSize(
            width: max(GlanceConstants.imageMinSize.width, (size.width * scale).rounded()),
            height: max(GlanceConstants.imageMinSize.height, (size.height * scale).rounded())
        )
    }

    func chooseImageFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.title = "选择图片"
        panel.prompt = "导入"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

enum MediaStoreError: LocalizedError {
    case writeFailed

    var errorDescription: String? {
        "无法将图片写入本地数据目录。"
    }
}

enum TextPayloadError: LocalizedError {
    case rtfEncodingFailed

    var errorDescription: String? {
        "无法将文字面板编码为 RTF。"
    }
}
