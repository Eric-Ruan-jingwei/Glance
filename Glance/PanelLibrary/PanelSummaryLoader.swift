import Foundation

/// Immutable snapshot of panel metadata for payload inspection. Not persisted.
struct PanelSummaryInput: Sendable, Equatable {
    let id: UUID
    let kindIdentifier: String
    let customTitle: String?
    let workspaceID: String
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let isLocked: Bool
    let isPassThrough: Bool
    let isPinned: Bool
    let isHidden: Bool
    let payloadDirectory: URL

    init(
        id: UUID,
        kindIdentifier: String,
        customTitle: String?,
        workspaceID: String,
        tags: [String],
        createdAt: Date,
        updatedAt: Date,
        isLocked: Bool,
        isPassThrough: Bool,
        isPinned: Bool,
        isHidden: Bool,
        payloadDirectory: URL
    ) {
        self.id = id
        self.kindIdentifier = kindIdentifier
        self.customTitle = customTitle
        self.workspaceID = workspaceID
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isLocked = isLocked
        self.isPassThrough = isPassThrough
        self.isPinned = isPinned
        self.isHidden = isHidden
        self.payloadDirectory = payloadDirectory
    }

    init(record: PanelRecord, payloadDirectory: URL) {
        self.init(
            id: record.id,
            kindIdentifier: record.kindIdentifier,
            customTitle: record.customTitle,
            workspaceID: record.workspaceID,
            tags: record.tags,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            isLocked: record.isLocked,
            isPassThrough: record.isPassThrough,
            isPinned: record.isPinned,
            isHidden: record.isHidden,
            payloadDirectory: payloadDirectory
        )
    }
}

protocol PanelSummaryLoading: Sendable {
    func loadSummaries(inputs: [PanelSummaryInput]) async -> [PanelSummary]
}

struct PanelSummaryLoader: PanelSummaryLoading {
    var maxConcurrent: Int

    init(maxConcurrent: Int = 6) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    func loadSummaries(inputs: [PanelSummaryInput]) async -> [PanelSummary] {
        guard !inputs.isEmpty else { return [] }
        var results = [PanelSummary?](repeating: nil, count: inputs.count)
        await withTaskGroup(of: (Int, PanelSummary).self) { group in
            var nextIndex = 0
            let initial = min(maxConcurrent, inputs.count)

            func enqueue(_ index: Int) {
                let input = inputs[index]
                group.addTask {
                    (index, PanelSummaryBuilder.summarize(input: input))
                }
            }

            while nextIndex < initial {
                enqueue(nextIndex)
                nextIndex += 1
            }

            for await (index, summary) in group {
                results[index] = summary
                if nextIndex < inputs.count {
                    enqueue(nextIndex)
                    nextIndex += 1
                }
            }
        }
        return results.compactMap { $0 }
    }
}
