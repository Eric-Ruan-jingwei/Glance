import Foundation
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class TodoPayloadFileTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    func testItemAndDocumentRoundTrip() throws {
        let item = TodoItem(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            text: "Finish Glance V0.4",
            isCompleted: false,
            createdAt: day
        )
        let document = TodoDocument(version: 1, items: [item])
        let data = try TodoPayloadFile.makeEncoder().encode(document)
        let decoded = try TodoPayloadFile.makeDecoder().decode(TodoDocument.self, from: data)
        XCTAssertEqual(decoded, document)

        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["version"] as? Int, 1)
        let items = try XCTUnwrap(root["items"] as? [[String: Any]])
        XCTAssertEqual(items.first?["text"] as? String, "Finish Glance V0.4")
        XCTAssertEqual(items.first?["isCompleted"] as? Bool, false)
    }

    func testMissingFileIsEmptyNotError() throws {
        let directory = try makeDirectory("GlanceTodoMissing")
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertNil(try TodoPayloadFile.readDocument(from: directory))
    }

    func testValidPayloadLoads() throws {
        let directory = try makeDirectory("GlanceTodoOK")
        defer { try? FileManager.default.removeItem(at: directory) }
        var document = TodoDocument.empty
        XCTAssertNotNil(TodoMutation.add(&document, text: "Ship it", createdAt: day))
        try TodoPayloadFile.writeDocument(document, to: directory)
        let loaded = try XCTUnwrap(try TodoPayloadFile.readDocument(from: directory))
        XCTAssertEqual(loaded.version, 1)
        XCTAssertEqual(loaded.items.map(\.text), ["Ship it"])
        XCTAssertEqual(loaded.items.first?.isCompleted, false)
    }

    func testInvalidJSONThrowsAndLeavesBytes() throws {
        let directory = try makeDirectory("GlanceTodoBadJSON")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(TodoPayloadFile.fileName)
        let original = Data("{not-json".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try TodoPayloadFile.readDocument(from: directory)) { error in
            guard case PayloadLoadError.unreadable = error else {
                return XCTFail("expected unreadable, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
        let flag = PayloadDirtyFlag()
        _ = try PayloadPersistence.persistIfDirty(flag) {
            try TodoPayloadFile.writeDocument(.empty, to: directory)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testUnsupportedVersionThrowsAndLeavesBytes() throws {
        let directory = try makeDirectory("GlanceTodoBadVersion")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(TodoPayloadFile.fileName)
        let original = Data("""
        { "version": 99, "items": [] }
        """.utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try TodoPayloadFile.readDocument(from: directory)) { error in
            guard case PayloadLoadError.unreadable = error else {
                return XCTFail("expected unreadable, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testMutationsMarkDirtyThenSaveClears() throws {
        let directory = try makeDirectory("GlanceTodoDirty")
        defer { try? FileManager.default.removeItem(at: directory) }
        var document = TodoDocument.empty
        let flag = PayloadDirtyFlag()
        XCTAssertFalse(flag.isDirty)

        let item = try XCTUnwrap(TodoMutation.add(&document, text: "A", createdAt: day))
        flag.markUserEdit()
        XCTAssertTrue(TodoMutation.toggle(&document, id: item.id))
        flag.markUserEdit()
        XCTAssertEqual(TodoMutation.edit(&document, id: item.id, text: "A2"), .updated)
        flag.markUserEdit()
        XCTAssertTrue(TodoMutation.delete(&document, id: item.id))
        flag.markUserEdit()
        XCTAssertTrue(flag.shouldPersist)

        let wrote = try PayloadPersistence.persistIfDirty(flag) {
            try TodoPayloadFile.writeDocument(document, to: directory)
        }
        XCTAssertTrue(wrote)
        XCTAssertFalse(flag.isDirty)
        XCTAssertEqual(try TodoPayloadFile.readDocument(from: directory)?.items, [])
    }

    func testAddEditToggleDelete() throws {
        var document = TodoDocument.empty
        XCTAssertNil(TodoMutation.add(&document, text: "   "))
        XCTAssertTrue(document.items.isEmpty)

        let first = try XCTUnwrap(TodoMutation.add(&document, text: " Task A ", createdAt: day))
        XCTAssertEqual(first.text, "Task A")
        XCTAssertEqual(document.items.count, 1)

        XCTAssertEqual(TodoMutation.edit(&document, id: first.id, text: "Task A"), .unchanged)
        XCTAssertEqual(TodoMutation.edit(&document, id: first.id, text: "Task B"), .updated)
        XCTAssertEqual(document.items[0].text, "Task B")
        XCTAssertTrue(TodoMutation.toggle(&document, id: first.id))
        XCTAssertTrue(document.items[0].isCompleted)
        XCTAssertEqual(TodoMutation.edit(&document, id: first.id, text: "   "), .deleted)
        XCTAssertTrue(document.items.isEmpty)
        XCTAssertFalse(TodoMutation.delete(&document, id: first.id))
    }

    func testEmptyExistingEditDeletes() {
        var document = TodoDocument.empty
        let item = TodoMutation.add(&document, text: "Keep", createdAt: day)!
        XCTAssertEqual(TodoMutation.edit(&document, id: item.id, text: ""), .deleted)
        XCTAssertTrue(document.items.isEmpty)
    }

    private func makeDirectory(_ prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
