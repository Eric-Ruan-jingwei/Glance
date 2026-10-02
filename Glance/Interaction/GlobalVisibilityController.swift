import AppKit

@MainActor
final class GlobalVisibilityController {
    private(set) var isConcealed = false

    func toggle(windows: [NSWindow]) {
        isConcealed.toggle()
        apply(windows: windows)
    }

    func apply(windows: [NSWindow]) {
        for window in windows {
            if isConcealed {
                window.orderOut(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }
}
