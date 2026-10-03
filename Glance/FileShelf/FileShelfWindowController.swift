import AppKit
import SwiftUI

@MainActor
final class FileShelfWindowController: NSWindowController {
    var onCreatePanel: ((UUID, NSScreen?) -> GlanceActionOutcome)?

    private let model: FileShelfViewModel
    private let clipboardWriter: GlanceClipboardWriter
    private let quickLook = FileShelfQuickLookController()
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var suppressResignDismiss = false
    private var dragAccess: FileAccessToken?
    private var dragAccessWork: DispatchWorkItem?

    var isShelfVisible: Bool {
        window?.isVisible == true
    }

    init(service: FileShelfService, monitor: ClipboardHistoryMonitor) {
        self.model = FileShelfViewModel(service: service)
        self.clipboardWriter = GlanceClipboardWriter(monitor: monitor)
        let panel = FileShelfPanel(
            contentRect: NSRect(origin: .zero, size: GlanceConstants.fileShelfSize)
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
        UtilityWindowPresentation.present(window, size: GlanceConstants.fileShelfSize)
        installDismissalMonitors()
    }

    @discardableResult
    func present(selecting id: UUID) -> Bool {
        present()
        return model.selectForReveal(id)
    }

    func dismiss(deactivate: Bool = true) {
        quickLook.close()
        endDragAccess()
        removeDismissalMonitors()
        model.resetPresentation()
        UtilityWindowPresentation.dismiss(window, deactivate: deactivate)
    }

    private func installContent() {
        guard let window else { return }
        let view = FileShelfView(
            model: model,
            onAdd: { [weak self] in self?.addFiles() },
            onOpen: { [weak self] id in self?.open(id) },
            onReveal: { [weak self] id in self?.reveal(id) },
            onPreview: { [weak self] id in self?.preview(id) },
            onCopyFile: { [weak self] id in self?.copyFile(id) },
            onCopyPath: { [weak self] id in self?.copyPath(id) },
            onToggleFavorite: { [weak self] id in
                self?.model.service.toggleFavorite(id: id)
            },
            onRemove: { [weak self] id in self?.remove(id) },
            onRelink: { [weak self] id in self?.relink(id) },
            onCreatePanel: { [weak self] id in self?.createPanel(id) },
            onDropPaths: { [weak self] paths in
                self?.model.service.add(paths: paths)
            }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(origin: .zero, size: GlanceConstants.fileShelfSize)
        window.contentViewController = hosting
    }

    private func createPanel(_ id: UUID) {
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        switch onCreatePanel?(id, screen) ?? .failed(GlanceNoticeCopy.panelCreateFailed) {
        case .succeeded:
            dismiss(deactivate: false)
        case .failed(let message):
            NSSound.beep()
            model.service.notice = message
        }
    }

    private func addFiles() {
        suppressResignDismiss = true
        let urls = FileShelfOpenPanel.chooseFiles()
        suppressResignDismiss = false
        window?.makeKeyAndOrderFront(nil)
        if !urls.isEmpty {
            model.service.add(paths: urls.map(\.path))
        }
    }

    private func resolvedPath(_ id: UUID) -> String? {
        let resolved = model.service.resolve(id, allowCache: false)
        guard !resolved.isMissing else { return nil }
        return resolved.urlPath
    }

    private func open(_ id: UUID) {
        guard let path = resolvedPath(id) else { return }
        model.service.markUsed(id: id)
        _ = MacFileShelfActions.open(path: path)
        dismiss(deactivate: false)
    }

    private func reveal(_ id: UUID) {
        guard let path = resolvedPath(id) else { return }
        model.service.markUsed(id: id)
        MacFileShelfActions.reveal(path: path)
        dismiss(deactivate: false)
    }

    private func preview(_ id: UUID) {
        guard let path = resolvedPath(id) else { return }
        suppressResignDismiss = true
        model.service.markUsed(id: id)
        quickLook.show(path: path)
    }

    private func copyFile(_ id: UUID) {
        guard let path = resolvedPath(id) else { return }
        beginDragAccess(path: path)
        model.service.markUsed(id: id)
        MacFileShelfActions.copyFile(path: path)
        clipboardWriter.adoptCurrent()
    }

    private func copyPath(_ id: UUID) {
        let resolved = model.service.resolve(id)
        let path = resolved.urlPath ?? model.service.records.first { $0.id == id }?.originalPath
        guard let path else { return }
        _ = clipboardWriter.write(.text(path))
    }

    private func remove(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        if record.isFavorite, !confirmFavoriteRemoval() {
            return
        }
        model.icons.evict(id)
        model.service.remove(id: id)
    }

    private func confirmFavoriteRemoval() -> Bool {
        let alert = NSAlert()
        alert.messageText = FileShelfCopy.removeFavoriteTitle
        alert.informativeText = FileShelfCopy.removeFavoriteBody
        alert.addButton(withTitle: FileShelfCopy.removeLabel)
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        suppressResignDismiss = true
        let response = alert.runModal()
        suppressResignDismiss = false
        return response == .alertFirstButtonReturn
    }

    private func relink(_ id: UUID) {
        suppressResignDismiss = true
        let urls = FileShelfOpenPanel.chooseFiles()
        suppressResignDismiss = false
        window?.makeKeyAndOrderFront(nil)
        guard let url = urls.first else { return }
        if !model.service.relink(id: id, to: url.path) {
            NSSound.beep()
            model.service.notice = GlanceNoticeCopy.cannotSave
        }
    }

    private func beginDragAccess(path: String) {
        endDragAccess()
        dragAccess = FileAccessToken(path: path)
        let work = DispatchWorkItem { [weak self] in
            self?.endDragAccess()
        }
        dragAccessWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    private func endDragAccess() {
        dragAccessWork?.cancel()
        dragAccessWork = nil
        dragAccess?.end()
        dragAccess = nil
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
                guard let self, !self.suppressResignDismiss, !self.quickLook.isPreviewing else { return }
                if NSEvent.pressedMouseButtons != 0 { return }
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
        guard isShelfVisible else { return event }
        if isComposingIME() { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let action = FileShelfActionPolicy.action(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers,
            command: flags.contains(.command)
        ) else {
            return event
        }
        switch action {
        case .recentTab:
            model.tab = .recent
        case .favoritesTab:
            model.tab = .favorites
        case .copyFile:
            if let id = model.selection { copyFile(id) }
        case .moveSelection(let delta):
            model.moveSelection(delta)
        case .open:
            if let id = model.selection { open(id) }
        case .reveal:
            if let id = model.selection { reveal(id) }
        case .preview:
            if let id = model.selection { preview(id) }
        case .remove:
            if let id = model.selection { remove(id) }
        case .dismiss:
            if quickLook.isPreviewing {
                quickLook.close()
                suppressResignDismiss = false
            } else {
                dismiss()
            }
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

final class FileShelfPanel: NSPanel {
    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = FileShelfCopy.windowTitle
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
        registerForDraggedTypes([.fileURL])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        (windowController as? FileShelfWindowController)?.dismiss()
    }
}
