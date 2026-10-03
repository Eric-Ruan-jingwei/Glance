import AppKit

/// One-shot pasteboard read. Does not observe changeCount or keep history.
enum MacClipboardReader {
    private static let rasterTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.jpeg-2000"),
        NSPasteboard.PasteboardType("public.heic"),
        NSPasteboard.PasteboardType("com.compuserve.gif"),
        NSPasteboard.PasteboardType("public.webp")
    ]

    static func hasSupportedContent(_ pasteboard: NSPasteboard = .general) -> Bool {
        hasImageType(pasteboard) || hasTextType(pasteboard)
    }

    static func read(_ pasteboard: NSPasteboard = .general) -> ClipboardCaptureContent? {
        if hasImageType(pasteboard),
           let png = pngData(from: pasteboard),
           !png.isEmpty {
            return ClipboardCaptureRouter.content(imagePNG: png, text: nil)
        }
        return ClipboardCaptureRouter.content(
            imagePNG: nil,
            text: pasteboard.string(forType: .string)
        )
    }

    static func hasImageType(_ pasteboard: NSPasteboard) -> Bool {
        let types = pasteboard.types ?? []
        return types.contains(where: { rasterTypes.contains($0) })
    }

    static func hasTextType(_ pasteboard: NSPasteboard) -> Bool {
        (pasteboard.types ?? []).contains(.string)
    }

    static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png), MediaStore.looksLikePNG(png) {
            return png
        }
        for type in rasterTypes where type != .png {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data),
               let png = MediaStore.pngData(from: image) {
                return png
            }
        }
        return nil
    }
}
