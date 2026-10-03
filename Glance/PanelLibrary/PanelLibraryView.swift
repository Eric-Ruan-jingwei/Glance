import SwiftUI

struct PanelLibraryView: View {
    @ObservedObject var model: PanelLibraryModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedWorkspaceID) {
                Section("工作区") {
                    ForEach(model.workspaces) { workspace in
                        Label {
                            HStack(spacing: GlanceTheme.Space.xs) {
                                Text(workspace.name)
                                    .lineLimit(1)
                                Spacer(minLength: GlanceTheme.Space.xs)
                                Text("\(model.panelCount(in: workspace.id))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: workspace.id == WorkspaceRecord.defaultID
                                  ? "square.stack"
                                  : "square.on.square")
                        }
                        .tag(workspace.id)
                        .contextMenu {
                            if workspace.id != WorkspaceRecord.defaultID {
                                Button("重命名") {
                                    model.promptRenameWorkspace(workspace.id)
                                }
                                Button("删除工作区", role: .destructive) {
                                    model.confirmDeleteWorkspace(workspace.id)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(
                min: 140,
                ideal: GlanceTheme.Size.sidebarIdeal,
                max: 220
            )
            .safeAreaInset(edge: .bottom) {
                Button {
                    model.promptCreateWorkspace()
                } label: {
                    Label("新建工作区…", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .padding(GlanceTheme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            NavigationStack {
                Group {
                    switch model.emptyKind {
                    case .loading:
                        ProgressView(GlanceEmptyCopy.loadingTitle)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .emptyWorkspace:
                        GlanceEmptyState(
                            symbol: "square.stack",
                            title: GlanceEmptyCopy.workspaceTitle,
                            detail: GlanceEmptyCopy.workspaceDetail
                        )
                    case .noSearchResults:
                        GlanceEmptyState(
                            symbol: "magnifyingglass",
                            title: GlanceEmptyCopy.searchTitle,
                            detail: GlanceEmptyCopy.searchDetail
                        )
                    case .noFilterMatches:
                        GlanceEmptyState(
                            symbol: "line.3.horizontal.decrease",
                            title: GlanceEmptyCopy.filterTitle,
                            detail: GlanceEmptyCopy.filterDetail
                        )
                    case .none:
                        ScrollViewReader { proxy in
                            List(selection: $model.selectedPanelIDs) {
                                ForEach(model.visible) { summary in
                                    PanelLibraryRow(
                                        summary: summary,
                                        workspaces: model.workspaces,
                                        isSelected: model.selectedPanelIDs.contains(summary.id),
                                        onReveal: { model.revealPanel(summary.id) },
                                        onHide: { model.hidePanel(summary.id) },
                                        onRename: { model.promptRename(summary) },
                                        onEditTags: { model.promptEditTags(summary) },
                                        onDelete: { model.confirmDelete(summary.id) },
                                        onOpenFolder: { model.openPayloadFolder(summary.id) },
                                        onMove: { model.movePanelToWorkspace(summary.id, workspaceID: $0) }
                                    )
                                    .tag(summary.id)
                                    .id(summary.id)
                                    .listRowInsets(
                                        EdgeInsets(
                                            top: GlanceTheme.Space.sm,
                                            leading: GlanceTheme.Space.md,
                                            bottom: GlanceTheme.Space.sm,
                                            trailing: GlanceTheme.Space.md
                                        )
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        model.selectSingle(summary.id)
                                        model.revealPanel(summary.id)
                                    }
                                }
                            }
                            .listStyle(.inset)
                            .onAppear {
                                scrollPendingRevealIfNeeded(using: proxy)
                            }
                            .onChange(of: model.pendingScrollID) { _, _ in
                                scrollPendingRevealIfNeeded(using: proxy)
                            }
                            .safeAreaInset(edge: .top, spacing: 0) {
                                if model.showsBatchToolbar {
                                    batchToolbar
                                }
                            }
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: GlanceMotion.duration),
                                value: model.showsBatchToolbar
                            )
                        }
                    }
                }
                .navigationTitle("Glance")
                .searchable(text: $model.query, placement: .toolbar, prompt: "搜索面板")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Picker("类型", selection: $model.filter) {
                            ForEach(PanelSummaryKindFilter.allCases, id: \.self) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(maxWidth: 340)
                    }
                    ToolbarItem {
                        Menu {
                            Button("全部") {
                                model.selectTagFilter(nil)
                            }
                            if !model.availableFilterTags.isEmpty {
                                Divider()
                                ForEach(model.availableFilterTags, id: \.self) { tag in
                                    Button(tag) {
                                        model.selectTagFilter(tag)
                                    }
                                }
                            }
                        } label: {
                            Label(model.tagFilterTitle, systemImage: "line.3.horizontal.decrease")
                        }
                    }
                    ToolbarItem {
                        if !model.visible.isEmpty {
                            Button("全选当前结果") {
                                model.selectAllVisible()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 720, minHeight: 420)
        .onAppear { model.reload() }
        .onChange(of: model.selectedWorkspaceID) { _, newValue in
            model.activateWorkspace(newValue)
        }
        .onChange(of: model.query) { _, _ in
            model.reconcileSelection()
        }
        .onChange(of: model.filter) { _, _ in
            model.reconcileSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glancePanelCollectionDidChange)) { _ in
            model.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glanceWorkspaceDidChange)) { _ in
            model.reload()
        }
    }

    private func scrollPendingRevealIfNeeded(using proxy: ScrollViewProxy) {
        guard model.pendingScrollID != nil else { return }
        DispatchQueue.main.async {
            guard let id = model.consumePendingScroll() else { return }
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private var batchToolbar: some View {
        HStack(spacing: GlanceTheme.Space.sm) {
            Text("已选择 \(model.selectedPanelIDs.count) 个")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("已选择 \(model.selectedPanelIDs.count) 个面板")
            batchToolbarDivider
            Button("隐藏") { model.batchHide() }
                .disabled(!model.canBatchHide)
            Button("显示") { model.batchShow() }
                .disabled(!model.canBatchShow)
            batchToolbarDivider
            Menu("移动到…") {
                ForEach(model.workspaces) { workspace in
                    Button {
                        model.batchMove(to: workspace.id)
                    } label: {
                        if model.allSelectedBelong(to: workspace.id) {
                            Label(workspace.name, systemImage: "checkmark")
                        } else {
                            Text(workspace.name)
                        }
                    }
                    .disabled(model.allSelectedBelong(to: workspace.id))
                }
            }
            Menu("标签") {
                Button("添加标签…") { model.promptBatchAddTags() }
                Button("移除标签…") { model.promptBatchRemoveTags() }
                    .disabled(model.selectedTagUnion.isEmpty)
            }
            Spacer(minLength: 0)
            Button("取消选择") { model.clearSelection() }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .frame(maxWidth: .infinity, minHeight: GlanceTheme.Size.controlHeight)
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.xs)
        .background(.bar)
    }

    private var batchToolbarDivider: some View {
        Divider()
            .frame(height: 12)
            .opacity(0.5)
    }
}

private struct PanelLibraryRow: View {
    let summary: PanelSummary
    let workspaces: [WorkspaceRecord]
    let isSelected: Bool
    let onReveal: () -> Void
    let onHide: () -> Void
    let onRename: () -> Void
    let onEditTags: () -> Void
    let onDelete: () -> Void
    let onOpenFolder: () -> Void
    let onMove: (String) -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            Image(systemName: PanelKindSymbol.name(
                for: summary.kindIdentifier,
                unreadable: summary.isUnreadable
            ))
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                Color.glanceHoverFill,
                in: RoundedRectangle(cornerRadius: GlanceTheme.Radius.control, style: .continuous)
            )
            .accessibilityLabel(kindAccessibilityLabel)

            VStack(alignment: .leading, spacing: GlanceTheme.Space.xxs) {
                Text(summary.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if summary.isUnreadable {
                    Text("内容无法读取，文件仍保留在本地。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else if let subtitle = summary.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: GlanceTheme.Space.sm) {
                    Text(tertiaryLine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    if summary.isHidden {
                        Image(systemName: PanelVisibilityMenu.symbolName(isHidden: true))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("已隐藏")
                    }
                    if summary.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("已锁定")
                    }
                    if summary.isPassThrough {
                        Image(systemName: "hand.tap")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("点击穿透")
                    }
                    if summary.isPinned {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("已固定")
                    }
                }

                if !summary.tags.isEmpty {
                    HStack(spacing: GlanceTheme.Space.xs) {
                        ForEach(tagPreview.shown, id: \.self) { tag in
                            PanelTagChip(text: tag)
                        }
                        if tagPreview.overflow > 0 {
                            Text("+\(tagPreview.overflow)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .lineLimit(1)
                }
            }
            .layoutPriority(0)

            Spacer(minLength: GlanceTheme.Space.sm)

            HStack(spacing: GlanceTheme.Space.xs) {
                Button(PanelVisibilityMenu.libraryActionTitle(isHidden: summary.isHidden), action: primaryAction)
                    .controlSize(.small)
                    .opacity(showsSecondaryActions ? 1 : 0)
                    .allowsHitTesting(showsSecondaryActions)
                Menu {
                    Button(PanelVisibilityMenu.libraryActionTitle(isHidden: summary.isHidden), action: primaryAction)
                    Button("重命名…", action: onRename)
                    Button("编辑标签…", action: onEditTags)
                    Menu(PanelVisibilityMenu.moveToWorkspace) {
                        ForEach(workspaces) { workspace in
                            Button {
                                onMove(workspace.id)
                            } label: {
                                if workspace.id == summary.workspaceID {
                                    Label(workspace.name, systemImage: "checkmark")
                                } else {
                                    Text(workspace.name)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("打开数据文件夹", action: onOpenFolder)
                    Divider()
                    Button("删除", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel("更多操作")
                .menuIndicator(.hidden)
                .fixedSize()
                .buttonStyle(.borderless)
                .opacity(showsSecondaryActions ? 1 : 0)
                .allowsHitTesting(showsSecondaryActions)
            }
            .layoutPriority(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, GlanceTheme.Space.xxs)
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: GlanceMotion.duration),
            value: showsSecondaryActions
        )
    }

    private var showsSecondaryActions: Bool {
        isHovered || isSelected
    }

    private var tagPreview: (shown: [String], overflow: Int) {
        PanelTags.rowPreview(summary.tags)
    }

    private func primaryAction() {
        if summary.isHidden {
            onReveal()
        } else {
            onHide()
        }
    }

    private var kindAccessibilityLabel: String {
        if summary.isUnreadable { return "无法读取内容" }
        return PanelSummaryKindLabel.displayName(for: summary.kindIdentifier)
    }

    private var tertiaryLine: String {
        let kind = PanelSummaryKindLabel.displayName(for: summary.kindIdentifier)
        return "\(kind) · \(editedLabel)"
    }

    private var editedLabel: String {
        if Calendar.current.isDateInToday(summary.updatedAt) {
            return "最后编辑：今天 \(Self.timeFormatter.string(from: summary.updatedAt))"
        }
        if Calendar.current.isDateInYesterday(summary.updatedAt) {
            return "最后编辑：昨天 \(Self.timeFormatter.string(from: summary.updatedAt))"
        }
        return "最后编辑：\(Self.relativeFormatter.localizedString(for: summary.updatedAt, relativeTo: Date()))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
