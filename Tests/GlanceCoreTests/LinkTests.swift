import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class LinkPolicyTests: XCTestCase {
    func testSchemasStayIndependent() {
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(LinkDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(ShortcutAction.links.title, "链接库")
        XCTAssertEqual(ShortcutDefaults.links.key, "l")
        XCTAssertEqual(ShortcutDefaults.links.command, true)
        XCTAssertEqual(ShortcutDefaults.links.option, true)
        XCTAssertEqual(GlanceHotKeyID.links.rawValue, 7)
        XCTAssertEqual(GlanceHotKeyID.hideShow.rawValue, 1)
        XCTAssertEqual(GlanceHotKeyID.quickCapture.rawValue, 2)
        XCTAssertEqual(GlanceHotKeyID.clipboardCapture.rawValue, 3)
        XCTAssertEqual(GlanceHotKeyID.clipboardHistory.rawValue, 4)
        XCTAssertEqual(GlanceHotKeyID.fileShelf.rawValue, 5)
        XCTAssertEqual(GlanceHotKeyID.snippets.rawValue, 6)
    }

    func testCodecPreservesQueryFragmentEncodingAndUnicodeTitle() throws {
        let url = "https://example.com/a%20b?x=1&q=%E4%B8%AD#part"
        let record = LinkRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            title: "论文 · Glance",
            urlString: url,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            lastOpenedAt: Date(timeIntervalSince1970: 30),
            isPinned: true
        )
        let data = try LinkCodec.makeEncoder().encode(LinkDatabase(items: [record]))
        let decoded = try LinkCodec.decode(from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.items.first?.urlString, url)
        XCTAssertEqual(decoded.items.first?.title, "论文 · Glance")
        XCTAssertEqual(decoded.items, [record])
    }

    func testURLValidationAcceptsHTTPAndHTTPSOnly() {
        XCTAssertEqual(WebLinkPolicy.normalizedURLString("https://example.com"), "https://example.com")
        XCTAssertEqual(WebLinkPolicy.normalizedURLString("http://localhost:3000"), "http://localhost:3000")
        XCTAssertEqual(
            WebLinkPolicy.normalizedURLString("https://example.com/a?x=1#part"),
            "https://example.com/a?x=1#part"
        )
        XCTAssertNil(WebLinkPolicy.normalizedURLString("file:///Users/me/test.pdf"))
        XCTAssertNil(WebLinkPolicy.normalizedURLString("javascript:alert(1)"))
        XCTAssertNil(WebLinkPolicy.normalizedURLString("data:text/plain,abc"))
        XCTAssertNil(WebLinkPolicy.normalizedURLString("mailto:test@example.com"))
        XCTAssertNil(WebLinkPolicy.normalizedURLString("ftp://example.com"))
        XCTAssertNil(WebLinkPolicy.normalizedURLString("plain text"))
        XCTAssertNil(WebLinkPolicy.normalizedURLString("   \n"))
        XCTAssertNil(WebLinkPolicy.normalizedURLString("https://"))
        XCTAssertEqual(LinkValidation.validate("file:///tmp/a"), .unsupportedScheme)
        XCTAssertEqual(LinkValidation.validate("javascript:alert(1)"), .unsupportedScheme)
        XCTAssertEqual(LinkValidation.validate(""), .emptyURL)
        XCTAssertEqual(LinkValidation.validate("   "), .emptyURL)
        XCTAssertEqual(LinkValidation.validate("hello"), .invalidURL)
        XCTAssertEqual(LinkValidation.validate("file:///tmp/a")?.message, "只支持 HTTP / HTTPS 链接")
        XCTAssertEqual(LinkValidation.validate("")?.message, "链接不能为空")
        XCTAssertEqual(LinkValidation.validate("hello")?.message, "链接格式无效")
    }

    func testOuterWhitespaceIsTrimmedWithoutRewritingQueryOrFragment() {
        XCTAssertEqual(
            WebLinkPolicy.normalizedURLString("  https://example.com/a?x=1#part\n"),
            "https://example.com/a?x=1#part"
        )
        XCTAssertEqual(
            WebLinkPolicy.normalizedURLString("\nhttps://example.com/a?x=1#part  "),
            "https://example.com/a?x=1#part"
        )
    }

    func testTitleGeneratorPriorityAndLimit() {
        XCTAssertEqual(
            LinkTitleGenerator.resolvedTitle(
                draftTitle: "  Glance GitHub  ",
                urlString: "https://github.com/Eric-Ruan-jingwei/Glance"
            ),
            "Glance GitHub"
        )
        XCTAssertEqual(
            LinkTitleGenerator.makeTitle(
                from: "https://github.com/Eric-Ruan-jingwei/Glance",
                suggested: "Glance · GitHub"
            ),
            "Glance · GitHub"
        )
        XCTAssertEqual(
            LinkTitleGenerator.makeTitle(from: "https://github.com/Eric-Ruan-jingwei/Glance"),
            "github.com — Glance"
        )
        XCTAssertEqual(
            LinkTitleGenerator.makeTitle(from: "https://www.example.com"),
            "example.com"
        )
        let long = String(repeating: "字", count: 90)
        XCTAssertEqual(LinkTitleGenerator.makeTitle(from: "https://example.com", suggested: long).count, 80)
        XCTAssertEqual(
            LinkTitleGenerator.resolvedTitle(draftTitle: long, urlString: "https://example.com").count,
            80
        )
    }

    func testSearchMatchesTitleURLDomainAndPath() {
        let record = LinkRecord(
            id: UUID(),
            title: "Café Docs",
            urlString: "https://example.com/docs/Glance",
            createdAt: Date(),
            updatedAt: Date(),
            lastOpenedAt: Date(),
            isPinned: false
        )
        XCTAssertTrue(LinkSearch.matches(record, query: "cafe"))
        XCTAssertTrue(LinkSearch.matches(record, query: "EXAMPLE"))
        XCTAssertTrue(LinkSearch.matches(record, query: "docs"))
        XCTAssertTrue(LinkSearch.matches(record, query: "glance"))
        XCTAssertFalse(LinkSearch.matches(record, query: "zip"))
    }

    func testSortPinsFirstThenLastOpenedThenCreated() {
        let olderPinned = makeRecord(title: "old pin", opened: 1, created: 8, pinned: true)
        let newerUnpinned = makeRecord(title: "new", opened: 9, created: 1, pinned: false)
        let newerPinned = makeRecord(title: "new pin", opened: 5, created: 2, pinned: true)
        let tiedOpened = makeRecord(title: "tie newer create", opened: 5, created: 9, pinned: true)
        XCTAssertEqual(
            LinkSort.displayed(
                [newerUnpinned, olderPinned, newerPinned, tiedOpened],
                query: ""
            ).map(\.title),
            ["tie newer create", "new pin", "old pin", "new"]
        )
    }

    func testKeyboardActions() {
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 36, characters: "\r", command: false), .open)
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 36, characters: "\r", command: true), .edit)
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 45, characters: "n", command: true), .create)
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 8, characters: "c", command: true), .copy)
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 51, characters: nil, command: false), .delete)
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 53, characters: nil, command: false), .dismiss)
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 125, characters: nil, command: false), .moveSelection(1))
        XCTAssertEqual(LinkActionPolicy.action(keyCode: 126, characters: nil, command: false), .moveSelection(-1))
    }

    func testDropParserCoversURLNamePlainTextAndMixedProviders() {
        let urlOnly = LinkDropParser.parse([
            LinkDropItem(urlStrings: ["https://example.com"])
        ])
        XCTAssertEqual(urlOnly.accepted, [LinkDropCandidate(urlString: "https://example.com", suggestedTitle: nil)])
        XCTAssertEqual(urlOnly.rejected, 0)

        let named = LinkDropParser.parse([
            LinkDropItem(urlStrings: ["https://github.com/Eric-Ruan-jingwei/Glance"], urlName: "Glance · GitHub")
        ])
        XCTAssertEqual(named.accepted.first?.suggestedTitle, "Glance · GitHub")

        let plain = LinkDropParser.parse(urlStrings: [], plainTexts: ["  https://example.com/a?x=1#part  "])
        XCTAssertEqual(plain.accepted.first?.urlString, "https://example.com/a?x=1#part")

        let invalidPlain = LinkDropParser.parse(urlStrings: [], plainTexts: ["hello"])
        XCTAssertTrue(invalidPlain.accepted.isEmpty)
        XCTAssertEqual(invalidPlain.rejected, 1)

        let file = LinkDropParser.parse([
            LinkDropItem(urlStrings: ["file:///Users/me/test.pdf"])
        ])
        XCTAssertTrue(file.accepted.isEmpty)
        XCTAssertEqual(file.rejected, 1)

        let mixed = LinkDropParser.parse([
            LinkDropItem(urlStrings: ["https://one.example"]),
            LinkDropItem(urlStrings: ["file:///tmp/x"]),
            LinkDropItem(plainTexts: ["https://two.example"]),
            LinkDropItem(plainTexts: ["not a url"])
        ])
        XCTAssertEqual(mixed.accepted.map(\.urlString), ["https://one.example", "https://two.example"])
        XCTAssertEqual(mixed.rejected, 2)

        let sameURLTwice = LinkDropParser.parse([
            LinkDropItem(urlStrings: ["https://example.com"], urlName: "A"),
            LinkDropItem(urlStrings: ["https://example.com"], urlName: "B")
        ])
        XCTAssertEqual(sameURLTwice.accepted.count, 2)
    }

    func testDragOutExposesOnlyValidHTTPURL() {
        XCTAssertEqual(
            LinkDragPayload.urlString(from: "https://example.com/a?x=1#part"),
            "https://example.com/a?x=1#part"
        )
        XCTAssertNil(LinkDragPayload.urlString(from: "file:///tmp/x"))
        XCTAssertNil(LinkDragPayload.urlString(from: "not-a-url"))
    }

    func testClipboardHandoffIsHTTPTextOnly() {
        let url = ClipboardHistoryRecord(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            lastCopiedAt: Date(),
            isFavorite: true,
            favoritedAt: Date(),
            contentHash: "h",
            text: "  https://example.com/a?x=1#part  ",
            assetPath: nil
        )
        let hello = ClipboardHistoryRecord(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            lastCopiedAt: Date(),
            isFavorite: false,
            favoritedAt: nil,
            contentHash: "t",
            text: "hello",
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
        XCTAssertTrue(ClipboardWebLinkHandoff.isAvailable(for: url))
        XCTAssertEqual(
            ClipboardWebLinkHandoff.normalizedURL(from: url),
            "https://example.com/a?x=1#part"
        )
        XCTAssertFalse(ClipboardWebLinkHandoff.isAvailable(for: hello))
        XCTAssertFalse(ClipboardWebLinkHandoff.isAvailable(for: image))
        XCTAssertTrue(ClipboardSnippetHandoff.isAvailable(for: url))
        XCTAssertTrue(ClipboardSnippetHandoff.isAvailable(for: hello))
        XCTAssertFalse(ClipboardSnippetHandoff.isAvailable(for: image))
    }

    func testOpenPolicyValidatesWithoutOpening() {
        let valid = makeRecord(title: "A", opened: 1, created: 1, pinned: false)
        let request = LinkOpenPolicy.request(for: valid)
        XCTAssertEqual(request?.id, valid.id)
        XCTAssertEqual(request?.urlString, valid.urlString)
        var corrupt = valid
        corrupt.urlString = "file:///tmp/x"
        XCTAssertNil(LinkOpenPolicy.request(for: corrupt))
    }

    private func makeRecord(title: String, opened: TimeInterval, created: TimeInterval, pinned: Bool) -> LinkRecord {
        LinkRecord(
            id: UUID(),
            title: title,
            urlString: "https://example.com/\(title)",
            createdAt: Date(timeIntervalSince1970: created),
            updatedAt: Date(timeIntervalSince1970: created),
            lastOpenedAt: Date(timeIntervalSince1970: opened),
            isPinned: pinned
        )
    }
}

@MainActor
final class LinkStoreAndServiceTests: XCTestCase {
    func testCreatePersistsNormalizedURLAndGeneratedTitle() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        let created = Date(timeIntervalSince1970: 100)
        let record = try unwrap(harness.service.create(
            LinkDraft(title: "", urlString: "  https://github.com/Eric-Ruan-jingwei/Glance  "),
            at: created
        ))
        XCTAssertEqual(record.title, "github.com — Glance")
        XCTAssertEqual(record.urlString, "https://github.com/Eric-Ruan-jingwei/Glance")
        XCTAssertEqual(record.createdAt, created)
        XCTAssertEqual(record.updatedAt, created)
        XCTAssertEqual(record.lastOpenedAt, created)
        let decoded = try LinkCodec.decode(from: Data(contentsOf: harness.store.metadataURL))
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.items.first?.urlString, record.urlString)
    }

    func testIdenticalURLsAreNotDeduped() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        _ = try unwrap(harness.service.create(LinkDraft(title: "A", urlString: "https://example.com")))
        _ = try unwrap(harness.service.create(LinkDraft(title: "B", urlString: "https://example.com")))
        XCTAssertEqual(harness.service.records.count, 2)
    }

    func testCreateRollbackRemovesMemoryRecord() throws {
        var failSave = false
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinks-\(UUID().uuidString)", isDirectory: true)
        let store = LinkStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw LinkStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = LinkService(store: store)
        defer { try? FileManager.default.removeItem(at: root) }
        failSave = true
        if case .failure(let error) = service.create(LinkDraft(title: "X", urlString: "https://example.com")) {
            XCTAssertEqual(error, .writeFailed)
        } else {
            XCTFail("create should fail")
        }
        XCTAssertTrue(service.records.isEmpty)
    }

    func testEditKeepsIdentityAndLastOpened() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        let created = Date(timeIntervalSince1970: 10)
        let record = try unwrap(harness.service.create(
            LinkDraft(title: "Old", urlString: "https://example.com/old"),
            at: created
        ))
        let updated = try unwrap(harness.service.update(
            id: record.id,
            draft: LinkDraft(title: "New", urlString: "https://example.com/new?x=1#part"),
            at: Date(timeIntervalSince1970: 40)
        ))
        XCTAssertEqual(updated.id, record.id)
        XCTAssertEqual(updated.createdAt, created)
        XCTAssertEqual(updated.lastOpenedAt, created)
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(updated.urlString, "https://example.com/new?x=1#part")
    }

    func testEditRollbackRestoresPreviousValues() throws {
        var failSave = false
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinks-\(UUID().uuidString)", isDirectory: true)
        let store = LinkStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw LinkStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = LinkService(store: store)
        defer { try? FileManager.default.removeItem(at: root) }
        let record = try unwrap(service.create(LinkDraft(title: "Keep", urlString: "https://example.com")))
        failSave = true
        if case .failure = service.update(
            id: record.id,
            draft: LinkDraft(title: "Changed", urlString: "https://example.com/new")
        ) {
            XCTAssertEqual(service.records[0].title, "Keep")
            XCTAssertEqual(service.records[0].urlString, "https://example.com")
        } else {
            XCTFail("update should fail")
        }
    }

    func testEditorCancelLeavesModelUnchanged() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        let record = try unwrap(harness.service.create(LinkDraft(title: "Keep", urlString: "https://example.com")))
        let model = LinkLibraryViewModel(service: harness.service)
        model.beginEdit(id: record.id)
        var session = try XCTUnwrap(model.editor)
        session.draft.title = "changed"
        session.draft.urlString = "https://example.com/changed"
        model.editor = session
        model.cancelEditor()
        XCTAssertNil(model.editor)
        XCTAssertEqual(harness.service.records.first?.title, "Keep")
        XCTAssertEqual(harness.service.records.first?.urlString, "https://example.com")
    }

    func testPinSortAndRollbackDoesNotTouchLastOpened() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        let older = try unwrap(harness.service.create(
            LinkDraft(title: "pinned", urlString: "https://example.com/p"),
            at: Date(timeIntervalSince1970: 1)
        ))
        _ = try unwrap(harness.service.create(
            LinkDraft(title: "fresh", urlString: "https://example.com/f"),
            at: Date(timeIntervalSince1970: 9)
        ))
        XCTAssertTrue(harness.service.togglePin(id: older.id))
        XCTAssertEqual(harness.service.records.first { $0.id == older.id }?.lastOpenedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(harness.service.displayed(matching: "").map(\.title), ["pinned", "fresh"])

        var failSave = false
        let failing = LinkStore(root: harness.root.appendingPathComponent("fail"), writePrimaryMetadata: { data, url in
            if failSave { throw LinkStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = LinkService(store: failing)
        let record = try unwrap(service.create(LinkDraft(title: "X", urlString: "https://example.com")))
        failSave = true
        XCTAssertFalse(service.togglePin(id: record.id))
        XCTAssertFalse(service.records[0].isPinned)
        XCTAssertEqual(service.records[0].lastOpenedAt, record.lastOpenedAt)
    }

    func testDeleteRollbackRestoresOriginalIndex() throws {
        var failSave = false
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinks-\(UUID().uuidString)", isDirectory: true)
        let store = LinkStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw LinkStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = LinkService(store: store)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try unwrap(service.create(LinkDraft(title: "A", urlString: "https://example.com/a")))
        let second = try unwrap(service.create(LinkDraft(title: "B", urlString: "https://example.com/b")))
        failSave = true
        XCTAssertFalse(service.delete(id: first.id))
        XCTAssertEqual(service.records.map(\.id), [first.id, second.id])
    }

    func testMarkOpenedRollbackRestoresPrevious() throws {
        var failSave = false
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinks-\(UUID().uuidString)", isDirectory: true)
        let store = LinkStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw LinkStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = LinkService(store: store)
        defer { try? FileManager.default.removeItem(at: root) }
        let created = Date(timeIntervalSince1970: 5)
        let record = try unwrap(service.create(
            LinkDraft(title: "A", urlString: "https://example.com"),
            at: created
        ))
        failSave = true
        XCTAssertFalse(service.markOpened(id: record.id, at: Date(timeIntervalSince1970: 90)))
        XCTAssertEqual(service.records[0].lastOpenedAt, created)
    }

    func testOpenRoutingCallsAdapterThenMarkOpened() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        let record = try unwrap(harness.service.create(
            LinkDraft(title: "Glance", urlString: "https://example.com/a?x=1#part")
        ))
        let opener = RecordingLinkOpener()
        var marked: UUID?
        let opened = LinkOpenCoordinator.perform(record: record, opener: opener) { id in
            marked = id
            return harness.service.markOpened(id: id)
        }
        XCTAssertTrue(opened)
        XCTAssertEqual(opener.opened, ["https://example.com/a?x=1#part"])
        XCTAssertEqual(marked, record.id)
        XCTAssertGreaterThan(harness.service.records[0].lastOpenedAt, record.lastOpenedAt)
    }

    func testCopyFidelityAndOwnWriteSuppression() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        let url = "https://example.com/a?x=1#part"
        let record = try unwrap(harness.service.create(LinkDraft(title: "T", urlString: url)))
        let pasteboard = NSPasteboard.withUniqueName()
        let written = MacClipboardWriter.write(.text(record.urlString), to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), url)
        var captured = 0
        let monitor = ClipboardHistoryMonitor(pasteboard: pasteboard, interval: 30, isEnabled: { true })
        monitor.onCapture = { _ in captured += 1 }
        monitor.start(baselineChangeCount: written)
        monitor.adopt(changeCount: written)
        monitor.tick()
        XCTAssertEqual(captured, 0)
    }

    func testClipboardSaveAsLinkDoesNotMutateHistory() throws {
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
        let history = try XCTUnwrap(clipboard.record(.text("  https://example.com/a?x=1#part  ")))
        clipboard.toggleFavorite(id: history.id)
        let url = try XCTUnwrap(ClipboardWebLinkHandoff.normalizedURL(from: history))
        XCTAssertEqual(url, "https://example.com/a?x=1#part")
        let links = try LinkHarness()
        defer { links.cleanup() }
        let model = LinkLibraryViewModel(service: links.service)
        model.beginCreate(prefilledURL: url)
        XCTAssertEqual(model.editor?.draft.urlString, url)
        XCTAssertEqual(model.editor?.focus, .title)
        _ = model.commitEditor()
        XCTAssertEqual(clipboard.records.count, 1)
        XCTAssertTrue(clipboard.records[0].isFavorite)
        XCTAssertEqual(clipboard.records[0].text, "  https://example.com/a?x=1#part  ")
        XCTAssertEqual(links.service.records.first?.urlString, url)
        XCTAssertTrue(ClipboardSnippetHandoff.isAvailable(for: history))
    }

    func testFutureSchemaRejectsWithoutOverwrite() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = root.appendingPathComponent("links.json")
        let future = "{ \"schemaVersion\": 2, \"items\": [] }"
        try Data(future.utf8).write(to: metadata)
        let store = LinkStore(root: root)
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
        let linkRoot = appRoot.appendingPathComponent("Links", isDirectory: true)
        try FileManager.default.createDirectory(at: linkRoot, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: linkRoot.appendingPathComponent("links.json"))
        let store = LinkStore(root: linkRoot)
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .recoveredFromCorruption)
        XCTAssertEqual(try String(contentsOf: panelURL, encoding: .utf8), panels)
        try FileManager.default.removeItem(at: appRoot)
    }

    func testInvalidSchemeCreateIsRejected() throws {
        let harness = try LinkHarness()
        defer { harness.cleanup() }
        if case .failure(let error) = harness.service.create(
            LinkDraft(title: "X", urlString: "javascript:alert(1)")
        ) {
            XCTAssertEqual(error, .unsupportedScheme)
        } else {
            XCTFail("javascript must be rejected")
        }
        XCTAssertTrue(harness.service.records.isEmpty)
    }

    private func unwrap(_ result: Result<LinkRecord, LinkCommitError>) throws -> LinkRecord {
        switch result {
        case .success(let record):
            return record
        case .failure(let error):
            XCTFail("unexpected \(error)")
            throw error
        }
    }
}

private final class RecordingLinkOpener: LinkOpening {
    var opened: [String] = []
    var result = true

    func open(_ urlString: String) -> Bool {
        opened.append(urlString)
        return result
    }
}

@MainActor
private final class LinkHarness {
    let root: URL
    let store: LinkStore
    let service: LinkService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceLinks-\(UUID().uuidString)", isDirectory: true)
        store = LinkStore(root: root.appendingPathComponent("Links", isDirectory: true))
        service = LinkService(store: store)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
