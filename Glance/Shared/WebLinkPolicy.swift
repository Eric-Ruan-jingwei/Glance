import Foundation

enum WebLinkPolicy {
    static func normalizedURLString(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let components = URLComponents(string: trimmed) else { return nil }
        guard let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        guard let host = components.host, !host.isEmpty else { return nil }
        return trimmed
    }
}

enum ClipboardWebLinkHandoff {
    static func isAvailable(for record: ClipboardHistoryRecord) -> Bool {
        record.kind == .text && normalizedURL(from: record) != nil
    }

    static func normalizedURL(from record: ClipboardHistoryRecord) -> String? {
        guard record.kind == .text, let text = record.text else { return nil }
        return WebLinkPolicy.normalizedURLString(text)
    }
}
