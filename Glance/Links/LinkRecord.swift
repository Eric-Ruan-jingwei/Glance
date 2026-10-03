import Foundation

struct LinkRecord: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var urlString: String
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date
    var isPinned: Bool
}

struct LinkDatabase: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var items: [LinkRecord]

    static let currentSchemaVersion = 1

    init(
        schemaVersion: Int = currentSchemaVersion,
        items: [LinkRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

struct LinkDraft: Equatable, Sendable {
    var title: String
    var urlString: String

    static let empty = LinkDraft(title: "", urlString: "")
}

enum LinkPolicy {
    static let maximumTitleLength = 80
}

enum LinkValidationError: Equatable {
    case emptyURL
    case unsupportedScheme
    case invalidURL

    var message: String {
        switch self {
        case .emptyURL:
            return LinkCopy.emptyURL
        case .unsupportedScheme:
            return LinkCopy.unsupportedScheme
        case .invalidURL:
            return LinkCopy.invalidURL
        }
    }
}

enum LinkValidation {
    static func validate(_ urlString: String) -> LinkValidationError? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .emptyURL }
        if let normalized = WebLinkPolicy.normalizedURLString(urlString) {
            _ = normalized
            return nil
        }
        if let components = URLComponents(string: trimmed),
           let scheme = components.scheme,
           !scheme.isEmpty,
           scheme.lowercased() != "http",
           scheme.lowercased() != "https" {
            return .unsupportedScheme
        }
        return .invalidURL
    }
}

enum LinkTitleGenerator {
    static func makeTitle(from urlString: String, suggested: String? = nil) -> String {
        let suggestion = suggested?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !suggestion.isEmpty {
            return truncate(suggestion)
        }
        return titleFromURL(urlString)
    }

    static func resolvedTitle(draftTitle: String, urlString: String, suggested: String? = nil) -> String {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return truncate(trimmed)
        }
        return makeTitle(from: urlString, suggested: suggested)
    }

    static func titleFromURL(_ urlString: String) -> String {
        guard let components = URLComponents(string: urlString) ?? URLComponents(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              var host = components.host, !host.isEmpty else {
            return "未命名链接"
        }
        if host.lowercased().hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        let last = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .last
            .map(String.init) ?? ""
        let decoded = last.removingPercentEncoding ?? last
        if !decoded.isEmpty {
            return truncate("\(host) — \(decoded)")
        }
        return truncate(host)
    }

    static func truncate(_ text: String, limit: Int = LinkPolicy.maximumTitleLength) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit))
    }
}

enum LinkSearch {
    static func matches(_ record: LinkRecord, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        return [record.title, record.urlString].contains { haystack in
            haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

enum LinkSort {
    static func displayed(_ records: [LinkRecord], query: String) -> [LinkRecord] {
        records
            .filter { LinkSearch.matches($0, query: query) }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                if lhs.lastOpenedAt != rhs.lastOpenedAt {
                    return lhs.lastOpenedAt > rhs.lastOpenedAt
                }
                return lhs.createdAt > rhs.createdAt
            }
    }
}

enum LinkPreview {
    static func line(from urlString: String, limit: Int = 72) -> String {
        guard let components = URLComponents(string: urlString), let host = components.host else {
            return truncate(urlString, limit: limit)
        }
        var text = host
        if !components.path.isEmpty, components.path != "/" {
            text += components.path
        }
        if let query = components.query, !query.isEmpty {
            text += "?" + query
        }
        return truncate(text, limit: limit)
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }
}

struct LinkDropCandidate: Equatable {
    var urlString: String
    var suggestedTitle: String?
}

struct LinkDropItem: Equatable {
    var urlStrings: [String]
    var urlName: String?
    var plainTexts: [String]

    init(urlStrings: [String] = [], urlName: String? = nil, plainTexts: [String] = []) {
        self.urlStrings = urlStrings
        self.urlName = urlName
        self.plainTexts = plainTexts
    }
}

enum LinkDropParser {
    static func parse(_ items: [LinkDropItem]) -> (accepted: [LinkDropCandidate], rejected: Int) {
        var accepted: [LinkDropCandidate] = []
        var rejected = 0
        for item in items {
            if let candidate = parse(item) {
                accepted.append(candidate)
            } else if hasPayload(item) {
                rejected += 1
            }
        }
        return (accepted, rejected)
    }

    static func parse(
        urlStrings: [String],
        urlNames: [String] = [],
        plainTexts: [String] = []
    ) -> (accepted: [LinkDropCandidate], rejected: Int) {
        if urlStrings.isEmpty, urlNames.isEmpty {
            return parse(plainTexts.map { LinkDropItem(plainTexts: [$0]) })
        }
        if urlStrings.count <= 1 {
            return parse([
                LinkDropItem(
                    urlStrings: urlStrings,
                    urlName: urlNames.first,
                    plainTexts: plainTexts
                )
            ])
        }
        let named = zip(urlStrings, urlNames + Array(repeating: "", count: max(0, urlStrings.count - urlNames.count)))
            .map { LinkDropItem(urlStrings: [$0.0], urlName: $0.1.isEmpty ? nil : $0.1) }
        let extras = plainTexts.map { LinkDropItem(plainTexts: [$0]) }
        return parse(named + extras)
    }

    private static func parse(_ item: LinkDropItem) -> LinkDropCandidate? {
        for raw in item.urlStrings {
            if let url = WebLinkPolicy.normalizedURLString(raw) {
                return LinkDropCandidate(urlString: url, suggestedTitle: trimmedName(item.urlName))
            }
        }
        for text in item.plainTexts {
            if let url = WebLinkPolicy.normalizedURLString(text) {
                return LinkDropCandidate(urlString: url, suggestedTitle: trimmedName(item.urlName))
            }
        }
        return nil
    }

    private static func hasPayload(_ item: LinkDropItem) -> Bool {
        item.urlStrings.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || item.plainTexts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func trimmedName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum LinkDragPayload {
    static func urlString(from stored: String) -> String? {
        WebLinkPolicy.normalizedURLString(stored)
    }
}

struct LinkOpenRequest: Equatable {
    var id: UUID
    var urlString: String
}

enum LinkOpenPolicy {
    static func request(for record: LinkRecord) -> LinkOpenRequest? {
        guard let url = WebLinkPolicy.normalizedURLString(record.urlString) else { return nil }
        return LinkOpenRequest(id: record.id, urlString: url)
    }
}

protocol LinkOpening {
    func open(_ urlString: String) -> Bool
}

enum LinkKeyboardAction: Equatable {
    case moveSelection(Int)
    case open
    case edit
    case create
    case copy
    case delete
    case dismiss
}

enum LinkActionPolicy {
    static func action(
        keyCode: UInt16,
        characters: String?,
        command: Bool
    ) -> LinkKeyboardAction? {
        let chars = characters?.lowercased()
        if command, chars == "n" { return .create }
        if command, chars == "c" || keyCode == 8 { return .copy }
        switch keyCode {
        case 125: return .moveSelection(1)
        case 126: return .moveSelection(-1)
        case 36, 76: return command ? .edit : .open
        case 51, 117: return .delete
        case 53: return .dismiss
        default: return nil
        }
    }
}

enum LinkCopy {
    static let windowTitle = "链接库"
    static let searchPrompt = "搜索链接…"
    static let addLabel = "新建链接"
    static let emptyTitle = "还没有链接"
    static let emptyDetail = "把经常访问的网页和在线资源保存到这里，以后可以快速搜索并打开。"
    static let emptySearch = "没有找到匹配的链接"
    static let futureSchema = "此版本无法读取链接库数据"
    static let openHint = "↩ 打开"
    static let editHint = "⌘↩ 编辑"
    static let createHint = "⌘N 新建"
    static let closeHint = "Esc 关闭"
    static let openLabel = "打开"
    static let copyLabel = "复制链接"
    static let editLabel = "编辑…"
    static let createPanelLabel = "创建面板"
    static let pinLabel = "置顶"
    static let unpinLabel = "取消置顶"
    static let deleteLabel = "删除…"
    static let deleteButton = "删除链接"
    static let cancelLabel = "取消"
    static let saveLabel = "保存"
    static let titleLabel = "标题"
    static let urlLabel = "链接"
    static let emptyURL = "链接不能为空"
    static let unsupportedScheme = "只支持 HTTP / HTTPS 链接"
    static let invalidURL = "链接格式无效"
    static let saveAsLink = "保存为链接…"
    static let partialRejected = "部分链接未加入"

    static func deleteTitle(_ name: String) -> String {
        "删除“\(name)”？"
    }

    static let deleteBody = "此操作无法撤销。"
}

enum LinkLoadOutcome: Equatable {
    case missing
    case loaded
    case recoveredFromCorruption
    case unsupportedFutureSchema(Int)
    case unavailable
}

enum LinkCommitError: Equatable, Error {
    case emptyURL
    case unsupportedScheme
    case invalidURL
    case notWritable
    case writeFailed
    case missing

    var message: String {
        switch self {
        case .emptyURL:
            return LinkCopy.emptyURL
        case .unsupportedScheme:
            return LinkCopy.unsupportedScheme
        case .invalidURL:
            return LinkCopy.invalidURL
        case .notWritable, .writeFailed, .missing:
            return "无法保存链接"
        }
    }

    static func from(_ error: LinkValidationError) -> LinkCommitError {
        switch error {
        case .emptyURL: return .emptyURL
        case .unsupportedScheme: return .unsupportedScheme
        case .invalidURL: return .invalidURL
        }
    }
}
