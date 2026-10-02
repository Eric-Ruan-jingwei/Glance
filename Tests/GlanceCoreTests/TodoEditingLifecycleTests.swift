import Foundation
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class TodoEditingLifecycleTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_700_000_000)
    private let idA = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let idB = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!

    func testFlushNewDraftAddsItem() {
        var document = TodoDocument.empty
        XCTAssertTrue(TodoPendingFlush.apply(to: &document, session: .adding, draft: "Task A"))
        XCTAssertEqual(document.items.map(\.text), ["Task A"])
    }

    func testFlushEmptyNewDraftDoesNothing() {
        var document = TodoDocument.empty
        XCTAssertFalse(TodoPendingFlush.apply(to: &document, session: .adding, draft: "   "))
        XCTAssertTrue(document.items.isEmpty)
    }

    func testFlushExistingEditUpdatesText() {
        var document = documentWithAandB()
        XCTAssertTrue(TodoPendingFlush.apply(to: &document, session: .editing(id: idA), draft: "Task B-title"))
        XCTAssertEqual(item(idA, in: document)?.text, "Task B-title")
        XCTAssertEqual(item(idB, in: document)?.text, "B")
    }

    func testFlushUnchangedEditReturnsFalse() {
        var document = documentWithAandB()
        XCTAssertFalse(TodoPendingFlush.apply(to: &document, session: .editing(id: idA), draft: "A"))
        XCTAssertEqual(document, documentWithAandB())
    }

    func testFlushEmptyExistingEditDeletes() {
        var document = documentWithAandB()
        XCTAssertTrue(TodoPendingFlush.apply(to: &document, session: .editing(id: idA), draft: "  "))
        XCTAssertNil(item(idA, in: document))
        XCTAssertEqual(document.items.map(\.text), ["B"])
    }

    func testDeleteBWhileEditingAKeepsADraft() {
        var document = documentWithAandB()
        XCTAssertTrue(TodoPendingFlush.apply(to: &document, session: .editing(id: idA), draft: "A2"))
        XCTAssertTrue(TodoMutation.delete(&document, id: idB))
        XCTAssertEqual(document.items.map(\.id), [idA])
        XCTAssertEqual(document.items.first?.text, "A2")
    }

    func testFlushNoneDoesNothing() {
        var document = documentWithAandB()
        let before = document
        XCTAssertFalse(TodoPendingFlush.apply(to: &document, session: .none, draft: "ignored"))
        XCTAssertEqual(document, before)
    }

    func testWritePersistsDocumentWithoutPendingDraft() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTodoNoFlush-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var document = TodoDocument.empty
        XCTAssertNotNil(TodoMutation.add(&document, text: "Committed A", id: idA, createdAt: day))
        try TodoPayloadFile.writeDocument(document, to: directory)

        let pending = document
        XCTAssertTrue(TodoPendingFlush.apply(to: &document, session: .adding, draft: "Uncommitted B"))
        XCTAssertNotEqual(document, pending)

        let loaded = try XCTUnwrap(try TodoPayloadFile.readDocument(from: directory))
        XCTAssertEqual(loaded.items.map(\.text), ["Committed A"])
        XCTAssertFalse(loaded.items.contains(where: { $0.text == "Uncommitted B" }))
    }

    private func documentWithAandB() -> TodoDocument {
        var document = TodoDocument.empty
        _ = TodoMutation.add(&document, text: "A", id: idA, createdAt: day)
        _ = TodoMutation.add(&document, text: "B", id: idB, createdAt: day)
        return document
    }

    private func item(_ id: UUID, in document: TodoDocument) -> TodoItem? {
        document.items.first { $0.id == id }
    }
}
