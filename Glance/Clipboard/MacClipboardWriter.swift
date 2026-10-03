import AppKit

enum MacClipboardWriter {
    @discardableResult
    static func write(
        _ content: ClipboardCaptureContent,
        to pasteboard: NSPasteboard = .general
    ) -> Int {
        pasteboard.clearContents()
        switch content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .png(let data):
            pasteboard.setData(data, forType: .png)
        }
        return pasteboard.changeCount
    }
}

enum ClipboardHistoryIngest {
    enum Result: Equatable {
        case captured(ClipboardCaptureContent)
        case skippedPrivacy
        case skippedOversizedImage
        case unsupported
    }

    static func read(
        _ pasteboard: NSPasteboard,
        maxImageBytes: Int = ClipboardHistoryPolicy.maximumStoredImageBytes
    ) -> Result {
        let types = (pasteboard.types ?? []).map(\.rawValue)
        if ClipboardPrivacyMarkers.shouldSkip(typeStrings: types) {
            return .skippedPrivacy
        }
        switch MacClipboardReader.readImage(from: pasteboard, maxBytes: maxImageBytes) {
        case .png(let data):
            return .captured(.png(data))
        case .oversized:
            return .skippedOversizedImage
        case .unavailable:
            break
        }
        guard let content = ClipboardCaptureRouter.content(
            imagePNG: nil,
            text: pasteboard.string(forType: .string)
        ) else {
            return .unsupported
        }
        return .captured(content)
    }
}

enum ClipboardHistoryMonitorPolicy {
    static func shouldRead(
        enabled: Bool,
        lastChangeCount: Int?,
        currentChangeCount: Int
    ) -> Bool {
        guard enabled, let lastChangeCount else { return false }
        return currentChangeCount != lastChangeCount
    }
}

@MainActor
final class ClipboardHistoryMonitor {
    var onCapture: ((ClipboardCaptureContent) -> Void)?

    private var lastChangeCount: Int?
    private var timer: Timer?
    private let pasteboard: NSPasteboard
    private let interval: TimeInterval
    private let isEnabled: () -> Bool

    init(
        pasteboard: NSPasteboard = .general,
        interval: TimeInterval = ClipboardHistoryPolicy.pollInterval,
        isEnabled: @escaping () -> Bool
    ) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.isEnabled = isEnabled
    }

    var adoptedChangeCount: Int? { lastChangeCount }

    func start(baselineChangeCount: Int? = nil) {
        lastChangeCount = baselineChangeCount ?? pasteboard.changeCount
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        timer.tolerance = interval / 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func adoptCurrentChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }

    func adopt(changeCount: Int) {
        lastChangeCount = changeCount
    }

    func tick() {
        let current = pasteboard.changeCount
        guard ClipboardHistoryMonitorPolicy.shouldRead(
            enabled: isEnabled(),
            lastChangeCount: lastChangeCount,
            currentChangeCount: current
        ) else { return }
        lastChangeCount = current
        switch ClipboardHistoryIngest.read(pasteboard) {
        case .captured(let content):
            onCapture?(content)
        case .skippedPrivacy, .skippedOversizedImage, .unsupported:
            break
        }
    }
}
