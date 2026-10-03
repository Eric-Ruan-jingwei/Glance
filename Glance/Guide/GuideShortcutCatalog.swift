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

enum GuideShortcutResolution: Equatable {
    case active(GlanceShortcut)
    case inactive
}

struct GuideShortcutItem: Equatable, Identifiable {
    static let inactiveShortcutDetail = "快捷键与已有设置冲突，可在设置中重新指定。"

    var id: String
    var title: String
    var detail: String?
    var source: GuideShortcutSource

    func tokens(using provider: (ShortcutAction) -> GlanceShortcut) -> [GuideKeycap] {
        tokens(resolvedBy: { action in .active(provider(action)) })
    }

    func tokens(resolvedBy resolution: (ShortcutAction) -> GuideShortcutResolution) -> [GuideKeycap] {
        switch source {
        case .dynamic(let action):
            switch resolution(action) {
            case .active(let shortcut):
                return GuideKeycap.tokens(from: shortcut)
            case .inactive:
                return [.gesture("未生效")]
            }
        case .keys(let keys):
            return keys
        case .mouseGesture(let label):
            return [.gesture(label)]
        case .modifierGesture(let key):
            return [key]
        }
    }

    func resolvedDetail(using provider: (ShortcutAction) -> GlanceShortcut) -> String? {
        resolvedDetail(resolvedBy: { action in .active(provider(action)) })
    }

    func resolvedDetail(resolvedBy resolution: (ShortcutAction) -> GuideShortcutResolution) -> String? {
        if case .dynamic(let action) = source, case .inactive = resolution(action) {
            return Self.inactiveShortcutDetail
        }
        return detail
    }

    func accessibilityLabel(using provider: (ShortcutAction) -> GlanceShortcut) -> String {
        accessibilityLabel(resolvedBy: { action in .active(provider(action)) })
    }

    func accessibilityLabel(resolvedBy resolution: (ShortcutAction) -> GuideShortcutResolution) -> String {
        var parts = [title]
        if let detail = resolvedDetail(resolvedBy: resolution), !detail.isEmpty {
            parts.append(detail)
        }
        switch source {
        case .dynamic(let action):
            switch resolution(action) {
            case .inactive:
                parts.append("未生效")
            case .active(let shortcut):
                parts.append("快捷键 \(ShortcutDisplayFormatter.spoken(shortcut))")
            }
        case .mouseGesture:
            let spoken = tokens(resolvedBy: resolution).map(\.spoken).joined(separator: " ")
            parts.append(spoken)
        default:
            let spoken = tokens(resolvedBy: resolution).map(\.spoken).joined(separator: " ")
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
    static func item(id: String) -> GuideShortcutItem? {
        groups.flatMap(\.items).first { $0.id == id }
    }

    static var groups: [GuideShortcutGroup] {
        [
            GuideShortcutGroup(id: "global", title: "全局", items: global),
            GuideShortcutGroup(id: "globalSearch", title: "全局搜索", items: globalSearch),
            GuideShortcutGroup(id: "panel", title: "面板操作", items: panel),
            GuideShortcutGroup(id: "quickCapture", title: "Quick Capture", items: quickCapture),
            GuideShortcutGroup(id: "clipboard", title: "剪贴板", items: clipboard),
            GuideShortcutGroup(id: "fileShelf", title: "文件架", items: fileShelf),
            GuideShortcutGroup(id: "snippets", title: "片段库", items: snippets),
            GuideShortcutGroup(id: "links", title: "链接库", items: links),
            GuideShortcutGroup(id: "editing", title: "编辑", items: editing),
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
            id: "globalSearch",
            title: ShortcutAction.globalSearch.title,
            detail: nil,
            source: .dynamic(.globalSearch)
        ),
        GuideShortcutItem(
            id: "clipboardHistory",
            title: ShortcutAction.clipboardHistory.title,
            detail: nil,
            source: .dynamic(.clipboardHistory)
        ),
        GuideShortcutItem(
            id: "fileShelf",
            title: ShortcutAction.fileShelf.title,
            detail: nil,
            source: .dynamic(.fileShelf)
        ),
        GuideShortcutItem(
            id: "snippets",
            title: ShortcutAction.snippets.title,
            detail: nil,
            source: .dynamic(.snippets)
        ),
        GuideShortcutItem(
            id: "links",
            title: ShortcutAction.links.title,
            detail: nil,
            source: .dynamic(.links)
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

    static let globalSearch: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "globalSearchPrevious",
            title: "选择上一个",
            detail: nil,
            source: .keys([.character("↑")])
        ),
        GuideShortcutItem(
            id: "globalSearchNext",
            title: "选择下一个",
            detail: nil,
            source: .keys([.character("↓")])
        ),
        GuideShortcutItem(
            id: "globalSearchActivate",
            title: "执行结果",
            detail: nil,
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "globalSearchCancel",
            title: "关闭",
            detail: nil,
            source: .keys([.escape])
        )
    ]

    static let panel: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "editTextMarkdown",
            title: "编辑文字 / Markdown",
            detail: nil,
            source: .mouseGesture("单击内容")
        ),
        GuideShortcutItem(
            id: "editTodo",
            title: "编辑待办",
            detail: nil,
            source: .mouseGesture("双击待办项")
        ),
        GuideShortcutItem(
            id: "textChecklistToggle",
            title: "切换文字清单",
            detail: "点击圆圈，用删除线标记完成",
            source: .mouseGesture("单击清单符号")
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
            title: "取消 Quick Capture",
            detail: nil,
            source: .keys([.escape])
        )
    ]

    static let clipboard: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "clipboardReuse",
            title: "写回系统剪贴板",
            detail: "关闭窗口后，在原 App 中自行粘贴",
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "clipboardCreatePanel",
            title: "从历史创建面板",
            detail: nil,
            source: .keys([.command, .enter])
        ),
        GuideShortcutItem(
            id: "clipboardRecentTab",
            title: "最近",
            detail: nil,
            source: .keys([.command, .character("1")])
        ),
        GuideShortcutItem(
            id: "clipboardFavoriteTab",
            title: "收藏",
            detail: nil,
            source: .keys([.command, .character("2")])
        ),
        GuideShortcutItem(
            id: "clipboardCancel",
            title: "关闭剪贴板",
            detail: nil,
            source: .keys([.escape])
        )
    ]

    static let fileShelf: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "fileShelfOpen",
            title: "打开文件",
            detail: nil,
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "fileShelfReveal",
            title: "在 Finder 中显示",
            detail: nil,
            source: .keys([.command, .enter])
        ),
        GuideShortcutItem(
            id: "fileShelfPreview",
            title: "快速预览",
            detail: nil,
            source: .keys([.character("Space")])
        ),
        GuideShortcutItem(
            id: "fileShelfCopy",
            title: "复制文件",
            detail: nil,
            source: .keys([.command, .character("C")])
        ),
        GuideShortcutItem(
            id: "fileShelfRemove",
            title: "从文件架移除",
            detail: nil,
            source: .keys([.character("Delete")])
        ),
        GuideShortcutItem(
            id: "fileShelfRecentTab",
            title: "最近",
            detail: nil,
            source: .keys([.command, .character("1")])
        ),
        GuideShortcutItem(
            id: "fileShelfFavoriteTab",
            title: "收藏",
            detail: nil,
            source: .keys([.command, .character("2")])
        ),
        GuideShortcutItem(
            id: "fileShelfCancel",
            title: "关闭文件架",
            detail: nil,
            source: .keys([.escape])
        )
    ]

    static let snippets: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "snippetCopy",
            title: "复制片段",
            detail: nil,
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "snippetEdit",
            title: "编辑片段",
            detail: nil,
            source: .keys([.command, .enter])
        ),
        GuideShortcutItem(
            id: "snippetCreate",
            title: "新建片段",
            detail: nil,
            source: .keys([.command, .character("N")])
        ),
        GuideShortcutItem(
            id: "snippetDelete",
            title: "删除片段",
            detail: nil,
            source: .keys([.character("Delete")])
        ),
        GuideShortcutItem(
            id: "snippetCancel",
            title: "关闭片段库",
            detail: nil,
            source: .keys([.escape])
        )
    ]

    static let links: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "linkOpen",
            title: "打开链接",
            detail: nil,
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "linkEdit",
            title: "编辑链接",
            detail: nil,
            source: .keys([.command, .enter])
        ),
        GuideShortcutItem(
            id: "linkCreate",
            title: "新建链接",
            detail: nil,
            source: .keys([.command, .character("N")])
        ),
        GuideShortcutItem(
            id: "linkCopy",
            title: "复制链接",
            detail: nil,
            source: .keys([.command, .character("C")])
        ),
        GuideShortcutItem(
            id: "linkDelete",
            title: "删除链接",
            detail: nil,
            source: .keys([.character("Delete")])
        ),
        GuideShortcutItem(
            id: "linkCancel",
            title: "关闭链接库",
            detail: nil,
            source: .keys([.escape])
        )
    ]

    static let editing: [GuideShortcutItem] = [
        GuideShortcutItem(
            id: "bold",
            title: "粗体",
            detail: nil,
            source: .keys([.command, .character("B")])
        ),
        GuideShortcutItem(
            id: "textEndEditing",
            title: "结束文字编辑",
            detail: nil,
            source: .keys([.escape])
        ),
        GuideShortcutItem(
            id: "markdownEndEditing",
            title: "结束 Markdown 编辑",
            detail: nil,
            source: .keys([.escape])
        ),
        GuideShortcutItem(
            id: "todoCommit",
            title: "保存待办 / 继续添加",
            detail: "新增待办时，保存后继续创建下一项",
            source: .keys([.enter])
        ),
        GuideShortcutItem(
            id: "todoCancel",
            title: "取消待办编辑",
            detail: "恢复编辑前的内容",
            source: .keys([.escape])
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
