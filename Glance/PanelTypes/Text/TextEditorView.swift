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
            hitsChecklist: checklistMarkIndex(atViewPoint: viewPoint) != nil,
            allowsContentMutation: allowsContentMutation
        ) {
        case .toggleChecklist:
            _ = toggleChecklist(atViewPoint: viewPoint)
        case .beginEditing:
            beginEditing(at: viewPoint)
        case .selectText, .followLink:
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
        } else {
            let line = ns.substring(with: lineRange)
            if line.hasPrefix("• ") || line.hasPrefix("☐ ") || line.hasPrefix("☑ ") {
                let stripped = String(line.dropFirst(2))
                textStorage.replaceCharacters(in: lineRange, with: prefix + stripped)
            } else {
                textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: prefix)
            }
        }
        if prefix.hasPrefix("☐") {
            let markLine = (textStorage.string as NSString).lineRange(for: selectedRange())
            applyChecklistMarkStyle(at: markLine.location)
        }
        didChangeText()
    }

    func toggleChecklist(atViewPoint viewPoint: NSPoint) -> Bool {
        guard let markIndex = checklistMarkIndex(atViewPoint: viewPoint), let textStorage else { return false }
        let ns = textStorage.string as NSString
        guard let spans = TextChecklistToggle.spans(in: ns, markIndex: markIndex) else { return false }
        let completed = TextChecklistToggle.isCompleted(
            usesCheckedGlyph: spans.usesCheckedGlyph,
            contentHasStrikethrough: contentHasStrikethrough(in: spans.contentRange)
        )
        if spans.usesCheckedGlyph {
            textStorage.replaceCharacters(in: spans.markRange, with: "☐")
        }
        applyChecklistMarkStyle(at: spans.markRange.location)
        applyChecklistContent(completed: !completed, range: spans.contentRange)
        didChangeText()
        onChecklistToggled?()
        return true
    }

    func checklistMarkIndex(atViewPoint viewPoint: NSPoint) -> Int? {
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
        return TextChecklistToggle.markIndex(in: textStorage.string as NSString, at: charIndex)
    }

    func refreshChecklistMarks() {
        guard let textStorage else { return }
        let ns = textStorage.string as NSString
        var location = 0
        while location < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
            if lineRange.length > 0 {
                let ch = ns.character(at: lineRange.location)
                if ch == TextChecklistToggle.checked {
                    textStorage.replaceCharacters(
                        in: NSRange(location: lineRange.location, length: 1),
                        with: "☐"
                    )
                    if let spans = TextChecklistToggle.spans(
                        in: textStorage.string as NSString,
                        markIndex: lineRange.location
                    ) {
                        applyChecklistContent(completed: true, range: spans.contentRange)
                    }
                    applyChecklistMarkStyle(at: lineRange.location)
                } else if ch == TextChecklistToggle.unchecked {
                    applyChecklistMarkStyle(at: lineRange.location)
                }
            }
            let next = NSMaxRange(lineRange)
            if next <= location { break }
            location = next
        }
    }

    private func applyChecklistMarkStyle(at markIndex: Int) {
        guard let textStorage, markIndex >= 0, markIndex < textStorage.length else { return }
        let ch = (textStorage.string as NSString).character(at: markIndex)
        guard ch == TextChecklistToggle.unchecked || ch == TextChecklistToggle.checked else { return }
        let range = NSRange(location: markIndex, length: 1)
        textStorage.addAttributes(TextChecklistToggle.markAttributes(), range: range)
        textStorage.removeAttribute(.strikethroughStyle, range: range)
        textStorage.removeAttribute(.strikethroughColor, range: range)
    }

    private func applyChecklistContent(completed: Bool, range: NSRange) {
        guard let textStorage, range.length > 0, NSMaxRange(range) <= textStorage.length else { return }
        if completed {
            textStorage.addAttributes(
                [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: NSColor.quaternaryLabelColor,
                    .foregroundColor: NSColor.tertiaryLabelColor
                ],
                range: range
            )
        } else {
            textStorage.removeAttribute(.strikethroughStyle, range: range)
            textStorage.removeAttribute(.strikethroughColor, range: range)
            textStorage.addAttribute(.foregroundColor, value: GlanceConstants.textBodyColor, range: range)
        }
    }

    private func contentHasStrikethrough(in range: NSRange) -> Bool {
        guard let textStorage, range.length > 0, range.location < textStorage.length else { return false }
        let value = textStorage.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil)
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let style = value as? Int { return style != 0 }
        return false
    }
}

enum PanelReadingClick: Equatable {
    case toggleChecklist
    case beginEditing
    case followLink
    case selectText
    case movePanel

    static func textAction(
        hitsChecklist: Bool,
        allowsContentMutation: Bool
    ) -> PanelReadingClick {
        if hitsChecklist, allowsContentMutation { return .toggleChecklist }
        if allowsContentMutation { return .beginEditing }
        return .selectText
    }

    static func markdownAction(
        hitsLink: Bool,
        allowsContentMutation: Bool
    ) -> PanelReadingClick {
        if hitsLink { return .followLink }
        if allowsContentMutation { return .beginEditing }
        return .selectText
    }
}

enum TextChecklistToggle {
    static let unchecked: unichar = 0x2610
    static let checked: unichar = 0x2611
    static let hitSlop: CGFloat = 8
    static let markSize: CGFloat = 16

    struct Spans: Equatable {
        var markRange: NSRange
        var contentRange: NSRange
        var usesCheckedGlyph: Bool
    }

    static var markFont: NSFont {
        .systemFont(ofSize: markSize, weight: .regular)
    }

    static func markAttributes() -> [NSAttributedString.Key: Any] {
        let body = GlanceConstants.textBodyFont
        let mark = markFont
        return [
            .font: mark,
            .foregroundColor: GlanceConstants.textBodyColor,
            .baselineOffset: (body.capHeight - mark.capHeight) / 2
        ]
    }

    static func containerPoint(viewPoint: NSPoint, containerOrigin: NSPoint) -> NSPoint {
        NSPoint(x: viewPoint.x - containerOrigin.x, y: viewPoint.y - containerOrigin.y)
    }

    static func hitsGlyph(containerPoint: NSPoint, glyphBounds: NSRect) -> Bool {
        glyphBounds.insetBy(dx: -hitSlop, dy: -hitSlop).contains(containerPoint)
    }

    static func markIndex(in string: NSString, at charIndex: Int) -> Int? {
        guard charIndex >= 0, charIndex < string.length else { return nil }
        let ch = string.character(at: charIndex)
        if ch == unchecked || ch == checked {
            return charIndex
        }
        if ch == 0x20, charIndex > 0 {
            let previous = string.character(at: charIndex - 1)
            if previous == unchecked || previous == checked {
                return charIndex - 1
            }
        }
        return nil
    }

    static func spans(in string: NSString, markIndex: Int) -> Spans? {
        guard let resolved = Self.markIndex(in: string, at: markIndex) else { return nil }
        let mark = string.character(at: resolved)
        let lineRange = string.lineRange(for: NSRange(location: resolved, length: 1))
        var end = NSMaxRange(lineRange)
        if end > lineRange.location {
            let last = string.character(at: end - 1)
            if last == 10 || last == 13 {
                end -= 1
            }
        }
        let contentLocation = resolved + 1
        return Spans(
            markRange: NSRange(location: resolved, length: 1),
            contentRange: NSRange(location: contentLocation, length: max(0, end - contentLocation)),
            usesCheckedGlyph: mark == checked
        )
    }

    static func isCompleted(usesCheckedGlyph: Bool, contentHasStrikethrough: Bool) -> Bool {
        usesCheckedGlyph || contentHasStrikethrough
    }
}
