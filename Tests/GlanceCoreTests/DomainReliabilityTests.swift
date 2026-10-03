import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class DomainReliabilityTests: XCTestCase {
    func testFutureLinksSchemaDoesNotBlockOtherDomains() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceIsolation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let panelsURL = root.appendingPathComponent("Database/panels.json")
        try FileManager.default.createDirectory(at: panelsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ \"schemaVersion\": 5, \"workspaces\": [], \"panels\": [] }".utf8).write(to: panelsURL)

        let clipboardRoot = root.appendingPathComponent("Clipboard", isDirectory: true)
        try FileManager.default.createDirectory(at: clipboardRoot, withIntermediateDirectories: true)
        try Data("{ \"schemaVersion\": 1, \"items\": [] }".utf8).write(
            to: clipboardRoot.appendingPathComponent("history.json")
        )

        let shelfRoot = root.appendingPathComponent("FileShelf", isDirectory: true)
        try FileManager.default.createDirectory(at: shelfRoot, withIntermediateDirectories: true)
        try Data("{ \"schemaVersion\": 1, \"items\": [] }".utf8).write(
            to: shelfRoot.appendingPathComponent("shelf.json")
        )

        let snippetRoot = root.appendingPathComponent("Snippets", isDirectory: true)
        try FileManager.default.createDirectory(at: snippetRoot, withIntermediateDirectories: true)
        try Data("{ \"schemaVersion\": 1, \"items\": [] }".utf8).write(
            to: snippetRoot.appendingPathComponent("snippets.json")
        )

        let linkRoot = root.appendingPathComponent("Links", isDirectory: true)
        try FileManager.default.createDirectory(at: linkRoot, withIntermediateDirectories: true)
        let futureLinks = "{ \"schemaVersion\": 99, \"items\": [] }"
        try Data(futureLinks.utf8).write(to: linkRoot.appendingPathComponent("links.json"))

        let repository = try PanelRepository(fileURL: panelsURL)
        XCTAssertEqual(repository.lastLoadOutcome, .loaded(migratedFromLegacy: false))
        XCTAssertTrue(try repository.all().isEmpty)

        let clipboard = ClipboardHistoryStore(root: clipboardRoot)
        XCTAssertEqual(clipboard.load().count, 0)
        XCTAssertEqual(clipboard.lastLoadOutcome, .loaded)
        XCTAssertTrue(clipboard.isWritable)

        let shelf = FileShelfStore(root: shelfRoot)
        XCTAssertEqual(shelf.load().count, 0)
        XCTAssertEqual(shelf.lastLoadOutcome, .loaded)
        XCTAssertTrue(shelf.isWritable)

        let snippets = SnippetStore(root: snippetRoot)
        XCTAssertEqual(snippets.load().count, 0)
        XCTAssertEqual(snippets.lastLoadOutcome, .loaded)
        XCTAssertTrue(snippets.isWritable)

        let links = LinkStore(root: linkRoot)
        XCTAssertTrue(links.load().isEmpty)
        XCTAssertEqual(links.lastLoadOutcome, .unsupportedFutureSchema(99))
        XCTAssertFalse(links.isWritable)
        XCTAssertEqual(
            try String(contentsOf: linkRoot.appendingPathComponent("links.json"), encoding: .utf8),
            futureLinks
        )
        XCTAssertTrue(GlobalSearchSnapshotBuilder.linksUnavailable(links.lastLoadOutcome))
        XCTAssertFalse(GlobalSearchSnapshotBuilder.clipboardUnavailable(clipboard.lastLoadOutcome))
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(LinkDatabase.currentSchemaVersion, 1)
    }

    func testCorruptUnquarantinedSourceIsUnavailableToSearch() {
        XCTAssertTrue(GlobalSearchSnapshotBuilder.clipboardUnavailable(.corruptUnquarantined))
        XCTAssertTrue(GlobalSearchSnapshotBuilder.fileShelfUnavailable(.corruptUnquarantined))
        XCTAssertTrue(GlobalSearchSnapshotBuilder.snippetsUnavailable(.corruptUnquarantined))
        XCTAssertTrue(GlobalSearchSnapshotBuilder.linksUnavailable(.corruptUnquarantined))
        XCTAssertFalse(GlobalSearchSnapshotBuilder.clipboardUnavailable(.recoveredFromCorruption))
    }
}
