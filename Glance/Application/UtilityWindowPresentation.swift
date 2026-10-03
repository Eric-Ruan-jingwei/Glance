import AppKit

enum UtilityWindowHandoff: Equatable {
    case returnToFrontApp
    case stayInGlance
    case yieldToExternal

    var shouldDeactivate: Bool {
        self == .returnToFrontApp
    }
}

enum UtilityWindowHandoffPolicy {
    static func afterPrimarySearchAction(source: GlobalSearchSource) -> UtilityWindowHandoff {
        switch source {
        case .clipboard, .snippets:
            return .returnToFrontApp
        case .fileShelf, .links:
            return .yieldToExternal
        case .panels:
            return .stayInGlance
        }
    }

    static func afterRevealInSource() -> UtilityWindowHandoff {
        .stayInGlance
    }

    static func afterCreatePanel() -> UtilityWindowHandoff {
        .stayInGlance
    }

    static func afterCopy() -> UtilityWindowHandoff {
        .returnToFrontApp
    }
}

enum UtilityWindowToggleAction: Equatable {
    case present
    case dismiss
    case bringForward
}

enum UtilityWindowPresentation {
    static func toggleAction(isVisible: Bool, isKey: Bool) -> UtilityWindowToggleAction {
        guard isVisible else { return .present }
        return isKey ? .dismiss : .bringForward
    }

    static func toggleAction(for window: NSWindow?) -> UtilityWindowToggleAction {
        toggleAction(isVisible: window?.isVisible == true, isKey: window?.isKeyWindow == true)
    }

    static func present(_ window: NSWindow?, size: NSSize) {
        positionOnWorkingScreen(window, size: size)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static func bringForward(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static func dismiss(_ window: NSWindow?, deactivate: Bool) {
        window?.orderOut(nil)
        if deactivate {
            NSApp.deactivate()
        }
    }

    static func positionOnWorkingScreen(_ window: NSWindow?, size: NSSize) {
        let screen = DisplayManager.screenContainingMouse()
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + visible.height * 0.08
        window?.setFrame(
            NSRect(x: x, y: max(visible.minY, y), width: size.width, height: size.height),
            display: true
        )
    }
}
