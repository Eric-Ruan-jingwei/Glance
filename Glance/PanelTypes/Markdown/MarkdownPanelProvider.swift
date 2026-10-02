import AppKit

enum MarkdownPanelProvider: PanelProviding {
    static let kindIdentifier = PanelKind.markdown
    static let defaultSize = GlanceConstants.markdownDefaultSize
    static let minimumSize = GlanceConstants.markdownMinSize
    static let payloadVersion = GlanceConstants.payloadVersionMarkdown

    @MainActor
    static func makeContent() -> PanelContentControlling {
        MarkdownPanelView()
    }
}
