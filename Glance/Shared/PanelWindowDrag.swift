import AppKit

@MainActor
enum PanelWindowDrag {
    static func move(_ window: NSWindow, onFinish: (() -> Void)? = nil) {
        let startFrame = window.frame
        let startMouse = NSEvent.mouseLocation
        while true {
            guard let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if event.type == .leftMouseUp {
                onFinish?()
                break
            }
            let mouse = NSEvent.mouseLocation
            var frame = startFrame
            frame.origin.x = startFrame.origin.x + (mouse.x - startMouse.x)
            frame.origin.y = startFrame.origin.y + (mouse.y - startMouse.y)
            window.setFrame(frame, display: true)
        }
    }

    static func moveThenFinishInteractive(_ window: NSWindow) {
        move(window) {
            (window.windowController as? PanelWindowController)?.finishInteractiveMove()
        }
    }
}
