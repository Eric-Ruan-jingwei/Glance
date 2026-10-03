import Combine
import Foundation

@MainActor
final class FileShelfService: ObservableObject {
    @Published private(set) var records: [FileShelfRecord] = []
    @Published private(set) var loadOutcome: FileShelfLoadOutcome = .missing
    @Published var notice: String?

    let store: FileShelfStore
    let bookmarks: FileShelfBookmarking
    private let fileManager: FileManager
    private var resolutionCache: [UUID: FileShelfResolvedReference] = [:]

    init(
        store: FileShelfStore,
        bookmarks: FileShelfBookmarking,
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.bookmarks = bookmarks
        self.fileManager = fileManager
        reload()
    }

    var canPersist: Bool {
        store.isWritable
    }

    func reload() {
        records = store.load()
        loadOutcome = store.lastLoadOutcome
        resolutionCache.removeAll()
    }

    func flush() {
        guard canPersist else { return }
        try? store.save(records)
    }

    @discardableResult
    func add(paths: [String], at date: Date = Date()) -> FileShelfAddResult {
        var result = FileShelfAddResult()
        guard canPersist else { return result }
        for raw in paths {
            let url = URL(fileURLWithPath: raw)
            switch FileShelfClassifier.classify(url, fileManager: fileManager) {
            case .directory:
                result.rejectedDirectories += 1
            case .missing:
                result.failed += 1
            case .file:
                let path = FileShelfIdentity.standardizedPath(for: url)
                if let existing = existingRecord(matching: path) {
                    touch(existing.id, at: date)
                    result.updatedIDs.append(existing.id)
                } else if let id = insert(path: path, at: date) {
                    result.addedIDs.append(id)
                } else {
                    result.failed += 1
                }
            }
        }
        notice = result.notice
        return result
    }

    func toggleFavorite(id: UUID, at date: Date = Date()) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let previous = records[index]
        if records[index].isFavorite {
            records[index].isFavorite = false
            records[index].favoritedAt = nil
        } else {
            records[index].isFavorite = true
            records[index].favoritedAt = date
        }
        persistRollingBack { records[index] = previous }
    }

    func remove(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let removed = records[index]
        records.remove(at: index)
        do {
            try store.save(records)
        } catch {
            records.insert(removed, at: min(index, records.count))
            return
        }
        store.deleteBookmark(id: removed.id)
        resolutionCache.removeValue(forKey: id)
    }

    func relink(id: UUID, to path: String, at date: Date = Date()) -> Bool {
        guard canPersist, let index = records.firstIndex(where: { $0.id == id }) else { return false }
        let url = URL(fileURLWithPath: path)
        guard FileShelfClassifier.classify(url, fileManager: fileManager) == .file else { return false }
        let standardized = FileShelfIdentity.standardizedPath(for: url)
        let snapshot = FileShelfMetadataSnapshot.capture(path: standardized, fileManager: fileManager)
        guard let bookmark = try? bookmarks.createBookmark(forFileAtPath: standardized) else {
            return false
        }
        let previous = records[index]
        let previousBookmark = store.readBookmark(id: id)
        let previousResolved = resolutionCache[id]
        do {
            try store.writeBookmark(id: id, data: bookmark)
        } catch {
            return false
        }
        records[index].originalPath = standardized
        records[index].displayName = snapshot.displayName
        records[index].fileSize = snapshot.fileSize
        records[index].contentTypeIdentifier = snapshot.contentTypeIdentifier
        records[index].lastUsedAt = date
        resolutionCache.removeValue(forKey: id)
        do {
            try store.save(records)
            return true
        } catch {
            records[index] = previous
            restoreBookmarkSidecar(id: id, previousBookmark: previousBookmark)
            if let previousResolved {
                resolutionCache[id] = previousResolved
            }
            return false
        }
    }

    func markUsed(id: UUID, at date: Date = Date()) {
        touch(id, at: date)
        if let path = resolve(id, allowCache: false).urlPath,
           let index = records.firstIndex(where: { $0.id == id }) {
            refreshSnapshotIfNeeded(at: index, path: path)
        }
    }

    func recent(matching query: String) -> [FileShelfRecord] {
        FileShelfSearch.recent(records, query: query)
    }

    func favorites(matching query: String) -> [FileShelfRecord] {
        FileShelfSearch.favorites(records, query: query)
    }

    func resolve(_ id: UUID, allowCache: Bool = true) -> FileShelfResolvedReference {
        if allowCache, let cached = resolutionCache[id] {
            return cached
        }
        let resolved = resolveUncached(id)
        resolutionCache[id] = resolved
        return resolved
    }

    private func resolveUncached(_ id: UUID) -> FileShelfResolvedReference {
        guard let record = records.first(where: { $0.id == id }) else { return .missing }
        if let data = store.readBookmark(id: id) {
            let resolved = bookmarks.resolveBookmark(data)
            if let usable = validated(resolved) {
                if let refresh = usable.bookmarkDataToRefresh {
                    try? store.writeBookmark(id: id, data: refresh)
                }
                return usable
            }
        }
        if let fallback = validated(
            FileShelfResolvedReference(
                urlPath: record.originalPath,
                isMissing: false,
                isStale: false,
                bookmarkDataToRefresh: nil
            )
        ) {
            return fallback
        }
        return .missing
    }

    private func validated(
        _ resolved: FileShelfResolvedReference
    ) -> FileShelfResolvedReference? {
        guard !resolved.isMissing, let path = resolved.urlPath else { return nil }
        guard FileShelfClassifier.classify(URL(fileURLWithPath: path), fileManager: fileManager) == .file else {
            return nil
        }
        return FileShelfResolvedReference(
            urlPath: path,
            isMissing: false,
            isStale: resolved.isStale,
            bookmarkDataToRefresh: resolved.bookmarkDataToRefresh
        )
    }

    func isMissing(_ id: UUID) -> Bool {
        resolve(id).isMissing
    }

    private func existingRecord(matching path: String) -> FileShelfRecord? {
        if let exact = records.first(where: { $0.originalPath == path }) {
            return exact
        }
        for record in records {
            let resolved = resolve(record.id, allowCache: false)
            if resolved.urlPath == path {
                return record
            }
        }
        return nil
    }

    private func insert(path: String, at date: Date) -> UUID? {
        let snapshot = FileShelfMetadataSnapshot.capture(path: path, fileManager: fileManager)
        guard let bookmark = try? bookmarks.createBookmark(forFileAtPath: path) else {
            return nil
        }
        let id = UUID()
        do {
            try store.writeBookmark(id: id, data: bookmark)
        } catch {
            return nil
        }
        let record = FileShelfRecord(
            id: id,
            originalPath: path,
            displayName: snapshot.displayName,
            fileSize: snapshot.fileSize,
            contentTypeIdentifier: snapshot.contentTypeIdentifier,
            createdAt: date,
            lastUsedAt: date,
            isFavorite: false,
            favoritedAt: nil
        )
        records.append(record)
        let doomed = Set(FileShelfRetention.idsToEvict(from: records))
        let evicted = records.filter { doomed.contains($0.id) }
        records.removeAll { doomed.contains($0.id) }
        do {
            try store.save(records)
        } catch {
            records.removeAll { $0.id == id }
            records.append(contentsOf: evicted)
            store.deleteBookmark(id: id)
            return nil
        }
        for item in evicted {
            store.deleteBookmark(id: item.id)
            resolutionCache.removeValue(forKey: item.id)
        }
        return id
    }

    private func touch(_ id: UUID, at date: Date) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        let previous = records[index]
        records[index].lastUsedAt = date
        persistRollingBack { records[index] = previous }
    }

    private func refreshSnapshotIfNeeded(at index: Int, path: String) {
        let snapshot = FileShelfMetadataSnapshot.capture(path: path, fileManager: fileManager)
        let previous = records[index]
        var changed = false
        if records[index].displayName != snapshot.displayName {
            records[index].displayName = snapshot.displayName
            changed = true
        }
        if records[index].fileSize != snapshot.fileSize {
            records[index].fileSize = snapshot.fileSize
            changed = true
        }
        if records[index].originalPath != path {
            records[index].originalPath = path
            changed = true
        }
        if changed {
            persistRollingBack { records[index] = previous }
        }
    }

    private func restoreBookmarkSidecar(id: UUID, previousBookmark: Data?) {
        if let previousBookmark {
            try? store.writeBookmark(id: id, data: previousBookmark)
        } else {
            store.deleteBookmark(id: id)
        }
    }

    private func persistRollingBack(_ restore: () -> Void) {
        do {
            try store.save(records)
        } catch {
            restore()
            NSLog("Glance file shelf: failed to persist: %@", error.localizedDescription)
        }
    }
}
