import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    var shortcut: GlanceShortcut
    var isRecording: Bool
    var onBegin: () -> Void
    var onDecision: (ShortcutRecorderDecision) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onBegin = onBegin
        view.onDecision = onDecision
        view.apply(shortcut: shortcut, isRecording: isRecording)
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.onBegin = onBegin
        nsView.onDecision = onDecision
        nsView.apply(shortcut: shortcut, isRecording: isRecording)
    }
}

final class ShortcutRecorderNSView: NSView {
    var onBegin: (() -> Void)?
    var onDecision: ((ShortcutRecorderDecision) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = GlanceTheme.Radius.control
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1

        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyChrome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 148, height: 28)
    }

    override var acceptsFirstResponder: Bool { true }

    func apply(shortcut: GlanceShortcut, isRecording: Bool) {
        self.isRecording = isRecording
        label.stringValue = isRecording ? "请按新的快捷键…" : ShortcutDisplayFormatter.display(shortcut)
        applyChrome()
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onBegin?()
    }

    override func keyDown(with event: NSEvent) {
        handle(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        handle(event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            onDecision?(.cancel)
        }
        return true
    }

    private func handle(_ event: NSEvent) {
        guard isRecording else { return }
        let modifiers = MacShortcutAdapter.modifiers(from: event)
        let decision = ShortcutRecorderInterpreter.interpret(
            escape: MacShortcutAdapter.isEscape(event),
            delete: MacShortcutAdapter.isDelete(event),
            key: MacShortcutAdapter.key(from: event),
            command: modifiers.command,
            option: modifiers.option,
            control: modifiers.control,
            shift: modifiers.shift
        )
        switch decision {
        case .ignore:
            break
        case .cancel, .capture:
            isRecording = false
            onDecision?(decision)
        case .reject:
            onDecision?(decision)
        }
    }

    private func applyChrome() {
        let border = NSColor.separatorColor.cgColor
        layer?.borderColor = isRecording ? NSColor.controlAccentColor.cgColor : border
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        label.textColor = isRecording ? .secondaryLabelColor : .labelColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
    }
}
