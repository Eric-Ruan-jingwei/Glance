import AppKit

@MainActor
enum PanelWindowDrag {
    static func move(_ window: NSWindow, with event: NSEvent, onFinish: (() -> Void)? = nil) {
        window.performDrag(with: event)
        finishAfterMouseUp(onFinish)
    }

    static func moveThenFinishInteractive(_ window: NSWindow, with event: NSEvent) {
        move(window, with: event) {
            (window.windowController as? PanelWindowController)?.finishInteractiveMove()
        }
    }

    /// `performDrag(with:)` returns immediately and may swallow the view's mouse-up.
    /// Snap / persist only after the button is released so Control-at-release still
    /// bypasses snapping.
    private static func finishAfterMouseUp(_ onFinish: (() -> Void)?) {
        guard let onFinish else { return }
        if NSEvent.pressedMouseButtons & (1 << 0) == 0 {
            onFinish()
            return
        }

        final class FinishBox {
            var finished = false
            var local: Any?
            var global: Any?
            let handler: () -> Void

            init(handler: @escaping () -> Void) {
                self.handler = handler
            }

            func complete() {
                guard !finished else { return }
                finished = true
                if let local {
                    NSEvent.removeMonitor(local)
                }
                if let global {
                    NSEvent.removeMonitor(global)
                }
                local = nil
                global = nil
                handler()
            }
        }

        let box = FinishBox(handler: onFinish)
        box.local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            box.complete()
            return event
        }
        box.global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            box.complete()
        }
    }
}
