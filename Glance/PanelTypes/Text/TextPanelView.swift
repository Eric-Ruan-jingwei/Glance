import AppKit

@MainActor
final class TextPanelView: NSView, PanelContentControlling, NSTextViewDelegate {
    var view: NSView { self }
    let minimumSize: NSSize = GlanceConstants.textMinSize
    var onPayloadChange: (() -> Void)?
    var onRequestEditing: (() -> Void)?
    var onRequestPreferredSize: ((NSSize) -> Void)?
    var allowsMove = true {
        didSet { textView.allowsMove = allowsMove }
    }
    var allowsContentMutation = true {
        didSet { textView.allowsContentMutation = allowsContentMutation }
    }

    private let formatChrome = FormatBarChrome()
    private let formatBar = NSStackView()
    private let formatSeparator = NSView()
    private let scrollView = NSScrollView()
    private let textView: GlanceTextView
    private let placeholder = NSTextField(labelWithString: GlanceEmptyCopy.textPlaceholder)

    init() {
        textView = GlanceTextView(usingTextLayoutManager: false)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) throws {
        if let attributed = try TextPayloadFile.readAttributedString(from: directory) {
            textView.textStorage?.setAttributedString(attributed)
        }
        refreshPlaceholder()
    }

    func savePayload(to directory: URL) throws {
        let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        let url = directory.appendingPathComponent("content.rtf")
        guard let data = textView.rtf(from: range) else {
            throw PayloadStoreError.writeFailed(url, TextPayloadError.rtfEncodingFailed)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PayloadStoreError.writeFailed(url, error)
        }
    }

    func enterEditing() {
        textView.isReadingMode = false
        textView.isEditable = true
        textView.isSelectable = true
        applyFormatBar(visible: true)
        placeholder.isHidden = true
        window?.makeFirstResponder(textView)
    }

    func exitEditing() {
        textView.isReadingMode = true
        textView.isEditable = false
        textView.isSelectable = true
        applyFormatBar(visible: false)
        refreshPlaceholder()
    }

    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }
    func primaryEditMenuTitle() -> String? { "编辑" }

    var automaticDisplayTitle: String? {
        PanelSummaryText.firstNonEmptyLine(textView.string)
    }

    func textDidChange(_ notification: Notification) {
        refreshPlaceholder()
        onPayloadChange?()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        formatChrome.translatesAutoresizingMaskIntoConstraints = false
        formatChrome.wantsLayer = true
        formatChrome.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
        formatChrome.ignoresHits = true
        formatChrome.alphaValue = 0

        formatBar.orientation = .horizontal
        formatBar.alignment = .centerY
        formatBar.spacing = GlanceTheme.Space.xs
        formatBar.edgeInsets = NSEdgeInsets(
            top: GlanceTheme.Space.xs,
            left: GlanceTheme.Space.md,
            bottom: GlanceTheme.Space.xs,
            right: GlanceTheme.Space.md
        )
        formatBar.translatesAutoresizingMaskIntoConstraints = false

        formatBar.addArrangedSubview(makeFormatButton(symbol: "bold", tooltip: "粗体 (⌘B)", action: #selector(boldClicked)))
        formatBar.addArrangedSubview(makeFormatButton(symbol: "list.bullet", tooltip: "无序列表", action: #selector(bulletClicked)))
        formatBar.addArrangedSubview(makeFormatButton(symbol: "checklist", tooltip: "清单", action: #selector(checklistClicked)))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        formatBar.addArrangedSubview(spacer)

        formatSeparator.wantsLayer = true
        formatSeparator.layer?.backgroundColor = GlanceTheme.Fill.panelBorder.cgColor
        formatSeparator.translatesAutoresizingMaskIntoConstraints = false

        formatChrome.addSubview(formatBar)
        formatChrome.addSubview(formatSeparator)

        textView.delegate = self
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isReadingMode = true
        textView.font = GlanceConstants.textBodyFont
        textView.textColor = GlanceConstants.textBodyColor
        textView.defaultParagraphStyle = GlanceTheme.Reading.bodyParagraphStyle()
        textView.typingAttributes = [
            .font: GlanceConstants.textBodyFont,
            .foregroundColor: GlanceConstants.textBodyColor,
            .paragraphStyle: GlanceTheme.Reading.bodyParagraphStyle()
        ]
        textView.textContainerInset = GlanceTheme.Size.readingInset
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.insertionPointColor = .labelColor
        textView.onBeginEditing = { [weak self] in self?.onRequestEditing?() }
        textView.onRequestEndEditing = { [weak self] in
            self?.exitEditing()
            NSApp.deactivate()
        }
        textView.onChecklistToggled = { [weak self] in self?.onPayloadChange?() }

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.font = GlanceTheme.Typography.placeholder
        placeholder.textColor = .tertiaryLabelColor
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isEditable = false
        placeholder.isBordered = false
        placeholder.drawsBackground = false

        addSubview(scrollView)
        addSubview(formatChrome)
        addSubview(placeholder)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            formatChrome.leadingAnchor.constraint(equalTo: leadingAnchor),
            formatChrome.trailingAnchor.constraint(equalTo: trailingAnchor),
            formatChrome.topAnchor.constraint(equalTo: topAnchor),
            formatChrome.heightAnchor.constraint(equalToConstant: GlanceTheme.Size.formatBarHeight),
            formatBar.leadingAnchor.constraint(equalTo: formatChrome.leadingAnchor),
            formatBar.trailingAnchor.constraint(equalTo: formatChrome.trailingAnchor),
            formatBar.topAnchor.constraint(equalTo: formatChrome.topAnchor),
            formatBar.bottomAnchor.constraint(equalTo: formatSeparator.topAnchor),
            formatSeparator.leadingAnchor.constraint(equalTo: formatChrome.leadingAnchor),
            formatSeparator.trailingAnchor.constraint(equalTo: formatChrome.trailingAnchor),
            formatSeparator.bottomAnchor.constraint(equalTo: formatChrome.bottomAnchor),
            formatSeparator.heightAnchor.constraint(equalToConstant: GlanceTheme.Size.hairline),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GlanceTheme.Size.readingInset.width + 4),
            placeholder.topAnchor.constraint(
                equalTo: topAnchor,
                constant: GlanceTheme.Size.readingInset.height
            )
        ])
        applyFormatBar(visible: false)
    }

    private func applyFormatBar(visible: Bool) {
        formatChrome.ignoresHits = !visible
        formatChrome.setAccessibilityElement(visible)
        applyScrollTopInset(visible)
        for case let button as NSButton in formatBar.arrangedSubviews {
            button.isEnabled = visible
        }
        GlanceMotion.setAlpha(formatChrome, visible ? 1 : 0)
    }

    private func applyScrollTopInset(_ editing: Bool) {
        let inset = TextFormatBarLayout.scrollTopInset(isEditing: editing)
        scrollView.contentInsets = NSEdgeInsets(top: inset, left: 0, bottom: 0, right: 0)
        scrollView.scrollerInsets = NSEdgeInsets(top: inset, left: 0, bottom: 0, right: 0)
    }

    private func makeFormatButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let button = NSButton(
            image: GlanceTheme.chromeSymbol(symbol, accessibilityDescription: tooltip) ?? NSImage(),
            target: self,
            action: action
        )
        button.bezelStyle = .toolbar
        button.isBordered = false
        button.toolTip = tooltip
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    @objc private func boldClicked() {
        textView.toggleBold()
        onPayloadChange?()
    }

    @objc private func bulletClicked() {
        textView.insertBullet()
        onPayloadChange?()
    }

    @objc private func checklistClicked() {
        textView.insertChecklist()
        onPayloadChange?()
    }

    private func refreshPlaceholder() {
        let empty = (textView.string.trimmingCharacters(in: .whitespacesAndNewlines)).isEmpty
        placeholder.isHidden = !empty || !textView.isReadingMode
    }
}

private final class FormatBarChrome: NSView {
    var ignoresHits = true

    override func hitTest(_ point: NSPoint) -> NSView? {
        ignoresHits ? nil : super.hitTest(point)
    }
}

enum TextPayloadFile {
    static let fileName = "content.rtf"

    /// `nil` means the file is absent (empty new panel). Existing unreadable files throw.
    static func readAttributedString(from directory: URL) throws -> NSAttributedString? {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard let attributed = NSAttributedString(rtf: data, documentAttributes: nil) else {
            throw PayloadLoadError.unreadable(url)
        }
        return attributed
    }

    static func writePlainText(_ string: String, to directory: URL) throws {
        let attributed = NSAttributedString(
            string: string,
            attributes: [
                .font: GlanceConstants.textBodyFont,
                .foregroundColor: GlanceConstants.textBodyColor,
                .paragraphStyle: GlanceTheme.Reading.bodyParagraphStyle()
            ]
        )
        let url = directory.appendingPathComponent(fileName)
        let range = NSRange(location: 0, length: attributed.length)
        guard let data = attributed.rtf(from: range, documentAttributes: [:]) else {
            throw PayloadStoreError.writeFailed(url, TextPayloadError.rtfEncodingFailed)
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PayloadStoreError.writeFailed(url, error)
        }
    }
}
