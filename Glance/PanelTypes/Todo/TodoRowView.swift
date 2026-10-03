import AppKit

final class TodoRowView: NSView {
    let itemID: UUID?
    var onToggle: (() -> Void)?
    var onBeginEdit: (() -> Void)?
    var onCommit: ((String, Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onDelete: (() -> Void)?
    var onShowPanelMenu: ((NSEvent) -> Void)?

    private let checkbox = NSButton()
    let field = NSTextField(string: "")
    private let deleteButton = NSButton()
    private var originalText = ""
    private var isEditing = false
    private var ignoreEndEditing = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?
    var allowsContentMutation = true {
        didSet { checkbox.isEnabled = allowsContentMutation }
    }

    init(item: TodoItem?, editing: Bool, allowsContentMutation: Bool) {
        self.itemID = item?.id
        self.allowsContentMutation = allowsContentMutation
        super.init(frame: .zero)
        originalText = item?.text ?? ""
        setup()
        apply(item: item, editing: editing)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func focusField() {
        window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        checkbox.bezelStyle = .inline
        checkbox.isBordered = false
        checkbox.setButtonType(.momentaryChange)
        checkbox.imagePosition = .imageOnly
        checkbox.imageScaling = .scaleProportionallyDown
        checkbox.target = self
        checkbox.action = #selector(toggleClicked)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.isEnabled = allowsContentMutation
        checkbox.contentTintColor = .secondaryLabelColor

        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = GlanceConstants.textBodyFont
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.usesSingleLineMode = true
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        deleteButton.bezelStyle = .inline
        deleteButton.isBordered = false
        deleteButton.imagePosition = .imageOnly
        deleteButton.imageScaling = .scaleProportionallyDown
        deleteButton.image = GlanceTheme.chromeSymbol("xmark", accessibilityDescription: "删除待办")
        deleteButton.contentTintColor = .tertiaryLabelColor
        deleteButton.target = self
        deleteButton.action = #selector(deleteClicked)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.refusesFirstResponder = true
        deleteButton.setAccessibilityLabel("删除待办")
        deleteButton.alphaValue = 0

        addSubview(checkbox)
        addSubview(field)
        addSubview(deleteButton)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: GlanceTheme.Size.todoRowHeight),
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GlanceTheme.Space.md),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 18),
            checkbox.heightAnchor.constraint(equalToConstant: 18),
            field.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: GlanceTheme.Space.sm),
            field.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -GlanceTheme.Space.xs),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -GlanceTheme.Space.sm),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 16),
            deleteButton.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func apply(item: TodoItem?, editing: Bool) {
        isEditing = editing
        let completed = item?.isCompleted ?? false
        let symbol = completed ? "checkmark.circle.fill" : "circle"
        checkbox.image = GlanceTheme.symbol(symbol, pointSize: 14)
        checkbox.contentTintColor = completed ? .tertiaryLabelColor : .secondaryLabelColor
        checkbox.setAccessibilityLabel(completed ? "已完成" : "未完成")
        checkbox.isHidden = itemID == nil && editing
        field.stringValue = item?.text ?? ""
        field.isEditable = editing
        field.isSelectable = editing
        field.drawsBackground = false
        refreshDeleteVisibility()
        if editing {
            field.textColor = NSColor.labelColor
            field.attributedStringValue = NSAttributedString(
                string: field.stringValue,
                attributes: [
                    .font: GlanceConstants.textBodyFont,
                    .foregroundColor: NSColor.labelColor
                ]
            )
        } else {
            applyCompletedAppearance(completed)
        }
    }

    private func applyCompletedAppearance(_ completed: Bool) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: GlanceConstants.textBodyFont,
            .foregroundColor: completed ? NSColor.tertiaryLabelColor : NSColor.labelColor
        ]
        if completed {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = NSColor.quaternaryLabelColor
        }
        field.attributedStringValue = NSAttributedString(string: field.stringValue, attributes: attributes)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshDeleteVisibility()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshDeleteVisibility()
    }

    private func refreshDeleteVisibility() {
        let show = isHovered && allowsContentMutation && itemID != nil && !isEditing
        deleteButton.alphaValue = show ? 1 : 0
        deleteButton.isEnabled = show
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2, allowsContentMutation, itemID != nil, !isEditing {
            onBeginEdit?()
            return
        }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard allowsContentMutation, itemID != nil else {
            onShowPanelMenu?(event)
            return
        }
        let menu = NSMenu()
        let edit = NSMenuItem(title: "编辑", action: #selector(editClicked), keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)
        let delete = NSMenuItem(title: "删除待办", action: #selector(deleteClicked), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func toggleClicked() {
        guard allowsContentMutation, itemID != nil else { return }
        onToggle?()
    }

    @objc private func editClicked() {
        onBeginEdit?()
    }

    @objc private func deleteClicked() {
        onDelete?()
    }
}

extension TodoRowView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            ignoreEndEditing = true
            onCommit?(field.stringValue, true)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            ignoreEndEditing = true
            field.stringValue = originalText
            onCancel?()
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !ignoreEndEditing, isEditing else { return }
        onCommit?(field.stringValue, false)
    }
}
