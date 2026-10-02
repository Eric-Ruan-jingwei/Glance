import Foundation

enum QuickCaptureKind: Equatable {
    case text
    case todo
}

struct QuickCaptureRequest: Equatable {
    var kind: QuickCaptureKind
    var text: String

    var normalizedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !normalizedText.isEmpty
    }

    var kindIdentifier: String {
        switch kind {
        case .text:
            return "com.glance.panel.text"
        case .todo:
            return "com.glance.panel.todo"
        }
    }

    func initialContent() -> PanelInitialContent? {
        guard isValid else { return nil }
        switch kind {
        case .text:
            return .plainText(normalizedText)
        case .todo:
            return .todoTitle(normalizedText)
        }
    }
}

enum PanelInitialContent: Equatable {
    case none
    case plainText(String)
    case todoTitle(String)
}

enum PanelCreationSession {
    /// Writes the initial payload, then inserts metadata. Any failure deletes the payload directory.
    static func materialize(
        id: UUID,
        store: PayloadStore,
        writePayload: (URL) throws -> Void,
        insert: () throws -> Void
    ) throws {
        let directory = try store.directory(for: id)
        do {
            try writePayload(directory)
            try insert()
        } catch {
            store.delete(id: id)
            throw error
        }
    }
}
