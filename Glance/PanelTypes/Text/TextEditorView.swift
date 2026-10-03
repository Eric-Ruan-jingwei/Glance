import AppKit

final class GlanceTextView: NSTextView {
    var isReadingMode = true
    var allowsMove = true
    var allowsContentMutation = true
    var onBeginEditing: (() -> Void)?
    var onRequestEndEditing: (() -> Void)?
    var onChecklistToggled: (() -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        if let chrome = window?.contentView as? PanelChromeView {
            chrome.rightMouseDown(with: event)
            return
        }
        super.rightMouseDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if isReadingMode {
            if event.clickCount >= 2 {
                if allowsContentMutation {
                    onBeginEditing?()
                }
                return
            }
            if allowsContentMutation, toggleChecklist(at: event) {
                return
            }
            if allowsMove, let window {
                PanelWindowDrag.moveThenFinishInteractive(window)
            }
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onRequestEndEditing?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !isReadingMode, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "b":
            toggleBold()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    func toggleBold() {
        let range = selectedRange()
        let current = (typingAttributes[.font] as? NSFont) ?? GlanceConstants.textBodyFont
        let hasBold = current.fontDescriptor.symbolicTraits.contains(.bold)
        let converted: NSFont
        if hasBold {
            converted = NSFontManager.shared.convert(current, toNotHaveTrait: .boldFontMask)
        } else {
            converted = NSFontManager.shared.convert(current, toHaveTrait: .boldFontMask)
        }
        if range.length == 0 {
            typingAttributes[.font] = converted
        } else {
            textStorage?.addAttribute(.font, value: converted, range: range)
            typingAttributes[.font] = converted
        }
        didChangeText()
    }

    func insertBullet() {
        insertParagraphPrefix("• ")
    }

    func insertChecklist() {
        insertParagraphPrefix("☐ ")
    }

    private func insertParagraphPrefix(_ prefix: String) {
        guard let textStorage else { return }
        let ns = textStorage.string as NSString
        let lineRange = ns.lineRange(for: selectedRange())
        if lineRange.length == 0 {
            insertText(prefix, replacementRange: selectedRange())
            return
        }
        let line = ns.substring(with: lineRange)
        if line.hasPrefix("• ") || line.hasPrefix("☐ ") || line.hasPrefix("☑ ") {
            let stripped = String(line.dropFirst(2))
            textStorage.replaceCharacters(in: lineRange, with: prefix + stripped)
        } else {
            textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: prefix)
        }
        didChangeText()
    }

    private func toggleChecklist(at event: NSEvent) -> Bool {
        guard let layoutManager, let textContainer, let textStorage else { return false }
        var fraction: CGFloat = 0
        let point = convert(event.locationInWindow, from: nil)
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        guard glyphIndex < layoutManager.numberOfGlyphs else { return false }
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let ns = textStorage.string as NSString
        guard charIndex < ns.length else { return false }
        let ch = ns.character(at: charIndex)
        if ch == 0x2610 { // ☐
            textStorage.replaceCharacters(in: NSRange(location: charIndex, length: 1), with: "☑")
            onChecklistToggled?()
            return true
        }
        if ch == 0x2611 { // ☑
            textStorage.replaceCharacters(in: NSRange(location: charIndex, length: 1), with: "☐")
            onChecklistToggled?()
            return true
        }
        return false
    }
}
