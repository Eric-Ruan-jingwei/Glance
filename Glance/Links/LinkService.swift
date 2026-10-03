import Combine
import Foundation

@MainActor
final class LinkService: ObservableObject {
    @Published private(set) var records: [LinkRecord] = []
    @Published private(set) var loadOutcome: LinkLoadOutcome = .missing

    let store: LinkStore

    init(store: LinkStore) {
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

    func displayed(matching query: String) -> [LinkRecord] {
        LinkSort.displayed(records, query: query)
    }

    @discardableResult
    func create(
        _ draft: LinkDraft,
        suggestedTitle: String? = nil,
        at date: Date = Date()
    ) -> Result<LinkRecord, LinkCommitError> {
        guard canMutate else { return .failure(.notWritable) }
        if let validation = LinkValidation.validate(draft.urlString) {
            return .failure(.from(validation))
        }
        guard let urlString = WebLinkPolicy.normalizedURLString(draft.urlString) else {
            return .failure(.invalidURL)
        }
        let record = LinkRecord(
            id: UUID(),
            title: LinkTitleGenerator.resolvedTitle(
                draftTitle: draft.title,
                urlString: urlString,
                suggested: suggestedTitle
            ),
            urlString: urlString,
            createdAt: date,
            updatedAt: date,
            lastOpenedAt: date,
            isPinned: false
        )
        records.append(record)
        do {
            try store.save(records)
            return .success(record)
        } catch let error as LinkStoreError {
            records.removeAll { $0.id == record.id }
            return .failure(mapStore(error))
        } catch {
            records.removeAll { $0.id == record.id }
            return .failure(.writeFailed)
        }
    }

    @discardableResult
    func update(id: UUID, draft: LinkDraft, at date: Date = Date()) -> Result<LinkRecord, LinkCommitError> {
        guard canMutate else { return .failure(.notWritable) }
        guard let index = records.firstIndex(where: { $0.id == id }) else { return .failure(.missing) }
        if let validation = LinkValidation.validate(draft.urlString) {
            return .failure(.from(validation))
        }
        guard let urlString = WebLinkPolicy.normalizedURLString(draft.urlString) else {
            return .failure(.invalidURL)
        }
        let previous = records[index]
        records[index].title = LinkTitleGenerator.resolvedTitle(
            draftTitle: draft.title,
            urlString: urlString
        )
        records[index].urlString = urlString
        records[index].updatedAt = date
        do {
            try store.save(records)
            return .success(records[index])
        } catch let error as LinkStoreError {
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
    func markOpened(id: UUID, at date: Date = Date()) -> Bool {
        guard canMutate, let index = records.firstIndex(where: { $0.id == id }) else { return false }
        let previous = records[index].lastOpenedAt
        records[index].lastOpenedAt = date
        do {
            try store.save(records)
            return true
        } catch {
            records[index].lastOpenedAt = previous
            return false
        }
    }

    private func mapStore(_ error: LinkStoreError) -> LinkCommitError {
        switch error {
        case .notWritable:
            return .notWritable
        case .writeFailed, .unreadable, .unsupportedFutureSchema:
            return .writeFailed
        }
    }
}

enum LinkOpenCoordinator {
    @discardableResult
    static func perform(
        record: LinkRecord,
        opener: LinkOpening,
        markOpened: (UUID) -> Bool
    ) -> Bool {
        guard let request = LinkOpenPolicy.request(for: record) else { return false }
        guard opener.open(request.urlString) else { return false }
        _ = markOpened(request.id)
        return true
    }
}
