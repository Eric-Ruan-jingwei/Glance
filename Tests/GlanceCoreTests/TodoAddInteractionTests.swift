import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class TodoAddInteractionTests: XCTestCase {
    func testEmptyTodoAddFocusesWhenWindowBecomesKeyAfterTheClick() throws {
        let harness = try HostedTodoPanel(document: .empty, embedInChrome: true)
        if let panelWindow = harness.window as? PanelWindow {
            panelWindow.allowsKey = false
        }
        let decoy = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        decoy.isReleasedWhenClosed = false
        decoy.makeKeyAndOrderFront(nil)
        harness.window.orderFrontRegardless()
        harness.layout()
        XCTAssertFalse(harness.window.isKeyWindow)
        XCTAssertEqual(harness.rows.count, 0)

        harness.panel.onRequestEditing = { [panel = harness.panel, window = harness.window] in
            (window as? PanelWindow)?.allowsKey = true
            panel.enterEditing()
        }
        harness.addButton.performClick(nil)
        harness.layout()
        XCTAssertEqual(harness.rows.count, 1, "Add must create the adding row before the window is key")
        XCTAssertTrue(harness.panel.isAddingForTests)

        (harness.window as? PanelWindow)?.allowsKey = true
        harness.window.makeKeyAndOrderFront(nil)
        harness.layout()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        let field = harness.rows[0].field
        XCTAssertTrue(
            harness.window.firstResponder === field.currentEditor() || harness.window.firstResponder === field,
            "becoming key after Add must focus the draft field, got \(String(describing: harness.window.firstResponder))"
        )
        XCTAssertEqual(field.placeholderString, GlanceEmptyCopy.todoDraftPlaceholder)
        decoy.close()
    }

    func testEmptyTodoAddCreatesEditableRow() throws {
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
        XCTAssertFalse(field.isHidden)
        XCTAssertGreaterThan(field.alphaValue, 0.01)
        XCTAssertEqual(field.placeholderString, GlanceEmptyCopy.todoDraftPlaceholder)
        XCTAssertGreaterThan(harness.rows[0].frame.width, 0)
        XCTAssertGreaterThan(harness.rows[0].frame.height, 0)
        XCTAssertTrue(
            harness.scrollVisibleRect.intersects(harness.rows[0].frame),
            "adding row must be in the document"
        )
        XCTAssertTrue(
            harness.window.firstResponder === field.currentEditor() || harness.window.firstResponder === field
        )
    }

    func testEmptyTodoAddCommitsOnReturnAndKeepsAdding() throws {
        let harness = try HostedTodoPanel(document: .empty)
        harness.layout()
        harness.addButton.performClick(nil)
        harness.layout()

        let field = harness.rows[0].field
        field.stringValue = "测试待办"
        XCTAssertTrue(harness.submitReturn(on: field))
        harness.layout()

        XCTAssertEqual(try harness.savedTexts(), ["测试待办"])
        XCTAssertEqual(harness.changes.count, 1)
        XCTAssertEqual(harness.rows.count, 2, "Return in adding should commit and keep a new draft row")
        XCTAssertFalse(harness.rows[0].field.isEditable)
        XCTAssertTrue(harness.rows[1].field.isEditable)
        XCTAssertEqual(harness.rows[0].field.stringValue, "测试待办")
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
        XCTAssertNil(harness.rows[2].field.placeholderString)
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

    func testProductionPanelWindowControllerEmptyAddCreatesFocusedRow() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] != nil,
            "PanelWindowController.enterEditing activates the app, which hung GitHub-hosted macOS runners"
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTodoController-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let environment = try AppEnvironment.isolatedForTesting(root: root)
        XCTAssertTrue(ApplicationDataLocation.isIsolatedFromUserData(environment.applicationSupportRoot))
        let manager = PanelManager(environment: environment)
        XCTAssertTrue(manager.createPanel(kindIdentifier: PanelKind.todo))

        let window = try XCTUnwrap(manager.windows.first)
        window.layoutIfNeeded()
        let chrome = try XCTUnwrap(window.contentView as? PanelChromeView)
        chrome.layoutSubtreeIfNeeded()
        let panel = try XCTUnwrap(views(of: TodoPanelView.self, in: chrome).first)
        let addButton = try XCTUnwrap(
            views(of: NSButton.self, in: panel).first { $0.title == "添加待办" }
        )
        XCTAssertEqual(views(of: TodoRowView.self, in: panel).count, 0)

        let buttonInChrome = addButton.convert(addButton.bounds, to: chrome)
        let center = NSPoint(x: buttonInChrome.midX, y: buttonInChrome.midY)
        let hit = chrome.hitTest(center)
        XCTAssertTrue(
            hit === addButton || hit?.ancestor(of: NSButton.self) === addButton,
            "production chrome hit test missed add button: \(String(describing: hit)) buttonFrame=\(buttonInChrome) chrome=\(chrome.bounds)"
        )

        addButton.performClick(nil)
        window.layoutIfNeeded()
        panel.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        window.layoutIfNeeded()
        panel.layoutSubtreeIfNeeded()

        let rows = views(of: TodoRowView.self, in: panel)
        XCTAssertEqual(rows.count, 1, "production add click must create the adding row")
        XCTAssertTrue(rows[0].field.isEditable)
        XCTAssertGreaterThan(rows[0].frame.width, 1)
        XCTAssertGreaterThan(rows[0].frame.height, 0)
        XCTAssertTrue(
            window.firstResponder === rows[0].field.currentEditor() || window.firstResponder === rows[0].field,
            "field must be first responder, got \(String(describing: window.firstResponder)) key=\(window.isKeyWindow) allowsKey=\((window as? PanelWindow)?.allowsKey ?? false)"
        )
    }

    func testProductionResignKeyAfterAddHandshakeCancelsEmptyDraft() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] != nil,
            "PanelWindowController.enterEditing activates the app, which hung GitHub-hosted macOS runners"
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTodoResign-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let environment = try AppEnvironment.isolatedForTesting(root: root)
        let manager = PanelManager(environment: environment)
        XCTAssertTrue(manager.createPanel(kindIdentifier: PanelKind.todo))
        let window = try XCTUnwrap(manager.windows.first)
        let chrome = try XCTUnwrap(window.contentView as? PanelChromeView)
        window.layoutIfNeeded()
        chrome.layoutSubtreeIfNeeded()
        let panel = try XCTUnwrap(views(of: TodoPanelView.self, in: chrome).first)
        let addButton = try XCTUnwrap(
            views(of: NSButton.self, in: panel).first { $0.title == "添加待办" }
        )
        addButton.performClick(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(views(of: TodoRowView.self, in: panel).count, 1)

        window.delegate?.windowDidResignKey?(Notification(name: NSWindow.didResignKeyNotification, object: window))
        window.layoutIfNeeded()
        XCTAssertFalse(panel.isAddingForTests)
        XCTAssertEqual(views(of: TodoRowView.self, in: panel).count, 0)
    }

    func testProductionNonKeyAccessoryPanelMouseClickAddsRow() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] != nil,
            "synthetic mouse events are not reliable on GitHub-hosted macOS runners"
        )
        _ = NSApplication.shared
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.accessory)
        defer { NSApp.setActivationPolicy(previousPolicy) }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceTodoAccessory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let environment = try AppEnvironment.isolatedForTesting(root: root)
        let manager = PanelManager(environment: environment)
        XCTAssertTrue(manager.createPanel(kindIdentifier: PanelKind.todo))

        let window = try XCTUnwrap(manager.windows.first as? PanelWindow)
        window.orderFrontRegardless()
        NSApp.deactivate()
        window.layoutIfNeeded()
        XCTAssertFalse(window.allowsKey)
        XCTAssertFalse(window.isKeyWindow)

        let chrome = try XCTUnwrap(window.contentView as? PanelChromeView)
        chrome.layoutSubtreeIfNeeded()
        let panel = try XCTUnwrap(views(of: TodoPanelView.self, in: chrome).first)
        let addButton = try XCTUnwrap(
            views(of: NSButton.self, in: panel).first { $0.title == "添加待办" }
        )
        let buttonInChrome = addButton.convert(addButton.bounds, to: chrome)
        let hit = chrome.hitTest(NSPoint(x: buttonInChrome.midX, y: buttonInChrome.midY))
        XCTAssertTrue(
            hit === addButton || hit?.ancestor(of: NSButton.self) === addButton,
            "non-key accessory chrome missed add button: \(String(describing: hit)) frame=\(buttonInChrome)"
        )

        let location = addButton.convert(
            NSPoint(x: addButton.bounds.midX, y: addButton.bounds.midY),
            to: nil
        )
        let timestamp = ProcessInfo.processInfo.systemUptime
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: location,
            modifierFlags: [],
            timestamp: timestamp,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 11,
            clickCount: 1,
            pressure: 1
        ))
        let up = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: location,
            modifierFlags: [],
            timestamp: timestamp + 0.05,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 12,
            clickCount: 1,
            pressure: 0
        ))
        window.sendEvent(down)
        window.sendEvent(up)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        window.layoutIfNeeded()
        panel.layoutSubtreeIfNeeded()

        XCTAssertTrue(panel.isAddingForTests, "add click must enter adding session")
        let rows = views(of: TodoRowView.self, in: panel)
        XCTAssertEqual(
            rows.count,
            1,
            "non-key accessory mouse click must create the adding row; firstResponder=\(String(describing: window.firstResponder)) key=\(window.isKeyWindow)"
        )
        XCTAssertTrue(rows[0].field.isEditable)
        XCTAssertGreaterThan(rows[0].frame.width, 1)
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

    func testEmptyTodoAddSurvivesSpuriousEndEditingFromTheAddClick() throws {
        let harness = try HostedTodoPanel(document: .empty, embedInChrome: true)
        if let panelWindow = harness.window as? PanelWindow {
            panelWindow.allowsKey = false
        }
        harness.layout()
        harness.installProductionEditingHandoff()

        harness.addButton.performClick(nil)
        XCTAssertEqual(harness.rows.count, 1, "Add must create a row before any follow-up end-editing")
        let field = harness.rows[0].field
        field.delegate?.controlTextDidEndEditing?(
            Notification(name: NSControl.textDidEndEditingNotification, object: field)
        )

        XCTAssertEqual(
            harness.rows.count,
            1,
            "empty end-editing from the same Add click must not abort the new row"
        )
        XCTAssertTrue(harness.rows[0].field.isEditable)
        XCTAssertFalse(harness.placeholderVisible)
        XCTAssertEqual(try harness.savedTexts(), [])
        XCTAssertEqual(harness.changes.count, 0)
        let restored = harness.rows[0].field
        XCTAssertTrue(
            harness.window.firstResponder === restored.currentEditor() || harness.window.firstResponder === restored,
            "empty adding row must keep focus so the user can type immediately"
        )
    }

    func testTypedAddingDraftStillCommitsOnEndEditing() throws {
        let harness = try HostedTodoPanel(document: .empty)
        harness.layout()
        harness.addButton.performClick(nil)
        harness.layout()
        let field = harness.rows[0].field
        field.stringValue = "回复邮件"
        field.delegate?.controlTextDidEndEditing?(
            Notification(name: NSControl.textDidEndEditingNotification, object: field)
        )
        harness.layout()
        XCTAssertEqual(try harness.savedTexts(), ["回复邮件"])
        XCTAssertEqual(harness.changes.count, 1)
        XCTAssertEqual(harness.rows.count, 1)
        XCTAssertFalse(harness.rows[0].field.isEditable)
    }

    func testAddButtonHitTestBeatsBottomResizeAcrossTheButtonFrame() throws {
        let harness = try HostedTodoPanel(document: .empty, embedInChrome: true)
        harness.layout()
        let chrome = try XCTUnwrap(harness.chrome)
        let button = harness.addButton
        let buttonInChrome = button.convert(button.bounds, to: chrome)

        XCTAssertGreaterThan(buttonInChrome.width, 1, "add button width \(buttonInChrome)")
        XCTAssertGreaterThan(buttonInChrome.height, 1, "add button height \(buttonInChrome)")
        XCTAssertGreaterThan(
            buttonInChrome.minY,
            GlanceConstants.resizeEdge,
            "add button overlaps the bottom resize edge: button=\(buttonInChrome) chrome=\(chrome.bounds)"
        )

        let samples = [
            NSPoint(x: buttonInChrome.midX, y: buttonInChrome.midY),
            NSPoint(x: buttonInChrome.minX + 4, y: buttonInChrome.midY),
            NSPoint(x: buttonInChrome.midX, y: buttonInChrome.minY + 2),
            NSPoint(x: buttonInChrome.midX, y: buttonInChrome.maxY - 2)
        ]
        for point in samples {
            let hit = chrome.hitTest(point)
            XCTAssertTrue(
                hit === button || hit?.ancestor(of: NSButton.self) === button,
                "click at \(point) in button frame \(buttonInChrome) hit \(String(describing: hit)) instead of the add button"
            )
        }
    }

    func testEmptyTodoAddMouseClickOnProductionPanelCreatesFocusedRow() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] != nil,
            "synthetic mouse events are not reliable on GitHub-hosted macOS runners"
        )
        let harness = try HostedTodoPanel(document: .empty, embedInChrome: true)
        if let panelWindow = harness.window as? PanelWindow {
            panelWindow.allowsKey = false
        }
        harness.layout()
        harness.installProductionEditingHandoff()
        XCTAssertEqual(harness.rows.count, 0)

        XCTAssertTrue(harness.clickAddButtonWithMouse(), "Add button mouse click must dispatch")
        XCTAssertEqual(harness.rows.count, 1, "real mouse click must create the adding row")
        XCTAssertFalse(harness.placeholderVisible)
        let field = harness.rows[0].field
        XCTAssertTrue(field.isEditable)
        XCTAssertGreaterThan(harness.rows[0].frame.width, 1)
        XCTAssertGreaterThan(harness.rows[0].frame.height, 0)
        XCTAssertTrue(
            harness.window.firstResponder === field.currentEditor() || harness.window.firstResponder === field,
            "field must be first responder after the Add mouse click, got \(String(describing: harness.window.firstResponder))"
        )
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

    func installProductionEditingHandoff() {
        panel.onRequestEditing = { [panel, window] in
            (window as? PanelWindow)?.allowsKey = true
            window.makeKeyAndOrderFront(nil)
            panel.enterEditing()
        }
    }

    @discardableResult
    func clickAddButtonWithMouse() -> Bool {
        let button = addButton
        let location = button.convert(
            NSPoint(x: button.bounds.midX, y: button.bounds.midY),
            to: nil
        )
        let timestamp = ProcessInfo.processInfo.systemUptime
        guard
            let down = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: location,
                modifierFlags: [],
                timestamp: timestamp,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            ),
            let up = NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: location,
                modifierFlags: [],
                timestamp: timestamp + 0.05,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 0
            )
        else {
            return false
        }
        window.sendEvent(down)
        window.sendEvent(up)
        return true
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
