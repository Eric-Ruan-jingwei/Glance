import Foundation

enum ClipboardCaptureContent: Equatable {
    case text(String)
    case png(Data)
}

enum ClipboardCaptureRouter {
    static func content(imagePNG: Data?, text: String?) -> ClipboardCaptureContent? {
        if let imagePNG, !imagePNG.isEmpty {
            return .png(imagePNG)
        }
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        return nil
    }

    static func kindIdentifier(for content: ClipboardCaptureContent) -> String {
        switch content {
        case .text:
            return "com.glance.panel.text"
        case .png:
            return "com.glance.panel.image"
        }
    }

    static func initialContent(for content: ClipboardCaptureContent) -> PanelInitialContent {
        switch content {
        case .text(let text):
            return .plainText(text)
        case .png(let data):
            return .imagePNG(data)
        }
    }
}
