import AppKit

enum WorkspaceNamePrompt {
    static func runModal(
        title: String,
        message: String,
        defaultName: String = ""
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = defaultName
        field.placeholderString = "工作区名称"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    static func runRenameModal(currentName: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "重命名工作区"
        alert.informativeText = "输入新的工作区名称。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = currentName
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    static func confirmDelete(name: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除工作区“\(name)”？"
        alert.informativeText = "其中的面板会移动到“默认”，不会被删除。"
        alert.addButton(withTitle: "删除工作区")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if let workspaceError = error as? WorkspaceError, workspaceError == .duplicateName {
            alert.messageText = "工作区名称已存在。"
        } else {
            alert.messageText = error.localizedDescription
        }
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
