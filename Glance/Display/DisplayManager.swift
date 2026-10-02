import AppKit

enum DisplayManager {
    static func screenContainingMouse() -> NSScreen {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    static func identifier(for screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return String(number.uint32Value)
        }
        return screen.localizedName
    }

    static func screen(forIdentifier identifier: String) -> NSScreen? {
        NSScreen.screens.first { self.identifier(for: $0) == identifier }
    }
}
