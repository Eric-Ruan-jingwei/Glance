import AppKit
import SwiftUI

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
    private var isLocked: Bool
    private var isPassThrough: Bool
    private var opacity: Double
    private let payloadDirty = PayloadDirtyFlag()
    private var settingsModel: PanelSettingsModel?
    private var settingsWindowController: PanelSettingsWindowController?

    var panelWindow: PanelWindow {
        window as! PanelWindow
    }

    init(record: PanelRecord, environment: AppEnvironment) {
        self.recordID = record.id
        self.kindIdentifier = record.kindIdentifier
        self.environment = environment
        self.isPinned = record.isPinned
        self.isLocked = record.isLocked
        self.isPassThrough = record.isPassThrough
        self.opacity = PanelOpacity.clamp(record.opacity)
        self.content = PanelProviderRegistry.makeContent(kindIdentifier: record.kindIdentifier)

        let window = PanelWindow(contentRect: record.frame.nsRect)
        super.init(window: window)

        window.delegate = self
        window.minSize = content.minimumSize
        window.applyPinned(record.isPinned)
        window.alphaValue = CGFloat(opacity)
        chrome.minimumSize = content.minimumSize
        chrome.embed(content.view)
        chrome.onCommitFrame = { [weak self] in self?.recoverAndApplyFrame() }
        chrome.onFinishMove = { [weak self] in self?.finishInteractiveMove() }
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
        applyPolicyToViews()
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
        absorbPendingUserChanges()
        environment.debouncer.flush(id: frameDebounceID)
        environment.debouncer.flush(id: payloadDebounceID)
        environment.debouncer.flush(id: opacityDebounceID)
        recoverAndApplyFrame()
        persistPayloadNow()
        persistOpacity()
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        panelWindow.applyPinned(pinned)
        mutateRecord { record in
            record.isPinned = pinned
        }
        syncSettingsModel()
        environment.panelManager?.notifyPanelsDidChange()
    }

    func setLocked(_ locked: Bool) {
        if locked, interactionState == .editing {
            leaveEditing()
        }
        isLocked = locked
        mutateRecord { record in
            record.isLocked = locked
        }
        applyPolicyToViews()
        syncSettingsModel()
        environment.panelManager?.notifyPanelsDidChange()
    }

    func setPassThrough(_ enabled: Bool) {
        if enabled {
            absorbPendingUserChanges()
            persistPayloadNow()
            applyPassThroughMode()
            mutateRecord { record in
                record.isPassThrough = true
            }
            PassThroughHint.showIfNeeded()
        } else {
            isPassThrough = false
            if interactionState == .editing {
                absorbPendingUserChanges()
                persistPayloadNow()
                content.exitEditing()
            }
            applyReadingMode()
            mutateRecord { record in
                record.isPassThrough = false
            }
        }
        applyPolicyToViews()
        syncSettingsModel()
        environment.panelManager?.notifyPanelsDidChange()
    }

    func setOpacity(_ value: Double) {
        let clamped = PanelOpacity.clamp(value)
        opacity = clamped
        panelWindow.alphaValue = CGFloat(clamped)
        settingsModel?.opacity = clamped
        environment.debouncer.schedule(id: opacityDebounceID, delay: GlanceConstants.frameSaveDelay) { [weak self] in
            self?.persistOpacity()
        }
    }

    func refreshInteractionChrome() {
        applyPolicyToViews()
    }

    private func applyReadingMode() {
        interactionState = .reading
        panelWindow.allowsKey = content.allowsKeyInReadingMode
        chrome.isInteractable = true
        content.exitEditing()
        removeClickOutsideMonitor()
        environment.interaction.update(window: panelWindow, passThrough: false)
        if panelWindow.isKeyWindow {
            NSApp.deactivate()
        }
        applyPolicyToViews()
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
        applyPolicyToViews()
    }

    private func enterEditing() {
        guard currentPolicy().allowsEdit else { return }
        interactionState = .editing
        panelWindow.allowsKey = true
        environment.interaction.update(window: panelWindow, passThrough: false)
        content.enterEditing()
        NSApp.activate(ignoringOtherApps: true)
        panelWindow.makeKeyAndOrderFront(nil)
        installClickOutsideMonitor()
        applyPolicyToViews()
    }

    private func leaveEditing() {
        absorbPendingUserChanges()
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
        applyRecoveredFrame(recovered)
    }

    func finishInteractiveMove() {
        guard let window else { return }
        environment.debouncer.cancel(id: frameDebounceID)
        let screen = window.screen ?? DisplayManager.screenContainingMouse()
        let visible = PanelFrame(screen.visibleFrame)
        let current = PanelFrame(window.frame)
        let snapped = PanelSnapEngine.snappedFrame(
            current,
            in: visible,
            enabled: !ModifierKeyController.controlIsPressed
        )
        let recovered = PanelFrameRecovery.recover(
            frame: snapped,
            displayIdentifier: DisplayManager.identifier(for: screen)
        )
        applyRecoveredFrame(recovered)
    }

    func applyLayoutPreset(_ preset: PanelLayoutPreset) {
        guard !isLocked, let window else { return }
        environment.debouncer.cancel(id: frameDebounceID)
        let screen = window.screen ?? DisplayManager.screenContainingMouse()
        let laidOut = PanelSnapEngine.frame(
            for: preset,
            panelFrame: PanelFrame(window.frame),
            visibleFrame: PanelFrame(screen.visibleFrame)
        )
        let recovered = PanelFrameRecovery.recover(
            frame: laidOut,
            displayIdentifier: DisplayManager.identifier(for: screen)
        )
        applyRecoveredFrame(recovered)
    }

    private func currentPolicy() -> PanelInteractionPolicy {
        PanelInteractionPolicy(
            isLocked: isLocked,
            isPassThrough: isPassThrough,
            isOptionPressed: ModifierKeyController.optionIsPressed,
            interactionState: interactionState
        )
    }

    private func applyPolicyToViews() {
        let policy = currentPolicy()
        chrome.allowsMove = policy.allowsMove
        chrome.allowsResize = policy.allowsResize
        chrome.showsLockBadge = isLocked
        chrome.showsTemporaryInteraction = isPassThrough
            && interactionState != .editing
            && ModifierKeyController.optionIsPressed
        chrome.isInteractable = true
        panelWindow.isMovable = policy.allowsMove
        content.allowsMove = policy.allowsMove
        content.allowsContentMutation = policy.allowsContentMutation
    }

    private func syncSettingsModel() {
        guard let settingsModel else { return }
        settingsModel.isPinned = isPinned
        settingsModel.isLocked = isLocked
        settingsModel.isPassThrough = isPassThrough
        settingsModel.opacity = opacity
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
        if let title = content.primaryEditMenuTitle() {
            let edit = NSMenuItem(title: title, action: #selector(editClicked), keyEquivalent: "")
            edit.target = self
            edit.isEnabled = currentPolicy().allowsEdit
            menu.addItem(edit)
            menu.addItem(.separator())
        }

        let pin = NSMenuItem(title: "置顶", action: #selector(pinClicked), keyEquivalent: "")
        pin.target = self
        pin.state = isPinned ? .on : .off
        menu.addItem(pin)

        let lock = NSMenuItem(title: "锁定", action: #selector(lockClicked), keyEquivalent: "")
        lock.target = self
        lock.state = isLocked ? .on : .off
        menu.addItem(lock)

        let passThrough = NSMenuItem(title: "点击穿透", action: #selector(passThroughClicked), keyEquivalent: "")
        passThrough.target = self
        passThrough.state = isPassThrough ? .on : .off
        menu.addItem(passThrough)

        if currentPolicy().allowsContentMutation {
            for item in content.additionalContextMenuItems() {
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(
            PanelLayoutMenu.makeItem(
                target: self,
                action: #selector(layoutPresetClicked(_:)),
                enabled: !isLocked
            )
        )

        menu.addItem(.separator())
        let rename = NSMenuItem(title: "重命名…", action: #selector(renameClicked), keyEquivalent: "")
        rename.target = self
        menu.addItem(rename)
        let editTags = NSMenuItem(title: "编辑标签…", action: #selector(editTagsClicked), keyEquivalent: "")
        editTags.target = self
        menu.addItem(editTags)
        menu.addItem(makeMoveToWorkspaceItem())

        let hide = NSMenuItem(
            title: PanelVisibilityMenu.hideThisPanel,
            action: #selector(hidePanelClicked),
            keyEquivalent: ""
        )
        hide.target = self
        menu.addItem(hide)

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
        setPinned(!isPinned)
    }

    @objc private func lockClicked() {
        setLocked(!isLocked)
    }

    @objc private func passThroughClicked() {
        setPassThrough(!isPassThrough)
    }

    @objc private func hidePanelClicked() {
        environment.panelManager?.hidePanel(id: recordID)
    }

    @objc private func renameClicked() {
        environment.panelManager?.promptRenamePanel(id: recordID)
    }

    @objc private func editTagsClicked() {
        environment.panelManager?.promptEditTags(id: recordID)
    }

    private func makeMoveToWorkspaceItem() -> NSMenuItem {
        let item = NSMenuItem(title: PanelVisibilityMenu.moveToWorkspace, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let workspaces = environment.panelManager?.workspaces() ?? [WorkspaceRecord.makeDefault()]
        let currentID = (try? environment.repository.record(id: recordID))?.workspaceID ?? WorkspaceRecord.defaultID
        for workspace in workspaces {
            let entry = NSMenuItem(
                title: workspace.name,
                action: #selector(moveToWorkspaceClicked(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.representedObject = workspace.id
            entry.state = workspace.id == currentID ? .on : .off
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    @objc private func moveToWorkspaceClicked(_ sender: NSMenuItem) {
        guard let workspaceID = sender.representedObject as? String else { return }
        _ = environment.panelManager?.movePanel(id: recordID, toWorkspaceID: workspaceID)
    }

    @objc private func layoutPresetClicked(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = PanelLayoutPreset(rawValue: raw) else { return }
        applyLayoutPreset(preset)
    }

    @objc private func panelSettingsClicked() {
        if let settingsWindowController {
            syncSettingsModel()
            settingsWindowController.bringForward()
            return
        }

        let model = PanelSettingsModel(
            isPinned: isPinned,
            isLocked: isLocked,
            isPassThrough: isPassThrough,
            opacity: opacity
        )
        settingsModel = model
        let view = PanelSettingsView(
            model: model,
            onPinned: { [weak self] value in self?.setPinned(value) },
            onLocked: { [weak self] value in self?.setLocked(value) },
            onPassThrough: { [weak self] value in self?.setPassThrough(value) },
            onOpacity: { [weak self] value in self?.setOpacity(value) },
            onOpenFolder: { [weak self] in self?.openPayloadFolder() },
            onDelete: { [weak self] in self?.deleteClicked() }
        )
        let controller = PanelSettingsWindowController(model: model, view: view)
        controller.onClose = { [weak self] in
            self?.settingsWindowController = nil
            self?.settingsModel = nil
        }
        settingsWindowController = controller
        controller.bringForward()
    }

    private func openPayloadFolder() {
        if let dir = try? environment.payloadStore.directory(for: recordID) {
            NSWorkspace.shared.open(dir)
        }
    }

    private func closeSettingsIfNeeded() {
        settingsWindowController?.close()
        settingsWindowController = nil
        settingsModel = nil
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
            closeSettingsIfNeeded()
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
        closeSettingsIfNeeded()
        if let window {
            environment.interaction.remove(window: window)
        }
    }

    private var frameDebounceID: String { "frame-\(recordID.uuidString)" }
    private var payloadDebounceID: String { "payload-\(recordID.uuidString)" }
    private var opacityDebounceID: String { "opacity-\(recordID.uuidString)" }

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

    private func persistOpacity() {
        mutateRecord { record in
            record.opacity = opacity
        }
    }

    private func absorbPendingUserChanges() {
        if content.flushPendingUserChanges() {
            payloadDirty.markUserEdit()
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
                environment.panelManager?.notifyPanelsDidChange()
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
        guard currentPolicy().allowsResize else { return }
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

    private func applyRecoveredFrame(_ recovered: RecoveredFrame) {
        guard let window else { return }
        if window.frame != recovered.frame.nsRect {
            window.setFrame(recovered.frame.nsRect, display: true)
            window.invalidateShadow()
        }
        mutateRecord { record in
            record.frame = recovered.frame
            record.displayIdentifier = recovered.displayIdentifier
        }
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
