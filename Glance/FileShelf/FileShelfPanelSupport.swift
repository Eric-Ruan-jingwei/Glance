import Foundation
import UniformTypeIdentifiers

enum FileShelfPanelKind: Equatable {
    case image
    case pdf
}

enum FileShelfPanelSupport {
    static func kind(for record: FileShelfRecord, resolvedURL: URL? = nil) -> FileShelfPanelKind? {
        if let resolvedURL, let type = contentType(of: resolvedURL) {
            if let kind = kind(conforming: type) {
                return kind
            }
        }
        if let identifier = record.contentTypeIdentifier {
            if let type = UTType(identifier), let kind = kind(conforming: type) {
                return kind
            }
            if let type = UTType(filenameExtension: identifier), let kind = kind(conforming: type) {
                return kind
            }
        }
        let nameExtension = (record.displayName as NSString).pathExtension
        if let type = UTType(filenameExtension: nameExtension), let kind = kind(conforming: type) {
            return kind
        }
        let pathExtension = (record.originalPath as NSString).pathExtension
        if let type = UTType(filenameExtension: pathExtension) {
            return kind(conforming: type)
        }
        return nil
    }

    static func isAvailable(for record: FileShelfRecord, missing: Bool, resolvedURL: URL? = nil) -> Bool {
        !missing && kind(for: record, resolvedURL: resolvedURL) != nil
    }

    static func menuTitle(for kind: FileShelfPanelKind) -> String {
        switch kind {
        case .image:
            return FileShelfCopy.createImagePanelLabel
        case .pdf:
            return FileShelfCopy.createPDFPanelLabel
        }
    }

    private static func kind(conforming type: UTType) -> FileShelfPanelKind? {
        if type.conforms(to: .pdf) {
            return .pdf
        }
        if type.conforms(to: .image) {
            return .image
        }
        return nil
    }

    private static func contentType(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
    }
}
