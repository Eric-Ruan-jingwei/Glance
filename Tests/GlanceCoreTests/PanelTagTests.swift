import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelTagNormalizationTests: XCTestCase {
    func testNormalizeTrimNewlinesAndBlanks() {
        XCTAssertEqual(
            PanelTags.normalized([
                " API ",
                "api",
                "",
                "论文",
                "论文",
                "Robot\nLearning"
            ]),
            ["API", "论文", "Robot Learning"]
        )
    }

    func testParseInputSplitsCommasAndNewlines() {
        XCTAssertEqual(PanelTags.parseInput("AI, Robot"), ["AI", "Robot"])
        XCTAssertEqual(PanelTags.parseInput("具身智能，论文"), ["具身智能", "论文"])
        XCTAssertEqual(PanelTags.parseInput("API\n参考"), ["API", "参考"])
    }

    func testUnicodeAndEmoji() {
        XCTAssertEqual(try PanelTags.validated(["机器人🤖"]), ["机器人🤖"])
    }

    func testMaxLengthWriteStrictReadTolerant() throws {
        let allowed = String(repeating: "你", count: 24)
        XCTAssertEqual(try PanelTags.validated([allowed]), [allowed])
        XCTAssertThrowsError(try PanelTags.validated([allowed + "x"])) { error in
            XCTAssertEqual(error as? PanelTagError, .tagTooLong)
            XCTAssertEqual((error as? PanelTagError)?.errorDescription, "标签最多 24 个字符。")
        }
        XCTAssertEqual(PanelTags.normalized([String(repeating: "a", count: 40)]).first?.count, 40)
    }

    func testMaxCountWriteStrict() {
        let twelve = (1...12).map { "t\($0)" }
        XCTAssertEqual(try PanelTags.validated(twelve).count, 12)
        XCTAssertThrowsError(try PanelTags.validated(twelve + ["t13"])) { error in
            XCTAssertEqual(error as? PanelTagError, .tooManyTags)
            XCTAssertEqual((error as? PanelTagError)?.errorDescription, "每个面板最多 12 个标签。")
        }
    }

    func testCatalogDedupeAndSort() {
        let catalog = PanelTags.catalog(["参考", "API", "后端", "api"])
        XCTAssertEqual(catalog.count, 3)
        XCTAssertEqual(catalog.filter { PanelTag.isEqual($0, "API") }, ["API"])
        XCTAssertTrue(catalog.contains("参考"))
        XCTAssertTrue(catalog.contains("后端"))
        XCTAssertEqual(catalog, catalog.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    func testRowPreviewOverflow() {
        let tags = ["API", "支付", "参考", "重要", "Backend"]
        let preview = PanelTags.rowPreview(tags)
        XCTAssertEqual(preview.shown, ["API", "支付", "参考"])
        XCTAssertEqual(preview.overflow, 2)
        XCTAssertEqual(PanelTags.rowPreview(["API"]).overflow, 0)
    }
}

final class PanelTagMigrationTests: XCTestCase {
    func testV4MigratesEmptyTagsWithoutChangingMetadata() throws {
        let original = Data(GlanceTestFixtures.schemaV4EnvelopeJSON.utf8)
        XCTAssertNil(
            (try JSONSerialization.jsonObject(with: original) as? [String: Any])
                .flatMap { ($0["panels"] as? [[String: Any]])?.first?["tags"] }
        )
        let decoded = try PanelDatabaseCodec.decode(from: original)
        XCTAssertTrue(decoded.migratedFromLegacy)
        XCTAssertEqual(decoded.database.schemaVersion, 5)
        let hidden = try XCTUnwrap(decoded.database.panels.first { $0.id.uuidString == "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA" })
        let pdf = try XCTUnwrap(decoded.database.panels.first { $0.id.uuidString == "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB" })
        XCTAssertEqual(hidden.tags, [])
        XCTAssertEqual(pdf.tags, [])
        XCTAssertEqual(hidden.customTitle, "API 文档")
        XCTAssertNil(pdf.customTitle)
        XCTAssertTrue(hidden.isHidden)
        XCTAssertEqual(hidden.workspaceID, "work")
        XCTAssertEqual(pdf.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertEqual(hidden.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z"))
        XCTAssertEqual(pdf.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:10:00Z"))
        XCTAssertEqual(decoded.database.workspaces.map(\.id), [WorkspaceRecord.defaultID, "work"])
    }

    func testV3MigratesToV5WithNilTitleAndEmptyTags() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV3EnvelopeJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, 5)
        XCTAssertTrue(decoded.database.panels.allSatisfy { $0.customTitle == nil && $0.tags.isEmpty })
        XCTAssertEqual(
            decoded.database.panels.first { $0.isHidden }?.workspaceID,
            "work"
        )
    }

    func testV2MigratesToV5() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV2EnvelopeJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, 5)
        XCTAssertTrue(decoded.database.panels.contains { $0.isHidden })
        XCTAssertTrue(decoded.database.panels.allSatisfy {
            $0.workspaceID == WorkspaceRecord.defaultID && $0.customTitle == nil && $0.tags.isEmpty
        })
    }

    func testV1MigratesToV5() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV1EnvelopeJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, 5)
        XCTAssertEqual(decoded.database.panels.first?.isHidden, false)
        XCTAssertEqual(decoded.database.panels.first?.tags, [])
        XCTAssertNil(decoded.database.panels.first?.customTitle)
    }

    func testSchema0MigratesToV5() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.legacyArrayJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, 5)
        XCTAssertEqual(decoded.database.panels.first?.tags, [])
    }

    func testFutureSchema6Rejected() {
        XCTAssertThrowsError(try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.futureSchemaJSON.utf8))) { error in
            XCTAssertEqual(error as? PanelDatabaseError, .unsupportedFutureSchema(6))
        }
    }
}

@MainActor
final class PanelTagPersistenceTests: XCTestCase {
    func testTagsRoundTripEncodesEmptyArray() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            record.tags = ["具身智能", "论文", "必读"]
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(record)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try reloaded.record(id: record.id)?.tags, ["具身智能", "论文", "必读"])
            let panel = try XCTUnwrap(
                ((try JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])?["panels"] as? [[String: Any]])?.first
            )
            XCTAssertEqual(panel["tags"] as? [String], ["具身智能", "论文", "必读"])
        }
    }

    func testEmptyTagsAreEncoded() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(GlanceTestFixtures.sampleRecord())
            let panel = try XCTUnwrap(
                ((try JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])?["panels"] as? [[String: Any]])?.first
            )
            XCTAssertEqual(panel["tags"] as? [String], [])
        }
    }

    func testDirtyJSONNormalizesOnRead() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.tags = [" API ", "api", "", "论文", "论文", "Robot\nLearning"]
        let data = try PanelDatabaseCodec.encode(PanelDatabase(panels: [record]))
        let decoded = try PanelDatabaseCodec.decode(from: data)
        XCTAssertEqual(decoded.database.panels.first?.tags, ["API", "论文", "Robot Learning"])
    }

    func testOversizedTagDoesNotRejectDatabase() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.tags = [String(repeating: "a", count: 40)]
        let data = try PanelDatabaseCodec.encode(PanelDatabase(panels: [record]))
        let decoded = try PanelDatabaseCodec.decode(from: data)
        XCTAssertEqual(decoded.database.panels.first?.tags.first?.count, 40)
    }

    func testV4FileRewritesAsSchema5WithoutChangingUpdatedAt() throws {
        try withTempRepository { _, metadataURL in
            try Data(GlanceTestFixtures.schemaV4EnvelopeJSON.utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .loaded(migratedFromLegacy: true))
            let hidden = try XCTUnwrap(try repository.all().first { $0.isHidden })
            XCTAssertEqual(hidden.tags, [])
            XCTAssertEqual(hidden.customTitle, "API 文档")
            XCTAssertEqual(hidden.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z"))
            let rewritten = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            XCTAssertEqual(rewritten.database.schemaVersion, 5)
            XCTAssertFalse(rewritten.migratedFromLegacy)
        }
    }

    func testSetTagsSuccess() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            let oldUpdated = record.updatedAt
            try repository.setTags(id: record.id, tags: [" API ", "参考"])
            XCTAssertEqual(record.tags, ["API", "参考"])
            XCTAssertGreaterThan(record.updatedAt, oldUpdated)
            XCTAssertEqual(try PanelRepository(fileURL: metadataURL).record(id: record.id)?.tags, ["API", "参考"])
        }
    }

    func testSetTagsNoOp() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            record.tags = ["API", "支付"]
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            try repository.setTags(id: record.id, tags: [" API ", "支付", "api"])
            XCTAssertEqual(record.tags, ["API", "支付"])
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testSetTagsRollback() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.setTags(id: record.id, tags: ["API"])) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(record.tags, [])
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testClearTagsRollback() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let record = GlanceTestFixtures.sampleRecord()
            record.tags = ["API", "参考"]
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.setTags(id: record.id, tags: [])) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(record.tags, ["API", "参考"])
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testSetTagsTooLongRejected() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            XCTAssertThrowsError(try repository.setTags(id: record.id, tags: [String(repeating: "a", count: 25)])) { error in
                XCTAssertEqual(error as? PanelTagError, .tagTooLong)
            }
            XCTAssertEqual(record.tags, [])
        }
    }

    func testRenamePreservesTags() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            record.tags = ["论文"]
            try repository.insert(record)
            try repository.setCustomTitle(id: record.id, title: "VLA 论文")
            XCTAssertEqual(record.tags, ["论文"])
            XCTAssertEqual(record.customTitle, "VLA 论文")
        }
    }

    func testMoveAndDeleteWorkspacePreserveTags() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let study = try repository.createWorkspace(name: "Study")
            let record = GlanceTestFixtures.sampleRecord()
            record.tags = ["API", "参考"]
            try repository.insert(record)
            try repository.movePanel(id: record.id, toWorkspaceID: study.id)
            XCTAssertEqual(record.tags, ["API", "参考"])
            try repository.deleteWorkspace(id: study.id)
            XCTAssertEqual(record.tags, ["API", "参考"])
            XCTAssertEqual(record.workspaceID, WorkspaceRecord.defaultID)
        }
    }

    func testHidePreservesTags() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.tags = ["必读"]
        try PanelVisibilityTransaction.setHidden(
            true,
            on: record,
            touch: { $0.updatedAt = Date() },
            persist: {}
        )
        XCTAssertEqual(record.tags, ["必读"])
        XCTAssertTrue(record.isHidden)
    }

    func testCatalogFromRepository() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = GlanceTestFixtures.sampleRecord()
            a.tags = ["API", "参考"]
            let b = GlanceTestFixtures.sampleRecord(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
            b.tags = ["api", "后端"]
            b.createdAt = Date(timeIntervalSince1970: 1_699_000_100)
            try repository.insert(a)
            try repository.insert(b)
            let names = repository.allTagNames()
            XCTAssertEqual(names.count, 3)
            XCTAssertEqual(names.filter { PanelTag.isEqual($0, "API") }, ["API"])
            XCTAssertTrue(names.contains("参考"))
            XCTAssertTrue(names.contains("后端"))
        }
    }

    private func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTags-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, directory.appendingPathComponent("panels.json"))
    }
}

@MainActor
final class PanelTagSummaryTests: XCTestCase {
    func testSummaryCopiesRecordTags() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let record = GlanceTestFixtures.sampleRecord()
        record.tags = ["具身智能", "必读"]
        let summary = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertEqual(summary.tags, ["具身智能", "必读"])
    }

    func testUnreadablePayloadKeepsTags() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{not-json".utf8).write(to: directory.appendingPathComponent(TodoPayloadFile.fileName))
        let record = GlanceTestFixtures.sampleRecord()
        record.kindIdentifier = PanelKind.todo
        record.customTitle = "项目资料"
        record.tags = ["论文", "归档"]
        let summary = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertTrue(summary.isUnreadable)
        XCTAssertEqual(summary.tags, ["论文", "归档"])
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "归档"))
    }

    func testSearchTagsAndPartial() {
        let summary = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.pdf,
            title: "Robot Learning Survey",
            subtitle: "PDF · 42 页",
            preview: "preview",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: false,
            automaticTitle: "Robot Learning Survey",
            tags: ["具身智能", "必读"],
            isUnreadable: false
        )
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "必读"))
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "具身"))
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "Robot Learning"))
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "42"))
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "preview"))
        XCTAssertFalse(PanelSummaryQuery.matches(summary, query: "missing"))
    }

    func testExactTagFilterDoesNotUseSubstring() {
        let api = tagged("A", tags: ["API"], workspace: "work", kind: PanelKind.text)
        let design = tagged("B", tags: ["API Design"], workspace: "work", kind: PanelKind.pdf)
        XCTAssertEqual(
            PanelSummaryQuery.filtered([api, design], query: "", kind: .all, tag: "API").map(\.title),
            ["A"]
        )
        XCTAssertEqual(
            PanelSummaryQuery.filtered([api, design], query: "", kind: .all, tag: "api").map(\.title),
            ["A"]
        )
    }

    func testCombinedWorkspaceKindTagSearch() {
        let match = tagged(
            "Robot Paper",
            tags: ["必读"],
            workspace: "code",
            kind: PanelKind.pdf,
            preview: "robot notes"
        )
        let wrongWorkspace = tagged("Robot Paper 2", tags: ["必读"], workspace: "study", kind: PanelKind.pdf)
        let wrongKind = tagged("Robot Paper 3", tags: ["必读"], workspace: "code", kind: PanelKind.text)
        let wrongTag = tagged("Robot Paper 4", tags: ["参考"], workspace: "code", kind: PanelKind.pdf)
        let filtered = PanelSummaryQuery.filtered(
            [match, wrongWorkspace, wrongKind, wrongTag],
            query: "robot",
            kind: .pdf,
            workspaceID: "code",
            tag: "必读"
        )
        XCTAssertEqual(filtered.map(\.title), ["Robot Paper"])
    }

    func testWorkspaceSwitchResetsTagFilter() {
        let work = tagged("API Panel", tags: ["API"], workspace: "work")
        let study = tagged("论文", tags: ["必读"], workspace: "study")
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
        model.selectTagFilter("API")
        XCTAssertEqual(model.visible.map(\.title), ["API Panel"])
        model.activateWorkspace("study")
        model.selectedWorkspaceID = "study"
        model.reload()
        XCTAssertNil(model.selectedTag)
        XCTAssertEqual(model.visible.map(\.title), ["论文"])
    }

    func testRemovingLastSelectedTagResetsFilter() {
        let panel = tagged("A", tags: ["必读"], workspace: WorkspaceRecord.defaultID)
        var current = panel
        let model = PanelLibraryModel()
        model.loadSummaries = { [current] }
        model.reload()
        model.selectTagFilter("必读")
        XCTAssertEqual(model.visible.map(\.title), ["A"])
        current.tags = []
        model.loadSummaries = { [current] }
        model.reload()
        XCTAssertNil(model.selectedTag)
    }

    private func tagged(
        _ title: String,
        tags: [String],
        workspace: String,
        kind: String = PanelKind.text,
        preview: String = ""
    ) -> PanelSummary {
        PanelSummary(
            id: UUID(),
            kindIdentifier: kind,
            title: title,
            subtitle: nil,
            preview: preview,
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: false,
            workspaceID: workspace,
            tags: tags,
            isUnreadable: false
        )
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTagSummary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

final class PanelTagEditorSessionTests: XCTestCase {
    func testDraftAddDedupeAndLimit() {
        let session = PanelTagEditorSession(tags: ["API"], catalog: ["API", "参考", "后端"])
        session.input = "api, 参考"
        session.addFromInput()
        XCTAssertEqual(session.draft, ["API", "参考"])
        XCTAssertEqual(session.suggestions, ["后端"])
        session.draft = (1...12).map { "t\($0)" }
        session.input = "t13"
        session.addFromInput()
        XCTAssertEqual(session.draft.count, 12)
        XCTAssertEqual(session.errorMessage, PanelTagError.tooManyTags.errorDescription)
    }
}
