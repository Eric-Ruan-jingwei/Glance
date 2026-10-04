import AppKit
import SwiftUI

@MainActor
final class SnippetLibraryWindowController: NSWindowController {
    var onPerformItemAction: ((GlanceItemAction, UUID, NSScreen?) -> GlanceActionOutcome)?
    var onAvailableActionsForSource: ((GlanceActionSourceID) -> [GlanceItemAction])?
    var onPerformActionForSource: ((GlanceItemAction, GlanceActionSourceID, NSScreen?) -> GlanceActionOutcome)?

    private let model: SnippetLibraryViewModel
    private let clipboardWriter: GlanceClipboardWriter
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var suppressResignDismiss = false

    var isLibraryVisible: Bool {
        window?.isVisible == true
    }

    init(service: SnippetService, monitor: ClipboardHistoryMonitor) {
        self.model = SnippetLibraryViewModel(service: service)
        self.clipboardWriter = GlanceClipboardWriter(monitor: monitor)
        let panel = SnippetLibraryPanel(
            contentRect: NSRect(origin: .zero, size: GlanceConstants.snippetLibrarySize)
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
            dismiss()
        case .bringForward:
            UtilityWindowPresentation.bringForward(window)
        case .present:
            present()
        }
    }

    func present() {
        model.resetPresentation()
        UtilityWindowPresentation.present(window, size: GlanceConstants.snippetLibrarySize)
        installDismissalMonitors()
    }

    @discardableResult
    func present(selecting id: UUID) -> Bool {
        present()
        return model.selectForReveal(id)
    }

    func presentEditor(prefilled content: String) {
        if !isLibraryVisible {
            present()
        }
        model.beginCreate(prefilled: content)
    }

    func handleCancel() {
        if model.editor != nil {
            model.cancelEditor()
        } else {
            dismiss()
        }
    }

    func dismiss(deactivate: Bool = true) {
        model.cancelEditor()
        removeDismissalMonitors()
        model.resetPresentation()
        UtilityWindowPresentation.dismiss(window, deactivate: deactivate)
    }

    private func installContent() {
        guard let window else { return }
        let view = SnippetLibraryView(
            model: model,
            onCopy: { [weak self] id in self?.copy(id) },
            onEdit: { [weak self] id in self?.edit(id) },
            onCreate: { [weak self] in self?.create() },
            onTogglePin: { [weak self] id in
                _ = self?.model.service.togglePin(id: id)
            },
            onDelete: { [weak self] id in self?.delete(id) },
            onPerformItemAction: { [weak self] action, id in
                self?.performItemAction(action, id: id)
            },
            onAvailableSourceActions: { [weak self] sourceID in
                self?.onAvailableActionsForSource?(sourceID) ?? []
            },
            onPerformSourceAction: { [weak self] action, sourceID, screen in
                self?.onPerformActionForSource?(action, sourceID, screen)
                    ?? .failed(GlanceNoticeCopy.panelCreateFailed)
            }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(origin: .zero, size: GlanceConstants.snippetLibrarySize)
        window.contentViewController = hosting
    }

    private func copy(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        guard clipboardWriter.write(.text(record.content)) else {
            NSSound.beep()
            model.showNotice(GlanceNoticeCopy.clipboardWriteFailed)
            return
        }
        _ = model.service.markUsed(id: id)
        dismiss(deactivate: true)
    }

    private func performItemAction(_ action: GlanceItemAction, id: UUID) {
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        switch onPerformItemAction?(action, id, screen) ?? .failed(GlanceNoticeCopy.panelCreateFailed) {
        case .succeeded:
            if action.createsPanel {
                dismiss(deactivate: false)
            }
        case .failed(let message):
            NSSound.beep()
            model.showNotice(message)
        }
    }

    private func edit(_ id: UUID) {
        model.beginEdit(id: id)
    }

    private func create() {
        model.beginCreate()
    }

    private func delete(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = SnippetCopy.deleteTitle(record.title)
        alert.informativeText = SnippetCopy.deleteBody
        alert.addButton(withTitle: SnippetCopy.deleteButton)
        alert.addButton(withTitle: SnippetCopy.cancelLabel)
        alert.alertStyle = .warning
        suppressResignDismiss = true
        let response = alert.runModal()
        suppressResignDismiss = false
        guard response == .alertFirstButtonReturn else { return }
        _ = model.service.delete(id: id)
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
                guard let self, !self.suppressResignDismiss, self.model.editor == nil else { return }
                self.dismiss()
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
        guard isLibraryVisible else { return event }
        if model.editor != nil { return event }
        if isComposingIME() { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let action = SnippetActionPolicy.action(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers,
            command: flags.contains(.command)
        ) else {
            return event
        }
        switch action {
        case .moveSelection(let delta):
            model.moveSelection(delta)
        case .copy:
            if let id = model.selection { copy(id) }
        case .edit:
            if let id = model.selection { edit(id) }
        case .create:
            create()
        case .delete:
            if let id = model.selection { delete(id) }
        case .dismiss:
            dismiss()
        }
        return nil
    }

    private func isComposingIME() -> Bool {
        if let view = window?.firstResponder as? NSTextView {
            return view.hasMarkedText()
        }
        return false
    }
}

final class SnippetLibraryPanel: NSPanel {
    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = SnippetCopy.windowTitle
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
        (windowController as? SnippetLibraryWindowController)?.handleCancel()
    }
}
