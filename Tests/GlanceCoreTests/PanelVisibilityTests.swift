import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelVisibilityPolicyTests: XCTestCase {
    func testEffectiveVisibility() {
        XCTAssertTrue(present(hidden: false, global: false))
        XCTAssertFalse(present(hidden: true, global: false))
        XCTAssertFalse(present(hidden: false, global: true))
        XCTAssertFalse(present(hidden: true, global: true))
    }

    func testNewPanelFollowsGlobalConcealmentOnly() {
        XCTAssertFalse(PanelRevealPolicy.shouldPresentNewlyCreatedPanel(isGloballyConcealed: true))
        XCTAssertTrue(PanelRevealPolicy.shouldPresentNewlyCreatedPanel(isGloballyConcealed: false))
        XCTAssertTrue(
            present(hidden: false, global: false)
        )
    }

    func testGlobalHideDoesNotTreatPanelAsIndividuallyHidden() {
        XCTAssertFalse(present(hidden: false, global: true))
        XCTAssertEqual(PanelVisibilityMenu.symbolName(isHidden: false), "eye")
        XCTAssertEqual(PanelVisibilityMenu.symbolName(isHidden: true), "eye.slash")
    }

    func testLibraryAndContextMenuCopy() {
        XCTAssertEqual(PanelVisibilityMenu.hideThisPanel, "隐藏此面板")
        XCTAssertEqual(PanelVisibilityMenu.libraryActionTitle(isHidden: false), "隐藏")
        XCTAssertEqual(PanelVisibilityMenu.libraryActionTitle(isHidden: true), "显示")
        XCTAssertNotEqual(PanelVisibilityMenu.hideThisPanel, "隐藏")
        XCTAssertNotEqual(PanelVisibilityMenu.hideThisPanel, "隐藏全部")
    }
}

@MainActor
final class PanelVisibilityPersistenceTests: XCTestCase {
    func testV1MigratesToVisibleWithoutChangingTimestamps() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV1EnvelopeJSON.utf8))
        XCTAssertTrue(decoded.migratedFromLegacy)
        XCTAssertEqual(decoded.database.schemaVersion, PanelDatabase.currentSchemaVersion)
        let panel = try XCTUnwrap(decoded.database.panels.first)
        XCTAssertNil(panel.customTitle)
        XCTAssertFalse(panel.isHidden)
        XCTAssertEqual(panel.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertTrue(panel.isLocked)
        XCTAssertEqual(panel.frame.x, 1130)
        XCTAssertEqual(panel.opacity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(panel.kindIdentifier, PanelKind.text)
        XCTAssertEqual(panel.payloadPath, "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7")
        let created = ISO8601DateFormatter().date(from: "2026-10-02T15:32:51Z")
        let updated = ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z")
        XCTAssertEqual(panel.createdAt, created)
        XCTAssertEqual(panel.updatedAt, updated)
        XCTAssertNil(
            (try JSONSerialization.jsonObject(with: Data(GlanceTestFixtures.schemaV1EnvelopeJSON.utf8)) as? [String: Any])
                .flatMap { ($0["panels"] as? [[String: Any]])?.first?["isHidden"] }
        )
    }

    func testV2EncodesIsHiddenAndRoundTripsHiddenState() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.isHidden = true
        let data = try PanelDatabaseCodec.encode(
            PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: [record])
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["schemaVersion"] as? Int, PanelDatabase.currentSchemaVersion)
        let panel = try XCTUnwrap((root["panels"] as? [[String: Any]])?.first)
        XCTAssertEqual(panel["isHidden"] as? Bool, true)
        XCTAssertEqual(panel["workspaceID"] as? String, WorkspaceRecord.defaultID)
        let decoded = try PanelDatabaseCodec.decode(from: data)
        XCTAssertFalse(decoded.migratedFromLegacy)
        XCTAssertEqual(decoded.database.schemaVersion, PanelDatabase.currentSchemaVersion)
        XCTAssertEqual(decoded.database.panels.first?.isHidden, true)
    }

    func testHiddenStateSurvivesReload() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            record.isHidden = true
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(record)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try reloaded.record(id: record.id)?.isHidden, true)
            XCTAssertEqual(try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL)).database.schemaVersion, PanelDatabase.currentSchemaVersion)
        }
    }

    func testV1FileRewritesAsSchema2WithoutChangingUpdatedAt() throws {
        try withTempRepository { _, metadataURL in
            try Data(GlanceTestFixtures.schemaV1EnvelopeJSON.utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .loaded(migratedFromLegacy: true))
            let panel = try XCTUnwrap(try repository.all().first)
            XCTAssertFalse(panel.isHidden)
            XCTAssertEqual(panel.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z"))
            let rewritten = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            XCTAssertEqual(rewritten.database.schemaVersion, PanelDatabase.currentSchemaVersion)
            XCTAssertEqual(rewritten.database.panels.first?.isHidden, false)
            XCTAssertEqual(rewritten.database.panels.first?.updatedAt, panel.updatedAt)
        }
    }

    private func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceVisibilityRepo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, directory.appendingPathComponent("panels.json"))
    }
}

@MainActor
final class PanelVisibilityTransactionTests: XCTestCase {
    func testHideSuccessPersistsThenConceals() throws {
        let record = GlanceTestFixtures.sampleRecord()
        var persisted = false
        var presented = 0
        var concealed = 0
        let originalUpdated = record.updatedAt
        try PanelVisibilityMutation.commit(
            hidden: true,
            record: record,
            globallyConcealed: false,
            activeWorkspaceID: WorkspaceRecord.defaultID,
            touch: { $0.updatedAt = Date(timeIntervalSince1970: 2_000) },
            persist: { persisted = true },
            present: { presented += 1 },
            conceal: { concealed += 1 }
        )
        XCTAssertTrue(persisted)
        XCTAssertTrue(record.isHidden)
        XCTAssertEqual(record.updatedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertNotEqual(record.updatedAt, originalUpdated)
        XCTAssertEqual(presented, 0)
        XCTAssertEqual(concealed, 1)
    }

    func testHideSaveFailureRestoresRecordAndSkipsUI() {
        let record = GlanceTestFixtures.sampleRecord()
        let originalUpdated = record.updatedAt
        var presented = 0
        var concealed = 0
        XCTAssertThrowsError(
            try PanelVisibilityMutation.commit(
                hidden: true,
                record: record,
                globallyConcealed: false,
                activeWorkspaceID: WorkspaceRecord.defaultID,
                touch: { $0.updatedAt = Date(timeIntervalSince1970: 2_000) },
                persist: { throw ForcedMetadataWriteError() },
                present: { presented += 1 },
                conceal: { concealed += 1 }
            )
        )
        XCTAssertFalse(record.isHidden)
        XCTAssertEqual(record.updatedAt, originalUpdated)
        XCTAssertEqual(presented, 0)
        XCTAssertEqual(concealed, 0)
    }

    func testShowSuccessPresentsWhenNotGloballyConcealed() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.isHidden = true
        var presented = 0
        var concealed = 0
        try PanelVisibilityMutation.commit(
            hidden: false,
            record: record,
            globallyConcealed: false,
            activeWorkspaceID: WorkspaceRecord.defaultID,
            touch: { $0.updatedAt = Date() },
            persist: {},
            present: { presented += 1 },
            conceal: { concealed += 1 }
        )
        XCTAssertFalse(record.isHidden)
        XCTAssertEqual(presented, 1)
        XCTAssertEqual(concealed, 0)
    }

    func testShowWhileGloballyConcealedClearsFlagWithoutPresenting() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.isHidden = true
        var presented = 0
        var concealed = 0
        try PanelVisibilityMutation.commit(
            hidden: false,
            record: record,
            globallyConcealed: true,
            activeWorkspaceID: WorkspaceRecord.defaultID,
            touch: { $0.updatedAt = Date() },
            persist: {},
            present: { presented += 1 },
            conceal: { concealed += 1 }
        )
        XCTAssertFalse(record.isHidden)
        XCTAssertEqual(presented, 0)
        XCTAssertEqual(concealed, 1)
        XCTAssertTrue(
            present(hidden: record.isHidden, global: false)
        )
    }

    func testLockDoesNotBlockHide() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.isLocked = true
        try PanelVisibilityTransaction.setHidden(
            true,
            on: record,
            touch: { $0.updatedAt = Date() },
            persist: {}
        )
        XCTAssertTrue(record.isHidden)
        XCTAssertTrue(record.isLocked)
    }

    func testHideSaveFailureLeavesDiskUnchanged() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            writer.shouldFail = true
            XCTAssertThrowsError(
                try PanelVisibilityTransaction.setHidden(
                    true,
                    on: record,
                    touch: { repository.touch($0) },
                    persist: { try repository.save() }
                )
            )
            XCTAssertFalse(record.isHidden)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try reloaded.record(id: record.id)?.isHidden, false)
        }
    }

    private func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceVisibilityTx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, directory.appendingPathComponent("panels.json"))
    }
}

final class PanelVisibilityGlobalStateTests: XCTestCase {
    func testGlobalHidePreservesIndividualFlagsThenShowRestores() {
        let aHidden = false
        let bHidden = true
        let cHidden = false
        let concealedPresentations = [aHidden, bHidden, cHidden].map {
            present(hidden: $0, global: true)
        }
        XCTAssertEqual(concealedPresentations, [false, false, false])
        let restored = [aHidden, bHidden, cHidden].map {
            present(hidden: $0, global: false)
        }
        XCTAssertEqual(restored, [true, false, true])
        XCTAssertEqual([aHidden, bHidden, cHidden], [false, true, false])
    }

    func testNewPanelWhileConcealedStaysVisibleInRecord() {
        let record = GlanceTestFixtures.sampleRecord()
        XCTAssertFalse(record.isHidden)
        XCTAssertFalse(
            present(hidden: record.isHidden, global: true)
        )
        XCTAssertTrue(
            present(hidden: record.isHidden, global: false)
        )
    }
}

@MainActor
final class PanelVisibilitySummaryTests: XCTestCase {
    func testSummaryHiddenFlagComesFromRecordNotWindow() throws {
        let visible = GlanceTestFixtures.sampleRecord()
        visible.isHidden = false
        let hidden = GlanceTestFixtures.sampleRecord(id: UUID())
        hidden.isHidden = true
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceVisibilitySummary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertFalse(PanelSummaryBuilder.summarize(record: visible, payloadDirectory: directory).isHidden)
        XCTAssertTrue(PanelSummaryBuilder.summarize(record: hidden, payloadDirectory: directory).isHidden)
    }

    func testLibraryModelHideAndShowActions() {
        let hidden = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.text,
            title: "Hidden",
            subtitle: nil,
            preview: "",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: true,
            isUnreadable: false
        )
        let visible = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.text,
            title: "Visible",
            subtitle: nil,
            preview: "",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: false,
            isUnreadable: false
        )
        var shown: [UUID] = []
        var hid: [UUID] = []
        let model = PanelLibraryModel()
        model.loadSummaries = { [hidden, visible] }
        model.reveal = { shown.append($0) }
        model.hide = { hid.append($0) }
        model.reload()
        model.revealPanel(hidden.id)
        model.hidePanel(visible.id)
        XCTAssertEqual(shown, [hidden.id])
        XCTAssertEqual(hid, [visible.id])
        XCTAssertEqual(model.summaries.first { $0.id == hidden.id }?.isHidden, true)
        XCTAssertEqual(PanelVisibilityMenu.libraryActionTitle(isHidden: true), "显示")
        XCTAssertEqual(PanelVisibilityMenu.libraryActionTitle(isHidden: false), "隐藏")
    }
}

private func present(
    hidden: Bool,
    workspace: String = WorkspaceRecord.defaultID,
    active: String = WorkspaceRecord.defaultID,
    global: Bool
) -> Bool {
    PanelVisibilityPolicy.shouldPresent(
        panelHidden: hidden,
        panelWorkspaceID: workspace,
        activeWorkspaceID: active,
        globallyConcealed: global
    )
}
