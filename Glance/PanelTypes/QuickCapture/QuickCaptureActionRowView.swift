import AppKit

final class QuickCaptureActionRowView: NSView {
    static let rowHeight: CGFloat = 32

    let action: QuickCaptureAction
    var onActivate: ((QuickCaptureAction) -> Void)?

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let destinationLabel = NSTextField(labelWithString: "")
    private let checkView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var selected = false

    var isSelected: Bool {
        get { selected }
        set {
            guard selected != newValue else { return }
            selected = newValue
            applyChrome()
        }
    }

    init(
        action: QuickCaptureAction,
        content: QuickCaptureContent,
        isSelected: Bool
    ) {
        self.action = action
        self.selected = isSelected
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier(action.identifier)
        configure(content: content)
        applyChrome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.rowHeight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyChrome()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyChrome()
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }
        onActivate?(action)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    private func configure(content: QuickCaptureContent) {
        wantsLayer = true
        layer?.cornerRadius = GlanceTheme.Radius.control
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false

        iconView.image = GlanceTheme.symbol(
            QuickCaptureActionPresentation.symbolName(for: action, content: content),
            pointSize: 13
        )
        iconView.imageScaling = .scaleProportionallyDown
        iconView.setAccessibilityElement(false)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = action.title
        titleLabel.font = GlanceTheme.Typography.body
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        destinationLabel.stringValue = QuickCaptureActionPresentation.destinationLabel(for: action)
        destinationLabel.font = GlanceTheme.Typography.tertiary
        destinationLabel.lineBreakMode = .byTruncatingTail
        destinationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let labels = NSStackView(views: [titleLabel, destinationLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        labels.translatesAutoresizingMaskIntoConstraints = false

        checkView.image = GlanceTheme.symbol("checkmark", pointSize: 11)
        checkView.imageScaling = .scaleProportionallyDown
        checkView.setAccessibilityElement(false)
        checkView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(labels)
        addSubview(checkView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.rowHeight),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GlanceTheme.Space.sm),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            labels.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: GlanceTheme.Space.sm),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(equalTo: checkView.leadingAnchor, constant: -GlanceTheme.Space.xs),

            checkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -GlanceTheme.Space.sm),
            checkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 14),
            checkView.heightAnchor.constraint(equalToConstant: 14)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(action.title)
        setAccessibilityHelp(QuickCaptureActionPresentation.destinationLabel(for: action))
        setAccessibilityIdentifier(action.identifier)
    }

    private func applyChrome() {
        let fill: NSColor
        if selected {
            fill = GlanceTheme.Fill.rowSelected
        } else if isHovered {
            fill = GlanceTheme.Fill.rowHover
        } else {
            fill = .clear
        }
        layer?.backgroundColor = fill.cgColor
        iconView.contentTintColor = selected ? .controlAccentColor : .secondaryLabelColor
        checkView.contentTintColor = .controlAccentColor
        checkView.isHidden = !selected
        titleLabel.textColor = .labelColor
        destinationLabel.textColor = .tertiaryLabelColor
        setAccessibilityValue(selected ? QuickCaptureCopy.selectedAccessibilityValue : nil)
    }
}
