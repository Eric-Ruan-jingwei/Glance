import AppKit

@MainActor
final class TodoPanelView: NSView, PanelContentControlling {
    var view: NSView { self }
    let minimumSize: NSSize = GlanceConstants.todoMinSize
    var onPayloadChange: (() -> Void)?
    var onRequestEditing: (() -> Void)?
    var onRequestPreferredSize: ((NSSize) -> Void)?
    var allowsMove = true
    var allowsContentMutation = true {
        didSet {
            addButton.isEnabled = allowsContentMutation
            for case let row as TodoRowView in stack.arrangedSubviews {
                row.allowsContentMutation = allowsContentMutation
            }
        }
    }

    private enum Session {
        case none
        case adding
        case editing(UUID, original: String)
    }

    private let scrollView = NSScrollView()
    private let documentView = TodoFlippedView()
    private let stack = NSStackView()
    private let placeholder = NSTextField(labelWithString: "添加你的第一个待办")
    private let addButton = NSButton(title: "+ 添加待办", target: nil, action: nil)
    private var document = TodoDocument.empty
    private var session: Session = .none
    private var isApplying = false
    private var focusedRow: TodoRowView?

    init() {
        super.init(frame: .zero)
        setup()
        reloadRows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) throws {
        document = try TodoPayloadFile.readDocument(from: directory) ?? .empty
        session = .none
        reloadRows()
    }

    func savePayload(to directory: URL) throws {
        commitPendingEditor(continueAdding: false, notify: false)
        try TodoPayloadFile.writeDocument(document, to: directory)
    }

    func enterEditing() {
        if case .none = session {
            beginAdding()
        }
        focusedRow?.focusField()
    }

    func exitEditing() {
        commitPendingEditor(continueAdding: false, notify: true)
        session = .none
        reloadRows()
    }

    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textColor = .tertiaryLabelColor
        placeholder.translatesAutoresizingMaskIntoConstraints = false

        addButton.bezelStyle = .inline
        addButton.isBordered = false
        addButton.font = .systemFont(ofSize: 13)
        addButton.contentTintColor = .secondaryLabelColor
        addButton.target = self
        addButton.action = #selector(addClicked)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.alignment = .left

        addSubview(scrollView)
        addSubview(placeholder)
        addSubview(addButton)

        let clip = scrollView.contentView
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor),
            addButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            addButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            addButton.heightAnchor.constraint(equalToConstant: 26),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            placeholder.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            documentView.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: clip.topAnchor),
            documentView.widthAnchor.constraint(equalTo: clip.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])
    }

    override func rightMouseDown(with event: NSEvent) {
        if let chrome = window?.contentView as? PanelChromeView {
            chrome.rightMouseDown(with: event)
        }
    }

    @objc private func addClicked() {
        guard allowsContentMutation else { return }
        switch session {
        case .none:
            onRequestEditing?()
        case .adding, .editing:
            commitPendingEditor(continueAdding: true, notify: true)
        }
    }

    private func beginAdding() {
        session = .adding
        reloadRows()
        focusedRow?.focusField()
    }

    private func beginEditing(id: UUID) {
        guard allowsContentMutation else { return }
        commitPendingEditor(continueAdding: false, notify: true)
        guard let item = document.items.first(where: { $0.id == id }) else { return }
        session = .editing(id, original: item.text)
        reloadRows()
        onRequestEditing?()
        focusedRow?.focusField()
    }

    private func commitPendingEditor(continueAdding: Bool, notify: Bool) {
        guard !isApplying else { return }
        var mutated = false
        switch session {
        case .none:
            return
        case .adding:
            if TodoMutation.add(&document, text: focusedRow?.field.stringValue ?? "") != nil {
                mutated = true
                session = continueAdding ? .adding : .none
            } else {
                session = .none
            }
        case .editing(let id, _):
            let result = TodoMutation.edit(&document, id: id, text: focusedRow?.field.stringValue ?? "")
            mutated = result == .updated || result == .deleted
            session = continueAdding ? .adding : .none
        }
        if mutated, notify {
            onPayloadChange?()
        }
        reloadRows()
        if case .adding = session {
            focusedRow?.focusField()
        }
    }

    private func cancelEditor() {
        session = .none
        reloadRows()
        NSApp.deactivate()
    }

    private func toggle(id: UUID) {
        guard allowsContentMutation else { return }
        commitPendingEditor(continueAdding: false, notify: true)
        if TodoMutation.toggle(&document, id: id) {
            onPayloadChange?()
            reloadRows()
        }
    }

    private func delete(id: UUID) {
        guard allowsContentMutation else { return }
        if TodoMutation.delete(&document, id: id) {
            session = .none
            onPayloadChange?()
            reloadRows()
        }
    }

    private func reloadRows() {
        isApplying = true
        focusedRow = nil
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for item in document.items {
            let editing: Bool
            if case .editing(let id, _) = session, id == item.id {
                editing = true
            } else {
                editing = false
            }
            let row = makeRow(item: item, editing: editing)
            stack.addArrangedSubview(row)
            if editing { focusedRow = row }
        }

        if case .adding = session {
            let row = makeRow(item: nil, editing: true)
            stack.addArrangedSubview(row)
            focusedRow = row
        }

        let empty = document.items.isEmpty
        if case .adding = session {
            placeholder.isHidden = true
        } else {
            placeholder.isHidden = !empty
        }
        isApplying = false
    }

    private func makeRow(item: TodoItem?, editing: Bool) -> TodoRowView {
        let row = TodoRowView(item: item, editing: editing, allowsContentMutation: allowsContentMutation)
        row.onToggle = { [weak self] in
            if let id = item?.id { self?.toggle(id: id) }
        }
        row.onBeginEdit = { [weak self] in
            if let id = item?.id { self?.beginEditing(id: id) }
        }
        row.onCommit = { [weak self] _, fromReturn in
            guard let self else { return }
            let addNext: Bool
            if fromReturn, case .adding = self.session {
                addNext = true
            } else {
                addNext = false
            }
            self.commitPendingEditor(continueAdding: addNext, notify: true)
            if case .none = self.session {
                NSApp.deactivate()
            }
        }
        row.onCancel = { [weak self] in
            self?.cancelEditor()
        }
        row.onDelete = { [weak self] in
            if let id = item?.id { self?.delete(id: id) }
        }
        row.onShowPanelMenu = { [weak self] event in
            if let chrome = self?.window?.contentView as? PanelChromeView {
                chrome.rightMouseDown(with: event)
            }
        }
        return row
    }
}

private final class TodoFlippedView: NSView {
    override var isFlipped: Bool { true }
}
