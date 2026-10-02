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
    private var originalText = ""
    private var isEditing = false
    private var ignoreEndEditing = false
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
        checkbox.font = NSFont.systemFont(ofSize: 15)
        checkbox.imagePosition = .noImage
        checkbox.target = self
        checkbox.action = #selector(toggleClicked)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.isEnabled = allowsContentMutation

        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = GlanceConstants.textBodyFont
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.usesSingleLineMode = true
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkbox)
        addSubview(field)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 22),
            field.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            field.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func apply(item: TodoItem?, editing: Bool) {
        isEditing = editing
        let completed = item?.isCompleted ?? false
        checkbox.title = completed ? "☑" : "☐"
        checkbox.isHidden = itemID == nil && editing
        field.stringValue = item?.text ?? ""
        field.isEditable = editing
        field.isSelectable = editing
        field.drawsBackground = editing
        field.backgroundColor = editing ? NSColor.textBackgroundColor.withAlphaComponent(0.35) : .clear
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
            .foregroundColor: completed ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        if completed {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        field.attributedStringValue = NSAttributedString(string: field.stringValue, attributes: attributes)
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
