import Foundation

struct GlanceNotice: Equatable {
    enum Kind: Equatable {
        case info
        case warning
        case error
    }

    var message: String
    var kind: Kind
}

enum GlanceActionOutcome: Equatable {
    case succeeded
    case failed(String)

    var noticeMessage: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}

enum GlanceNoticeCopy {
    static let staleItem = "内容已经不存在"
    static let fileMissing = "文件已移动或不存在"
    static let linkInvalid = "链接已经失效"
    static let globallyHidden = "面板当前已全局隐藏"
    static let panelCreateFailed = "无法创建面板"
    static let clipboardWriteFailed = "无法写入剪贴板"
}
