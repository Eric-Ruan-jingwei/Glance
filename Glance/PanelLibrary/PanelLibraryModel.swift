import AppKit
import Combine

@MainActor
final class PanelLibraryModel: ObservableObject {
    @Published var query = ""
    @Published var filter: PanelSummaryKindFilter = .all
    @Published var summaries: [PanelSummary] = []
    @Published var workspaces: [WorkspaceRecord] = []
    @Published var selectedWorkspaceID: String = WorkspaceRecord.defaultID
    @Published var selectedTag: String? = nil
    @Published var selectedPanelIDs: Set<UUID> = []
    @Published var isLoadingSummaries = false

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
    var setTags: (UUID, [String]) throws -> Void = { _, _ in }
    var loadTagCatalog: () -> [String] = { [] }
    var setHiddenMany: (Set<UUID>, Bool) throws -> Void = { _, _ in }
    var movePanels: (Set<UUID>, String) throws -> Void = { _, _ in }
    var addTagsToPanels: (Set<UUID>, [String]) throws -> Void = { _, _ in }
    var removeTagsFromPanels: (Set<UUID>, [String]) throws -> Void = { _, _ in }
    var presentBatchError: (Error) -> Void = { PanelBatchTagPrompt.presentError($0) }
    var loadSummaryInputs: (() -> [PanelSummaryInput])?
    var summaryLoader: any PanelSummaryLoading = PanelSummaryLoader()

    private var summaryGeneration: UInt64 = 0
    private var summaryLoadTask: Task<Void, Never>?
    private var pendingRevealID: UUID?

    var workspaceSummaries: [PanelSummary] {
        summaries.filter { $0.workspaceID == selectedWorkspaceID }
    }

    var visible: [PanelSummary] {
        PanelSummaryQuery.sortedByUpdatedAtDescending(
            PanelSummaryQuery.filtered(
                summaries,
                query: query,
                kind: filter,
                workspaceID: selectedWorkspaceID,
                tag: selectedTag
            )
        )
    }

    var availableFilterTags: [String] {
        PanelTags.catalog(workspaceSummaries.flatMap(\.tags))
    }

    var tagFilterTitle: String {
        if let selectedTag {
            return "标签：\(selectedTag)"
        }
        return "标签：全部"
    }

    func panelCount(in workspaceID: String) -> Int {
        summaries.filter { $0.workspaceID == workspaceID }.count
    }

    var isCompletelyEmpty: Bool { workspaceSummaries.isEmpty }
    var hasNoMatches: Bool { !workspaceSummaries.isEmpty && visible.isEmpty }

    var emptyKind: PanelLibraryEmptyKind {
        if isLoadingSummaries, summaries.isEmpty {
            return .loading
        }
        if isCompletelyEmpty {
            return .emptyWorkspace
        }
        if hasNoMatches {
            let hasQuery = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasQuery ? .noSearchResults : .noFilterMatches
        }
        return .none
    }

    var showsBatchToolbar: Bool {
        emptyKind == .none && !selectedPanelIDs.isEmpty
    }

    var selectedSummaries: [PanelSummary] {
        let ids = selectedPanelIDs
        return visible.filter { ids.contains($0.id) }
    }

    var canBatchHide: Bool {
        selectedSummaries.contains { !$0.isHidden }
    }

    var canBatchShow: Bool {
        selectedSummaries.contains { $0.isHidden }
    }

    var selectedTagUnion: [String] {
        PanelTags.catalog(selectedSummaries.flatMap(\.tags))
    }

    func allSelectedBelong(to workspaceID: String) -> Bool {
        let selected = selectedSummaries
        return !selected.isEmpty && selected.allSatisfy { $0.workspaceID == workspaceID }
    }

    func resetSessionState() {
        query = ""
        filter = .all
        selectedTag = nil
        selectedPanelIDs = []
        pendingRevealID = nil
        cancelSummaryLoading()
    }

    @discardableResult
    func revealInLibrary(_ id: UUID) -> Bool {
        pendingRevealID = id
        if selectForReveal(id) {
            pendingRevealID = nil
            return true
        }
        return true
    }

    @discardableResult
    func selectForReveal(_ id: UUID) -> Bool {
        query = ""
        filter = .all
        selectedTag = nil
        guard let summary = summaries.first(where: { $0.id == id }) else {
            return false
        }
        selectedWorkspaceID = summary.workspaceID
        selectedPanelIDs = [id]
        return true
    }

    func reload() {
        workspaces = WorkspaceCatalog.sorted(loadWorkspaces())
        let active = loadActiveWorkspaceID()
        if selectedWorkspaceID != active {
            selectedTag = nil
            selectedPanelIDs = []
        }
        selectedWorkspaceID = active
        if let loadSummaryInputs {
            startSummaryLoad(loadSummaryInputs())
        } else {
            _ = beginSummaryRequest()
            summaries = loadSummaries()
            reconcileSelection()
            reconcileSelectedTag()
            finishPendingRevealIfPossible()
        }
    }

    @discardableResult
    func beginSummaryRequest() -> UInt64 {
        summaryGeneration += 1
        summaryLoadTask?.cancel()
        summaryLoadTask = nil
        return summaryGeneration
    }

    func applyLoadedSummaries(_ summaries: [PanelSummary], generation: UInt64) {
        guard generation == summaryGeneration else { return }
        isLoadingSummaries = false
        self.summaries = summaries
        reconcileSelection()
        reconcileSelectedTag()
        finishPendingRevealIfPossible()
    }

    func cancelSummaryLoading() {
        summaryGeneration += 1
        summaryLoadTask?.cancel()
        summaryLoadTask = nil
        isLoadingSummaries = false
    }

    private func startSummaryLoad(_ inputs: [PanelSummaryInput]) {
        let generation = beginSummaryRequest()
        isLoadingSummaries = summaries.isEmpty
        let loader = summaryLoader
        summaryLoadTask = Task.detached { [weak self] in
            let summaries = await loader.loadSummaries(inputs: inputs)
            guard !Task.isCancelled else { return }
            await self?.applyLoadedSummaries(summaries, generation: generation)
        }
    }

    private func finishPendingRevealIfPossible() {
        guard let pendingRevealID else { return }
        if selectForReveal(pendingRevealID) {
            self.pendingRevealID = nil
        } else if !isLoadingSummaries {
            self.pendingRevealID = nil
        }
    }

    func selectTagFilter(_ tag: String?) {
        selectedTag = tag
        reconcileSelectedTag()
        reconcileSelection()
    }

    func activateWorkspace(_ id: String) {
        if id != loadActiveWorkspaceID() {
            selectedTag = nil
            selectedPanelIDs = []
        }
        guard id != loadActiveWorkspaceID() else { return }
        switchWorkspace(id)
    }

    func selectSingle(_ id: UUID) {
        selectedPanelIDs = [id]
    }

    func toggleSelection(_ id: UUID) {
        if selectedPanelIDs.contains(id) {
            selectedPanelIDs.remove(id)
        } else {
            selectedPanelIDs.insert(id)
        }
    }

    func selectAllVisible() {
        selectedPanelIDs = Set(visible.map(\.id))
    }

    func clearSelection() {
        selectedPanelIDs.removeAll()
    }

    func reconcileSelection() {
        selectedPanelIDs.formIntersection(Set(visible.map(\.id)))
    }

    func batchHide() {
        performBatch(ids: selectedPanelIDs) { ids in
            try setHiddenMany(ids, true)
        }
    }

    func batchShow() {
        performBatch(ids: selectedPanelIDs) { ids in
            try setHiddenMany(ids, false)
        }
    }

    func batchMove(to workspaceID: String) {
        performBatch(ids: selectedPanelIDs) { ids in
            try movePanels(ids, workspaceID)
        }
    }

    func addTagsToSelection(_ tags: [String]) {
        performBatch(ids: selectedPanelIDs) { ids in
            try addTagsToPanels(ids, tags)
        }
    }

    func removeTagsFromSelection(_ tags: [String]) {
        performBatch(ids: selectedPanelIDs) { ids in
            try removeTagsFromPanels(ids, tags)
        }
    }

    func promptBatchAddTags() {
        switch PanelBatchTagPrompt.runAddModal() {
        case .cancelled:
            return
        case .submitted(let tags):
            guard !tags.isEmpty else { return }
            addTagsToSelection(tags)
        }
    }

    func promptBatchRemoveTags() {
        switch PanelBatchTagPrompt.runRemoveModal(tags: selectedTagUnion) {
        case .cancelled:
            return
        case .submitted(let tags):
            guard !tags.isEmpty else { return }
            removeTagsFromSelection(tags)
        }
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

    func promptEditTags(_ summary: PanelSummary) {
        switch PanelTagEditorPrompt.runModal(
            currentTags: summary.tags,
            catalog: loadTagCatalog()
        ) {
        case .cancelled:
            return
        case .submitted(let tags):
            do {
                try setTags(summary.id, tags)
                reload()
            } catch {
                PanelTagEditorPrompt.presentError(error)
            }
        }
    }

    func promptCreateWorkspace() {
        guard let raw = WorkspaceNamePrompt.runModal(
            title: "新建工作区",
            message: "给这个工作区起个名字。"
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

    private func reconcileSelectedTag() {
        guard let selectedTag else { return }
        if !availableFilterTags.contains(where: { PanelTag.isEqual($0, selectedTag) }) {
            self.selectedTag = nil
        }
    }

    private func performBatch(ids: Set<UUID>, _ work: (Set<UUID>) throws -> Void) {
        guard !ids.isEmpty else { return }
        do {
            try work(ids)
            reload()
        } catch {
            presentBatchError(error)
        }
    }
}
