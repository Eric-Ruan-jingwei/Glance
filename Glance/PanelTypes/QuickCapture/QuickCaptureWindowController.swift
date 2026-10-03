import AppKit

@MainActor
final class QuickCaptureWindowController: NSWindowController, NSTextViewDelegate {
    var onSubmit: (QuickCaptureRequest, NSScreen?) -> Bool = { _, _ in false }

    private let textView: QuickCaptureTextView
    private let placeholder = NSTextField(labelWithString: "记录点什么…")
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
        if isCaptureVisible {
            cancel()
        } else {
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

    fileprivate func submit() {
        let request = QuickCaptureRequest(kind: kind, text: textView.string)
        guard request.isValid else {
            NSSound.beep()
            return
        }
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        if onSubmit(request, screen) {
            dismiss(activatePreviousApp: true)
        } else {
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
        placeholder.isHidden = !textView.string.isEmpty
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
        textView.textContainerInset = NSSize(width: 2, height: GlanceTheme.Space.xs)
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
        scroll.documentView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        placeholder.textColor = .tertiaryLabelColor
        placeholder.font = GlanceTheme.Typography.body
        placeholder.translatesAutoresizingMaskIntoConstraints = false

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
        effect.addSubview(placeholder)
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

            placeholder.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: GlanceTheme.Space.sm),
            placeholder.topAnchor.constraint(equalTo: scroll.topAnchor, constant: GlanceTheme.Space.sm),

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
        guard flags == .command, let character = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        switch character {
        case "1":
            (windowController as? QuickCaptureWindowController)?.setKind(.text)
            return true
        case "2":
            (windowController as? QuickCaptureWindowController)?.setKind(.todo)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

final class QuickCaptureTextView: NSTextView {
    var onSubmit: () -> Void = {}
    var allowsNewline: () -> Bool = { true }

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)) || selector == #selector(insertNewlineIgnoringFieldEditor(_:)) {
            let isComposing = hasMarkedText()
            if isComposing {
                super.doCommand(by: selector)
                return
            }
            let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            if shift, allowsNewline() {
                super.doCommand(by: selector)
                return
            }
            onSubmit()
            return
        }
        super.doCommand(by: selector)
    }
}
