import AppKit

@MainActor
final class GlanceClipboardWriter {
    private let monitor: ClipboardHistoryMonitor
    var pasteboard: NSPasteboard
    var performWrite: (ClipboardCaptureContent, NSPasteboard) -> Int?

    init(
        monitor: ClipboardHistoryMonitor,
        pasteboard: NSPasteboard = .general,
        performWrite: @escaping (ClipboardCaptureContent, NSPasteboard) -> Int? = { content, pasteboard in
            MacClipboardWriter.write(content, to: pasteboard)
        }
    ) {
        self.monitor = monitor
        self.pasteboard = pasteboard
        self.performWrite = performWrite
    }

    @discardableResult
    func write(_ content: ClipboardCaptureContent) -> Bool {
        guard let count = performWrite(content, pasteboard) else {
            return false
        }
        monitor.adopt(changeCount: count)
        return true
    }

    func adoptCurrent() {
        monitor.adoptCurrentChangeCount()
    }
}
