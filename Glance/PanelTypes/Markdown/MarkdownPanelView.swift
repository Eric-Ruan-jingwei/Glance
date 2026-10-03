import AppKit

@MainActor
final class MarkdownPanelView: NSView, PanelContentControlling, NSTextViewDelegate {
    var view: NSView { self }
    let minimumSize: NSSize = GlanceConstants.markdownMinSize
    var onPayloadChange: (() -> Void)?
    var onRequestEditing: (() -> Void)?
    var onRequestPreferredSize: ((NSSize) -> Void)?
    var allowsMove = true {
        didSet { textView.allowsMove = allowsMove }
    }
    var allowsContentMutation = true {
        didSet { textView.allowsContentMutation = allowsContentMutation }
    }
    var allowsKeyInReadingMode: Bool { true }

    private let scrollView = NSScrollView()
    private let textView: MarkdownPanelTextView
    private let placeholder = NSTextField(labelWithString: GlanceEmptyCopy.markdownPlaceholder)
    private var source = ""
    private var isEditing = false
    private var isApplyingContent = false

    init() {
        textView = MarkdownPanelTextView(usingTextLayoutManager: false)
        super.init(frame: .zero)
        setup()
        applyReadingPresentation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) throws {
        source = try MarkdownPayloadFile.readSource(from: directory) ?? ""
        if isEditing {
            applyEditingPresentation()
        } else {
            applyReadingPresentation()
        }
    }

    func savePayload(to directory: URL) throws {
        if isEditing {
            source = textView.string
        }
        try MarkdownPayloadFile.writeSource(source, to: directory)
    }

    func enterEditing() {
        if isEditing { return }
        isEditing = true
        applyEditingPresentation()
        window?.makeFirstResponder(textView)
    }

    func exitEditing() {
        if isEditing {
            source = textView.string
        }
        isEditing = false
        applyReadingPresentation()
    }

    func primaryEditMenuTitle() -> String? { "编辑 Markdown" }
    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingContent, isEditing else { return }
        source = textView.string
        onPayloadChange?()
        refreshPlaceholder()
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        let url: URL?
        if let value = link as? URL {
            url = value
        } else if let value = link as? String {
            url = URL(string: value)
        } else {
            url = nil
        }
        guard let url else { return false }
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" || scheme == "mailto" else {
            return false
        }
        NSWorkspace.shared.open(url)
        return true
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        textView.delegate = self
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = GlanceTheme.Size.readingInset
        textView.defaultParagraphStyle = GlanceTheme.Reading.bodyParagraphStyle()
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.insertionPointColor = .labelColor
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.onBeginEditing = { [weak self] in self?.onRequestEditing?() }
        textView.onRequestEndEditing = { [weak self] in
            self?.exitEditing()
            NSApp.deactivate()
        }

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.stringValue = GlanceEmptyCopy.markdownPlaceholder
        placeholder.font = GlanceTheme.Typography.placeholder
        placeholder.textColor = .tertiaryLabelColor
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isEditable = false
        placeholder.isBordered = false
        placeholder.drawsBackground = false

        addSubview(scrollView)
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholder.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: GlanceTheme.Size.readingInset.width + 4
            ),
            placeholder.topAnchor.constraint(
                equalTo: topAnchor,
                constant: GlanceTheme.Size.readingInset.height
            )
        ])
    }

    private func applyReadingPresentation() {
        isApplyingContent = true
        textView.isReadingMode = true
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.textStorage?.setAttributedString(MarkdownPreviewAppearance.nsAttributedString(from: source))
        isApplyingContent = false
        refreshPlaceholder()
    }

    private func applyEditingPresentation() {
        isApplyingContent = true
        textView.isReadingMode = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = GlanceTheme.Typography.markdownEdit
        textView.textColor = NSColor.labelColor
        textView.defaultParagraphStyle = GlanceTheme.Reading.bodyParagraphStyle()
        textView.string = source
        isApplyingContent = false
        placeholder.isHidden = true
    }

    private func refreshPlaceholder() {
        let empty = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        placeholder.isHidden = !empty || isEditing
    }
}
