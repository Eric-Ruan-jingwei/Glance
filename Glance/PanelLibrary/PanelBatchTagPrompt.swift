import AppKit
import SwiftUI

enum PanelBatchTagPromptResult: Equatable {
    case cancelled
    case submitted([String])
}

enum PanelBatchTagPrompt {
    static func runAddModal() -> PanelBatchTagPromptResult {
        let alert = NSAlert()
        alert.messageText = "添加标签"
        alert.informativeText = "多个标签用逗号或换行分开。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        let field = GlancePromptField.make(placeholder: "必读, 论文")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return .cancelled }
        return .submitted(PanelTags.parseInput(field.stringValue))
    }

    static func runRemoveModal(tags: [String]) -> PanelBatchTagPromptResult {
        let catalog = PanelTags.catalog(tags)
        guard !catalog.isEmpty else { return .cancelled }

        let session = BatchTagRemovalSession(tags: catalog)
        let hosting = NSHostingController(rootView: BatchTagRemovalView(session: session))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 360, height: 280)
        let window = NSWindow(contentViewController: hosting)
        window.title = "移除标签"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 360, height: 280))
        window.center()
        let delegate = CloseCancelsModalDelegate()
        window.delegate = delegate
        NSApp.activate(ignoringOtherApps: true)
        let response = NSApp.runModal(for: window)
        window.delegate = nil
        window.close()
        _ = delegate
        if response == .OK {
            return .submitted(session.selected)
        }
        return .cancelled
    }

    static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if let batchError = error as? PanelBatchError {
            alert.messageText = batchError.errorDescription ?? "无法完成批量操作。"
        } else if let tagError = error as? PanelTagError {
            alert.messageText = tagError.errorDescription ?? "无法完成批量操作。"
        } else if let workspaceError = error as? WorkspaceError {
            alert.messageText = workspaceError.errorDescription ?? "无法完成批量操作。"
        } else {
            alert.messageText = "无法完成批量操作。"
        }
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private final class BatchTagRemovalSession: ObservableObject {
    let tags: [String]
    @Published var selected: [String] = []

    init(tags: [String]) {
        self.tags = tags
    }

    func toggle(_ tag: String) {
        if selected.contains(where: { PanelTag.isEqual($0, tag) }) {
            selected.removeAll { PanelTag.isEqual($0, tag) }
        } else {
            selected.append(tag)
        }
    }

    func isSelected(_ tag: String) -> Bool {
        selected.contains { PanelTag.isEqual($0, tag) }
    }
}

private struct BatchTagRemovalView: View {
    @ObservedObject var session: BatchTagRemovalSession

    var body: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.md) {
            Text("选择要从所选面板移除的标签。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TagFlowLayout {
                ForEach(session.tags, id: \.self) { tag in
                    PanelTagChip(text: tag)
                        .overlay(
                            RoundedRectangle(cornerRadius: GlanceTheme.Radius.chip, style: .continuous)
                                .stroke(session.isSelected(tag) ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture { session.toggle(tag) }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("取消") {
                    NSApp.stopModal(withCode: .cancel)
                }
                .keyboardShortcut(.cancelAction)
                Button("移除") {
                    NSApp.stopModal(withCode: .OK)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(session.selected.isEmpty)
            }
        }
        .padding(GlanceTheme.Space.lg)
        .frame(width: 360, height: 280)
    }
}

private final class CloseCancelsModalDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.stopModal(withCode: .cancel)
        return true
    }
}
