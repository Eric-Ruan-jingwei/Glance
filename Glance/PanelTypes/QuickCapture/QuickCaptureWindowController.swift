import AppKit

@MainActor
final class QuickCaptureWindowController: NSWindowController, NSTextViewDelegate {
    var makeDestinations: (NSScreen?) -> QuickCaptureDestinations = { _ in .unavailable }
    var readPasteboard: () -> QuickCaptureContent = { QuickCapturePasteboard.content() }

    let model = QuickCaptureModel()
    private let textView: QuickCaptureTextView
    private let detectedRow = NSStackView()
    private let detectedIcon = NSImageView()
    private let detectedLabel = NSTextField(labelWithString: "")
    private let chromeStack = NSStackView()
    private let actionStack = NSStackView()
    private let errorLabel = NSTextField(labelWithString: "")
    private var localMouseMonitor: Any?
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var isApplyingModel = false

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
        applyPrefillIfNeeded()
        positionOnWorkingScreen()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(textView)
        installDismissalMonitors()
    }

    func cancel() {
        dismiss(activatePreviousApp: true)
    }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingModel else { return }
        model.setText(textView.string)
        refreshChrome()
    }

    fileprivate func handleReturnKey(_ event: NSEvent) -> Bool {
        window?.makeFirstResponder(textView)
        textView.handleReturn(event)
        return true
    }

    fileprivate func handleArrowKey(delta: Int) {
        guard !textView.hasMarkedText() else { return }
        model.moveAction(delta)
        refreshChrome()
    }

    fileprivate func acceptDroppedFiles(_ urls: [URL]) {
        let files = QuickCaptureClassifier.uniquedFileURLs(urls)
        guard !files.isEmpty else { return }
        model.setFiles(files)
        syncEditorFromModel()
        refreshChrome()
    }

    fileprivate func submit() {
        if !isApplyingModel {
            model.setText(textView.string)
        }
        let screen = window?.screen ?? DisplayManager.screenContainingMouse()
        if model.submit(using: makeDestinations(screen)) {
            dismiss(activatePreviousApp: true)
            return
        }
        NSSound.beep()
        refreshChrome()
        window?.makeFirstResponder(textView)
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
        model.reset()
        syncEditorFromModel()
        refreshChrome()
    }

    private func applyPrefillIfNeeded() {
        guard model.content == .empty else { return }
        let prefill = readPasteboard()
        guard prefill != .empty else { return }
        model.applyPrefill(prefill)
        syncEditorFromModel()
        refreshChrome()
    }

    private func syncEditorFromModel() {
        isApplyingModel = true
        textView.string = model.text
        isApplyingModel = false
        refreshPlaceholder()
    }

    private func refreshPlaceholder() {
        textView.needsDisplay = true
    }

    private func refreshChrome() {
        let content = model.content
        let detectedTitle = QuickCaptureCopy.detectedTitle(for: content)
        detectedLabel.stringValue = detectedTitle
        if let symbol = QuickCaptureDetectedPresentation.symbolName(for: content) {
            detectedIcon.image = GlanceTheme.symbol(symbol, pointSize: 11)
            detectedIcon.contentTintColor = .secondaryLabelColor
            detectedIcon.isHidden = false
        } else {
            detectedIcon.image = nil
            detectedIcon.isHidden = true
        }
        detectedRow.isHidden = detectedTitle.isEmpty
        errorLabel.stringValue = model.error ?? ""
        errorLabel.isHidden = model.error == nil
        rebuildActionButtons()
        textView.allowsNewline = { [weak self] in self?.model.allowsNewline ?? true }
        refreshPlaceholder()
    }

    private func rebuildActionButtons() {
        actionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let content = model.content
        for action in model.actions {
            let row = QuickCaptureActionRowView(
                action: action,
                content: content,
                isSelected: QuickCaptureActionPresentation.isSelected(
                    action,
                    selectedAction: model.selectedAction
                )
            )
            row.onActivate = { [weak self] selected in
                self?.actionClicked(selected)
            }
            actionStack.addArrangedSubview(row)
        }
        actionStack.isHidden = model.actions.isEmpty
    }

    private func actionClicked(_ action: QuickCaptureAction) {
        model.select(action)
        submit()
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
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
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
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard isCaptureVisible else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch QuickCaptureKeyPolicy.intent(
            keyCode: event.keyCode,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            isComposing: textView.hasMarkedText(),
            allowsNewline: model.allowsNewline
        ) {
        case .moveAction(let delta):
            handleArrowKey(delta: delta)
            return nil
        case .submit:
            if flags.contains(.command) {
                submit()
                return nil
            }
            return event
        case .insertNewline, .confirmComposition, .none:
            return event
        }
    }

    private func handlePossibleOutsideClick(_ event: NSEvent) {
        guard isCaptureVisible, let capture = window else { return }
        guard let eventWindow = event.window, eventWindow !== capture else { return }
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

        let border = QuickCaptureDropView()
        border.onDropFiles = { [weak self] urls in self?.acceptDroppedFiles(urls) }
        border.registerForDraggedTypes([.fileURL])
        border.wantsLayer = true
        border.layer?.cornerRadius = GlanceTheme.Radius.panel
        border.layer?.cornerCurve = .continuous
        border.layer?.borderWidth = GlanceTheme.Size.hairline
        border.layer?.borderColor = GlanceTheme.Fill.panelBorder.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        border.addSubview(effect)

        textView.delegate = self
        textView.onSubmit = { [weak self] in self?.submit() }
        textView.onPasteFiles = { [weak self] urls in self?.acceptDroppedFiles(urls) }
        textView.allowsNewline = { [weak self] in self?.model.allowsNewline ?? true }
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
        textView.registerForDraggedTypes([.fileURL])
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

        detectedIcon.imageScaling = .scaleProportionallyDown
        detectedIcon.setAccessibilityElement(false)
        detectedIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            detectedIcon.widthAnchor.constraint(equalToConstant: 12),
            detectedIcon.heightAnchor.constraint(equalToConstant: 12)
        ])

        detectedLabel.textColor = .secondaryLabelColor
        detectedLabel.font = GlanceTheme.Typography.tertiary
        detectedLabel.setAccessibilityRole(.staticText)

        detectedRow.orientation = .horizontal
        detectedRow.alignment = .centerY
        detectedRow.spacing = GlanceTheme.Space.xs
        detectedRow.addArrangedSubview(detectedIcon)
        detectedRow.addArrangedSubview(detectedLabel)

        actionStack.orientation = .vertical
        actionStack.alignment = .width
        actionStack.spacing = GlanceTheme.Space.xxs

        errorLabel.textColor = .secondaryLabelColor
        errorLabel.font = GlanceTheme.Typography.tertiary
        errorLabel.isHidden = true
        errorLabel.setAccessibilityRole(.staticText)

        chromeStack.orientation = .vertical
        chromeStack.alignment = .leading
        chromeStack.spacing = GlanceTheme.Space.xs
        chromeStack.translatesAutoresizingMaskIntoConstraints = false
        chromeStack.addArrangedSubview(detectedRow)
        chromeStack.addArrangedSubview(errorLabel)
        chromeStack.addArrangedSubview(actionStack)

        effect.addSubview(scroll)
        effect.addSubview(chromeStack)
        window.contentView = border

        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: border.leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: border.trailingAnchor),
            effect.topAnchor.constraint(equalTo: border.topAnchor),
            effect.bottomAnchor.constraint(equalTo: border.bottomAnchor),

            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: GlanceTheme.Space.lg),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -GlanceTheme.Space.lg),
            scroll.topAnchor.constraint(equalTo: effect.topAnchor, constant: GlanceTheme.Space.md),
            scroll.heightAnchor.constraint(equalToConstant: 72),

            chromeStack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: GlanceTheme.Space.lg),
            chromeStack.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -GlanceTheme.Space.lg),
            chromeStack.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: GlanceTheme.Space.sm),
            chromeStack.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -GlanceTheme.Space.md),

            actionStack.trailingAnchor.constraint(equalTo: chromeStack.trailingAnchor)
        ])
        refreshChrome()
    }
}

final class QuickCaptureDropView: NSView {
    var onDropFiles: ([URL]) -> Void = { _ in }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        QuickCapturePasteboard.fileURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        !QuickCapturePasteboard.fileURLs(from: sender.draggingPasteboard).isEmpty
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = QuickCapturePasteboard.fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        onDropFiles(urls)
        return true
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
    var onPasteFiles: ([URL]) -> Void = { _ in }
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

    override func paste(_ sender: Any?) {
        let files = QuickCapturePasteboard.fileURLs(from: .general)
        if !files.isEmpty {
            onPasteFiles(files)
            return
        }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        QuickCapturePasteboard.fileURLs(from: sender.draggingPasteboard).isEmpty
            ? super.draggingEntered(sender)
            : .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = QuickCapturePasteboard.fileURLs(from: sender.draggingPasteboard)
        if !urls.isEmpty {
            onPasteFiles(urls)
            return true
        }
        return super.performDragOperation(sender)
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
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch QuickCaptureKeyPolicy.intent(
            keyCode: event.keyCode,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            isComposing: hasMarkedText(),
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
        case .moveAction, .none:
            break
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
