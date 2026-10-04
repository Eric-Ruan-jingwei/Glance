import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

enum ClipboardHistoryTab: Int, CaseIterable {
    case recent
    case favorites

    var title: String {
        switch self {
        case .recent: return ClipboardHistoryCopy.recentTab
        case .favorites: return ClipboardHistoryCopy.favoriteTab
        }
    }
}

@MainActor
final class ClipboardHistoryViewModel: ObservableObject {
    @Published var query = ""
    @Published var tab: ClipboardHistoryTab = .recent
    @Published var selection: UUID?
    @Published var presentationID = 0

    let service: ClipboardHistoryService
    let thumbnails: ClipboardThumbnailLoader
    private var cancellables = Set<AnyCancellable>()

    init(service: ClipboardHistoryService, thumbnails: ClipboardThumbnailLoader? = nil) {
        self.service = service
        self.thumbnails = thumbnails ?? ClipboardThumbnailLoader()
        service.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var displayed: [ClipboardHistoryRecord] {
        switch tab {
        case .recent:
            return service.recent(matching: query)
        case .favorites:
            return service.favorites(matching: query)
        }
    }

    func resetPresentation() {
        query = ""
        tab = .recent
        selection = displayed.first?.id
        presentationID += 1
    }

    @discardableResult
    func selectForReveal(_ id: UUID) -> Bool {
        query = ""
        tab = .recent
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

    func selectedRecord() -> ClipboardHistoryRecord? {
        displayed.first { $0.id == selection }
    }

    func ensureSelection() {
        let items = displayed
        if let selection, items.contains(where: { $0.id == selection }) {
            return
        }
        self.selection = items.first?.id
    }
}

struct ClipboardHistoryView: View {
    @ObservedObject var model: ClipboardHistoryViewModel
    @FocusState private var searchFocused: Bool
    var onEnableRecording: () -> Void
    var onReuse: (UUID) -> Void
    var onToggleFavorite: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onPerformItemAction: (GlanceItemAction, UUID) -> Void
    var relativeNow: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: model.query) { _, _ in model.ensureSelection() }
        .onChange(of: model.tab) { _, _ in model.ensureSelection() }
        .onChange(of: model.service.records) { _, _ in model.ensureSelection() }
        .onChange(of: model.presentationID) { _, _ in
            searchFocused = true
        }
        .onAppear {
            searchFocused = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.sm) {
            HStack(spacing: GlanceTheme.Space.sm) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(ClipboardHistoryCopy.searchPrompt, text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                    .accessibilityLabel(ClipboardHistoryCopy.searchPrompt)
                if model.service.isRecordingEnabled {
                    Text(ClipboardHistoryCopy.recording)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Picker("", selection: $model.tab) {
                ForEach(ClipboardHistoryTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("剪贴板分组")
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        if !model.service.canPersist, case .unsupportedFutureSchema = model.service.loadOutcome {
            emptyState(
                symbol: ClipboardEmptyPresentation.unavailableSymbol,
                title: ClipboardHistoryCopy.futureSchema,
                detail: nil,
                action: nil
            )
        } else if !model.service.canPersist {
            emptyState(
                symbol: ClipboardEmptyPresentation.unavailableSymbol,
                title: ClipboardHistoryCopy.unreadable,
                detail: nil,
                action: nil
            )
        } else if !model.service.preferences.isRecordingEnabled && model.service.records.isEmpty {
            emptyState(
                symbol: ClipboardEmptyPresentation.symbol,
                title: ClipboardHistoryCopy.enableTitle,
                detail: ClipboardHistoryCopy.enableBody,
                action: (ClipboardHistoryCopy.enableAction, onEnableRecording)
            )
        } else if displayedEmpty {
            emptyState(
                symbol: emptySymbol,
                title: emptyTitle,
                detail: emptyDetail,
                action: nil
            )
        } else {
            list
        }
    }

    private var displayedEmpty: Bool {
        model.displayed.isEmpty
    }

    private var emptyTitle: String {
        if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClipboardHistoryCopy.emptySearch
        }
        switch model.tab {
        case .recent:
            return ClipboardHistoryCopy.emptyRecentTitle
        case .favorites:
            return ClipboardHistoryCopy.emptyFavoritesTitle
        }
    }

    private var emptyDetail: String? {
        if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClipboardHistoryCopy.emptySearchDetail
        }
        switch model.tab {
        case .recent:
            return ClipboardHistoryCopy.emptyRecentDetail
        case .favorites:
            return ClipboardHistoryCopy.emptyFavoritesDetail
        }
    }

    private var emptySymbol: String {
        if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClipboardEmptyPresentation.searchSymbol
        }
        return ClipboardEmptyPresentation.symbol
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(model.displayed, selection: $model.selection) { record in
                ClipboardHistoryRow(
                    record: record,
                    isSelected: model.selection == record.id,
                    thumbnail: model.thumbnails.thumbnail(for: record, store: model.service.store),
                    relativeNow: relativeNow,
                    onToggleFavorite: {
                        ClipboardRowQuickAction.toggleFavorite(record.id, using: onToggleFavorite)
                    },
                    onDelete: {
                        ClipboardRowQuickAction.delete(record.id, using: onDelete)
                    },
                    moreMenu: { clipboardMenus(for: record) }
                )
                .id(record.id)
                .contentShape(Rectangle())
                .modifier(GlanceItemDragModifier(
                    sourceID: .clipboard(record.id),
                    nativeText: record.kind == .text ? record.text : nil
                ))
                .onTapGesture(count: 2) {
                    onReuse(record.id)
                }
                .onTapGesture {
                    model.selection = record.id
                }
                .contextMenu {
                    clipboardMenus(for: record)
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
                GlanceEmptyCTA(title: action.0, systemImage: nil, action: action.1)
            }
        }
    }

    @ViewBuilder
    private func clipboardMenus(for record: ClipboardHistoryRecord) -> some View {
        ForEach(GlanceItemActionPolicy.secondaryActions(for: .clipboard(record)), id: \.identifier) { action in
            Button(action.title) {
                onPerformItemAction(action, record.id)
            }
            .accessibilityIdentifier(action.identifier)
        }
        Button(record.isFavorite ? ClipboardHistoryCopy.unfavoriteLabel : ClipboardHistoryCopy.favoriteLabel) {
            onToggleFavorite(record.id)
        }
        Button(ClipboardHistoryCopy.deleteLabel, role: .destructive) {
            onDelete(record.id)
        }
    }

    private var footer: some View {
        HStack(spacing: GlanceTheme.Space.lg) {
            footerHint(ClipboardHistoryCopy.reuseHint)
            footerHint(ClipboardHistoryCopy.panelHint)
            footerHint(ClipboardHistoryCopy.closeHint)
            Spacer()
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.sm)
        .foregroundStyle(.secondary)
        .font(.caption)
    }

    private func footerHint(_ text: String) -> some View {
        Text(text)
    }
}

struct ClipboardHistoryRow<MoreMenu: View>: View {
    var record: ClipboardHistoryRecord
    var isSelected: Bool
    var thumbnail: NSImage?
    var relativeNow: Date
    var onToggleFavorite: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var moreMenu: () -> MoreMenu

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            GlanceRowTrailingAccessory(
                width: GlanceRowQuickActionLayout.slotWidth(for: .clipboard),
                showsActions: showsSecondary
            ) {
                HStack(spacing: 0) {
                    Text(relativeDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if record.isFavorite {
                        GlanceRowIconButton(
                            systemName: "star.fill",
                            help: ClipboardHistoryCopy.unfavoriteLabel,
                            isActive: true,
                            action: onToggleFavorite
                        )
                    }
                }
            } actions: {
                HStack(spacing: 0) {
                    GlanceRowIconButton(
                        systemName: record.isFavorite ? "star.fill" : "star",
                        help: record.isFavorite ? ClipboardHistoryCopy.unfavoriteLabel : ClipboardHistoryCopy.favoriteLabel,
                        isActive: record.isFavorite,
                        action: onToggleFavorite
                    )
                    GlanceRowIconButton(
                        systemName: "trash",
                        help: ClipboardHistoryCopy.deleteLabel,
                        action: onDelete
                    )
                    GlanceRowMoreButton(visible: true, menu: moreMenu)
                }
            }
        }
        .onHover { isHovered = $0 }
        .animation(GlanceMotion.animation, value: showsSecondary)
        .animation(GlanceMotion.animation, value: record.isFavorite)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var showsSecondary: Bool {
        GlanceRowQuickActionVisibility.showsSecondary(isHovered: isHovered, isSelected: isSelected)
    }

    private var title: String {
        switch record.kind {
        case .text:
            return ClipboardHistoryPreview.lines(from: record.text ?? "").0
        case .image:
            return "图片"
        }
    }

    private var subtitle: String? {
        switch record.kind {
        case .text:
            return ClipboardHistoryPreview.lines(from: record.text ?? "").1
        case .image:
            return nil
        }
    }

    private var relativeDate: String {
        ClipboardHistoryRelativeDate.string(from: record.lastCopiedAt, now: relativeNow)
    }

    @ViewBuilder
    private var leading: some View {
        switch record.kind {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var accessibilitySummary: String {
        let favorite = record.isFavorite ? "已收藏" : "未收藏"
        switch record.kind {
        case .text:
            return "文字，\(title)，\(relativeDate)，\(favorite)"
        case .image:
            return "图片，\(relativeDate)，\(favorite)"
        }
    }
}

enum ClipboardHistoryRelativeDate {
    static func string(from date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
