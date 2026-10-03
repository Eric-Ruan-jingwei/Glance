import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class FileShelfPolicyTests: XCTestCase {
    func testSchemaVersionIsIndependent() {
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfPolicy.maximumRecentNonFavorites, 100)
        XCTAssertEqual(FileShelfCopy.removeLabel, "从文件架移除")
        XCTAssertNotEqual(FileShelfCopy.removeLabel, "删除文件")
        XCTAssertEqual(ShortcutAction.fileShelf.title, "文件架")
        XCTAssertEqual(ShortcutDefaults.fileShelf.key, "f")
        XCTAssertEqual(GlanceHotKeyID.fileShelf.rawValue, 5)
        XCTAssertEqual(GlanceHotKeyID.clipboardHistory.rawValue, 4)
    }

    func testSchemaRoundTripOmitsBookmarkBytes() throws {
        let record = FileShelfRecord(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            originalPath: "/tmp/report.pdf",
            displayName: "report.pdf",
            fileSize: 2400,
            contentTypeIdentifier: "pdf",
            createdAt: Date(timeIntervalSince1970: 10),
            lastUsedAt: Date(timeIntervalSince1970: 20),
            isFavorite: true,
            favoritedAt: Date(timeIntervalSince1970: 15)
        )
        let data = try FileShelfCodec.makeEncoder().encode(FileShelfDatabase(items: [record]))
        let decoded = try FileShelfCodec.decode(from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.items, [record])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let item = try XCTUnwrap((object["items"] as? [[String: Any]])?.first)
        XCTAssertNil(item["bookmarkData"])
        XCTAssertNil(item["bookmarkPath"])
        XCTAssertEqual(item["originalPath"] as? String, "/tmp/report.pdf")
    }

    func testSearchMatchesFilenameAndExtension() {
        let record = FileShelfRecord(
            id: UUID(),
            originalPath: "/tmp/Project Plan.PDF",
            displayName: "Project Plan.PDF",
            fileSize: 1,
            contentTypeIdentifier: "pdf",
            createdAt: Date(),
            lastUsedAt: Date(),
            isFavorite: false,
            favoritedAt: nil
        )
        XCTAssertTrue(FileShelfSearch.matches(record, query: ""))
        XCTAssertTrue(FileShelfSearch.matches(record, query: "plan"))
        XCTAssertTrue(FileShelfSearch.matches(record, query: "PDF"))
        XCTAssertFalse(FileShelfSearch.matches(record, query: "zip"))
    }

    func testRecentAndFavoriteSort() {
        let older = makeRecord(name: "a.txt", lastUsed: 1, favorite: false, favorited: nil)
        let newer = makeRecord(name: "b.txt", lastUsed: 3, favorite: true, favorited: 2)
        let mid = makeRecord(name: "c.txt", lastUsed: 2, favorite: true, favorited: 9)
        XCTAssertEqual(FileShelfSearch.recent([older, newer, mid], query: "").map(\.displayName), ["b.txt", "c.txt", "a.txt"])
        XCTAssertEqual(FileShelfSearch.favorites([older, newer, mid], query: "").map(\.displayName), ["c.txt", "b.txt"])
    }

    func testRetentionSkipsFavorites() {
        var records: [FileShelfRecord] = []
        for index in 0..<101 {
            records.append(makeRecord(name: "n\(index).txt", lastUsed: TimeInterval(index), favorite: false, favorited: nil))
        }
        let favorite = makeRecord(name: "keep.pdf", lastUsed: 0, favorite: true, favorited: 1)
        records.append(favorite)
        let evicted = FileShelfRetention.idsToEvict(from: records)
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(evicted.first, records[0].id)
        XCTAssertFalse(evicted.contains(favorite.id))
    }

    func testDropParserAcceptsFileURLsAndIgnoresOthers() {
        let urls = FileShelfDropParser.urls(from: [
            "file:///tmp/a.pdf",
            "/tmp/b.txt",
            "https://example.com/c.pdf",
            ""
        ])
        XCTAssertEqual(urls.map(\.path), ["/tmp/a.pdf", "/tmp/b.txt"])
    }

    func testDragPayloadRequiresExistingFile() {
        XCTAssertEqual(FileShelfDragPayload.fileURL(resolvedPath: "/tmp/a.pdf", fileExists: true), "/tmp/a.pdf")
        XCTAssertNil(FileShelfDragPayload.fileURL(resolvedPath: "/tmp/a.pdf", fileExists: false))
        XCTAssertNil(FileShelfDragPayload.fileURL(resolvedPath: nil, fileExists: true))
    }

    func testKeyboardActions() {
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 36, characters: "\r", command: false), .open)
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 36, characters: "\r", command: true), .reveal)
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 49, characters: " ", command: false), .preview)
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 8, characters: "c", command: true), .copyFile)
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 51, characters: nil, command: false), .remove)
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 53, characters: nil, command: false), .dismiss)
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 18, characters: "1", command: true), .recentTab)
        XCTAssertEqual(FileShelfActionPolicy.action(keyCode: 19, characters: "2", command: true), .favoritesTab)
        XCTAssertFalse(FileShelfActionPolicy.allowsFileAction(missing: true))
        XCTAssertTrue(FileShelfActionPolicy.allowsFileAction(missing: false))
    }

    func testClassifierRejectsDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelfClass-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("note.txt")
        try Data("hi".utf8).write(to: file)
        let folder = root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertEqual(FileShelfClassifier.classify(file), .file)
        XCTAssertEqual(FileShelfClassifier.classify(folder), .directory)
        XCTAssertEqual(FileShelfClassifier.classify(root.appendingPathComponent("gone.txt")), .missing)
    }

    private func makeRecord(
        name: String,
        lastUsed: TimeInterval,
        favorite: Bool,
        favorited: TimeInterval?
    ) -> FileShelfRecord {
        FileShelfRecord(
            id: UUID(),
            originalPath: "/tmp/\(name)",
            displayName: name,
            fileSize: 1,
            contentTypeIdentifier: "txt",
            createdAt: Date(timeIntervalSince1970: lastUsed),
            lastUsedAt: Date(timeIntervalSince1970: lastUsed),
            isFavorite: favorite,
            favoritedAt: favorited.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

@MainActor
final class FileShelfStoreAndServiceTests: XCTestCase {
    func testAddMultipleFilesAndRejectDirectory() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let fileA = try harness.writeFile("report.pdf", contents: Data("pdf".utf8))
        let fileB = try harness.writeFile("notes.md", contents: Data("md".utf8))
        let folder = try harness.writeDirectory("Project")
        let result = harness.service.add(paths: [fileA.path, fileB.path, folder.path])
        XCTAssertEqual(result.addedIDs.count, 2)
        XCTAssertEqual(result.rejectedDirectories, 1)
        XCTAssertEqual(result.notice, FileShelfCopy.partialRejected)
        XCTAssertEqual(harness.service.records.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.store.root.appendingPathComponent("report.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileA.path))
        assertShelfContainsOnlyMetadata(harness.store)
    }

    func testSamePathDedupesAndPreservesFavorite() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let file = try harness.writeFile("same.txt", contents: Data("one".utf8))
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)
        let created = try XCTUnwrap(harness.service.add(paths: [file.path], at: first).addedIDs.first)
        harness.service.toggleFavorite(id: created, at: first)
        let result = harness.service.add(paths: [file.path], at: second)
        XCTAssertEqual(harness.service.records.count, 1)
        XCTAssertEqual(result.updatedIDs, [created])
        let record = try XCTUnwrap(harness.service.records.first)
        XCTAssertEqual(record.id, created)
        XCTAssertEqual(record.lastUsedAt, second)
        XCTAssertTrue(record.isFavorite)
        XCTAssertEqual(record.favoritedAt, first)
    }

    func testSymlinkDedupesToResolvedPath() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let file = try harness.writeFile("target.txt", contents: Data("target".utf8))
        let link = harness.files.appendingPathComponent("alias.txt")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: file.path)
        let first = harness.service.add(paths: [link.path], at: Date(timeIntervalSince1970: 1))
        let second = harness.service.add(paths: [file.path], at: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(first.addedIDs.count, 1)
        XCTAssertEqual(second.updatedIDs, first.addedIDs)
        XCTAssertEqual(harness.service.records.count, 1)
        XCTAssertEqual(harness.service.records.first?.originalPath, FileShelfIdentity.standardizedPath(for: file))
    }

    func testMovedFileIdentityUsesResolvedBookmark() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let original = try harness.writeFile("before.txt", contents: Data("x".utf8))
        let moved = harness.files.appendingPathComponent("after.txt")
        let added = try XCTUnwrap(harness.service.add(paths: [original.path]).addedIDs.first)
        try FileManager.default.moveItem(at: original, to: moved)
        harness.bookmarks.resolvedOverride[FileShelfIdentity.standardizedPath(for: original)] =
            FileShelfIdentity.standardizedPath(for: moved)
        let result = harness.service.add(paths: [moved.path])
        XCTAssertEqual(result.updatedIDs, [added])
        XCTAssertEqual(harness.service.records.count, 1)
    }

    func testRetentionEvictsOldestNonfavoriteBookmarkButLeavesOriginal() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        var originals: [URL] = []
        let start = Date(timeIntervalSince1970: 1_000)
        let favoriteFile = try harness.writeFile("keep.pdf", contents: Data("keep".utf8))
        let favoriteID = try XCTUnwrap(harness.service.add(paths: [favoriteFile.path], at: start).addedIDs.first)
        harness.service.toggleFavorite(id: favoriteID, at: start)
        var firstID: UUID?
        for index in 0..<100 {
            let url = try harness.writeFile("item-\(index).txt", contents: Data("\(index)".utf8))
            originals.append(url)
            let added = harness.service.add(paths: [url.path], at: start.addingTimeInterval(TimeInterval(index + 1)))
            if index == 0 { firstID = added.addedIDs.first }
        }
        XCTAssertEqual(harness.service.records.filter { !$0.isFavorite }.count, 100)
        let overflow = try harness.writeFile("overflow.txt", contents: Data("new".utf8))
        _ = harness.service.add(paths: [overflow.path], at: start.addingTimeInterval(200))
        XCTAssertEqual(harness.service.records.filter { !$0.isFavorite }.count, 100)
        XCTAssertTrue(harness.service.records.contains { $0.id == favoriteID })
        XCTAssertFalse(harness.service.records.contains { $0.displayName == "item-0.txt" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: originals[0].path))
        let evicted = try XCTUnwrap(firstID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.store.bookmarkURL(for: evicted).path))
        let leftoverBookmarks = try FileManager.default.contentsOfDirectory(atPath: harness.store.bookmarksDirectory.path)
        XCTAssertEqual(leftoverBookmarks.count, harness.service.records.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: favoriteFile.path))
    }

    func testRemoveDeletesRecordAndBookmarkButNotOriginal() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let file = try harness.writeFile("keep-me.txt", contents: Data("safe".utf8))
        let id = try XCTUnwrap(harness.service.add(paths: [file.path]).addedIDs.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.store.bookmarkURL(for: id).path))
        harness.service.remove(id: id)
        XCTAssertTrue(harness.service.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.store.bookmarkURL(for: id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testMissingOriginalLeavesRecord() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let file = try harness.writeFile("gone.txt", contents: Data("temp".utf8))
        let id = try XCTUnwrap(harness.service.add(paths: [file.path]).addedIDs.first)
        try FileManager.default.removeItem(at: file)
        harness.bookmarks.failResolvePaths.insert(FileShelfIdentity.standardizedPath(for: file))
        harness.service.reload()
        XCTAssertEqual(harness.service.records.count, 1)
        XCTAssertTrue(harness.service.isMissing(id))
        XCTAssertEqual(harness.service.resolve(id).isMissing, true)
    }

    func testRelinkKeepsIdentityAndFavorite() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let original = try harness.writeFile("old.txt", contents: Data("old".utf8))
        let replacement = try harness.writeFile("new.md", contents: Data("new".utf8))
        let id = try XCTUnwrap(harness.service.add(paths: [original.path]).addedIDs.first)
        harness.service.toggleFavorite(id: id, at: Date(timeIntervalSince1970: 5))
        try FileManager.default.removeItem(at: original)
        harness.bookmarks.failResolvePaths.insert(FileShelfIdentity.standardizedPath(for: original))
        XCTAssertTrue(harness.service.isMissing(id))
        XCTAssertTrue(harness.service.relink(id: id, to: replacement.path, at: Date(timeIntervalSince1970: 9)))
        let record = try XCTUnwrap(harness.service.records.first)
        XCTAssertEqual(record.id, id)
        XCTAssertTrue(record.isFavorite)
        XCTAssertEqual(record.favoritedAt, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(record.displayName, "new.md")
        XCTAssertFalse(harness.service.isMissing(id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.store.bookmarkURL(for: id).path))
    }

    func testBookmarkCreateFailureDoesNotInsertRecord() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let file = try harness.writeFile("blocked.txt", contents: Data("x".utf8))
        harness.bookmarks.failCreate = true
        let result = harness.service.add(paths: [file.path])
        XCTAssertTrue(result.addedIDs.isEmpty)
        XCTAssertEqual(result.failed, 1)
        XCTAssertTrue(harness.service.records.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: harness.store.bookmarksDirectory.path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testMetadataSaveFailureRollsBackBookmark() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelf-\(UUID().uuidString)", isDirectory: true)
        var failSave = false
        let store = FileShelfStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw FileShelfStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let bookmarks = FakeFileShelfBookmarks()
        let service = FileShelfService(store: store, bookmarks: bookmarks)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("files/one.txt")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("one".utf8).write(to: file)
        failSave = true
        let result = service.add(paths: [file.path])
        XCTAssertTrue(result.addedIDs.isEmpty)
        XCTAssertTrue(service.records.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: store.bookmarksDirectory.path).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testRelinkMetadataSaveFailureRestoresPreviousRecordAndBookmark() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelf-\(UUID().uuidString)", isDirectory: true)
        var failSave = false
        let store = FileShelfStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw FileShelfStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let bookmarks = FakeFileShelfBookmarks()
        let service = FileShelfService(store: store, bookmarks: bookmarks)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("files/old.txt")
        let replacement = root.appendingPathComponent("files/new.txt")
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: original)
        try Data("new".utf8).write(to: replacement)
        let id = try XCTUnwrap(service.add(paths: [original.path]).addedIDs.first)
        let previousBookmark = try XCTUnwrap(store.readBookmark(id: id))
        failSave = true
        XCTAssertFalse(service.relink(id: id, to: replacement.path))
        let record = try XCTUnwrap(service.records.first)
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.displayName, "old.txt")
        XCTAssertEqual(store.readBookmark(id: id), previousBookmark)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacement.path))
    }

    func testRelinkMetadataSaveFailureWithoutPreviousBookmarkDeletesWrittenSidecar() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelf-\(UUID().uuidString)", isDirectory: true)
        var failSave = false
        let store = FileShelfStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw FileShelfStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let bookmarks = FakeFileShelfBookmarks()
        let service = FileShelfService(store: store, bookmarks: bookmarks)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("files/old.txt")
        let replacement = root.appendingPathComponent("files/new.txt")
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: original)
        try Data("new".utf8).write(to: replacement)
        let id = try XCTUnwrap(service.add(paths: [original.path]).addedIDs.first)
        store.deleteBookmark(id: id)
        XCTAssertNil(store.readBookmark(id: id))
        failSave = true
        XCTAssertFalse(service.relink(id: id, to: replacement.path))
        let record = try XCTUnwrap(service.records.first)
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.displayName, "old.txt")
        XCTAssertEqual(record.originalPath, FileShelfIdentity.standardizedPath(for: original))
        XCTAssertNil(store.readBookmark(id: id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.bookmarkURL(for: id).path))
        let resolved = service.resolve(id, allowCache: false)
        XCTAssertEqual(resolved.urlPath, FileShelfIdentity.standardizedPath(for: original))
        XCTAssertNotEqual(resolved.urlPath, FileShelfIdentity.standardizedPath(for: replacement))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacement.path))
    }

    func testFavoriteSaveFailureRestoresMemory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelf-\(UUID().uuidString)", isDirectory: true)
        var failSave = false
        let store = FileShelfStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw FileShelfStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let service = FileShelfService(store: store, bookmarks: FakeFileShelfBookmarks())
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("files/keep.txt")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: file)
        let id = try XCTUnwrap(service.add(paths: [file.path]).addedIDs.first)
        failSave = true
        service.toggleFavorite(id: id)
        XCTAssertFalse(service.records[0].isFavorite)
    }

    func testQuarantineFailureLeavesCorruptShelfUntouched() throws {
        enum MoveFailure: Error { case denied }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Data("{".utf8)
        let metadata = root.appendingPathComponent("shelf.json")
        try original.write(to: metadata)
        let store = FileShelfStore(root: root, moveItem: { _, _ in throw MoveFailure.denied })
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .corruptUnquarantined)
        XCTAssertFalse(store.isWritable)
        XCTAssertEqual(try Data(contentsOf: metadata), original)
        XCTAssertThrowsError(try store.save([]))
        XCTAssertEqual(try Data(contentsOf: metadata), original)
    }

    func testStaleBookmarkRefreshWritesSidecar() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let file = try harness.writeFile("stale.txt", contents: Data("s".utf8))
        let id = try XCTUnwrap(harness.service.add(paths: [file.path]).addedIDs.first)
        let storedPath = FileShelfIdentity.standardizedPath(for: file)
        harness.bookmarks.stalePaths.insert(storedPath)
        let resolved = harness.service.resolve(id, allowCache: false)
        XCTAssertFalse(resolved.isMissing)
        XCTAssertTrue(resolved.isStale)
        let data = try XCTUnwrap(harness.store.readBookmark(id: id))
        XCTAssertEqual(data, Data("\(storedPath)-refreshed".utf8))
    }

    func testFutureSchemaRejectsWithoutOverwrite() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = root.appendingPathComponent("shelf.json")
        let future = """
        { "schemaVersion": 2, "items": [] }
        """
        try Data(future.utf8).write(to: metadata)
        let store = FileShelfStore(root: root)
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .unsupportedFutureSchema(2))
        XCTAssertFalse(store.isWritable)
        XCTAssertThrowsError(try store.save([]))
        XCTAssertEqual(try String(contentsOf: metadata, encoding: .utf8), future)
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        try FileManager.default.removeItem(at: root)
    }

    func testCorruptStoreQuarantinesWithoutTouchingPanels() throws {
        let appRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceApp-\(UUID().uuidString)", isDirectory: true)
        let panelURL = appRoot.appendingPathComponent("Database/panels.json")
        try FileManager.default.createDirectory(at: panelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let panels = "{ \"schemaVersion\": 5, \"workspaces\": [], \"panels\": [] }"
        try Data(panels.utf8).write(to: panelURL)
        let shelfRoot = appRoot.appendingPathComponent("FileShelf", isDirectory: true)
        try FileManager.default.createDirectory(at: shelfRoot, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: shelfRoot.appendingPathComponent("shelf.json"))
        let store = FileShelfStore(root: shelfRoot)
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .recoveredFromCorruption)
        XCTAssertEqual(try String(contentsOf: panelURL, encoding: .utf8), panels)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: shelfRoot.path)
        XCTAssertTrue(leftovers.contains { $0.hasPrefix("shelf.corrupted-") })
        try FileManager.default.removeItem(at: appRoot)
    }

    func testOrphanBookmarkCleanupOnLoad() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let orphan = harness.store.bookmarkURL(for: UUID())
        try Data("orphan".utf8).write(to: orphan)
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphan.path))
        harness.service.reload()
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testFavoriteToggleAndSearch() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        let pdf = try harness.writeFile("Plan.PDF", contents: Data("p".utf8))
        let zip = try harness.writeFile("data.zip", contents: Data("z".utf8))
        let pdfID = try XCTUnwrap(harness.service.add(paths: [pdf.path], at: Date(timeIntervalSince1970: 1)).addedIDs.first)
        _ = harness.service.add(paths: [zip.path], at: Date(timeIntervalSince1970: 2))
        harness.service.toggleFavorite(id: pdfID, at: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(harness.service.favorites(matching: "plan").map(\.id), [pdfID])
        XCTAssertEqual(harness.service.recent(matching: "ZIP").map(\.displayName), ["data.zip"])
        harness.service.toggleFavorite(id: pdfID)
        XCTAssertTrue(harness.service.favorites(matching: "").isEmpty)
    }

    private func assertShelfContainsOnlyMetadata(_ store: FileShelfStore) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: store.root.path)) ?? []
        XCTAssertEqual(Set(names), ["shelf.json", "Bookmarks"])
    }

    private func makeHarness() throws -> FileShelfHarness {
        try FileShelfHarness()
    }
}

@MainActor
private final class FileShelfHarness {
    let root: URL
    let files: URL
    let store: FileShelfStore
    let bookmarks: FakeFileShelfBookmarks
    let service: FileShelfService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceFileShelf-\(UUID().uuidString)", isDirectory: true)
        files = root.appendingPathComponent("UserFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        store = FileShelfStore(root: root.appendingPathComponent("FileShelf", isDirectory: true))
        bookmarks = FakeFileShelfBookmarks()
        service = FileShelfService(store: store, bookmarks: bookmarks)
    }

    func writeFile(_ name: String, contents: Data) throws -> URL {
        let url = files.appendingPathComponent(name)
        try contents.write(to: url)
        return url
    }

    func writeDirectory(_ name: String) throws -> URL {
        let url = files.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

final class FakeFileShelfBookmarks: FileShelfBookmarking {
    var failCreate = false
    var failResolvePaths: Set<String> = []
    var stalePaths: Set<String> = []
    var resolvedOverride: [String: String] = [:]

    func createBookmark(forFileAtPath path: String) throws -> Data {
        if failCreate { throw FileShelfStoreError.bookmarkFailed }
        return Data(path.utf8)
    }

    func resolveBookmark(_ data: Data) -> FileShelfResolvedReference {
        let stored = String(data: data, encoding: .utf8) ?? ""
        if failResolvePaths.contains(stored) {
            return .missing
        }
        let path = resolvedOverride[stored] ?? stored
        return FileShelfResolvedReference(
            urlPath: path,
            isMissing: false,
            isStale: stalePaths.contains(stored),
            bookmarkDataToRefresh: stalePaths.contains(stored) ? Data("\(stored)-refreshed".utf8) : nil
        )
    }
}
