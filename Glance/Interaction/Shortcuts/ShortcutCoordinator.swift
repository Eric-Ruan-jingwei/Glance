import Combine
import Foundation

@MainActor
final class ShortcutCoordinator: ObservableObject {
    /// Currently registered global shortcuts. Missing keys are inactive, not defaults.
    @Published private(set) var shortcuts: [ShortcutAction: GlanceShortcut]
    @Published private(set) var runtimeIssues: [ShortcutAction: ShortcutRuntimeIssue]
    @Published var errorMessage: String?

    let store: ShortcutStore
    let manager: ShortcutManager

    init(store: ShortcutStore, manager: ShortcutManager) {
        self.store = store
        self.manager = manager
        self.shortcuts = [:]
        self.runtimeIssues = [:]
    }

    func start() {
        manager.installHandler()
        manager.clearRegistrations()
        runtimeIssues = [:]

        let explicit = collectedExplicitShortcuts()
        let plan = ShortcutRegistrationPlanner.plan(explicit: explicit)

        for action in ShortcutAction.allCases {
            if let winner = plan.explicitConflicts[action] {
                runtimeIssues[action] = .conflictsWithExplicit(winner)
                continue
            }
            guard let preferred = plan.explicitOwners[action] else { continue }
            registerExplicit(preferred, for: action, reserved: plan.explicitOwners)
        }

        for action in ShortcutAction.allCases {
            if let winner = plan.implicitConflicts[action] {
                runtimeIssues[action] = .conflictsWithExplicit(winner)
                continue
            }
            guard let shortcut = plan.implicitAttempts[action] else { continue }
            registerImplicit(shortcut, for: action)
        }

        publishActiveShortcuts()
        errorMessage = joinedDiagnostics()
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
        runtimeIssues[action] = nil
        reconcileInactiveDefaults()
        publishActiveShortcuts()
        errorMessage = joinedDiagnostics()
    }

    func resetAll() {
        store.resetAll()
        start()
    }

    /// Configured shortcut: stored preference if valid, otherwise the action default.
    func configuredShortcut(for action: ShortcutAction) -> GlanceShortcut {
        store.shortcut(for: action)
    }

    func activeShortcut(for action: ShortcutAction) -> GlanceShortcut? {
        manager.registeredShortcut(for: action)
    }

    func runtimeIssue(for action: ShortcutAction) -> ShortcutRuntimeIssue? {
        runtimeIssues[action]
    }

    /// Configured shortcut. Does not mean the chord is registered this session.
    func shortcut(for action: ShortcutAction) -> GlanceShortcut {
        configuredShortcut(for: action)
    }

    func reconcileInactiveDefaults() {
        let explicit = collectedExplicitShortcuts()
        let plan = ShortcutRegistrationPlanner.plan(explicit: explicit)
        for action in ShortcutAction.allCases {
            guard manager.registeredShortcut(for: action) == nil else { continue }
            guard explicit[action] == nil else { continue }
            if let winner = plan.implicitConflicts[action] {
                runtimeIssues[action] = .conflictsWithExplicit(winner)
                continue
            }
            guard let shortcut = plan.implicitAttempts[action] else { continue }
            if registerImplicit(shortcut, for: action) {
                runtimeIssues[action] = nil
            }
        }
    }

    private func collectedExplicitShortcuts() -> [ShortcutAction: GlanceShortcut] {
        var explicit: [ShortcutAction: GlanceShortcut] = [:]
        for action in ShortcutAction.allCases {
            if let stored = store.explicitShortcut(for: action) {
                explicit[action] = stored
            }
        }
        return explicit
    }

    private func registerExplicit(
        _ preferred: GlanceShortcut,
        for action: ShortcutAction,
        reserved: [ShortcutAction: GlanceShortcut]
    ) {
        if manager.register(preferred, for: action) {
            return
        }
        let fallback = ShortcutDefaults.shortcut(for: action)
        if preferred == fallback {
            runtimeIssues[action] = .registrationFailed
            NSLog("Glance shortcuts: %@ has no global hotkey this session", action.rawValue)
            return
        }
        if let owner = ShortcutCollisionResolver.conflictingAction(
            for: fallback,
            excluding: action,
            among: reserved
        ) {
            runtimeIssues[action] = .conflictsWithExplicit(owner)
            NSLog("Glance shortcuts: %@ has no global hotkey this session", action.rawValue)
            return
        }
        if let owner = ShortcutCollisionResolver.conflictingAction(
            for: fallback,
            excluding: action,
            among: currentlyRegistered()
        ) {
            runtimeIssues[action] = .conflictsWithActive(owner)
            NSLog("Glance shortcuts: %@ has no global hotkey this session", action.rawValue)
            return
        }
        if manager.register(fallback, for: action) {
            runtimeIssues[action] = .customRegistrationFailedUsingDefault
            NSLog("Glance shortcuts: using default for %@ this session", action.rawValue)
            return
        }
        runtimeIssues[action] = .registrationFailed
        NSLog("Glance shortcuts: %@ has no global hotkey this session", action.rawValue)
    }

    @discardableResult
    private func registerImplicit(_ shortcut: GlanceShortcut, for action: ShortcutAction) -> Bool {
        if let owner = ShortcutCollisionResolver.conflictingAction(
            for: shortcut,
            excluding: action,
            among: currentlyRegistered()
        ) {
            runtimeIssues[action] = .conflictsWithActive(owner)
            return false
        }
        if manager.register(shortcut, for: action) {
            return true
        }
        runtimeIssues[action] = .registrationFailed
        NSLog("Glance shortcuts: %@ has no global hotkey this session", action.rawValue)
        return false
    }

    private func currentlyRegistered() -> [ShortcutAction: GlanceShortcut] {
        var registered: [ShortcutAction: GlanceShortcut] = [:]
        for action in ShortcutAction.allCases {
            if let shortcut = manager.registeredShortcut(for: action) {
                registered[action] = shortcut
            }
        }
        return registered
    }

    private func publishActiveShortcuts() {
        var active: [ShortcutAction: GlanceShortcut] = [:]
        for action in ShortcutAction.allCases {
            if let registered = manager.registeredShortcut(for: action) {
                active[action] = registered
            }
        }
        shortcuts = active
    }

    private func joinedDiagnostics() -> String? {
        let messages = ShortcutAction.allCases.compactMap { action -> String? in
            guard let issue = runtimeIssues[action] else { return nil }
            return issue.diagnosticMessage(
                for: action,
                configuredIsExplicit: store.explicitShortcut(for: action) != nil
            )
        }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}
