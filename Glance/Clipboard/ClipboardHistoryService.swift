import Combine
import Foundation

@MainActor
final class ClipboardHistoryService: ObservableObject {
    @Published private(set) var records: [ClipboardHistoryRecord] = []
    @Published private(set) var loadOutcome: ClipboardHistoryLoadOutcome = .missing

    let store: ClipboardHistoryStore
    let preferences: ClipboardHistoryPreferenceStore
    private var cancellables = Set<AnyCancellable>()

    init(store: ClipboardHistoryStore, preferences: ClipboardHistoryPreferenceStore) {
        self.store = store
        self.preferences = preferences
        preferences.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        reload()
    }

    var canPersist: Bool {
        store.isWritable
    }

    var isRecordingEnabled: Bool {
        preferences.isRecordingEnabled && canPersist
    }

    func reload() {
        records = store.load()
        loadOutcome = store.lastLoadOutcome
    }

    func flush() {
        guard canPersist else { return }
        try? store.save(records)
    }

    @discardableResult
    func record(_ content: ClipboardCaptureContent, at date: Date = Date()) -> ClipboardHistoryRecord? {
        guard canPersist else { return nil }
        switch content {
        case .text(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return upsert(
                kind: .text,
                hash: ClipboardHistoryHasher.hash(text: text),
                at: date,
                text: text,
                png: nil
            )
        case .png(let data):
            guard !data.isEmpty, data.count <= ClipboardHistoryPolicy.maximumStoredImageBytes else {
                return nil
            }
            return upsert(
                kind: .image,
                hash: ClipboardHistoryHasher.hash(png: data),
                at: date,
                text: nil,
                png: data
            )
        }
    }

    func toggleFavorite(id: UUID, at date: Date = Date()) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        if records[index].isFavorite {
            records[index].isFavorite = false
            records[index].favoritedAt = nil
        } else {
            records[index].isFavorite = true
            records[index].favoritedAt = date
        }
        persistPreservingMemory()
    }

    func delete(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let removed = records[index]
        records.remove(at: index)
        do {
            try store.save(records)
        } catch {
            records.insert(removed, at: min(index, records.count))
            return
        }
        if let assetPath = removed.assetPath {
            store.deleteAsset(relativePath: assetPath)
        }
    }

    func clearRecent() {
        let kept = records.filter(\.isFavorite)
        let removed = records.filter { !$0.isFavorite }
        records = kept
        do {
            try store.save(records)
        } catch {
            records.append(contentsOf: removed)
            return
        }
        for item in removed {
            if let assetPath = item.assetPath {
                store.deleteAsset(relativePath: assetPath)
            }
        }
    }

    func clearAll() {
        let previous = records
        records = []
        do {
            try store.save(records)
        } catch {
            records = previous
            return
        }
        store.removeAllAssets()
    }

    func content(for id: UUID) -> ClipboardCaptureContent? {
        guard let record = records.first(where: { $0.id == id }) else { return nil }
        switch record.kind {
        case .text:
            guard let text = record.text else { return nil }
            return .text(text)
        case .image:
            guard let url = store.assetURL(for: record),
                  let data = try? Data(contentsOf: url),
                  !data.isEmpty
            else { return nil }
            return .png(data)
        }
    }

    @discardableResult
    func reuse(_ id: UUID, at date: Date = Date()) -> ClipboardCaptureContent? {
        guard let content = content(for: id) else { return nil }
        guard let index = records.firstIndex(where: { $0.id == id }) else { return content }
        records[index].lastCopiedAt = date
        persistPreservingMemory()
        return content
    }

    func recent(matching query: String) -> [ClipboardHistoryRecord] {
        ClipboardHistorySearch.recent(records, query: query)
    }

    func favorites(matching query: String) -> [ClipboardHistoryRecord] {
        ClipboardHistorySearch.favorites(records, query: query)
    }

    private func upsert(
        kind: ClipboardHistoryKind,
        hash: String,
        at date: Date,
        text: String?,
        png: Data?
    ) -> ClipboardHistoryRecord? {
        if let index = records.firstIndex(where: { $0.contentHash == hash }) {
            records[index].lastCopiedAt = date
            persistPreservingMemory()
            return records[index]
        }

        let id = UUID()
        var assetPath: String?
        if let png {
            do {
                assetPath = try store.writeAsset(id: id, png: png)
            } catch {
                return nil
            }
        }
        let record = ClipboardHistoryRecord(
            id: id,
            kind: kind,
            createdAt: date,
            lastCopiedAt: date,
            isFavorite: false,
            favoritedAt: nil,
            contentHash: hash,
            text: text,
            assetPath: assetPath
        )
        records.append(record)
        let doomed = Set(ClipboardHistoryRetention.idsToEvict(from: records))
        let evicted = records.filter { doomed.contains($0.id) }
        records.removeAll { doomed.contains($0.id) }
        do {
            try store.save(records)
        } catch {
            records.removeAll { $0.id == id }
            records.append(contentsOf: evicted)
            if let assetPath {
                store.deleteAsset(relativePath: assetPath)
            }
            return nil
        }
        for item in evicted {
            if let assetPath = item.assetPath {
                store.deleteAsset(relativePath: assetPath)
            }
        }
        return record
    }

    private func persistPreservingMemory() {
        do {
            try store.save(records)
        } catch {
            NSLog("Glance clipboard: failed to persist history: %@", error.localizedDescription)
        }
    }
}
