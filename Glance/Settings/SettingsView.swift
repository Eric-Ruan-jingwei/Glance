import SwiftUI

struct SettingsView: View {
    var dataFolderURL: URL
    var versionText: String
    var onRevealData: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

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

            GroupBox("通用") {
                Toggle("开机自动启动 Glance", isOn: launchBinding)
                    .toggleStyle(.switch)
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            GroupBox("快捷键") {
                HStack {
                    Text("隐藏 / 显示全部")
                    Spacer()
                    Text("⌥⌘H")
                        .foregroundStyle(.secondary)
                        .font(.body.monospaced())
                }
            }

            GroupBox("数据") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本地数据位置")
                    Text(displayPath(dataFolderURL))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button("打开数据文件夹", action: onRevealData)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(versionText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 440)
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                    launchError = nil
                } catch {
                    launchAtLogin = LaunchAtLogin.isEnabled
                    launchError = error.localizedDescription
                }
            }
        )
    }

    private func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix(home) {
            return "~" + url.path.dropFirst(home.count)
        }
        return url.path
    }
}
