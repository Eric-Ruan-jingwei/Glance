import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

enum FileShelfTab: Int, CaseIterable {
    case recent
    case favorites

    var title: String {
        switch self {
        case .recent: return FileShelfCopy.recentTab
        case .favorites: return FileShelfCopy.favoriteTab
        }
    }
}

@MainActor
final class FileShelfViewModel: ObservableObject {
    @Published var query = ""
    @Published var tab: FileShelfTab = .recent
    @Published var selection: UUID?
    @Published var presentationID = 0
    @Published var isDropTargeted = false

    let service: FileShelfService
    let icons: FileShelfIconCache
    private var cancellables = Set<AnyCancellable>()

    init(service: FileShelfService, icons: FileShelfIconCache? = nil) {
        self.service = service
        self.icons = icons ?? FileShelfIconCache()
        service.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var displayed: [FileShelfRecord] {
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
        service.notice = nil
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

    func ensureSelection() {
        let items = displayed
        if let selection, items.contains(where: { $0.id == selection }) {
            return
        }
        self.selection = items.first?.id
    }

    func selectedRecord() -> FileShelfRecord? {
        displayed.first { $0.id == selection }
    }
}

final class FileShelfIconCache {
    private var cache: [UUID: NSImage] = [:]

    func icon(for record: FileShelfRecord, path: String?, missing: Bool) -> NSImage {
        if let cached = cache[record.id], !missing {
            return cached
        }
        let image: NSImage
        if let path, !missing {
            image = MacFileReferenceAdapter.shared.icon(for: path)
            cache[record.id] = image
        } else {
            image = MacFileReferenceAdapter.shared.genericIcon()
        }
        return image
    }

    func evict(_ id: UUID) {
        cache.removeValue(forKey: id)
    }
}

struct FileShelfView: View {
    @ObservedObject var model: FileShelfViewModel
    @FocusState private var searchFocused: Bool
    var onAdd: () -> Void
    var onOpen: (UUID) -> Void
    var onReveal: (UUID) -> Void
    var onPreview: (UUID) -> Void
    var onCopyFile: (UUID) -> Void
    var onCopyPath: (UUID) -> Void
    var onToggleFavorite: (UUID) -> Void
    var onRemove: (UUID) -> Void
    var onRelink: (UUID) -> Void
    var onPerformItemAction: (GlanceItemAction, UUID) -> Void
    var onDropPaths: ([String]) -> Void
    var relativeNow: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted) { providers in
            collectDroppedPaths(providers)
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
                Image(systemName: "tray")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(FileShelfCopy.searchPrompt, text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                    .accessibilityLabel(FileShelfCopy.searchPrompt)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FileShelfCopy.addLabel)
            }
            Picker("", selection: $model.tab) {
                ForEach(FileShelfTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("文件架分组")
            if let notice = model.service.notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        if !model.service.canPersist, case .unsupportedFutureSchema = model.service.loadOutcome {
            emptyState(
                symbol: "exclamationmark.triangle",
                title: FileShelfCopy.futureSchema,
                detail: nil,
                action: nil
            )
        } else if !model.service.canPersist {
            emptyState(
                symbol: "exclamationmark.triangle",
                title: FileShelfCopy.unreadable,
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
        if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return FileShelfCopy.emptySearch
        }
        switch model.tab {
        case .recent:
            return FileShelfCopy.emptyTitle
        case .favorites:
            return FileShelfCopy.emptyFavoritesTitle
        }
    }

    private var emptyDetail: String? {
        if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return FileShelfCopy.emptySearchDetail
        }
        switch model.tab {
        case .recent:
            return FileShelfCopy.emptyDetail
        case .favorites:
            return FileShelfCopy.emptyFavoritesDetail
        }
    }

    private var emptySymbol: String {
        if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return FileShelfEmptyPresentation.searchSymbol
        }
        return FileShelfEmptyPresentation.symbol
    }

    private var emptyAction: (String, () -> Void)? {
        guard FileShelfEmptyPresentation.showsAddCTA(query: model.query, tab: model.tab) else {
            return nil
        }
        return (FileShelfCopy.emptyCTA, { FileShelfEmptyPresentation.add(using: onAdd) })
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(model.displayed, selection: $model.selection) { record in
                let resolved = model.service.resolve(record.id)
                FileShelfRow(
                    record: record,
                    isSelected: model.selection == record.id,
                    missing: resolved.isMissing,
                    icon: model.icons.icon(for: record, path: resolved.urlPath ?? record.originalPath, missing: resolved.isMissing),
                    relativeNow: relativeNow,
                    onPrimary: {
                        FileShelfRowQuickAction.performPrimary(
                            missing: resolved.isMissing,
                            id: record.id,
                            onOpen: onOpen,
                            onRelink: onRelink
                        )
                    },
                    onToggleFavorite: { onToggleFavorite(record.id) },
                    onRemove: {
                        FileShelfRowQuickAction.remove(record.id, using: onRemove)
                    },
                    moreMenu: { contextMenu(for: record, missing: resolved.isMissing, resolution: resolved) }
                )
                .id(record.id)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onOpen(record.id)
                }
                .onTapGesture {
                    model.selection = record.id
                }
                .contextMenu {
                    contextMenu(for: record, missing: resolved.isMissing, resolution: resolved)
                }
                .modifier(FileShelfDragModifier(
                    recordID: record.id,
                    path: FileShelfDragPayload.fileURL(
                        resolvedPath: resolved.urlPath,
                        fileExists: !resolved.isMissing
                    )
                ))
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
    private func contextMenu(
        for record: FileShelfRecord,
        missing: Bool,
        resolution: FileShelfResolvedReference
    ) -> some View {
        if missing {
            GlanceMenuButton(
                title: FileShelfCopy.relinkLabel,
                systemImage: GlanceActionSymbol.relink
            ) {
                onRelink(record.id)
            }
        } else {
            GlanceMenuButton(
                title: FileShelfCopy.openLabel,
                systemImage: GlanceActionSymbol.openFile
            ) {
                onOpen(record.id)
            }
            GlanceMenuButton(
                title: FileShelfCopy.revealLabel,
                systemImage: GlanceActionSymbol.reveal
            ) {
                onReveal(record.id)
            }
            GlanceMenuButton(
                title: FileShelfCopy.previewLabel,
                systemImage: GlanceActionSymbol.preview
            ) {
                onPreview(record.id)
            }
            Divider()
            GlanceMenuButton(
                title: FileShelfCopy.copyFileLabel,
                systemImage: GlanceActionSymbol.copy
            ) {
                onCopyFile(record.id)
            }
            GlanceMenuButton(
                title: FileShelfCopy.copyPathLabel,
                systemImage: GlanceActionSymbol.copy
            ) {
                onCopyPath(record.id)
            }
            fileShelfPanelMenu(for: record, resolution: resolution)
        }
        Divider()
        GlanceMenuButton(
            title: record.isFavorite ? FileShelfCopy.unfavoriteLabel : FileShelfCopy.favoriteLabel,
            systemImage: GlanceActionSymbol.favorite(isOn: record.isFavorite)
        ) {
            onToggleFavorite(record.id)
        }
        GlanceMenuButton(
            title: FileShelfCopy.removeLabel,
            systemImage: GlanceActionSymbol.remove
        ) {
            onRemove(record.id)
        }
    }

    @ViewBuilder
    private func fileShelfPanelMenu(
        for record: FileShelfRecord,
        resolution: FileShelfResolvedReference
    ) -> some View {
        let panelActions = fileShelfActions(for: record, resolution: resolution)
        if !panelActions.isEmpty {
            Divider()
            ForEach(panelActions, id: \.identifier) { action in
                GlanceMenuButton(
                    title: action.title,
                    systemImage: action.symbolName,
                    identifier: action.identifier
                ) {
                    onPerformItemAction(action, record.id)
                }
            }
        }
    }

    private func fileShelfActions(
        for record: FileShelfRecord,
        resolution: FileShelfResolvedReference
    ) -> [GlanceItemAction] {
        GlanceItemActionPolicy.actions(for: .fileShelf(record, resolution: resolution))
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
                    accessibilityText: FileShelfCopy.addLabel,
                    systemImage: "plus",
                    action: action.1
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: GlanceShortcutHintBar.spacing) {
            ForEach(Array(GlanceShortcutFooter.fileShelf.enumerated()), id: \.offset) { _, hint in
                GlanceShortcutHint(keys: hint.keys, label: hint.label)
            }
            Spacer()
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.sm)
    }

    private func collectDroppedPaths(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var paths: [String] = []
        let lock = NSLock()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? URL {
                    url = value
                } else {
                    url = nil
                }
                if let url, url.isFileURL {
                    lock.lock()
                    paths.append(url.path)
                    lock.unlock()
                }
            }
        }
        group.notify(queue: .main) {
            onDropPaths(paths)
        }
    }
}

private struct FileShelfDragModifier: ViewModifier {
    var recordID: UUID
    var path: String?

    func body(content: Content) -> some View {
        content.modifier(GlanceItemDragModifier(
            sourceID: .fileShelf(recordID),
            nativeURL: path.map { URL(fileURLWithPath: $0) }
        ))
    }
}

struct FileShelfRow<MoreMenu: View>: View {
    var record: FileShelfRecord
    var isSelected: Bool
    var missing: Bool
    var icon: NSImage
    var relativeNow: Date
    var onPrimary: () -> Void
    var onToggleFavorite: () -> Void
    var onRemove: () -> Void
    @ViewBuilder var moreMenu: () -> MoreMenu

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .opacity(missing ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayName)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(missing ? Color.secondary : Color.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            GlanceRowTrailingAccessory(
                width: GlanceRowQuickActionLayout.slotWidth(for: .fileShelf),
                showsActions: showsSecondary
            ) {
                if record.isFavorite {
                    GlanceRowIconButton(
                        systemName: "star.fill",
                        help: FileShelfCopy.unfavoriteLabel,
                        isActive: true,
                        action: onToggleFavorite
                    )
                }
            } actions: {
                HStack(spacing: 0) {
                    GlanceRowIconButton(
                        systemName: FileShelfQuickAction.primarySymbol(missing: missing),
                        help: FileShelfQuickAction.primaryHelp(missing: missing),
                        action: onPrimary
                    )
                    GlanceRowIconButton(
                        systemName: record.isFavorite ? "star.fill" : "star",
                        help: record.isFavorite ? FileShelfCopy.unfavoriteLabel : FileShelfCopy.favoriteLabel,
                        isActive: record.isFavorite,
                        action: onToggleFavorite
                    )
                    GlanceRowIconButton(
                        systemName: FileShelfQuickAction.removeSymbol,
                        help: FileShelfCopy.removeLabel,
                        action: onRemove
                    )
                    GlanceRowMoreButton(
                        visible: true,
                        help: GlanceRowActionCopy.moreHelp(for: record.displayName),
                        menu: moreMenu
                    )
                }
            }
        }
        .onHover { isHovered = $0 }
        .animation(GlanceMotion.animation, value: showsSecondary)
        .animation(GlanceMotion.animation, value: record.isFavorite)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var showsSecondary: Bool {
        GlanceRowQuickActionVisibility.showsSecondary(isHovered: isHovered, isSelected: isSelected)
    }

    private var subtitle: String {
        if missing {
            return "⚠ \(FileShelfCopy.missing)"
        }
        let kind = FileShelfTypeLabel.display(
            name: record.displayName,
            typeIdentifier: record.contentTypeIdentifier
        )
        let size = FileShelfSizeFormatter.string(record.fileSize)
        let time = FileShelfRelativeDate.string(from: record.lastUsedAt, now: relativeNow)
        return [kind, size, time].compactMap { $0 }.joined(separator: " · ")
    }

    private var accessibilitySummary: String {
        let favorite = record.isFavorite ? "已收藏" : "未收藏"
        if missing {
            return "\(record.displayName)，\(FileShelfCopy.missing)，\(favorite)"
        }
        return "\(record.displayName)，\(subtitle)，\(favorite)"
    }
}

enum FileShelfRelativeDate {
    static func string(from date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

enum FileShelfSizeFormatter {
    static func string(_ bytes: Int64?) -> String? {
        guard let bytes else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }
}
