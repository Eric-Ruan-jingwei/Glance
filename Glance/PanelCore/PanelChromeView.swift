import AppKit

final class PanelChromeView: NSView {
    var minimumSize: NSSize = GlanceConstants.textMinSize
    var onCommitFrame: (() -> Void)?
    var onFinishMove: (() -> Void)?
    var onContextMenu: ((NSEvent) -> NSMenu)?
    var onPinToggle: (() -> Void)?
    var onHide: (() -> Void)?
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
    var isPinned: Bool = false {
        didSet { applyHover() }
    }
    var titleText: String = "" {
        didSet { titleLabel.stringValue = titleText }
    }
    var kindIdentifier: String = PanelKind.text {
        didSet { applyKindIcon() }
    }

    private let effectView = NSVisualEffectView()
    let contentContainer = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let kindIcon = NSImageView()
    private let lockBadge = NSImageView()
    private let pinButton = NSButton()
    private let hideButton = NSButton()
    private let moreButton = NSButton()
    private let accessoryStack = NSStackView()

    private var isHovered = false
    private var trackingArea: NSTrackingArea?
    private var dragStartFrame: NSRect = .zero
    private var dragStartMouse: NSPoint = .zero
    private var activeEdges: ResizeEdge = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        applyShape()

        effectView.material = GlanceTheme.Fill.panelMaterial
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)
        effectView.addSubview(contentContainer)

        titleLabel.font = GlanceTheme.Typography.chromeTitle
        titleLabel.textColor = GlanceTheme.Fill.chromeForeground
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.drawsBackground = false
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        kindIcon.imageScaling = .scaleProportionallyDown
        kindIcon.contentTintColor = GlanceTheme.Fill.chromeForegroundQuiet
        kindIcon.setAccessibilityLabel(PanelSummaryKindLabel.displayName(for: PanelKind.text))
        kindIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(kindIcon)
        applyKindIcon()

        configureIconButton(
            pinButton,
            action: #selector(pinClicked),
            label: "置顶"
        )
        configureIconButton(
            hideButton,
            action: #selector(hideClicked),
            label: GlanceRowActionCopy.hidePanel
        )
        hideButton.image = GlanceTheme.chromeSymbol("xmark", accessibilityDescription: GlanceRowActionCopy.hidePanel)
        configureIconButton(
            moreButton,
            action: #selector(moreClicked),
            label: "更多操作"
        )
        moreButton.image = GlanceTheme.chromeSymbol("ellipsis", accessibilityDescription: "更多操作")

        lockBadge.image = GlanceTheme.chromeSymbol("lock.fill", accessibilityDescription: "已锁定")
        lockBadge.contentTintColor = GlanceTheme.Fill.chromeForeground
        lockBadge.imageScaling = .scaleProportionallyDown
        lockBadge.setAccessibilityLabel("已锁定")

        accessoryStack.orientation = .horizontal
        accessoryStack.alignment = .centerY
        accessoryStack.spacing = 1
        accessoryStack.translatesAutoresizingMaskIntoConstraints = false
        accessoryStack.addArrangedSubview(lockBadge)
        accessoryStack.addArrangedSubview(pinButton)
        accessoryStack.addArrangedSubview(hideButton)
        accessoryStack.addArrangedSubview(moreButton)
        addSubview(accessoryStack)

        let chrome = GlanceTheme.Size.panelChromeHeight
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: effectView.topAnchor, constant: chrome),
            contentContainer.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: kindIcon.trailingAnchor, constant: GlanceTheme.Space.xs),
            titleLabel.centerYAnchor.constraint(
                equalTo: topAnchor,
                constant: chrome / 2
            ),
            kindIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GlanceTheme.Space.sm),
            kindIcon.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            kindIcon.widthAnchor.constraint(equalToConstant: 14),
            kindIcon.heightAnchor.constraint(equalToConstant: 14),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: accessoryStack.leadingAnchor,
                constant: -GlanceTheme.Space.sm
            ),
            accessoryStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -GlanceTheme.Space.sm),
            accessoryStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            lockBadge.widthAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton),
            lockBadge.heightAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton),
            pinButton.widthAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton),
            pinButton.heightAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton),
            hideButton.widthAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton),
            hideButton.heightAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton),
            moreButton.widthAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton),
            moreButton.heightAnchor.constraint(equalToConstant: GlanceTheme.Size.chromeButton)
        ])

        applyHover()
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
        if let accessory = accessoryStack.hitTest(convert(point, to: accessoryStack)),
           accessory !== accessoryStack {
            return accessory
        }
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
        PanelWindowDrag.move(window, with: event, onFinish: onFinishMove ?? onCommitFrame)
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
        let height = GlanceTheme.Size.panelChromeHeight
        let accessoryWidth = accessoryStack.bounds.width + GlanceTheme.Space.md
        return NSRect(
            x: t,
            y: bounds.height - height,
            width: max(0, bounds.width - 2 * t - accessoryWidth),
            height: height - t
        )
    }

    private func applyHover() {
        let chromeActive = isHovered || showsTemporaryInteraction
        layer?.borderWidth = GlanceTheme.Size.hairline
        titleLabel.textColor = chromeActive
            ? GlanceTheme.Fill.chromeForeground
            : GlanceTheme.Fill.chromeForegroundQuiet
        lockBadge.isHidden = false
        lockBadge.alphaValue = showsLockBadge ? 1 : 0
        lockBadge.setAccessibilityElement(showsLockBadge)
        pinButton.isHidden = false
        hideButton.isHidden = false
        moreButton.isHidden = false
        GlanceMotion.setAlpha(pinButton, (chromeActive || isPinned) ? 1 : 0)
        GlanceMotion.setAlpha(hideButton, chromeActive ? 1 : 0)
        GlanceMotion.setAlpha(moreButton, chromeActive ? 1 : 0)
        pinButton.isEnabled = chromeActive || isPinned
        hideButton.isEnabled = chromeActive
        moreButton.isEnabled = chromeActive
        pinButton.setAccessibilityElement(chromeActive || isPinned)
        hideButton.setAccessibilityElement(chromeActive)
        moreButton.setAccessibilityElement(chromeActive)
        kindIcon.alphaValue = chromeActive ? 1 : 0.72
        kindIcon.contentTintColor = chromeActive
            ? GlanceTheme.Fill.chromeForeground
            : GlanceTheme.Fill.chromeForegroundQuiet
        pinButton.image = GlanceTheme.chromeSymbol(
            isPinned ? "star.fill" : "star",
            accessibilityDescription: isPinned ? "取消置顶" : "置顶"
        )
        pinButton.contentTintColor = isPinned
            ? NSColor.controlAccentColor
            : GlanceTheme.Fill.chromeForeground
        moreButton.contentTintColor = GlanceTheme.Fill.chromeForeground
        hideButton.contentTintColor = GlanceTheme.Fill.chromeForeground
        applyShape()
        window?.invalidateShadow()
        window?.resetCursorRects()
        resetCursorRects()
    }

    private func applyShape() {
        let radius = GlanceTheme.Radius.panel
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.borderColor = (isHovered || showsTemporaryInteraction)
            ? GlanceTheme.Fill.panelBorderHover.cgColor
            : GlanceTheme.Fill.panelBorder.cgColor
        effectView.layer?.cornerRadius = radius
        effectView.layer?.cornerCurve = .continuous
    }

    private func configureIconButton(_ button: NSButton, action: Selector, label: String) {
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.setButtonType(.momentaryChange)
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = action
        button.refusesFirstResponder = true
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    @objc private func pinClicked() {
        onPinToggle?()
    }

    @objc private func hideClicked() {
        onHide?()
    }

    @objc private func moreClicked(_ sender: NSButton) {
        guard let event = NSApp.currentEvent, let menu = onContextMenu?(event) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: sender)
    }

    private func applyKindIcon() {
        let symbol = PanelChromeCloseRouting.kindSymbolName(for: kindIdentifier)
        let label = PanelSummaryKindLabel.displayName(for: kindIdentifier)
        kindIcon.image = GlanceTheme.chromeSymbol(symbol, accessibilityDescription: label)
        kindIcon.setAccessibilityLabel(label)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyShape()
    }
}

private struct ResizeEdge: OptionSet {
    let rawValue: Int
    static let left = ResizeEdge(rawValue: 1 << 0)
    static let right = ResizeEdge(rawValue: 1 << 1)
    static let top = ResizeEdge(rawValue: 1 << 2)
    static let bottom = ResizeEdge(rawValue: 1 << 3)
}
