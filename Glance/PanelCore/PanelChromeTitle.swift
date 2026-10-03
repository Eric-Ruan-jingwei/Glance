import Foundation

enum PanelChromeTitle {
    /// Presentation-only chrome title. Never writes `customTitle` or other persisted fields.
    static func resolved(
        customTitle: String?,
        automaticTitle: String?,
        kindIdentifier: String
    ) -> String {
        if let custom = PanelTitle.normalize(customTitle) {
            return custom
        }
        if let automatic = PanelTitle.normalize(automaticTitle) {
            return automatic
        }
        return PanelSummaryKindLabel.displayName(for: kindIdentifier)
    }
}

enum TextFormatBarLayout {
    static func scrollTopInset(isEditing: Bool) -> CGFloat {
        isEditing ? GlanceTheme.Size.formatBarHeight : 0
    }
}
