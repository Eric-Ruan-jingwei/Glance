import SwiftUI

struct GuideGettingStartedPage: View {
    var step: Int
    var shortcutProvider: (ShortcutAction) -> GlanceShortcut

    var body: some View {
        switch step {
        case 0:
            whatIsGlance
        case 1:
            usingPanels
        case 2:
            clickThrough
        default:
            callGlance
        }
    }

    private var whatIsGlance: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.lg) {
            GuideSectionHeader(
                title: "把重要的东西留在眼前",
                detail: "Glance 可以把文字、待办、图片和 PDF 固定在桌面上。即使你切换到其他 App，它们也能继续留在眼前。"
            )
            HStack(spacing: GlanceTheme.Space.md) {
                miniPanel("文字", PanelKindSymbol.name(for: PanelKind.text))
                miniPanel("待办", PanelKindSymbol.name(for: PanelKind.todo))
                miniPanel("图片", PanelKindSymbol.name(for: PanelKind.image))
                miniPanel("PDF", PanelKindSymbol.name(for: PanelKind.pdf))
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("文字、待办、图片和 PDF 面板")
        }
    }

    private var usingPanels: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.lg) {
            GuideSectionHeader(
                title: "像桌面便签一样使用",
                detail: "先记住这三个动作，就足够开始用 Glance。"
            )
            VStack(spacing: GlanceTheme.Space.sm) {
                GuideInstructionRow(symbol: "arrow.up.and.down.and.arrow.left.and.right", title: "拖动顶部", detail: "移动面板")
                GuideInstructionRow(symbol: "character.cursor.ibeam", title: "单击文字", detail: "编辑内容")
                GuideInstructionRow(symbol: "rectangle.split.2x1", title: "拖到屏幕边缘", detail: "自动吸附")
            }
        }
    }

    private var clickThrough: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.lg) {
            GuideSectionHeader(
                title: "让鼠标穿过面板",
                detail: "开启「点击穿透」后，鼠标点击会直接作用到面板后面的窗口。面板仍然可见，只是点击会穿过它。"
            )
            VStack(alignment: .leading, spacing: GlanceTheme.Space.md) {
                HStack(spacing: GlanceTheme.Space.md) {
                    ShortcutKeycapView(cap: .option, prominent: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("按住 Option")
                            .font(.title3.weight(.semibold))
                        Text("临时恢复面板交互")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("只在按住期间生效。松开后，点击穿透会回到原来的状态，不会永久关闭。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(GlanceTheme.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: GlanceTheme.Radius.card, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("按住 Option，临时恢复面板交互。只在按住期间生效，松开后点击穿透会回到原来的状态。")
        }
    }

    private var callGlance: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.lg) {
            GuideSectionHeader(
                title: "不必先找到 Glance",
                detail: "三个全局快捷键可以随时叫出 Glance。如果之后改过设置，这里会显示你当前的快捷键。"
            )
            VStack(spacing: 0) {
                ForEach(GuideShortcutCatalog.global) { item in
                    ShortcutRow(item: item, shortcutProvider: shortcutProvider)
                    if item.id != GuideShortcutCatalog.global.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func miniPanel(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: GlanceTheme.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 36)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GlanceTheme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: GlanceTheme.Radius.card, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: GlanceTheme.Radius.card, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct GuideGettingStartedView: View {
    var shortcutProvider: (ShortcutAction) -> GlanceShortcut
    var paginated: Bool
    var step: Int = 0

    var body: some View {
        if paginated {
            GuideGettingStartedPage(step: step, shortcutProvider: shortcutProvider)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: GlanceTheme.Space.xl) {
                    ForEach(0..<GuideModel.onboardingPageCount, id: \.self) { index in
                        GuideGettingStartedPage(step: index, shortcutProvider: shortcutProvider)
                        if index < GuideModel.onboardingPageCount - 1 {
                            Divider()
                        }
                    }
                }
                .padding(GlanceTheme.Space.xl)
            }
        }
    }
}
