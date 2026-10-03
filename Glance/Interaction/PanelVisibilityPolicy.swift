import Foundation

enum PanelVisibilityPolicy {
    static func shouldPresent(panelHidden: Bool, globallyConcealed: Bool) -> Bool {
        !panelHidden && !globallyConcealed
    }
}

enum PanelRevealPolicy {
    static func shouldPresentNewlyCreatedPanel(isGloballyConcealed: Bool) -> Bool {
        PanelVisibilityPolicy.shouldPresent(panelHidden: false, globallyConcealed: isGloballyConcealed)
    }
}

enum PanelVisibilityMenu {
    static let hideThisPanel = "隐藏此面板"
    static let hide = "隐藏"
    static let show = "显示"

    static func libraryActionTitle(isHidden: Bool) -> String {
        isHidden ? show : hide
    }

    static func symbolName(isHidden: Bool) -> String {
        isHidden ? "eye.slash" : "eye"
    }
}
