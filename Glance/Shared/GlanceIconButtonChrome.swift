import AppKit

enum GlanceIconButtonChrome {
    static var side: CGFloat { GlanceRowQuickActionLayout.buttonSide }
    static var cornerRadius: CGFloat { GlanceTheme.Radius.control }

    static func backgroundColor(isHovered: Bool) -> NSColor {
        isHovered ? GlanceTheme.Fill.rowHover : .clear
    }
}

class GlanceHoverIconButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private(set) var isPointerInside = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        imagePosition = .imageOnly
        bezelStyle = .inline
        focusRingType = .none
        wantsLayer = true
        applyHoverChrome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: GlanceIconButtonChrome.side, height: GlanceIconButtonChrome.side)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isPointerInside = true
        applyHoverChrome()
    }

    override func mouseExited(with event: NSEvent) {
        isPointerInside = false
        applyHoverChrome()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyHoverChrome()
    }

    func applyHoverChrome() {
        layer?.cornerRadius = GlanceIconButtonChrome.cornerRadius
        layer?.cornerCurve = .continuous
        let fill = GlanceIconButtonChrome.backgroundColor(isHovered: isPointerInside)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fill.cgColor
        }
    }
}
