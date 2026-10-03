import Foundation

enum PanelBatchError: Error, Equatable, LocalizedError {
    case panelNotFound
    case tooManyTags

    var errorDescription: String? {
        switch self {
        case .panelNotFound:
            return "找不到该面板。"
        case .tooManyTags:
            return "其中至少一个面板添加这些标签后会超过 12 个标签。"
        }
    }
}
