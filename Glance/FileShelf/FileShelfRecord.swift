import Foundation

struct FileShelfRecord: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var originalPath: String
    var displayName: String
    var fileSize: Int64?
    var contentTypeIdentifier: String?
    var createdAt: Date
    var lastUsedAt: Date
    var isFavorite: Bool
    var favoritedAt: Date?
}

struct FileShelfDatabase: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var items: [FileShelfRecord]

    static let currentSchemaVersion = 1

    init(
        schemaVersion: Int = currentSchemaVersion,
        items: [FileShelfRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

enum FileShelfPolicy {
    static let maximumRecentNonFavorites = 100
}

enum FileShelfIdentity {
    static func standardizedPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}

enum FileShelfFileClassification: Equatable {
    case file
    case directory
    case missing
}

enum FileShelfClassifier {
    static func classify(_ url: URL, fileManager: FileManager = .default) -> FileShelfFileClassification {
        let resolved = url.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else {
            return .missing
        }
        return isDirectory.boolValue ? .directory : .file
    }
}

enum FileShelfSearch {
    static func matches(_ record: FileShelfRecord, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        let haystacks = [
            record.displayName,
            (record.originalPath as NSString).lastPathComponent,
            (record.displayName as NSString).pathExtension,
            (record.originalPath as NSString).pathExtension
        ]
        return haystacks.contains { candidate in
            candidate.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    static func recent(_ records: [FileShelfRecord], query: String) -> [FileShelfRecord] {
        records
            .sorted { $0.lastUsedAt > $1.lastUsedAt }
            .filter { matches($0, query: query) }
    }

    static func favorites(_ records: [FileShelfRecord], query: String) -> [FileShelfRecord] {
        records
            .filter(\.isFavorite)
            .sorted { ($0.favoritedAt ?? .distantPast) > ($1.favoritedAt ?? .distantPast) }
            .filter { matches($0, query: query) }
    }
}

enum FileShelfRetention {
    static func idsToEvict(
        from records: [FileShelfRecord],
        limit: Int = FileShelfPolicy.maximumRecentNonFavorites
    ) -> [UUID] {
        let nonFavorites = records
            .filter { !$0.isFavorite }
            .sorted { lhs, rhs in
                if lhs.lastUsedAt != rhs.lastUsedAt {
                    return lhs.lastUsedAt < rhs.lastUsedAt
                }
                return lhs.createdAt < rhs.createdAt
            }
        let overflow = nonFavorites.count - limit
        guard overflow > 0 else { return [] }
        return Array(nonFavorites.prefix(overflow).map(\.id))
    }
}

enum FileShelfTypeLabel {
    static func display(name: String, typeIdentifier: String?) -> String {
        let ext = (name as NSString).pathExtension
        if !ext.isEmpty { return ext.uppercased() }
        if let typeIdentifier, let last = typeIdentifier.split(separator: ".").last, !last.isEmpty {
            return String(last).uppercased()
        }
        return "FILE"
    }
}

enum FileShelfDropParser {
    static func urls(from fileURLStrings: [String]) -> [URL] {
        fileURLStrings.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if let url = URL(string: trimmed), url.isFileURL {
                return url
            }
            if trimmed.hasPrefix("/") {
                return URL(fileURLWithPath: trimmed)
            }
            return nil
        }
    }
}

enum FileShelfDragPayload {
    static func fileURL(resolvedPath: String?, fileExists: Bool) -> String? {
        guard let resolvedPath, fileExists else { return nil }
        return resolvedPath
    }
}

enum FileShelfCopy {
    static let windowTitle = "文件架"
    static let searchPrompt = "搜索文件…"
    static let recentTab = "最近"
    static let favoriteTab = "收藏"
    static let addLabel = "添加文件"
    static let emptyTitle = "还没有文件"
    static let emptyDetail = "从 Finder 拖入文件，或点击右上角添加。文件仍留在原来的位置。"
    static let emptyFavoritesTitle = "还没有收藏"
    static let emptyFavoritesDetail = "把常用文件标记为 ★，之后可以随时打开或拖出。"
    static let emptySearch = "没有找到匹配的文件"
    static let futureSchema = "此版本无法读取文件架数据"
    static let unreadable = "文件架数据无法读取，已保留原文件"
    static let missing = "文件已移动或不存在"
    static let openHint = "↩ 打开"
    static let revealHint = "⌘↩ Finder"
    static let previewHint = "Space 预览"
    static let closeHint = "Esc 关闭"
    static let favoriteLabel = "收藏"
    static let unfavoriteLabel = "取消收藏"
    static let removeLabel = "从文件架移除"
    static let relinkLabel = "重新定位…"
    static let openLabel = "打开"
    static let revealLabel = "在 Finder 中显示"
    static let previewLabel = "快速预览"
    static let copyFileLabel = "复制文件"
    static let copyPathLabel = "复制路径"
    static let createImagePanelLabel = "创建图片面板"
    static let createPDFPanelLabel = "创建 PDF 面板"
    static let partialRejected = "部分项目未加入"
    static let removeFavoriteTitle = "从文件架移除？"
    static let removeFavoriteBody = "这只会移除文件架中的记录，不会删除原文件。"
}

enum FileShelfLoadOutcome: Equatable {
    case missing
    case loaded
    case recoveredFromCorruption
    case corruptUnquarantined
    case unsupportedFutureSchema(Int)
    case unavailable
}

struct FileShelfResolvedReference: Equatable {
    var urlPath: String?
    var isMissing: Bool
    var isStale: Bool
    var bookmarkDataToRefresh: Data?

    static let missing = FileShelfResolvedReference(
        urlPath: nil,
        isMissing: true,
        isStale: false,
        bookmarkDataToRefresh: nil
    )
}

struct FileShelfAddResult: Equatable {
    var addedIDs: [UUID] = []
    var updatedIDs: [UUID] = []
    var rejectedDirectories: Int = 0
    var failed: Int = 0

    var notice: String? {
        rejectedDirectories > 0 ? FileShelfCopy.partialRejected : nil
    }
}

protocol FileShelfBookmarking {
    func createBookmark(forFileAtPath path: String) throws -> Data
    func resolveBookmark(_ data: Data) -> FileShelfResolvedReference
}

enum FileShelfMetadataSnapshot {
    static func capture(
        path: String,
        fileManager: FileManager = .default
    ) -> (displayName: String, fileSize: Int64?, contentTypeIdentifier: String?) {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        let size = (try? fileManager.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
        return (name, size, url.pathExtension.isEmpty ? nil : url.pathExtension.lowercased())
    }
}

enum FileShelfKeyboardAction: Equatable {
    case moveSelection(Int)
    case open
    case reveal
    case preview
    case copyFile
    case remove
    case dismiss
    case recentTab
    case favoritesTab
}

enum FileShelfActionPolicy {
    static func action(
        keyCode: UInt16,
        characters: String?,
        command: Bool
    ) -> FileShelfKeyboardAction? {
        let chars = characters?.lowercased()
        if command {
            if chars == "1" { return .recentTab }
            if chars == "2" { return .favoritesTab }
            if chars == "c" || keyCode == 8 { return .copyFile }
        }
        switch keyCode {
        case 125: return .moveSelection(1)
        case 126: return .moveSelection(-1)
        case 36, 76: return command ? .reveal : .open
        case 49: return .preview
        case 51, 117: return .remove
        case 53: return .dismiss
        default: return nil
        }
    }

    static func allowsFileAction(missing: Bool) -> Bool {
        !missing
    }
}
