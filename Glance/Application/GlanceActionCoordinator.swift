import AppKit

@MainActor
protocol GlanceWindowHost: AnyObject {
    func presentClipboard(selecting id: UUID) -> Bool
    func presentFileShelf(selecting id: UUID) -> Bool
    func presentSnippets(selecting id: UUID) -> Bool
    func presentLinks(selecting id: UUID) -> Bool
    func presentPanelLibrary(selecting id: UUID) -> Bool
    func presentSnippetEditor(prefilled text: String)
    func presentLinkEditor(prefilledURL urlString: String)
    func dismissClipboardIfVisible()
}

struct GlanceActionDependencies {
    var createTextPanel: (String?, String, NSScreen?) -> Bool
    var importImage: (URL, String?, NSScreen?) -> Bool
    var importPDF: (URL, String?, NSScreen?) -> Bool
    var createFromClipboard: (ClipboardCaptureContent, NSScreen?) -> Bool
    var snippet: (UUID) -> SnippetRecord?
    var link: (UUID) -> LinkRecord?
    var fileRecord: (UUID) -> FileShelfRecord?
    var resolveFile: (UUID) -> FileShelfResolvedReference
    var clipboardRecord: (UUID) -> ClipboardHistoryRecord?
    var clipboardContent: (UUID) -> ClipboardCaptureContent?
    var clipboardExists: (UUID) -> Bool
    var panelExists: (UUID) -> Bool
    var presentClipboard: (UUID) -> Bool
    var presentFileShelf: (UUID) -> Bool
    var presentSnippets: (UUID) -> Bool
    var presentLinks: (UUID) -> Bool
    var presentPanelLibrary: (UUID) -> Bool
    var presentSnippetEditor: (String) -> Void
    var presentLinkEditor: (String) -> Void
    var dismissClipboard: () -> Void
}

@MainActor
final class GlanceActionCoordinator {
    private let dependencies: GlanceActionDependencies

    init(dependencies: GlanceActionDependencies) {
        self.dependencies = dependencies
    }

    convenience init(
        environment: AppEnvironment,
        panelManager: PanelManager,
        windowHost: GlanceWindowHost
    ) {
        self.init(
            dependencies: .live(
                environment: environment,
                panelManager: panelManager,
                windowHost: windowHost
            )
        )
    }

    func availableActions(for sourceID: GlanceActionSourceID) -> [GlanceItemAction] {
        guard let source = GlanceItemActionExecutor.resolve(sourceID, dependencies: dependencies) else {
            return []
        }
        return GlanceItemActionPolicy.actions(for: source)
    }

    @discardableResult
    func perform(
        _ action: GlanceItemAction,
        sourceID: GlanceActionSourceID,
        screen: NSScreen?
    ) -> GlanceActionOutcome {
        GlanceItemActionExecutor.perform(
            action,
            sourceID: sourceID,
            screen: screen,
            dependencies: dependencies
        )
    }

    @discardableResult
    func perform(
        _ action: GlanceItemAction,
        source: GlanceActionSource,
        screen: NSScreen?
    ) -> GlanceActionOutcome {
        GlanceItemActionExecutor.perform(
            action,
            source: source,
            screen: screen,
            dependencies: dependencies
        )
    }

    @discardableResult
    func createPanel(
        fromClipboard content: ClipboardCaptureContent,
        screen: NSScreen?
    ) -> Bool {
        dependencies.createFromClipboard(content, screen)
    }

    func saveClipboardTextAsSnippet(_ text: String) {
        dependencies.dismissClipboard()
        dependencies.presentSnippetEditor(text)
    }

    func saveClipboardTextAsLink(_ urlString: String) {
        dependencies.dismissClipboard()
        dependencies.presentLinkEditor(urlString)
    }

    func createPanel(from snippet: SnippetRecord, screen: NSScreen?) -> GlanceActionOutcome {
        perform(.createTextPanel, source: .snippet(snippet), screen: screen)
    }

    func createPanel(fromSnippetID id: UUID, screen: NSScreen?) -> GlanceActionOutcome {
        perform(.createTextPanel, sourceID: .snippet(id), screen: screen)
    }

    func createPanel(from link: LinkRecord, screen: NSScreen?) -> GlanceActionOutcome {
        perform(.createTextPanel, source: .link(link), screen: screen)
    }

    func createPanel(fromLinkID id: UUID, screen: NSScreen?) -> GlanceActionOutcome {
        perform(.createTextPanel, sourceID: .link(id), screen: screen)
    }

    func createPanel(fromFileShelfID id: UUID, screen: NSScreen?) -> GlanceActionOutcome {
        guard let record = dependencies.fileRecord(id) else {
            return .failed(GlanceNoticeCopy.staleItem)
        }
        let resolved = dependencies.resolveFile(id)
        guard !resolved.isMissing, let path = resolved.urlPath else {
            return .failed(GlanceNoticeCopy.fileMissing)
        }
        let source = GlanceActionSource.fileShelf(
            record,
            resolvedURL: URL(fileURLWithPath: path)
        )
        guard let action = GlanceItemActionPolicy.panelAction(for: source) else {
            return .failed(GlanceNoticeCopy.panelCreateFailed)
        }
        return perform(action, source: source, screen: screen)
    }

    func revealInSource(_ id: GlobalSearchResultID) -> GlanceActionOutcome {
        switch GlobalSearchRevealRouter.plan(
            id: id,
            clipboardExists: dependencies.clipboardExists,
            fileExists: { self.dependencies.fileRecord($0) != nil },
            snippetExists: { self.dependencies.snippet($0) != nil },
            linkExists: { self.dependencies.link($0) != nil },
            panelExists: dependencies.panelExists
        ) {
        case .failed(let message):
            return .failed(message)
        case .reveal(let target):
            let presented: Bool
            switch target {
            case .clipboard(let itemID):
                presented = dependencies.presentClipboard(itemID)
            case .fileShelf(let itemID):
                presented = dependencies.presentFileShelf(itemID)
            case .snippets(let itemID):
                presented = dependencies.presentSnippets(itemID)
            case .links(let itemID):
                presented = dependencies.presentLinks(itemID)
            case .panels(let itemID):
                presented = dependencies.presentPanelLibrary(itemID)
            }
            return presented ? .succeeded : .failed(GlanceNoticeCopy.staleItem)
        }
    }
}

extension GlanceActionDependencies {
    @MainActor
    static func live(
        environment: AppEnvironment,
        panelManager: PanelManager,
        windowHost: GlanceWindowHost
    ) -> GlanceActionDependencies {
        GlanceActionDependencies(
            createTextPanel: { title, content, screen in
                panelManager.createTextPanel(
                    title: title,
                    content: content,
                    preferredScreen: screen
                )
            },
            importImage: { url, title, screen in
                panelManager.importImage(
                    from: url,
                    customTitle: title,
                    preferredScreen: screen
                )
            },
            importPDF: { url, title, screen in
                do {
                    try panelManager.importPDF(
                        from: url,
                        customTitle: title,
                        preferredScreen: screen
                    )
                    return true
                } catch {
                    return false
                }
            },
            createFromClipboard: { content, screen in
                panelManager.createPanel(fromClipboardContent: content, preferredScreen: screen)
            },
            snippet: { id in
                environment.snippetService.records.first { $0.id == id }
            },
            link: { id in
                environment.linkService.records.first { $0.id == id }
            },
            fileRecord: { id in
                environment.fileShelfService.records.first { $0.id == id }
            },
            resolveFile: { id in
                environment.fileShelfService.resolve(id, allowCache: false)
            },
            clipboardRecord: { id in
                environment.clipboardHistoryService.records.first { $0.id == id }
            },
            clipboardContent: { id in
                environment.clipboardHistoryService.content(for: id)
            },
            clipboardExists: { id in
                environment.clipboardHistoryService.records.contains { $0.id == id }
            },
            panelExists: { id in
                (try? environment.repository.record(id: id)) != nil
            },
            presentClipboard: { [weak windowHost] id in
                windowHost?.presentClipboard(selecting: id) ?? false
            },
            presentFileShelf: { [weak windowHost] id in
                windowHost?.presentFileShelf(selecting: id) ?? false
            },
            presentSnippets: { [weak windowHost] id in
                windowHost?.presentSnippets(selecting: id) ?? false
            },
            presentLinks: { [weak windowHost] id in
                windowHost?.presentLinks(selecting: id) ?? false
            },
            presentPanelLibrary: { [weak windowHost] id in
                windowHost?.presentPanelLibrary(selecting: id) ?? false
            },
            presentSnippetEditor: { [weak windowHost] text in
                windowHost?.presentSnippetEditor(prefilled: text)
            },
            presentLinkEditor: { [weak windowHost] url in
                windowHost?.presentLinkEditor(prefilledURL: url)
            },
            dismissClipboard: { [weak windowHost] in
                windowHost?.dismissClipboardIfVisible()
            }
        )
    }
}
