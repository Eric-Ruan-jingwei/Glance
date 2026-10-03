import Foundation

enum ShortcutAction: String, CaseIterable, Equatable {
    case quickCapture
    case clipboardHistory
    case fileShelf
    case snippets
    case links
    case clipboardCapture
    case hideShow

    var title: String {
        switch self {
        case .quickCapture: return "快速记录"
        case .clipboardHistory: return "剪贴板"
        case .fileShelf: return "文件架"
        case .snippets: return "片段库"
        case .links: return "链接库"
        case .clipboardCapture: return "从当前剪贴板创建"
        case .hideShow: return "隐藏 / 显示全部"
        }
    }

    var preferenceKey: String {
        "com.glance.shortcut.\(rawValue)"
    }
}

struct GlanceShortcut: Codable, Equatable {
    var key: String
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool

    init(key: String, command: Bool, option: Bool, control: Bool, shift: Bool) {
        self.key = Self.canonicalizeKey(key)
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = Self.canonicalizeKey(try container.decodeIfPresent(String.self, forKey: .key) ?? "")
        command = try container.decodeIfPresent(Bool.self, forKey: .command) ?? false
        option = try container.decodeIfPresent(Bool.self, forKey: .option) ?? false
        control = try container.decodeIfPresent(Bool.self, forKey: .control) ?? false
        shift = try container.decodeIfPresent(Bool.self, forKey: .shift) ?? false
    }

    var canonicalKey: String { Self.canonicalizeKey(key) }

    var strongModifierCount: Int {
        [command, option, control].filter { $0 }.count
    }

    static func canonicalizeKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func == (lhs: GlanceShortcut, rhs: GlanceShortcut) -> Bool {
        lhs.canonicalKey == rhs.canonicalKey
            && lhs.command == rhs.command
            && lhs.option == rhs.option
            && lhs.control == rhs.control
            && lhs.shift == rhs.shift
    }
}

enum ShortcutDefaults {
    static let quickCapture = GlanceShortcut(
        key: "j",
        command: true,
        option: true,
        control: false,
        shift: false
    )
    static let clipboardHistory = GlanceShortcut(
        key: "v",
        command: true,
        option: true,
        control: false,
        shift: false
    )
    static let fileShelf = GlanceShortcut(
        key: "f",
        command: true,
        option: true,
        control: false,
        shift: false
    )
    static let snippets = GlanceShortcut(
        key: "s",
        command: true,
        option: true,
        control: false,
        shift: false
    )
    static let links = GlanceShortcut(
        key: "l",
        command: true,
        option: true,
        control: false,
        shift: false
    )
    static let clipboardCapture = GlanceShortcut(
        key: "b",
        command: true,
        option: true,
        control: false,
        shift: false
    )
    static let hideShow = GlanceShortcut(
        key: "g",
        command: true,
        option: true,
        control: false,
        shift: false
    )

    static func shortcut(for action: ShortcutAction) -> GlanceShortcut {
        switch action {
        case .quickCapture: return quickCapture
        case .clipboardHistory: return clipboardHistory
        case .fileShelf: return fileShelf
        case .snippets: return snippets
        case .links: return links
        case .clipboardCapture: return clipboardCapture
        case .hideShow: return hideShow
        }
    }

    static var all: [ShortcutAction: GlanceShortcut] {
        Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, shortcut(for: $0)) })
    }
}

enum ShortcutDisplayFormatter {
    static func display(_ shortcut: GlanceShortcut) -> String {
        tokens(shortcut).joined()
    }

    static func tokens(_ shortcut: GlanceShortcut) -> [String] {
        var result: [String] = []
        if shortcut.control { result.append("⌃") }
        if shortcut.option { result.append("⌥") }
        if shortcut.shift { result.append("⇧") }
        if shortcut.command { result.append("⌘") }
        result.append(shortcut.canonicalKey.uppercased())
        return result
    }

    static func spoken(_ shortcut: GlanceShortcut) -> String {
        var parts: [String] = []
        if shortcut.control { parts.append("Control") }
        if shortcut.option { parts.append("Option") }
        if shortcut.shift { parts.append("Shift") }
        if shortcut.command { parts.append("Command") }
        parts.append(shortcut.canonicalKey.uppercased())
        return parts.joined(separator: " ")
    }

    static func keyEquivalent(_ shortcut: GlanceShortcut) -> String {
        shortcut.canonicalKey
    }
}

enum ShortcutError: LocalizedError, Equatable {
    case invalidCombination
    case duplicate(ShortcutAction)
    case registrationFailed
    case unsupportedKey
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .invalidCombination:
            return "快捷键需要至少包含 Command、Control、Option 中的两个。"
        case .duplicate(let action):
            return "这个快捷键已经被 Glance 的“\(action.title)”使用。"
        case .registrationFailed:
            return "无法注册这个快捷键，可能已被系统或其他应用占用。"
        case .unsupportedKey:
            return "只支持字母和数字键。"
        case .restoreFailed:
            return "无法注册这个快捷键，原先的快捷键也未能恢复。"
        }
    }
}

enum ShortcutValidator {
    private static let supportedKeys = Set("abcdefghijklmnopqrstuvwxyz0123456789")
    private static let reservedCommandOnlyKeys: Set<String> = ["c", "v", "x", "z", "a", "s", "q", "w"]

    static func isSupportedKey(_ key: String) -> Bool {
        let canonical = GlanceShortcut.canonicalizeKey(key)
        return canonical.count == 1 && supportedKeys.contains(canonical)
    }

    static func problem(with shortcut: GlanceShortcut) -> ShortcutError? {
        guard isSupportedKey(shortcut.canonicalKey) else {
            return .unsupportedKey
        }
        if shortcut.strongModifierCount < 2 {
            return .invalidCombination
        }
        if isReserved(shortcut) {
            return .invalidCombination
        }
        return nil
    }

    static func duplicate(
        of shortcut: GlanceShortcut,
        excluding action: ShortcutAction,
        in shortcuts: [ShortcutAction: GlanceShortcut]
    ) -> ShortcutAction? {
        shortcuts.first { $0.key != action && $0.value == shortcut }?.key
    }

    private static func isReserved(_ shortcut: GlanceShortcut) -> Bool {
        shortcut.command
            && !shortcut.option
            && !shortcut.control
            && reservedCommandOnlyKeys.contains(shortcut.canonicalKey)
    }
}

enum ShortcutRecorderDecision: Equatable {
    case cancel
    case ignore
    case reject(ShortcutError)
    case capture(GlanceShortcut)
}

enum ShortcutRecorderInterpreter {
    static func interpret(
        escape: Bool,
        delete: Bool,
        key: String?,
        command: Bool,
        option: Bool,
        control: Bool,
        shift: Bool
    ) -> ShortcutRecorderDecision {
        if escape { return .cancel }
        if delete { return .ignore }
        guard let key else { return .ignore }
        guard ShortcutValidator.isSupportedKey(key) else {
            return .reject(.unsupportedKey)
        }
        let shortcut = GlanceShortcut(
            key: key,
            command: command,
            option: option,
            control: control,
            shift: shift
        )
        if let error = ShortcutValidator.problem(with: shortcut) {
            return .reject(error)
        }
        return .capture(shortcut)
    }
}
