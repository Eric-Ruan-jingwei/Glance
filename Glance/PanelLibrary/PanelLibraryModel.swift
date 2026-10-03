import AppKit
import Combine

@MainActor
final class PanelLibraryModel: ObservableObject {
    @Published var query = ""
    @Published var filter: PanelSummaryKindFilter = .all
    @Published var summaries: [PanelSummary] = []
    @Published var workspaces: [WorkspaceRecord] = []
    @Published var selectedWorkspaceID: String = WorkspaceRecord.defaultID

    var loadSummaries: () -> [PanelSummary] = { [] }
    var loadWorkspaces: () -> [WorkspaceRecord] = { [WorkspaceRecord.makeDefault()] }
    var loadActiveWorkspaceID: () -> String = { WorkspaceRecord.defaultID }
    var switchWorkspace: (String) -> Void = { _ in }
    var createWorkspace: (String) throws -> WorkspaceRecord = { _ in throw WorkspaceError.emptyName }
    var renameWorkspace: (String, String) throws -> Void = { _, _ in }
    var deleteWorkspace: (String) throws -> Void = { _ in }
    var movePanel: (UUID, String) -> Bool = { _, _ in false }
    var reveal: (UUID) -> Void = { _ in }
    var hide: (UUID) -> Void = { _ in }
    var delete: (UUID) -> Bool = { _ in false }
    var openFolder: (UUID) -> Void = { _ in }
    var rename: (UUID, String?) throws -> Void = { _, _ in }

    var workspaceSummaries: [PanelSummary] {
        summaries.filter { $0.workspaceID == selectedWorkspaceID }
    }

    var visible: [PanelSummary] {
        PanelSummaryQuery.sortedByUpdatedAtDescending(
            PanelSummaryQuery.filtered(
                summaries,
                query: query,
                kind: filter,
                workspaceID: selectedWorkspaceID
            )
        )
    }

    var isCompletelyEmpty: Bool { workspaceSummaries.isEmpty }
    var hasNoMatches: Bool { !workspaceSummaries.isEmpty && visible.isEmpty }

    func resetSessionState() {
        query = ""
        filter = .all
    }

    func reload() {
        workspaces = WorkspaceCatalog.sorted(loadWorkspaces())
        selectedWorkspaceID = loadActiveWorkspaceID()
        summaries = loadSummaries()
    }

    func activateWorkspace(_ id: String) {
        guard id != loadActiveWorkspaceID() else { return }
        switchWorkspace(id)
    }

    func revealPanel(_ id: UUID) {
        reveal(id)
    }

    func hidePanel(_ id: UUID) {
        hide(id)
    }

    func confirmDelete(_ id: UUID) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除此面板？"
        alert.informativeText = "内容会从本地删除，无法撤销。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = delete(id)
        reload()
    }

    func openPayloadFolder(_ id: UUID) {
        openFolder(id)
    }

    func movePanelToWorkspace(_ panelID: UUID, workspaceID: String) {
        _ = movePanel(panelID, workspaceID)
        reload()
    }

    func promptRename(_ summary: PanelSummary) {
        switch PanelTitlePrompt.runModal(
            customTitle: summary.customTitle,
            automaticTitle: summary.automaticTitle
        ) {
        case .cancelled:
            return
        case .submitted(let raw):
            do {
                try rename(summary.id, raw)
                reload()
            } catch {
                PanelTitlePrompt.presentError(error)
            }
        }
    }

    func promptCreateWorkspace() {
        guard let raw = WorkspaceNamePrompt.runModal(
            title: "新建工作区",
            message: "输入工作区名称。"
        ) else { return }
        do {
            _ = try createWorkspace(raw)
            reload()
        } catch {
            WorkspaceNamePrompt.presentError(error)
        }
    }

    func promptRenameWorkspace(_ id: String) {
        guard id != WorkspaceRecord.defaultID else { return }
        guard let current = workspaces.first(where: { $0.id == id }) else { return }
        guard let raw = WorkspaceNamePrompt.runRenameModal(currentName: current.name) else { return }
        do {
            try renameWorkspace(id, raw)
            reload()
        } catch {
            WorkspaceNamePrompt.presentError(error)
        }
    }

    func confirmDeleteWorkspace(_ id: String) {
        guard id != WorkspaceRecord.defaultID else { return }
        guard let current = workspaces.first(where: { $0.id == id }) else { return }
        guard WorkspaceNamePrompt.confirmDelete(name: current.name) else { return }
        do {
            try deleteWorkspace(id)
            reload()
        } catch {
            WorkspaceNamePrompt.presentError(error)
        }
    }
}
