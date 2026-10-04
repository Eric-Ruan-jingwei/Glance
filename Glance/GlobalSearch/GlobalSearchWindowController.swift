import AppKit
import SwiftUI

@MainActor
final class GlobalSearchWindowController: NSWindowController {
    var onRevealInSource: ((GlobalSearchResultID) -> GlanceActionOutcome)?
    var onPerformItemAction: ((GlanceItemAction, GlobalSearchResultID, NSScreen?) -> GlanceActionOutcome)?
    var onAvailableItemActions: ((GlobalSearchResultID) -> [GlanceItemAction])?

    private let model: GlobalSearchViewModel
    private let environment: AppEnvironment
    private let panelManager: PanelManager
    private let opener: LinkOpening
    private let clipboardWriter: GlanceClipboardWriter
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    var isSearchVisible: Bool {
        window?.isVisible == true
    }

    init(
        environment: AppEnvironment,
        panelManager: PanelManager,
        opener: LinkOpening = MacLinkOpener(),
        summaryLoader: any PanelSummaryLoading = PanelSummaryLoader()
    ) {
        self.environment = environment
        self.panelManager = panelManager
        self.opener = opener
        self.clipboardWriter = GlanceClipboardWriter(monitor: environment.clipboardHistoryMonitor)
        self.model = GlobalSearchViewModel(summaryLoader: summaryLoader)
        let panel = GlobalSearchPanel(
            contentRect: NSRect(origin: .zero, size: GlanceConstants.globalSearchSize)
        )
        super.init(window: panel)
        panel.windowController = self
        installContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        switch UtilityWindowPresentation.toggleAction(for: window) {
        case .dismiss:
            dismiss(deactivate: true)
        case .bringForward:
            UtilityWindowPresentation.bringForward(window)
        case .present:
            present()
        }
    }

    func present() {
        model.resetPresentation()
        model.applyImmediateSnapshot(currentSnapshot())
        UtilityWindowPresentation.present(window, size: GlanceConstants.globalSearchSize)
        installDismissalMonitors()
    }

    func dismiss(deactivate: Bool) {
        model.cancelPanelLoading()
        removeDismissalMonitors()
        model.resetPresentation()
        UtilityWindowPresentation.dismiss(window, deactivate: deactivate)
    }

    private func installContent() {
        guard let window else { return }
        let view = GlobalSearchView(
            model: model,
            onActivate: { [weak self] id in self?.activate(id) },
            onRevealInSource: { [weak self] id in self?.revealInSource(id) },
            onPerformItemAction: { [weak self] action, id in
                self?.performItemAction(action, id: id)
            },
            onItemActions: { [weak self] id in
                self?.onAvailableItemActions?(id) ?? []
            }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(origin: .zero, size: GlanceConstants.globalSearchSize)
        window.contentViewController = hosting
    }

    private func currentSnapshot() -> GlobalSearchImmediateSnapshot {
        let names = Dictionary(
            uniqueKeysWithValues: panelManager.workspaces().map { ($0.id, $0.name) }
        )
        let panelsBlocked: Bool
        switch environment.repository.lastLoadOutcome {
        case .unsupportedFutureSchema, .corruptUnquarantined:
            panelsBlocked = true
        case .missing, .loaded, .recoveredFromBackup, .quarantinedCorruptAndEmpty:
            panelsBlocked = false
        }
        return GlobalSearchImmediateSnapshot(
            clipboard: environment.clipboardHistoryService.records,
            clipboardUnavailable: GlobalSearchSnapshotBuilder.clipboardUnavailable(
                environment.clipboardHistoryService.loadOutcome
            ),
            files: environment.fileShelfService.records,
            filesUnavailable: GlobalSearchSnapshotBuilder.fileShelfUnavailable(
                environment.fileShelfService.loadOutcome
            ),
            snippets: environment.snippetService.records,
            snippetsUnavailable: GlobalSearchSnapshotBuilder.snippetsUnavailable(
                environment.snippetService.loadOutcome
            ),
            links: environment.linkService.records,
            linksUnavailable: GlobalSearchSnapshotBuilder.linksUnavailable(
                environment.linkService.loadOutcome
            ),
            panelInputs: panelsBlocked ? [] : panelManager.summaryInputs(),
            panelsUnavailable: panelsBlocked,
            workspaceNames: names
        )
    }

    private func activate(_ id: GlobalSearchResultID) {
        let result = GlobalSearchActionRouter.perform(
            id: id,
            globallyConcealed: environment.visibility.isConcealed,
            using: dependencies()
        )
        switch result {
        case .succeeded(let deactivate):
            dismiss(deactivate: deactivate)
        case .failed(let notice):
            NSSound.beep()
            if notice == GlobalSearchCopy.fileMissing {
                model.markUnavailable(id)
            }
            model.showNotice(notice)
        }
    }

    private func dependencies() -> GlobalSearchActionDependencies {
        GlobalSearchActionDependencies(
            restoreClipboard: { [weak self] itemID in
                self?.restoreClipboard(itemID) ?? false
            },
            openFile: { [weak self] itemID in
                self?.openFile(itemID) ?? false
            },
            copySnippet: { [weak self] itemID in
                self?.copySnippet(itemID) ?? false
            },
            openLink: { [weak self] itemID in
                self?.openLink(itemID) ?? false
            },
            lookupPanel: { [weak self] itemID in
                guard let record = try? self?.environment.repository.record(id: itemID) else {
                    return nil
                }
                return GlobalSearchPanelLookup(workspaceID: record.workspaceID)
            },
            activeWorkspaceID: { [weak self] in
                self?.panelManager.activeWorkspaceID ?? WorkspaceRecord.defaultID
            },
            switchWorkspace: { [weak self] workspaceID in
                self?.panelManager.switchWorkspace(id: workspaceID) ?? false
            },
            revealPanel: { [weak self] itemID in
                self?.panelManager.revealPanel(id: itemID)
                return (try? self?.environment.repository.record(id: itemID)) != nil
            }
        )
    }

    private func revealInSource(_ id: GlobalSearchResultID) {
        switch onRevealInSource?(id) ?? .failed(GlanceNoticeCopy.staleItem) {
        case .succeeded:
            dismiss(deactivate: false)
        case .failed(let notice):
            NSSound.beep()
            model.showNotice(notice)
        }
    }

    private func performItemAction(_ action: GlanceItemAction, id: GlobalSearchResultID) {
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        let outcome = onPerformItemAction?(action, id, screen)
            ?? .failed(GlanceNoticeCopy.panelCreateFailed)
        if GlobalSearchItemActionSessionPolicy.shouldDismiss(after: action, outcome: outcome) {
            dismiss(deactivate: false)
            return
        }
        if case .failed(let notice) = outcome {
            NSSound.beep()
            model.showNotice(notice)
        }
    }

    private func restoreClipboard(_ id: UUID) -> Bool {
        guard let content = environment.clipboardHistoryService.reuse(id) else { return false }
        return clipboardWriter.write(content)
    }

    private func openFile(_ id: UUID) -> Bool {
        let resolved = environment.fileShelfService.resolve(id, allowCache: false)
        guard !resolved.isMissing, let path = resolved.urlPath else { return false }
        guard MacFileShelfActions.open(path: path) else { return false }
        environment.fileShelfService.markUsed(id: id)
        return true
    }

    private func copySnippet(_ id: UUID) -> Bool {
        guard let record = environment.snippetService.records.first(where: { $0.id == id }) else {
            return false
        }
        guard clipboardWriter.write(.text(record.content)) else { return false }
        _ = environment.snippetService.markUsed(id: id)
        return true
    }

    private func openLink(_ id: UUID) -> Bool {
        guard let record = environment.linkService.records.first(where: { $0.id == id }) else {
            return false
        }
        return LinkOpenCoordinator.perform(
            record: record,
            opener: opener
        ) { [weak self] openedID in
            self?.environment.linkService.markOpened(id: openedID) ?? false
        }
    }

    private func installDismissalMonitors() {
        removeDismissalMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(deactivate: false)
            }
        }
    }

    private func removeDismissalMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard isSearchVisible else { return event }
        if isComposingIME() { return event }
        guard let action = GlobalSearchActionPolicy.action(
            keyCode: event.keyCode,
            command: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
        ) else {
            return event
        }
        switch action {
        case .moveSelection(let delta):
            model.moveSelection(delta)
        case .activate:
            if let id = model.selection { activate(id) }
        case .revealInSource:
            if let id = model.selection { revealInSource(id) }
        case .dismiss:
            dismiss(deactivate: true)
        }
        return nil
    }

    private func isComposingIME() -> Bool {
        if let view = window?.firstResponder as? NSTextView {
            return view.hasMarkedText()
        }
        if let editor = window?.firstResponder as? NSText,
           let view = editor as? NSTextView {
            return view.hasMarkedText()
        }
        return false
    }
}

final class GlobalSearchPanel: NSPanel {
    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = GlobalSearchCopy.windowTitle
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        level = .floating
        isMovable = true
        isMovableByWindowBackground = true
        titleVisibility = .visible
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        (windowController as? GlobalSearchWindowController)?.dismiss(deactivate: true)
    }
}
