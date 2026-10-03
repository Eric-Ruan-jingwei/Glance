import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class PanelSummaryTests: XCTestCase {
    func testTextUsesFirstNonEmptyLine() {
        XCTAssertEqual(PanelSummaryText.firstNonEmptyLine("产品规划\n第二行"), "产品规划")
        XCTAssertEqual(PanelSummaryText.firstNonEmptyLine("\n  \nHello"), "Hello")
        XCTAssertNil(PanelSummaryText.firstNonEmptyLine("   \n"))
    }

    func testMarkdownPrefersHeading() {
        let source = """
        # Glance Architecture

        body
        """
        XCTAssertEqual(PanelSummaryText.markdownTitle(from: source), "Glance Architecture")
    }

    func testMarkdownFallsBackToFirstLine() {
        XCTAssertEqual(PanelSummaryText.markdownTitle(from: "Hello world\nMore"), "Hello world")
    }

    func testTodoPrefersFirstIncompleteItem() {
        let items = [
            TodoItem(id: UUID(), text: "Done", isCompleted: true, createdAt: Date()),
            TodoItem(id: UUID(), text: "Send email", isCompleted: false, createdAt: Date()),
            TodoItem(id: UUID(), text: "Review PR", isCompleted: false, createdAt: Date())
        ]
        let derived = PanelSummaryText.todoTitle(items: items)
        XCTAssertEqual(derived.title, "Send email")
        XCTAssertEqual(derived.subtitle, "1 / 3 已完成")
    }

    func testCompletedTodoUsesFirstItem() {
        let items = [
            TodoItem(id: UUID(), text: "Done A", isCompleted: true, createdAt: Date()),
            TodoItem(id: UUID(), text: "Done B", isCompleted: true, createdAt: Date())
        ]
        XCTAssertEqual(PanelSummaryText.todoTitle(items: items).title, "Done A")
    }

    func testEmptyFallbacks() {
        XCTAssertEqual(PanelSummaryFallback.text, "空文字面板")
        XCTAssertEqual(PanelSummaryFallback.markdown, "空 Markdown 面板")
        XCTAssertEqual(PanelSummaryFallback.todo, "空待办面板")
        XCTAssertEqual(PanelSummaryFallback.image, "图片面板")
        XCTAssertEqual(PanelSummaryFallback.pdf, "PDF 文档")
        XCTAssertEqual(PanelSummaryText.pdfTitle(from: "Robot Learning Survey.pdf"), "Robot Learning Survey")
        XCTAssertEqual(PanelSummaryText.pdfSubtitle(pageCount: 35), "PDF · 35 页")
        XCTAssertTrue(PanelSummaryText.pdfSubtitle(pageCount: 35).contains("PDF"))
        XCTAssertTrue(PanelSummaryText.pdfSubtitle(pageCount: 35).contains("35"))
        XCTAssertEqual(PanelSummaryText.todoTitle(items: []).title, PanelSummaryFallback.todo)
    }

    func testSearchAndChineseMatch() {
        let architecture = sample(title: "Glance Architecture", kind: "com.glance.panel.markdown")
        let plan = sample(title: "商业计划", kind: "com.glance.panel.text")
        XCTAssertTrue(PanelSummaryQuery.matches(architecture, query: "glance"))
        XCTAssertTrue(PanelSummaryQuery.matches(plan, query: "商业"))
        XCTAssertFalse(PanelSummaryQuery.matches(plan, query: "glance"))
    }

    func testKindFilterAndSort() {
        let older = sample(
            title: "Old Todo",
            kind: "com.glance.panel.todo",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = sample(
            title: "New Text",
            kind: "com.glance.panel.text",
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let pdf = sample(
            title: "Robot Learning Survey",
            kind: "com.glance.panel.pdf",
            updatedAt: Date(timeIntervalSince1970: 150)
        )
        let filtered = PanelSummaryQuery.filtered([older, newer], query: "", kind: .todo)
        XCTAssertEqual(filtered.map(\.title), ["Old Todo"])
        XCTAssertEqual(
            PanelSummaryQuery.filtered([older, newer, pdf], query: "", kind: .pdf).map(\.title),
            ["Robot Learning Survey"]
        )
        let sorted = PanelSummaryQuery.sortedByUpdatedAtDescending([older, newer])
        XCTAssertEqual(sorted.map(\.title), ["New Text", "Old Todo"])
    }

    func testFilterAndSearchTogether() {
        let todo = sample(title: "邮件", kind: "com.glance.panel.todo")
        let text = sample(title: "邮件草稿", kind: "com.glance.panel.text")
        let filtered = PanelSummaryQuery.filtered([todo, text], query: "邮件", kind: .todo)
        XCTAssertEqual(filtered.map(\.title), ["邮件"])
    }

    private func sample(
        title: String,
        kind: String,
        updatedAt: Date = Date()
    ) -> PanelSummary {
        PanelSummary(
            id: UUID(),
            kindIdentifier: kind,
            title: title,
            subtitle: nil,
            preview: "",
            createdAt: updatedAt,
            updatedAt: updatedAt,
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isUnreadable: false
        )
    }
}

@MainActor
final class PanelSummaryBuilderTests: XCTestCase {
    func testTextPayloadFirstLine() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try TextPayloadFile.writePlainText("产品规划\n第二行内容", to: directory)
        let summary = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.text),
            payloadDirectory: directory
        )
        XCTAssertEqual(summary.title, "产品规划")
        XCTAssertFalse(summary.isUnreadable)
    }

    func testMarkdownHeadingAndPlainFallback() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try MarkdownPayloadFile.writeSource("# System Design\n\nbody", to: directory)
        let heading = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.markdown),
            payloadDirectory: directory
        )
        XCTAssertEqual(heading.title, "System Design")

        try MarkdownPayloadFile.writeSource("Hello world\nMore", to: directory)
        let plain = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.markdown),
            payloadDirectory: directory
        )
        XCTAssertEqual(plain.title, "Hello world")
    }

    func testTodoIncompleteItemAndEmptyFallback() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var document = TodoDocument.empty
        XCTAssertNotNil(TodoMutation.add(&document, text: "A"))
        document.items[0].isCompleted = true
        XCTAssertNotNil(TodoMutation.add(&document, text: "B"))
        XCTAssertNotNil(TodoMutation.add(&document, text: "C"))
        try TodoPayloadFile.writeDocument(document, to: directory)
        let summary = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.todo),
            payloadDirectory: directory
        )
        XCTAssertEqual(summary.title, "B")
        XCTAssertEqual(summary.subtitle, "1 / 3 已完成")

        try TodoPayloadFile.writeDocument(.empty, to: directory)
        let empty = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.todo),
            payloadDirectory: directory
        )
        XCTAssertEqual(empty.title, PanelSummaryFallback.todo)
    }

    func testEmptyPayloadFallbacks() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(
            PanelSummaryBuilder.summarize(record: record(kind: PanelKind.text), payloadDirectory: directory).title,
            PanelSummaryFallback.text
        )
        XCTAssertEqual(
            PanelSummaryBuilder.summarize(record: record(kind: PanelKind.markdown), payloadDirectory: directory).title,
            PanelSummaryFallback.markdown
        )
        XCTAssertEqual(
            PanelSummaryBuilder.summarize(record: record(kind: PanelKind.todo), payloadDirectory: directory).title,
            PanelSummaryFallback.todo
        )
        let image = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.image),
            payloadDirectory: directory
        )
        XCTAssertEqual(image.title, PanelSummaryFallback.image)
        XCTAssertEqual(image.subtitle, "PNG")
        let pdf = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.pdf),
            payloadDirectory: directory
        )
        XCTAssertEqual(pdf.title, PanelSummaryFallback.pdfUnreadable)
        XCTAssertEqual(pdf.subtitle, "PDF")
        XCTAssertTrue(pdf.isUnreadable)
    }

    func testUnreadableTextLeavesBytes() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(TextPayloadFile.fileName)
        let original = Data([0x00, 0x01, 0x02, 0xFF])
        try original.write(to: url)
        let summary = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.text),
            payloadDirectory: directory
        )
        XCTAssertEqual(summary.title, PanelSummaryFallback.unreadable)
        XCTAssertTrue(summary.isUnreadable)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testUnreadableMarkdownLeavesBytes() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(MarkdownPayloadFile.fileName)
        let original = Data([0xFF, 0xFE, 0x00])
        try original.write(to: url)
        let summary = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.markdown),
            payloadDirectory: directory
        )
        XCTAssertEqual(summary.title, PanelSummaryFallback.unreadable)
        XCTAssertTrue(summary.isUnreadable)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testUnreadableTodoLeavesBytes() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent(TodoPayloadFile.fileName)
        let original = Data("{not-json".utf8)
        try original.write(to: url)
        let summary = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.todo),
            payloadDirectory: directory
        )
        XCTAssertEqual(summary.title, PanelSummaryFallback.unreadable)
        XCTAssertTrue(summary.isUnreadable)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testPNGSizeSubtitle() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var data = Data([137, 80, 78, 71, 13, 10, 26, 10])
        data.append(contentsOf: [0, 0, 0, 13, 73, 72, 68, 82])
        data.append(contentsOf: [0, 0, 4, 176, 0, 0, 3, 32])
        try data.write(to: directory.appendingPathComponent("image.png"))
        let summary = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.image),
            payloadDirectory: directory
        )
        XCTAssertEqual(summary.title, PanelSummaryFallback.image)
        XCTAssertEqual(summary.subtitle, "1200 × 800")
    }

    func testPDFSummaryTitlePageCountAndBrokenMetadata() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try GlanceTestPDF.data(pageCount: 2).write(to: PDFPayloadFile.documentURL(in: directory))
        try PDFPayloadFile.writeMetadata(
            PDFDocumentMetadata(version: 1, displayName: "Robot Learning Survey.pdf", pageCount: 35),
            to: directory
        )
        let summary = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.pdf),
            payloadDirectory: directory
        )
        XCTAssertEqual(summary.title, "Robot Learning Survey")
        XCTAssertEqual(summary.subtitle, "PDF · 35 页")
        XCTAssertTrue(summary.subtitle?.contains("PDF") == true)
        XCTAssertTrue(summary.subtitle?.contains("35") == true)
        XCTAssertEqual(summary.preview, "Robot Learning Survey.pdf")
        XCTAssertFalse(summary.isUnreadable)

        let metadataURL = PDFPayloadFile.metadataURL(in: directory)
        let original = Data("{not-json".utf8)
        try original.write(to: metadataURL)
        let broken = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.pdf),
            payloadDirectory: directory
        )
        XCTAssertEqual(broken.title, PanelSummaryFallback.pdf)
        XCTAssertEqual(broken.subtitle, "PDF")
        XCTAssertFalse(broken.isUnreadable)
        XCTAssertEqual(try Data(contentsOf: metadataURL), original)
        XCTAssertTrue(PDFPayloadFile.documentExists(in: directory))

        try FileManager.default.removeItem(at: metadataURL)
        let missingJSON = PanelSummaryBuilder.summarize(
            record: record(kind: PanelKind.pdf),
            payloadDirectory: directory
        )
        XCTAssertEqual(missingJSON.title, PanelSummaryFallback.pdf)
        XCTAssertEqual(missingJSON.subtitle, "PDF")
        XCTAssertFalse(missingJSON.isUnreadable)
        XCTAssertFalse(FileManager.default.fileExists(atPath: metadataURL.path))
    }

    func testLibraryModelRefreshReappliesFilter() {
        let older = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.todo,
            title: "Send email",
            subtitle: nil,
            preview: "",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isUnreadable: false
        )
        let newer = PanelSummary(
            id: UUID(),
            kindIdentifier: PanelKind.markdown,
            title: "Glance Architecture",
            subtitle: nil,
            preview: "",
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 2),
            isLocked: false,
            isPassThrough: false,
            isPinned: true,
            isUnreadable: false
        )
        let model = PanelLibraryModel()
        model.loadSummaries = { [newer, older] }
        model.reload()
        model.filter = .todo
        model.query = "email"
        XCTAssertEqual(model.visible.map(\.title), ["Send email"])
        model.loadSummaries = { [newer] }
        model.reload()
        XCTAssertTrue(model.visible.isEmpty)
    }

    private func record(kind: String) -> PanelRecord {
        GlanceTestFixtures.sampleRecord()
            .withKind(kind)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceSummary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private extension PanelRecord {
    func withKind(_ kind: String) -> PanelRecord {
        kindIdentifier = kind
        return self
    }
}
