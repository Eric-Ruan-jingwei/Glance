import AppKit
import PDFKit

@MainActor
final class PDFPanelView: NSView, PanelContentControlling {
    var view: NSView { self }
    let minimumSize: NSSize = GlanceConstants.pdfMinSize
    var onPayloadChange: (() -> Void)?
    var onRequestEditing: (() -> Void)?
    var onRequestPreferredSize: ((NSSize) -> Void)?
    var allowsMove = true
    var allowsContentMutation = true
    var allowsKeyInReadingMode: Bool { true }

    private(set) var isShowingError = false
    private(set) var loadedPageCount = 0
    private var cachedDisplayName: String?

    private let pdfView = PDFView()
    private let placeholder = GlanceMessagePlaceholder()

    init() {
        super.init(frame: .zero)
        setup()
        showMissing()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) throws {
        cachedDisplayName = nil
        let documentURL = PDFPayloadFile.documentURL(in: directory)
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            showMissing()
            return
        }
        if let metadata = try? PDFPayloadFile.readMetadata(from: directory) {
            cachedDisplayName = metadata.displayName
        }
        guard let document = PDFDocument(url: documentURL), document.pageCount > 0, !document.isLocked else {
            cachedDisplayName = nil
            showUnreadable()
            return
        }
        showDocument(document)
    }

    func savePayload(to directory: URL) throws {}

    func enterEditing() {}
    func exitEditing() {}
    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }

    var automaticDisplayTitle: String? {
        cachedDisplayName.map(PanelSummaryText.pdfTitle(from:))
    }

    private func setup() {
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        pdfView.pageShadowsEnabled = false
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.translatesAutoresizingMaskIntoConstraints = false

        addSubview(pdfView)
        addSubview(placeholder)

        let inset = GlanceTheme.Size.mediaInset
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            pdfView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: topAnchor),
            placeholder.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func showDocument(_ document: PDFDocument) {
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.goToFirstPage(nil)
        pdfView.isHidden = false
        placeholder.isHidden = true
        isShowingError = false
        loadedPageCount = document.pageCount
    }

    private func showMissing() {
        pdfView.document = nil
        pdfView.isHidden = true
        placeholder.apply(
            symbol: "doc.richtext",
            title: GlanceEmptyCopy.pdfEmptyTitle,
            detail: GlanceEmptyCopy.pdfEmptyDetail
        )
        placeholder.isHidden = false
        isShowingError = true
        loadedPageCount = 0
    }

    private func showUnreadable() {
        pdfView.document = nil
        pdfView.isHidden = true
        placeholder.apply(
            symbol: "exclamationmark.triangle",
            title: GlanceEmptyCopy.pdfUnreadableTitle,
            detail: GlanceEmptyCopy.pdfUnreadableDetail
        )
        placeholder.isHidden = false
        isShowingError = true
        loadedPageCount = 0
    }
}
