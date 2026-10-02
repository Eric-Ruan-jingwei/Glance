import AppKit

extension PanelFrame {
    init(_ rect: NSRect) {
        self.init(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    var nsRect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}
