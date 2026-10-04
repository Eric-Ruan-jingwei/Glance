import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum GlanceItemDropDestination: Equatable {
    case snippets
    case links
    case panels
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

    func cachedAction(
        for sourceID: GlanceActionSourceID,
        destination: GlanceItemDropDestination
    ) -> GlanceItemAction? {
        guard cachedSourceID == sourceID, cachedDestination == destination else {
            return nil
        }
        return cachedAction
    }

    func reset() {
        cachedSourceID = nil
        cachedDestination = nil
        cachedAction = nil
    }
}

enum GlanceItemDropRunner {
    static func hoverHighlight(
        targeted: Bool,
        destination: GlanceItemDropDestination,
        session: GlanceItemDropSession,
        availableActions: (GlanceActionSourceID) -> [GlanceItemAction]
    ) -> Bool {
        guard targeted else {
            session.reset()
            return false
        }
        guard let sourceID = GlanceItemDragCodec.sourceID(from: NSPasteboard(name: .drag)) else {
            return false
        }
        return session.plannedAction(
            sourceID: sourceID,
            destination: destination,
            availableActions: availableActions
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
        let live = GlanceItemDropPolicy.action(
            for: sourceID,
            destination: destination,
            availableActions: availableActions(sourceID)
        )
        let action = live ?? session.cachedAction(for: sourceID, destination: destination)
        session.reset()
        guard let action else { return nil }
        return perform(action, sourceID, screen)
    }

    static func handleProviders(
        _ providers: [NSItemProvider],
        destination: GlanceItemDropDestination,
        session: GlanceItemDropSession,
        availableActions: @escaping (GlanceActionSourceID) -> [GlanceItemAction],
        perform: @escaping (GlanceItemAction, GlanceActionSourceID, NSScreen?) -> GlanceActionOutcome,
        screen: NSScreen?,
        onFailed: @escaping (String) -> Void
    ) -> Bool {
        guard GlanceItemDragCodec.hasInternalPayload(providers) else { return false }
        GlanceItemDragCodec.load(from: providers) { sourceID in
            guard let sourceID else { return }
            let outcome = drop(
                sourceID: sourceID,
                destination: destination,
                session: session,
                availableActions: availableActions,
                perform: perform,
                screen: screen
            )
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
