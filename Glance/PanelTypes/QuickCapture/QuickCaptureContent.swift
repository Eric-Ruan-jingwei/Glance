import Foundation

enum QuickCaptureContent: Equatable {
    case empty
    case text(String)
    case url(String)
    case files([URL])
}

enum QuickCaptureClassifier {
    static func classify(text: String, fileURLs: [URL] = []) -> QuickCaptureContent {
        let files = uniquedFileURLs(fileURLs)
        if !files.isEmpty {
            return .files(files)
        }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return .empty
        }
        if let urlString = WebLinkPolicy.normalizedURLString(normalized) {
            return .url(urlString)
        }
        return .text(normalized)
    }

    static func uniquedFileURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            let fileURL: URL
            if url.isFileURL {
                fileURL = url
            } else if url.scheme == nil || url.scheme?.isEmpty == true {
                fileURL = URL(fileURLWithPath: url.path)
            } else {
                continue
            }
            let path = FileShelfIdentity.standardizedPath(for: fileURL)
            guard seen.insert(path).inserted else { continue }
            result.append(URL(fileURLWithPath: path))
        }
        return result
    }
}

enum QuickCapturePasteboardCandidate {
    static func content(
        fileURLs: [URL],
        text: String?,
        skipPrivacy: Bool
    ) -> QuickCaptureContent {
        if skipPrivacy {
            return .empty
        }
        return QuickCaptureClassifier.classify(text: text ?? "", fileURLs: fileURLs)
    }
}

enum QuickCapturePanelFileSupport {
    static func kind(for url: URL) -> FileShelfPanelKind? {
        let record = FileShelfRecord(
            id: UUID(),
            originalPath: url.path,
            displayName: url.lastPathComponent,
            fileSize: nil,
            contentTypeIdentifier: url.pathExtension.lowercased(),
            createdAt: Date(timeIntervalSince1970: 0),
            lastUsedAt: Date(timeIntervalSince1970: 0),
            isFavorite: false,
            favoritedAt: nil
        )
        return FileShelfPanelSupport.kind(for: record, resolvedURL: url)
    }

    static func isSupported(_ url: URL) -> Bool {
        kind(for: url) != nil
    }
}
