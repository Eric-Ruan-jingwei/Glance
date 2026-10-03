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

    func createPDFPanel() {
        let screen = DisplayManager.screenContainingMouse()
        NSApp.activate(ignoringOtherApps: true)
        guard let url = MacPDFImporter.chooseFile() else { return }
        do {
            try importPDF(from: url, preferredScreen: screen)
        } catch {
            presentPDFImportAlert(error)
        }
    }

    func importPDF(from sourceURL: URL, preferredScreen: NSScreen? = nil) throws {
        let metadata = try MacPDFImporter.inspect(sourceURL)
        try materializePanel(
            kindIdentifier: PanelKind.pdf,
            preferredScreen: preferredScreen
        ) { directory in
            try PDFPayloadFile.importDocument(from: sourceURL, metadata: metadata, to: directory)
        }
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
        environment.visibility.toggle()
        applyEffectiveVisibilityToAll()
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
        do {
            try materializePanel(
                kindIdentifier: kindIdentifier,
                preferredScreen: preferredScreen
            ) { directory in
                try PanelInitialPayloadWriter.write(initialContent, to: directory)
            }
            return true
        } catch {
            NSLog("Glance: create panel failed: \(error.localizedDescription)")
            return false
        }
    }

    private func materializePanel(
        kindIdentifier: String,
        preferredScreen: NSScreen?,
        writePayload: @escaping (URL) throws -> Void
    ) throws {
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

        try PanelCreationSession.materialize(
            id: id,
            store: environment.payloadStore,
            writePayload: writePayload,
            insert: {
                try environment.repository.insert(record)
            }
        )
        present(record: record)
        notifyPanelsDidChange()
    }

    @discardableResult
    func hidePanel(id: UUID) -> Bool {
        setPanelHidden(true, id: id)
    }

    @discardableResult
    func showPanel(id: UUID) -> Bool {
        setPanelHidden(false, id: id)
    }

    @discardableResult
    func togglePanelVisibility(id: UUID) -> Bool {
        let hidden = (try? environment.repository.record(id: id))?.isHidden ?? false
        return setPanelHidden(!hidden, id: id)
    }

    private func presentPDFImportAlert(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if let importError = error as? PDFImportError {
            alert.messageText = importError.errorDescription ?? "无法导入 PDF。"
        } else {
            alert.messageText = "无法导入 PDF。"
        }
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func present(record: PanelRecord) {
        let controller = PanelWindowController(record: record, environment: environment)
        controllers[record.id] = controller
        applyEffectiveVisibility(id: record.id)
    }

    private func setPanelHidden(_ hidden: Bool, id: UUID) -> Bool {
        do {
            guard let record = try environment.repository.record(id: id) else { return false }
            let controller = controllers[id]
            try PanelVisibilityMutation.commit(
                hidden: hidden,
                record: record,
                globallyConcealed: environment.visibility.isConcealed,
                touch: { environment.repository.touch($0) },
                persist: { try environment.repository.save() },
                present: { controller?.showFront() },
                conceal: { controller?.conceal() }
            )
            notifyPanelsDidChange()
            return true
        } catch {
            NSLog("Glance persistence: failed to update panel visibility: %@", error.localizedDescription)
            return false
        }
    }

    private func applyEffectiveVisibility(id: UUID) {
        guard let controller = controllers[id] else { return }
        let hidden = (try? environment.repository.record(id: id))?.isHidden ?? false
        if PanelVisibilityPolicy.shouldPresent(
            panelHidden: hidden,
            globallyConcealed: environment.visibility.isConcealed
        ) {
            controller.showFront()
        } else {
            controller.conceal()
        }
    }

    private func applyEffectiveVisibilityToAll() {
        for id in controllers.keys {
            applyEffectiveVisibility(id: id)
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
        guard showPanel(id: id) else { return }
        let hidden = (try? environment.repository.record(id: id))?.isHidden ?? true
        guard PanelVisibilityPolicy.shouldPresent(
            panelHidden: hidden,
            globallyConcealed: environment.visibility.isConcealed
        ) else { return }
        controllers[id]?.window?.makeKey()
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
