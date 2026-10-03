import Foundation

enum QuickCaptureAction: Equatable, CaseIterable {
    case saveSnippet
    case saveLink
    case addToFileShelf
    case createPanel

    var title: String {
        switch self {
        case .saveSnippet:
            return QuickCaptureCopy.saveSnippet
        case .saveLink:
            return QuickCaptureCopy.saveLink
        case .addToFileShelf:
            return QuickCaptureCopy.addToFileShelf
        case .createPanel:
            return QuickCaptureCopy.createPanel
        }
    }
}

enum QuickCapturePolicy {
    static func actions(
        for content: QuickCaptureContent,
        fileSupportsPanel: (URL) -> Bool = { QuickCapturePanelFileSupport.isSupported($0) }
    ) -> [QuickCaptureAction] {
        switch content {
        case .empty:
            return []
        case .text:
            return [.saveSnippet, .createPanel]
        case .url:
            return [.saveLink, .createPanel, .saveSnippet]
        case .files(let urls):
            var items: [QuickCaptureAction] = [.addToFileShelf]
            if !urls.isEmpty, urls.allSatisfy(fileSupportsPanel) {
                items.append(.createPanel)
            }
            return items
        }
    }

    static func defaultAction(
        for content: QuickCaptureContent,
        fileSupportsPanel: (URL) -> Bool = { QuickCapturePanelFileSupport.isSupported($0) }
    ) -> QuickCaptureAction? {
        actions(for: content, fileSupportsPanel: fileSupportsPanel).first
    }
}

enum QuickCaptureKeyIntent: Equatable {
    case submit
    case insertNewline
    case confirmComposition
    case moveAction(Int)
    case none
}

enum QuickCaptureKeyPolicy {
    static func intent(
        keyCode: UInt16,
        command: Bool,
        shift: Bool,
        isComposing: Bool,
        allowsNewline: Bool
    ) -> QuickCaptureKeyIntent {
        if isComposing {
            if isReturn(keyCode) {
                return .confirmComposition
            }
            return .none
        }
        if keyCode == 126 {
            return .moveAction(-1)
        }
        if keyCode == 125 {
            return .moveAction(1)
        }
        if isReturn(keyCode) {
            if command {
                return .submit
            }
            switch QuickCaptureReturn.action(
                isComposing: false,
                shift: shift,
                allowsNewline: allowsNewline
            ) {
            case .confirmComposition:
                return .confirmComposition
            case .insertNewline:
                return .insertNewline
            case .submit:
                return .submit
            }
        }
        return .none
    }

    private static func isReturn(_ keyCode: UInt16) -> Bool {
        keyCode == 36 || keyCode == 76
    }
}

enum QuickCaptureCopy {
    static let saveSnippet = "保存为片段"
    static let saveLink = "保存到链接库"
    static let addToFileShelf = "加入文件架"
    static let createPanel = "创建面板"
    static let detectedText = "识别：文字"
    static let detectedLink = "识别：链接"
    static let detectedFile = "识别：文件"
    static let detectedImage = "识别：图片"
    static let detectedPDF = "识别：PDF"
    static let emptyHint = "先输入内容"

    static func detectedTitle(for content: QuickCaptureContent) -> String {
        switch content {
        case .empty:
            return ""
        case .text:
            return detectedText
        case .url:
            return detectedLink
        case .files(let urls):
            let kinds = Set(urls.map { QuickCapturePanelFileSupport.kind(for: $0) })
            if kinds == [.pdf] {
                return detectedPDF
            }
            if kinds == [.image] {
                return detectedImage
            }
            return detectedFile
        }
    }

    static func fileSummary(for urls: [URL]) -> String {
        urls.map(\.lastPathComponent).joined(separator: "\n")
    }
}
