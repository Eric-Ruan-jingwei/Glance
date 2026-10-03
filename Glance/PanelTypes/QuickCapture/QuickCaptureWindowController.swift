import AppKit

@MainActor
final class QuickCaptureWindowController: NSWindowController, NSTextViewDelegate {
    var onSubmit: (QuickCaptureRequest, NSScreen?) -> Bool = { _, _ in false }

    private let textView: QuickCaptureTextView
    private let modeControl = NSSegmentedControl()
    private let errorLabel = NSTextField(labelWithString: "无法创建面板")
    private var kind: QuickCaptureKind = .text
    private var localMouseMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    var isCaptureVisible: Bool {
        window?.isVisible == true
    }

    convenience init() {
        let panel = QuickCapturePanel(
            contentRect: NSRect(origin: .zero, size: GlanceConstants.quickCaptureSize)
        )
        self.init(window: panel)
        panel.windowController = self
        window?.initialFirstResponder = textView
        installContent()
    }

    override init(window: NSWindow?) {
        textView = QuickCaptureTextView(usingTextLayoutManager: false)
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        switch UtilityWindowPresentation.toggleAction(for: window) {
        case .dismiss:
            cancel()
        case .bringForward:
            UtilityWindowPresentation.bringForward(window)
            window?.makeFirstResponder(textView)
        case .present:
            present()
        }
    }

    func present() {
        resetDraft()
        positionOnWorkingScreen()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(textView)
        installDismissalMonitors()
    }

    func cancel() {
        dismiss(activatePreviousApp: true)
    }

    func setKind(_ kind: QuickCaptureKind) {
        self.kind = kind
        modeControl.selectedSegment = kind == .text ? 0 : 1
        window?.makeFirstResponder(textView)
    }

    func textDidChange(_ notification: Notification) {
        refreshPlaceholder()
        clearError()
    }

    fileprivate func handleReturnKey(_ event: NSEvent) -> Bool {
        window?.makeFirstResponder(textView)
        textView.handleReturn(event)
        return true
    }

    fileprivate func submit() {
        let request = QuickCaptureRequest(kind: kind, text: textView.string)
        guard request.isValid else {
            NSSound.beep()
            errorLabel.stringValue = "先输入内容"
            errorLabel.isHidden = false
            return
        }
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        if onSubmit(request, screen) {
            dismiss(activatePreviousApp: true)
        } else {
            errorLabel.stringValue = "无法创建面板"
            errorLabel.isHidden = false
        }
    }

    private func dismiss(activatePreviousApp: Bool) {
        removeDismissalMonitors()
        window?.orderOut(nil)
        resetDraft()
        if activatePreviousApp {
            NSApp.deactivate()
        }
    }

    private func resetDraft() {
        textView.string = ""
        setKind(.text)
        clearError()
        refreshPlaceholder()
    }

    private func clearError() {
        errorLabel.isHidden = true
    }

    private func refreshPlaceholder() {
        textView.needsDisplay = true
    }

    private func positionOnWorkingScreen() {
        let screen = DisplayManager.screenContainingMouse()
        let size = GlanceConstants.quickCaptureSize
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = visible.maxY - visible.height * 0.25 - size.height
        window?.setFrame(
            NSRect(x: x, y: max(visible.minY, y), width: size.width, height: size.height),
            display: true
        )
    }

    private func installDismissalMonitors() {
        removeDismissalMonitors()
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handlePossibleOutsideClick(event)
            return event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancel()
            }
        }
    }

    private func removeDismissalMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    private func handlePossibleOutsideClick(_ event: NSEvent) {
        guard isCaptureVisible, let capture = window else { return }
        guard let eventWindow = event.window, eventWindow !== capture else { return }
        // Leave IME candidate / menu popups alone.
        if eventWindow.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
            return
        }
        cancel()
    }

    private func installContent() {
        guard let window else { return }

        let effect = NSVisualEffectView()
        effect.material = GlanceTheme.Fill.floatingMaterial
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = GlanceTheme.Radius.panel
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false

        let border = NSView()
        border.wantsLayer = true
        border.layer?.cornerRadius = GlanceTheme.Radius.panel
        border.layer?.cornerCurve = .continuous
        border.layer?.borderWidth = GlanceTheme.Size.hairline
        border.layer?.borderColor = GlanceTheme.Fill.panelBorder.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        border.addSubview(effect)

        textView.delegate = self
        textView.onSubmit = { [weak self] in self?.submit() }
        textView.allowsNewline = { [weak self] in self?.kind == .text }
        textView.minSize = NSSize(width: 0, height: 80)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 480, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = GlanceTheme.Typography.body
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: GlanceTheme.Space.xxs)
        textView.placeholderString = GlanceEmptyCopy.quickCapturePlaceholder
        textView.setAccessibilityPlaceholderValue(GlanceEmptyCopy.quickCapturePlaceholder)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.focusRingType = .none

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets()
        scroll.contentView.drawsBackground = false
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        modeControl.segmentCount = 2
        modeControl.setLabel("文字", forSegment: 0)
        modeControl.setLabel("待办", forSegment: 1)
        modeControl.selectedSegment = 0
        modeControl.segmentStyle = .rounded
        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.textColor = .secondaryLabelColor
        errorLabel.font = GlanceTheme.Typography.tertiary
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(scroll)
        effect.addSubview(modeControl)
        effect.addSubview(errorLabel)
        window.contentView = border

        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: border.leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: border.trailingAnchor),
            effect.topAnchor.constraint(equalTo: border.topAnchor),
            effect.bottomAnchor.constraint(equalTo: border.bottomAnchor),

            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: GlanceTheme.Space.lg),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -GlanceTheme.Space.lg),
            scroll.topAnchor.constraint(equalTo: effect.topAnchor, constant: GlanceTheme.Space.md),
            scroll.heightAnchor.constraint(equalToConstant: 88),

            modeControl.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: GlanceTheme.Space.lg),
            modeControl.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: GlanceTheme.Space.md),
            modeControl.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -GlanceTheme.Space.md),

            errorLabel.leadingAnchor.constraint(equalTo: modeControl.trailingAnchor, constant: GlanceTheme.Space.md),
            errorLabel.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -GlanceTheme.Space.lg)
        ])
    }

    @objc private func modeChanged() {
        kind = modeControl.selectedSegment == 1 ? .todo : .text
        window?.makeFirstResponder(textView)
    }
}

final class QuickCapturePanel: NSPanel {
    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = true
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        (windowController as? QuickCaptureWindowController)?.cancel()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, let character = event.charactersIgnoringModifiers {
            switch character {
            case "1":
                (windowController as? QuickCaptureWindowController)?.setKind(.text)
                return true
            case "2":
                (windowController as? QuickCaptureWindowController)?.setKind(.todo)
                return true
            default:
                break
            }
        }
        if QuickCaptureReturn.isReturnKey(event) {
            return (windowController as? QuickCaptureWindowController)?.handleReturnKey(event) ?? false
        }
        return super.performKeyEquivalent(with: event)
    }
}

enum QuickCapturePlaceholderLayout {
    static func shouldDraw(text: String, isComposing: Bool) -> Bool {
        text.isEmpty && !isComposing
    }

    static func origin(
        containerOrigin: NSPoint,
        extraLineFragment: NSRect,
        lineFragmentPadding: CGFloat
    ) -> NSPoint {
        NSPoint(
            x: containerOrigin.x + extraLineFragment.minX + lineFragmentPadding,
            y: containerOrigin.y + extraLineFragment.minY
        )
    }
}

enum QuickCaptureReturn {
    case confirmComposition
    case insertNewline
    case submit

    static func action(isComposing: Bool, shift: Bool, allowsNewline: Bool) -> QuickCaptureReturn {
        if isComposing { return .confirmComposition }
        if shift, allowsNewline { return .insertNewline }
        return .submit
    }

    static func isReturnKey(_ event: NSEvent) -> Bool {
        event.keyCode == 36 || event.keyCode == 76
    }

    static func isNewlineCommand(_ selector: Selector) -> Bool {
        selector == #selector(NSResponder.insertNewline(_:))
            || selector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            || selector == #selector(NSResponder.insertLineBreak(_:))
    }
}

final class QuickCaptureTextView: NSTextView {
    var onSubmit: () -> Void = {}
    var allowsNewline: () -> Bool = { true }
    var placeholderString = GlanceEmptyCopy.quickCapturePlaceholder
    private var isHandlingReturn = false

    var placeholderOrigin: NSPoint {
        if let textContainer {
            layoutManager?.ensureLayout(for: textContainer)
        }
        return QuickCapturePlaceholderLayout.origin(
            containerOrigin: textContainerOrigin,
            extraLineFragment: layoutManager?.extraLineFragmentRect ?? .zero,
            lineFragmentPadding: textContainer?.lineFragmentPadding ?? 0
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        drawPlaceholderIfNeeded()
        super.draw(dirtyRect)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    private func drawPlaceholderIfNeeded() {
        guard QuickCapturePlaceholderLayout.shouldDraw(text: string, isComposing: hasMarkedText()) else {
            return
        }
        if let textContainer {
            layoutManager?.ensureLayout(for: textContainer)
        }
        let fragmentHeight = layoutManager?.extraLineFragmentRect.height ?? 0
        let height = fragmentHeight > 0
            ? fragmentHeight
            : ceil((font ?? GlanceTheme.Typography.body).boundingRectForFont.height)
        let origin = placeholderOrigin
        let drawingRect = NSRect(
            x: origin.x,
            y: origin.y,
            width: max(0, bounds.width - origin.x),
            height: height
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? GlanceTheme.Typography.body,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        (placeholderString as NSString).draw(in: drawingRect, withAttributes: attributes)
    }

    func handleReturn(_ event: NSEvent) {
        switch QuickCaptureReturn.action(
            isComposing: hasMarkedText(),
            shift: event.modifierFlags.contains(.shift),
            allowsNewline: allowsNewline()
        ) {
        case .confirmComposition:
            isHandlingReturn = true
            super.keyDown(with: event)
            isHandlingReturn = false
        case .insertNewline:
            insertNewline(nil)
        case .submit:
            onSubmit()
        }
    }

    override func keyDown(with event: NSEvent) {
        if !isHandlingReturn, QuickCaptureReturn.isReturnKey(event) {
            handleReturn(event)
            return
        }
        super.keyDown(with: event)
    }

    override func doCommand(by selector: Selector) {
        if QuickCaptureReturn.isNewlineCommand(selector) {
            switch QuickCaptureReturn.action(
                isComposing: hasMarkedText(),
                shift: NSApp.currentEvent?.modifierFlags.contains(.shift) == true,
                allowsNewline: allowsNewline()
            ) {
            case .confirmComposition, .insertNewline:
                super.doCommand(by: selector)
            case .submit:
                onSubmit()
            }
            return
        }
        super.doCommand(by: selector)
    }
}
