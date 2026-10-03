import Foundation

enum GlobalSearchActionKind: Equatable {
    case restoreClipboard
    case openFile
    case copySnippet
    case openLink
    case revealPanel
}

enum GlobalSearchActionPlan: Equatable {
    case run(GlobalSearchActionKind, deactivateApp: Bool)
    case fail(String)
}

enum GlobalSearchActionResult: Equatable {
    case succeeded(deactivateApp: Bool)
    case failed(String)
}

enum GlobalSearchActionPlanner {
    static func plan(
        source: GlobalSearchSource,
        globallyConcealed: Bool
    ) -> GlobalSearchActionPlan {
        switch source {
        case .clipboard:
            return .run(.restoreClipboard, deactivateApp: true)
        case .fileShelf:
            return .run(.openFile, deactivateApp: true)
        case .snippets:
            return .run(.copySnippet, deactivateApp: true)
        case .links:
            return .run(.openLink, deactivateApp: true)
        case .panels:
            if globallyConcealed {
                return .fail(GlobalSearchCopy.globallyHidden)
            }
            return .run(.revealPanel, deactivateApp: false)
        }
    }
}

struct GlobalSearchPanelLookup: Equatable {
    var workspaceID: String
}

struct GlobalSearchActionDependencies {
    var restoreClipboard: (UUID) -> Bool
    var openFile: (UUID) -> Bool
    var copySnippet: (UUID) -> Bool
    var openLink: (UUID) -> Bool
    var lookupPanel: (UUID) -> GlobalSearchPanelLookup?
    var activeWorkspaceID: () -> String
    var switchWorkspace: (String) -> Bool
    var revealPanel: (UUID) -> Bool
}

enum GlobalSearchRevealTarget: Equatable {
    case clipboard(UUID)
    case fileShelf(UUID)
    case snippets(UUID)
    case links(UUID)
    case panels(UUID)
}

enum GlobalSearchRevealPlan: Equatable {
    case reveal(GlobalSearchRevealTarget)
    case failed(String)
}

enum GlobalSearchRevealRouter {
    static func plan(
        id: GlobalSearchResultID,
        clipboardExists: (UUID) -> Bool,
        fileExists: (UUID) -> Bool,
        snippetExists: (UUID) -> Bool,
        linkExists: (UUID) -> Bool,
        panelExists: (UUID) -> Bool
    ) -> GlobalSearchRevealPlan {
        let exists: Bool
        switch id.source {
        case .clipboard:
            exists = clipboardExists(id.itemID)
        case .fileShelf:
            exists = fileExists(id.itemID)
        case .snippets:
            exists = snippetExists(id.itemID)
        case .links:
            exists = linkExists(id.itemID)
        case .panels:
            exists = panelExists(id.itemID)
        }
        guard exists else {
            return .failed(GlanceNoticeCopy.staleItem)
        }
        switch id.source {
        case .clipboard:
            return .reveal(.clipboard(id.itemID))
        case .fileShelf:
            return .reveal(.fileShelf(id.itemID))
        case .snippets:
            return .reveal(.snippets(id.itemID))
        case .links:
            return .reveal(.links(id.itemID))
        case .panels:
            return .reveal(.panels(id.itemID))
        }
    }
}

enum GlobalSearchActionRouter {
    static func perform(
        id: GlobalSearchResultID,
        globallyConcealed: Bool,
        using dependencies: GlobalSearchActionDependencies
    ) -> GlobalSearchActionResult {
        switch GlobalSearchActionPlanner.plan(source: id.source, globallyConcealed: globallyConcealed) {
        case .fail(let notice):
            return .failed(notice)
        case .run(let kind, let deactivate):
            let ok: Bool
            switch kind {
            case .restoreClipboard:
                ok = dependencies.restoreClipboard(id.itemID)
            case .openFile:
                ok = dependencies.openFile(id.itemID)
            case .copySnippet:
                ok = dependencies.copySnippet(id.itemID)
            case .openLink:
                ok = dependencies.openLink(id.itemID)
            case .revealPanel:
                guard let panel = dependencies.lookupPanel(id.itemID) else {
                    return .failed(GlobalSearchCopy.panelMissing)
                }
                if panel.workspaceID != dependencies.activeWorkspaceID() {
                    guard dependencies.switchWorkspace(panel.workspaceID) else {
                        return .failed(GlobalSearchCopy.panelMissing)
                    }
                }
                ok = dependencies.revealPanel(id.itemID)
            }
            if ok {
                return .succeeded(deactivateApp: deactivate)
            }
            return .failed(failureNotice(for: kind))
        }
    }

    private static func failureNotice(for kind: GlobalSearchActionKind) -> String {
        switch kind {
        case .restoreClipboard: return GlobalSearchCopy.clipboardMissing
        case .openFile: return GlobalSearchCopy.fileMissing
        case .copySnippet: return GlobalSearchCopy.snippetMissing
        case .openLink: return GlobalSearchCopy.linkFailed
        case .revealPanel: return GlobalSearchCopy.panelMissing
        }
    }
}
