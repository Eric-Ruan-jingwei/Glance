import AppKit
import Combine
import SwiftUI

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
            emptyState(title: ClipboardHistoryCopy.futureSchema, detail: nil, action: nil)
        } else if !model.service.canPersist {
            emptyState(title: ClipboardHistoryCopy.unreadable, detail: nil, action: nil)
        } else if !model.service.preferences.isRecordingEnabled && model.service.records.isEmpty {
            emptyState(
                title: ClipboardHistoryCopy.enableTitle,
                detail: ClipboardHistoryCopy.enableBody,
                action: (ClipboardHistoryCopy.enableAction, onEnableRecording)
            )
        } else if displayedEmpty {
            emptyState(title: emptyTitle, detail: emptyDetail, action: nil)
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
            return nil
        }
        switch model.tab {
        case .recent:
            return ClipboardHistoryCopy.emptyRecentDetail
        case .favorites:
            return ClipboardHistoryCopy.emptyFavoritesDetail
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(model.displayed, selection: $model.selection) { record in
                ClipboardHistoryRow(
                    record: record,
                    isSelected: model.selection == record.id,
                    thumbnail: model.thumbnails.thumbnail(for: record, store: model.service.store),
                    relativeNow: relativeNow,
                    onToggleFavorite: { onToggleFavorite(record.id) },
                    onDelete: { onDelete(record.id) }
                )
                .id(record.id)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onReuse(record.id)
                }
                .onTapGesture {
                    model.selection = record.id
                }
                .contextMenu {
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

struct ClipboardHistoryRow: View {
    var record: ClipboardHistoryRecord
    var isSelected: Bool
    var thumbnail: NSImage?
    var relativeNow: Date
    var onToggleFavorite: () -> Void
    var onDelete: () -> Void

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
            Spacer(minLength: GlanceTheme.Space.sm)
            Text(relativeDate)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(action: onToggleFavorite) {
                Image(systemName: record.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(record.isFavorite ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(record.isFavorite ? ClipboardHistoryCopy.unfavoriteLabel : ClipboardHistoryCopy.favoriteLabel)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isSelected ? 1 : 0.35)
            .accessibilityLabel(ClipboardHistoryCopy.deleteLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
