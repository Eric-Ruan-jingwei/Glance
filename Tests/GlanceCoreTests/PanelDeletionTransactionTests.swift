import Foundation
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class PanelDeletionTransactionTests: XCTestCase {
    func testMetadataFailureDoesNotRunDestructiveCleanup() {
        var steps: [String] = []
        XCTAssertThrowsError(
            try PanelDeletionTransaction.perform(
                deleteMetadata: {
                    steps.append("metadata")
                    throw ForcedMetadataWriteError()
                },
                removeController: { steps.append("controller") },
                deletePayload: { steps.append("payload") }
            )
        ) { error in
            XCTAssertTrue(error is ForcedMetadataWriteError)
        }
        XCTAssertEqual(steps, ["metadata"])
    }

    func testSuccessfulDeleteCleansControllerThenPayload() throws {
        var steps: [String] = []
        try PanelDeletionTransaction.perform(
            deleteMetadata: { steps.append("metadata") },
            removeController: { steps.append("controller") },
            deletePayload: { steps.append("payload") }
        )
        XCTAssertEqual(steps, ["metadata", "controller", "payload"])
    }

    func testRepositoryDeleteFailureLeavesRecordAndPayload() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(
                fileURL: store.metadataURL,
                writePrimaryMetadata: writer.write
            )
            let id = UUID()
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
            let payloadDirectory = store.panelsRoot.appendingPathComponent(id.uuidString)
            XCTAssertTrue(FileManager.default.fileExists(atPath: payloadDirectory.path))

            writer.shouldFail = true
            var removedController = false
            var deletedPayload = false
            XCTAssertThrowsError(
                try PanelDeletionTransaction.perform(
                    deleteMetadata: { try repository.delete(id: id) },
                    removeController: { removedController = true },
                    deletePayload: {
                        deletedPayload = true
                        store.delete(id: id)
                    }
                )
            ) { error in
                XCTAssertTrue(error is ForcedMetadataWriteError)
            }

            XCTAssertFalse(removedController)
            XCTAssertFalse(deletedPayload)
            XCTAssertEqual(try repository.record(id: id)?.id, id)
            XCTAssertTrue(FileManager.default.fileExists(atPath: payloadDirectory.path))
            XCTAssertEqual(
                try TextPayloadFile.readAttributedString(from: payloadDirectory)?.string,
                "Keep me"
            )
        }
    }

    func testSuccessfulDeleteRemovesMetadataThenPayload() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let repository = try PanelRepository(fileURL: store.metadataURL)
            let id = UUID()
            try PanelCreationSession.materialize(
                id: id,
                store: store,
                writePayload: { directory in
                    try PanelInitialPayloadWriter.write(.plainText("Delete me"), to: directory)
                },
                insert: {
                    try repository.insert(GlanceTestFixtures.sampleRecord(id: id))
                }
            )
            let payloadDirectory = store.panelsRoot.appendingPathComponent(id.uuidString)
            var steps: [String] = []

            try PanelDeletionTransaction.perform(
                deleteMetadata: {
                    try repository.delete(id: id)
                    steps.append("metadata")
                },
                removeController: { steps.append("controller") },
                deletePayload: {
                    store.delete(id: id)
                    steps.append("payload")
                }
            )

            XCTAssertEqual(steps, ["metadata", "controller", "payload"])
            XCTAssertNil(try repository.record(id: id))
            XCTAssertFalse(FileManager.default.fileExists(atPath: payloadDirectory.path))
        }
    }

    func testPayloadCleanupFailureDoesNotResurrectMetadata() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let repository = try PanelRepository(fileURL: store.metadataURL)
            let id = UUID()
            try repository.insert(GlanceTestFixtures.sampleRecord(id: id))

            try PanelDeletionTransaction.perform(
                deleteMetadata: { try repository.delete(id: id) },
                removeController: {},
                deletePayload: {
                    NSLog("Glance test: simulated payload delete failure")
                }
            )

            XCTAssertNil(try repository.record(id: id))
        }
    }

    private func withTempRoot(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceDeleteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
