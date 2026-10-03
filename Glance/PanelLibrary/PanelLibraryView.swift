import SwiftUI

struct PanelLibraryView: View {
    @ObservedObject var model: PanelLibraryModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedWorkspaceID) {
                ForEach(model.workspaces) { workspace in
                    Text(workspace.name)
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
            .navigationSplitViewColumnWidth(min: 140, ideal: 168, max: 220)
            .safeAreaInset(edge: .bottom) {
                Button("新建工作区…") {
                    model.promptCreateWorkspace()
                }
                .buttonStyle(.borderless)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("类型", selection: $model.filter) {
                        ForEach(PanelSummaryKindFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    HStack {
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
                            Text(model.tagFilterTitle)
                        }
                        .menuStyle(.borderlessButton)
                        Spacer()
                        if !model.visible.isEmpty {
                            Button("全选当前结果") {
                                model.selectAllVisible()
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    if !model.selectedPanelIDs.isEmpty {
                        batchToolbar
                    }

                    Divider()

                    if model.isCompletelyEmpty {
                        emptyState("这个工作区还没有面板")
                    } else if model.hasNoMatches {
                        emptyState("没有匹配的面板")
                    } else {
                        List(selection: $model.selectedPanelIDs) {
                            ForEach(model.visible) { summary in
                                PanelLibraryRow(
                                    summary: summary,
                                    workspaces: model.workspaces,
                                    onReveal: { model.revealPanel(summary.id) },
                                    onHide: { model.hidePanel(summary.id) },
                                    onRename: { model.promptRename(summary) },
                                    onEditTags: { model.promptEditTags(summary) },
                                    onDelete: { model.confirmDelete(summary.id) },
                                    onOpenFolder: { model.openPayloadFolder(summary.id) },
                                    onMove: { model.movePanelToWorkspace(summary.id, workspaceID: $0) }
                                )
                                .tag(summary.id)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    model.selectSingle(summary.id)
                                    model.revealPanel(summary.id)
                                }
                            }
                        }
                        .listStyle(.inset)
                    }
                }
                .navigationTitle("面板")
                .searchable(text: $model.query, prompt: "搜索面板")
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

    private var batchToolbar: some View {
        HStack(spacing: 8) {
            Text("已选择 \(model.selectedPanelIDs.count) 个")
                .font(.callout.weight(.medium))
            Button("隐藏") { model.batchHide() }
                .disabled(!model.canBatchHide)
            Button("显示") { model.batchShow() }
                .disabled(!model.canBatchShow)
            Menu("移动到工作区…") {
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
            Menu("标签…") {
                Button("添加标签…") { model.promptBatchAddTags() }
                Button("移除标签…") { model.promptBatchRemoveTags() }
                    .disabled(model.selectedTagUnion.isEmpty)
            }
            Button("取消选择") { model.clearSelection() }
            Spacer(minLength: 0)
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func emptyState(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PanelLibraryRow: View {
    let summary: PanelSummary
    let workspaces: [WorkspaceRecord]
    let onReveal: () -> Void
    let onHide: () -> Void
    let onRename: () -> Void
    let onEditTags: () -> Void
    let onDelete: () -> Void
    let onOpenFolder: () -> Void
    let onMove: (String) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(summary.isUnreadable ? Color.orange : Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 6) {
                    Text(metaLine)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                    Image(systemName: PanelVisibilityMenu.symbolName(isHidden: summary.isHidden))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if summary.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if summary.isPassThrough {
                        Text("穿透")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if summary.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !summary.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tagPreview.shown, id: \.self) { tag in
                            PanelTagChip(text: tag)
                        }
                        if tagPreview.overflow > 0 {
                            Text("+\(tagPreview.overflow)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Button(PanelVisibilityMenu.libraryActionTitle(isHidden: summary.isHidden), action: primaryAction)
                .controlSize(.small)
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
                Image(systemName: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
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

    private var symbolName: String {
        if summary.isUnreadable { return "exclamationmark.triangle" }
        switch summary.kindIdentifier {
        case "com.glance.panel.text": return "doc.text"
        case "com.glance.panel.markdown": return "text.alignleft"
        case "com.glance.panel.todo": return "checklist"
        case "com.glance.panel.image": return "photo"
        case "com.glance.panel.pdf": return "doc.richtext"
        default: return "square.dashed"
        }
    }

    private var metaLine: String {
        let kind = PanelSummaryKindLabel.displayName(for: summary.kindIdentifier)
        let time = Self.dateFormatter.localizedString(for: summary.updatedAt, relativeTo: Date())
        if let subtitle = summary.subtitle, !subtitle.isEmpty {
            return "\(kind) · \(subtitle) · \(time)"
        }
        return "\(kind) · \(time)"
    }

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
