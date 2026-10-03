import Foundation

enum PanelVisibilityTransaction {
    /// Persist `isHidden` first. Callers apply window visibility only after this returns.
    static func setHidden(
        _ hidden: Bool,
        on record: PanelRecord,
        touch: (PanelRecord) -> Void,
        persist: () throws -> Void
    ) throws {
        guard record.isHidden != hidden else { return }
        let previousHidden = record.isHidden
        let previousUpdated = record.updatedAt
        record.isHidden = hidden
        touch(record)
        do {
            try persist()
        } catch {
            record.isHidden = previousHidden
            record.updatedAt = previousUpdated
            throw error
        }
    }
}

enum PanelVisibilityMutation {
    static func commit(
        hidden: Bool,
        record: PanelRecord,
        globallyConcealed: Bool,
        touch: (PanelRecord) -> Void,
        persist: () throws -> Void,
        present: () -> Void,
        conceal: () -> Void
    ) throws {
        try PanelVisibilityTransaction.setHidden(
            hidden,
            on: record,
            touch: touch,
            persist: persist
        )
        if PanelVisibilityPolicy.shouldPresent(
            panelHidden: record.isHidden,
            globallyConcealed: globallyConcealed
        ) {
            present()
        } else {
            conceal()
        }
    }
}
