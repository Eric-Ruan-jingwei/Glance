import Foundation

enum PanelTag {
    static let maxLength = 24
    static let maxCount = 12
    static let rowChipLimit = 3

    /// Read-path cleanup for a single tag. Does not enforce max length.
    static func normalize(_ raw: String) -> String? {
        let collapsed = raw.replacingOccurrences(
            of: "[\\r\\n]+",
            with: " ",
            options: .regularExpression
        )
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func isEqual(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}

enum PanelTags {
    /// Read-tolerant: trim, collapse newlines, drop blanks, case-insensitive dedupe.
    /// Keeps first-seen display casing and insertion order. Does not enforce max length or count.
    static func normalized(_ tags: [String]) -> [String] {
        var result: [String] = []
        for raw in tags {
            guard let tag = PanelTag.normalize(raw) else { continue }
            if result.contains(where: { PanelTag.isEqual($0, tag) }) { continue }
            result.append(tag)
        }
        return result
    }

    /// Write-strict: normalize, then reject oversize tags or too many tags.
    static func validated(_ tags: [String]) throws -> [String] {
        let normalized = Self.normalized(tags)
        if normalized.contains(where: { $0.count > PanelTag.maxLength }) {
            throw PanelTagError.tagTooLong
        }
        guard normalized.count <= PanelTag.maxCount else {
            throw PanelTagError.tooManyTags
        }
        return normalized
    }

    /// Split user input on commas (ASCII / Chinese) and newlines, then normalize.
    static func parseInput(_ raw: String) -> [String] {
        let unified = raw
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "[\\r\\n]+", with: ",", options: .regularExpression)
        let parts = unified.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        return normalized(parts)
    }

    /// Derived catalog: case-insensitive dedupe, localized sort. Not a persisted registry.
    static func catalog(_ tags: [String]) -> [String] {
        normalized(tags).sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    static func containsExact(_ tags: [String], tag: String) -> Bool {
        tags.contains { PanelTag.isEqual($0, tag) }
    }

    static func rowPreview(_ tags: [String]) -> (shown: [String], overflow: Int) {
        if tags.count <= PanelTag.rowChipLimit {
            return (tags, 0)
        }
        return (Array(tags.prefix(PanelTag.rowChipLimit)), tags.count - PanelTag.rowChipLimit)
    }
}

enum PanelTagError: Error, Equatable, LocalizedError {
    case panelNotFound
    case tagTooLong
    case tooManyTags

    var errorDescription: String? {
        switch self {
        case .panelNotFound:
            return "找不到该面板。"
        case .tagTooLong:
            return "标签最多 24 个字符。"
        case .tooManyTags:
            return "每个面板最多 12 个标签。"
        }
    }
}
