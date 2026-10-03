import Foundation

enum ShortcutRuntimeIssue: Equatable {
    case conflictsWithExplicit(ShortcutAction)
    case conflictsWithActive(ShortcutAction)
    case customRegistrationFailedUsingDefault
    case registrationFailed

    var settingsCaption: String {
        switch self {
        case .conflictsWithExplicit(let other), .conflictsWithActive(let other):
            return "⚠ 与“\(other.title)”的快捷键冲突，当前未生效"
        case .customRegistrationFailedUsingDefault:
            return "自定义快捷键无法注册，本次运行暂时使用默认快捷键。"
        case .registrationFailed:
            return "⚠ 当前未生效"
        }
    }

    func diagnosticMessage(for action: ShortcutAction, configuredIsExplicit: Bool) -> String {
        switch self {
        case .conflictsWithExplicit(let other), .conflictsWithActive(let other):
            if configuredIsExplicit {
                return "“\(action.title)”的快捷键与“\(other.title)”的已有快捷键冲突，当前未生效。可在设置中重新指定。"
            }
            return "“\(action.title)”的默认快捷键与“\(other.title)”的已有快捷键冲突，当前未生效。可在设置中重新指定。"
        case .customRegistrationFailedUsingDefault:
            return "“\(action.title)”的自定义快捷键无法注册，本次运行暂时使用默认快捷键。"
        case .registrationFailed:
            return "“\(action.title)”的快捷键当前未能注册。"
        }
    }
}

enum ShortcutCollisionResolver {
    static func conflictingAction(
        for shortcut: GlanceShortcut,
        excluding action: ShortcutAction? = nil,
        among reservations: [ShortcutAction: GlanceShortcut],
        order: [ShortcutAction] = Array(ShortcutAction.allCases)
    ) -> ShortcutAction? {
        order.first { candidate in
            if let action, candidate == action { return false }
            return reservations[candidate] == shortcut
        }
    }
}

struct ShortcutStartupPlan: Equatable {
    var explicitOwners: [ShortcutAction: GlanceShortcut]
    var explicitConflicts: [ShortcutAction: ShortcutAction]
    var implicitAttempts: [ShortcutAction: GlanceShortcut]
    var implicitConflicts: [ShortcutAction: ShortcutAction]
}

enum ShortcutRegistrationPlanner {
    static func plan(
        explicit: [ShortcutAction: GlanceShortcut],
        defaults: [ShortcutAction: GlanceShortcut] = ShortcutDefaults.all,
        order: [ShortcutAction] = Array(ShortcutAction.allCases)
    ) -> ShortcutStartupPlan {
        var owners: [GlanceShortcut: ShortcutAction] = [:]
        var explicitOwners: [ShortcutAction: GlanceShortcut] = [:]
        var explicitConflicts: [ShortcutAction: ShortcutAction] = [:]

        for action in order {
            guard let shortcut = explicit[action] else { continue }
            if let existing = owners[shortcut] {
                explicitConflicts[action] = existing
            } else {
                owners[shortcut] = action
                explicitOwners[action] = shortcut
            }
        }

        var implicitAttempts: [ShortcutAction: GlanceShortcut] = [:]
        var implicitConflicts: [ShortcutAction: ShortcutAction] = [:]
        for action in order {
            if explicit[action] != nil { continue }
            let shortcut = defaults[action] ?? ShortcutDefaults.shortcut(for: action)
            if let winner = owners[shortcut] {
                implicitConflicts[action] = winner
            } else {
                implicitAttempts[action] = shortcut
            }
        }

        return ShortcutStartupPlan(
            explicitOwners: explicitOwners,
            explicitConflicts: explicitConflicts,
            implicitAttempts: implicitAttempts,
            implicitConflicts: implicitConflicts
        )
    }
}
