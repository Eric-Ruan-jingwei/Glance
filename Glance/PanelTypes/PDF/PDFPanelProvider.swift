import AppKit

enum PDFPanelProvider: PanelProviding {
    static let kindIdentifier = PanelKind.pdf
    static let defaultSize = GlanceConstants.pdfDefaultSize
    static let minimumSize = GlanceConstants.pdfMinSize
    static let payloadVersion = GlanceConstants.payloadVersionPDF

    @MainActor
    static func makeContent() -> PanelContentControlling {
        PDFPanelView()
    }
}
