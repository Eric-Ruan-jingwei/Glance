import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelTitleNormalizationTests: XCTestCase {
    func testNormalizeNilAndBlank() {
        XCTAssertNil(PanelTitle.normalize(nil))
        XCTAssertNil(PanelTitle.normalize(""))
        XCTAssertNil(PanelTitle.normalize("   "))
        XCTAssertNil(PanelTitle.normalize("\n\t"))
        XCTAssertNil(try PanelTitle.validated("   "))
    }

    func testNormalizeNewlinesAndTrim() {
        XCTAssertEqual(PanelTitle.normalize("  API 文档  "), "API 文档")
        XCTAssertEqual(PanelTitle.normalize("API\n文档"), "API 文档")
        XCTAssertEqual(PanelTitle.normalize("API\r\n文档"), "API 文档")
        XCTAssertEqual(PanelTitle.normalize("API\n\n文档"), "API 文档")
    }

    func testUnicodeAndEmoji() {
        XCTAssertEqual(PanelTitle.normalize("具身智能 🤖 论文"), "具身智能 🤖 论文")
        XCTAssertEqual(try PanelTitle.validated("具身智能 🤖 论文"), "具身智能 🤖 论文")
    }

    func testWritePathRejectsTooLongButAllowsMax() throws {
        let allowed = String(repeating: "你", count: PanelTitle.maxLength)
        XCTAssertEqual(try PanelTitle.validated(allowed), allowed)
        XCTAssertThrowsError(try PanelTitle.validated(allowed + "x")) { error in
            XCTAssertEqual(error as? PanelTitleError, .tooLong)
            XCTAssertEqual(
                (error as? PanelTitleError)?.errorDescription,
                "面板名称最多 80 个字符。"
            )
        }
        XCTAssertEqual(PanelTitle.normalize(String(repeating: "a", count: 100))?.count, 100)
    }
}

final class PanelCustomTitleMigrationTests: XCTestCase {
    func testV3MigratesCustomTitleNilWithoutChangingMetadata() throws {
        let original = Data(GlanceTestFixtures.schemaV3EnvelopeJSON.utf8)
        XCTAssertNil(
            (try JSONSerialization.jsonObject(with: original) as? [String: Any])
                .flatMap { ($0["panels"] as? [[String: Any]])?.first?["customTitle"] }
        )
        let decoded = try PanelDatabaseCodec.decode(from: original)
        XCTAssertTrue(decoded.migratedFromLegacy)
        XCTAssertEqual(decoded.database.schemaVersion, 4)
        XCTAssertEqual(decoded.database.workspaces.map(\.id), [WorkspaceRecord.defaultID, "work"])
        let hidden = try XCTUnwrap(decoded.database.panels.first { $0.id.uuidString == "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA" })
        let pdf = try XCTUnwrap(decoded.database.panels.first { $0.id.uuidString == "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB" })
        XCTAssertNil(hidden.customTitle)
        XCTAssertNil(pdf.customTitle)
        XCTAssertTrue(hidden.isHidden)
        XCTAssertFalse(pdf.isHidden)
        XCTAssertEqual(hidden.workspaceID, "work")
        XCTAssertEqual(pdf.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertEqual(hidden.kindIdentifier, PanelKind.text)
        XCTAssertEqual(pdf.kindIdentifier, PanelKind.pdf)
        XCTAssertEqual(hidden.frame.x, 100)
        XCTAssertEqual(pdf.displayIdentifier, "1")
        XCTAssertTrue(hidden.isPinned)
        XCTAssertFalse(hidden.isLocked)
        XCTAssertTrue(pdf.isLocked)
        XCTAssertFalse(hidden.isCollapsed)
        XCTAssertFalse(hidden.isPassThrough)
        XCTAssertEqual(pdf.opacity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(pdf.themeIdentifier, "system")
        XCTAssertEqual(hidden.payloadPath, "Panels/AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
        XCTAssertEqual(pdf.payloadVersion, 1)
        XCTAssertEqual(hidden.createdAt, ISO8601DateFormatter().date(from: "2026-10-02T15:32:51Z"))
        XCTAssertEqual(hidden.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z"))
        XCTAssertEqual(pdf.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:10:00Z"))
    }

    func testV2MigratesToV4WithNilCustomTitle() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV2EnvelopeJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, 4)
        XCTAssertEqual(decoded.database.workspaces.map(\.id), [WorkspaceRecord.defaultID])
        XCTAssertTrue(decoded.database.panels.contains { $0.isHidden && $0.customTitle == nil })
        XCTAssertEqual(
            decoded.database.panels.map(\.workspaceID),
            [WorkspaceRecord.defaultID, WorkspaceRecord.defaultID]
        )
        XCTAssertTrue(decoded.database.panels.allSatisfy { $0.customTitle == nil })
    }

    func testV1MigratesToV4WithNilCustomTitle() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.schemaV1EnvelopeJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, 4)
        XCTAssertEqual(decoded.database.panels.first?.isHidden, false)
        XCTAssertEqual(decoded.database.panels.first?.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertNil(decoded.database.panels.first?.customTitle)
    }

    func testSchema0MigratesToV4WithNilCustomTitle() throws {
        let decoded = try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.legacyArrayJSON.utf8))
        XCTAssertEqual(decoded.database.schemaVersion, 4)
        XCTAssertNil(decoded.database.panels.first?.customTitle)
        XCTAssertEqual(decoded.database.panels.first?.workspaceID, WorkspaceRecord.defaultID)
        XCTAssertEqual(decoded.database.panels.first?.isHidden, false)
    }

    func testFutureSchema5RejectedAndBytesUnchanged() throws {
        XCTAssertThrowsError(try PanelDatabaseCodec.decode(from: Data(GlanceTestFixtures.futureSchemaJSON.utf8))) { error in
            XCTAssertEqual(error as? PanelDatabaseError, .unsupportedFutureSchema(5))
        }
    }
}

@MainActor
final class PanelCustomTitlePersistenceTests: XCTestCase {
    func testCustomTitleRoundTrip() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            record.customTitle = "API 文档"
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(record)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(try reloaded.record(id: record.id)?.customTitle, "API 文档")
            let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
            XCTAssertEqual(root["schemaVersion"] as? Int, 4)
            let panel = try XCTUnwrap((root["panels"] as? [[String: Any]])?.first)
            XCTAssertEqual(panel["customTitle"] as? String, "API 文档")
        }
    }

    func testNilCustomTitleOmitsKey() throws {
        try withTempRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            let repository = try PanelRepository(fileURL: metadataURL)
            try repository.insert(record)
            let reloaded = try PanelRepository(fileURL: metadataURL)
            XCTAssertNil(try reloaded.record(id: record.id)?.customTitle)
            let panel = try XCTUnwrap(
                ((try JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])?["panels"] as? [[String: Any]])?.first
            )
            XCTAssertNil(panel["customTitle"])
        }
    }

    func testDecodeBlankCustomTitleAsNil() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.customTitle = "   "
        let data = try PanelDatabaseCodec.encode(PanelDatabase(panels: [record]))
        let decoded = try PanelDatabaseCodec.decode(from: data)
        XCTAssertNil(decoded.database.panels.first?.customTitle)
    }

    func testOversizedJSONTitleDoesNotRejectDatabase() throws {
        let record = GlanceTestFixtures.sampleRecord()
        record.customTitle = String(repeating: "a", count: 100)
        let data = try PanelDatabaseCodec.encode(PanelDatabase(panels: [record]))
        let decoded = try PanelDatabaseCodec.decode(from: data)
        XCTAssertEqual(decoded.database.panels.first?.customTitle?.count, 100)
        XCTAssertEqual(decoded.database.schemaVersion, 4)
    }

    func testV3FileRewritesAsSchema4WithoutChangingUpdatedAt() throws {
        try withTempRepository { _, metadataURL in
            try Data(GlanceTestFixtures.schemaV3EnvelopeJSON.utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .loaded(migratedFromLegacy: true))
            let hidden = try XCTUnwrap(try repository.all().first { $0.isHidden })
            XCTAssertNil(hidden.customTitle)
            XCTAssertEqual(hidden.workspaceID, "work")
            XCTAssertEqual(hidden.updatedAt, ISO8601DateFormatter().date(from: "2026-10-02T16:00:00Z"))
            let rewritten = try PanelDatabaseCodec.decode(from: Data(contentsOf: metadataURL))
            XCTAssertEqual(rewritten.database.schemaVersion, 4)
            XCTAssertFalse(rewritten.migratedFromLegacy)
            XCTAssertTrue(rewritten.database.panels.allSatisfy { $0.customTitle == nil })
            XCTAssertEqual(rewritten.database.workspaces.map(\.id), [WorkspaceRecord.defaultID, "work"])
        }
    }

    func testRenameSuccessTrimsAndTouches() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            let oldUpdated = record.updatedAt
            try repository.setCustomTitle(id: record.id, title: "  API 文档  ")
            XCTAssertEqual(record.customTitle, "API 文档")
            XCTAssertGreaterThan(record.updatedAt, oldUpdated)
            XCTAssertEqual(try PanelRepository(fileURL: metadataURL).record(id: record.id)?.customTitle, "API 文档")
        }
    }

    func testClearCustomTitleRestoresAutomaticMode() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            record.customTitle = "API 文档"
            try repository.insert(record)
            let oldUpdated = record.updatedAt
            try repository.setCustomTitle(id: record.id, title: "   ")
            XCTAssertNil(record.customTitle)
            XCTAssertGreaterThan(record.updatedAt, oldUpdated)
            XCTAssertNil(try PanelRepository(fileURL: metadataURL).record(id: record.id)?.customTitle)
        }
    }

    func testSameTitleIsNoOp() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            record.customTitle = "API 文档"
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            try repository.setCustomTitle(id: record.id, title: " API 文档 ")
            XCTAssertEqual(record.customTitle, "API 文档")
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testAutomaticModeBlankIsNoOp() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            try repository.setCustomTitle(id: record.id, title: "   ")
            XCTAssertNil(record.customTitle)
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testRenameRollbackRestoresTitleAndTimestamp() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.setCustomTitle(id: record.id, title: "API 文档")) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertNil(record.customTitle)
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testClearRollbackRestoresPreviousTitle() throws {
        try withTempRepository { _, metadataURL in
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(fileURL: metadataURL, writePrimaryMetadata: writer.write)
            let record = GlanceTestFixtures.sampleRecord()
            record.customTitle = "API 文档"
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            writer.shouldFail = true
            XCTAssertThrowsError(try repository.setCustomTitle(id: record.id, title: "   ")) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertEqual(record.customTitle, "API 文档")
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testTooLongTitleRejectedWithoutMutation() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            let disk = try Data(contentsOf: metadataURL)
            let oldUpdated = record.updatedAt
            XCTAssertThrowsError(
                try repository.setCustomTitle(id: record.id, title: String(repeating: "a", count: 81))
            ) { error in
                XCTAssertEqual(error as? PanelTitleError, .tooLong)
            }
            XCTAssertNil(record.customTitle)
            XCTAssertEqual(record.updatedAt, oldUpdated)
            XCTAssertEqual(try Data(contentsOf: metadataURL), disk)
        }
    }

    func testMissingPanelThrows() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertThrowsError(try repository.setCustomTitle(id: UUID(), title: "API 文档")) { error in
                XCTAssertEqual(error as? PanelTitleError, .panelNotFound)
            }
        }
    }

    func testRenamePreservesWorkspaceVisibilityAndLock() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let study = try repository.createWorkspace(name: "Study")
            let record = GlanceTestFixtures.sampleRecord()
            record.workspaceID = study.id
            record.isHidden = true
            record.isLocked = true
            record.isPassThrough = true
            try repository.insert(record)
            try repository.setCustomTitle(id: record.id, title: "毕业论文")
            XCTAssertEqual(record.customTitle, "毕业论文")
            XCTAssertEqual(record.workspaceID, study.id)
            XCTAssertTrue(record.isHidden)
            XCTAssertTrue(record.isLocked)
            XCTAssertTrue(record.isPassThrough)
        }
    }

    func testMoveAfterRenameKeepsCustomTitle() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let study = try repository.createWorkspace(name: "Study")
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            try repository.setCustomTitle(id: record.id, title: "API 文档")
            try repository.movePanel(id: record.id, toWorkspaceID: study.id)
            XCTAssertEqual(record.customTitle, "API 文档")
            XCTAssertEqual(record.workspaceID, study.id)
        }
    }

    func testWorkspaceDeleteKeepsCustomTitle() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let study = try repository.createWorkspace(name: "Study")
            let record = GlanceTestFixtures.sampleRecord()
            record.workspaceID = study.id
            record.customTitle = "API 文档"
            try repository.insert(record)
            try repository.deleteWorkspace(id: study.id)
            XCTAssertEqual(record.customTitle, "API 文档")
            XCTAssertEqual(record.workspaceID, WorkspaceRecord.defaultID)
        }
    }

    func testRenameDoesNotRewritePayloadBytes() throws {
        try withTempRepository { directory, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let record = GlanceTestFixtures.sampleRecord()
            try repository.insert(record)
            let payloadDirectory = directory.appendingPathComponent(record.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
            try TextPayloadFile.writePlainText("Hello world", to: payloadDirectory)
            let original = try Data(contentsOf: payloadDirectory.appendingPathComponent(TextPayloadFile.fileName))
            try repository.setCustomTitle(id: record.id, title: "工作笔记")
            XCTAssertEqual(
                try Data(contentsOf: payloadDirectory.appendingPathComponent(TextPayloadFile.fileName)),
                original
            )
        }
    }

    func testDuplicateCustomTitlesAreAllowed() throws {
        try withTempRepository { _, metadataURL in
            let repository = try PanelRepository(fileURL: metadataURL)
            let a = GlanceTestFixtures.sampleRecord()
            let b = GlanceTestFixtures.sampleRecord(id: UUID())
            try repository.insert(a)
            try repository.insert(b)
            try repository.setCustomTitle(id: a.id, title: "API 文档")
            try repository.setCustomTitle(id: b.id, title: "API 文档")
            XCTAssertEqual(try repository.record(id: a.id)?.customTitle, "API 文档")
            XCTAssertEqual(try repository.record(id: b.id)?.customTitle, "API 文档")
        }
    }

    private func withTempRepository(_ body: (URL, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceCustomTitle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory, directory.appendingPathComponent("panels.json"))
    }
}

@MainActor
final class PanelCustomTitleSummaryTests: XCTestCase {
    func testCustomTitleOverridesAutomaticText() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try TextPayloadFile.writePlainText("Prepare investor meeting\nMore", to: directory)
        let record = GlanceTestFixtures.sampleRecord()
        record.kindIdentifier = PanelKind.text
        let automatic = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertEqual(automatic.title, "Prepare investor meeting")
        XCTAssertEqual(automatic.automaticTitle, "Prepare investor meeting")
        XCTAssertNil(automatic.customTitle)

        record.customTitle = "融资准备"
        let custom = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertEqual(custom.title, "融资准备")
        XCTAssertEqual(custom.automaticTitle, "Prepare investor meeting")
        XCTAssertEqual(custom.customTitle, "融资准备")
    }

    func testPDFCustomTitleLeavesSubtitleAndDisplayName() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try GlanceTestPDF.data(pageCount: 2).write(to: PDFPayloadFile.documentURL(in: directory))
        let metadata = PDFDocumentMetadata(version: 1, displayName: "Robot Learning Survey.pdf", pageCount: 42)
        try PDFPayloadFile.writeMetadata(metadata, to: directory)
        let originalJSON = try Data(contentsOf: PDFPayloadFile.metadataURL(in: directory))
        let originalPDF = try Data(contentsOf: PDFPayloadFile.documentURL(in: directory))
        let record = GlanceTestFixtures.sampleRecord()
        record.kindIdentifier = PanelKind.pdf
        record.customTitle = "论文"
        let summary = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertEqual(summary.title, "论文")
        XCTAssertEqual(summary.automaticTitle, "Robot Learning Survey")
        XCTAssertEqual(summary.subtitle, "PDF · 42 页")
        XCTAssertEqual(summary.preview, "Robot Learning Survey.pdf")
        XCTAssertEqual(try Data(contentsOf: PDFPayloadFile.metadataURL(in: directory)), originalJSON)
        XCTAssertEqual(try Data(contentsOf: PDFPayloadFile.documentURL(in: directory)), originalPDF)
        XCTAssertEqual(try PDFPayloadFile.readMetadata(from: directory)?.displayName, "Robot Learning Survey.pdf")
    }

    func testTodoCustomTitleLeavesSubtitle() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var document = TodoDocument.empty
        XCTAssertNotNil(TodoMutation.add(&document, text: "完成论文"))
        XCTAssertNotNil(TodoMutation.add(&document, text: "Second"))
        document.items[0].isCompleted = true
        try TodoPayloadFile.writeDocument(document, to: directory)
        let original = try Data(contentsOf: directory.appendingPathComponent(TodoPayloadFile.fileName))
        let record = GlanceTestFixtures.sampleRecord()
        record.kindIdentifier = PanelKind.todo
        record.customTitle = "本周任务"
        let summary = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertEqual(summary.title, "本周任务")
        XCTAssertEqual(summary.automaticTitle, "Second")
        XCTAssertEqual(summary.subtitle, "1 / 2 已完成")
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(TodoPayloadFile.fileName)), original)
    }

    func testUnreadablePayloadKeepsCustomTitleAndWarning() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{not-json".utf8).write(to: directory.appendingPathComponent(TodoPayloadFile.fileName))
        let record = GlanceTestFixtures.sampleRecord()
        record.kindIdentifier = PanelKind.todo
        record.customTitle = "项目资料"
        let summary = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertEqual(summary.title, "项目资料")
        XCTAssertEqual(summary.automaticTitle, PanelSummaryFallback.unreadable)
        XCTAssertTrue(summary.isUnreadable)
    }

    func testImageCustomTitle() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let record = GlanceTestFixtures.sampleRecord()
        record.kindIdentifier = PanelKind.image
        record.customTitle = "官网视觉参考"
        let summary = PanelSummaryBuilder.summarize(record: record, payloadDirectory: directory)
        XCTAssertEqual(summary.title, "官网视觉参考")
        XCTAssertEqual(summary.automaticTitle, PanelSummaryFallback.image)
        XCTAssertEqual(summary.subtitle, "PNG")
    }

    func testSearchMatchesCustomAndAutomaticAndPreview() {
        let summary = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.pdf,
            title: "项目资料",
            subtitle: "PDF · 42 页",
            preview: "Robot Learning Survey.pdf",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: false,
            automaticTitle: "Robot Learning Survey",
            customTitle: "项目资料",
            isUnreadable: false
        )
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "项目资料"))
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "Robot Learning"))
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "42"))
        XCTAssertTrue(PanelSummaryQuery.matches(summary, query: "Survey.pdf"))
        XCTAssertFalse(PanelSummaryQuery.matches(summary, query: "missing"))
    }

    func testWorkspaceFilterUnchangedByCustomTitle() {
        let work = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.text,
            title: "API 文档",
            subtitle: nil,
            preview: "Stripe payment API",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: false,
            workspaceID: "work",
            automaticTitle: "Stripe payment API",
            customTitle: "API 文档",
            isUnreadable: false
        )
        let study = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.text,
            title: "笔记",
            subtitle: nil,
            preview: "",
            createdAt: Date(),
            updatedAt: Date(),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isHidden: false,
            workspaceID: "study",
            automaticTitle: "笔记",
            customTitle: nil,
            isUnreadable: false
        )
        let filtered = PanelSummaryQuery.filtered(
            [work, study],
            query: "Stripe",
            kind: .all,
            workspaceID: "work"
        )
        XCTAssertEqual(filtered.map(\.id), [work.id])
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceCustomTitleSummary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

final class PanelPlacementOccupancyTests: XCTestCase {
    func testHiddenAndOtherWorkspaceDoNotOccupyPlacement() {
        XCTAssertTrue(
            PanelPlacementOccupancy.shouldOccupy(
                workspaceID: "work",
                isHidden: false,
                activeWorkspaceID: "work"
            )
        )
        XCTAssertFalse(
            PanelPlacementOccupancy.shouldOccupy(
                workspaceID: "work",
                isHidden: true,
                activeWorkspaceID: "work"
            )
        )
        XCTAssertFalse(
            PanelPlacementOccupancy.shouldOccupy(
                workspaceID: "study",
                isHidden: false,
                activeWorkspaceID: "work"
            )
        )
    }
}
