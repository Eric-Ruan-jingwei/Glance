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
                    GlobalSearchRow(
                        document: document,
                        relativeNow: relativeNow,
                        isSelected: model.selection == document.id,
                        onSelect: { model.selection = document.id },
                        onActivate: { onActivate(document.id) },
                        onRevealInSource: { onRevealInSource(document.id) },
                        onPerformItemAction: { onPerformItemAction($0, document.id) },
                        itemActions: { onItemActions(document.id) }
                    )
                    .id(document.id)
                    .contextMenu {
                        actionsMenu(for: document.id)
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
    private func actionsMenu(for id: GlobalSearchResultID) -> some View {
        GlobalSearchDeferredActionsMenu(
            itemActions: { onItemActions(id) },
            onReveal: { onRevealInSource(id) },
            onAction: { onPerformItemAction($0, id) }
        )
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
    var isSelected: Bool = false
    var onSelect: () -> Void = {}
    var onActivate: () -> Void = {}
    var onRevealInSource: () -> Void = {}
    var onPerformItemAction: (GlanceItemAction) -> Void = { _ in }
    var itemActions: () -> [GlanceItemAction] = { [] }

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
                Image(systemName: document.rowSymbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: GlobalSearchRowActionPresentation.sourceIconSide,
                        height: GlobalSearchRowActionPresentation.sourceIconSide
                    )
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
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onActivate)
            .onTapGesture(perform: onSelect)

            GlanceRowTrailingAccessory(
                width: GlobalSearchRowActionPresentation.trailingWidth,
                showsActions: showsEllipsis
            ) {
                Color.clear
            } actions: {
                GlanceLazyMoreButton(
                    help: GlobalSearchRowActionPresentation.moreHelp(title: document.title),
                    itemActions: itemActions,
                    onReveal: onRevealInSource,
                    onAction: onPerformItemAction
                )
                .frame(
                    width: GlanceRowQuickActionLayout.buttonSide,
                    height: GlanceRowQuickActionLayout.buttonSide
                )
            }
        }
        .opacity(document.isUnavailable ? 0.7 : 1)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var showsEllipsis: Bool {
        GlobalSearchRowActionPresentation.showsEllipsis(
            isHovered: isHovered,
            isSelected: isSelected
        )
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

struct GlobalSearchDeferredActionsMenu: View {
    var itemActions: () -> [GlanceItemAction]
    var onReveal: () -> Void
    var onAction: (GlanceItemAction) -> Void

    var body: some View {
        ForEach(GlobalSearchResultMenu.items(itemActions: itemActions)) { item in
            switch item {
            case .reveal:
                Button(GlobalSearchCopy.revealInSourceLabel, action: onReveal)
            case .divider:
                Divider()
            case .action(let action):
                Button(action.title) {
                    onAction(action)
                }
                .accessibilityIdentifier(action.identifier)
            }
        }
    }
}

struct GlanceLazyMoreButton: NSViewRepresentable {
    var help: String
    var itemActions: () -> [GlanceItemAction]
    var onReveal: () -> Void
    var onAction: (GlanceItemAction) -> Void

    func makeNSView(context: Context) -> GlanceLazyMoreNSButton {
        let button = GlanceLazyMoreNSButton()
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.bezelStyle = .inline
        button.focusRingType = .none
        applyChrome(button)
        return button
    }

    func updateNSView(_ nsView: GlanceLazyMoreNSButton, context: Context) {
        context.coordinator.onReveal = onReveal
        context.coordinator.onAction = onAction
        context.coordinator.itemActions = itemActions
        nsView.toolTip = help
        nsView.setAccessibilityLabel(help)
        nsView.makeMenu = { [weak coordinator = context.coordinator] in
            coordinator?.makeMenu() ?? NSMenu()
        }
        applyChrome(nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func applyChrome(_ button: GlanceLazyMoreNSButton) {
        let image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: help)
        image?.isTemplate = true
        button.image = image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        )
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = help
        button.setAccessibilityLabel(help)
        button.setAccessibilityRole(.button)
        button.setAccessibilityHelp(GlanceRowActionCopy.more)
    }

    final class Coordinator: NSObject {
        var onReveal: () -> Void = {}
        var onAction: (GlanceItemAction) -> Void = { _ in }
        var itemActions: () -> [GlanceItemAction] = { [] }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()
            for item in GlobalSearchResultMenu.items(itemActions: itemActions) {
                switch item {
                case .reveal:
                    let menuItem = NSMenuItem(
                        title: GlobalSearchCopy.revealInSourceLabel,
                        action: #selector(reveal),
                        keyEquivalent: ""
                    )
                    menuItem.target = self
                    menu.addItem(menuItem)
                case .divider:
                    menu.addItem(.separator())
                case .action(let action):
                    let menuItem = NSMenuItem(
                        title: action.title,
                        action: #selector(performAction(_:)),
                        keyEquivalent: ""
                    )
                    menuItem.target = self
                    menuItem.representedObject = action.identifier
                    menuItem.identifier = NSUserInterfaceItemIdentifier(action.identifier)
                    menu.addItem(menuItem)
                }
            }
            return menu
        }

        @objc func reveal() {
            onReveal()
        }

        @objc func performAction(_ sender: NSMenuItem) {
            guard let identifier = sender.representedObject as? String,
                  let action = GlanceItemAction(identifier: identifier) else {
                return
            }
            onAction(action)
        }
    }
}

final class GlanceLazyMoreNSButton: NSButton {
    var makeMenu: () -> NSMenu = { NSMenu() }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: GlanceRowQuickActionLayout.buttonSide,
            height: GlanceRowQuickActionLayout.buttonSide
        )
    }

    override func mouseDown(with event: NSEvent) {
        let menu = makeMenu()
        guard menu.numberOfItems > 0 else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 2), in: self)
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

