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
