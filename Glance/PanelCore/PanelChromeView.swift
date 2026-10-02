import AppKit

final class PanelChromeView: NSView {
    var minimumSize: NSSize = GlanceConstants.textMinSize
    var onCommitFrame: (() -> Void)?
    var onContextMenu: ((NSEvent) -> NSMenu)?
    var isInteractable: Bool = true
    var allowsMove: Bool = true {
        didSet { applyHover() }
    }
    var allowsResize: Bool = true
    var showsLockBadge: Bool = false {
        didSet { applyHover() }
    }
    var showsTemporaryInteraction: Bool = false {
        didSet { applyHover() }
    }

    private let effectView = NSVisualEffectView()
    let contentContainer = NSView()
    private let lockBadge = NSImageView()
    private let dragGrip = NSView()

    private var isHovered = false
    private var trackingArea: NSTrackingArea?
    private var dragStartFrame: NSRect = .zero
    private var dragStartMouse: NSPoint = .zero
    private var activeEdges: ResizeEdge = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = GlanceConstants.cornerRadius
        layer?.masksToBounds = false
        layer?.borderWidth = 0
        applyBorderColor()

        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = GlanceConstants.cornerRadius
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)
        effectView.addSubview(contentContainer)

        lockBadge.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "已锁定")
        lockBadge.contentTintColor = NSColor.secondaryLabelColor
        lockBadge.imageScaling = .scaleProportionallyDown
        lockBadge.translatesAutoresizingMaskIntoConstraints = false
        lockBadge.isHidden = true
        addSubview(lockBadge)

        dragGrip.wantsLayer = true
        dragGrip.layer?.cornerRadius = 1.5
        dragGrip.translatesAutoresizingMaskIntoConstraints = false
        dragGrip.isHidden = true
        addSubview(dragGrip)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: effectView.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            lockBadge.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            lockBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            lockBadge.widthAnchor.constraint(equalToConstant: 11),
            lockBadge.heightAnchor.constraint(equalToConstant: 11),
            dragGrip.centerXAnchor.constraint(equalTo: centerXAnchor),
            dragGrip.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            dragGrip.widthAnchor.constraint(equalToConstant: 22),
            dragGrip.heightAnchor.constraint(equalToConstant: 3)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embed(_ content: NSView) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        content.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyHover()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyHover()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard isInteractable else { return }
        let t = GlanceConstants.resizeEdge
        if allowsResize {
            addCursorRect(NSRect(x: 0, y: t, width: t, height: bounds.height - 2 * t), cursor: .resizeLeftRight)
            addCursorRect(NSRect(x: bounds.width - t, y: t, width: t, height: bounds.height - 2 * t), cursor: .resizeLeftRight)
            addCursorRect(NSRect(x: t, y: bounds.height - t, width: bounds.width - 2 * t, height: t), cursor: .resizeUpDown)
            addCursorRect(NSRect(x: t, y: 0, width: bounds.width - 2 * t, height: t), cursor: .resizeUpDown)
            addCursorRect(NSRect(x: 0, y: bounds.height - t, width: t, height: t), cursor: .resizeLeftRight)
            addCursorRect(NSRect(x: bounds.width - t, y: bounds.height - t, width: t, height: t), cursor: .resizeLeftRight)
            addCursorRect(NSRect(x: 0, y: 0, width: t, height: t), cursor: .resizeLeftRight)
            addCursorRect(NSRect(x: bounds.width - t, y: 0, width: t, height: t), cursor: .resizeLeftRight)
        }
        if allowsMove {
            addCursorRect(dragStripRect, cursor: .openHand)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isInteractable, allowsResize, !edges(at: point).isEmpty {
            return self
        }
        if isInteractable, allowsMove, dragStripRect.contains(point) {
            return self
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        guard isInteractable, let window else { return }
        if event.type == .rightMouseDown { return }
        let local = convert(event.locationInWindow, from: nil)
        let edges = edges(at: local)
        if allowsResize, !edges.isEmpty {
            activeEdges = edges
            dragStartFrame = window.frame
            dragStartMouse = NSEvent.mouseLocation
            return
        }
        guard allowsMove else { return }
        PanelWindowDrag.move(window, onFinish: onCommitFrame)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isInteractable, allowsResize, let window, !activeEdges.isEmpty else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - dragStartMouse.x
        let dy = mouse.y - dragStartMouse.y
        var frame = dragStartFrame

        if activeEdges.contains(.right) {
            frame.size.width = max(minimumSize.width, dragStartFrame.width + dx)
        }
        if activeEdges.contains(.left) {
            let width = max(minimumSize.width, dragStartFrame.width - dx)
            frame.origin.x = dragStartFrame.maxX - width
            frame.size.width = width
        }
        if activeEdges.contains(.top) {
            frame.size.height = max(minimumSize.height, dragStartFrame.height + dy)
        }
        if activeEdges.contains(.bottom) {
            let height = max(minimumSize.height, dragStartFrame.height - dy)
            frame.origin.y = dragStartFrame.maxY - height
            frame.size.height = height
        }

        window.setFrame(frame, display: true)
        window.invalidateShadow()
    }

    override func mouseUp(with event: NSEvent) {
        if !activeEdges.isEmpty {
            activeEdges = []
            onCommitFrame?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = onContextMenu?(event) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    private func edges(at point: NSPoint) -> ResizeEdge {
        let t = GlanceConstants.resizeEdge
        var result: ResizeEdge = []
        if point.x <= t { result.insert(.left) }
        if point.x >= bounds.width - t { result.insert(.right) }
        if point.y <= t { result.insert(.bottom) }
        if point.y >= bounds.height - t { result.insert(.top) }
        return result
    }

    private var dragStripRect: NSRect {
        let t = GlanceConstants.resizeEdge
        let height = GlanceConstants.panelDragStrip
        return NSRect(
            x: t,
            y: bounds.height - t - height,
            width: max(0, bounds.width - 2 * t),
            height: height
        )
    }

    private func applyHover() {
        let showBorder = isHovered || showsTemporaryInteraction
        layer?.borderWidth = showBorder ? 1 : 0
        lockBadge.isHidden = !(showsLockBadge && isHovered)
        dragGrip.isHidden = !(isHovered && allowsMove)
        applyBorderColor()
        window?.invalidateShadow()
        window?.resetCursorRects()
        resetCursorRects()
    }

    private func applyBorderColor() {
        layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.16).cgColor
        layer?.cornerRadius = GlanceConstants.cornerRadius
        dragGrip.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.28).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyBorderColor()
    }
}

private struct ResizeEdge: OptionSet {
    let rawValue: Int
    static let left = ResizeEdge(rawValue: 1 << 0)
    static let right = ResizeEdge(rawValue: 1 << 1)
    static let top = ResizeEdge(rawValue: 1 << 2)
    static let bottom = ResizeEdge(rawValue: 1 << 3)
}
