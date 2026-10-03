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

    private struct DraftKey: Equatable {
        var isAdding: Bool
        var editingID: UUID?
        var text: String
    }

    private let scrollView = NSScrollView()
    private let documentView = TodoFlippedView()
    private let stack = NSStackView()
    private let placeholder = NSTextField(labelWithString: GlanceEmptyCopy.todoPlaceholder)
    private let addButton = NSButton(title: "添加待办", target: nil, action: nil)
    private var document = TodoDocument.empty
    private var session: Session = .none
    private var isApplying = false
    private var focusedRow: TodoRowView?
    private var lastAbsorbedDraft: DraftKey?

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
        try TodoPayloadFile.writeDocument(document, to: directory)
    }

    func enterEditing() {
        if case .none = session {
            beginAdding()
        }
        focusedRow?.focusField()
    }

    func exitEditing() {
        session = .none
        lastAbsorbedDraft = nil
        reloadRows()
    }

    func flushPendingUserChanges() -> Bool {
        absorbDraftIntoDocument()
    }

    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }

    var automaticDisplayTitle: String? {
        PanelSummaryText.todoTitle(items: document.items).title
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = GlanceTheme.Space.xxs
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

        placeholder.stringValue = GlanceEmptyCopy.todoPlaceholder
        placeholder.font = GlanceTheme.Typography.placeholder
        placeholder.textColor = .tertiaryLabelColor
        placeholder.translatesAutoresizingMaskIntoConstraints = false

        addButton.bezelStyle = .inline
        addButton.isBordered = false
        addButton.image = GlanceTheme.symbol("plus", pointSize: 11)
        addButton.imagePosition = .imageLeading
        addButton.title = "添加待办"
        addButton.font = GlanceTheme.Typography.secondary
        addButton.contentTintColor = .tertiaryLabelColor
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
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: GlanceTheme.Space.sm),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor),
            addButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GlanceTheme.Space.md),
            addButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -GlanceTheme.Space.md),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -GlanceTheme.Space.sm),
            addButton.heightAnchor.constraint(equalToConstant: GlanceTheme.Size.controlHeight),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GlanceTheme.Space.lg),
            placeholder.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: GlanceTheme.Space.sm),
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
        lastAbsorbedDraft = nil
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

    private func pendingSession() -> TodoPendingSession {
        switch session {
        case .none:
            return .none
        case .adding:
            return .adding
        case .editing(let id, _):
            return .editing(id: id)
        }
    }

    private func currentDraftKey() -> DraftKey {
        DraftKey(
            isAdding: {
                if case .adding = session { return true }
                return false
            }(),
            editingID: {
                if case .editing(let id, _) = session { return id }
                return nil
            }(),
            text: TodoMutation.trimmed(focusedRow?.field.stringValue ?? "")
        )
    }

    @discardableResult
    private func absorbDraftIntoDocument() -> Bool {
        guard !isApplying else { return false }
        let key = currentDraftKey()
        if lastAbsorbedDraft == key {
            return false
        }
        let mutated = TodoPendingFlush.apply(
            to: &document,
            session: pendingSession(),
            draft: focusedRow?.field.stringValue ?? ""
        )
        lastAbsorbedDraft = key
        return mutated
    }

    private func commitPendingEditor(continueAdding: Bool, notify: Bool) {
        guard !isApplying else { return }
        let draft = focusedRow?.field.stringValue ?? ""
        let mutated = TodoPendingFlush.apply(to: &document, session: pendingSession(), draft: draft)
        switch session {
        case .none:
            return
        case .adding:
            session = mutated && continueAdding ? .adding : .none
        case .editing:
            session = continueAdding ? .adding : .none
        }
        lastAbsorbedDraft = nil
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
        lastAbsorbedDraft = nil
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
        commitPendingEditor(continueAdding: false, notify: true)
        guard TodoMutation.delete(&document, id: id) else { return }
        onPayloadChange?()
        reloadRows()
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
