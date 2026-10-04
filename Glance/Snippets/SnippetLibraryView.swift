import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

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
    @Published var isDropCandidate = false
    @Published var isInternalDropHighlighted = false

    let service: SnippetService
    let dropSession = GlanceItemDropSession()
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
        isDropCandidate = false
        isInternalDropHighlighted = false
        dropSession.reset()
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
    var onPerformItemAction: (GlanceItemAction, UUID) -> Void
    var onAvailableSourceActions: (GlanceActionSourceID) -> [GlanceItemAction] = { _ in [] }
    var onPerformSourceAction: (GlanceItemAction, GlanceActionSourceID, NSScreen?) -> GlanceActionOutcome = { _, _, _ in
        .failed(GlanceNoticeCopy.panelCreateFailed)
    }
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
        .onDrop(of: [GlanceDragType.utType], isTargeted: $model.isDropCandidate) { providers in
            GlanceItemDropRunner.handleProviders(
                providers,
                destination: .snippets,
                session: model.dropSession,
                availableActions: onAvailableSourceActions,
                perform: onPerformSourceAction,
                screen: DisplayManager.screenContainingMouse(),
                onFailed: { message in
                    model.showNotice(message)
                }
            )
        }
        .onChange(of: model.isDropCandidate) { _, targeted in
            model.isInternalDropHighlighted = GlanceItemDropRunner.hoverHighlight(
                targeted: targeted,
                destination: .snippets,
                session: model.dropSession,
                availableActions: onAvailableSourceActions
            )
        }
        .overlay {
            GlanceDropHighlight(isActive: model.isInternalDropHighlighted)
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
        } else if !model.service.canPersist {
            emptyState(title: SnippetCopy.unreadable, detail: nil, action: nil)
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
                    isSelected: model.selection == record.id,
                    relativeNow: relativeNow,
                    onCopy: { SnippetRowQuickAction.copy(record.id, using: onCopy) },
                    onTogglePin: { SnippetRowQuickAction.togglePin(record.id, using: onTogglePin) },
                    onDelete: { SnippetRowQuickAction.delete(record.id, using: onDelete) },
                    moreMenu: { snippetMenus(for: record) }
                )
                .id(record.id)
                .contentShape(Rectangle())
                .modifier(GlanceItemDragModifier(
                    sourceID: .snippet(record.id),
                    nativeText: record.content
                ))
                .onTapGesture(count: 2) {
                    onEdit(record.id)
                }
                .onTapGesture {
                    model.selection = record.id
                }
                .contextMenu {
                    snippetMenus(for: record)
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

    @ViewBuilder
    private func snippetMenus(for record: SnippetRecord) -> some View {
        Button(SnippetCopy.copyLabel) { onCopy(record.id) }
        Button(SnippetCopy.editLabel) { onEdit(record.id) }
        ForEach(GlanceItemActionPolicy.actions(for: .snippet(record)), id: \.identifier) { action in
            Button(action.title) {
                onPerformItemAction(action, record.id)
            }
            .accessibilityIdentifier(action.identifier)
        }
        Button(record.isPinned ? SnippetCopy.unpinLabel : SnippetCopy.pinLabel) {
            onTogglePin(record.id)
        }
        Button(SnippetCopy.deleteLabel, role: .destructive) {
            onDelete(record.id)
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

struct SnippetRow<MoreMenu: View>: View {
    var record: SnippetRecord
    var isSelected: Bool
    var relativeNow: Date
    var onCopy: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var moreMenu: () -> MoreMenu

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            Image(systemName: SnippetRowQuickAction.leadingSymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .accessibilityLabel(GlanceRowActionCopy.leadingSnippet)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.body)
                    .lineLimit(1)
                Text(SnippetPreview.line(from: record.content))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            GlanceRowTrailingAccessory(
                width: GlanceRowQuickActionLayout.slotWidth(for: .snippet),
                showsActions: showsSecondary
            ) {
                HStack(spacing: 0) {
                    Text(SnippetRelativeDate.string(from: record.lastUsedAt, now: relativeNow))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if record.isPinned {
                        GlanceRowIconButton(
                            systemName: "pin.fill",
                            help: SnippetCopy.unpinLabel,
                            isActive: true,
                            action: onTogglePin
                        )
                    }
                }
            } actions: {
                HStack(spacing: 0) {
                    GlanceRowIconButton(
                        systemName: "doc.on.doc",
                        help: SnippetCopy.copyLabel,
                        action: onCopy
                    )
                    GlanceRowIconButton(
                        systemName: record.isPinned ? "pin.fill" : "pin",
                        help: record.isPinned ? SnippetCopy.unpinLabel : SnippetCopy.pinLabel,
                        isActive: record.isPinned,
                        action: onTogglePin
                    )
                    GlanceRowIconButton(
                        systemName: "trash",
                        help: GlanceRowActionCopy.delete,
                        action: onDelete
                    )
                    GlanceRowMoreButton(visible: true, menu: moreMenu)
                }
            }
        }
        .onHover { isHovered = $0 }
        .animation(GlanceMotion.animation, value: showsSecondary)
        .animation(GlanceMotion.animation, value: record.isPinned)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var showsSecondary: Bool {
        GlanceRowQuickActionVisibility.showsSecondary(isHovered: isHovered, isSelected: isSelected)
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
