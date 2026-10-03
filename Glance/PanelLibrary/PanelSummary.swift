import Foundation

extension Notification.Name {
    static let glancePanelCollectionDidChange = Notification.Name("GlancePanelCollectionDidChange")
}

struct PanelSummary: Identifiable, Equatable {
    var id: UUID
    var kindIdentifier: String
    var title: String
    var subtitle: String?
    var preview: String
    var createdAt: Date
    var updatedAt: Date
    var isLocked: Bool
    var isPassThrough: Bool
    var isPinned: Bool
    var isUnreadable: Bool
}

enum PanelSummaryKindFilter: String, CaseIterable, Equatable {
    case all
    case text
    case markdown
    case todo
    case image

    var title: String {
        switch self {
        case .all: return "全部"
        case .text: return "文字"
        case .markdown: return "Markdown"
        case .todo: return "待办"
        case .image: return "图片"
        }
    }

    var kindIdentifier: String? {
        switch self {
        case .all: return nil
        case .text: return "com.glance.panel.text"
        case .markdown: return "com.glance.panel.markdown"
        case .todo: return "com.glance.panel.todo"
        case .image: return "com.glance.panel.image"
        }
    }
}

enum PanelSummaryFallback {
    static let text = "空文字面板"
    static let markdown = "空 Markdown 面板"
    static let todo = "空待办面板"
    static let image = "图片面板"
    static let unreadable = "无法读取内容"
}

enum PanelSummaryKindLabel {
    static func displayName(for kindIdentifier: String) -> String {
        switch kindIdentifier {
        case "com.glance.panel.text": return "文字"
        case "com.glance.panel.markdown": return "Markdown"
        case "com.glance.panel.todo": return "待办"
        case "com.glance.panel.image": return "图片"
        default: return "面板"
        }
    }
}

enum PanelSummaryText {
    static let titleLimit = 80

    static func firstNonEmptyLine(_ text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return truncated(trimmed)
            }
        }
        return nil
    }

    static func truncated(_ text: String, limit: Int = titleLimit) -> String {
        if text.count <= limit { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<end])
    }

    static func markdownTitle(from source: String) -> String? {
        var firstNonEmpty: String?
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if firstNonEmpty == nil {
                firstNonEmpty = trimmed
            }
            if let heading = headingText(trimmed) {
                return truncated(heading)
            }
        }
        return firstNonEmpty.map { truncated(stripMarkdownDecorations($0)) }
    }

    static func headingText(_ line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        var count = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == "#", count < 6 {
            count += 1
            index = line.index(after: index)
        }
        guard count >= 1, index < line.endIndex, line[index].isWhitespace else { return nil }
        let rest = line[index...].trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }

    static func stripMarkdownDecorations(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)
        if result.hasPrefix("#") {
            result = String(result.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
        }
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func todoTitle(items: [TodoItem]) -> (title: String, subtitle: String) {
        if items.isEmpty {
            return (PanelSummaryFallback.todo, "0 / 0 已完成")
        }
        let done = items.filter(\.isCompleted).count
        let subtitle = "\(done) / \(items.count) 已完成"
        if let open = items.first(where: { !$0.isCompleted }) {
            return (truncated(open.text), subtitle)
        }
        return (truncated(items[0].text), subtitle)
    }
}

enum PanelSummaryQuery {
    static func matches(_ summary: PanelSummary, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        if summary.title.localizedCaseInsensitiveContains(needle) { return true }
        if let subtitle = summary.subtitle, subtitle.localizedCaseInsensitiveContains(needle) {
            return true
        }
        return summary.preview.localizedCaseInsensitiveContains(needle)
    }

    static func filtered(
        _ summaries: [PanelSummary],
        query: String,
        kind: PanelSummaryKindFilter
    ) -> [PanelSummary] {
        summaries.filter { summary in
            if let identifier = kind.kindIdentifier, summary.kindIdentifier != identifier {
                return false
            }
            return matches(summary, query: query)
        }
    }

    static func sortedByUpdatedAtDescending(_ summaries: [PanelSummary]) -> [PanelSummary] {
        summaries.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

enum PNGImageSize {
    static func read(from data: Data) -> (width: Int, height: Int)? {
        let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        guard data.count >= 24, Array(data.prefix(8)) == signature else { return nil }
        let width = int32(data, offset: 16)
        let height = int32(data, offset: 20)
        guard width > 0, height > 0 else { return nil }
        return (width, height)
    }

    static func read(fromFile url: URL) -> (width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return read(from: data)
    }

    private static func int32(_ data: Data, offset: Int) -> Int {
        var value = 0
        for byte in data[offset..<(offset + 4)] {
            value = (value << 8) | Int(byte)
        }
        return value
    }
}
