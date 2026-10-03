import Foundation

enum GlobalSearchSnapshotBuilder {
    static func clipboard(
        _ records: [ClipboardHistoryRecord],
        unavailable: Bool
    ) -> [GlobalSearchDocument] {
        guard !unavailable else { return [] }
        return records.map(document(from:))
    }

    static func fileShelf(
        _ records: [FileShelfRecord],
        unavailable: Bool
    ) -> [GlobalSearchDocument] {
        guard !unavailable else { return [] }
        return records.map(document(from:))
    }

    static func snippets(
        _ records: [SnippetRecord],
        unavailable: Bool
    ) -> [GlobalSearchDocument] {
        guard !unavailable else { return [] }
        return records.map(document(from:))
    }

    static func links(
        _ records: [LinkRecord],
        unavailable: Bool
    ) -> [GlobalSearchDocument] {
        guard !unavailable else { return [] }
        return records.map(document(from:))
    }

    static func panels(
        _ summaries: [PanelSummary],
        workspaceName: (String) -> String
    ) -> [GlobalSearchDocument] {
        summaries.map { document(from: $0, workspaceName: workspaceName($0.workspaceID)) }
    }

    static func clipboardUnavailable(_ outcome: ClipboardHistoryLoadOutcome) -> Bool {
        switch outcome {
        case .unsupportedFutureSchema, .corruptUnquarantined, .unavailable:
            return true
        case .missing, .loaded, .recoveredFromCorruption:
            return false
        }
    }

    static func fileShelfUnavailable(_ outcome: FileShelfLoadOutcome) -> Bool {
        switch outcome {
        case .unsupportedFutureSchema, .corruptUnquarantined, .unavailable:
            return true
        case .missing, .loaded, .recoveredFromCorruption:
            return false
        }
    }

    static func snippetsUnavailable(_ outcome: SnippetLoadOutcome) -> Bool {
        switch outcome {
        case .unsupportedFutureSchema, .corruptUnquarantined, .unavailable:
            return true
        case .missing, .loaded, .recoveredFromCorruption:
            return false
        }
    }

    static func linksUnavailable(_ outcome: LinkLoadOutcome) -> Bool {
        switch outcome {
        case .unsupportedFutureSchema, .corruptUnquarantined, .unavailable:
            return true
        case .missing, .loaded, .recoveredFromCorruption:
            return false
        }
    }

    static func document(from record: ClipboardHistoryRecord) -> GlobalSearchDocument {
        switch record.kind {
        case .text:
            let text = record.text ?? ""
            let title = GlobalSearchText.firstNonEmptyLine(text) ?? GlobalSearchText.truncated(text, limit: 80)
            return GlobalSearchDocument(
                id: GlobalSearchResultID(source: .clipboard, itemID: record.id),
                source: .clipboard,
                title: title.isEmpty ? "剪贴板" : title,
                subtitle: nil,
                preview: GlobalSearchPreview.display(text),
                searchableTitle: title,
                searchableFields: [text],
                activityAt: record.lastCopiedAt,
                rowSymbol: GlobalSearchSource.clipboard.symbol
            )
        case .image:
            return GlobalSearchDocument(
                id: GlobalSearchResultID(source: .clipboard, itemID: record.id),
                source: .clipboard,
                title: GlobalSearchCopy.clipboardImageTitle,
                subtitle: nil,
                preview: nil,
                searchableTitle: GlobalSearchCopy.clipboardImageTitle,
                searchableFields: [GlobalSearchCopy.clipboardImageAlias],
                activityAt: record.lastCopiedAt,
                rowSymbol: "photo"
            )
        }
    }

    static func document(from record: FileShelfRecord) -> GlobalSearchDocument {
        GlobalSearchDocument(
            id: GlobalSearchResultID(source: .fileShelf, itemID: record.id),
            source: .fileShelf,
            title: record.displayName,
            subtitle: GlobalSearchPreview.display(record.originalPath),
            preview: GlobalSearchPreview.display(record.originalPath),
            searchableTitle: record.displayName,
            searchableFields: [
                record.displayName,
                record.originalPath,
                (record.displayName as NSString).pathExtension,
                (record.originalPath as NSString).pathExtension
            ],
            activityAt: record.lastUsedAt
        )
    }

    static func document(from record: SnippetRecord) -> GlobalSearchDocument {
        GlobalSearchDocument(
            id: GlobalSearchResultID(source: .snippets, itemID: record.id),
            source: .snippets,
            title: record.title,
            subtitle: nil,
            preview: GlobalSearchPreview.display(record.content),
            searchableTitle: record.title,
            searchableFields: [record.content],
            activityAt: record.lastUsedAt
        )
    }

    static func document(from record: LinkRecord) -> GlobalSearchDocument {
        let preview = LinkPreview.line(from: record.urlString)
        return GlobalSearchDocument(
            id: GlobalSearchResultID(source: .links, itemID: record.id),
            source: .links,
            title: record.title,
            subtitle: preview,
            preview: preview,
            searchableTitle: record.title,
            searchableFields: [record.urlString, preview],
            activityAt: record.lastOpenedAt
        )
    }

    static func document(from summary: PanelSummary, workspaceName: String) -> GlobalSearchDocument {
        let kind = PanelSummaryKindLabel.displayName(for: summary.kindIdentifier)
        let subtitle = [workspaceName, kind].filter { !$0.isEmpty }.joined(separator: " · ")
        var fields = [
            summary.title,
            summary.automaticTitle,
            summary.customTitle ?? "",
            summary.subtitle ?? "",
            summary.preview,
            kind,
            workspaceName
        ]
        fields.append(contentsOf: summary.tags)
        let preview = summary.isUnreadable
            ? PanelSummaryFallback.unreadable
            : GlobalSearchPreview.display(summary.preview)
        return GlobalSearchDocument(
            id: GlobalSearchResultID(source: .panels, itemID: summary.id),
            source: .panels,
            title: summary.title,
            subtitle: subtitle,
            preview: preview,
            searchableTitle: summary.title,
            searchableFields: fields.filter { !$0.isEmpty },
            activityAt: summary.updatedAt,
            workspaceID: summary.workspaceID
        )
    }
}
