import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum GlanceDragType {
    static let identifier = "\(GlanceConstants.bundleIdentifier).item"

    static let utType = UTType(exportedAs: identifier)

    static let pasteboardType = NSPasteboard.PasteboardType(identifier)
}

enum GlanceItemDragSource: String, Equatable {
    case clipboard
    case snippet
    case link
    case fileShelf
}

struct GlanceItemDragPayload: Codable, Equatable, Transferable {
    static let currentVersion = 1

    var version: Int
    var source: String
    var itemID: UUID

    init(sourceID: GlanceActionSourceID) {
        version = Self.currentVersion
        itemID = Self.itemID(from: sourceID)
        source = Self.source(from: sourceID).rawValue
    }

    var sourceID: GlanceActionSourceID? {
        guard version == Self.currentVersion else { return nil }
        guard let kind = GlanceItemDragSource(rawValue: source) else { return nil }
        switch kind {
        case .clipboard: return .clipboard(itemID)
        case .snippet: return .snippet(itemID)
        case .link: return .link(itemID)
        case .fileShelf: return .fileShelf(itemID)
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: GlanceDragType.utType) { payload in
            try GlanceItemDragCodec.encodeThrowing(payload)
        } importing: { data in
            guard let payload = GlanceItemDragCodec.decode(data) else {
                throw CocoaError(.coderInvalidValue)
            }
            return payload
        }
    }

    private static func source(from sourceID: GlanceActionSourceID) -> GlanceItemDragSource {
        switch sourceID {
        case .clipboard: return .clipboard
        case .snippet: return .snippet
        case .link: return .link
        case .fileShelf: return .fileShelf
        }
    }

    private static func itemID(from sourceID: GlanceActionSourceID) -> UUID {
        switch sourceID {
        case .clipboard(let id), .snippet(let id), .link(let id), .fileShelf(let id):
            return id
        }
    }
}

enum GlanceItemDragCodec {
    enum CodecError: Error {
        case encodeFailed
    }

    static func encode(_ payload: GlanceItemDragPayload) -> Data? {
        try? JSONEncoder().encode(payload)
    }

    static func encodeThrowing(_ payload: GlanceItemDragPayload) throws -> Data {
        guard let data = encode(payload) else { throw CodecError.encodeFailed }
        return data
    }

    static func decode(_ data: Data) -> GlanceItemDragPayload? {
        guard let payload = try? JSONDecoder().decode(GlanceItemDragPayload.self, from: data) else {
            return nil
        }
        guard payload.version == GlanceItemDragPayload.currentVersion else { return nil }
        guard payload.sourceID != nil else { return nil }
        return payload
    }

    static func sourceID(from data: Data) -> GlanceActionSourceID? {
        decode(data)?.sourceID
    }

    static func sourceID(from pasteboard: NSPasteboard) -> GlanceActionSourceID? {
        if let data = pasteboard.data(forType: GlanceDragType.pasteboardType) {
            return sourceID(from: data)
        }
        if let string = pasteboard.string(forType: GlanceDragType.pasteboardType),
           let data = string.data(using: .utf8) {
            return sourceID(from: data)
        }
        return nil
    }

    static func sourceIDIfSynchronouslyAvailable(
        pasteboard: NSPasteboard = NSPasteboard(name: .drag)
    ) -> GlanceActionSourceID? {
        sourceID(from: pasteboard)
    }

    static func pasteboardHasInternalItem(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.data(forType: GlanceDragType.pasteboardType) != nil
            || pasteboard.string(forType: GlanceDragType.pasteboardType) != nil
    }

    static func hasInternalPayload(_ providers: [NSItemProvider]) -> Bool {
        providers.contains { $0.hasItemConformingToTypeIdentifier(GlanceDragType.identifier) }
    }

    static func load(
        from providers: [NSItemProvider],
        completion: @escaping (GlanceActionSourceID?) -> Void
    ) {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(GlanceDragType.identifier)
        }) else {
            completion(nil)
            return
        }
        provider.loadDataRepresentation(forTypeIdentifier: GlanceDragType.identifier) { data, _ in
            let sourceID = data.flatMap(self.sourceID(from:))
            DispatchQueue.main.async {
                completion(sourceID)
            }
        }
    }
}

struct GlanceURLDragItem: Transferable {
    var payload: GlanceItemDragPayload
    var url: URL

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: GlanceDragType.utType) { item in
            try GlanceItemDragCodec.encodeThrowing(item.payload)
        }
        ProxyRepresentation(exporting: \.url)
    }
}

struct GlanceTextDragItem: Transferable {
    var payload: GlanceItemDragPayload
    var text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: GlanceDragType.utType) { item in
            try GlanceItemDragCodec.encodeThrowing(item.payload)
        }
        ProxyRepresentation(exporting: \.text)
    }
}

enum GlanceDragOffer {
    static func typeIdentifiers(
        nativeText: String? = nil,
        nativeURL: URL? = nil
    ) -> [String] {
        var identifiers = [GlanceDragType.identifier]
        if nativeText != nil {
            identifiers.append(UTType.utf8PlainText.identifier)
        }
        if let nativeURL {
            identifiers.append(nativeURL.isFileURL ? UTType.fileURL.identifier : UTType.url.identifier)
        }
        return identifiers
    }

    static func itemProvider(
        sourceID: GlanceActionSourceID,
        nativeText: String? = nil,
        nativeURL: URL? = nil
    ) -> NSItemProvider {
        let provider = NSItemProvider()
        if let data = GlanceItemDragCodec.encode(GlanceItemDragPayload(sourceID: sourceID)) {
            provider.registerDataRepresentation(
                forTypeIdentifier: GlanceDragType.identifier,
                visibility: .ownProcess
            ) { completion in
                completion(data, nil)
                return nil
            }
        }
        if let nativeText {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.utf8PlainText.identifier,
                visibility: .all
            ) { completion in
                completion(Data(nativeText.utf8), nil)
                return nil
            }
        }
        if let nativeURL {
            provider.registerObject(nativeURL as NSURL, visibility: .all)
        }
        return provider
    }
}

struct GlanceItemDragModifier: ViewModifier {
    var sourceID: GlanceActionSourceID
    var nativeText: String? = nil
    var nativeURL: URL? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        let payload = GlanceItemDragPayload(sourceID: sourceID)
        if let nativeURL {
            content.draggable(GlanceURLDragItem(payload: payload, url: nativeURL))
        } else if let nativeText {
            content.draggable(GlanceTextDragItem(payload: payload, text: nativeText))
        } else {
            content.draggable(payload)
        }
    }
}
