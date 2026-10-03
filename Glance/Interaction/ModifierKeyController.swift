import CoreGraphics

/// Reads current modifier flags from the login session without an
/// Accessibility prompt. Used by V0.2 Option-to-interact while pass-through.
enum ModifierKeyController {
    static var optionIsPressed: Bool {
        flags.contains(.maskAlternate)
    }

    static var controlIsPressed: Bool {
        flags.contains(.maskControl)
    }

    private static var flags: CGEventFlags {
        CGEventSource.flagsState(.hidSystemState)
    }
}
