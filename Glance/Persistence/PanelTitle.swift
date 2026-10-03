import Foundation

enum PanelTitle {
    static let maxLength = 80

    /// Read-path cleanup: newline sequences become a single space, then trim.
    /// Empty / whitespace-only values become `nil`. Does not enforce max length.
    static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let collapsed = raw.replacingOccurrences(
            of: "[\\r\\n]+",
            with: " ",
            options: .regularExpression
        )
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Write-path validation for user mutations. Blank input clears the custom title.
    static func validated(_ raw: String?) throws -> String? {
        guard let normalized = normalize(raw) else { return nil }
        guard normalized.count <= maxLength else { throw PanelTitleError.tooLong }
        return normalized
    }
}

enum PanelTitleError: Error, Equatable, LocalizedError {
    case panelNotFound
    case tooLong

    var errorDescription: String? {
        switch self {
        case .panelNotFound:
            return "找不到该面板。"
        case .tooLong:
            return "面板名称最多 80 个字符。"
        }
    }
}
