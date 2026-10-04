import Foundation

struct SnippetRecord: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date
    var isPinned: Bool
}

struct SnippetDatabase: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var items: [SnippetRecord]

    static let currentSchemaVersion = 1

    init(
        schemaVersion: Int = currentSchemaVersion,
        items: [SnippetRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

struct SnippetDraft: Equatable, Sendable {
    var title: String
    var content: String

    static let empty = SnippetDraft(title: "", content: "")
}

enum SnippetPolicy {
    static let maximumContentBytes = 256 * 1024
    static let maximumTitleLength = 80
    static let maximumGeneratedTitleLength = 48
    static let untitledFallback = "未命名片段"
}

enum SnippetValidationError: Equatable {
    case emptyContent
    case contentTooLarge

    var message: String {
        switch self {
        case .emptyContent:
            return SnippetCopy.emptyContent
        case .contentTooLarge:
            return SnippetCopy.contentTooLarge
        }
    }
}

enum SnippetValidation {
    static func validate(content: String) -> SnippetValidationError? {
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyContent
        }
        if content.utf8.count > SnippetPolicy.maximumContentBytes {
            return .contentTooLarge
        }
        return nil
    }
}

enum SnippetTitleGenerator {
    static func makeTitle(from content: String) -> String {
        let line = content
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let line else { return SnippetPolicy.untitledFallback }
        return truncate(line, limit: SnippetPolicy.maximumGeneratedTitleLength)
    }

    static func resolvedTitle(draftTitle: String, content: String) -> String {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return makeTitle(from: content)
        }
        return truncate(trimmed, limit: SnippetPolicy.maximumTitleLength)
    }

    static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit))
    }
}

enum SnippetSearch {
    static func matches(_ record: SnippetRecord, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        return [record.title, record.content].contains { haystack in
            haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

enum SnippetSort {
    static func displayed(_ records: [SnippetRecord], query: String) -> [SnippetRecord] {
        records
            .filter { SnippetSearch.matches($0, query: query) }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                if lhs.lastUsedAt != rhs.lastUsedAt {
                    return lhs.lastUsedAt > rhs.lastUsedAt
                }
                return lhs.createdAt > rhs.createdAt
            }
    }
}

enum SnippetPreview {
    static func line(from content: String, limit: Int = 72) -> String {
        let line = content
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        let text = line ?? content
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }
}

enum SnippetKeyboardAction: Equatable {
    case moveSelection(Int)
    case copy
    case edit
    case create
    case delete
    case dismiss
}

enum SnippetActionPolicy {
    static func action(
        keyCode: UInt16,
        characters: String?,
        command: Bool
    ) -> SnippetKeyboardAction? {
        let chars = characters?.lowercased()
        if command, chars == "n" { return .create }
        switch keyCode {
        case 125: return .moveSelection(1)
        case 126: return .moveSelection(-1)
        case 36, 76: return command ? .edit : .copy
        case 51, 117: return .delete
        case 53: return .dismiss
        default: return nil
        }
    }
}

enum ClipboardSnippetHandoff {
    static func isAvailable(for record: ClipboardHistoryRecord) -> Bool {
        record.kind == .text && record.text != nil
    }

    static func draft(from record: ClipboardHistoryRecord) -> SnippetDraft? {
        guard isAvailable(for: record), let text = record.text else { return nil }
        return SnippetDraft(
            title: SnippetTitleGenerator.makeTitle(from: text),
            content: text
        )
    }
}

enum SnippetCopy {
    static let windowTitle = "片段库"
    static let searchPrompt = "搜索片段…"
    static let addLabel = "新建片段"
    static let emptyCTA = "新建片段…"
    static let emptyTitle = "还没有片段"
    static let emptyDetail = "保存常用文字，之后可以快速复制或创建面板。"
    static let emptySearch = "没有找到匹配的片段"
    static let emptySearchDetail = "试试其他关键词。"
    static let futureSchema = "此版本无法读取片段库数据"
    static let unreadable = "片段库数据无法读取，已保留原文件"
    static let copyHint = "↩ 复制"
    static let editHint = "⌘↩ 编辑"
    static let createHint = "⌘N 新建"
    static let closeHint = "Esc 关闭"
    static let copyLabel = "复制"
    static let editLabel = "编辑…"
    static let createPanelLabel = "创建文字面板"
    static let pinLabel = "置顶"
    static let unpinLabel = "取消置顶"
    static let deleteLabel = "删除…"
    static let deleteButton = "删除片段"
    static let cancelLabel = "取消"
    static let saveLabel = "保存"
    static let titleLabel = "标题"
    static let contentLabel = "内容"
    static let emptyContent = "内容不能为空"
    static let contentTooLarge = "内容过长"
    static let saveAsSnippet = "保存为片段…"

    static func deleteTitle(_ name: String) -> String {
        "删除“\(name)”？"
    }

    static let deleteBody = "此操作无法撤销。"
}

enum SnippetEmptyPresentation {
    static let symbol = "text.quote"
    static let searchSymbol = "magnifyingglass"

    static func showsCreateCTA(query: String, canMutate: Bool) -> Bool {
        canMutate && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func create(using onCreate: () -> Void) {
        onCreate()
    }
}

enum SnippetLoadOutcome: Equatable {
    case missing
    case loaded
    case recoveredFromCorruption
    case corruptUnquarantined
    case unsupportedFutureSchema(Int)
    case unavailable
}

enum SnippetCommitError: Equatable, Error {
    case emptyContent
    case contentTooLarge
    case notWritable
    case writeFailed
    case missing

    var message: String {
        switch self {
        case .emptyContent:
            return SnippetCopy.emptyContent
        case .contentTooLarge:
            return SnippetCopy.contentTooLarge
        case .notWritable, .writeFailed, .missing:
            return "无法保存片段"
        }
    }

    static func from(_ error: SnippetValidationError) -> SnippetCommitError {
        switch error {
        case .emptyContent: return .emptyContent
        case .contentTooLarge: return .contentTooLarge
        }
    }
}
