import Foundation

enum QuickCaptureAction: Equatable, CaseIterable {
    case saveSnippet
    case saveLink
    case addToFileShelf
    case createTextPanel
    case createTodoPanel
    case createFilePanel

    var title: String {
        switch self {
        case .saveSnippet:
            return QuickCaptureCopy.saveSnippet
        case .saveLink:
            return QuickCaptureCopy.saveLink
        case .addToFileShelf:
            return QuickCaptureCopy.addToFileShelf
        case .createTextPanel:
            return QuickCaptureCopy.createTextPanel
        case .createTodoPanel:
            return QuickCaptureCopy.createTodoPanel
        case .createFilePanel:
            return QuickCaptureCopy.createFilePanel
        }
    }

    var identifier: String {
        switch self {
        case .saveSnippet: return "saveSnippet"
        case .saveLink: return "saveLink"
        case .addToFileShelf: return "addToFileShelf"
        case .createTextPanel: return "createTextPanel"
        case .createTodoPanel: return "createTodoPanel"
        case .createFilePanel: return "createFilePanel"
        }
    }

    init?(identifier: String) {
        guard let match = Self.allCases.first(where: { $0.identifier == identifier }) else {
            return nil
        }
        self = match
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
            return [.saveSnippet, .createTextPanel, .createTodoPanel]
        case .url:
            return [.saveLink, .createTextPanel, .saveSnippet]
        case .files(let urls):
            var items: [QuickCaptureAction] = [.addToFileShelf]
            if urls.count == 1, let url = urls.first, fileSupportsPanel(url) {
                items.append(.createFilePanel)
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

enum QuickCaptureNewlinePolicy {
    static func allowsNewline(
        content: QuickCaptureContent,
        selectedAction: QuickCaptureAction?
    ) -> Bool {
        switch content {
        case .files:
            return false
        case .empty, .text, .url:
            return selectedAction != .createTodoPanel
        }
    }
}

enum QuickCaptureTodoPolicy {
    static func isValid(_ text: String) -> Bool {
        rejection(for: text) == nil
    }

    static func rejection(for text: String) -> GlanceActionOutcome? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failed(QuickCaptureCopy.emptyHint)
        }
        if trimmed.rangeOfCharacter(from: .newlines) != nil {
            return .failed(QuickCaptureCopy.todoMustBeSingleLine)
        }
        return nil
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
    static let createTextPanel = "创建文字面板"
    static let createTodoPanel = "创建待办面板"
    static let createFilePanel = "创建面板"
    static let detectedText = "识别：文字"
    static let detectedLink = "识别：链接"
    static let detectedFile = "识别：文件"
    static let detectedImage = "识别：图片"
    static let detectedPDF = "识别：PDF"
    static let emptyHint = "先输入内容"
    static let todoMustBeSingleLine = "待办内容需要保持单行"

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

enum QuickCaptureFileShelfAddPolicy {
    static func outcome(
        for result: FileShelfAddResult,
        inputCount: Int
    ) -> GlanceActionOutcome {
        let handled = result.addedIDs.count + result.updatedIDs.count
        if inputCount > 0,
           handled == inputCount,
           result.failed == 0,
           result.rejectedDirectories == 0 {
            return .succeeded
        }
        if handled == 0 {
            return .failed(GlanceNoticeCopy.fileShelfAddFailed)
        }
        return .failed(GlanceNoticeCopy.fileShelfPartialAddFailed)
    }
}
