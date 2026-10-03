import AppKit
import Combine

@MainActor
final class PanelLibraryModel: ObservableObject {
    @Published var query = ""
    @Published var filter: PanelSummaryKindFilter = .all
    @Published var summaries: [PanelSummary] = []

    var loadSummaries: () -> [PanelSummary] = { [] }
    var reveal: (UUID) -> Void = { _ in }
    var hide: (UUID) -> Void = { _ in }
    var delete: (UUID) -> Bool = { _ in false }
    var openFolder: (UUID) -> Void = { _ in }

    var visible: [PanelSummary] {
        PanelSummaryQuery.sortedByUpdatedAtDescending(
            PanelSummaryQuery.filtered(summaries, query: query, kind: filter)
        )
    }

    var isCompletelyEmpty: Bool { summaries.isEmpty }
    var hasNoMatches: Bool { !summaries.isEmpty && visible.isEmpty }

    func resetSessionState() {
        query = ""
        filter = .all
    }

    func reload() {
        summaries = loadSummaries()
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
}
