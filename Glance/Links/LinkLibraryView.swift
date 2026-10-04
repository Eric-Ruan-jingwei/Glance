import AppKit
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
    @Published var isDropCandidate = false
    @Published var isInternalDropHighlighted = false
    @Published var notice: String?

    let service: LinkService
    let dropSession = GlanceItemDropSession()
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
    var onPerformItemAction: (GlanceItemAction, UUID) -> Void
    var onAvailableSourceActions: (GlanceActionSourceID) -> [GlanceItemAction] = { _ in [] }
    var onPerformSourceAction: (GlanceItemAction, GlanceActionSourceID, NSScreen?) -> GlanceActionOutcome = { _, _, _ in
        .failed(GlanceNoticeCopy.panelCreateFailed)
    }
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
        .onDrop(of: [GlanceDragType.utType, UTType.url, UTType.plainText], isTargeted: $model.isDropCandidate) { providers in
            if GlanceItemDragCodec.hasInternalPayload(providers) {
                return GlanceItemDropRunner.handleProviders(
                    providers,
                    destination: .links,
                    session: model.dropSession,
                    availableActions: onAvailableSourceActions,
                    perform: onPerformSourceAction,
                    screen: DisplayManager.screenContainingMouse(),
                    onFailed: { message in
                        model.showNotice(message)
                    }
                )
            }
            MacLinkDropCollector.collect(providers) { items in
                onDropItems(items)
            }
            return true
        }
        .onChange(of: model.isDropCandidate) { _, targeted in
            if GlanceItemDragCodec.sourceID(from: NSPasteboard(name: .drag)) != nil {
                model.isDropTargeted = false
                model.isInternalDropHighlighted = GlanceItemDropRunner.hoverHighlight(
                    targeted: targeted,
                    destination: .links,
                    session: model.dropSession,
                    availableActions: onAvailableSourceActions
                )
            } else {
                model.isInternalDropHighlighted = false
                model.isDropTargeted = targeted
                if !targeted {
                    model.dropSession.reset()
                }
            }
        }
        .overlay {
            GlanceDropHighlight(isActive: model.isDropTargeted || model.isInternalDropHighlighted)
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
            emptyState(
                symbol: "exclamationmark.triangle",
                title: LinkCopy.futureSchema,
                detail: nil,
                action: nil
            )
        } else if !model.service.canPersist {
            emptyState(
                symbol: "exclamationmark.triangle",
                title: LinkCopy.unreadable,
                detail: nil,
                action: nil
            )
        } else if displayedEmpty {
            emptyState(
                symbol: emptySymbol,
                title: emptyTitle,
                detail: emptyDetail,
                action: emptyAction
            )
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
            : LinkCopy.emptySearchDetail
    }

    private var emptySymbol: String {
        model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? LinkEmptyPresentation.symbol
            : LinkEmptyPresentation.searchSymbol
    }

    private var emptyAction: (String, () -> Void)? {
        guard LinkEmptyPresentation.showsCreateCTA(
            query: model.query,
            canMutate: model.service.canMutate
        ) else {
            return nil
        }
        return (LinkCopy.emptyCTA, { LinkEmptyPresentation.create(using: onCreate) })
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(model.displayed, selection: $model.selection) { record in
                LinkRow(
                    record: record,
                    isSelected: model.selection == record.id,
                    relativeNow: relativeNow,
                    onOpen: { LinkRowQuickAction.open(record.id, using: onOpen) },
                    onTogglePin: { LinkRowQuickAction.togglePin(record.id, using: onTogglePin) },
                    onDelete: { LinkRowQuickAction.delete(record.id, using: onDelete) },
                    moreMenu: { linkMenus(for: record) }
                )
                .id(record.id)
                .contentShape(Rectangle())
                .modifier(LinkDragOutModifier(
                    recordID: record.id,
                    urlString: LinkDragPayload.urlString(from: record.urlString)
                ))
                .onTapGesture(count: 2) {
                    onOpen(record.id)
                }
                .onTapGesture {
                    model.selection = record.id
                }
                .contextMenu {
                    linkMenus(for: record)
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
    private func linkMenus(for record: LinkRecord) -> some View {
        Button(LinkCopy.openLabel) { onOpen(record.id) }
        Button(LinkCopy.copyLabel) { onCopy(record.id) }
        Button(LinkCopy.editLabel) { onEdit(record.id) }
        ForEach(GlanceItemActionPolicy.actions(for: .link(record)), id: \.identifier) { action in
            Button(action.title) {
                onPerformItemAction(action, record.id)
            }
            .accessibilityIdentifier(action.identifier)
        }
        Button(record.isPinned ? LinkCopy.unpinLabel : LinkCopy.pinLabel) {
            onTogglePin(record.id)
        }
        Button(LinkCopy.deleteLabel, role: .destructive) {
            onDelete(record.id)
        }
    }

    private func emptyState(
        symbol: String,
        title: String,
        detail: String?,
        action: (String, () -> Void)?
    ) -> some View {
        GlanceEmptyState(
            symbol: symbol,
            title: title,
            detail: detail ?? ""
        ) {
            if let action {
                GlanceEmptyCTA(
                    title: action.0,
                    accessibilityText: LinkCopy.emptyCTAAccessibility,
                    action: action.1
                )
            }
        }
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
    var recordID: UUID
    var urlString: String?

    func body(content: Content) -> some View {
        content.modifier(GlanceItemDragModifier(
            sourceID: .link(recordID),
            nativeURL: urlString.flatMap { URL(string: $0) }
        ))
    }
}

struct LinkRow<MoreMenu: View>: View {
    var record: LinkRecord
    var isSelected: Bool
    var relativeNow: Date
    var onOpen: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var moreMenu: () -> MoreMenu

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            Image(systemName: "link")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
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
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            GlanceRowTrailingAccessory(
                width: GlanceRowQuickActionLayout.slotWidth(for: .link),
                showsActions: showsSecondary
            ) {
                HStack(spacing: 0) {
                    Text(LinkRelativeDate.string(from: record.lastOpenedAt, now: relativeNow))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if record.isPinned {
                        GlanceRowIconButton(
                            systemName: "pin.fill",
                            help: LinkCopy.unpinLabel,
                            isActive: true,
                            action: onTogglePin
                        )
                    }
                }
            } actions: {
                HStack(spacing: 0) {
                    GlanceRowIconButton(
                        systemName: "arrow.up.right.square",
                        help: LinkCopy.openLabel,
                        action: onOpen
                    )
                    GlanceRowIconButton(
                        systemName: record.isPinned ? "pin.fill" : "pin",
                        help: record.isPinned ? LinkCopy.unpinLabel : LinkCopy.pinLabel,
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
