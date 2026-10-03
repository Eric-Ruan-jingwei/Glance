import AppKit
import Carbon

enum MacShortcutAdapter {
    static func carbonKeyCode(for shortcut: GlanceShortcut) -> UInt32? {
        keyCodes[shortcut.canonicalKey]
    }

    static func carbonModifiers(for shortcut: GlanceShortcut) -> UInt32 {
        var modifiers: UInt32 = 0
        if shortcut.command { modifiers |= UInt32(cmdKey) }
        if shortcut.option { modifiers |= UInt32(optionKey) }
        if shortcut.control { modifiers |= UInt32(controlKey) }
        if shortcut.shift { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    static func menuModifierMask(for shortcut: GlanceShortcut) -> NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if shortcut.command { mask.insert(.command) }
        if shortcut.option { mask.insert(.option) }
        if shortcut.control { mask.insert(.control) }
        if shortcut.shift { mask.insert(.shift) }
        return mask
    }

    static func key(fromCarbonKeyCode code: UInt32) -> String? {
        keyCodes.first { $0.value == code }?.key
    }

    static func key(from event: NSEvent) -> String? {
        key(fromCarbonKeyCode: UInt32(event.keyCode))
    }

    static func modifiers(from event: NSEvent) -> (command: Bool, option: Bool, control: Bool, shift: Bool) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return (
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )
    }

    static func isEscape(_ event: NSEvent) -> Bool {
        event.keyCode == UInt16(kVK_Escape)
    }

    static func isDelete(_ event: NSEvent) -> Bool {
        event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)
    }

    private static let keyCodes: [String: UInt32] = [
        "a": UInt32(kVK_ANSI_A),
        "b": UInt32(kVK_ANSI_B),
        "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D),
        "e": UInt32(kVK_ANSI_E),
        "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G),
        "h": UInt32(kVK_ANSI_H),
        "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J),
        "k": UInt32(kVK_ANSI_K),
        "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M),
        "n": UInt32(kVK_ANSI_N),
        "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P),
        "q": UInt32(kVK_ANSI_Q),
        "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S),
        "t": UInt32(kVK_ANSI_T),
        "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V),
        "w": UInt32(kVK_ANSI_W),
        "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y),
        "z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0),
        "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4),
        "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6),
        "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9)
    ]
}
