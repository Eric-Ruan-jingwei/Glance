import Foundation

struct GlanceHomeItem: Equatable, Identifiable {
    var id: GlobalSearchResultID
    var source: GlobalSearchSource
    var title: String
    var activityAt: Date
    var preferredAt: Date?
}

struct GlanceHomePanelCandidate: Equatable {
    var id: UUID
    var title: String
    var updatedAt: Date

    init(id: UUID, title: String, updatedAt: Date) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
    }

    init(record: PanelRecord) {
        self.init(
            id: record.id,
            title: GlanceHomeTitle.panel(
                customTitle: record.customTitle,
                kindIdentifier: record.kindIdentifier
            ),
            updatedAt: record.updatedAt
        )
    }
}

struct GlanceHomeSnapshot: Equatable {
    var preferred: [GlanceHomeItem]
    var recent: [GlanceHomeItem]

    static let empty = GlanceHomeSnapshot(preferred: [], recent: [])
}

enum GlanceHomePolicy {
    static let maximumPreferredItems = 8
    static let maximumRecentItems = 8
    static let maximumRecentPerSource = 2
}

enum GlanceHomeCopy {
    static let preferred = "常用"
    static let recent = "最近使用"
    static let emptyPreferred = "暂无常用项目"
    static let emptyRecent = "暂无最近项目"
    static let panel = "面板…"
    static let panelOperations = "面板操作"
}

enum GlanceHomeTitle {
    static func clipboard(_ record: ClipboardHistoryRecord) -> String {
        switch record.kind {
        case .image:
            return GlobalSearchCopy.clipboardImageTitle
        case .text:
            let first = ClipboardHistoryPreview.lines(from: record.text ?? "").0
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? GlobalSearchSource.clipboard.displayName : first
        }
    }

    static func fileShelf(_ record: FileShelfRecord) -> String {
        record.displayName
    }

    static func snippet(_ record: SnippetRecord) -> String {
        record.title
    }

    static func link(_ record: LinkRecord) -> String {
        record.title
    }

    static func panel(customTitle: String?, kindIdentifier: String) -> String {
        if let customTitle {
            return customTitle
        }
        switch kindIdentifier {
        case PanelKind.text: return PanelSummaryFallback.text
        case PanelKind.markdown: return PanelSummaryFallback.markdown
        case PanelKind.todo: return PanelSummaryFallback.todo
        case PanelKind.image: return PanelSummaryFallback.image
        case PanelKind.pdf: return PanelSummaryFallback.pdf
        default: return GlobalSearchSource.panels.displayName
        }
    }
}

enum GlanceHomeProjection {
    static func preferred(
        clipboards: [ClipboardHistoryRecord],
        files: [FileShelfRecord],
        snippets: [SnippetRecord],
        links: [LinkRecord]
    ) -> [GlanceHomeItem] {
        var items: [GlanceHomeItem] = []
        items.append(contentsOf: clipboards.compactMap(preferredItem(from:)))
        items.append(contentsOf: files.compactMap(preferredItem(from:)))
        items.append(contentsOf: snippets.compactMap(preferredItem(from:)))
        items.append(contentsOf: links.compactMap(preferredItem(from:)))
        return ranked(
            items,
            date: { $0.preferredAt ?? $0.activityAt },
            limit: GlanceHomePolicy.maximumPreferredItems
        )
    }

    static func recent(
        clipboards: [ClipboardHistoryRecord],
        files: [FileShelfRecord],
        snippets: [SnippetRecord],
        links: [LinkRecord],
        panels: [GlanceHomePanelCandidate]
    ) -> [GlanceHomeItem] {
        var items: [GlanceHomeItem] = []
        items.append(contentsOf: clipboards.map(recentItem(from:)))
        items.append(contentsOf: files.map(recentItem(from:)))
        items.append(contentsOf: snippets.map(recentItem(from:)))
        items.append(contentsOf: links.map(recentItem(from:)))
        items.append(contentsOf: panels.map(recentItem(from:)))
        return ranked(
            capPerSource(items, limit: GlanceHomePolicy.maximumRecentPerSource),
            date: { $0.activityAt },
            limit: GlanceHomePolicy.maximumRecentItems
        )
    }

    private static func preferredItem(from record: ClipboardHistoryRecord) -> GlanceHomeItem? {
        guard record.isFavorite else { return nil }
        let activity = record.lastCopiedAt
        return GlanceHomeItem(
            id: GlobalSearchResultID(source: .clipboard, itemID: record.id),
            source: .clipboard,
            title: GlanceHomeTitle.clipboard(record),
            activityAt: activity,
            preferredAt: record.favoritedAt ?? activity
        )
    }

    private static func preferredItem(from record: FileShelfRecord) -> GlanceHomeItem? {
        guard record.isFavorite else { return nil }
        let activity = record.lastUsedAt
        return GlanceHomeItem(
            id: GlobalSearchResultID(source: .fileShelf, itemID: record.id),
            source: .fileShelf,
            title: GlanceHomeTitle.fileShelf(record),
            activityAt: activity,
            preferredAt: record.favoritedAt ?? activity
        )
    }

    private static func preferredItem(from record: SnippetRecord) -> GlanceHomeItem? {
        guard record.isPinned else { return nil }
        return GlanceHomeItem(
            id: GlobalSearchResultID(source: .snippets, itemID: record.id),
            source: .snippets,
            title: GlanceHomeTitle.snippet(record),
            activityAt: record.lastUsedAt,
            preferredAt: record.lastUsedAt
        )
    }

    private static func preferredItem(from record: LinkRecord) -> GlanceHomeItem? {
        guard record.isPinned else { return nil }
        return GlanceHomeItem(
            id: GlobalSearchResultID(source: .links, itemID: record.id),
            source: .links,
            title: GlanceHomeTitle.link(record),
            activityAt: record.lastOpenedAt,
            preferredAt: record.lastOpenedAt
        )
    }

    private static func recentItem(from record: ClipboardHistoryRecord) -> GlanceHomeItem {
        GlanceHomeItem(
            id: GlobalSearchResultID(source: .clipboard, itemID: record.id),
            source: .clipboard,
            title: GlanceHomeTitle.clipboard(record),
            activityAt: record.lastCopiedAt,
            preferredAt: nil
        )
    }

    private static func recentItem(from record: FileShelfRecord) -> GlanceHomeItem {
        GlanceHomeItem(
            id: GlobalSearchResultID(source: .fileShelf, itemID: record.id),
            source: .fileShelf,
            title: GlanceHomeTitle.fileShelf(record),
            activityAt: record.lastUsedAt,
            preferredAt: nil
        )
    }

    private static func recentItem(from record: SnippetRecord) -> GlanceHomeItem {
        GlanceHomeItem(
            id: GlobalSearchResultID(source: .snippets, itemID: record.id),
            source: .snippets,
            title: GlanceHomeTitle.snippet(record),
            activityAt: record.lastUsedAt,
            preferredAt: nil
        )
    }

    private static func recentItem(from record: LinkRecord) -> GlanceHomeItem {
        GlanceHomeItem(
            id: GlobalSearchResultID(source: .links, itemID: record.id),
            source: .links,
            title: GlanceHomeTitle.link(record),
            activityAt: record.lastOpenedAt,
            preferredAt: nil
        )
    }

    private static func recentItem(from panel: GlanceHomePanelCandidate) -> GlanceHomeItem {
        GlanceHomeItem(
            id: GlobalSearchResultID(source: .panels, itemID: panel.id),
            source: .panels,
            title: panel.title,
            activityAt: panel.updatedAt,
            preferredAt: nil
        )
    }

    private static func capPerSource(_ items: [GlanceHomeItem], limit: Int) -> [GlanceHomeItem] {
        var result: [GlanceHomeItem] = []
        for source in GlobalSearchSource.allCases {
            let slice = items
                .filter { $0.source == source }
                .sorted(by: { compare($0, $1, date: { $0.activityAt }) })
                .prefix(limit)
            result.append(contentsOf: slice)
        }
        return result
    }

    private static func ranked(
        _ items: [GlanceHomeItem],
        date: (GlanceHomeItem) -> Date,
        limit: Int
    ) -> [GlanceHomeItem] {
        Array(
            items
                .sorted(by: { compare($0, $1, date: date) })
                .prefix(limit)
        )
    }

    static func compare(
        _ lhs: GlanceHomeItem,
        _ rhs: GlanceHomeItem,
        date: (GlanceHomeItem) -> Date
    ) -> Bool {
        let leftDate = date(lhs)
        let rightDate = date(rhs)
        if leftDate != rightDate {
            return leftDate > rightDate
        }
        if lhs.source.stableSortOrder != rhs.source.stableSortOrder {
            return lhs.source.stableSortOrder < rhs.source.stableSortOrder
        }
        let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }
        return lhs.id.itemID.uuidString < rhs.id.itemID.uuidString
    }
}

enum GlanceHomeSnapshotBuilder {
    static func build(
        clipboards: [ClipboardHistoryRecord] = [],
        files: [FileShelfRecord] = [],
        snippets: [SnippetRecord] = [],
        links: [LinkRecord] = [],
        panels: [GlanceHomePanelCandidate] = []
    ) -> GlanceHomeSnapshot {
        GlanceHomeSnapshot(
            preferred: GlanceHomeProjection.preferred(
                clipboards: clipboards,
                files: files,
                snippets: snippets,
                links: links
            ),
            recent: GlanceHomeProjection.recent(
                clipboards: clipboards,
                files: files,
                snippets: snippets,
                links: links,
                panels: panels
            )
        )
    }
}
