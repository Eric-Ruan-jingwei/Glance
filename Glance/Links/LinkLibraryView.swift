import Combine
import SwiftUI
import UniformTypeIdentifiers

enum LinkEditorFocus: Equatable {
    case title
    case url
}

struct LinkEditorSession: Equatable {
    var editingID: UUID?
    var draft: LinkDraft
    var suggestedTitle: String?
    var focus: LinkEditorFocus
    var error: String?
}

@MainActor
final class LinkLibraryViewModel: ObservableObject {
    @Published var query = ""
    @Published var selection: UUID?
    @Published var presentationID = 0
    @Published var editor: LinkEditorSession?
    @Published var isDropTargeted = false
    @Published var notice: String?

    let service: LinkService
    private var cancellables = Set<AnyCancellable>()
    private var noticeTask: Task<Void, Never>?

    init(service: LinkService) {
        self.service = service
        service.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var displayed: [LinkRecord] {
        service.displayed(matching: query)
    }

    func resetPresentation() {
        query = ""
        editor = nil
        notice = nil
        isDropTargeted = false
        selection = displayed.first?.id
        presentationID += 1
    }

    func moveSelection(_ delta: Int) {
        let items = displayed
        guard !items.isEmpty else {
            selection = nil
            return
        }
        guard let selection, let index = items.firstIndex(where: { $0.id == selection }) else {
            self.selection = items.first?.id
            return
        }
        let next = min(max(0, index + delta), items.count - 1)
        self.selection = items[next].id
    }

    func ensureSelection() {
        let items = displayed
        if let selection, items.contains(where: { $0.id == selection }) {
            return
        }
        self.selection = items.first?.id
    }

    func beginCreate() {
        guard service.canMutate else { return }
        editor = LinkEditorSession(
            editingID: nil,
            draft: .empty,
            suggestedTitle: nil,
            focus: .url,
            error: nil
        )
    }

    func beginCreate(prefilledURL urlString: String, suggestedTitle: String? = nil) {
        guard service.canMutate else { return }
        let normalized = WebLinkPolicy.normalizedURLString(urlString) ?? urlString
        editor = LinkEditorSession(
            editingID: nil,
            draft: LinkDraft(
                title: LinkTitleGenerator.makeTitle(from: normalized, suggested: suggestedTitle),
                urlString: normalized
            ),
            suggestedTitle: suggestedTitle,
            focus: .title,
            error: nil
        )
    }

    func beginEdit(id: UUID) {
        guard service.canMutate, let record = service.records.first(where: { $0.id == id }) else { return }
        selection = id
        editor = LinkEditorSession(
            editingID: id,
            draft: LinkDraft(title: record.title, urlString: record.urlString),
            suggestedTitle: nil,
            focus: .title,
            error: nil
        )
    }

    func cancelEditor() {
        editor = nil
    }

    @discardableResult
    func commitEditor(at date: Date = Date()) -> Bool {
        guard var session = editor else { return false }
        let result: Result<LinkRecord, LinkCommitError>
        if let id = session.editingID {
            result = service.update(id: id, draft: session.draft, at: date)
        } else {
            result = service.create(session.draft, suggestedTitle: session.suggestedTitle, at: date)
        }
        switch result {
        case .success(let record):
            selection = record.id
            editor = nil
            return true
        case .failure(let error):
            session.error = error.message
            editor = session
            return false
        }
    }

    func ingest(_ candidates: [LinkDropCandidate], rejected: Int) {
        guard service.canMutate else { return }
        var lastID: UUID?
        for candidate in candidates {
            let draft = LinkDraft(
                title: candidate.suggestedTitle ?? "",
                urlString: candidate.urlString
            )
            if case .success(let record) = service.create(draft, suggestedTitle: candidate.suggestedTitle) {
                lastID = record.id
            }
        }
        if let lastID {
            selection = lastID
        }
        if rejected > 0 {
            showNotice(LinkCopy.partialRejected)
        }
    }

    func showNotice(_ message: String) {
        noticeTask?.cancel()
        notice = message
        noticeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
}

struct LinkLibraryView: View {
    @ObservedObject var model: LinkLibraryViewModel
    @FocusState private var searchFocused: Bool
    var onOpen: (UUID) -> Void
    var onCopy: (UUID) -> Void
    var onEdit: (UUID) -> Void
    var onCreate: () -> Void
    var onTogglePin: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onDropItems: ([LinkDropItem]) -> Void
    var relativeNow: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: editorBinding) { session in
            LinkEditorView(
                session: binding(for: session),
                onSave: { _ = model.commitEditor() },
                onCancel: { model.cancelEditor() }
            )
        }
        .onDrop(of: [UTType.url, UTType.plainText], isTargeted: $model.isDropTargeted) { providers in
            MacLinkDropCollector.collect(providers) { items in
                onDropItems(items)
            }
            return true
        }
        .overlay {
            if model.isDropTargeted {
                RoundedRectangle(cornerRadius: GlanceTheme.Radius.panel, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 2)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                Text(notice)
                    .font(.caption)
                    .padding(.horizontal, GlanceTheme.Space.md)
                    .padding(.vertical, GlanceTheme.Space.xs)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 44)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: model.query) { _, _ in model.ensureSelection() }
        .onChange(of: model.service.records) { _, _ in model.ensureSelection() }
        .onChange(of: model.presentationID) { _, _ in
            searchFocused = true
        }
        .onAppear {
            searchFocused = true
        }
    }

    private var editorBinding: Binding<LinkEditorSession?> {
        Binding(
            get: { model.editor },
            set: { newValue in
                if newValue == nil {
                    model.cancelEditor()
                } else {
                    model.editor = newValue
                }
            }
        )
    }

    private func binding(for session: LinkEditorSession) -> Binding<LinkEditorSession> {
        Binding(
            get: { model.editor ?? session },
            set: { model.editor = $0 }
        )
    }

    private var header: some View {
        HStack(spacing: GlanceTheme.Space.sm) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(LinkCopy.searchPrompt, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .accessibilityLabel(LinkCopy.searchPrompt)
            Button(action: onCreate) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .disabled(!model.service.canMutate)
            .accessibilityLabel(LinkCopy.addLabel)
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        if !model.service.canPersist, case .unsupportedFutureSchema = model.service.loadOutcome {
            emptyState(title: LinkCopy.futureSchema, detail: nil, action: nil)
        } else if displayedEmpty {
            emptyState(title: emptyTitle, detail: emptyDetail, action: emptyAction)
        } else {
            list
        }
    }

    private var displayedEmpty: Bool {
        model.displayed.isEmpty
    }

    private var emptyTitle: String {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? LinkCopy.emptyTitle
            : LinkCopy.emptySearch
    }

    private var emptyDetail: String? {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? LinkCopy.emptyDetail
            : nil
    }

    private var emptyAction: (String, () -> Void)? {
        guard model.service.canMutate,
              model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return (LinkCopy.addLabel, onCreate)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(model.displayed, selection: $model.selection) { record in
                LinkRow(
                    record: record,
                    relativeNow: relativeNow,
                    onTogglePin: { onTogglePin(record.id) }
                )
                .id(record.id)
                .contentShape(Rectangle())
                .modifier(LinkDragOutModifier(urlString: LinkDragPayload.urlString(from: record.urlString)))
                .onTapGesture(count: 2) {
                    onOpen(record.id)
                }
                .onTapGesture {
                    model.selection = record.id
                }
                .contextMenu {
                    Button(LinkCopy.openLabel) { onOpen(record.id) }
                    Button(LinkCopy.copyLabel) { onCopy(record.id) }
                    Button(LinkCopy.editLabel) { onEdit(record.id) }
                    Button(record.isPinned ? LinkCopy.unpinLabel : LinkCopy.pinLabel) {
                        onTogglePin(record.id)
                    }
                    Button(LinkCopy.deleteLabel, role: .destructive) {
                        onDelete(record.id)
                    }
                }
                .listRowInsets(EdgeInsets(
                    top: GlanceTheme.Space.sm,
                    leading: GlanceTheme.Space.md,
                    bottom: GlanceTheme.Space.sm,
                    trailing: GlanceTheme.Space.md
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: GlanceTheme.Radius.control, style: .continuous)
                        .fill(model.selection == record.id ? Color.accentColor.opacity(0.14) : Color.clear)
                )
            }
            .listStyle(.plain)
            .onChange(of: model.selection) { _, id in
                if let id {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func emptyState(
        title: String,
        detail: String?,
        action: (String, () -> Void)?
    ) -> some View {
        VStack(spacing: GlanceTheme.Space.md) {
            Spacer(minLength: GlanceTheme.Space.lg)
            Text(title)
                .font(.headline)
            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action {
                Button(action.0, action: action.1)
                    .keyboardShortcut(.defaultAction)
            }
            Spacer(minLength: GlanceTheme.Space.lg)
        }
        .padding(.horizontal, GlanceTheme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: GlanceTheme.Space.lg) {
            Text(LinkCopy.openHint)
            Text(LinkCopy.editHint)
            Text(LinkCopy.createHint)
            Text(LinkCopy.closeHint)
            Spacer()
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.sm)
        .foregroundStyle(.secondary)
        .font(.caption)
    }
}

private struct LinkDragOutModifier: ViewModifier {
    var urlString: String?

    func body(content: Content) -> some View {
        if let urlString, let url = URL(string: urlString) {
            content.draggable(url)
        } else {
            content
        }
    }
}

struct LinkRow: View {
    var record: LinkRecord
    var relativeNow: Date
    var onTogglePin: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.body)
                    .lineLimit(1)
                Text(LinkPreview.line(from: record.urlString))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: GlanceTheme.Space.sm)
            Text(LinkRelativeDate.string(from: record.lastOpenedAt, now: relativeNow))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(action: onTogglePin) {
                Image(systemName: record.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(record.isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(record.isPinned ? LinkCopy.unpinLabel : LinkCopy.pinLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let pin = record.isPinned ? "已置顶" : "未置顶"
        let time = LinkRelativeDate.string(from: record.lastOpenedAt, now: relativeNow)
        let host = URLComponents(string: record.urlString)?.host ?? LinkPreview.line(from: record.urlString)
        return "\(record.title)，\(host)，\(time)，\(pin)"
    }
}

enum LinkRelativeDate {
    static func string(from date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

extension LinkEditorSession: Identifiable {
    var id: String {
        editingID?.uuidString ?? "new"
    }
}
