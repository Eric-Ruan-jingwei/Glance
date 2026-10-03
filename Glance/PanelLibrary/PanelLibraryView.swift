import SwiftUI

struct PanelLibraryView: View {
    @ObservedObject var model: PanelLibraryModel

    var body: some View {
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

            Divider()

            if model.isCompletelyEmpty {
                emptyState("还没有面板")
            } else if model.hasNoMatches {
                emptyState("没有匹配的面板")
            } else {
                List(model.visible) { summary in
                    PanelLibraryRow(
                        summary: summary,
                        onReveal: { model.revealPanel(summary.id) },
                        onDelete: { model.confirmDelete(summary.id) },
                        onOpenFolder: { model.openPayloadFolder(summary.id) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        model.revealPanel(summary.id)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("面板")
        .searchable(text: $model.query, prompt: "搜索面板")
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear { model.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .glancePanelCollectionDidChange)) { _ in
            model.reload()
        }
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
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onOpenFolder: () -> Void

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
            }
            Spacer(minLength: 8)
            Button("显示", action: onReveal)
                .controlSize(.small)
            Menu {
                Button("显示", action: onReveal)
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

    private var symbolName: String {
        if summary.isUnreadable { return "exclamationmark.triangle" }
        switch summary.kindIdentifier {
        case "com.glance.panel.text": return "doc.text"
        case "com.glance.panel.markdown": return "text.alignleft"
        case "com.glance.panel.todo": return "checklist"
        case "com.glance.panel.image": return "photo"
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
