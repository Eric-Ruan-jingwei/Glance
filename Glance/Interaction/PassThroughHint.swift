import AppKit

enum PassThroughHint {
    static let defaultsKey = "didShowPassThroughHint"
    static let title = "按住 Option 可临时操作此面板"
    static let body = """
    开启点击穿透后，鼠标事件会传递给后面的窗口。
    按住 Option 可临时操作面板；已锁定的面板仍不会被移动、缩放或编辑。
    """

    static func showIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: defaultsKey) else { return }
        defaults.set(true, forKey: defaultsKey)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
