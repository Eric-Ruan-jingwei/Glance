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

    private let pdfView = PDFView()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init() {
        super.init(frame: .zero)
        setup()
        showErrorPlaceholder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) throws {
        let documentURL = PDFPayloadFile.documentURL(in: directory)
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            showErrorPlaceholder()
            return
        }
        guard let document = PDFDocument(url: documentURL), document.pageCount > 0, !document.isLocked else {
            showErrorPlaceholder()
            return
        }
        showDocument(document)
    }

    func savePayload(to directory: URL) throws {}

    func enterEditing() {}
    func exitEditing() {}
    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }

    private func setup() {
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.alignment = .center
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(pdfView)
        addSubview(errorLabel)

        let topInset = GlanceConstants.panelDragStrip
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor, constant: topInset),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            errorLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    private func showDocument(_ document: PDFDocument) {
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.goToFirstPage(nil)
        pdfView.isHidden = false
        errorLabel.isHidden = true
        isShowingError = false
        loadedPageCount = document.pageCount
    }

    private func showErrorPlaceholder() {
        pdfView.document = nil
        pdfView.isHidden = true
        errorLabel.stringValue = "无法读取 PDF\n原文件仍保存在 Glance 数据目录中。"
        errorLabel.isHidden = false
        isShowingError = true
        loadedPageCount = 0
    }
}
