import AppKit

enum ClipboardImageRead: Equatable {
    case png(Data)
    case oversized
    case unavailable
}

/// One-shot pasteboard read. Does not observe changeCount or keep history.
enum MacClipboardReader {
    static let rasterTypes: [NSPasteboard.PasteboardType] = [
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
        if case .png(let data) = readImage(from: pasteboard, maxBytes: nil) {
            return data
        }
        return nil
    }

    /// Walks image representations in priority order.
    /// Oversized raw bytes are skipped without `NSImage` decode.
    /// When `maxBytes` is nil, the first readable representation wins (one-shot capture).
    static func readImage(
        from pasteboard: NSPasteboard,
        maxBytes: Int?
    ) -> ClipboardImageRead {
        var sawOversized = false
        var triedDecodable = false
        for type in rasterTypes {
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
            if let maxBytes, data.count > maxBytes {
                sawOversized = true
                continue
            }
            triedDecodable = true
            guard let png = normalizePNG(data, declaredType: type), !png.isEmpty else {
                continue
            }
            if let maxBytes, png.count > maxBytes {
                sawOversized = true
                continue
            }
            return .png(png)
        }
        if sawOversized && !triedDecodable {
            return .oversized
        }
        return .unavailable
    }

    private static func normalizePNG(_ data: Data, declaredType: NSPasteboard.PasteboardType) -> Data? {
        if declaredType == .png {
            return MediaStore.looksLikePNG(data) ? data : nil
        }
        guard let image = NSImage(data: data) else { return nil }
        return MediaStore.pngData(from: image)
    }
}
