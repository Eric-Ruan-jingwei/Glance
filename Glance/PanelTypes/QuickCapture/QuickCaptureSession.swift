import AppKit
import Foundation

struct QuickCaptureDestinations {
    var saveSnippet: (String) -> GlanceActionOutcome
    var saveLink: (String) -> GlanceActionOutcome
    var addToFileShelf: ([URL]) -> GlanceActionOutcome
    var createTextPanel: (String) -> Bool
    var createTodoPanel: (String) -> Bool
    var createImagePanel: (URL) -> Bool
    var createPDFPanel: (URL) -> Bool

    static let unavailable = QuickCaptureDestinations(
        saveSnippet: { _ in .failed(GlanceNoticeCopy.cannotSave) },
        saveLink: { _ in .failed(GlanceNoticeCopy.cannotSave) },
        addToFileShelf: { _ in .failed(GlanceNoticeCopy.fileShelfAddFailed) },
        createTextPanel: { _ in false },
        createTodoPanel: { _ in false },
        createImagePanel: { _ in false },
        createPDFPanel: { _ in false }
    )
}

enum QuickCaptureExecutor {
    static func perform(
        _ action: QuickCaptureAction,
        content: QuickCaptureContent,
        destinations: QuickCaptureDestinations
    ) -> GlanceActionOutcome {
        switch (action, content) {
        case (.saveSnippet, .text(let text)), (.saveSnippet, .url(let text)):
            return destinations.saveSnippet(text)
        case (.saveLink, .url(let urlString)):
            return destinations.saveLink(urlString)
        case (.addToFileShelf, .files(let urls)):
            return destinations.addToFileShelf(urls)
        case (.createTextPanel, .text(let text)), (.createTextPanel, .url(let text)):
            return panel(destinations.createTextPanel(text))
        case (.createTodoPanel, .text(let text)):
            if let rejection = QuickCaptureTodoPolicy.rejection(for: text) {
                return rejection
            }
            return panel(destinations.createTodoPanel(text))
        case (.createFilePanel, .files(let urls)):
            guard urls.count == 1, let url = urls.first else {
                return .failed(GlanceNoticeCopy.panelCreateFailed)
            }
            switch QuickCapturePanelFileSupport.kind(for: url) {
            case .image:
                return panel(destinations.createImagePanel(url))
            case .pdf:
                return panel(destinations.createPDFPanel(url))
            case nil:
                return .failed(GlanceNoticeCopy.panelCreateFailed)
            }
        default:
            return .failed(GlanceNoticeCopy.cannotSave)
        }
    }

    private static func panel(_ created: Bool) -> GlanceActionOutcome {
        created ? .succeeded : .failed(GlanceNoticeCopy.panelCreateFailed)
    }
}

@MainActor
final class QuickCaptureModel {
    private(set) var text = ""
    private(set) var fileURLs: [URL] = []
    private(set) var selectedAction: QuickCaptureAction?
    private(set) var error: String?
    private(set) var didComplete = false

    var content: QuickCaptureContent {
        QuickCaptureClassifier.classify(text: text, fileURLs: fileURLs)
    }

    var actions: [QuickCaptureAction] {
        QuickCapturePolicy.actions(for: content)
    }

    var allowsNewline: Bool {
        QuickCaptureNewlinePolicy.allowsNewline(content: content, selectedAction: selectedAction)
    }

    func reset() {
        text = ""
        fileURLs = []
        selectedAction = nil
        error = nil
        didComplete = false
    }

    func applyPrefill(_ content: QuickCaptureContent) {
        reset()
        switch content {
        case .empty:
            break
        case .text(let value):
            text = value
        case .url(let value):
            text = value
        case .files(let urls):
            fileURLs = urls
            text = QuickCaptureCopy.fileSummary(for: urls)
        }
        selectedAction = QuickCapturePolicy.defaultAction(for: self.content)
    }

    func setText(_ value: String) {
        if !fileURLs.isEmpty {
            let summary = QuickCaptureCopy.fileSummary(for: fileURLs)
            if value != summary {
                fileURLs = []
            }
        }
        text = value
        error = nil
        reconcileAction()
    }

    func setFiles(_ urls: [URL]) {
        fileURLs = QuickCaptureClassifier.uniquedFileURLs(urls)
        text = QuickCaptureCopy.fileSummary(for: fileURLs)
        error = nil
        reconcileAction()
    }

    func moveAction(_ delta: Int) {
        let items = actions
        guard !items.isEmpty else { return }
        let current = selectedAction.flatMap { items.firstIndex(of: $0) } ?? 0
        let next = (current + delta + items.count) % items.count
        selectedAction = items[next]
    }

    func select(_ action: QuickCaptureAction) {
        guard actions.contains(action) else { return }
        selectedAction = action
    }

    @discardableResult
    func submit(using destinations: QuickCaptureDestinations) -> Bool {
        didComplete = false
        let current = content
        guard let action = selectedAction ?? QuickCapturePolicy.defaultAction(for: current) else {
            error = QuickCaptureCopy.emptyHint
            return false
        }
        switch QuickCaptureExecutor.perform(action, content: current, destinations: destinations) {
        case .succeeded:
            error = nil
            didComplete = true
            return true
        case .failed(let message):
            error = message
            didComplete = false
            return false
        }
    }

    private func reconcileAction() {
        let items = actions
        if let selectedAction, items.contains(selectedAction) {
            return
        }
        self.selectedAction = items.first
    }
}

enum QuickCapturePasteboard {
    static func content(from pasteboard: NSPasteboard = .general) -> QuickCaptureContent {
        let types = pasteboard.types?.map(\.rawValue) ?? []
        return QuickCapturePasteboardCandidate.content(
            fileURLs: fileURLs(from: pasteboard),
            text: pasteboard.string(forType: .string),
            skipPrivacy: ClipboardPrivacyMarkers.shouldSkip(typeStrings: types)
        )
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let types = pasteboard.types?.map(\.rawValue) ?? []
        if ClipboardPrivacyMarkers.shouldSkip(typeStrings: types) {
            return []
        }
        var strings: [String] = []
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            strings.append(contentsOf: urls.map { url in
                url.isFileURL ? url.path : url.absoluteString
            })
        }
        if let items = pasteboard.pasteboardItems {
            for item in items {
                if let value = item.string(forType: .fileURL) {
                    strings.append(value)
                }
            }
        }
        return QuickCaptureClassifier.uniquedFileURLs(FileShelfDropParser.urls(from: strings))
    }
}

extension QuickCaptureDestinations {
    @MainActor
    static func live(
        environment: AppEnvironment,
        panelManager: PanelManager,
        screen: NSScreen?
    ) -> QuickCaptureDestinations {
        QuickCaptureDestinations(
            saveSnippet: { text in
                switch environment.snippetService.create(SnippetDraft(title: "", content: text)) {
                case .success:
                    return .succeeded
                case .failure(let error):
                    return .failed(error.message)
                }
            },
            saveLink: { urlString in
                switch environment.linkService.create(LinkDraft(title: "", urlString: urlString)) {
                case .success:
                    return .succeeded
                case .failure(let error):
                    return .failed(error.message)
                }
            },
            addToFileShelf: { urls in
                let result = environment.fileShelfService.add(paths: urls.map(\.path))
                return QuickCaptureFileShelfAddPolicy.outcome(for: result, inputCount: urls.count)
            },
            createTextPanel: { text in
                panelManager.createPanel(
                    from: QuickCaptureRequest(kind: .text, text: text),
                    preferredScreen: screen
                )
            },
            createTodoPanel: { text in
                panelManager.createPanel(
                    from: QuickCaptureRequest(kind: .todo, text: text),
                    preferredScreen: screen
                )
            },
            createImagePanel: { url in
                panelManager.importImage(
                    from: url,
                    customTitle: url.lastPathComponent,
                    preferredScreen: screen
                )
            },
            createPDFPanel: { url in
                do {
                    try panelManager.importPDF(
                        from: url,
                        customTitle: url.lastPathComponent,
                        preferredScreen: screen
                    )
                    return true
                } catch {
                    return false
                }
            }
        )
    }
}
