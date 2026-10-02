import SwiftUI

struct SettingsView: View {
    var dataFolderURL: URL
    var onRevealData: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Glance")
                        .font(.title2.weight(.semibold))
                    Text(GlanceConstants.slogan)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            Text("A lightweight, local-first floating panel app for macOS.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                labeled("版本", GlanceConstants.version)
                labeled("数据", dataFolderURL.path)
            }

            HStack {
                Button("打开数据文件夹", action: onRevealData)
                Spacer()
            }

            Text("开机启动、点击穿透、透明度等能力会在 V0.2 加入。")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 440)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
