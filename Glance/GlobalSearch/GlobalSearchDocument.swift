import Foundation

enum GlobalSearchSource: String, CaseIterable, Sendable {
    case clipboard
    case fileShelf
    case snippets
    case links
    case panels

    var displayName: String {
        switch self {
        case .clipboard: return "剪贴板"
        case .fileShelf: return "文件架"
        case .snippets: return "片段库"
        case .links: return "链接库"
        case .panels: return "面板"
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: return "list.clipboard"
        case .fileShelf: return "tray"
        case .snippets: return "text.quote"
        case .links: return "link"
        case .panels: return "pin"
        }
    }

    var stableSortOrder: Int {
        switch self {
        case .clipboard: return 0
        case .fileShelf: return 1
        case .snippets: return 2
        case .links: return 3
        case .panels: return 4
        }
    }
}

struct GlobalSearchResultID: Hashable, Sendable {
    var source: GlobalSearchSource
    var itemID: UUID
}

struct GlobalSearchDocument: Identifiable, Equatable, Sendable {
    var id: GlobalSearchResultID
    var source: GlobalSearchSource
    var title: String
    var subtitle: String?
    var preview: String?
    var searchableTitle: String
    var searchableFields: [String]
    var activityAt: Date
    var isUnavailable: Bool
    var rowSymbol: String
    var workspaceID: String?
    var foldedTitle: String
    var foldedFields: [String]

    init(
        id: GlobalSearchResultID,
        source: GlobalSearchSource,
        title: String,
        subtitle: String? = nil,
        preview: String? = nil,
        searchableTitle: String,
        searchableFields: [String],
        activityAt: Date,
        isUnavailable: Bool = false,
        rowSymbol: String? = nil,
        workspaceID: String? = nil
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.subtitle = subtitle
        self.preview = preview
        self.searchableTitle = searchableTitle
        self.searchableFields = searchableFields
        self.activityAt = activityAt
        self.isUnavailable = isUnavailable
        self.rowSymbol = rowSymbol ?? source.symbol
        self.workspaceID = workspaceID
        self.foldedTitle = GlobalSearchText.folded(searchableTitle)
        self.foldedFields = searchableFields.map(GlobalSearchText.folded)
    }
}

enum GlobalSearchPolicy {
    static let maximumRecentResults = 20
    static let maximumSearchResults = 50
    static let maximumPreviewLength = 120
    static let maximumTitleLength = 80
}

enum GlobalSearchCopy {
    static let windowTitle = "搜索 Glance"
    static let searchPrompt = "搜索 Glance…"
    static let recentSection = "最近使用"
    static let resultsSection = "搜索结果"
    static let emptySearch = "没有找到匹配的内容"
    static let emptyRecent = "还没有可搜索的内容"
    static let loadingPanels = "正在载入面板…"
    static let partialUnavailable = "部分 Glance 内容暂不可搜索"
    static let selectHint = "↑↓ 选择"
    static let actHint = "↩ 执行"
    static let closeHint = "Esc 关闭"
    static let fileMissing = "文件已移动或不存在"
    static let fileMissingRow = "⚠ 文件已移动或不存在"
    static let globallyHidden = "面板当前已全局隐藏"
    static let clipboardMissing = "无法恢复剪贴板内容"
    static let snippetMissing = "该片段已不存在"
    static let linkFailed = "无法打开链接"
    static let panelMissing = "无法打开面板"
    static let clipboardImageTitle = "剪贴板图片"
    static let clipboardImageAlias = "图片"
}

enum GlobalSearchPreview {
    static func display(_ text: String?, limit: Int = GlobalSearchPolicy.maximumPreviewLength) -> String? {
        guard let text else { return nil }
        var collapsed = text.replacingOccurrences(of: "\n", with: " ")
        while collapsed.contains("  ") {
            collapsed = collapsed.replacingOccurrences(of: "  ", with: " ")
        }
        collapsed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        if collapsed.count <= limit { return collapsed }
        return String(collapsed.prefix(limit))
    }
}

enum GlobalSearchText {
    static func firstNonEmptyLine(_ text: String, limit: Int = GlobalSearchPolicy.maximumTitleLength) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return truncated(trimmed, limit: limit)
            }
        }
        return nil
    }

    static func truncated(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit))
    }

    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

enum GlobalSearchMatchScore {
    static let titleExact = 400
    static let titlePrefix = 300
    static let titleSubstring = 200
    static let secondarySubstring = 100
}

enum GlobalSearchRanker {
    static func score(document: GlobalSearchDocument, query: String) -> Int? {
        let needle = GlobalSearchText.folded(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return nil }
        let title = document.foldedTitle
        if title == needle { return GlobalSearchMatchScore.titleExact }
        if title.hasPrefix(needle) { return GlobalSearchMatchScore.titlePrefix }
        if title.contains(needle) { return GlobalSearchMatchScore.titleSubstring }
        let secondary = document.foldedFields.contains { $0.contains(needle) }
        return secondary ? GlobalSearchMatchScore.secondarySubstring : nil
    }
}

enum GlobalSearchEngine {
    static func results(
        documents: [GlobalSearchDocument],
        query: String
    ) -> [GlobalSearchDocument] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(
                documents
                    .sorted(by: recentOrder)
                    .prefix(GlobalSearchPolicy.maximumRecentResults)
            )
        }
        let ranked = documents.compactMap { document -> (GlobalSearchDocument, Int)? in
            guard let score = GlobalSearchRanker.score(document: document, query: trimmed) else {
                return nil
            }
            return (document, score)
        }
        let sorted = ranked.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return searchTieBreak(lhs.0, rhs.0)
        }
        return Array(sorted.map(\.0).prefix(GlobalSearchPolicy.maximumSearchResults))
    }

    private static func recentOrder(_ lhs: GlobalSearchDocument, _ rhs: GlobalSearchDocument) -> Bool {
        if lhs.activityAt != rhs.activityAt {
            return lhs.activityAt > rhs.activityAt
        }
        return searchTieBreak(lhs, rhs)
    }

    private static func searchTieBreak(_ lhs: GlobalSearchDocument, _ rhs: GlobalSearchDocument) -> Bool {
        if lhs.activityAt != rhs.activityAt {
            return lhs.activityAt > rhs.activityAt
        }
        if lhs.source.stableSortOrder != rhs.source.stableSortOrder {
            return lhs.source.stableSortOrder < rhs.source.stableSortOrder
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}

enum GlobalSearchKeyboardAction: Equatable {
    case moveSelection(Int)
    case activate
    case dismiss
}

enum GlobalSearchActionPolicy {
    static func action(keyCode: UInt16) -> GlobalSearchKeyboardAction? {
        switch keyCode {
        case 125: return .moveSelection(1)
        case 126: return .moveSelection(-1)
        case 36, 76: return .activate
        case 53: return .dismiss
        default: return nil
        }
    }
}
