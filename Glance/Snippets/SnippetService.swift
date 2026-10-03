import Combine
import Foundation

@MainActor
final class SnippetService: ObservableObject {
    @Published private(set) var records: [SnippetRecord] = []
    @Published private(set) var loadOutcome: SnippetLoadOutcome = .missing

    let store: SnippetStore

    init(store: SnippetStore) {
        self.store = store
        reload()
    }

    var canPersist: Bool {
        store.isWritable
    }

    var canMutate: Bool {
        guard canPersist else { return false }
        if case .unsupportedFutureSchema = loadOutcome { return false }
        return true
    }

    func reload() {
        records = store.load()
        loadOutcome = store.lastLoadOutcome
    }

    func flush() {
        guard canPersist else { return }
        try? store.save(records)
    }

    func displayed(matching query: String) -> [SnippetRecord] {
        SnippetSort.displayed(records, query: query)
    }

    @discardableResult
    func create(_ draft: SnippetDraft, at date: Date = Date()) -> Result<SnippetRecord, SnippetCommitError> {
        guard canMutate else { return .failure(.notWritable) }
        if let validation = SnippetValidation.validate(content: draft.content) {
            return .failure(.from(validation))
        }
        let record = SnippetRecord(
            id: UUID(),
            title: SnippetTitleGenerator.resolvedTitle(draftTitle: draft.title, content: draft.content),
            content: draft.content,
            createdAt: date,
            updatedAt: date,
            lastUsedAt: date,
            isPinned: false
        )
        records.append(record)
        do {
            try store.save(records)
            return .success(record)
        } catch let error as SnippetStoreError {
            records.removeAll { $0.id == record.id }
            return .failure(mapStore(error))
        } catch {
            records.removeAll { $0.id == record.id }
            return .failure(.writeFailed)
        }
    }

    @discardableResult
    func update(id: UUID, draft: SnippetDraft, at date: Date = Date()) -> Result<SnippetRecord, SnippetCommitError> {
        guard canMutate else { return .failure(.notWritable) }
        guard let index = records.firstIndex(where: { $0.id == id }) else { return .failure(.missing) }
        if let validation = SnippetValidation.validate(content: draft.content) {
            return .failure(.from(validation))
        }
        let previous = records[index]
        records[index].title = SnippetTitleGenerator.resolvedTitle(draftTitle: draft.title, content: draft.content)
        records[index].content = draft.content
        records[index].updatedAt = date
        do {
            try store.save(records)
            return .success(records[index])
        } catch let error as SnippetStoreError {
            records[index] = previous
            return .failure(mapStore(error))
        } catch {
            records[index] = previous
            return .failure(.writeFailed)
        }
    }

    @discardableResult
    func togglePin(id: UUID) -> Bool {
        guard canMutate, let index = records.firstIndex(where: { $0.id == id }) else { return false }
        let previous = records[index]
        records[index].isPinned.toggle()
        do {
            try store.save(records)
            return true
        } catch {
            records[index] = previous
            return false
        }
    }

    @discardableResult
    func delete(id: UUID) -> Bool {
        guard canMutate, let index = records.firstIndex(where: { $0.id == id }) else { return false }
        let removed = records[index]
        records.remove(at: index)
        do {
            try store.save(records)
            return true
        } catch {
            records.insert(removed, at: min(index, records.count))
            return false
        }
    }

    @discardableResult
    func markUsed(id: UUID, at date: Date = Date()) -> Bool {
        guard canMutate, let index = records.firstIndex(where: { $0.id == id }) else { return false }
        let previous = records[index].lastUsedAt
        records[index].lastUsedAt = date
        do {
            try store.save(records)
            return true
        } catch {
            records[index].lastUsedAt = previous
            return false
        }
    }

    private func mapStore(_ error: SnippetStoreError) -> SnippetCommitError {
        switch error {
        case .notWritable:
            return .notWritable
        case .writeFailed, .unreadable, .unsupportedFutureSchema:
            return .writeFailed
        }
    }
}
