import AppKit
import Foundation

enum GlanceItemAction: Equatable, CaseIterable {
    case createTextPanel
    case createTodoPanel
    case createImagePanel
    case createPDFPanel
    case saveAsSnippet
    case saveAsLink

    var identifier: String {
        switch self {
        case .createTextPanel: return "createTextPanel"
        case .createTodoPanel: return "createTodoPanel"
        case .createImagePanel: return "createImagePanel"
        case .createPDFPanel: return "createPDFPanel"
        case .saveAsSnippet: return "saveAsSnippet"
        case .saveAsLink: return "saveAsLink"
        }
    }

    var title: String {
        switch self {
        case .createTextPanel: return "创建文字面板"
        case .createTodoPanel: return "创建待办面板"
        case .createImagePanel: return FileShelfCopy.createImagePanelLabel
        case .createPDFPanel: return FileShelfCopy.createPDFPanelLabel
        case .saveAsSnippet: return ClipboardHistoryCopy.saveAsSnippet
        case .saveAsLink: return LinkCopy.saveAsLink
        }
    }

    var createsPanel: Bool {
        switch self {
        case .createTextPanel, .createTodoPanel, .createImagePanel, .createPDFPanel:
            return true
        case .saveAsSnippet, .saveAsLink:
            return false
        }
    }

    init?(identifier: String) {
        guard let match = Self.allCases.first(where: { $0.identifier == identifier }) else {
            return nil
        }
        self = match
    }
}

enum GlanceActionSource: Equatable {
    case clipboard(ClipboardHistoryRecord)
    case snippet(SnippetRecord)
    case link(LinkRecord)
    case fileShelf(FileShelfRecord, resolvedURL: URL?)
}

enum GlanceActionSourceID: Equatable {
    case clipboard(UUID)
    case snippet(UUID)
    case link(UUID)
    case fileShelf(UUID)
}

enum GlanceItemActionPolicy {
    static func actions(for source: GlanceActionSource) -> [GlanceItemAction] {
        switch source {
        case .clipboard(let record):
            return clipboardActions(record)
        case .snippet:
            return [.createTextPanel]
        case .link:
            return [.createTextPanel]
        case .fileShelf(let record, let resolvedURL):
            switch FileShelfPanelSupport.kind(for: record, resolvedURL: resolvedURL) {
            case .image:
                return [.createImagePanel]
            case .pdf:
                return [.createPDFPanel]
            case nil:
                return []
            }
        }
    }

    static func allows(_ action: GlanceItemAction, for source: GlanceActionSource) -> Bool {
        actions(for: source).contains(action)
    }

    static func panelAction(for source: GlanceActionSource) -> GlanceItemAction? {
        actions(for: source).first(where: \.createsPanel)
    }

    static func secondaryActions(for source: GlanceActionSource) -> [GlanceItemAction] {
        actions(for: source).filter { !$0.createsPanel }
    }

    private static func clipboardActions(_ record: ClipboardHistoryRecord) -> [GlanceItemAction] {
        switch record.kind {
        case .text:
            guard record.text != nil else { return [] }
            var items: [GlanceItemAction] = [.createTextPanel]
            if ClipboardSnippetHandoff.isAvailable(for: record) {
                items.append(.saveAsSnippet)
            }
            if ClipboardWebLinkHandoff.isAvailable(for: record) {
                items.append(.saveAsLink)
            }
            return items
        case .image:
            return [.createImagePanel]
        }
    }
}

enum GlanceItemActionExecutor {
    static func resolve(
        _ sourceID: GlanceActionSourceID,
        dependencies: GlanceActionDependencies
    ) -> GlanceActionSource? {
        switch sourceID {
        case .clipboard(let id):
            guard let record = dependencies.clipboardRecord(id) else { return nil }
            return .clipboard(record)
        case .snippet(let id):
            guard let record = dependencies.snippet(id) else { return nil }
            return .snippet(record)
        case .link(let id):
            guard let record = dependencies.link(id) else { return nil }
            return .link(record)
        case .fileShelf(let id):
            guard let record = dependencies.fileRecord(id) else { return nil }
            let resolved = dependencies.resolveFile(id)
            let url: URL?
            if !resolved.isMissing, let path = resolved.urlPath {
                url = URL(fileURLWithPath: path)
            } else {
                url = nil
            }
            return .fileShelf(record, resolvedURL: url)
        }
    }

    static func perform(
        _ action: GlanceItemAction,
        sourceID: GlanceActionSourceID,
        screen: NSScreen?,
        dependencies: GlanceActionDependencies
    ) -> GlanceActionOutcome {
        guard let source = resolve(sourceID, dependencies: dependencies) else {
            return .failed(GlanceNoticeCopy.staleItem)
        }
        return perform(action, source: source, screen: screen, dependencies: dependencies)
    }

    static func perform(
        _ action: GlanceItemAction,
        source: GlanceActionSource,
        screen: NSScreen?,
        dependencies: GlanceActionDependencies
    ) -> GlanceActionOutcome {
        guard GlanceItemActionPolicy.allows(action, for: source) else {
            return .failed(rejectionNotice(for: action))
        }
        switch (action, source) {
        case (.createTextPanel, .clipboard(let record)):
            return createClipboardPanel(record, expected: .text, screen: screen, dependencies: dependencies)
        case (.createImagePanel, .clipboard(let record)):
            return createClipboardPanel(record, expected: .image, screen: screen, dependencies: dependencies)
        case (.saveAsSnippet, .clipboard(let record)):
            return saveClipboardSnippet(record, dependencies: dependencies)
        case (.saveAsLink, .clipboard(let record)):
            return saveClipboardLink(record, dependencies: dependencies)
        case (.createTextPanel, .snippet(let record)):
            let request = SnippetPanelHandoff.request(from: record)
            return panel(
                dependencies.createTextPanel(request.customTitle, request.content, screen)
            )
        case (.createTextPanel, .link(let record)):
            let request = LinkPanelHandoff.request(from: record)
            return panel(
                dependencies.createTextPanel(request.customTitle, request.content, screen)
            )
        case (.createImagePanel, .fileShelf(let record, let url)):
            return importFilePanel(
                record: record,
                url: url,
                expected: .image,
                screen: screen,
                dependencies: dependencies
            )
        case (.createPDFPanel, .fileShelf(let record, let url)):
            return importFilePanel(
                record: record,
                url: url,
                expected: .pdf,
                screen: screen,
                dependencies: dependencies
            )
        default:
            return .failed(rejectionNotice(for: action))
        }
    }

    private static func createClipboardPanel(
        _ record: ClipboardHistoryRecord,
        expected: ClipboardHistoryKind,
        screen: NSScreen?,
        dependencies: GlanceActionDependencies
    ) -> GlanceActionOutcome {
        guard record.kind == expected else {
            return .failed(GlanceNoticeCopy.panelCreateFailed)
        }
        guard let content = clipboardContent(record, dependencies: dependencies) else {
            return .failed(GlanceNoticeCopy.panelCreateFailed)
        }
        switch (expected, content) {
        case (.text, .text), (.image, .png):
            return panel(dependencies.createFromClipboard(content, screen))
        default:
            return .failed(GlanceNoticeCopy.panelCreateFailed)
        }
    }

    private static func clipboardContent(
        _ record: ClipboardHistoryRecord,
        dependencies: GlanceActionDependencies
    ) -> ClipboardCaptureContent? {
        if let content = dependencies.clipboardContent(record.id) {
            return content
        }
        if record.kind == .text, let text = record.text {
            return .text(text)
        }
        return nil
    }

    private static func saveClipboardSnippet(
        _ record: ClipboardHistoryRecord,
        dependencies: GlanceActionDependencies
    ) -> GlanceActionOutcome {
        guard let draft = ClipboardSnippetHandoff.draft(from: record) else {
            return .failed(GlanceNoticeCopy.cannotSave)
        }
        dependencies.dismissClipboard()
        dependencies.presentSnippetEditor(draft.content)
        return .succeeded
    }

    private static func saveClipboardLink(
        _ record: ClipboardHistoryRecord,
        dependencies: GlanceActionDependencies
    ) -> GlanceActionOutcome {
        guard let url = ClipboardWebLinkHandoff.normalizedURL(from: record) else {
            return .failed(GlanceNoticeCopy.cannotSave)
        }
        dependencies.dismissClipboard()
        dependencies.presentLinkEditor(url)
        return .succeeded
    }

    private static func importFilePanel(
        record: FileShelfRecord,
        url: URL?,
        expected: FileShelfPanelKind,
        screen: NSScreen?,
        dependencies: GlanceActionDependencies
    ) -> GlanceActionOutcome {
        guard let url else {
            return .failed(GlanceNoticeCopy.fileMissing)
        }
        guard FileShelfPanelSupport.kind(for: record, resolvedURL: url) == expected else {
            return .failed(GlanceNoticeCopy.panelCreateFailed)
        }
        let title = record.displayName
        let ok: Bool
        switch expected {
        case .image:
            ok = dependencies.importImage(url, title, screen)
        case .pdf:
            ok = dependencies.importPDF(url, title, screen)
        }
        return panel(ok)
    }

    private static func panel(_ created: Bool) -> GlanceActionOutcome {
        created ? .succeeded : .failed(GlanceNoticeCopy.panelCreateFailed)
    }

    private static func rejectionNotice(for action: GlanceItemAction) -> String {
        switch action {
        case .createTextPanel, .createTodoPanel, .createImagePanel, .createPDFPanel:
            return GlanceNoticeCopy.panelCreateFailed
        case .saveAsSnippet, .saveAsLink:
            return GlanceNoticeCopy.cannotSave
        }
    }
}
