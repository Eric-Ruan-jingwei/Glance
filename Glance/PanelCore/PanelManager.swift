import AppKit

@MainActor
final class PanelManager {
    var onToggleQuickCapture: (() -> Void)?

    private let environment: AppEnvironment
    private var controllers: [UUID: PanelWindowController] = [:]
    private let placement = PanelPlacementEngine()
    private var screenObserver: NSObjectProtocol?

    init(environment: AppEnvironment) {
        self.environment = environment
        environment.panelManager = self
        environment.interaction.onModifierChanged = { [weak self] in
            self?.refreshInteractionChrome()
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reclampVisiblePanels()
            }
        }
    }

    var windows: [NSWindow] {
        controllers.values.compactMap(\.window)
    }

    func restoreAll() {
        do {
            let records = try environment.repository.all()
            for record in records {
                let recovered = PanelFrameRecovery.recover(
                    frame: record.frame,
                    displayIdentifier: record.displayIdentifier
                )
                if recovered.migrated || recovered.frame != record.frame {
                    record.frame = recovered.frame
                    record.displayIdentifier = recovered.displayIdentifier
                    environment.repository.touch(record)
                }
                present(record: record)
            }
            try environment.repository.save()
        } catch {
            NSLog("Glance persistence: restore save failed: %@", error.localizedDescription)
        }
    }

    func createTextPanel() {
        _ = createPanel(kindIdentifier: PanelKind.text)
    }

    func createMarkdownPanel() {
        _ = createPanel(kindIdentifier: PanelKind.markdown)
    }

    func createTodoPanel() {
        _ = createPanel(kindIdentifier: PanelKind.todo)
    }

    func createImagePanel() {
        _ = createPanel(kindIdentifier: PanelKind.image)
    }

    @discardableResult
    func createPanel(
        from request: QuickCaptureRequest,
        preferredScreen: NSScreen? = nil
    ) -> Bool {
        guard let initialContent = request.initialContent() else { return false }
        return createPanel(
            kindIdentifier: request.kindIdentifier,
            initialContent: initialContent,
            preferredScreen: preferredScreen
        )
    }

    @discardableResult
    func deletePanel(id: UUID) -> Bool {
        controllers[id]?.persistAllNow()
        do {
            try PanelDeletionTransaction.perform(
                deleteMetadata: {
                    try environment.repository.delete(id: id)
                },
                removeController: {
                    environment.debouncer.cancel(id: "frame-\(id.uuidString)")
                    environment.debouncer.cancel(id: "payload-\(id.uuidString)")
                    environment.debouncer.cancel(id: "opacity-\(id.uuidString)")
                    if let controller = controllers.removeValue(forKey: id) {
                        controller.window?.close()
                    }
                },
                deletePayload: {
                    environment.payloadStore.delete(id: id)
                }
            )
            notifyPanelsDidChange()
            return true
        } catch {
            NSLog("Glance persistence: failed to delete panel metadata: %@", error.localizedDescription)
            return false
        }
    }

    func persistAllNow() {
        for controller in controllers.values {
            controller.persistAllNow()
        }
        do {
            try environment.repository.save()
        } catch {
            NSLog("Glance persistence: failed to save metadata: %@", error.localizedDescription)
        }
    }

    func toggleGlobalVisibility() {
        environment.visibility.toggle(windows: windows)
    }

    func toggleQuickCapture() {
        onToggleQuickCapture?()
    }

    func captureClipboard() {
        guard let content = MacClipboardReader.read() else {
            NSSound.beep()
            return
        }
        let created = createPanel(
            kindIdentifier: ClipboardCaptureRouter.kindIdentifier(for: content),
            initialContent: ClipboardCaptureRouter.initialContent(for: content),
            preferredScreen: DisplayManager.screenContainingMouse()
        )
        if !created {
            NSSound.beep()
        }
    }

    var allHidden: Bool {
        environment.visibility.isConcealed
    }

    @discardableResult
    func createPanel(
        kindIdentifier: String,
        initialContent: PanelInitialContent = .none,
        preferredScreen: NSScreen? = nil
    ) -> Bool {
        let id = UUID()
        let size = PanelProviderRegistry.defaultSize(for: kindIdentifier)
        let screen = preferredScreen ?? DisplayManager.screenContainingMouse()
        let nsFrame = placement.frameForNewPanel(
            size: size,
            existingFrames: windows.map(\.frame),
            on: screen
        )
        let payloadPath = environment.payloadStore.relativePath(for: id)
        let record = PanelRecord(
            id: id,
            kindIdentifier: kindIdentifier,
            frame: PanelFrame(nsFrame),
            displayIdentifier: DisplayManager.identifier(for: screen),
            payloadPath: payloadPath,
            payloadVersion: PanelProviderRegistry.payloadVersion(for: kindIdentifier)
        )

        do {
            try PanelCreationSession.materialize(
                id: id,
                store: environment.payloadStore,
                writePayload: { directory in
                    try PanelInitialPayloadWriter.write(initialContent, to: directory)
                },
                insert: {
                    try environment.repository.insert(record)
                }
            )
            present(record: record)
            notifyPanelsDidChange()
            return true
        } catch {
            NSLog("Glance: create panel failed: \(error.localizedDescription)")
            return false
        }
    }

    private func present(record: PanelRecord) {
        let controller = PanelWindowController(record: record, environment: environment)
        controllers[record.id] = controller
        if PanelRevealPolicy.shouldPresentNewlyCreatedPanel(
            isGloballyConcealed: environment.visibility.isConcealed
        ) {
            controller.showFront()
        } else {
            controller.conceal()
        }
    }

    private func reclampVisiblePanels() {
        for controller in controllers.values {
            controller.recoverAndApplyFrame()
        }
    }

    func refreshInteractionChrome() {
        for controller in controllers.values {
            controller.refreshInteractionChrome()
        }
    }

    func shutdown() {
        persistAllNow()
        environment.shortcuts.unregister()
        environment.interaction.shutdown()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    func panelSummaries() -> [PanelSummary] {
        let records = (try? environment.repository.all()) ?? []
        return records.map { record in
            let directory = environment.payloadStore.panelsRoot
                .appendingPathComponent(record.id.uuidString, isDirectory: true)
            return PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        }
    }

    func revealPanel(id: UUID) {
        guard let controller = controllers[id] else { return }
        controller.showFront()
        controller.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func openPayloadFolder(id: UUID) {
        let directory = environment.payloadStore.panelsRoot
            .appendingPathComponent(id.uuidString, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    func notifyPanelsDidChange() {
        NotificationCenter.default.post(name: .glancePanelCollectionDidChange, object: nil)
    }
}
