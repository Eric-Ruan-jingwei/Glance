import Carbon
import Foundation

/// Registers ⌥⌘H without Accessibility permission.
final class ShortcutManager: @unchecked Sendable {
    var onToggleVisibility: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func registerDefaults() {
        unregister()

        let hotKeyID = EventHotKeyID(signature: fourCharCode("GLNC"), id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if hotKeyStatus != noErr {
            NSLog("Glance shortcuts: RegisterEventHotKey failed (%d)", hotKeyStatus)
            return
        }

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

    func unregister() {
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    fileprivate func handleHotKey() {
        onToggleVisibility?()
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}

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
    guard status == noErr, hotKeyID.signature == fourCharCode("GLNC") else {
        return OSStatus(eventNotHandledErr)
    }
    let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.handleHotKey()
    }
    return noErr
}
