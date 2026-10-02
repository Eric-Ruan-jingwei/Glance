import AppKit

@MainActor
final class PanelWindowController: NSWindowController, NSWindowDelegate {
    let recordID: UUID
    let kindIdentifier: String

    private let environment: AppEnvironment
    private let content: PanelContentControlling
    private let chrome = PanelChromeView()
    private var interactionState: PanelInteractionState = .reading
    private var clickOutsideMonitor: Any?
    private var isPinned: Bool
    private var isPassThrough: Bool
    private let payloadDirty = PayloadDirtyFlag()

    var panelWindow: PanelWindow {
        window as! PanelWindow
    }

    init(record: PanelRecord, environment: AppEnvironment) {
        self.recordID = record.id
        self.kindIdentifier = record.kindIdentifier
        self.environment = environment
        self.isPinned = record.isPinned
        self.isPassThrough = record.isPassThrough
        self.content = PanelProviderRegistry.makeContent(kindIdentifier: record.kindIdentifier)

        let window = PanelWindow(contentRect: record.frame)
        super.init(window: window)

        window.delegate = self
        window.minSize = content.minimumSize
        window.applyPinned(record.isPinned)
        chrome.minimumSize = content.minimumSize
        chrome.embed(content.view)
        chrome.onCommitFrame = { [weak self] in self?.recoverAndApplyFrame() }
        chrome.onContextMenu = { [weak self] _ in
            self?.makeContextMenu() ?? NSMenu()
        }
        window.contentView = chrome

        content.onPayloadChange = { [weak self] in
            self?.payloadDirty.markUserEdit()
            self?.schedulePayloadSave()
        }
        content.onRequestEditing = { [weak self] in self?.enterEditing() }
        content.onRequestPreferredSize = { [weak self] size in
            self?.resizeToPreferred(size)
        }

        loadPayload()
        if record.isPassThrough {
            applyPassThroughMode()
        } else {
            applyReadingMode()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showFront() {
        panelWindow.orderFrontRegardless()
        panelWindow.invalidateShadow()
    }

    func conceal() {
        panelWindow.orderOut(nil)
    }

    func persistAllNow() {
        environment.debouncer.flush(id: frameDebounceID)
        environment.debouncer.flush(id: payloadDebounceID)
        recoverAndApplyFrame()
        persistPayloadNow()
    }

    func applyPinned(_ pinned: Bool) {
        isPinned = pinned
        panelWindow.applyPinned(pinned)
        mutateRecord { record in
            record.isPinned = pinned
        }
    }

    private func applyReadingMode() {
        interactionState = .reading
        panelWindow.allowsKey = false
        chrome.isInteractable = true
        content.exitEditing()
        removeClickOutsideMonitor()
        environment.interaction.update(window: panelWindow, passThrough: false)
        if panelWindow.isKeyWindow {
            NSApp.deactivate()
        }
    }

    private func applyPassThroughMode() {
        if interactionState == .editing {
            content.exitEditing()
        }
        interactionState = .passThrough
        isPassThrough = true
        panelWindow.allowsKey = false
        chrome.isInteractable = true
        removeClickOutsideMonitor()
        environment.interaction.update(window: panelWindow, passThrough: true)
        if panelWindow.isKeyWindow {
            NSApp.deactivate()
        }
    }

    private func enterEditing() {
        guard PanelModeTransition.canBeginEditing(from: interactionState) else { return }
        interactionState = .editing
        panelWindow.allowsKey = true
        environment.interaction.update(window: panelWindow, passThrough: false)
        content.enterEditing()
        NSApp.activate(ignoringOtherApps: true)
        panelWindow.makeKeyAndOrderFront(nil)
        installClickOutsideMonitor()
    }

    private func leaveEditing() {
        persistPayloadNow()
        switch PanelModeTransition.stateAfterLeavingEditing(persistedPassThrough: isPassThrough) {
        case .passThrough:
            applyPassThroughMode()
        case .reading, .editing:
            applyReadingMode()
        }
    }

    func recoverAndApplyFrame() {
        guard let window else { return }
        let recovered = PanelFrameRecovery.recover(
            frame: window.frame,
            displayIdentifier: DisplayManager.identifier(for: window.screen ?? DisplayManager.screenContainingMouse())
        )
        if window.frame != recovered.frame {
            window.setFrame(recovered.frame, display: true)
            window.invalidateShadow()
        }
        mutateRecord { record in
            record.frame = recovered.frame
            record.displayIdentifier = recovered.displayIdentifier
        }
    }

    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.window, self.interactionState == .editing {
                self.leaveEditing()
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
            self.clickOutsideMonitor = nil
        }
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        if kindIdentifier == PanelKind.text {
            let edit = NSMenuItem(title: "编辑", action: #selector(editClicked), keyEquivalent: "")
            edit.target = self
            menu.addItem(edit)
            menu.addItem(.separator())
        }

        let pin = NSMenuItem(title: "置顶", action: #selector(pinClicked), keyEquivalent: "")
        pin.target = self
        pin.state = isPinned ? .on : .off
        menu.addItem(pin)

        let passThrough = NSMenuItem(title: "点击穿透", action: #selector(passThroughClicked), keyEquivalent: "")
        passThrough.target = self
        passThrough.state = isPassThrough ? .on : .off
        menu.addItem(passThrough)

        for item in content.additionalContextMenuItems() {
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "面板设置…", action: #selector(panelSettingsClicked), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let delete = NSMenuItem(title: "删除面板", action: #selector(deleteClicked), keyEquivalent: "")
        delete.target = self
        menu.addItem(delete)
        return menu
    }

    @objc private func editClicked() {
        enterEditing()
    }

    @objc private func pinClicked() {
        applyPinned(!isPinned)
    }

    @objc private func passThroughClicked() {
        if isPassThrough {
            isPassThrough = false
            if interactionState == .editing {
                persistPayloadNow()
                content.exitEditing()
            }
            applyReadingMode()
            mutateRecord { record in
                record.isPassThrough = false
            }
        } else {
            persistPayloadNow()
            applyPassThroughMode()
            mutateRecord { record in
                record.isPassThrough = true
            }
        }
    }

    @objc private func panelSettingsClicked() {
        guard let record = try? environment.repository.record(id: recordID) else { return }
        let alert = NSAlert()
        alert.messageText = "面板设置"
        alert.informativeText = """
        类型：\(kindIdentifier)
        显示器：\(record.displayIdentifier)
        创建时间：\(record.createdAt.formatted(date: .abbreviated, time: .shortened))
        内容目录：\(record.payloadPath)

        颜色、透明度等高级选项将在 V0.2 提供。
        """
        alert.addButton(withTitle: "打开内容文件夹")
        alert.addButton(withTitle: "关闭")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let dir = try? environment.payloadStore.directory(for: recordID) {
                NSWorkspace.shared.open(dir)
            }
        }
    }

    @objc private func deleteClicked() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除此面板？"
        alert.informativeText = "内容会从本地删除，无法撤销。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            environment.panelManager?.deletePanel(id: recordID)
        }
    }

    func windowDidMove(_ notification: Notification) {
        scheduleFrameSave()
    }

    func windowDidResize(_ notification: Notification) {
        scheduleFrameSave()
        panelWindow.invalidateShadow()
    }

    func windowDidResignKey(_ notification: Notification) {
        if interactionState == .editing {
            leaveEditing()
        }
    }

    func windowWillClose(_ notification: Notification) {
        persistAllNow()
        removeClickOutsideMonitor()
        if let window {
            environment.interaction.remove(window: window)
        }
    }

    private var frameDebounceID: String { "frame-\(recordID.uuidString)" }
    private var payloadDebounceID: String { "payload-\(recordID.uuidString)" }

    private func scheduleFrameSave() {
        environment.debouncer.schedule(id: frameDebounceID, delay: GlanceConstants.frameSaveDelay) { [weak self] in
            self?.recoverAndApplyFrame()
        }
    }

    private func schedulePayloadSave() {
        environment.debouncer.schedule(id: payloadDebounceID, delay: GlanceConstants.textSaveDelay) { [weak self] in
            self?.persistPayloadNow()
        }
    }

    private func persistPayloadNow() {
        do {
            let wrote = try PayloadPersistence.persistIfDirty(payloadDirty) {
                let dir = try environment.payloadStore.directory(for: recordID)
                try content.savePayload(to: dir)
            }
            if wrote {
                mutateRecord { record in
                    record.payloadPath = environment.payloadStore.relativePath(for: recordID)
                }
            }
        } catch {
            NSLog("Glance persistence: failed to save payload: %@", error.localizedDescription)
        }
    }

    private func loadPayload() {
        do {
            let dir = try environment.payloadStore.directory(for: recordID)
            try content.loadPayload(from: dir)
        } catch {
            NSLog(
                "Glance persistence: payload unreadable for %@: %@. Original files were left untouched.",
                recordID.uuidString,
                error.localizedDescription
            )
        }
    }

    private func resizeToPreferred(_ size: NSSize) {
        guard let window else { return }
        var frame = window.frame
        frame.size = NSSize(
            width: max(size.width, content.minimumSize.width),
            height: max(size.height, content.minimumSize.height)
        )
        let screen = window.screen ?? DisplayManager.screenContainingMouse()
        frame = PanelFrameRecovery.clamp(frame, to: screen.visibleFrame)
        window.setFrame(frame, display: true)
        recoverAndApplyFrame()
    }

    private func mutateRecord(_ body: (PanelRecord) -> Void) {
        do {
            guard let record = try environment.repository.record(id: recordID) else { return }
            body(record)
            environment.repository.touch(record)
            try environment.repository.save()
        } catch {
            NSLog("Glance persistence: failed to update record: %@", error.localizedDescription)
        }
    }

}
