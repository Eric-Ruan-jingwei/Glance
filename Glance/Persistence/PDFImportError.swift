import Foundation

enum PDFImportError: LocalizedError, Equatable {
    case unreadable
    case emptyDocument
    case passwordProtected
    case copyFailed
    case invalidMetadata

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "无法读取这个 PDF。"
        case .emptyDocument:
            return "这个 PDF 没有可显示的页面。"
        case .passwordProtected:
            return "暂不支持需要密码的 PDF。"
        case .copyFailed:
            return "无法把 PDF 复制到 Glance 数据目录。"
        case .invalidMetadata:
            return "无法写入 PDF 信息。"
        }
    }
}
