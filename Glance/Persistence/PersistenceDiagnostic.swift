import Foundation

enum PersistenceDiagnostic: Equatable {
    case recoveredFromBackup
    case quarantinedCorruptMetadata
    case unsupportedFutureSchema(Int)

    static func from(outcome: PanelDatabaseLoadOutcome) -> PersistenceDiagnostic? {
        switch outcome {
        case .recoveredFromBackup:
            return .recoveredFromBackup
        case .quarantinedCorruptAndEmpty:
            return .quarantinedCorruptMetadata
        case .unsupportedFutureSchema(let version):
            return .unsupportedFutureSchema(version)
        case .missing, .loaded:
            return nil
        }
    }

    var menuTitle: String {
        "⚠ 数据恢复提示…"
    }

    var alertMessage: String {
        switch self {
        case .recoveredFromBackup:
            return "已从本地备份恢复面板信息"
        case .quarantinedCorruptMetadata:
            return "主数据文件无法读取"
        case .unsupportedFutureSchema:
            return "这份 Glance 数据由更新版本创建"
        }
    }

    var alertInformative: String {
        switch self {
        case .recoveredFromBackup:
            return "Glance 检测到主数据文件无法读取，并已从本地备份恢复面板信息。建议确认面板内容是否完整。"
        case .quarantinedCorruptMetadata:
            return "损坏的 metadata 文件已保留为 panels.corrupted-*.json。Glance 没有删除该文件。当前面板列表可能为空。"
        case .unsupportedFutureSchema:
            return "当前版本不会修改或降级该数据，也不会覆盖现有文件。请改用更新版本的 Glance 打开。"
        }
    }
}
