import SwiftUI

struct SettingsView: View {
    var dataFolderURL: URL
    var versionText: String
    var onRevealData: () -> Void
    var onOpenGuideShortcuts: () -> Void = {}
    @ObservedObject var shortcuts: ShortcutCoordinator
    @ObservedObject var clipboard: ClipboardHistoryService
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var confirmClearRecent = false
    @State private var confirmClearAll = false
    @State private var launchError: String?
    @State private var recording: ShortcutAction?

    var body: some View {
        ScrollView {
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
                        VStack(alignment: .leading, spacing: GlanceTheme.Space.xxs) {
                            HStack {
                                Text(action.title)
                                Spacer(minLength: GlanceTheme.Space.sm)
                                ShortcutRecorderView(
                                    shortcut: shortcuts.configuredShortcut(for: action),
                                    isRecording: recording == action,
                                    onBegin: { beginRecording(action) },
                                    onDecision: { handleDecision($0, for: action) }
                                )
                            }
                            if let caption = shortcuts.runtimeIssue(for: action)?.settingsCaption {
                                Text(caption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                    Button(GlanceGuideEntry.settingsLinkTitle, action: onOpenGuideShortcuts)
                }
                .padding(.vertical, GlanceTheme.Space.xs)
            }

            GroupBox("剪贴板") {
                VStack(alignment: .leading, spacing: GlanceTheme.Space.sm) {
                    Toggle("记录剪贴板历史", isOn: recordingBinding)
                        .toggleStyle(.switch)
                    Text("内容只保存在本机，不会上传。关闭后不会删除已有记录和收藏。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("清空最近记录…") {
                        confirmClearRecent = true
                    }
                    .disabled(!clipboard.canPersist)
                    Button("清空所有剪贴板数据…") {
                        confirmClearAll = true
                    }
                    .disabled(!clipboard.canPersist)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .confirmationDialog(
            "清空最近记录？",
            isPresented: $confirmClearRecent,
            titleVisibility: .visible
        ) {
            Button("清空最近记录", role: .destructive) {
                clipboard.clearRecent()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除未收藏的记录，收藏会保留。不会清空系统剪贴板。")
        }
        .confirmationDialog(
            "清空所有剪贴板数据？",
            isPresented: $confirmClearAll,
            titleVisibility: .visible
        ) {
            Button("清空所有剪贴板数据", role: .destructive) {
                clipboard.clearAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除所有最近记录和收藏，此操作无法撤销。不会清空系统剪贴板。")
        }
    }

    private var recordingBinding: Binding<Bool> {
        Binding(
            get: { clipboard.preferences.isRecordingEnabled },
            set: { newValue in
                clipboard.preferences.isRecordingEnabled = newValue
                onRecordingChange(newValue)
            }
        )
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
