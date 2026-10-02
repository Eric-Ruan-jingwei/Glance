import AppKit

enum PassThroughHint {
    static let defaultsKey = "didShowPassThroughHint"

    static func showIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: defaultsKey) else { return }
        defaults.set(true, forKey: defaultsKey)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "按住 Option 可临时操作此面板"
        alert.informativeText = "开启点击穿透后，面板会把鼠标事件交给下面的窗口。按住 Option 可以临时拖动、右键或编辑。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
