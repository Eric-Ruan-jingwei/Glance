import SwiftUI

struct SettingsView: View {
    var dataFolderURL: URL
    var versionText: String
    var onRevealData: () -> Void
    @ObservedObject var shortcuts: ShortcutCoordinator

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var recording: ShortcutAction?

    var body: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.lg) {
            HStack(spacing: GlanceTheme.Space.md) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: GlanceTheme.Space.xxs) {
                    Text("Glance")
                        .font(.title2.weight(.semibold))
                    Text(GlanceConstants.slogan)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            GroupBox("通用") {
                VStack(alignment: .leading, spacing: GlanceTheme.Space.sm) {
                    Toggle("开机自动启动 Glance", isOn: launchBinding)
                        .toggleStyle(.switch)
                    if let launchError {
                        Text(launchError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, GlanceTheme.Space.xs)
            }

            GroupBox("快捷键") {
                VStack(alignment: .leading, spacing: GlanceTheme.Space.sm) {
                    ForEach(ShortcutAction.allCases, id: \.self) { action in
                        HStack {
                            Text(action.title)
                            Spacer(minLength: GlanceTheme.Space.sm)
                            ShortcutRecorderView(
                                shortcut: shortcuts.shortcut(for: action),
                                isRecording: recording == action,
                                onBegin: { beginRecording(action) },
                                onDecision: { handleDecision($0, for: action) }
                            )
                        }
                    }
                    if let message = shortcuts.errorMessage, !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button("恢复默认快捷键") {
                        if let recording {
                            shortcuts.cancelRecording(recording)
                            self.recording = nil
                        }
                        shortcuts.resetAll()
                    }
                }
                .padding(.vertical, GlanceTheme.Space.xs)
            }

            GroupBox("数据") {
                VStack(alignment: .leading, spacing: GlanceTheme.Space.sm) {
                    Text("本地数据位置")
                    Text(displayPath(dataFolderURL))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button("打开数据文件夹", action: onRevealData)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, GlanceTheme.Space.xs)
            }

            Text(versionText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(GlanceTheme.Space.xl)
        .frame(width: 440)
    }

    private func beginRecording(_ action: ShortcutAction) {
        if let recording, recording != action {
            shortcuts.cancelRecording(recording)
        }
        recording = action
        shortcuts.beginRecording(action)
    }

    private func handleDecision(_ decision: ShortcutRecorderDecision, for action: ShortcutAction) {
        switch decision {
        case .ignore:
            break
        case .cancel:
            shortcuts.cancelRecording(action)
            recording = nil
        case .reject(let error):
            shortcuts.errorMessage = error.errorDescription
        case .capture(let shortcut):
            recording = nil
            shortcuts.commitRecording(shortcut, for: action)
        }
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
