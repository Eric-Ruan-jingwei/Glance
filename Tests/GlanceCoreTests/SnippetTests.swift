import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class SnippetPolicyTests: XCTestCase {
    func testSchemasStayIndependent() {
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(LinkDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(SnippetPolicy.maximumContentBytes, 256 * 1024)
        XCTAssertEqual(ShortcutAction.snippets.title, "片段库")
        XCTAssertEqual(ShortcutDefaults.snippets.key, "s")
        XCTAssertEqual(GlanceHotKeyID.snippets.rawValue, 6)
    }

    func testCodecPreservesExactWhitespaceEmojiAndUnicode() throws {
        let content = "  hello\n\nworld\t 🎉\n中文\tindent"
        let record = SnippetRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            title: "标题",
            content: content,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            lastUsedAt: Date(timeIntervalSince1970: 30),
            isPinned: true
        )
        let data = try SnippetCodec.makeEncoder().encode(SnippetDatabase(items: [record]))
        let decoded = try SnippetCodec.decode(from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.items.first?.content, content)
        XCTAssertEqual(decoded.items, [record])
    }

    func testValidationRejectsWhitespaceAndOversizedContent() {
        XCTAssertEqual(SnippetValidation.validate(content: "   \n\t"), .emptyContent)
        XCTAssertNil(SnippetValidation.validate(content: "  hello  "))
        let huge = String(repeating: "a", count: SnippetPolicy.maximumContentBytes + 1)
        XCTAssertEqual(SnippetValidation.validate(content: huge), .contentTooLarge)
    }

    func testTitleGeneratorUsesFirstNonEmptyLine() {
        XCTAssertEqual(
            SnippetTitleGenerator.makeTitle(from: "\n   公司简介   \n第二行"),
            "公司简介"
        )
        let long = String(repeating: "字", count: 80)
        XCTAssertEqual(
            SnippetTitleGenerator.makeTitle(from: long).count,
            SnippetPolicy.maximumGeneratedTitleLength
        )
        XCTAssertEqual(SnippetTitleGenerator.makeTitle(from: "\n\n"), SnippetPolicy.untitledFallback)
        XCTAssertEqual(
            SnippetTitleGenerator.resolvedTitle(draftTitle: "  邮箱  ", content: "hello@example.com"),
            "邮箱"
        )
        XCTAssertEqual(
            SnippetTitleGenerator.resolvedTitle(draftTitle: "   ", content: "Hello\nWorld"),
            "Hello"
        )
    }

    func testSearchMatchesTitleAndContent() {
        let record = SnippetRecord(
            id: UUID(),
            title: "Café",
            content: "Hello WORLD",
            createdAt: Date(),
            updatedAt: Date(),
            lastUsedAt: Date(),
            isPinned: false
        )
        XCTAssertTrue(SnippetSearch.matches(record, query: "cafe"))
        XCTAssertTrue(SnippetSearch.matches(record, query: "world"))
        XCTAssertFalse(SnippetSearch.matches(record, query: "zip"))
    }

    func testSortPinsFirstThenLastUsedDescending() {
        let oldPinned = makeRecord(title: "old pin", lastUsed: 1, pinned: true)
        let newUnpinned = makeRecord(title: "new", lastUsed: 9, pinned: false)
        let newerPinned = makeRecord(title: "new pin", lastUsed: 5, pinned: true)
        XCTAssertEqual(
            SnippetSort.displayed([newUnpinned, oldPinned, newerPinned], query: "").map(\.title),
            ["new pin", "old pin", "new"]
        )
    }

    func testKeyboardActions() {
        XCTAssertEqual(SnippetActionPolicy.action(keyCode: 36, characters: "\r", command: false), .copy)
        XCTAssertEqual(SnippetActionPolicy.action(keyCode: 36, characters: "\r", command: true), .edit)
        XCTAssertEqual(SnippetActionPolicy.action(keyCode: 45, characters: "n", command: true), .create)
        XCTAssertEqual(SnippetActionPolicy.action(keyCode: 51, characters: nil, command: false), .delete)
        XCTAssertEqual(SnippetActionPolicy.action(keyCode: 53, characters: nil, command: false), .dismiss)
    }

    func testClipboardHandoffIsTextOnlyAndExact() {
        let text = ClipboardHistoryRecord(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            lastCopiedAt: Date(),
            isFavorite: true,
            favoritedAt: Date(),
            contentHash: "h",
            text: "  hello\n\nworld\t ",
            assetPath: nil
        )
        let image = ClipboardHistoryRecord(
            id: UUID(),
            kind: .image,
            createdAt: Date(),
            lastCopiedAt: Date(),
            isFavorite: false,
            favoritedAt: nil,
            contentHash: "i",
            text: nil,
            assetPath: "Assets/x.png"
        )
        XCTAssertTrue(ClipboardSnippetHandoff.isAvailable(for: text))
        XCTAssertFalse(ClipboardSnippetHandoff.isAvailable(for: image))
        XCTAssertEqual(ClipboardSnippetHandoff.draft(from: text)?.content, "  hello\n\nworld\t ")
        XCTAssertNil(ClipboardSnippetHandoff.draft(from: image))
    }

    private func makeRecord(title: String, lastUsed: TimeInterval, pinned: Bool) -> SnippetRecord {
        SnippetRecord(
            id: UUID(),
            title: title,
            content: title,
            createdAt: Date(timeIntervalSince1970: lastUsed),
            updatedAt: Date(timeIntervalSince1970: lastUsed),
            lastUsedAt: Date(timeIntervalSince1970: lastUsed),
            isPinned: pinned
        )
    }
}

@MainActor
final class SnippetStoreAndServiceTests: XCTestCase {
    func testCreatePersistsExactContentAndGeneratedTitle() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let created = Date(timeIntervalSince1970: 100)
        let record = try unwrap(harness.service.create(
            SnippetDraft(title: "", content: "  Hello\n\n  World\t "),
            at: created
        ))
        XCTAssertEqual(record.title, "Hello")
        XCTAssertEqual(record.content, "  Hello\n\n  World\t ")
        XCTAssertEqual(record.createdAt, created)
        XCTAssertEqual(record.updatedAt, created)
        XCTAssertEqual(record.lastUsedAt, created)
        XCTAssertEqual(harness.service.records.count, 1)
        let data = try Data(contentsOf: harness.store.metadataURL)
        let decoded = try SnippetCodec.decode(from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.items.first?.content, "  Hello\n\n  World\t ")
    }

    func testIdenticalContentIsNotDeduped() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        _ = try unwrap(harness.service.create(SnippetDraft(title: "A", content: "hello")))
        _ = try unwrap(harness.service.create(SnippetDraft(title: "B", content: "hello")))
        XCTAssertEqual(harness.service.records.count, 2)
    }

    func testEditKeepsIdentityAndLastUsed() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let created = Date(timeIntervalSince1970: 10)
        let record = try unwrap(harness.service.create(
            SnippetDraft(title: "Old", content: "before"),
            at: created
        ))
        let updated = try unwrap(harness.service.update(
            id: record.id,
            draft: SnippetDraft(title: "New", content: "  after\n"),
            at: Date(timeIntervalSince1970: 40)
        ))
        XCTAssertEqual(updated.id, record.id)
        XCTAssertEqual(updated.createdAt, created)
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(updated.lastUsedAt, created)
        XCTAssertEqual(updated.content, "  after\n")
    }

    func testEditorCancelLeavesModelUnchanged() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let record = try unwrap(harness.service.create(SnippetDraft(title: "Keep", content: "exact")))
        let model = SnippetLibraryViewModel(service: harness.service)
        model.beginEdit(id: record.id)
        var session = try XCTUnwrap(model.editor)
        session.draft.content = "changed"
        model.editor = session
        model.cancelEditor()
        XCTAssertNil(model.editor)
        XCTAssertEqual(harness.service.records.first?.content, "exact")
        XCTAssertEqual(harness.service.records.first?.title, "Keep")
    }

    func testPinSortAndRollback() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let older = try unwrap(harness.service.create(
            SnippetDraft(title: "pinned", content: "p"),
            at: Date(timeIntervalSince1970: 1)
        ))
        _ = try unwrap(harness.service.create(
            SnippetDraft(title: "fresh", content: "f"),
            at: Date(timeIntervalSince1970: 9)
        ))
        XCTAssertTrue(harness.service.togglePin(id: older.id))
        XCTAssertEqual(harness.service.displayed(matching: "").map(\.title), ["pinned", "fresh"])
        XCTAssertTrue(harness.service.togglePin(id: older.id))
        XCTAssertEqual(harness.service.displayed(matching: "").map(\.title), ["fresh", "pinned"])

        var failSave = false
        let failing = SnippetStore(root: harness.root.appendingPathComponent("fail"), writePrimaryMetadata: { data, url in
            if failSave { throw SnippetStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = SnippetService(store: failing)
        let record = try unwrap(service.create(SnippetDraft(title: "X", content: "x")))
        failSave = true
        XCTAssertFalse(service.togglePin(id: record.id))
        XCTAssertFalse(service.records[0].isPinned)
    }

    func testDeleteRollback() throws {
        var failSave = false
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippets-\(UUID().uuidString)", isDirectory: true)
        let store = SnippetStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw SnippetStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = SnippetService(store: store)
        defer { try? FileManager.default.removeItem(at: root) }
        let record = try unwrap(service.create(SnippetDraft(title: "Keep", content: "body")))
        failSave = true
        XCTAssertFalse(service.delete(id: record.id))
        XCTAssertEqual(service.records.count, 1)
        failSave = false
        XCTAssertTrue(service.delete(id: record.id))
        XCTAssertTrue(service.records.isEmpty)
    }

    func testMarkUsedRollbackDoesNotInventPersistence() throws {
        var failSave = false
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippets-\(UUID().uuidString)", isDirectory: true)
        let store = SnippetStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw SnippetStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = SnippetService(store: store)
        defer { try? FileManager.default.removeItem(at: root) }
        let created = Date(timeIntervalSince1970: 5)
        let record = try unwrap(service.create(SnippetDraft(title: "A", content: "a"), at: created))
        failSave = true
        XCTAssertFalse(service.markUsed(id: record.id, at: Date(timeIntervalSince1970: 90)))
        XCTAssertEqual(service.records[0].lastUsedAt, created)
    }

    func testCopyFidelityAndOwnWriteSuppression() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let content = "  hello\n\nworld\t "
        let record = try unwrap(harness.service.create(SnippetDraft(title: "T", content: content)))
        let pasteboard = NSPasteboard.withUniqueName()
        let written = MacClipboardWriter.write(.text(record.content), to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), content)
        XCTAssertFalse(
            ClipboardHistoryMonitorPolicy.shouldRead(
                enabled: true,
                lastChangeCount: written,
                currentChangeCount: pasteboard.changeCount
            )
        )
        var captured = 0
        let monitor = ClipboardHistoryMonitor(pasteboard: pasteboard, interval: 30, isEnabled: { true })
        monitor.onCapture = { _ in captured += 1 }
        monitor.start(baselineChangeCount: written)
        monitor.adopt(changeCount: written)
        monitor.tick()
        XCTAssertEqual(captured, 0)
        XCTAssertEqual(harness.service.records.count, 1)
    }

    func testClipboardSaveAsSnippetDoesNotMutateHistory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboard-\(UUID().uuidString)", isDirectory: true)
        let defaultsName = "GlanceClipboardDefaults-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        let clipboard = ClipboardHistoryService(
            store: ClipboardHistoryStore(root: root),
            preferences: ClipboardHistoryPreferenceStore(defaults: defaults)
        )
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let history = try XCTUnwrap(clipboard.record(.text("  公司地址\n二楼  ")))
        clipboard.toggleFavorite(id: history.id)
        let draft = try XCTUnwrap(ClipboardSnippetHandoff.draft(from: history))
        let snippets = try makeHarness()
        defer { snippets.cleanup() }
        _ = try unwrap(snippets.service.create(draft))
        XCTAssertEqual(clipboard.records.count, 1)
        XCTAssertTrue(clipboard.records[0].isFavorite)
        XCTAssertEqual(clipboard.records[0].text, "  公司地址\n二楼  ")
        XCTAssertEqual(snippets.service.records.first?.content, "  公司地址\n二楼  ")
    }

    func testFutureSchemaRejectsWithoutOverwrite() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = root.appendingPathComponent("snippets.json")
        let future = "{ \"schemaVersion\": 2, \"items\": [] }"
        try Data(future.utf8).write(to: metadata)
        let store = SnippetStore(root: root)
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .unsupportedFutureSchema(2))
        XCTAssertFalse(store.isWritable)
        XCTAssertThrowsError(try store.save([]))
        XCTAssertEqual(try String(contentsOf: metadata, encoding: .utf8), future)
        try FileManager.default.removeItem(at: root)
    }

    func testCorruptStoreQuarantinesWithoutTouchingOtherDomains() throws {
        let appRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceApp-\(UUID().uuidString)", isDirectory: true)
        let panelURL = appRoot.appendingPathComponent("Database/panels.json")
        try FileManager.default.createDirectory(at: panelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let panels = "{ \"schemaVersion\": 5, \"workspaces\": [], \"panels\": [] }"
        try Data(panels.utf8).write(to: panelURL)
        let snippetRoot = appRoot.appendingPathComponent("Snippets", isDirectory: true)
        try FileManager.default.createDirectory(at: snippetRoot, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: snippetRoot.appendingPathComponent("snippets.json"))
        let store = SnippetStore(root: snippetRoot)
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .recoveredFromCorruption)
        XCTAssertEqual(try String(contentsOf: panelURL, encoding: .utf8), panels)
        try FileManager.default.removeItem(at: appRoot)
    }

    func testQuarantineFailureLeavesCorruptSnippetsUntouched() throws {
        enum MoveFailure: Error { case denied }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Data("{".utf8)
        let metadata = root.appendingPathComponent("snippets.json")
        try original.write(to: metadata)
        let store = SnippetStore(root: root, moveItem: { _, _ in throw MoveFailure.denied })
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .corruptUnquarantined)
        XCTAssertFalse(store.isWritable)
        XCTAssertEqual(try Data(contentsOf: metadata), original)
        XCTAssertThrowsError(try store.save([]))
        XCTAssertEqual(try Data(contentsOf: metadata), original)
    }

    func testWhitespaceOnlyCreateIsRejected() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        if case .failure(let error) = harness.service.create(SnippetDraft(title: "X", content: "\n  \t")) {
            XCTAssertEqual(error, .emptyContent)
        } else {
            XCTFail("whitespace-only content must be rejected")
        }
        XCTAssertTrue(harness.service.records.isEmpty)
    }

    private func unwrap(_ result: Result<SnippetRecord, SnippetCommitError>) throws -> SnippetRecord {
        switch result {
        case .success(let record):
            return record
        case .failure(let error):
            XCTFail("unexpected \(error)")
            throw error
        }
    }

    private func makeHarness() throws -> SnippetHarness {
        try SnippetHarness()
    }
}

@MainActor
private final class SnippetHarness {
    let root: URL
    let store: SnippetStore
    let service: SnippetService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSnippets-\(UUID().uuidString)", isDirectory: true)
        store = SnippetStore(root: root.appendingPathComponent("Snippets", isDirectory: true))
        service = SnippetService(store: store)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
