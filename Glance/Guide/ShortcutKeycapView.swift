import SwiftUI

struct ShortcutKeycapView: View {
    var cap: GuideKeycap
    var prominent: Bool = false

    var body: some View {
        Text(cap.display)
            .font(.system(size: prominent ? 22 : 12, weight: .medium, design: .rounded))
            .padding(.horizontal, prominent ? 14 : 6)
            .padding(.vertical, prominent ? 8 : 3)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: prominent ? 8 : 5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: prominent ? 8 : 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

struct ShortcutDisplayView: View {
    var tokens: [GuideKeycap]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, cap in
                ShortcutKeycapView(cap: cap)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ShortcutRow: View {
    var item: GuideShortcutItem
    var shortcutProvider: (ShortcutAction) -> GlanceShortcut

    var body: some View {
        HStack(alignment: .center, spacing: GlanceTheme.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: GlanceTheme.Space.sm)
            ShortcutDisplayView(tokens: item.tokens(using: shortcutProvider))
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel(using: shortcutProvider))
    }
}

struct GuideInstructionRow: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: GlanceTheme.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: GlanceTheme.Radius.control, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.medium))
            Spacer(minLength: GlanceTheme.Space.sm)
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, GlanceTheme.Space.md)
        .padding(.vertical, GlanceTheme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: GlanceTheme.Radius.card, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(detail)")
    }
}

struct GuideSectionHeader: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.sm) {
            Text(title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
