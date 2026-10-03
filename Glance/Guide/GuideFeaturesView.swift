import SwiftUI

struct GuideFeaturesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GlanceTheme.Space.xl) {
                GuideSectionHeader(
                    title: "更多功能",
                    detail: "这些功能可以稍后使用。它们不是开始使用 Glance 的前提。"
                )
                feature(
                    title: "Workspaces",
                    symbol: "square.on.square",
                    body: "一个面板只属于一个工作区。切换工作区时，只显示当前工作区中的面板。适合把工作、学习、项目等不同上下文分开。"
                )
                feature(
                    title: "Tags",
                    symbol: "tag",
                    body: "一个面板可以拥有多个标签。标签用于搜索和筛选，不会影响面板是否显示。工作区决定当前能看见哪些面板；标签只负责整理和查找。"
                )
                feature(
                    title: "Panel Manager",
                    symbol: "square.stack",
                    body: "Panel Manager 用于集中搜索、筛选和整理已有面板。可以搜索、按类型筛选、移动工作区、批量隐藏或显示，以及批量编辑标签。"
                )
            }
            .padding(GlanceTheme.Space.xl)
        }
    }

    private func feature(title: String, symbol: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.sm) {
            HStack(spacing: GlanceTheme.Space.sm) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
