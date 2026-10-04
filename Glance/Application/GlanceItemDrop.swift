import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum GlanceItemDropDestination: Equatable {
    case snippets
    case links
    case panels
}

struct GlanceAcceptedDropPlan: Equatable {
    var sourceID: GlanceActionSourceID
    var destination: GlanceItemDropDestination
    var action: GlanceItemAction
}

enum GlanceItemDropPolicy {
    static func action(
        for _: GlanceActionSourceID,
        destination: GlanceItemDropDestination,
        availableActions: [GlanceItemAction]
    ) -> GlanceItemAction? {
        switch destination {
        case .snippets:
            return availableActions.contains(.saveAsSnippet) ? .saveAsSnippet : nil
        case .links:
            return availableActions.contains(.saveAsLink) ? .saveAsLink : nil
        case .panels:
            if availableActions.contains(.createTextPanel) {
                return .createTextPanel
            }
            if availableActions.contains(.createImagePanel) {
                return .createImagePanel
            }
            if availableActions.contains(.createPDFPanel) {
                return .createPDFPanel
            }
            return nil
        }
    }
}

final class GlanceItemDropSession {
    private var cachedSourceID: GlanceActionSourceID?
    private var cachedDestination: GlanceItemDropDestination?
    private var cachedAction: GlanceItemAction?
    private var acceptedPlan: GlanceAcceptedDropPlan?

    func plannedAction(
        sourceID: GlanceActionSourceID,
        destination: GlanceItemDropDestination,
        availableActions: (GlanceActionSourceID) -> [GlanceItemAction]
    ) -> GlanceItemAction? {
        if cachedSourceID == sourceID, cachedDestination == destination {
            return cachedAction
        }
        let action = GlanceItemDropPolicy.action(
            for: sourceID,
            destination: destination,
            availableActions: availableActions(sourceID)
        )
        cachedSourceID = sourceID
        cachedDestination = destination
        cachedAction = action
        return action
    }

    func cachedSourceID(for destination: GlanceItemDropDestination) -> GlanceActionSourceID? {
        guard cachedDestination == destination else { return nil }
        return cachedSourceID
    }

    func cachedAction(
        for sourceID: GlanceActionSourceID,
        destination: GlanceItemDropDestination
    ) -> GlanceItemAction? {
        guard cachedSourceID == sourceID, cachedDestination == destination else {
            return nil
        }
        return cachedAction
    }

    func captureAcceptedPlan(_ plan: GlanceAcceptedDropPlan) {
        acceptedPlan = plan
    }

    func currentAcceptedPlan() -> GlanceAcceptedDropPlan? {
        acceptedPlan
    }

    func resetHover() {
        cachedSourceID = nil
        cachedDestination = nil
        cachedAction = nil
    }

    func reset() {
        resetHover()
        acceptedPlan = nil
    }
}

enum GlanceItemDropRunner {
    static func hoverHighlight(
        targeted: Bool,
        destination: GlanceItemDropDestination,
        session: GlanceItemDropSession,
        availableActions: (GlanceActionSourceID) -> [GlanceItemAction],
        pasteboard: NSPasteboard = NSPasteboard(name: .drag)
    ) -> Bool {
        guard targeted else {
            session.resetHover()
            return false
        }
        guard let sourceID = GlanceItemDragCodec.sourceIDIfSynchronouslyAvailable(
            pasteboard: pasteboard
        ) else {
            session.resetHover()
            return false
        }
        return session.plannedAction(
            sourceID: sourceID,
            destination: destination,
            availableActions: availableActions
        ) != nil
    }

    static func acceptedPlan(
        providers: [NSItemProvider],
        destination: GlanceItemDropDestination,
        session: GlanceItemDropSession,
        availableActions: (GlanceActionSourceID) -> [GlanceItemAction],
        pasteboard: NSPasteboard = NSPasteboard(name: .drag)
    ) -> GlanceAcceptedDropPlan? {
        guard GlanceItemDragCodec.hasInternalPayload(providers) else {
            return nil
        }
        let sourceID: GlanceActionSourceID?
        if GlanceItemDragCodec.pasteboardHasInternalItem(pasteboard) {
            sourceID = GlanceItemDragCodec.sourceID(from: pasteboard)
        } else {
            sourceID = session.cachedSourceID(for: destination)
        }
        guard let sourceID else {
            return nil
        }
        guard let action = session.plannedAction(
            sourceID: sourceID,
            destination: destination,
            availableActions: availableActions
        ) else {
            return nil
        }
        let plan = GlanceAcceptedDropPlan(
            sourceID: sourceID,
            destination: destination,
            action: action
        )
        session.captureAcceptedPlan(plan)
        return plan
    }

    static func accepts(
        providers: [NSItemProvider],
        destination: GlanceItemDropDestination,
        session: GlanceItemDropSession,
        availableActions: (GlanceActionSourceID) -> [GlanceItemAction],
        pasteboard: NSPasteboard = NSPasteboard(name: .drag)
    ) -> Bool {
        acceptedPlan(
            providers: providers,
            destination: destination,
            session: session,
            availableActions: availableActions,
            pasteboard: pasteboard
        ) != nil
    }

    static func drop(
        sourceID: GlanceActionSourceID,
        destination: GlanceItemDropDestination,
        session: GlanceItemDropSession,
        availableActions: (GlanceActionSourceID) -> [GlanceItemAction],
        perform: (GlanceItemAction, GlanceActionSourceID, NSScreen?) -> GlanceActionOutcome,
        screen: NSScreen?
    ) -> GlanceActionOutcome? {
        defer {
            session.reset()
        }
        guard let action = GlanceItemDropPolicy.action(
            for: sourceID,
            destination: destination,
            availableActions: availableActions(sourceID)
        ) else {
            return nil
        }
        return perform(action, sourceID, screen)
    }

    static func handleProviders(
        _ providers: [NSItemProvider],
        destination: GlanceItemDropDestination,
        session: GlanceItemDropSession,
        availableActions: @escaping (GlanceActionSourceID) -> [GlanceItemAction],
        perform: @escaping (GlanceItemAction, GlanceActionSourceID, NSScreen?) -> GlanceActionOutcome,
        screen: NSScreen?,
        onFailed: @escaping (String) -> Void,
        pasteboard: NSPasteboard = NSPasteboard(name: .drag),
        loadSourceID: @escaping ([NSItemProvider], @escaping (GlanceActionSourceID?) -> Void) -> Void = { providers, completion in
            GlanceItemDragCodec.load(from: providers, completion: completion)
        }
    ) -> Bool {
        guard let plan = acceptedPlan(
            providers: providers,
            destination: destination,
            session: session,
            availableActions: availableActions,
            pasteboard: pasteboard
        ) else {
            return false
        }
        loadSourceID(providers) { decodedID in
            defer {
                session.reset()
            }
            guard let decodedID else {
                NSSound.beep()
                onFailed(GlanceNoticeCopy.staleItem)
                return
            }
            guard decodedID == plan.sourceID else {
                NSSound.beep()
                onFailed(GlanceNoticeCopy.staleItem)
                return
            }
            let outcome = drop(
                sourceID: decodedID,
                destination: plan.destination,
                session: session,
                availableActions: availableActions,
                perform: perform,
                screen: screen
            )
            if outcome == nil {
                NSSound.beep()
                onFailed(GlanceNoticeCopy.staleItem)
                return
            }
            if case .failed(let message)? = outcome {
                NSSound.beep()
                onFailed(message)
            }
        }
        return true
    }
}

struct GlanceDropHighlight: View {
    var isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: GlanceTheme.Radius.panel, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(isActive ? 0.7 : 0), lineWidth: 2)
            .padding(4)
            .allowsHitTesting(false)
    }
}
