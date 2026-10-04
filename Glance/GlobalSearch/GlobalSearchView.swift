import AppKit
import SwiftUI

struct GlobalSearchView: View {
    @ObservedObject var model: GlobalSearchViewModel
    @FocusState private var searchFocused: Bool
    var onActivate: (GlobalSearchResultID) -> Void
    var onRevealInSource: (GlobalSearchResultID) -> Void
    var onPerformItemAction: (GlanceItemAction, GlobalSearchResultID) -> Void = { _, _ in }
    var onItemActions: (GlobalSearchResultID) -> [GlanceItemAction] = { _ in [] }
    var relativeNow: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
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
        .onChange(of: model.query) { _, _ in model.reconcileSelection() }
        .onChange(of: model.presentationID) { _, _ in
            searchFocused = true
        }
        .onAppear {
            searchFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: GlanceTheme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(GlobalSearchCopy.searchPrompt, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($searchFocused)
                .accessibilityLabel(GlobalSearchCopy.searchPrompt)
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.md)
    }

    @ViewBuilder
    private var content: some View {
        if model.displayed.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var emptyState: some View {
        VStack(spacing: GlanceTheme.Space.md) {
            Spacer(minLength: GlanceTheme.Space.lg)
            Text(
                model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? GlobalSearchCopy.emptyRecent
                    : GlobalSearchCopy.emptySearch
            )
            .font(.headline)
            .foregroundStyle(.secondary)
            Spacer(minLength: GlanceTheme.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.sectionTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, GlanceTheme.Space.lg)
                .padding(.top, GlanceTheme.Space.sm)
                .padding(.bottom, GlanceTheme.Space.xs)
            ScrollViewReader { proxy in
                List(model.displayed, selection: selectionBinding) { document in
                    GlobalSearchRow(document: document, relativeNow: relativeNow)
                        .id(document.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            onActivate(document.id)
                        }
                        .onTapGesture {
                            model.selection = document.id
                        }
                        .contextMenu {
                            contextMenu(for: document.id)
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
                                .fill(model.selection == document.id ? Color.accentColor.opacity(0.14) : Color.clear)
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
    }

    @ViewBuilder
    private func contextMenu(for id: GlobalSearchResultID) -> some View {
        Button(GlobalSearchCopy.revealInSourceLabel) {
            onRevealInSource(id)
        }
        let actions = onItemActions(id)
        if !actions.isEmpty {
            Divider()
            ForEach(actions, id: \.identifier) { action in
                Button(action.title) {
                    onPerformItemAction(action, id)
                }
                .accessibilityIdentifier(action.identifier)
            }
        }
    }

    private var selectionBinding: Binding<GlobalSearchResultID?> {
        Binding(
            get: { model.selection },
            set: { model.selection = $0 }
        )
    }

    private var footer: some View {
        HStack(spacing: GlanceTheme.Space.lg) {
            Text(GlobalSearchCopy.selectHint)
            Text(GlobalSearchCopy.actHint)
            Text(GlobalSearchCopy.revealHint)
            Text(GlobalSearchCopy.closeHint)
            Spacer()
            if model.isLoadingPanels {
                Text(GlobalSearchCopy.loadingPanels)
            } else if model.showsPartialUnavailable {
                Text(GlobalSearchCopy.partialUnavailable)
            }
        }
        .padding(.horizontal, GlanceTheme.Space.lg)
        .padding(.vertical, GlanceTheme.Space.sm)
        .foregroundStyle(.secondary)
        .font(.caption)
    }
}

struct GlobalSearchRow: View {
    var document: GlobalSearchDocument
    var relativeNow: Date

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            Image(systemName: document.rowSymbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.body)
                    .lineLimit(1)
                if let preview = rowPreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: GlanceTheme.Space.sm)
            VStack(alignment: .trailing, spacing: 2) {
                Text(document.source.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(GlobalSearchRelativeDate.string(from: document.activityAt, now: relativeNow))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .opacity(document.isUnavailable ? 0.7 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var rowPreview: String? {
        if document.isUnavailable, document.source == .fileShelf {
            return GlobalSearchCopy.fileMissingRow
        }
        return document.preview ?? document.subtitle
    }

    private var accessibilitySummary: String {
        let time = GlobalSearchRelativeDate.string(from: document.activityAt, now: relativeNow)
        var parts = [document.title, document.source.displayName, time]
        if let preview = rowPreview {
            parts.insert(preview, at: 1)
        }
        return parts.joined(separator: "，")
    }
}

enum GlobalSearchRelativeDate {
    static func string(from date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

