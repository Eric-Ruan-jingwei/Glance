import SwiftUI

struct GuideFeaturesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GlanceTheme.Space.xl) {
                GuideSectionHeader(
                    title: "更多功能",
                    detail: "这些功能可以稍后使用。它们不是开始使用 Glance 的前提。"
                )
                ForEach(GuideFeatureCatalog.items, id: \.title) { item in
                    feature(title: item.title, symbol: item.symbol, body: item.body)
                }
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
