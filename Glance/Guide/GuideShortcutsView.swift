import SwiftUI

struct GuideShortcutsView: View {
    var shortcutProvider: (ShortcutAction) -> GlanceShortcut
    var onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GlanceTheme.Space.xl) {
                GuideSectionHeader(
                    title: "快捷键与操作",
                    detail: "包含可修改的全局快捷键，以及面板上的鼠标和修饰键操作。"
                )
                ForEach(GuideShortcutCatalog.groups) { group in
                    VStack(alignment: .leading, spacing: GlanceTheme.Space.xs) {
                        Text(group.title)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            ForEach(group.items) { item in
                                ShortcutRow(item: item, shortcutProvider: shortcutProvider)
                                if item.id != group.items.last?.id {
                                    Divider()
                                }
                            }
                        }
                        if group.id == "global" {
                            Button(GlanceGuideEntry.openSettingsTitle, action: onOpenSettings)
                                .padding(.top, GlanceTheme.Space.sm)
                        }
                    }
                }
            }
            .padding(GlanceTheme.Space.xl)
        }
    }
}
