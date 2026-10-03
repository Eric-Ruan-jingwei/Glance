import Carbon
import Foundation

enum GlanceHotKeyID: UInt32 {
    case hideShow = 1
    case quickCapture = 2
    case clipboardCapture = 3
    case clipboardHistory = 4
    case fileShelf = 5
}

final class CarbonHotKeyRegistrar: HotKeyRegistering {
    private var refs: [UInt32: EventHotKeyRef] = [:]

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) throws {
        unregister(id: id)
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: glanceHotKeySignature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            NSLog("Glance shortcuts: RegisterEventHotKey failed for id %u (%d)", id, status)
            throw ShortcutError.registrationFailed
        }
        refs[id] = ref
    }

    func unregister(id: UInt32) {
        guard let ref = refs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
    }

    func unregisterAll() {
        for id in Array(refs.keys) {
            unregister(id: id)
        }
    }
}

/// Registers user-configured global shortcuts without Accessibility permission.
final class ShortcutManager: @unchecked Sendable {
    var onToggleVisibility: (() -> Void)?
    var onQuickCapture: (() -> Void)?
    var onCaptureClipboard: (() -> Void)?
    var onShowClipboardHistory: (() -> Void)?
    var onShowFileShelf: (() -> Void)?

    private let registrar: HotKeyRegistering
    private let bindSystemHandler: Bool
    private var registered: [ShortcutAction: GlanceShortcut] = [:]
    private var handlerRef: EventHandlerRef?
    private var ignoredAction: ShortcutAction?

    init(
        registrar: HotKeyRegistering = CarbonHotKeyRegistrar(),
        bindSystemHandler: Bool = true
    ) {
        self.registrar = registrar
        self.bindSystemHandler = bindSystemHandler
    }

    func registeredShortcut(for action: ShortcutAction) -> GlanceShortcut? {
        registered[action]
    }

    func menuShortcuts() -> [ShortcutAction: GlanceShortcut] {
        var result = ShortcutDefaults.all
        for (action, shortcut) in registered {
            result[action] = shortcut
        }
        return result
    }

    func installHandler() {
        guard bindSystemHandler else { return }
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            glanceHotKeyHandler,
            1,
            &spec,
            userData,
            &handlerRef
        )
        if handlerStatus != noErr {
            NSLog("Glance shortcuts: InstallEventHandler failed (%d)", handlerStatus)
        }
    }

    @discardableResult
    func register(_ shortcut: GlanceShortcut, for action: ShortcutAction) -> Bool {
        do {
            try registerThrowing(shortcut, for: action)
            return true
        } catch {
            NSLog(
                "Glance global shortcut %@ could not be registered: %@",
                ShortcutDisplayFormatter.display(shortcut) as NSString,
                error.localizedDescription as NSString
            )
            return false
        }
    }

    func replaceShortcut(for action: ShortcutAction, with shortcut: GlanceShortcut) throws {
        let old = registered[action]
        registrar.unregister(id: carbonID(for: action))
        do {
            try registerThrowing(shortcut, for: action)
        } catch {
            if let old {
                do {
                    try registerThrowing(old, for: action)
                } catch {
                    registered.removeValue(forKey: action)
                    NSLog(
                        "Glance shortcuts: failed to restore %@ after rejected replacement",
                        action.rawValue as NSString
                    )
                    throw ShortcutError.restoreFailed
                }
            }
            throw ShortcutError.registrationFailed
        }
    }

    func isSuspended(_ action: ShortcutAction) -> Bool {
        ignoredAction == action
    }

    func suspend(_ action: ShortcutAction) {
        ignoredAction = action
        registrar.unregister(id: carbonID(for: action))
    }

    func finishSuspension(_ action: ShortcutAction) {
        if ignoredAction == action {
            ignoredAction = nil
        }
    }

    func resume(_ action: ShortcutAction) throws {
        guard ignoredAction == action else { return }
        ignoredAction = nil
        guard let shortcut = registered[action] else { return }
        try registerThrowing(shortcut, for: action)
    }

    func handleHotKeyForTesting(_ action: ShortcutAction) {
        handleHotKey(id: carbonID(for: action))
    }

    func unregister() {
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        for action in ShortcutAction.allCases {
            registrar.unregister(id: carbonID(for: action))
        }
        registered.removeAll()
        ignoredAction = nil
    }

    fileprivate func handleHotKey(id: UInt32) {
        guard let action = action(forCarbonID: id) else { return }
        if ignoredAction == action { return }
        switch action {
        case .hideShow:
            onToggleVisibility?()
        case .quickCapture:
            onQuickCapture?()
        case .clipboardCapture:
            onCaptureClipboard?()
        case .clipboardHistory:
            onShowClipboardHistory?()
        case .fileShelf:
            onShowFileShelf?()
        }
    }

    private func registerThrowing(_ shortcut: GlanceShortcut, for action: ShortcutAction) throws {
        guard let keyCode = MacShortcutAdapter.carbonKeyCode(for: shortcut) else {
            throw ShortcutError.unsupportedKey
        }
        try registrar.register(
            id: carbonID(for: action),
            keyCode: keyCode,
            modifiers: MacShortcutAdapter.carbonModifiers(for: shortcut)
        )
        registered[action] = shortcut
    }

    private func carbonID(for action: ShortcutAction) -> UInt32 {
        switch action {
        case .hideShow: return GlanceHotKeyID.hideShow.rawValue
        case .quickCapture: return GlanceHotKeyID.quickCapture.rawValue
        case .clipboardCapture: return GlanceHotKeyID.clipboardCapture.rawValue
        case .clipboardHistory: return GlanceHotKeyID.clipboardHistory.rawValue
        case .fileShelf: return GlanceHotKeyID.fileShelf.rawValue
        }
    }

    private func action(forCarbonID id: UInt32) -> ShortcutAction? {
        switch GlanceHotKeyID(rawValue: id) {
        case .hideShow: return .hideShow
        case .quickCapture: return .quickCapture
        case .clipboardCapture: return .clipboardCapture
        case .clipboardHistory: return .clipboardHistory
        case .fileShelf: return .fileShelf
        case nil: return nil
        }
    }
}

let glanceHotKeySignature: OSType = {
    var result: OSType = 0
    for scalar in "GLNC".unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}()

private let glanceHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let userData, let event else {
        return OSStatus(eventNotHandledErr)
    }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == glanceHotKeySignature else {
        return OSStatus(eventNotHandledErr)
    }
    let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.handleHotKey(id: hotKeyID.id)
    }
    return noErr
}
