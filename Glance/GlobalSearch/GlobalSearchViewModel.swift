import Combine
import Foundation

struct GlobalSearchImmediateSnapshot {
    var clipboard: [ClipboardHistoryRecord]
    var clipboardUnavailable: Bool
    var files: [FileShelfRecord]
    var filesUnavailable: Bool
    var snippets: [SnippetRecord]
    var snippetsUnavailable: Bool
    var links: [LinkRecord]
    var linksUnavailable: Bool
    var panelInputs: [PanelSummaryInput]
    var panelsUnavailable: Bool
    var workspaceNames: [String: String]
}

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var selection: GlobalSearchResultID?
    @Published var immediateDocuments: [GlobalSearchDocument] = []
    @Published var panelDocuments: [GlobalSearchDocument] = []
    @Published var isLoadingPanels = false
    @Published var unavailableSources: [GlobalSearchSource] = []
    @Published var notice: String?
    @Published var presentationID = 0
    @Published private(set) var panelLoadCount = 0

    var summaryLoader: any PanelSummaryLoading
    private var summaryGeneration: UInt64 = 0
    private var summaryLoadTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var workspaceNames: [String: String] = [:]

    init(summaryLoader: any PanelSummaryLoading = PanelSummaryLoader()) {
        self.summaryLoader = summaryLoader
    }

    var displayed: [GlobalSearchDocument] {
        GlobalSearchEngine.results(
            documents: immediateDocuments + panelDocuments,
            query: query
        )
    }

    var sectionTitle: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? GlobalSearchCopy.recentSection
            : GlobalSearchCopy.resultsSection
    }

    var showsPartialUnavailable: Bool {
        !unavailableSources.isEmpty
    }

    func resetPresentation() {
        query = ""
        notice = nil
        cancelPanelLoading()
        immediateDocuments = []
        panelDocuments = []
        unavailableSources = []
        selection = nil
        presentationID += 1
    }

    func applyImmediateSnapshot(_ snapshot: GlobalSearchImmediateSnapshot) {
        workspaceNames = snapshot.workspaceNames
        var unavailable: [GlobalSearchSource] = []
        immediateDocuments =
            GlobalSearchSnapshotBuilder.clipboard(snapshot.clipboard, unavailable: snapshot.clipboardUnavailable)
            + GlobalSearchSnapshotBuilder.fileShelf(snapshot.files, unavailable: snapshot.filesUnavailable)
            + GlobalSearchSnapshotBuilder.snippets(snapshot.snippets, unavailable: snapshot.snippetsUnavailable)
            + GlobalSearchSnapshotBuilder.links(snapshot.links, unavailable: snapshot.linksUnavailable)
        if snapshot.clipboardUnavailable { unavailable.append(.clipboard) }
        if snapshot.filesUnavailable { unavailable.append(.fileShelf) }
        if snapshot.snippetsUnavailable { unavailable.append(.snippets) }
        if snapshot.linksUnavailable { unavailable.append(.links) }
        if snapshot.panelsUnavailable { unavailable.append(.panels) }
        unavailableSources = unavailable
        reconcileSelection()
        if !snapshot.panelsUnavailable {
            startPanelLoad(snapshot.panelInputs)
        } else {
            isLoadingPanels = false
        }
    }

    func moveSelection(_ delta: Int) {
        let items = displayed
        guard !items.isEmpty else {
            selection = nil
            return
        }
        guard let selection, let index = items.firstIndex(where: { $0.id == selection }) else {
            self.selection = items.first?.id
            return
        }
        let next = min(max(0, index + delta), items.count - 1)
        self.selection = items[next].id
    }

    func reconcileSelection() {
        let items = displayed
        if let selection, items.contains(where: { $0.id == selection }) {
            return
        }
        self.selection = items.first?.id
    }

    func selectedDocument() -> GlobalSearchDocument? {
        displayed.first { $0.id == selection }
    }

    func showNotice(_ message: String) {
        noticeTask?.cancel()
        notice = message
        noticeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    func cancelPanelLoading() {
        summaryGeneration += 1
        summaryLoadTask?.cancel()
        summaryLoadTask = nil
        isLoadingPanels = false
    }

    func applyLoadedPanels(_ summaries: [PanelSummary], generation: UInt64) {
        guard generation == summaryGeneration else { return }
        isLoadingPanels = false
        panelDocuments = GlobalSearchSnapshotBuilder.panels(summaries) { id in
            workspaceNames[id] ?? WorkspaceRecord.defaultName
        }
        reconcileSelection()
    }

    private func startPanelLoad(_ inputs: [PanelSummaryInput]) {
        summaryGeneration += 1
        summaryLoadTask?.cancel()
        let generation = summaryGeneration
        if inputs.isEmpty {
            isLoadingPanels = false
            panelDocuments = []
            return
        }
        panelLoadCount += 1
        isLoadingPanels = true
        let loader = summaryLoader
        summaryLoadTask = Task.detached { [weak self] in
            let summaries = await loader.loadSummaries(inputs: inputs)
            guard !Task.isCancelled else { return }
            await self?.applyLoadedPanels(summaries, generation: generation)
        }
    }

    func markUnavailable(_ id: GlobalSearchResultID) {
        if let index = immediateDocuments.firstIndex(where: { $0.id == id }) {
            immediateDocuments[index].isUnavailable = true
            if immediateDocuments[index].source == .fileShelf {
                immediateDocuments[index].preview = GlobalSearchCopy.fileMissingRow
                immediateDocuments[index].subtitle = GlobalSearchCopy.fileMissingRow
            }
        }
        reconcileSelection()
    }
}
