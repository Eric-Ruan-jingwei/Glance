import Foundation
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class MarkdownPayloadFileTests: XCTestCase {
    func testMissingFileIsEmptyNotError() throws {
        let directory = try makeDirectory("GlanceMarkdownMissing")
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertNil(try MarkdownPayloadFile.readSource(from: directory))
    }

    func testValidUTF8Loads() throws {
        let directory = try makeDirectory("GlanceMarkdownOK")
        defer { try? FileManager.default.removeItem(at: directory) }
        try MarkdownPayloadFile.writeSource("# Hello\n\n- item\n", to: directory)
        XCTAssertEqual(try MarkdownPayloadFile.readSource(from: directory), "# Hello\n\n- item\n")
    }

    func testInvalidUTF8ThrowsAndLeavesBytes() throws {
        let directory = try makeDirectory("GlanceMarkdownBad")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(MarkdownPayloadFile.fileName)
        let original = Data([0xFF, 0xFE, 0x00, 0x80])
        try original.write(to: url)
        XCTAssertThrowsError(try MarkdownPayloadFile.readSource(from: directory)) { error in
            guard case PayloadLoadError.unreadable = error else {
                return XCTFail("expected unreadable, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
        let flag = PayloadDirtyFlag()
        _ = try PayloadPersistence.persistIfDirty(flag) {
            try MarkdownPayloadFile.writeSource("", to: directory)
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testModifyMarksDirtyThenSaveClears() throws {
        let directory = try makeDirectory("GlanceMarkdownDirty")
        defer { try? FileManager.default.removeItem(at: directory) }
        let flag = PayloadDirtyFlag()
        XCTAssertFalse(flag.isDirty)
        flag.markUserEdit()
        XCTAssertTrue(flag.shouldPersist)
        let wrote = try PayloadPersistence.persistIfDirty(flag) {
            try MarkdownPayloadFile.writeSource("**bold**", to: directory)
        }
        XCTAssertTrue(wrote)
        XCTAssertFalse(flag.isDirty)
        XCTAssertEqual(try MarkdownPayloadFile.readSource(from: directory), "**bold**")
    }

    func testTaskListNormalizationIsPreviewOnly() {
        let source = """
        - [ ] Todo
        - [x] Done
        1. [X] Also done
        """
        let display = MarkdownTaskList.displaySource(from: source)
        XCTAssertTrue(display.contains("☐ Todo"))
        XCTAssertTrue(display.contains("☑ Done"))
        XCTAssertTrue(display.contains("☑ Also done"))
        XCTAssertTrue(source.contains("[ ]"))
        XCTAssertTrue(source.contains("[x]"))
        let preview = MarkdownDocument.attributedPreview(from: source)
        XCTAssertTrue(String(preview.characters).contains("Todo"))
        XCTAssertFalse(String(preview.characters).contains("[x]"))
    }

    func testPreviewParsesCommonMarkdown() {
        let source = """
        # Heading
        ## Sub

        **bold** and *italic*

        - unordered
        1. ordered

        > quote

        `inline`

        ```
        code fence
        ```

        [OpenAI](https://openai.com)

        ---
        """
        let preview = MarkdownDocument.attributedPreview(from: source)
        let text = String(preview.characters)
        XCTAssertTrue(text.contains("Heading"))
        XCTAssertTrue(text.contains("bold"))
        XCTAssertTrue(text.contains("unordered"))
        XCTAssertTrue(text.contains("quote"))
        XCTAssertTrue(text.contains("inline"))
        XCTAssertTrue(text.contains("code fence"))
        XCTAssertTrue(preview.runs.contains { $0.link != nil })
    }

    func testEmptySourceIsEmptyPreview() {
        XCTAssertTrue(MarkdownDocument.attributedPreview(from: "  \n").characters.isEmpty)
    }

    private func makeDirectory(_ prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
