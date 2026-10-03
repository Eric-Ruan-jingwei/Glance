import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class PanelInitialContentTests: XCTestCase {
    func testTextInitialContentWritesRTF() throws {
        let directory = try makeDirectory("GlanceTextInitial")
        defer { try? FileManager.default.removeItem(at: directory) }

        try PanelInitialPayloadWriter.write(.plainText("Hello Glance"), to: directory)
        let attributed = try XCTUnwrap(try TextPayloadFile.readAttributedString(from: directory))
        XCTAssertEqual(attributed.string, "Hello Glance")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(TextPayloadFile.fileName).path
            )
        )
    }

    func testTodoInitialContentWritesOneUncheckedItem() throws {
        let directory = try makeDirectory("GlanceTodoInitial")
        defer { try? FileManager.default.removeItem(at: directory) }

        try PanelInitialPayloadWriter.write(.todoTitle("Send email"), to: directory)
        let document = try XCTUnwrap(try TodoPayloadFile.readDocument(from: directory))
        XCTAssertEqual(document.version, 1)
        XCTAssertEqual(document.items.count, 1)
        XCTAssertEqual(document.items[0].text, "Send email")
        XCTAssertEqual(document.items[0].isCompleted, false)
    }

    func testEmptyInitialContentWritesNoPayloadFiles() throws {
        let directory = try makeDirectory("GlanceEmptyInitial")
        defer { try? FileManager.default.removeItem(at: directory) }

        try PanelInitialPayloadWriter.write(.none, to: directory)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(TextPayloadFile.fileName).path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(TodoPayloadFile.fileName).path
            )
        )
        XCTAssertNil(try TextPayloadFile.readAttributedString(from: directory))
        XCTAssertNil(try TodoPayloadFile.readDocument(from: directory))
    }

    func testPayloadWriteFailureLeavesNoMetadataAndDeletesDirectory() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let repository = try PanelRepository(fileURL: store.metadataURL)
            let id = UUID()
            XCTAssertThrowsError(
                try PanelCreationSession.materialize(
                    id: id,
                    store: store,
                    writePayload: { _ in throw TestWriteFailure() },
                    insert: {
                        XCTFail("metadata insert must not run after payload failure")
                        try repository.insert(GlanceTestFixtures.sampleRecord(id: id))
                    }
                )
            )
            XCTAssertTrue(try repository.all().isEmpty)
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: store.panelsRoot.appendingPathComponent(id.uuidString).path
                )
            )
        }
    }

    func testMetadataInsertFailureDeletesPayloadDirectory() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            try Data(GlanceTestFixtures.futureSchemaJSON.utf8).write(to: store.metadataURL)
            let repository = try PanelRepository(fileURL: store.metadataURL)
            let id = UUID()
            XCTAssertThrowsError(
                try PanelCreationSession.materialize(
                    id: id,
                    store: store,
                    writePayload: { directory in
                        try PanelInitialPayloadWriter.write(.plainText("Keep me"), to: directory)
                    },
                    insert: {
                        try repository.insert(GlanceTestFixtures.sampleRecord(id: id))
                    }
                )
            )
            XCTAssertTrue(try repository.all().isEmpty)
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: store.panelsRoot.appendingPathComponent(id.uuidString).path
                )
            )
        }
    }

    func testEmptyCreateStillMaterializesDirectoryWithoutPayloadFile() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let repository = try PanelRepository(fileURL: store.metadataURL)
            let id = UUID()
            try PanelCreationSession.materialize(
                id: id,
                store: store,
                writePayload: { directory in
                    try PanelInitialPayloadWriter.write(.none, to: directory)
                },
                insert: {
                    try repository.insert(GlanceTestFixtures.sampleRecord(id: id))
                }
            )
            XCTAssertEqual(try repository.all().count, 1)
            let directory = store.panelsRoot.appendingPathComponent(id.uuidString)
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent(TextPayloadFile.fileName).path
                )
            )
        }
    }

    func testSuccessfulTextCaptureWritesThenInserts() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let repository = try PanelRepository(fileURL: store.metadataURL)
            let id = UUID()
            let request = QuickCaptureRequest(kind: .text, text: "Hello Glance")
            let content = try XCTUnwrap(request.initialContent())
            try PanelCreationSession.materialize(
                id: id,
                store: store,
                writePayload: { directory in
                    try PanelInitialPayloadWriter.write(content, to: directory)
                },
                insert: {
                    try repository.insert(GlanceTestFixtures.sampleRecord(id: id))
                }
            )
            let directory = store.panelsRoot.appendingPathComponent(id.uuidString)
            XCTAssertEqual(
                try TextPayloadFile.readAttributedString(from: directory)?.string,
                "Hello Glance"
            )
            XCTAssertEqual(try repository.record(id: id)?.id, id)
        }
    }

    func testCaptureSessionRollsBackPayloadWhenInsertSaveFails() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(
                fileURL: store.metadataURL,
                writePrimaryMetadata: writer.write
            )
            writer.shouldFail = true
            let id = UUID()
            XCTAssertThrowsError(
                try PanelCreationSession.materialize(
                    id: id,
                    store: store,
                    writePayload: { directory in
                        try PanelInitialPayloadWriter.write(.plainText("Hello Glance"), to: directory)
                    },
                    insert: {
                        try repository.insert(GlanceTestFixtures.sampleRecord(id: id))
                    }
                )
            ) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }
            XCTAssertTrue(try repository.all().isEmpty)
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: store.panelsRoot.appendingPathComponent(id.uuidString).path
                )
            )
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.metadataURL.path))
        }
    }

    func testNewlyCreatedPanelFollowsGlobalVisibility() {
        XCTAssertFalse(PanelRevealPolicy.shouldPresentNewlyCreatedPanel(isGloballyConcealed: true))
        XCTAssertTrue(PanelRevealPolicy.shouldPresentNewlyCreatedPanel(isGloballyConcealed: false))
        XCTAssertFalse(
            PanelVisibilityPolicy.shouldPresent(
                panelHidden: false,
                panelWorkspaceID: WorkspaceRecord.defaultID,
                activeWorkspaceID: WorkspaceRecord.defaultID,
                globallyConcealed: true
            )
        )
    }

    private struct TestWriteFailure: Error {}

    private func makeDirectory(_ prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func withTempRoot(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceCaptureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
