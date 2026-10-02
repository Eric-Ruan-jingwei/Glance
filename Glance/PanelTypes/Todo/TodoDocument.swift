import Foundation

struct TodoItem: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var isCompleted: Bool
    var createdAt: Date
}

struct TodoDocument: Codable, Equatable {
    static let currentVersion = 1
    static let empty = TodoDocument(version: currentVersion, items: [])

    var version: Int
    var items: [TodoItem]
}

enum TodoMutation {
    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    static func add(
        _ document: inout TodoDocument,
        text: String,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) -> TodoItem? {
        let text = trimmed(text)
        guard !text.isEmpty else { return nil }
        let item = TodoItem(id: id, text: text, isCompleted: false, createdAt: createdAt)
        document.items.append(item)
        return item
    }

    enum EditResult: Equatable {
        case updated
        case deleted
        case unchanged
        case notFound
    }

    @discardableResult
    static func edit(_ document: inout TodoDocument, id: UUID, text: String) -> EditResult {
        guard let index = document.items.firstIndex(where: { $0.id == id }) else { return .notFound }
        let text = trimmed(text)
        if text.isEmpty {
            document.items.remove(at: index)
            return .deleted
        }
        if document.items[index].text == text {
            return .unchanged
        }
        document.items[index].text = text
        return .updated
    }

    @discardableResult
    static func toggle(_ document: inout TodoDocument, id: UUID) -> Bool {
        guard let index = document.items.firstIndex(where: { $0.id == id }) else { return false }
        document.items[index].isCompleted.toggle()
        return true
    }

    @discardableResult
    static func delete(_ document: inout TodoDocument, id: UUID) -> Bool {
        let before = document.items.count
        document.items.removeAll { $0.id == id }
        return document.items.count < before
    }
}
