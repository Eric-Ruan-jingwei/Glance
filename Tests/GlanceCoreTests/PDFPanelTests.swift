import AppKit
import PDFKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PDFPayloadFileTests: XCTestCase {
    func testMetadataRoundTripKeepsUnicodeName() throws {
        let metadata = PDFDocumentMetadata(
            version: 1,
            displayName: "论文.pdf",
            pageCount: 10
        )
        let data = try PDFPayloadFile.makeEncoder().encode(metadata)
        let decoded = try PDFPayloadFile.makeDecoder().decode(PDFDocumentMetadata.self, from: data)
        XCTAssertEqual(decoded, metadata)
    }

    func testUnsupportedMetadataVersionLeavesOriginalBytes() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Data("""
        {"displayName":"keep-me.pdf","pageCount":3,"version":2}
        """.utf8)
        let url = PDFPayloadFile.metadataURL(in: directory)
        try original.write(to: url)
        XCTAssertThrowsError(try PDFPayloadFile.readMetadata(from: directory))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testImportCopiesBytesIndependentOfSource() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("物理智能综述.pdf")
        let payload = root.appendingPathComponent("panel", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        let bytes = GlanceTestPDF.data(pageCount: 2)
        try bytes.write(to: source)

        let metadata = try MacPDFImporter.inspect(source)
        XCTAssertEqual(metadata.displayName, "物理智能综述.pdf")
        XCTAssertEqual(metadata.pageCount, 2)
        try PDFPayloadFile.importDocument(from: source, metadata: metadata, to: payload)

        let copied = PDFPayloadFile.documentURL(in: payload)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied.path))
        try FileManager.default.removeItem(at: source)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied.path))
        XCTAssertEqual(try PDFPayloadFile.readMetadata(from: payload)?.displayName, "物理智能综述.pdf")
        XCTAssertEqual(try PDFPayloadFile.readMetadata(from: payload)?.pageCount, 2)
        XCTAssertEqual(PDFDocument(url: copied)?.pageCount, 2)
    }

    func testInvalidPDFIsRejected() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fake = directory.appendingPathComponent("fake.pdf")
        try Data("not a pdf".utf8).write(to: fake)
        XCTAssertThrowsError(try MacPDFImporter.inspect(fake)) { error in
            XCTAssertEqual(error as? PDFImportError, .unreadable)
        }
    }

    func testPasswordProtectedPDFIsRejected() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("locked.pdf")
        try GlanceTestPDF.data(pageCount: 1).write(to: source)
        guard let document = PDFDocument(url: source) else {
            return XCTFail("expected a writable PDF")
        }
        let locked = directory.appendingPathComponent("secret.pdf")
        let wrote = document.write(to: locked, withOptions: [
            .userPasswordOption: "secret",
            .ownerPasswordOption: "secret"
        ])
        guard wrote else {
            throw XCTSkip("PDFKit could not write a password-protected fixture")
        }
        do {
            _ = try MacPDFImporter.inspect(locked)
            throw XCTSkip("PDFKit did not treat the fixture as locked")
        } catch PDFImportError.passwordProtected {
            return
        } catch {
            XCTFail("expected passwordProtected, got \(error)")
        }
    }

    @MainActor
    func testImportDoesNotCreatePanelWhenValidationFails() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let repository = try PanelRepository(fileURL: store.metadataURL)
            let fake = root.appendingPathComponent("fake.pdf")
            try Data("not a pdf".utf8).write(to: fake)
            XCTAssertThrowsError(try MacPDFImporter.inspect(fake))
            XCTAssertTrue(try repository.all().isEmpty)
            let leftover = (try? FileManager.default.contentsOfDirectory(
                at: store.panelsRoot,
                includingPropertiesForKeys: nil
            )) ?? []
            XCTAssertTrue(leftover.isEmpty)
        }
    }
}

@MainActor
final class PDFPanelCreationTests: XCTestCase {
    func testMetadataSaveFailureRollsBackCopiedPDF() throws {
        try withTempRoot { root in
            let store = try PayloadStore(applicationSupportRoot: root)
            let writer = ControllableMetadataWriter()
            let repository = try PanelRepository(
                fileURL: store.metadataURL,
                writePrimaryMetadata: writer.write
            )
            writer.shouldFail = true
            let source = root.appendingPathComponent("source.pdf")
            try GlanceTestPDF.data(pageCount: 1).write(to: source)
            let metadata = try MacPDFImporter.inspect(source)
            let id = UUID()
            XCTAssertThrowsError(
                try PanelCreationSession.materialize(
                    id: id,
                    store: store,
                    writePayload: { directory in
                        try PDFPayloadFile.importDocument(from: source, metadata: metadata, to: directory)
                    },
                    insert: {
                        try repository.insert(GlanceTestFixtures.sampleRecord(id: id).withKind(PanelKind.pdf))
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

    func testPDFRecordKeepsSchemaWithoutPDFFields() throws {
        let record = PanelRecord(
            kindIdentifier: PanelKind.pdf,
            frame: PanelFrame(x: 40, y: 80, width: 480, height: 620),
            displayIdentifier: "1",
            payloadPath: "Panels/pdf-id",
            payloadVersion: 1
        )
        let data = try PanelDatabaseCodec.encode(
            PanelDatabase(schemaVersion: PanelDatabase.currentSchemaVersion, panels: [record])
        )
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let panel = try XCTUnwrap((root["panels"] as? [[String: Any]])?.first)
        XCTAssertEqual(root["schemaVersion"] as? Int, PanelDatabase.currentSchemaVersion)
        XCTAssertEqual(panel["kindIdentifier"] as? String, PanelKind.pdf)
        XCTAssertEqual(panel["payloadVersion"] as? Int, 1)
        XCTAssertNotNil(panel["x"])
        XCTAssertNil(panel["sourcePath"])
        XCTAssertNil(panel["pdfTitle"])
        XCTAssertNil(panel["pageCount"])
        XCTAssertNil(panel["currentPage"])
        XCTAssertNil(panel["zoom"])
    }

    func testPDFPanelViewLoadsValidDocumentAndShowsErrorForGarbage() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try GlanceTestPDF.data(pageCount: 2).write(to: PDFPayloadFile.documentURL(in: directory))
        let view = PDFPanelView()
        try view.loadPayload(from: directory)
        XCTAssertFalse(view.isShowingError)
        XCTAssertEqual(view.loadedPageCount, 2)

        try Data("broken".utf8).write(to: PDFPayloadFile.documentURL(in: directory))
        try view.loadPayload(from: directory)
        XCTAssertTrue(view.isShowingError)
        XCTAssertEqual(try Data(contentsOf: PDFPayloadFile.documentURL(in: directory)), Data("broken".utf8))
    }

    func testMissingDocumentShowsErrorWithoutWritingMetadata() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let view = PDFPanelView()
        try view.loadPayload(from: directory)
        XCTAssertTrue(view.isShowingError)
        XCTAssertFalse(FileManager.default.fileExists(atPath: PDFPayloadFile.metadataURL(in: directory).path))
    }
}

@MainActor
final class PDFPanelProviderTests: XCTestCase {
    @MainActor
    func testKindSizeAndRegistry() {
        XCTAssertEqual(PDFPanelProvider.kindIdentifier, "com.glance.panel.pdf")
        XCTAssertEqual(PanelKind.pdf, "com.glance.panel.pdf")
        XCTAssertEqual(PDFPanelProvider.payloadVersion, 1)
        XCTAssertEqual(GlanceConstants.payloadVersionPDF, 1)
        XCTAssertEqual(PDFPanelProvider.defaultSize, GlanceConstants.pdfDefaultSize)
        XCTAssertEqual(PDFPanelProvider.minimumSize, GlanceConstants.pdfMinSize)
        XCTAssertEqual(PDFPanelProvider.defaultSize.width, 480)
        XCTAssertEqual(PDFPanelProvider.defaultSize.height, 620)
        XCTAssertEqual(PDFPanelProvider.minimumSize.width, 260)
        XCTAssertEqual(PDFPanelProvider.minimumSize.height, 260)
        XCTAssertEqual(PanelProviderRegistry.payloadVersion(for: PanelKind.pdf), 1)
        XCTAssertEqual(PanelProviderRegistry.defaultSize(for: PanelKind.pdf), GlanceConstants.pdfDefaultSize)
        XCTAssertEqual(PanelProviderRegistry.minimumSize(for: PanelKind.pdf), GlanceConstants.pdfMinSize)
    }

    @MainActor
    func testRegistryResolvesPDFProvider() {
        XCTAssertTrue(PanelProviderRegistry.makeContent(kindIdentifier: PanelKind.pdf) is PDFPanelView)
    }

    func testMenuInsertsPDFAfterImage() {
        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            onQuickCapture: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onNewPDF: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
        let titles = menu.items.map(\.title)
        XCTAssertEqual(titles[8], "新建图片面板")
        XCTAssertEqual(titles[9], "新建 PDF 面板…")
    }
}

enum GlanceTestPDF {
    static func data(pageCount: Int) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 200, height: 280)
        guard
            let consumer = CGDataConsumer(data: data),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            return Data()
        }
        for _ in 0..<pageCount {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}

private func makeDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GlancePDF-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func withTempRoot(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GlancePDFRoot-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}

private extension PanelRecord {
    func withKind(_ kind: String) -> PanelRecord {
        kindIdentifier = kind
        return self
    }
}
