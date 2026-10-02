import AppKit

@MainActor
final class PanelManager {
    private let environment: AppEnvironment
    private var controllers: [UUID: PanelWindowController] = [:]
    private let placement = PanelPlacementEngine()
    private var screenObserver: NSObjectProtocol?

    init(environment: AppEnvironment) {
        self.environment = environment
        environment.panelManager = self
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
                if recovered.migrated {
                    record.frame = recovered.frame
                    record.displayIdentifier = recovered.displayIdentifier
                    environment.repository.touch(record)
                }
                present(record: record)
            }
            try environment.repository.save()
        } catch {
            NSLog("Glance: restore failed: \(error.localizedDescription)")
        }
    }

    func createTextPanel() {
        createPanel(kindIdentifier: PanelKind.text)
    }

    func createImagePanel() {
        createPanel(kindIdentifier: PanelKind.image)
    }

    func deletePanel(id: UUID) {
        environment.debouncer.cancel(id: "frame-\(id.uuidString)")
        environment.debouncer.cancel(id: "payload-\(id.uuidString)")
        if let controller = controllers.removeValue(forKey: id) {
            controller.persistAllNow()
            controller.window?.close()
        }
        try? environment.repository.delete(id: id)
        environment.payloadStore.delete(id: id)
    }

    func persistAllNow() {
        for controller in controllers.values {
            controller.persistAllNow()
        }
        try? environment.repository.save()
    }

    func toggleGlobalVisibility() {
        environment.visibility.toggle(windows: windows)
    }

    var allHidden: Bool {
        environment.visibility.isConcealed
    }

    private func createPanel(kindIdentifier: String) {
        let id = UUID()
        let size = PanelProviderRegistry.defaultSize(for: kindIdentifier)
        let screen = DisplayManager.screenContainingMouse()
        let frame = placement.frameForNewPanel(
            size: size,
            existingFrames: windows.map(\.frame),
            on: screen
        )
        let payloadPath = environment.payloadStore.relativePath(for: id)
        _ = try? environment.payloadStore.directory(for: id)

        let record = PanelRecord(
            id: id,
            kindIdentifier: kindIdentifier,
            frame: frame,
            displayIdentifier: DisplayManager.identifier(for: screen),
            payloadPath: payloadPath,
            payloadVersion: PanelProviderRegistry.payloadVersion(for: kindIdentifier)
        )

        do {
            try environment.repository.insert(record)
            present(record: record)
        } catch {
            NSLog("Glance: create panel failed: \(error.localizedDescription)")
        }
    }

    private func present(record: PanelRecord) {
        let controller = PanelWindowController(record: record, environment: environment)
        controllers[record.id] = controller
        if environment.visibility.isConcealed {
            controller.conceal()
        } else {
            controller.showFront()
        }
    }

    private func reclampVisiblePanels() {
        for controller in controllers.values {
            guard let window = controller.window else { continue }
            let recovered = PanelFrameRecovery.recover(
                frame: window.frame,
                displayIdentifier: DisplayManager.identifier(for: window.screen ?? DisplayManager.screenContainingMouse())
            )
            if window.frame != recovered.frame {
                window.setFrame(recovered.frame, display: true)
            }
        }
    }

    func shutdown() {
        persistAllNow()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }
}
