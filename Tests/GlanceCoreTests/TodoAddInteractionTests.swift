import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class TodoAddInteractionTests: XCTestCase {
    func testEmptyTodoAddCreatesEditableRowAndCommitsOnReturn() throws {
        let harness = try HostedTodoPanel(document: .empty)
        harness.layout()

        XCTAssertTrue(harness.placeholderVisible, "empty panel should show the placeholder")
        XCTAssertEqual(harness.rows.count, 0)
        XCTAssertTrue(harness.addButton.isEnabled)

        harness.addButton.performClick(nil)
        harness.layout()

        XCTAssertEqual(harness.rows.count, 1, "Add must create the adding row")
        XCTAssertFalse(harness.placeholderVisible)
        let field = harness.rows[0].field
        XCTAssertTrue(field.isEditable)
        XCTAssertTrue(field.isSelectable)
        XCTAssertGreaterThan(harness.rows[0].frame.width, 0)
        XCTAssertGreaterThan(harness.rows[0].frame.height, 0)
        XCTAssertTrue(
            harness.scrollVisibleRect.intersects(harness.rows[0].frame),
            "adding row must be in the document"
        )
        XCTAssertTrue(harness.window.firstResponder === field.currentEditor() || harness.window.firstResponder === field)

        field.stringValue = "测试待办"
        XCTAssertTrue(harness.submitReturn(on: field))
        harness.layout()

        XCTAssertEqual(try harness.savedTexts(), ["测试待办"])
        XCTAssertEqual(harness.changes.count, 1)
        XCTAssertEqual(harness.rows.count, 2, "Return in adding should commit and keep a new draft row")
        XCTAssertTrue(harness.rows[1].field.isEditable)
    }

    func testExistingTodoAddAppendsEditableRow() throws {
        var document = TodoDocument.empty
        XCTAssertNotNil(TodoMutation.add(&document, text: "A"))
        XCTAssertNotNil(TodoMutation.add(&document, text: "B"))
        let harness = try HostedTodoPanel(document: document)
        harness.layout()
        XCTAssertEqual(harness.rows.count, 2)

        harness.addButton.performClick(nil)
        harness.layout()

        XCTAssertEqual(harness.rows.count, 3)
        XCTAssertTrue(harness.rows[2].field.isEditable)
        XCTAssertGreaterThan(harness.rows[2].frame.width, 0)
        harness.rows[2].field.stringValue = "C"
        XCTAssertTrue(harness.submitReturn(on: harness.rows[2].field))
        harness.layout()

        XCTAssertEqual(try harness.savedTexts(), ["A", "B", "C"])
        XCTAssertEqual(harness.rows.count, 4)
        XCTAssertTrue(harness.rows[3].field.isEditable)
    }

    func testEmptyTodoEscapeCancelsDraft() throws {
        let harness = try HostedTodoPanel(document: .empty)
        harness.layout()
        harness.addButton.performClick(nil)
        harness.layout()
        XCTAssertEqual(harness.rows.count, 1)

        harness.rows[0].field.stringValue = "不会留下"
        XCTAssertTrue(harness.submitEscape(on: harness.rows[0].field))
        harness.layout()

        XCTAssertEqual(harness.rows.count, 0)
        XCTAssertTrue(harness.placeholderVisible)
        XCTAssertEqual(try harness.savedTexts(), [])
        XCTAssertEqual(harness.changes.count, 0)
    }

    func testChromeHitTestPrefersAddButtonOverBottomResize() throws {
        let harness = try HostedTodoPanel(document: .empty, embedInChrome: true)
        harness.layout()
        let chrome = try XCTUnwrap(harness.chrome)

        let addHit = chrome.hitTest(harness.addButtonCenterInChrome())
        XCTAssertTrue(
            addHit === harness.addButton || addHit?.ancestor(of: NSButton.self) === harness.addButton,
            "Add button must beat the resize edge, got \(String(describing: addHit))"
        )

        let bottomEdge = NSPoint(x: chrome.bounds.midX, y: 1)
        XCTAssertTrue(chrome.hitTest(bottomEdge) === chrome, "true bottom edge should still resize")

        let drag = NSPoint(x: 40, y: chrome.bounds.height - 10)
        XCTAssertTrue(chrome.hitTest(drag) === chrome, "chrome drag strip should still move")
    }

    func testLockedTodoAddButtonDoesNotMutate() throws {
        let harness = try HostedTodoPanel(document: .empty)
        harness.panel.allowsContentMutation = false
        harness.layout()
        XCTAssertFalse(harness.addButton.isEnabled)
        harness.addButton.performClick(nil)
        harness.layout()
        XCTAssertEqual(harness.rows.count, 0)
        XCTAssertTrue(harness.placeholderVisible)
    }

    func testEmptyTodoAddOnNonactivatingPanelFocusesField() throws {
        let harness = try HostedTodoPanel(document: .empty, embedInChrome: true)
        if let panelWindow = harness.window as? PanelWindow {
            panelWindow.allowsKey = false
        }
        harness.layout()
        XCTAssertEqual(harness.rows.count, 0)

        harness.panel.onRequestEditing = { [panel = harness.panel, window = harness.window] in
            (window as? PanelWindow)?.allowsKey = true
            window.makeKeyAndOrderFront(nil)
            panel.enterEditing()
        }
        harness.addButton.performClick(nil)
        harness.layout()

        XCTAssertEqual(harness.rows.count, 1)
        XCTAssertTrue(harness.rows[0].field.isEditable)
        XCTAssertGreaterThan(harness.rows[0].frame.width, 1)
        let field = harness.rows[0].field
        XCTAssertTrue(harness.window.firstResponder === field.currentEditor() || harness.window.firstResponder === field)
    }
}

@MainActor
private final class ChangeCounter {
    var count = 0
}

@MainActor
private final class HostedTodoPanel {
    let directory: URL
    let panel: TodoPanelView
    let window: NSWindow
    let chrome: PanelChromeView?
    let changes: ChangeCounter

    init(document: TodoDocument, embedInChrome: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTodoAdd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try TodoPayloadFile.writeDocument(document, to: directory)

        let changes = ChangeCounter()
        self.changes = changes
        let panel = TodoPanelView()
        self.panel = panel
        try panel.loadPayload(from: directory)
        panel.onPayloadChange = {
            changes.count += 1
        }
        panel.onRequestEditing = { [weak panel] in
            panel?.enterEditing()
        }

        let frame = NSRect(x: 0, y: 0, width: 320, height: 240)
        if embedInChrome {
            let hosted = PanelWindow(contentRect: frame)
            hosted.allowsKey = true
            let chrome = PanelChromeView(frame: frame)
            chrome.embed(panel)
            hosted.contentView = chrome
            self.window = hosted
            self.chrome = chrome
        } else {
            let hosted = NSWindow(
                contentRect: frame,
                styleMask: [.titled, .resizable],
                backing: .buffered,
                defer: false
            )
            hosted.contentView = panel
            panel.translatesAutoresizingMaskIntoConstraints = true
            panel.frame = NSRect(origin: .zero, size: frame.size)
            self.window = hosted
            self.chrome = nil
        }
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
    }

    var rows: [TodoRowView] {
        views(of: TodoRowView.self, in: panel)
    }

    var addButton: NSButton {
        let matches = views(of: NSButton.self, in: panel).filter { $0.title == "添加待办" }
        precondition(!matches.isEmpty, "missing add button")
        return matches[0]
    }

    var placeholderVisible: Bool {
        views(of: NSTextField.self, in: panel).contains {
            $0.stringValue == GlanceEmptyCopy.todoPlaceholder && !$0.isHidden && $0.alphaValue > 0.01
        }
    }

    var scrollVisibleRect: NSRect {
        let scroll = views(of: NSScrollView.self, in: panel)[0]
        return scroll.documentView?.bounds ?? .zero
    }

    func layout() {
        window.layoutIfNeeded()
        panel.layoutSubtreeIfNeeded()
        chrome?.layoutSubtreeIfNeeded()
    }

    func savedTexts() throws -> [String] {
        try panel.savePayload(to: directory)
        return try TodoPayloadFile.readDocument(from: directory)?.items.map(\.text) ?? []
    }

    func submitReturn(on field: NSTextField) -> Bool {
        guard let editor = field.currentEditor() as? NSTextView ?? makeEditor(for: field) else {
            return false
        }
        return field.delegate?.control?(
            field,
            textView: editor,
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        ) ?? false
    }

    func submitEscape(on field: NSTextField) -> Bool {
        guard let editor = field.currentEditor() as? NSTextView ?? makeEditor(for: field) else {
            return false
        }
        return field.delegate?.control?(
            field,
            textView: editor,
            doCommandBy: #selector(NSResponder.cancelOperation(_:))
        ) ?? false
    }

    func addButtonCenterInChrome() -> NSPoint {
        let bounds = addButton.convert(addButton.bounds, to: chrome!)
        return NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func makeEditor(for field: NSTextField) -> NSTextView? {
        window.makeFirstResponder(field)
        return field.currentEditor() as? NSTextView
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

private extension NSView {
    func ancestor<T: NSView>(of type: T.Type) -> T? {
        var current: NSView? = self
        while let view = current {
            if let match = view as? T {
                return match
            }
            current = view.superview
        }
        return nil
    }
}
