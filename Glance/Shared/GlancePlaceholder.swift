import AppKit

enum GlanceEmptyCopy {
    static let workspaceTitle = "这个工作区还是空的"
    static let workspaceDetail = "新建一个面板，开始使用这个工作区。"
    static let searchTitle = "没有找到匹配的面板"
    static let searchDetail = "试试其他关键词。"
    static let filterTitle = "没有符合筛选条件的面板"
    static let filterDetail = "调整类型或标签筛选后再试。"
    static let loadingTitle = "正在读取面板"
    static let imageEmptyTitle = "还没有图片"
    static let imageEmptyDetail = "拖入、粘贴，或右键导入。"
    static let imageUnreadableTitle = "无法显示这张图片"
    static let imageUnreadableDetail = "原文件还在数据目录里。"
    static let pdfEmptyTitle = "还没有 PDF"
    static let pdfEmptyDetail = "从菜单栏导入一份文档。"
    static let pdfUnreadableTitle = "无法显示这份 PDF"
    static let pdfUnreadableDetail = "原文件还在数据目录里。"
    static let quickCapturePlaceholder = "记录点什么…"
    static let textPlaceholder = "单击编辑"
    static let markdownPlaceholder = "单击编辑 Markdown"
    static let todoPlaceholder = "添加你的第一项待办"
}

enum GlancePromptField {
    static func make(width: CGFloat = 280, placeholder: String = "", value: String = "") -> NSTextField {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: width, height: GlanceTheme.Size.controlHeight))
        field.placeholderString = placeholder
        field.stringValue = value
        field.font = GlanceTheme.Typography.body
        field.bezelStyle = .roundedBezel
        field.isBezeled = true
        field.drawsBackground = true
        field.focusRingType = .default
        return field
    }
}

final class GlanceClickThroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class GlanceMessagePlaceholder: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .tertiaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = GlanceTheme.Typography.bodyEmphasized
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center

        detailLabel.font = GlanceTheme.Typography.secondary
        detailLabel.textColor = .tertiaryLabelColor
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 3

        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = GlanceTheme.Space.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(detailLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: GlanceTheme.Space.lg),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -GlanceTheme.Space.lg)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(symbol: String, title: String, detail: String) {
        iconView.image = GlanceTheme.symbol(symbol, pointSize: 22)
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
        detailLabel.isHidden = detail.isEmpty
    }
}
