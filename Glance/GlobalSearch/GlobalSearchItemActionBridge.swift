import Foundation

enum GlobalSearchItemActionBridge {
    static func sourceID(for resultID: GlobalSearchResultID) -> GlanceActionSourceID? {
        switch resultID.source {
        case .clipboard:
            return .clipboard(resultID.itemID)
        case .fileShelf:
            return .fileShelf(resultID.itemID)
        case .snippets:
            return .snippet(resultID.itemID)
        case .links:
            return .link(resultID.itemID)
        case .panels:
            return nil
        }
    }
}

struct GlobalSearchResultActions: Equatable {
    var canReveal: Bool
    var itemActions: [GlanceItemAction]

    static func compose(
        resultID: GlobalSearchResultID,
        canReveal: Bool = true,
        itemActionsFor: (GlanceActionSourceID) -> [GlanceItemAction]
    ) -> GlobalSearchResultActions {
        let items: [GlanceItemAction]
        if let sourceID = GlobalSearchItemActionBridge.sourceID(for: resultID) {
            items = itemActionsFor(sourceID)
        } else {
            items = []
        }
        return GlobalSearchResultActions(canReveal: canReveal, itemActions: items)
    }
}

enum GlobalSearchItemActionSessionPolicy {
    static func shouldDismiss(
        after action: GlanceItemAction,
        outcome: GlanceActionOutcome
    ) -> Bool {
        guard case .succeeded = outcome else {
            return false
        }
        return action.createsPanel
    }
}
