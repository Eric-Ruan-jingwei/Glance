import Combine
import SwiftUI

enum SnippetEditorFocus: Equatable {
    case title
    case body
}

struct SnippetEditorSession: Equatable {
    var editingID: UUID?
    var draft: SnippetDraft
    var focus: SnippetEditorFocus
    var error: String?
}

@MainActor
final class SnippetLibraryViewModel: ObservableObject {
    @Published var query = ""
    @Published var selection: UUID?
    @Published var presentationID = 0
    @Published var editor: SnippetEditorSession?
    @Published var notice: String?

    let service: SnippetService
    private var cancellables = Set<AnyCancellable>()
    private var noticeTask: Task<Void, Never>?

    init(service: SnippetService) {
        self.service = service
        service.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var displayed: [SnippetRecord] {
        service.displayed(matching: query)
    }

    func resetPresentation() {
        query = ""
        editor = nil
        notice = nil
        selection = displayed.first?.id
        presentationID += 1
    }

    @discardableResult
    func selectForReveal(_ id: UUID) -> Bool {
        query = ""
        editor = nil
        guard service.records.contains(where: { $0.id == id }) else { return false }
        selection = id
        return displayed.contains(where: { $0.id == id })
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
        editor = SnippetEditorSession(
            editingID: nil,
            draft: .empty,
            focus: .body,
            error: nil
        )
    }

    func beginCreate(prefilled content: String) {
        guard service.canMutate else { return }
        editor = SnippetEditorSession(
            editingID: nil,
            draft: SnippetDraft(
                title: SnippetTitleGenerator.makeTitle(from: content),
                content: content
            ),
            focus: .title,
            error: nil
        )
    }

    func beginEdit(id: UUID) {
        guard service.canMutate, let record = service.records.first(where: { $0.id == id }) else { return }
        selection = id
        editor = SnippetEditorSession(
            editingID: id,
            draft: SnippetDraft(title: record.title, content: record.content),
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
        let result: Result<SnippetRecord, SnippetCommitError>
        if let id = session.editingID {
            result = service.update(id: id, draft: session.draft, at: date)
        } else {
            result = service.create(session.draft, at: date)
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
}

struct SnippetLibraryView: View {
    @ObservedObject var model: SnippetLibraryViewModel
    @FocusState private var searchFocused: Bool
    var onCopy: (UUID) -> Void
    var onEdit: (UUID) -> Void
    var onCreate: () -> Void
    var onTogglePin: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onCreatePanel: (UUID) -> Void
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
        .sheet(item: editorBinding) { session in
            SnippetEditorView(
                session: binding(for: session),
                onSave: { _ = model.commitEditor() },
                onCancel: { model.cancelEditor() }
            )
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

    private var editorBinding: Binding<SnippetEditorSession?> {
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

    private func binding(for session: SnippetEditorSession) -> Binding<SnippetEditorSession> {
        Binding(
            get: { model.editor ?? session },
            set: { model.editor = $0 }
        )
    }

    private var header: some View {
        HStack(spacing: GlanceTheme.Space.sm) {
            Image(systemName: "text.quote")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(SnippetCopy.searchPrompt, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .accessibilityLabel(SnippetCopy.searchPrompt)
            Button(action: onCreate) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .disabled(!model.service.canMutate)
            .accessibilityLabel(SnippetCopy.addLabel)
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        if !model.service.canPersist, case .unsupportedFutureSchema = model.service.loadOutcome {
            emptyState(title: SnippetCopy.futureSchema, detail: nil, action: nil)
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
            ? SnippetCopy.emptyTitle
            : SnippetCopy.emptySearch
    }

    private var emptyDetail: String? {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? SnippetCopy.emptyDetail
            : nil
    }

    private var emptyAction: (String, () -> Void)? {
        guard model.service.canMutate,
              model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return (SnippetCopy.addLabel, onCreate)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(model.displayed, selection: $model.selection) { record in
                SnippetRow(
                    record: record,
                    relativeNow: relativeNow,
                    onTogglePin: { onTogglePin(record.id) }
                )
                .id(record.id)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onEdit(record.id)
                }
                .onTapGesture {
                    model.selection = record.id
                }
                .contextMenu {
                    Button(SnippetCopy.copyLabel) { onCopy(record.id) }
                    Button(SnippetCopy.editLabel) { onEdit(record.id) }
                    Button(SnippetCopy.createPanelLabel) { onCreatePanel(record.id) }
                    Button(record.isPinned ? SnippetCopy.unpinLabel : SnippetCopy.pinLabel) {
                        onTogglePin(record.id)
                    }
                    Button(SnippetCopy.deleteLabel, role: .destructive) {
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
            Text(SnippetCopy.copyHint)
            Text(SnippetCopy.editHint)
            Text(SnippetCopy.createHint)
            Text(SnippetCopy.closeHint)
            Spacer()
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.sm)
        .foregroundStyle(.secondary)
        .font(.caption)
    }
}

struct SnippetRow: View {
    var record: SnippetRecord
    var relativeNow: Date
    var onTogglePin: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.body)
                    .lineLimit(1)
                Text(SnippetPreview.line(from: record.content))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: GlanceTheme.Space.sm)
            Text(SnippetRelativeDate.string(from: record.lastUsedAt, now: relativeNow))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(action: onTogglePin) {
                Image(systemName: record.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(record.isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(record.isPinned ? SnippetCopy.unpinLabel : SnippetCopy.pinLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let pin = record.isPinned ? "已置顶" : "未置顶"
        let time = SnippetRelativeDate.string(from: record.lastUsedAt, now: relativeNow)
        return "\(record.title)，\(SnippetPreview.line(from: record.content))，\(time)，\(pin)"
    }
}

enum SnippetRelativeDate {
    static func string(from date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

extension SnippetEditorSession: Identifiable {
    var id: String {
        editingID?.uuidString ?? "new"
    }
}
