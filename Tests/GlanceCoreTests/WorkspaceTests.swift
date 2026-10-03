import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class WorkspaceRecordTests: XCTestCase {
    func testRoundTrip() throws {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = Date(timeIntervalSince1970: 1_700_000_100)
        let record = WorkspaceRecord(
            id: "0B123",
            name: "写代码",
            createdAt: created,
            updatedAt: updated
        )
        let encoder = PanelDatabaseCodec.makeEncoder()
        let decoder = PanelDatabaseCodec.makeDecoder()
        let data = try encoder.encode(record)
        let decoded = try decoder.decode(WorkspaceRecord.self, from: data)
        XCTAssertEqual(decoded, record)
        XCTAssertEqual(WorkspaceRecord.defaultID, "default")
        XCTAssertEqual(WorkspaceRecord.defaultName, "默认")
    }

    func testNameValidation() throws {
        XCTAssertEqual(try WorkspaceName.validate("  写论文  "), "写论文")
        XCTAssertThrowsError(try WorkspaceName.validate("   ")) { error in
            XCTAssertEqual(error as? WorkspaceError, .emptyName)
        }
        XCTAssertThrowsError(try WorkspaceName.validate(String(repeating: "a", count: 41))) { error in
            XCTAssertEqual(error as? WorkspaceError, .nameTooLong)
        }
        XCTAssertEqual(try WorkspaceName.validate("论文📚"), "论文📚")
        XCTAssertEqual(try WorkspaceName.validate(String(repeating: "あ", count: 40)).count, 40)
    }

    func testDuplicateNamesAreCaseInsensitive() {
        let work = WorkspaceRecord(id: "1", name: "Work", createdAt: Date(), updatedAt: Date())
        XCTAssertTrue(WorkspaceName.isDuplicate("work", among: [work]))
        XCTAssertTrue(WorkspaceName.isDuplicate("  WORK  ", among: [work]))
        XCTAssertFalse(WorkspaceName.isDuplicate("Study", among: [work]))
        XCTAssertFalse(WorkspaceName.isDuplicate("Work", among: [work], excluding: "1"))
    }

    func testDefaultWorkspaceSortsFirst() {
        let later = WorkspaceRecord(
            id: UUID().uuidString,
            name: "写论文",
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let earlier = WorkspaceRecord(
            id: UUID().uuidString,
            name: "写代码",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let sorted = WorkspaceCatalog.sorted([later, WorkspaceRecord.makeDefault(at: Date(timeIntervalSince1970: 999)), earlier])
        XCTAssertEqual(sorted.map(\.id), [WorkspaceRecord.defaultID, earlier.id, later.id])
    }
}

final class WorkspaceVisibilityPolicyTests: XCTestCase {
    func testThreeLayerPolicy() {
        XCTAssertTrue(
            PanelVisibilityPolicy.shouldPresent(
                panelHidden: false,
                panelWorkspaceID: "work",
                activeWorkspaceID: "work",
                globallyConcealed: false
            )
        )
        XCTAssertFalse(
            PanelVisibilityPolicy.shouldPresent(
                panelHidden: false,
                panelWorkspaceID: "study",
                activeWorkspaceID: "work",
                globallyConcealed: false
            )
        )
        XCTAssertFalse(
            PanelVisibilityPolicy.shouldPresent(
                panelHidden: true,
                panelWorkspaceID: "work",
                activeWorkspaceID: "work",
                globallyConcealed: false
            )
        )
        XCTAssertFalse(
            PanelVisibilityPolicy.shouldPresent(
                panelHidden: false,
                panelWorkspaceID: "work",
                activeWorkspaceID: "work",
                globallyConcealed: true
            )
        )
    }

    func testWorkspaceSwitchDoesNotChangeHiddenFlags() {
        let a = GlanceTestFixtures.sampleRecord()
        a.workspaceID = "work"
        a.isHidden = false
        let b = GlanceTestFixtures.sampleRecord(id: UUID())
        b.workspaceID = "work"
        b.isHidden = true
        let c = GlanceTestFixtures.sampleRecord(id: UUID())
        c.workspaceID = "study"
        c.isHidden = false

        func visible(active: String, global: Bool) -> [Bool] {
            [a, b, c].map {
                PanelVisibilityPolicy.shouldPresent(
                    panelHidden: $0.isHidden,
                    panelWorkspaceID: $0.workspaceID,
                    activeWorkspaceID: active,
                    globallyConcealed: global
                )
            }
        }

        XCTAssertEqual(visible(active: "work", global: false), [true, false, false])
        XCTAssertEqual(visible(active: "study", global: false), [false, false, true])
        XCTAssertEqual(visible(active: "study", global: true), [false, false, false])
        XCTAssertEqual(visible(active: "study", global: false), [false, false, true])
        XCTAssertFalse(a.isHidden)
        XCTAssertTrue(b.isHidden)
        XCTAssertFalse(c.isHidden)
    }

    func testNewPanelMembershipFallback() {
        XCTAssertEqual(
            WorkspaceMembership.idForNewPanel(activeID: "study", availableIDs: ["default", "study"]),
            "study"
        )
        XCTAssertEqual(
            WorkspaceMembership.idForNewPanel(activeID: "missing", availableIDs: ["default"]),
            WorkspaceRecord.defaultID
        )
    }

    func testActiveWorkspaceResolverFallback() {
        XCTAssertEqual(
            ActiveWorkspaceResolver.resolve(storedID: "study", availableIDs: ["default", "study"]),
            "study"
        )
        XCTAssertEqual(
            ActiveWorkspaceResolver.resolve(storedID: "missing", availableIDs: ["default", "study"]),
            WorkspaceRecord.defaultID
        )
        XCTAssertEqual(
            ActiveWorkspaceResolver.resolve(storedID: nil, availableIDs: ["default"]),
            WorkspaceRecord.defaultID
        )
    }
}

@MainActor
final class WorkspaceMigrationTests: XCTestCase {
    func testV2MigratesToDefaultWithoutChangingPanelState() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV2EnvelopeJSON.utf8))
        XCTAssertTrue(decoded.migratedFromLegacy)
        XCTAssertEqual(decoded.database.schemaVersion, PanelDatabase.currentSchemaVersion)
        XCTAssertEqual(decoded.database.workspaces.map(\.id), [WorkspaceRecord.defaultID])
        XCTAssertEqual(decoded.database.workspaces.first?.name, "默认")
        XCTAssertEqual(decoded.database.panels.count, 2)
        let hidden = try XCTUnwrap(decoded.database.panels.first { $0.id.uuidString == "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA" })
        let visible = try XCTUnwrap(decoded.database.panels.first { $0.id.uuidString == "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB" })
        XCTAssertTrue(hidden.isHidden)
        XCTAssertFalse(visible.isHidden)
        XCTAssertNil(hidden.customTitle)
        XCTAssertNil(visible.customTitle)
        XCTAssertEqual(hidden.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertEqual(visible.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertEqual(hidden.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z"))
        XCTAssertEqual(visible.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:10:00Z"))
        XCTAssertEqual(visible.frame.x, 200)
        XCTAssertEqual(visible.opacity, 0.5, accuracy: 0.0001)
        XCTAssertTrue(visible.isLocked)
        XCTAssertNil(
            (try JSONSerialization.jsonObject(with: Data(GlanceTestFixtures.schemaV2EnvelopeJSON.utf8)) as? [String: Any])
                .flatMap { ($0["panels"] as? [[String: Any]])?.first?["workspaceID"] }
        )
    }

    func testV1MigratesHiddenFalseAndDefaultWorkspace() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV1EnvelopeJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, PanelDatabase.currentSchemaVersion)
        XCTAssertNil(decoded.database.panels.first?.customTitle)
        XCTAssertEqual(decoded.database.workspaces.map(\.id), [WorkspaceRecord.defaultID])
        XCTAssertEqual(decoded.database.panels.first?.isHidden, false)
        XCTAssertEqual(decoded.database.panels.first?.workspaceID, WorkspaceRecord.defaultID)
    }

    func testSchema0MigratesToV3() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.legacyArrayJSON.utf8))
        XCTAssertTrue(decoded.migratedFromLegacy)
        XCTAssertEqual(decoded.database.schemaVersion, PanelDatabase.currentSchemaVersion)
        XCTAssertNil(decoded.database.panels.first?.customTitle)
        XCTAssertEqual(decoded.database.workspaces.first?.id, WorkspaceRecord.defaultID)
        XCTAssertEqual(decoded.database.panels.first?.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertFalse(decoded.database.panels.first?.isHidden ?? true)
    }

    func testFutureSchemaRejectedAndBytesUnchanged() throws {
        try withTempRepository { _, metadataURL in
            let original = Data(GlanceTestFixtures.futureSchemaJSON.utf8)
            try original.write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .unsupportedFutureSchema(5))
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
        }
    }

    func testV2FileRewritesAsSchema3WithoutChangingUpdatedAt() throws {
        try withTempRepository { _, metadataURL in
            try Data(GlanceTestFixtures.schemaV2EnvelopeJSON.utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .loaded(migratedFromLegacy: true))
            let hidden = try XCTUnwrap(try repository.all().first { $0.isHidden })
            XCTAssertEqual(hidden.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(hidden.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z"))
            let rewritten = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            XCTAssertEqual(rewritten.database.schemaVersion, PanelDatabase.currentSchemaVersion)
            XCTAssertEqual(rewritten.database.workspaces.map(\.id), [WorkspaceRecord.defaultID])
            XCTAssertFalse(rewritten.migratedFromLegacy)
        }
    }

    func testMissingDefaultWorkspaceIsEnsuredInMemoryWithoutRewrite() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            record.workspaceID = WorkspaceRecord.defaultID
            let data = try PanelDatabaseCodec.encode(
                PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, workspaces: [], panels: [record])
            )
            try data.write(to: metadataURL)
            let original = try Data(contentsOf: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .loaded(migratedFromLegacy: false))
            XCTAssertEqual(try repository.workspace(id: WorkspaceRecord.defaultID)?.id, WorkspaceRecord.defaultID)
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
        }
    }

    func testOrphanWorkspaceIDFallsBackInMemoryWithoutRewrite() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            record.workspaceID = "missing-id"
            let data = try PanelDatabaseCodec.encode(
                PanelDatabase(
                    schemaVersion: PanelDatabase.currentSchemaVersion,
                    workspaces: [WorkspaceRecord.makeDefault(at: Date(timeIntervalSince1970: 1))],
                    panels: [record]
                )
            )
            try data.write(to: metadataURL)
            let original = try Data(contentsOf: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try repository.record(id: record.id)?.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
        }
    }

    private func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        try WorkspaceTestSupport.withTempRepository(body)
    }
}

@MainActor
final class WorkspaceRepositoryTests: XCTestCase {
    func testCreateWorkspacePersists() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let created = try repository.createWorkspace(name: "  写论文  ")
            XCTAssertEqual(created.name, "写论文")
            XCTAssertNotEqual(created.id, WorkspaceRecord.defaultID)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try reloaded.allWorkspaces().map(\.name), ["默认", "写论文"])
            XCTAssertEqual(try reloaded.workspace(id: created.id)?.name, "写论文")
        }
    }

    func testCreateDuplicateNameRejected() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            _ = try repository.createWorkspace(name: "Work")
            XCTAssertThrowsError(try repository.createWorkspace(name: "work")) { error in
                XCTAssertEqual(error as? WorkspaceError, .duplicateName)
            }
            XCTAssertEqual(try repository.allWorkspaces().count, 2)
        }
    }

    func testCreateSaveFailureDoesNotRetainWorkspace() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.createWorkspace(name: "写论文")) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(try repository.allWorkspaces().map(\.id), [WorkspaceRecord.defaultID])
            XCTAssertFalse(FileManager.default.fileExists(atPath: metadataURL.path))
        }
    }

    func testRenameDoesNotChangePanelMembership() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let workspace = try repository.createWorkspace(name: "写论文")
            let panel = GlanceTestFixtures.sampleRecord()
            panel.workspaceID = workspace.id
            try repository.insert(panel)
            try repository.renameWorkspace(id: workspace.id, name: "Thesis")
            XCTAssertEqual(try repository.workspace(id: workspace.id)?.name, "Thesis")
            XCTAssertEqual(try repository.record(id: panel.id)?.workspaceID, workspace.id)
        }
    }

    func testRenameDefaultRejected() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertThrowsError(try repository.renameWorkspace(id: WorkspaceRecord.defaultID, name: "Home")) { error in
                XCTAssertEqual(error as? WorkspaceError, .cannotRenameDefault)
            }
            XCTAssertEqual(try repository.workspace(id: WorkspaceRecord.defaultID)?.name, "默认")
        }
    }

    func testDeleteMovesPanelsToDefaultInOneTransaction() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let study = try repository.createWorkspace(name: "Study")
            let a = GlanceTestFixtures.sampleRecord()
            a.workspaceID = study.id
            let b = GlanceTestFixtures.sampleRecord(id: UUID())
            b.workspaceID = study.id
            try repository.insert(a)
            try repository.insert(b)
            try repository.deleteWorkspace(id: study.id)
            XCTAssertNil(try repository.workspace(id: study.id))
            XCTAssertEqual(try repository.record(id: a.id)?.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(try repository.record(id: b.id)?.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(try repository.all().count, 2)
        }
    }

    func testDeleteSaveFailureRestoresWorkspaceAndMembership() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let study = try repository.createWorkspace(name: "Study")
            let a = GlanceTestFixtures.sampleRecord()
            a.workspaceID = study.id
            let b = GlanceTestFixtures.sampleRecord(id: UUID())
            b.workspaceID = study.id
            try repository.insert(a)
            try repository.insert(b)
            let oldAUpdated = a.updatedAt
            let oldBUpdated = b.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.deleteWorkspace(id: study.id)) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(try repository.workspace(id: study.id)?.name, "Study")
            XCTAssertEqual(a.workspaceID, study.id)
            XCTAssertEqual(b.workspaceID, study.id)
            XCTAssertEqual(a.updatedAt, oldAUpdated)
            XCTAssertEqual(b.updatedAt, oldBUpdated)
        }
    }

    func testDeleteDefaultRejected() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertThrowsError(try repository.deleteWorkspace(id: WorkspaceRecord.defaultID)) { error in
                XCTAssertEqual(error as? WorkspaceError, .cannotDeleteDefault)
            }
            XCTAssertNotNil(try repository.workspace(id: WorkspaceRecord.defaultID))
        }
    }

    func testMovePanelUpdatesWorkspaceAndTimestamp() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let study = try repository.createWorkspace(name: "Study")
            let panel = GlanceTestFixtures.sampleRecord()
            try repository.insert(panel)
            let oldUpdated = panel.updatedAt
            try repository.movePanel(id: panel.id, toWorkspaceID: study.id)
            XCTAssertEqual(panel.workspaceID, study.id)
            XCTAssertGreaterThan(panel.updatedAt, oldUpdated)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try reloaded.record(id: panel.id)?.workspaceID, study.id)
        }
    }

    func testMoveToSameWorkspaceIsNoOp() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let panel = GlanceTestFixtures.sampleRecord()
            try repository.insert(panel)
            let oldUpdated = panel.updatedAt
            try repository.movePanel(id: panel.id, toWorkspaceID: WorkspaceRecord.defaultID)
            XCTAssertEqual(panel.updatedAt, oldUpdated)
        }
    }

    func testMoveSaveFailureRestoresMembership() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let study = try repository.createWorkspace(name: "Study")
            let panel = GlanceTestFixtures.sampleRecord()
            try repository.insert(panel)
            let oldUpdated = panel.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.movePanel(id: panel.id, toWorkspaceID: study.id)) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(panel.workspaceID, WorkspaceRecord.defaultID)
            XCTAssertEqual(panel.updatedAt, oldUpdated)
        }
    }

    func testMoveToMissingWorkspaceRejected() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let panel = GlanceTestFixtures.sampleRecord()
            try repository.insert(panel)
            XCTAssertThrowsError(try repository.movePanel(id: panel.id, toWorkspaceID: "missing")) { error in
                XCTAssertEqual(error as? WorkspaceError, .workspaceNotFound)
            }
            XCTAssertEqual(panel.workspaceID, WorkspaceRecord.defaultID)
        }
    }

    func testEmptyDatabaseHasDefaultWorkspace() throws {
        try WorkspaceTestSupport.withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try repository.allWorkspaces().map(\.id), [WorkspaceRecord.defaultID])
        }
    }
}

final class WorkspacePreferenceStoreTests: XCTestCase {
    func testPersistsActiveIDAndFallsBack() {
        let name = "GlanceWorkspace-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WorkspacePreferenceStore(defaults: defaults)
        XCTAssertNil(store.activeWorkspaceID())
        store.setActiveWorkspaceID("study")
        XCTAssertEqual(store.activeWorkspaceID(), "study")
        XCTAssertEqual(
            ActiveWorkspaceResolver.resolve(
                storedID: store.activeWorkspaceID(),
                availableIDs: [WorkspaceRecord.defaultID]
            ),
            WorkspaceRecord.defaultID
        )
    }
}

@MainActor
final class WorkspaceSummaryAndMenuTests: XCTestCase {
    func testSummaryWorkspaceIDComesFromRecord() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.workspaceID = "study"
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceWorkspaceSummary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(
            PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory).workspaceID,
            "study"
        )
    }

    func testManagerListsOnlyActiveWorkspace() {
        let work = summary(title: "API", workspaceID: "work")
        let study = summary(title: "PDF", workspaceID: "study")
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
        XCTAssertEqual(model.visible.map(\.title), ["API"])
        model.selectedWorkspaceID = "study"
        XCTAssertEqual(model.visible.map(\.title), ["PDF"])
        XCTAssertTrue(model.isCompletelyEmpty == false)
        model.selectedWorkspaceID = WorkspaceRecord.defaultID
        XCTAssertTrue(model.isCompletelyEmpty)
        XCTAssertEqual(model.workspaces.first?.id, WorkspaceRecord.defaultID)
    }

    func testStatusMenuWorkspaceCheckmark() {
        let workspaces = [
            WorkspaceRecord.makeDefault(at: Date(timeIntervalSince1970: 1)),
            WorkspaceRecord(id: "work", name: "Work", createdAt: Date(timeIntervalSince1970: 2), updatedAt: Date(timeIntervalSince1970: 2)),
            WorkspaceRecord(id: "study", name: "Study", createdAt: Date(timeIntervalSince1970: 3), updatedAt: Date(timeIntervalSince1970: 3))
        ]
        let items = WorkspaceMenuModel.items(workspaces: workspaces, activeID: "work")
        XCTAssertEqual(items.map(\.id), [WorkspaceRecord.defaultID, "work", "study"])
        XCTAssertEqual(items.map(\.isActive), [false, true, false])

        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            workspaces: items,
            onQuickCapture: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
        let workspaceItem = menu.items.first { $0.title == "工作区" }
        let titles = workspaceItem?.submenu?.items.map(\.title) ?? []
        XCTAssertEqual(titles.first, "默认")
        XCTAssertEqual(titles[1], "Work")
        XCTAssertEqual(workspaceItem?.submenu?.items[1].state, .on)
        XCTAssertEqual(titles.last, "新建工作区…")
    }

    func testNewPanelUsesActiveWorkspace() {
        let record = PanelRecord(
            kindIdentifier: PanelKind.text,
            frame: PanelFrame(x: 0, y: 0, width: 320, height: 220),
            displayIdentifier: "1",
            payloadPath: "Panels/x",
            payloadVersion: 1,
            workspaceID: WorkspaceMembership.idForNewPanel(
                activeID: "study",
                availableIDs: ["default", "study"]
            )
        )
        XCTAssertEqual(record.workspaceID, "study")
        XCTAssertFalse(record.isHidden)
    }

    private func summary(title: String, workspaceID: String) -> PanelSummary {
        PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.text,
            title: title,
            subtitle: nil,
            preview: "",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: false,
            workspaceID: workspaceID,
            isUnreadable: false
        )
    }
}

enum WorkspaceTestSupport {
    @MainActor
    static func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceWorkspace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, directory.appendingPathComponent("panels.json"))
    }
}
