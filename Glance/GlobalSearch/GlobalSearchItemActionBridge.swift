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

enum GlobalSearchResultMenu {
    enum Item: Equatable, Identifiable {
        case reveal
        case divider
        case action(GlanceItemAction)

        var id: String {
            switch self {
            case .reveal:
                return "reveal"
            case .divider:
                return "divider"
            case .action(let action):
                return "action.\(action.identifier)"
            }
        }

        var symbolName: String? {
            switch self {
            case .reveal:
                return GlanceActionSymbol.revealInSource
            case .divider:
                return nil
            case .action(let action):
                return action.symbolName
            }
        }
    }

    static func items(itemActions: () -> [GlanceItemAction]) -> [Item] {
        var result: [Item] = [.reveal]
        let actions = itemActions()
        if !actions.isEmpty {
            result.append(.divider)
            result.append(contentsOf: actions.map { .action($0) })
        }
        return result
    }
}

enum GlobalSearchRowActionPresentation {
    static let trailingKind = GlanceRowQuickActionLayout.Kind.globalSearch
    static var trailingWidth: CGFloat { trailingKind.width }
    static let sourceIconSide: CGFloat = 28

    static func showsEllipsis(isHovered: Bool, isSelected: Bool) -> Bool {
        GlanceRowQuickActionVisibility.showsSecondary(
            isHovered: isHovered,
            isSelected: isSelected
        )
    }

    static func moreHelp(title: String) -> String {
        GlanceRowActionCopy.moreHelp(for: title)
    }
}
