import Carbon
import Foundation

enum GlanceHotKeyID: UInt32 {
    case hideShow = 1
    case quickCapture = 2
    case clipboardCapture = 3
}

/// Registers ⌥⌘G, ⌥⌘J, and ⌥⌘B without Accessibility permission.
final class ShortcutManager: @unchecked Sendable {
    var onToggleVisibility: (() -> Void)?
    var onQuickCapture: (() -> Void)?
    var onCaptureClipboard: (() -> Void)?

    private var hideShowHotKeyRef: EventHotKeyRef?
    private var quickCaptureHotKeyRef: EventHotKeyRef?
    private var clipboardCaptureHotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func registerDefaults() {
        unregister()

        registerHotKey(
            virtualKey: UInt32(kVK_ANSI_G),
            id: GlanceHotKeyID.hideShow,
            displayName: GlanceConstants.hideShowShortcutDisplay,
            storage: &hideShowHotKeyRef
        )
        registerHotKey(
            virtualKey: UInt32(kVK_ANSI_J),
            id: GlanceHotKeyID.quickCapture,
            displayName: GlanceConstants.quickCaptureShortcutDisplay,
            storage: &quickCaptureHotKeyRef
        )
        registerHotKey(
            virtualKey: UInt32(kVK_ANSI_B),
            id: GlanceHotKeyID.clipboardCapture,
            displayName: GlanceConstants.clipboardCaptureShortcutDisplay,
            storage: &clipboardCaptureHotKeyRef
        )

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
        if let hideShowHotKeyRef {
            UnregisterEventHotKey(hideShowHotKeyRef)
            self.hideShowHotKeyRef = nil
        }
        if let quickCaptureHotKeyRef {
            UnregisterEventHotKey(quickCaptureHotKeyRef)
            self.quickCaptureHotKeyRef = nil
        }
        if let clipboardCaptureHotKeyRef {
            UnregisterEventHotKey(clipboardCaptureHotKeyRef)
            self.clipboardCaptureHotKeyRef = nil
        }
    }

    fileprivate func handleHotKey(id: UInt32) {
        switch GlanceHotKeyID(rawValue: id) {
        case .hideShow:
            onToggleVisibility?()
        case .quickCapture:
            onQuickCapture?()
        case .clipboardCapture:
            onCaptureClipboard?()
        case nil:
            break
        }
    }

    private func registerHotKey(
        virtualKey: UInt32,
        id: GlanceHotKeyID,
        displayName: String,
        storage: inout EventHotKeyRef?
    ) {
        let hotKeyID = EventHotKeyID(signature: fourCharCode("GLNC"), id: id.rawValue)
        let status = RegisterEventHotKey(
            virtualKey,
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &storage
        )
        if status != noErr {
            NSLog(
                "Glance global shortcut %@ could not be registered (%d)",
                displayName as NSString,
                status
            )
        }
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
        manager.handleHotKey(id: hotKeyID.id)
    }
    return noErr
}
