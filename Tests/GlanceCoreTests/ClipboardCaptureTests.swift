import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class ClipboardCaptureTests: XCTestCase {
    private let samplePNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    func testTextRoutingKeepsOriginalString() {
        let content = ClipboardCaptureRouter.content(imagePNG: nil, text: "  hello\nworld  ")
        XCTAssertEqual(content, .text("  hello\nworld  "))
        XCTAssertEqual(ClipboardCaptureRouter.kindIdentifier(for: content!), PanelKind.text)
        XCTAssertEqual(ClipboardCaptureRouter.initialContent(for: content!), .plainText("  hello\nworld  "))
    }

    func testWhitespaceTextIsUnsupported() {
        for text in ["", "   ", "\n\t", " \n "] {
            XCTAssertNil(ClipboardCaptureRouter.content(imagePNG: nil, text: text))
        }
    }

    func testImageTakesPriorityOverText() {
        let content = ClipboardCaptureRouter.content(imagePNG: samplePNG, text: "filename.png")
        XCTAssertEqual(content, .png(samplePNG))
        XCTAssertEqual(ClipboardCaptureRouter.kindIdentifier(for: content!), PanelKind.image)
        XCTAssertEqual(ClipboardCaptureRouter.initialContent(for: content!), .imagePNG(samplePNG))
    }

    func testTextFallbackWhenImageMissing() {
        let content = ClipboardCaptureRouter.content(imagePNG: nil, text: "Hello Glance")
        XCTAssertEqual(content, .text("Hello Glance"))
    }

    func testUnsupportedWhenNeitherImageNorText() {
        XCTAssertNil(ClipboardCaptureRouter.content(imagePNG: nil, text: nil))
        XCTAssertNil(ClipboardCaptureRouter.content(imagePNG: Data(), text: "   "))
    }

    func testClipboardShortcutsAreOptionCommandB() {
        XCTAssertEqual(GlanceConstants.clipboardCaptureKeyEquivalent, "b")
        XCTAssertEqual(GlanceConstants.clipboardCaptureShortcutDisplay, "⌥⌘B")
        XCTAssertNotEqual(GlanceConstants.clipboardCaptureKeyEquivalent, "v")
        XCTAssertNotEqual(GlanceConstants.clipboardCaptureKeyEquivalent, GlanceConstants.quickCaptureKeyEquivalent)
        XCTAssertNotEqual(GlanceConstants.clipboardCaptureKeyEquivalent, GlanceConstants.hideShowKeyEquivalent)
        XCTAssertEqual(GlanceHotKeyID.clipboardCapture.rawValue, 3)
        XCTAssertNotEqual(GlanceHotKeyID.clipboardCapture, GlanceHotKeyID.quickCapture)
        XCTAssertNotEqual(GlanceHotKeyID.clipboardCapture, GlanceHotKeyID.hideShow)
    }

    func testIsolatedPasteboardTextDoesNotTouchGeneral() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("Hello Glance", forType: .string)
        XCTAssertTrue(MacClipboardReader.hasSupportedContent(pasteboard))
        XCTAssertEqual(MacClipboardReader.read(pasteboard), .text("Hello Glance"))
    }

    func testIsolatedPasteboardImageBeatsText() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .string], owner: nil)
        pasteboard.setData(samplePNG, forType: .png)
        pasteboard.setString("shot.png", forType: .string)
        XCTAssertEqual(MacClipboardReader.read(pasteboard), .png(samplePNG))
    }

    func testIsolatedPasteboardFileURLAloneIsUnsupported() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.fileURL], owner: nil)
        XCTAssertFalse(MacClipboardReader.hasSupportedContent(pasteboard))
        XCTAssertNil(MacClipboardReader.read(pasteboard))
    }

    func testUnreadableImageFallsBackToValidText() {
        let pasteboard = isolatedPasteboard(types: [.tiff, .string])
        pasteboard.setData(Data([0x00, 0x01]), forType: .tiff)
        pasteboard.setString("hello", forType: .string)
        XCTAssertTrue(MacClipboardReader.hasImageType(pasteboard))
        XCTAssertEqual(MacClipboardReader.read(pasteboard), .text("hello"))
    }

    func testUnreadableImageFallsBackToOriginalTextIncludingWhitespace() {
        let pasteboard = isolatedPasteboard(types: [.tiff, .string])
        pasteboard.setData(Data([0x00, 0x01]), forType: .tiff)
        pasteboard.setString("  hello\nworld  ", forType: .string)
        XCTAssertEqual(MacClipboardReader.read(pasteboard), .text("  hello\nworld  "))
    }

    func testUnreadableImageAndNoTextIsUnsupported() {
        let pasteboard = isolatedPasteboard(types: [.tiff])
        pasteboard.setData(Data([0x00, 0x01]), forType: .tiff)
        XCTAssertTrue(MacClipboardReader.hasSupportedContent(pasteboard))
        XCTAssertNil(MacClipboardReader.read(pasteboard))
    }

    func testUnreadableImageAndWhitespaceTextIsUnsupported() {
        let pasteboard = isolatedPasteboard(types: [.tiff, .string])
        pasteboard.setData(Data([0x00, 0x01]), forType: .tiff)
        pasteboard.setString("   \n ", forType: .string)
        XCTAssertNil(MacClipboardReader.read(pasteboard))
    }

    func testMenuClipboardItemUsesShortcutAndCanDisable() {
        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            clipboardCaptureEnabled: false,
            onQuickCapture: {},
            onCaptureClipboard: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
        let item = GlanceMenuQuery.item(titled: "从当前剪贴板创建…", in: menu)
        XCTAssertNil(menu.items.first { $0.title == "从当前剪贴板创建…" })
        XCTAssertEqual(item?.keyEquivalent, "b")
        XCTAssertEqual(item?.keyEquivalentModifierMask, [.option, .command])
        XCTAssertEqual(item?.isEnabled, false)
    }

    private func isolatedPasteboard(types: [NSPasteboard.PasteboardType]) -> NSPasteboard {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes(types, owner: nil)
        return pasteboard
    }
}

@MainActor
final class ClipboardCapturePersistenceTests: XCTestCase {
    private let samplePNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    func testTextInitialPayloadKeepsNewlines() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = "Line 1\nLine 2"
        try PanelInitialPayloadWriter.write(.plainText(source), to: directory)
        XCTAssertEqual(try TextPayloadFile.readAttributedString(from: directory)?.string, source)
    }

    func testImagePNGInitialPayloadWritesImageFile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try PanelInitialPayloadWriter.write(.imagePNG(samplePNG), to: directory)
        let url = directory.appendingPathComponent("image.png")
        let data = try Data(contentsOf: url)
        XCTAssertTrue(MediaStore.looksLikePNG(data))
        XCTAssertNotNil(NSImage(data: data))
        let record = GlanceTestFixtures.sampleRecord().withKind(PanelKind.image)
        let encoded = try PanelDatabaseCodec.encode(
            PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: [record])
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let panel = try XCTUnwrap((root["panels"] as? [[String: Any]])?.first)
        XCTAssertEqual(root["schemaVersion"] as? Int, PanelDatabase.currentSchemaVersion)
        XCTAssertNil(panel["source"])
        XCTAssertNil(panel["copiedAt"])
        XCTAssertNotNil(panel["x"])
    }

    func testImageCaptureRollsBackWhenMetadataSaveFails() throws {
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
                        try PanelInitialPayloadWriter.write(.imagePNG(samplePNG), to: directory)
                    },
                    insert: {
                        try repository.insert(GlanceTestFixtures.sampleRecord(id: id).withKind(PanelKind.image))
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

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func withTempRoot(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboardRoot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}

private extension PanelRecord {
    func withKind(_ kind: String) -> PanelRecord {
        kindIdentifier = kind
        return self
    }
}
