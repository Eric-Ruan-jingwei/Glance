import Combine
import Foundation

@MainActor
final class ShortcutCoordinator: ObservableObject {
    @Published private(set) var shortcuts: [ShortcutAction: GlanceShortcut]
    @Published var errorMessage: String?

    let store: ShortcutStore
    let manager: ShortcutManager

    init(store: ShortcutStore, manager: ShortcutManager) {
        self.store = store
        self.manager = manager
        self.shortcuts = store.all()
    }

    func start() {
        manager.installHandler()
        var diagnostics: [String] = []
        for action in ShortcutAction.allCases {
            let preferred = store.shortcut(for: action)
            if manager.register(preferred, for: action) {
                continue
            }
            let fallback = ShortcutDefaults.shortcut(for: action)
            if preferred != fallback, manager.register(fallback, for: action) {
                NSLog("Glance shortcuts: using default for %@ this session", action.rawValue)
                diagnostics.append("“\(action.title)”的自定义快捷键无法注册，本次运行暂时使用默认快捷键。")
                continue
            }
            NSLog("Glance shortcuts: %@ has no global hotkey this session", action.rawValue)
            diagnostics.append("“\(action.title)”的快捷键当前未能注册。")
        }
        publishActiveShortcuts()
        errorMessage = diagnostics.isEmpty ? nil : diagnostics.joined(separator: "\n")
    }

    func beginRecording(_ action: ShortcutAction) {
        errorMessage = nil
        for other in ShortcutAction.allCases where other != action && manager.isSuspended(other) {
            cancelRecording(other)
        }
        manager.suspend(action)
    }

    func cancelRecording(_ action: ShortcutAction) {
        do {
            try manager.resume(action)
        } catch {
            publishActiveShortcuts()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法恢复原来的快捷键。"
        }
    }

    func commitRecording(_ shortcut: GlanceShortcut, for action: ShortcutAction) {
        do {
            try apply(shortcut, for: action)
            manager.finishSuspension(action)
        } catch {
            do {
                try manager.resume(action)
            } catch {
                publishActiveShortcuts()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法设置这个快捷键。"
                return
            }
            publishActiveShortcuts()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法设置这个快捷键。"
        }
    }

    func apply(_ shortcut: GlanceShortcut, for action: ShortcutAction) throws {
        if let problem = ShortcutValidator.problem(with: shortcut) {
            throw problem
        }
        if let duplicate = ShortcutValidator.duplicate(of: shortcut, excluding: action, in: store.all()) {
            throw ShortcutError.duplicate(duplicate)
        }
        try manager.replaceShortcut(for: action, with: shortcut)
        store.setShortcut(shortcut, for: action)
        shortcuts[action] = shortcut
        errorMessage = nil
    }

    func resetAll() {
        errorMessage = nil
        var lastError: String?
        for action in ShortcutAction.allCases {
            let fallback = ShortcutDefaults.shortcut(for: action)
            do {
                try manager.replaceShortcut(for: action, with: fallback)
                store.resetShortcut(for: action)
                shortcuts[action] = fallback
            } catch {
                lastError = (error as? LocalizedError)?.errorDescription ?? "无法恢复默认快捷键。"
            }
        }
        errorMessage = lastError
    }

    func shortcut(for action: ShortcutAction) -> GlanceShortcut {
        shortcuts[action] ?? manager.registeredShortcut(for: action) ?? store.shortcut(for: action)
    }

    private func publishActiveShortcuts() {
        var active: [ShortcutAction: GlanceShortcut] = [:]
        for action in ShortcutAction.allCases {
            active[action] = manager.registeredShortcut(for: action) ?? store.shortcut(for: action)
        }
        shortcuts = active
    }
}
