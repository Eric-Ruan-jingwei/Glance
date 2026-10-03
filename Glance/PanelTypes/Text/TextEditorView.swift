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
            handleReadingMouseDown(event)
            return
        }
        if event.clickCount == 1, allowsContentMutation {
            let viewPoint = convert(event.locationInWindow, from: nil)
            if toggleChecklist(atViewPoint: viewPoint) {
                return
            }
        }
        super.mouseDown(with: event)
    }

    private func handleReadingMouseDown(_ event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        switch PanelReadingClick.textAction(
            isInText: isPointInText(event),
            hitsChecklist: checklistChange(atViewPoint: viewPoint) != nil,
            allowsContentMutation: allowsContentMutation
        ) {
        case .toggleChecklist:
            _ = toggleChecklist(atViewPoint: viewPoint)
        case .beginEditing:
            beginEditing(at: viewPoint)
        case .selectText:
            prepareReadingSelection()
            super.mouseDown(with: event)
        case .followLink:
            prepareReadingSelection()
            super.mouseDown(with: event)
        case .movePanel:
            if allowsMove, let window {
                PanelWindowDrag.moveThenFinishInteractive(window, with: event)
            }
        }
    }

    private func beginEditing(at viewPoint: NSPoint) {
        let index = characterIndexForInsertion(at: viewPoint)
        onBeginEditing?()
        let length = (string as NSString).length
        setSelectedRange(NSRange(location: min(max(0, index), length), length: 0))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers == "c",
           selectedRange().length > 0 {
            copy(nil)
            return true
        }
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

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onRequestEndEditing?()
            return
        }
        super.keyDown(with: event)
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

    func toggleChecklist(atViewPoint viewPoint: NSPoint) -> Bool {
        guard let change = checklistChange(atViewPoint: viewPoint), let textStorage else { return false }
        textStorage.replaceCharacters(in: change.range, with: change.replacement)
        didChangeText()
        onChecklistToggled?()
        return true
    }

    func checklistChange(atViewPoint viewPoint: NSPoint) -> (range: NSRange, replacement: String)? {
        guard let layoutManager, let textContainer, let textStorage else { return nil }
        var fraction: CGFloat = 0
        let containerPoint = TextChecklistToggle.containerPoint(
            viewPoint: viewPoint,
            containerOrigin: textContainerOrigin
        )
        let glyphIndex = layoutManager.glyphIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }
        let glyphBounds = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        guard TextChecklistToggle.hitsGlyph(containerPoint: containerPoint, glyphBounds: glyphBounds) else {
            return nil
        }
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        return TextChecklistToggle.replacement(in: textStorage.string as NSString, at: charIndex)
    }
}

enum PanelReadingClick: Equatable {
    case toggleChecklist
    case beginEditing
    case followLink
    case selectText
    case movePanel

    static func textAction(
        isInText: Bool,
        hitsChecklist: Bool,
        allowsContentMutation: Bool
    ) -> PanelReadingClick {
        if hitsChecklist, allowsContentMutation { return .toggleChecklist }
        if isInText, allowsContentMutation { return .beginEditing }
        if isInText { return .selectText }
        return .movePanel
    }

    static func markdownAction(
        isInText: Bool,
        hitsLink: Bool,
        allowsContentMutation: Bool
    ) -> PanelReadingClick {
        if !isInText { return .movePanel }
        if hitsLink { return .followLink }
        if allowsContentMutation { return .beginEditing }
        return .selectText
    }
}

enum TextChecklistToggle {
    static let unchecked: unichar = 0x2610
    static let checked: unichar = 0x2611
    static let hitSlop: CGFloat = 6

    static func containerPoint(viewPoint: NSPoint, containerOrigin: NSPoint) -> NSPoint {
        NSPoint(x: viewPoint.x - containerOrigin.x, y: viewPoint.y - containerOrigin.y)
    }

    static func hitsGlyph(containerPoint: NSPoint, glyphBounds: NSRect) -> Bool {
        glyphBounds.insetBy(dx: -hitSlop, dy: -hitSlop).contains(containerPoint)
    }

    static func replacement(in string: NSString, at charIndex: Int) -> (range: NSRange, replacement: String)? {
        guard charIndex >= 0, charIndex < string.length else { return nil }
        let markIndex: Int
        let ch = string.character(at: charIndex)
        if ch == unchecked || ch == checked {
            markIndex = charIndex
        } else if ch == 0x20, charIndex > 0 {
            let previous = string.character(at: charIndex - 1)
            guard previous == unchecked || previous == checked else { return nil }
            markIndex = charIndex - 1
        } else {
            return nil
        }
        let mark = string.character(at: markIndex)
        return (
            NSRange(location: markIndex, length: 1),
            mark == unchecked ? "☑" : "☐"
        )
    }
}
