import Foundation

struct WorkspaceRecord: Codable, Equatable, Identifiable {
    static let defaultID = "default"
    static let defaultWorkspaceID = defaultID
    static let defaultName = "默认"

    var id: String
    var name: String
    var createdAt: Date
    var updatedAt: Date

    static func makeDefault(at date: Date = Date()) -> WorkspaceRecord {
        WorkspaceRecord(
            id: defaultID,
            name: defaultName,
            createdAt: date,
            updatedAt: date
        )
    }
}

enum WorkspaceError: Error, Equatable, LocalizedError {
    case emptyName
    case nameTooLong
    case duplicateName
    case cannotRenameDefault
    case cannotDeleteDefault
    case workspaceNotFound
    case panelNotFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "工作区名称不能为空。"
        case .nameTooLong:
            return "工作区名称过长。"
        case .duplicateName:
            return "工作区名称已存在。"
        case .cannotRenameDefault:
            return "默认工作区不可重命名。"
        case .cannotDeleteDefault:
            return "默认工作区不可删除。"
        case .workspaceNotFound:
            return "找不到该工作区。"
        case .panelNotFound:
            return "找不到该面板。"
        }
    }
}

enum WorkspaceName {
    static let maxLength = 40

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validate(_ raw: String) throws -> String {
        let name = normalized(raw)
        guard !name.isEmpty else { throw WorkspaceError.emptyName }
        guard name.count <= maxLength else { throw WorkspaceError.nameTooLong }
        return name
    }

    static func isDuplicate(
        _ raw: String,
        among workspaces: [WorkspaceRecord],
        excluding id: String? = nil
    ) -> Bool {
        let needle = normalized(raw)
        guard !needle.isEmpty else { return false }
        return workspaces.contains { workspace in
            if workspace.id == id { return false }
            return workspace.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(needle) == .orderedSame
        }
    }
}

enum WorkspaceCatalog {
    static func sorted(_ workspaces: [WorkspaceRecord]) -> [WorkspaceRecord] {
        workspaces.sorted { lhs, rhs in
            if lhs.id == WorkspaceRecord.defaultID { return true }
            if rhs.id == WorkspaceRecord.defaultID { return false }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }
    }
}

enum WorkspaceMembership {
    static func idForNewPanel(activeID: String, availableIDs: Set<String>) -> String {
        availableIDs.contains(activeID) ? activeID : WorkspaceRecord.defaultID
    }
}

enum ActiveWorkspaceResolver {
    static func resolve(storedID: String?, availableIDs: Set<String>) -> String {
        if let storedID, availableIDs.contains(storedID) {
            return storedID
        }
        return WorkspaceRecord.defaultID
    }
}

struct WorkspaceMenuItem: Equatable, Identifiable {
    var id: String
    var name: String
    var isActive: Bool
}

enum WorkspaceMenuModel {
    static func items(
        workspaces: [WorkspaceRecord],
        activeID: String
    ) -> [WorkspaceMenuItem] {
        WorkspaceCatalog.sorted(workspaces).map { workspace in
            WorkspaceMenuItem(
                id: workspace.id,
                name: workspace.name,
                isActive: workspace.id == activeID
            )
        }
    }
}
