import AppKit

enum TextPanelProvider: PanelProviding {
    static let kindIdentifier = PanelKind.text
    static let defaultSize = GlanceConstants.textDefaultSize
    static let minimumSize = GlanceConstants.textMinSize
    static let payloadVersion = GlanceConstants.payloadVersionRTF

    @MainActor
    static func makeContent() -> PanelContentControlling {
        TextPanelView()
    }
}
