import AppKit
import SwiftUI

@MainActor
final class ClipboardHistoryWindowController: NSWindowController {
    var onPerformItemAction: ((GlanceItemAction, UUID, NSScreen?) -> GlanceActionOutcome)?

    private let model: ClipboardHistoryViewModel
    private let monitor: ClipboardHistoryMonitor
    private let clipboardWriter: GlanceClipboardWriter
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    var isShelfVisible: Bool {
        window?.isVisible == true
    }

    init(service: ClipboardHistoryService, monitor: ClipboardHistoryMonitor) {
        self.model = ClipboardHistoryViewModel(service: service)
        self.monitor = monitor
        self.clipboardWriter = GlanceClipboardWriter(monitor: monitor)
        let panel = ClipboardHistoryPanel(
            contentRect: NSRect(origin: .zero, size: GlanceConstants.clipboardHistorySize)
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
        UtilityWindowPresentation.present(window, size: GlanceConstants.clipboardHistorySize)
        installDismissalMonitors()
    }

    @discardableResult
    func present(selecting id: UUID) -> Bool {
        present()
        return model.selectForReveal(id)
    }

    func dismiss(deactivate: Bool = true) {
        removeDismissalMonitors()
        model.resetPresentation()
        UtilityWindowPresentation.dismiss(window, deactivate: deactivate)
    }

    private func installContent() {
        guard let window else { return }
        let view = ClipboardHistoryView(
            model: model,
            onEnableRecording: { [weak self] in self?.enableRecording() },
            onReuse: { [weak self] id in self?.reuse(id) },
            onToggleFavorite: { [weak self] id in
                self?.model.service.toggleFavorite(id: id)
            },
            onDelete: { [weak self] id in
                self?.model.thumbnails.evict(id)
                self?.model.service.delete(id: id)
            },
            onPerformItemAction: { [weak self] action, id in
                self?.performItemAction(action, id: id)
            }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(origin: .zero, size: GlanceConstants.clipboardHistorySize)
        window.contentViewController = hosting
    }

    private func enableRecording() {
        model.service.preferences.isRecordingEnabled = true
        monitor.start(baselineChangeCount: NSPasteboard.general.changeCount)
    }

    private func reuse(_ id: UUID) {
        guard let content = model.service.reuse(id) else { return }
        guard clipboardWriter.write(content) else {
            NSSound.beep()
            return
        }
        dismiss(deactivate: true)
    }

    private func performItemAction(_ action: GlanceItemAction, id: UUID) {
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        switch onPerformItemAction?(action, id, screen) ?? .failed(GlanceNoticeCopy.panelCreateFailed) {
        case .succeeded:
            if action.createsPanel {
                dismiss(deactivate: false)
            }
        case .failed:
            NSSound.beep()
        }
    }

    private func createPanel(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        guard let action = GlanceItemActionPolicy.panelAction(for: .clipboard(record)) else {
            NSSound.beep()
            return
        }
        performItemAction(action, id: id)
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
                self?.dismiss()
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
        guard isShelfVisible else { return event }
        if isComposingIME() { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), event.charactersIgnoringModifiers == "1" {
            model.tab = .recent
            return nil
        }
        if flags.contains(.command), event.charactersIgnoringModifiers == "2" {
            model.tab = .favorites
            return nil
        }
        switch event.keyCode {
        case 125:
            model.moveSelection(1)
            return nil
        case 126:
            model.moveSelection(-1)
            return nil
        case 36, 76:
            guard let id = model.selection else { return event }
            if flags.contains(.command) {
                createPanel(id)
            } else {
                reuse(id)
            }
            return nil
        case 53:
            dismiss()
            return nil
        default:
            return event
        }
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

final class ClipboardHistoryPanel: NSPanel {
    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = ClipboardHistoryCopy.windowTitle
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
        (windowController as? ClipboardHistoryWindowController)?.dismiss()
    }
}
