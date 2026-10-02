import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PayloadDirtyFlagTests: XCTestCase {
    func testLoadLeavesClean() {
        let flag = PayloadDirtyFlag()
        XCTAssertFalse(flag.isDirty)
        XCTAssertFalse(flag.shouldPersist)
    }

    func testUserEditMarksDirty() {
        let flag = PayloadDirtyFlag()
        flag.markUserEdit()
        XCTAssertTrue(flag.isDirty)
        XCTAssertTrue(flag.shouldPersist)
    }

    func testSuccessfulSaveClearsDirty() {
        let flag = PayloadDirtyFlag()
        flag.markUserEdit()
        var saved = false
        let wrote = PayloadPersistence.persistIfDirty(flag) {
            saved = true
        }
        XCTAssertTrue(wrote)
        XCTAssertTrue(saved)
        XCTAssertFalse(flag.isDirty)
    }

    func testFailedSaveKeepsDirty() {
        let flag = PayloadDirtyFlag()
        flag.markUserEdit()
        struct SaveFailed: Error {}
        XCTAssertThrowsError(try PayloadPersistence.persistIfDirty(flag) {
            throw SaveFailed()
        })
        XCTAssertTrue(flag.isDirty)
    }

    func testCleanPersistDoesNotCallSave() {
        let flag = PayloadDirtyFlag()
        var saved = false
        let wrote = PayloadPersistence.persistIfDirty(flag) {
            saved = true
        }
        XCTAssertFalse(wrote)
        XCTAssertFalse(saved)
        XCTAssertFalse(flag.isDirty)
    }

    func testUnreadablePayloadIsNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlancePayload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(TextPayloadFile.fileName)
        let original = Data("this is not rtf {{{".utf8)
        try original.write(to: url)

        XCTAssertThrowsError(try TextPayloadFile.readAttributedString(from: directory)) { error in
            guard case PayloadLoadError.unreadable = error else {
                return XCTFail("expected unreadable, got \(error)")
            }
        }

        let flag = PayloadDirtyFlag()
        _ = try PayloadPersistence.persistIfDirty(flag) {
            try Data().write(to: url)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testMissingPayloadIsEmptyNotError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlancePayloadMissing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let loaded = try TextPayloadFile.readAttributedString(from: directory)
        XCTAssertNil(loaded)
    }

    func testUnreadableImageIsNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceImage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("image.png")
        let original = Data("not a png".utf8)
        try original.write(to: url)
        let store = MediaStore()
        XCTAssertThrowsError(try store.loadImage(from: directory)) { error in
            guard case PayloadLoadError.unreadable = error else {
                return XCTFail("expected unreadable, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testReadablePayloadLoadDoesNotWrite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlancePayloadOk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = NSAttributedString(string: "keep me")
        let range = NSRange(location: 0, length: text.length)
        let original = try XCTUnwrap(text.rtf(from: range))
        let url = directory.appendingPathComponent(TextPayloadFile.fileName)
        try original.write(to: url)
        let loaded = try TextPayloadFile.readAttributedString(from: directory)
        XCTAssertEqual(loaded?.string, "keep me")
        let flag = PayloadDirtyFlag()
        _ = try PayloadPersistence.persistIfDirty(flag) {
            try Data("overwrite".utf8).write(to: url)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
