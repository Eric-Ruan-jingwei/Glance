import AppKit

final class MarkdownPanelTextView: NSTextView {
    var isReadingMode = true
    var allowsMove = true
    var allowsContentMutation = true
    var onBeginEditing: (() -> Void)?
    var onRequestEndEditing: (() -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        if let chrome = window?.contentView as? PanelChromeView {
            chrome.rightMouseDown(with: event)
            return
        }
        super.rightMouseDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if isReadingMode {
            switch PanelReadingClick.markdownAction(
                isInText: isPointInText(event),
                hitsLink: isPointOnLink(event),
                allowsContentMutation: allowsContentMutation
            ) {
            case .followLink, .selectText:
                prepareReadingSelection()
                super.mouseDown(with: event)
            case .beginEditing:
                onBeginEditing?()
            case .movePanel:
                if allowsMove, let window {
                    PanelWindowDrag.moveThenFinishInteractive(window, with: event)
                }
            case .toggleChecklist:
                break
            }
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, !isReadingMode {
            onRequestEndEditing?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers == "c",
           selectedRange().length > 0 {
            copy(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func prepareReadingSelection() {
        guard let panel = window as? PanelWindow else { return }
        panel.allowsKey = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        panel.makeFirstResponder(self)
    }

    private func isPointInText(_ event: NSEvent) -> Bool {
        guard let layoutManager, let textContainer else { return false }
        let point = convert(event.locationInWindow, from: nil)
        let used = layoutManager.usedRect(for: textContainer)
        let inset = textContainerInset
        let textRect = used.offsetBy(dx: inset.width, dy: inset.height).insetBy(dx: -4, dy: -4)
        return textRect.contains(point)
    }

    private func isPointOnLink(_ event: NSEvent) -> Bool {
        guard let textStorage else { return false }
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        guard index >= 0, index < textStorage.length else { return false }
        return textStorage.attribute(.link, at: index, effectiveRange: nil) != nil
    }
}
