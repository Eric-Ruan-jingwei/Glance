import SwiftUI

struct GlanceShortcutHint: View {
    var keys: [String]
    var label: String

    var body: some View {
        HStack(spacing: GlanceTheme.Space.xs) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(nsColor: .quaternarySystemFill))
                    )
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(keys: keys, label: label))
    }

    static func accessibilityLabel(keys: [String], label: String) -> String {
        let spoken = keys.map(spokenKey).joined(separator: " ")
        return "\(spoken)，\(label)"
    }

    static func spokenKey(_ key: String) -> String {
        switch key {
        case "↩": return "回车"
        case "⌘↩": return "Command 回车"
        case "⌘N": return "Command N"
        case "Esc": return "Escape"
        case "↑↓": return "上下方向键"
        case "Space": return "空格"
        default: return key
        }
    }
}

enum GlanceShortcutHintBar {
    static var spacing: CGFloat { GlanceTheme.Space.shortcutHint }
}

struct GlanceShortcutFooterHint: Equatable {
    var keys: [String]
    var label: String
}

enum GlanceShortcutFooter {
    static let clipboard: [GlanceShortcutFooterHint] = [
        .init(keys: ["↩"], label: "复制"),
        .init(keys: ["⌘↩"], label: "创建面板"),
        .init(keys: ["Esc"], label: "关闭")
    ]

    static let fileShelf: [GlanceShortcutFooterHint] = [
        .init(keys: ["↩"], label: "打开"),
        .init(keys: ["⌘↩"], label: "在 Finder 中显示"),
        .init(keys: ["Space"], label: "预览"),
        .init(keys: ["Esc"], label: "关闭")
    ]

    static let snippet: [GlanceShortcutFooterHint] = [
        .init(keys: ["↩"], label: "复制"),
        .init(keys: ["⌘↩"], label: "编辑"),
        .init(keys: ["⌘N"], label: "新建"),
        .init(keys: ["Esc"], label: "关闭")
    ]

    static let link: [GlanceShortcutFooterHint] = [
        .init(keys: ["↩"], label: "打开"),
        .init(keys: ["⌘↩"], label: "编辑"),
        .init(keys: ["⌘N"], label: "新建"),
        .init(keys: ["Esc"], label: "关闭")
    ]

    static let globalSearch: [GlanceShortcutFooterHint] = [
        .init(keys: ["↑↓"], label: "选择"),
        .init(keys: ["↩"], label: "执行"),
        .init(keys: ["⌘↩"], label: "在来源中显示"),
        .init(keys: ["Esc"], label: "关闭")
    ]
}
