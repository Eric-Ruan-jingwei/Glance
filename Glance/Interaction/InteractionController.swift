import AppKit

enum InteractionMode {
    case normal
    case passThrough
}

/// Owns click-through so it never leaks into individual panel views.
/// While a panel is editing, the controller is told `passThrough: false` so
/// releasing Option cannot ignore mouse events mid-session.
@MainActor
final class InteractionController {
    private struct Entry {
        weak var window: NSWindow?
        var passThrough: Bool
    }

    private var entries: [ObjectIdentifier: Entry] = [:]
    private var timer: Timer?
    private var lastOption = false
    var onModifierChanged: (() -> Void)?

    func update(window: NSWindow, passThrough: Bool) {
        entries[ObjectIdentifier(window)] = Entry(window: window, passThrough: passThrough)
        prune()
        refreshTimer()
        apply(to: window, passThrough: passThrough)
    }

    func remove(window: NSWindow) {
        entries[ObjectIdentifier(window)] = nil
        window.ignoresMouseEvents = false
        prune()
        refreshTimer()
    }

    func shutdown() {
        stopTimer()
        for entry in entries.values {
            entry.window?.ignoresMouseEvents = false
        }
        entries.removeAll()
    }

    private func prune() {
        entries = entries.filter { $0.value.window != nil }
    }

    private var hasPassThrough: Bool {
        entries.values.contains { entry in
            entry.passThrough && entry.window != nil
        }
    }

    private func refreshTimer() {
        if hasPassThrough {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        lastOption = ModifierKeyController.optionIsPressed
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.pollModifier()
            }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func pollModifier() {
        let option = ModifierKeyController.optionIsPressed
        guard option != lastOption else { return }
        lastOption = option
        applyAll()
        onModifierChanged?()
    }

    private func applyAll() {
        prune()
        for entry in entries.values {
            guard let window = entry.window else { continue }
            apply(to: window, mode: entry.passThrough ? .passThrough : .normal)
        }
    }

    private func apply(to window: NSWindow, passThrough: Bool) {
        apply(to: window, mode: passThrough ? .passThrough : .normal)
    }

    private func apply(to window: NSWindow, mode: InteractionMode) {
        switch mode {
        case .normal:
            window.ignoresMouseEvents = false
        case .passThrough:
            window.ignoresMouseEvents = !ModifierKeyController.optionIsPressed
        }
    }
}
