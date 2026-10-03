import AppKit

enum PanelTitlePromptResult: Equatable {
    case cancelled
    case submitted(String)
}

enum PanelTitlePrompt {
    static func runModal(customTitle: String?, automaticTitle: String) -> PanelTitlePromptResult {
        let alert = NSAlert()
        alert.messageText = "重命名面板"
        alert.informativeText = "设置自定义名称。留空可恢复自动标题。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = customTitle ?? ""
        let placeholder = automaticTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        field.placeholderString = placeholder.isEmpty ? "当前：自动标题" : "当前：\(placeholder)"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return .cancelled }
        return .submitted(field.stringValue)
    }

    static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if let titleError = error as? PanelTitleError, titleError == .tooLong {
            alert.messageText = PanelTitleError.tooLong.errorDescription ?? "面板名称最多 80 个字符。"
        } else if error is PanelTitleError {
            alert.messageText = error.localizedDescription
        } else {
            alert.messageText = "无法保存面板名称。"
        }
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
