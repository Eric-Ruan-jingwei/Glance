import AppKit
import ImageIO

final class ClipboardThumbnailLoader {
    private var cache: [UUID: NSImage] = [:]
    private let maxPixel: CGFloat

    init(maxPixel: CGFloat = 56) {
        self.maxPixel = maxPixel
    }

    func thumbnail(for record: ClipboardHistoryRecord, store: ClipboardHistoryStore) -> NSImage? {
        if let cached = cache[record.id] {
            return cached
        }
        guard record.kind == .image, let url = store.assetURL(for: record) else {
            return nil
        }
        let image = makeThumbnail(at: url)
        if let image {
            cache[record.id] = image
        }
        return image
    }

    func evict(_ id: UUID) {
        cache.removeValue(forKey: id)
    }

    func removeAll() {
        cache.removeAll()
    }

    private func makeThumbnail(at url: URL) -> NSImage? {
        let options = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
