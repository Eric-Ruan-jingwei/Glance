import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class TodoPanelLayoutTests: XCTestCase {
    func testTodoRowsAlignToTheLeadingEdge() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTodoLayout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var document = TodoDocument.empty
        XCTAssertNotNil(TodoMutation.add(&document, text: "回复邮件"))
        XCTAssertNotNil(TodoMutation.add(&document, text: "提交版本"))
        try TodoPayloadFile.writeDocument(document, to: directory)

        let panel = TodoPanelView()
        try panel.loadPayload(from: directory)
        panel.translatesAutoresizingMaskIntoConstraints = true
        panel.frame = NSRect(x: 0, y: 0, width: 320, height: 240)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = panel
        panel.layoutSubtreeIfNeeded()

        let rows = views(of: TodoRowView.self, in: panel)
        XCTAssertEqual(rows.count, 2)

        for row in rows {
            let frame = row.convert(row.bounds, to: panel)
            XCTAssertEqual(frame.minX, 0, accuracy: 1)
            XCTAssertEqual(frame.width, panel.bounds.width, accuracy: 1)

            let checkbox = row.subviews.compactMap { $0 as? NSButton }.first { $0.imagePosition == .imageOnly }
            XCTAssertNotNil(checkbox)
            if let checkbox {
                let checkFrame = checkbox.convert(checkbox.bounds, to: panel)
                XCTAssertEqual(checkFrame.minX, GlanceTheme.Space.md, accuracy: 1)
                XCTAssertLessThan(checkFrame.minX, panel.bounds.width / 3)
            }
        }
    }

    private func views<T: NSView>(of type: T.Type, in root: NSView) -> [T] {
        var found: [T] = []
        var queue: [NSView] = [root]
        while let view = queue.first {
            queue.removeFirst()
            if let match = view as? T {
                found.append(match)
            }
            queue.append(contentsOf: view.subviews)
        }
        return found
    }
}
