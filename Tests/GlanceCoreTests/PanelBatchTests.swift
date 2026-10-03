import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class PanelBatchRepositoryTests: XCTestCase {
    func testBatchHideSuccessTouchesOnlyChangedRecords() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let a = record(hidden: false)
            let b = record(hidden: false)
            let c = record(hidden: true)
            try repository.insert(a)
            try repository.insert(b)
            try repository.insert(c)
            let oldA = a.updatedAt
            let oldB = b.updatedAt
            let oldC = c.updatedAt
            let writesBefore = writer.writeCount
            let changed = try repository.setHidden(ids: [a.id, b.id, c.id], hidden: true)
            XCTAssertEqual(changed, [a.id, b.id])
            XCTAssertTrue(a.isHidden)
            XCTAssertTrue(b.isHidden)
            XCTAssertTrue(c.isHidden)
            XCTAssertGreaterThan(a.updatedAt, oldA)
            XCTAssertGreaterThan(b.updatedAt, oldB)
            XCTAssertEqual(c.updatedAt, oldC)
            XCTAssertEqual(writer.writeCount, writesBefore + 1)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try reloaded.record(id: a.id)?.isHidden, true)
            XCTAssertEqual(try reloaded.record(id: b.id)?.isHidden, true)
            XCTAssertEqual(try reloaded.record(id: c.id)?.isHidden, true)
        }
    }

    func testBatchHideRollback() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let a = record(hidden: false)
            let b = record(hidden: false)
            let c = record(hidden: true)
            try repository.insert(a)
            try repository.insert(b)
            try repository.insert(c)
            let disk = try Data(contentsOf: metadataURL)
            let oldA = a.updatedAt
            let oldB = b.updatedAt
            let oldC = c.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.setHidden(ids: [a.id, b.id, c.id], hidden: true)) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertFalse(a.isHidden)
            XCTAssertFalse(b.isHidden)
            XCTAssertTrue(c.isHidden)
            XCTAssertEqual(a.updatedAt, oldA)
            XCTAssertEqual(b.updatedAt, oldB)
            XCTAssertEqual(c.updatedAt, oldC)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testBatchShowSuccess() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = record(hidden: true)
            let b = record(hidden: false)
            try repository.insert(a)
            try repository.insert(b)
            let oldB = b.updatedAt
            let changed = try repository.setHidden(ids: [a.id, b.id], hidden: false)
            XCTAssertEqual(changed, [a.id])
            XCTAssertFalse(a.isHidden)
            XCTAssertFalse(b.isHidden)
            XCTAssertEqual(b.updatedAt, oldB)
        }
    }

    func testWholeBatchHideNoOpDoesNotWrite() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let a = record(hidden: true)
            let b = record(hidden: true)
            try repository.insert(a)
            try repository.insert(b)
            let disk = try Data(contentsOf: metadataURL)
            let oldA = a.updatedAt
            let writesBefore = writer.writeCount
            let changed = try repository.setHidden(ids: [a.id, b.id], hidden: true)
            XCTAssertTrue(changed.isEmpty)
            XCTAssertEqual(a.updatedAt, oldA)
            XCTAssertEqual(writer.writeCount, writesBefore)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testEmptySelectionIsNoOp() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let writesBefore = writer.writeCount
            XCTAssertTrue(try repository.setHidden(ids: [], hidden: true).isEmpty)
            XCTAssertTrue(try repository.movePanels(ids: [], toWorkspaceID: "missing").isEmpty)
            XCTAssertTrue(try repository.addTags(ids: [], tags: ["API"]).isEmpty)
            XCTAssertTrue(try repository.removeTags(ids: [], tags: ["API"]).isEmpty)
            XCTAssertEqual(writer.writeCount, writesBefore)
        }
    }

    func testMissingPanelFailsEntireBatch() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = record(hidden: false)
            try repository.insert(a)
            let disk = try Data(contentsOf: metadataURL)
            XCTAssertThrowsError(try repository.setHidden(ids: [a.id, UUID()], hidden: true)) { error in
                XCTAssertEqual(error as? PanelBatchError, .panelNotFound)
            }
            XCTAssertFalse(a.isHidden)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testBatchMoveSuccessPreservesOtherMetadata() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let study = try repository.createWorkspace(name: "Study")
            let a = record(hidden: true, tags: ["API"], title: "论文 A")
            a.isLocked = true
            a.opacity = 0.4
            let b = record(hidden: false, tags: ["参考"], title: "论文 B")
            try repository.insert(a)
            try repository.insert(b)
            let writesBefore = writer.writeCount
            let changed = try repository.movePanels(ids: [a.id, b.id], toWorkspaceID: study.id)
            XCTAssertEqual(changed, [a.id, b.id])
            XCTAssertEqual(writer.writeCount, writesBefore + 1)
            XCTAssertEqual(a.workspaceID, study.id)
            XCTAssertEqual(b.workspaceID, study.id)
            XCTAssertEqual(a.tags, ["API"])
            XCTAssertEqual(b.tags, ["参考"])
            XCTAssertEqual(a.customTitle, "论文 A")
            XCTAssertEqual(b.customTitle, "论文 B")
            XCTAssertTrue(a.isHidden)
            XCTAssertFalse(b.isHidden)
            XCTAssertTrue(a.isLocked)
            XCTAssertEqual(a.opacity, 0.4, accuracy: 0.0001)
        }
    }

    func testBatchMoveSameWorkspaceAndInvalidTarget() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let a = record()
            let b = record()
            try repository.insert(a)
            try repository.insert(b)
            let writesBefore = writer.writeCount
            let oldA = a.updatedAt
            XCTAssertTrue(try repository.movePanels(ids: [a.id, b.id], toWorkspaceID: WorkspaceRecord.defaultID).isEmpty)
            XCTAssertEqual(a.updatedAt, oldA)
            XCTAssertEqual(writer.writeCount, writesBefore)
            XCTAssertThrowsError(try repository.movePanels(ids: [a.id, b.id], toWorkspaceID: "missing")) { error in
                XCTAssertEqual(error as? WorkspaceError, .workspaceNotFound)
            }
            XCTAssertEqual(a.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(b.workspaceID, WorkspaceRecord.defaultID)
        }
    }

    func testBatchMoveRollback() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let study = try repository.createWorkspace(name: "Study")
            let a = record()
            let b = record()
            try repository.insert(a)
            try repository.insert(b)
            let disk = try Data(contentsOf: metadataURL)
            let oldA = a.updatedAt
            let oldB = b.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.movePanels(ids: [a.id, b.id], toWorkspaceID: study.id)) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(a.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(b.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(a.updatedAt, oldA)
            XCTAssertEqual(b.updatedAt, oldB)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testBatchAddTagsAppendsAndDedupes() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = record(tags: ["API"])
            let b = record(tags: ["参考", "必读"])
            try repository.insert(a)
            try repository.insert(b)
            let changed = try repository.addTags(ids: [a.id, b.id], tags: ["必读", "论文"])
            XCTAssertEqual(changed, [a.id, b.id])
            XCTAssertEqual(a.tags, ["API", "必读", "论文"])
            XCTAssertEqual(b.tags, ["参考", "必读", "论文"])
        }
    }

    func testBatchAddDuplicateCasingIsNoOp() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let a = record(tags: ["API"])
            try repository.insert(a)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = a.updatedAt
            let writesBefore = writer.writeCount
            XCTAssertTrue(try repository.addTags(ids: [a.id], tags: ["api"]).isEmpty)
            XCTAssertEqual(a.tags, ["API"])
            XCTAssertEqual(a.updatedAt, oldUpdated)
            XCTAssertEqual(writer.writeCount, writesBefore)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testBatchAddOverflowFailsAtomically() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let a = record(tags: (1...12).map { "t\($0)" })
            let b = record(tags: ["API", "参考"])
            try repository.insert(a)
            try repository.insert(b)
            let disk = try Data(contentsOf: metadataURL)
            let oldA = a.updatedAt
            let oldB = b.updatedAt
            let writesBefore = writer.writeCount
            XCTAssertThrowsError(try repository.addTags(ids: [a.id, b.id], tags: ["new"])) { error in
                XCTAssertEqual(error as? PanelBatchError, .tooManyTags)
            }
            XCTAssertEqual(a.tags.count, 12)
            XCTAssertEqual(b.tags, ["API", "参考"])
            XCTAssertEqual(a.updatedAt, oldA)
            XCTAssertEqual(b.updatedAt, oldB)
            XCTAssertEqual(writer.writeCount, writesBefore)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testBatchRemoveTagsMixedPresence() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = record(tags: ["API", "必读"])
            let b = record(tags: ["必读", "论文"])
            let c = record(tags: ["API"])
            try repository.insert(a)
            try repository.insert(b)
            try repository.insert(c)
            let oldC = c.updatedAt
            let changed = try repository.removeTags(ids: [a.id, b.id, c.id], tags: ["必读"])
            XCTAssertEqual(changed, [a.id, b.id])
            XCTAssertEqual(a.tags, ["API"])
            XCTAssertEqual(b.tags, ["论文"])
            XCTAssertEqual(c.tags, ["API"])
            XCTAssertEqual(c.updatedAt, oldC)
        }
    }

    func testBatchTagRollback() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let a = record(tags: ["API"])
            let b = record(tags: ["参考"])
            try repository.insert(a)
            try repository.insert(b)
            let disk = try Data(contentsOf: metadataURL)
            let oldA = a.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.addTags(ids: [a.id, b.id], tags: ["必读"])) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(a.tags, ["API"])
            XCTAssertEqual(b.tags, ["参考"])
            XCTAssertEqual(a.updatedAt, oldA)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testLockedAndPayloadAreIgnoredByBatchMetadata() throws {
        try withTempRepository { directory, metadataURL in
            let payload = directory.appendingPathComponent("content.rtf")
            let bytes = Data("payload-bytes".utf8)
            try bytes.write(to: payload)
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = record(tags: ["API"])
            a.isLocked = true
            try repository.insert(a)
            _ = try repository.setHidden(ids: [a.id], hidden: true)
            _ = try repository.addTags(ids: [a.id], tags: ["必读"])
            XCTAssertTrue(a.isHidden)
            XCTAssertTrue(a.isLocked)
            XCTAssertEqual(a.tags, ["API", "必读"])
            XCTAssertEqual(try Data(contentsOf: payload), bytes)
        }
    }

    func testBatchShowLeavesGlobalConcealPolicyFalse() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = record(hidden: true)
            try repository.insert(a)
            _ = try repository.setHidden(ids: [a.id], hidden: false)
            XCTAssertFalse(a.isHidden)
            XCTAssertFalse(
                PanelVisibilityPolicy.shouldPresent(
                    panelHidden: a.isHidden,
                    panelWorkspaceID: a.workspaceID,
                    activeWorkspaceID: WorkspaceRecord.defaultID,
                    globallyConcealed: true
                )
            )
        }
    }

    private func record(
        hidden: Bool = false,
        workspace: String = WorkspaceRecord.defaultID,
        tags: [String] = [],
        title: String? = nil
    ) -> PanelRecord {
        let record = GlanceTestFixtures.sampleRecord(id: UUID(), updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        record.isHidden = hidden
        record.workspaceID = workspace
        record.tags = tags
        record.customTitle = title
        return record
    }

    private func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceBatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, directory.appendingPathComponent("panels.json"))
    }
}

@MainActor
final class PanelLibrarySelectionTests: XCTestCase {
    func testOrdinaryClickReplacesSelection() {
        let a = summary("A")
        let b = summary("B")
        let model = modelWith([a, b])
        model.selectSingle(a.id)
        XCTAssertEqual(model.selectedPanelIDs, [a.id])
        model.selectSingle(b.id)
        XCTAssertEqual(model.selectedPanelIDs, [b.id])
    }

    func testToggleSelection() {
        let a = summary("A")
        let b = summary("B")
        let model = modelWith([a, b])
        model.toggleSelection(a.id)
        model.toggleSelection(b.id)
        model.toggleSelection(a.id)
        XCTAssertEqual(model.selectedPanelIDs, [b.id])
    }

    func testSelectAllVisibleIgnoresFilteredOut() {
        let a = summary("A", kind: PanelKind.text)
        let b = summary("B", kind: PanelKind.text)
        let c = summary("C", kind: PanelKind.text)
        let d = summary("D", kind: PanelKind.pdf)
        let e = summary("E", kind: PanelKind.pdf)
        let model = modelWith([a, b, c, d, e])
        model.filter = .text
        model.selectAllVisible()
        XCTAssertEqual(model.selectedPanelIDs, [a.id, b.id, c.id])
    }

    func testSearchReconcileDropsInvisibleIDs() {
        let a = summary("Alpha")
        let b = summary("Beta")
        let c = summary("Gamma")
        let model = modelWith([a, b, c])
        model.selectedPanelIDs = [a.id, b.id, c.id]
        model.query = "Alpha"
        model.reconcileSelection()
        XCTAssertEqual(model.selectedPanelIDs, [a.id])
    }

    func testFilterReconcileDropsInvisibleIDs() {
        let a = summary("A", kind: PanelKind.text)
        let b = summary("B", kind: PanelKind.pdf)
        let c = summary("C", kind: PanelKind.pdf)
        let model = modelWith([a, b, c])
        model.selectedPanelIDs = [a.id, b.id, c.id]
        model.filter = .pdf
        model.reconcileSelection()
        XCTAssertEqual(model.selectedPanelIDs, [b.id, c.id])
    }

    func testWorkspaceSwitchClearsSelection() {
        let work = summary("API", workspace: "work")
        let study = summary("论文", workspace: "study")
        let model = PanelLibraryModel()
        model.loadSummaries = { [work, study] }
        model.loadWorkspaces = {
            [
                WorkspaceRecord.makeDefault(at: Date(timeIntervalSince1970: 1)),
                WorkspaceRecord(id: "work", name: "Work", createdAt: Date(timeIntervalSince1970: 2), updatedAt: Date(timeIntervalSince1970: 2)),
                WorkspaceRecord(id: "study", name: "Study", createdAt: Date(timeIntervalSince1970: 3), updatedAt: Date(timeIntervalSince1970: 3))
            ]
        }
        model.loadActiveWorkspaceID = { model.selectedWorkspaceID }
        model.reload()
        model.selectedWorkspaceID = "work"
        model.selectAllVisible()
        XCTAssertEqual(model.selectedPanelIDs, [work.id])
        model.activateWorkspace("study")
        XCTAssertTrue(model.selectedPanelIDs.isEmpty)
    }

    func testBatchMoveReconcilesSelection() {
        var a = summary("A", workspace: "work")
        var b = summary("B", workspace: "work")
        let model = PanelLibraryModel()
        model.loadSummaries = { [a, b] }
        model.loadWorkspaces = {
            [
                WorkspaceRecord.makeDefault(at: Date(timeIntervalSince1970: 1)),
                WorkspaceRecord(id: "work", name: "Work", createdAt: Date(timeIntervalSince1970: 2), updatedAt: Date(timeIntervalSince1970: 2)),
                WorkspaceRecord(id: "study", name: "Study", createdAt: Date(timeIntervalSince1970: 3), updatedAt: Date(timeIntervalSince1970: 3))
            ]
        }
        model.loadActiveWorkspaceID = { model.selectedWorkspaceID }
        model.reload()
        model.selectedWorkspaceID = "work"
        model.selectAllVisible()
        model.movePanels = { ids, destination in
            if ids.contains(a.id) { a.workspaceID = destination }
            if ids.contains(b.id) { b.workspaceID = destination }
        }
        model.batchMove(to: "study")
        XCTAssertTrue(model.selectedPanelIDs.isEmpty)
        XCTAssertEqual(model.visible, [])
    }

    func testRemovingFilteredTagClearsSelectionAndFilter() {
        var a = summary("A", tags: ["必读"])
        var b = summary("B", tags: ["必读"])
        let model = PanelLibraryModel()
        model.loadSummaries = { [a, b] }
        model.reload()
        model.selectTagFilter("必读")
        model.selectAllVisible()
        XCTAssertEqual(model.selectedPanelIDs, [a.id, b.id])
        model.removeTagsFromPanels = { ids, tags in
            if ids.contains(a.id) {
                a.tags = a.tags.filter { tag in !tags.contains(where: { PanelTag.isEqual($0, tag) }) }
            }
            if ids.contains(b.id) {
                b.tags = b.tags.filter { tag in !tags.contains(where: { PanelTag.isEqual($0, tag) }) }
            }
        }
        model.removeTagsFromSelection(["必读"])
        XCTAssertNil(model.selectedTag)
        XCTAssertTrue(model.selectedPanelIDs.isEmpty)
        XCTAssertEqual(Set(model.visible.map(\.title)), ["A", "B"])
    }

    func testBatchOverflowKeepsSelectionAndShowsError() {
        let a = summary("A")
        let b = summary("B")
        let model = modelWith([a, b])
        model.selectAllVisible()
        var presented: [String] = []
        model.presentBatchError = { error in
            presented.append((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
        model.addTagsToPanels = { _, _ in
            throw PanelBatchError.tooManyTags
        }
        model.addTagsToSelection(["new"])
        XCTAssertEqual(model.selectedPanelIDs, [a.id, b.id])
        XCTAssertEqual(presented, [PanelBatchError.tooManyTags.errorDescription])
    }

    func testResetSessionClearsSelection() {
        let a = summary("A")
        let model = modelWith([a])
        model.selectSingle(a.id)
        model.resetSessionState()
        XCTAssertTrue(model.selectedPanelIDs.isEmpty)
    }

    private func modelWith(_ summaries: [PanelSummary]) -> PanelLibraryModel {
        let model = PanelLibraryModel()
        model.loadSummaries = { summaries }
        model.reload()
        return model
    }

    private func summary(
        _ title: String,
        kind: String = PanelKind.text,
        workspace: String = WorkspaceRecord.defaultID,
        tags: [String] = [],
        hidden: Bool = false
    ) -> PanelSummary {
        PanelSummary(
            id: UUID(),
            kindIdentifier: kind,
            title: title,
            subtitle: nil,
            preview: "",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: hidden,
            workspaceID: workspace,
            tags: tags,
            isUnreadable: false
        )
    }
}
