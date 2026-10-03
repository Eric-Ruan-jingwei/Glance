import Foundation

enum GuideKeycap: Equatable {
    case control
    case option
    case shift
    case command
    case character(String)
    case enter
    case escape
    case gesture(String)

    var display: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        case .character(let value): return value
        case .enter: return "↩"
        case .escape: return "Esc"
        case .gesture(let value): return value
        }
    }

    var spoken: String {
        switch self {
        case .control: return "Control"
        case .option: return "Option"
        case .shift: return "Shift"
        case .command: return "Command"
        case .character(let value): return value
        case .enter: return "Return"
        case .escape: return "Escape"
        case .gesture(let value): return value
        }
    }

    static func tokens(from shortcut: GlanceShortcut) -> [GuideKeycap] {
        ShortcutDisplayFormatter.tokens(shortcut).map { token in
            switch token {
            case "⌃": return .control
            case "⌥": return .option
            case "⇧": return .shift
            case "⌘": return .command
            default: return .character(token)
            }
        }
    }
}

enum GuideShortcutSource: Equatable {
    case dynamic(ShortcutAction)
    case keys([GuideKeycap])
    case mouseGesture(String)
    case modifierGesture(GuideKeycap)
}

struct GuideShortcutItem: Equatable, Identifiable {
    var id: String
    var title: String
    var detail: String?
    var source: GuideShortcutSource

    func tokens(using provider: (ShortcutAction) -> GlanceShortcut) -> [GuideKeycap] {
        switch source {
        case .dynamic(let action):
            return GuideKeycap.tokens(from: provider(action))
        case .keys(let keys):
            return keys
        case .mouseGesture(let label):
            return [.gesture(label)]
        case .modifierGesture(let key):
            return [key]
        }
    }

    func accessibilityLabel(using provider: (ShortcutAction) -> GlanceShortcut) -> String {
        let spoken = tokens(using: provider).map(\.spoken).joined(separator: " ")
        var parts = [title]
        if let detail, !detail.isEmpty {
            parts.append(detail)
        }
        switch source {
        case .mouseGesture:
            parts.append(spoken)
        default:
            parts.append("快捷键 \(spoken)")
        }
        return parts.joined(separator: "，")
    }
}

struct GuideShortcutGroup: Equatable, Identifiable {
    var id: String
    var title: String
    var items: [GuideShortcutItem]
}

enum GuideShortcutCatalog {
    static var groups: [GuideShortcutGroup] {
        [
            GuideShortcutGroup(id: "global", title: "全局", items: global),
            GuideShortcutGroup(id: "panel", title: "面板操作", items: panel),
            GuideShortcutGroup(id: "quickCapture", title: "Quick Capture", items: quickCapture),
            GuideShortcutGroup(id: "text", title: "文字编辑", items: textEditing),
            GuideShortcutGroup(id: "dialogs", title: "弹窗", items: dialogs)
        ]
    }

    static let global: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "quickCapture",
            title: ShortcutAction.quickCapture.title,
            detail: nil,
            source: .dynamic(.quickCapture)
        ),
        GuideShortcutItem(
            id: "clipboardCapture",
            title: ShortcutAction.clipboardCapture.title,
            detail: nil,
            source: .dynamic(.clipboardCapture)
        ),
        GuideShortcutItem(
            id: "hideShow",
            title: ShortcutAction.hideShow.title,
            detail: nil,
            source: .dynamic(.hideShow)
        )
    ]

    static let panel: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "editText",
            title: "编辑文字",
            detail: nil,
            source: .mouseGesture("双击")
        ),
        GuideShortcutItem(
            id: "optionPassThrough",
            title: "临时操作穿透面板",
            detail: "仅在开启点击穿透时生效。按住期间可点击面板，松开后恢复穿透。",
            source: .modifierGesture(.option)
        ),
        GuideShortcutItem(
            id: "controlSnapBypass",
            title: "拖动时忽略吸附",
            detail: "拖动面板时按住 Control，可暂时关闭边缘吸附。",
            source: .modifierGesture(.control)
        )
    ]

    static let quickCapture: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "qcText",
            title: "文字模式",
            detail: nil,
            source: .keys([.command, .character("1")])
        ),
        GuideShortcutItem(
            id: "qcTodo",
            title: "待办模式",
            detail: nil,
            source: .keys([.command, .character("2")])
        ),
        GuideShortcutItem(
            id: "qcCreate",
            title: "创建",
            detail: nil,
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "qcNewline",
            title: "换行",
            detail: "文字模式下换行",
            source: .keys([.shift, .enter])
        ),
        GuideShortcutItem(
            id: "qcCancel",
            title: "取消",
            detail: nil,
            source: .keys([.escape])
        )
    ]

    static let textEditing: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "bold",
            title: "粗体",
            detail: nil,
            source: .keys([.command, .character("B")])
        )
    ]

    static let dialogs: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "confirm",
            title: "确认",
            detail: "大多数 Glance 弹窗",
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "cancel",
            title: "取消",
            detail: "大多数 Glance 弹窗",
            source: .keys([.escape])
        )
    ]
}
