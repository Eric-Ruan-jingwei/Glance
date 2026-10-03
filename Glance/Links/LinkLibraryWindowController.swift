import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MacLinkOpener: LinkOpening {
    func open(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return NSWorkspace.shared.open(url)
    }
}

enum MacLinkDropCollector {
    static let urlNameType = "public.url-name"

    static func collect(
        _ providers: [NSItemProvider],
        completion: @escaping ([LinkDropItem]) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var items: [LinkDropItem] = Array(repeating: LinkDropItem(), count: providers.count)
        for (index, provider) in providers.enumerated() {
            group.enter()
            collect(provider) { item in
                lock.lock()
                items[index] = item
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(items)
        }
    }

    private static func collect(
        _ provider: NSItemProvider,
        completion: @escaping (LinkDropItem) -> Void
    ) {
        let group = DispatchGroup()
        var urlStrings: [String] = []
        var urlName: String?
        var plainTexts: [String] = []
        let lock = NSLock()

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let value = string(from: item) {
                    lock.lock()
                    urlStrings.append(value)
                    lock.unlock()
                }
                group.leave()
            }
        }
        if provider.hasItemConformingToTypeIdentifier(urlNameType) {
            group.enter()
            provider.loadItem(forTypeIdentifier: urlNameType, options: nil) { item, _ in
                if let value = string(from: item) {
                    lock.lock()
                    urlName = value
                    lock.unlock()
                }
                group.leave()
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, _ in
                if let value = string(from: item) {
                    lock.lock()
                    plainTexts.append(value)
                    lock.unlock()
                }
                group.leave()
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let value = string(from: item) {
                    lock.lock()
                    plainTexts.append(value)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(LinkDropItem(urlStrings: urlStrings, urlName: urlName, plainTexts: plainTexts))
        }
    }

    private static func string(from item: NSSecureCoding?) -> String? {
        if let url = item as? URL {
            return url.absoluteString
        }
        if let text = item as? String {
            return text
        }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                return url.absoluteString
            }
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}

@MainActor
final class LinkLibraryWindowController: NSWindowController {
    var onCreatePanel: ((LinkRecord, NSScreen?) -> GlanceActionOutcome)?

    private let model: LinkLibraryViewModel
    private let clipboardWriter: GlanceClipboardWriter
    private let opener: LinkOpening
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var suppressResignDismiss = false

    var isLibraryVisible: Bool {
        window?.isVisible == true
    }

    init(
        service: LinkService,
        monitor: ClipboardHistoryMonitor,
        opener: LinkOpening = MacLinkOpener()
    ) {
        self.model = LinkLibraryViewModel(service: service)
        self.clipboardWriter = GlanceClipboardWriter(monitor: monitor)
        self.opener = opener
        let panel = LinkLibraryPanel(
            contentRect: NSRect(origin: .zero, size: GlanceConstants.linkLibrarySize)
        )
        super.init(window: panel)
        panel.windowController = self
        installContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        if isLibraryVisible {
            dismiss()
        } else {
            present()
        }
    }

    func present() {
        model.resetPresentation()
        UtilityWindowPresentation.present(window, size: GlanceConstants.linkLibrarySize)
        installDismissalMonitors()
    }

    @discardableResult
    func present(selecting id: UUID) -> Bool {
        present()
        return model.selectForReveal(id)
    }

    func presentEditor(prefilledURL urlString: String) {
        if !isLibraryVisible {
            present()
        }
        model.beginCreate(prefilledURL: urlString)
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
        let view = LinkLibraryView(
            model: model,
            onOpen: { [weak self] id in self?.open(id) },
            onCopy: { [weak self] id in self?.copy(id) },
            onEdit: { [weak self] id in self?.edit(id) },
            onCreate: { [weak self] in self?.create() },
            onTogglePin: { [weak self] id in
                _ = self?.model.service.togglePin(id: id)
            },
            onDelete: { [weak self] id in self?.delete(id) },
            onCreatePanel: { [weak self] id in self?.createPanel(id) },
            onDropItems: { [weak self] items in self?.handleDrop(items) }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(origin: .zero, size: GlanceConstants.linkLibrarySize)
        window.contentViewController = hosting
    }

    private func open(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        let opened = LinkOpenCoordinator.perform(
            record: record,
            opener: opener,
            markOpened: { [weak self] openedID in
                self?.model.service.markOpened(id: openedID) ?? false
            }
        )
        if opened {
            dismiss(deactivate: false)
        } else {
            NSSound.beep()
            model.showNotice(GlanceNoticeCopy.linkInvalid)
        }
    }

    private func copy(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        guard clipboardWriter.write(.text(record.urlString)) else {
            NSSound.beep()
            model.showNotice(GlanceNoticeCopy.clipboardWriteFailed)
            return
        }
        dismiss(deactivate: true)
    }

    private func createPanel(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        switch onCreatePanel?(record, screen) ?? .failed(GlanceNoticeCopy.panelCreateFailed) {
        case .succeeded:
            dismiss(deactivate: false)
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

    private func handleDrop(_ items: [LinkDropItem]) {
        let parsed = LinkDropParser.parse(items)
        model.ingest(parsed.accepted, rejected: parsed.rejected)
    }

    private func delete(_ id: UUID) {
        guard let record = model.service.records.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = LinkCopy.deleteTitle(record.title)
        alert.informativeText = LinkCopy.deleteBody
        alert.addButton(withTitle: LinkCopy.deleteButton)
        alert.addButton(withTitle: LinkCopy.cancelLabel)
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
        guard let action = LinkActionPolicy.action(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers,
            command: flags.contains(.command)
        ) else {
            return event
        }
        switch action {
        case .moveSelection(let delta):
            model.moveSelection(delta)
        case .open:
            if let id = model.selection { open(id) }
        case .edit:
            if let id = model.selection { edit(id) }
        case .create:
            create()
        case .copy:
            if let id = model.selection { copy(id) }
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

final class LinkLibraryPanel: NSPanel {
    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = LinkCopy.windowTitle
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
        (windowController as? LinkLibraryWindowController)?.handleCancel()
    }
}
