import AppKit
import UniformTypeIdentifiers

struct MacFileReferenceAdapter: FileShelfBookmarking {
    static let shared = MacFileReferenceAdapter()

    /// Tries a security-scoped bookmark first so a future sandbox can reuse the same sidecar.
    /// Non-sandboxed Glance falls back to a regular bookmark if that option is unavailable.
    func createBookmark(forFileAtPath path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    func resolveBookmark(_ data: Data) -> FileShelfResolvedReference {
        if let resolved = resolve(data, options: [.withSecurityScope, .withoutUI]) {
            return resolved
        }
        if let resolved = resolve(data, options: [.withoutUI]) {
            return resolved
        }
        return .missing
    }

    func icon(for path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    func genericIcon() -> NSImage {
        NSWorkspace.shared.icon(for: .data)
    }

    private func resolve(
        _ data: Data,
        options: URL.BookmarkResolutionOptions
    ) -> FileShelfResolvedReference? {
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            let path = FileShelfIdentity.standardizedPath(for: url)
            var refresh: Data?
            if stale {
                refresh = try? createBookmark(forFileAtPath: path)
            }
            return FileShelfResolvedReference(
                urlPath: path,
                isMissing: false,
                isStale: stale,
                bookmarkDataToRefresh: refresh
            )
        } catch {
            return nil
        }
    }
}

final class FileAccessToken {
    private let url: URL
    private var didStart: Bool

    init(path: String) {
        self.url = URL(fileURLWithPath: path)
        self.didStart = url.startAccessingSecurityScopedResource()
    }

    func end() {
        guard didStart else { return }
        url.stopAccessingSecurityScopedResource()
        didStart = false
    }

    deinit {
        end()
    }
}
