import AppKit

enum ImagePanelProvider: PanelProviding {
    static let kindIdentifier = PanelKind.image
    static let defaultSize = NSSize(width: 400, height: 300)
    static let minimumSize = GlanceConstants.imageMinSize
    static let payloadVersion = GlanceConstants.payloadVersionImage

    @MainActor
    static func makeContent() -> PanelContentControlling {
        ImagePanelView()
    }
}
