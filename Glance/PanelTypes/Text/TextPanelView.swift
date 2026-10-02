import AppKit

@MainActor
final class TextPanelView: NSView, PanelContentControlling, NSTextViewDelegate {
    var view: NSView { self }
    let minimumSize: NSSize = GlanceConstants.textMinSize
    var onPayloadChange: (() -> Void)?
    var onRequestEditing: (() -> Void)?
    var onRequestPreferredSize: ((NSSize) -> Void)?

    private let formatBar = NSStackView()
    private let scrollView = NSScrollView()
    private let textView: GlanceTextView
    private let placeholder = NSTextField(labelWithString: "双击开始编辑")
    private var formatBarHeight: NSLayoutConstraint!

    init() {
        textView = GlanceTextView(usingTextLayoutManager: false)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) {
        let url = directory.appendingPathComponent("content.rtf")
        if let data = try? Data(contentsOf: url),
           let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attributed)
        }
        refreshPlaceholder()
    }

    func savePayload(to directory: URL) {
        let range = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        let url = directory.appendingPathComponent("content.rtf")
        if let data = textView.rtf(from: range) {
            try? data.write(to: url)
        }
    }

    func enterEditing() {
        textView.isReadingMode = false
        textView.isEditable = true
        textView.isSelectable = true
        formatBar.isHidden = false
        formatBarHeight.constant = 30
        placeholder.isHidden = true
        window?.makeFirstResponder(textView)
    }

    func exitEditing() {
        textView.isReadingMode = true
        textView.isEditable = false
        textView.isSelectable = false
        formatBar.isHidden = true
        formatBarHeight.constant = 0
        refreshPlaceholder()
        onPayloadChange?()
    }

    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }

    func textDidChange(_ notification: Notification) {
        refreshPlaceholder()
        onPayloadChange?()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        formatBar.orientation = .horizontal
        formatBar.alignment = .centerY
        formatBar.spacing = 6
        formatBar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 2, right: 10)
        formatBar.translatesAutoresizingMaskIntoConstraints = false
        formatBar.isHidden = true

        formatBar.addArrangedSubview(makeFormatButton(symbol: "bold", tooltip: "粗体 (⌘B)", action: #selector(boldClicked)))
        formatBar.addArrangedSubview(makeFormatButton(symbol: "list.bullet", tooltip: "无序列表", action: #selector(bulletClicked)))
        formatBar.addArrangedSubview(makeFormatButton(symbol: "checklist", tooltip: "清单", action: #selector(checklistClicked)))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        formatBar.addArrangedSubview(spacer)

        textView.delegate = self
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.isReadingMode = true
        textView.font = GlanceConstants.textBodyFont
        textView.textColor = GlanceConstants.textBodyColor
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
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
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textColor = .tertiaryLabelColor
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isEditable = false
        placeholder.isBordered = false
        placeholder.drawsBackground = false

        addSubview(formatBar)
        addSubview(scrollView)
        addSubview(placeholder)

        formatBarHeight = formatBar.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            formatBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            formatBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            formatBar.topAnchor.constraint(equalTo: topAnchor),
            formatBarHeight,
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: formatBar.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            placeholder.topAnchor.constraint(equalTo: formatBar.bottomAnchor, constant: 14)
        ])
    }

    private func makeFormatButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        let button = NSButton(image: image ?? NSImage(), target: self, action: action)
        button.bezelStyle = .toolbar
        button.isBordered = false
        button.toolTip = tooltip
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
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
