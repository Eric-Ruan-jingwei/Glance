import AppKit

enum MarkdownPreviewAppearance {
    static func nsAttributedString(from source: String) -> NSAttributedString {
        let parsed = MarkdownDocument.attributedPreview(from: source)
        let mutable = NSMutableAttributedString(parsed)
        let full = NSRange(location: 0, length: mutable.length)
        guard full.length > 0 else { return mutable }

        mutable.addAttribute(.font, value: GlanceTheme.Typography.body, range: full)
        mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        mutable.addAttribute(.paragraphStyle, value: GlanceTheme.Reading.bodyParagraphStyle(), range: full)

        for run in parsed.runs {
            let nsRange = NSRange(run.range, in: parsed)
            guard nsRange.location != NSNotFound,
                  NSMaxRange(nsRange) <= mutable.length else { continue }
            if let intent = run.presentationIntent {
                for component in intent.components {
                    switch component.kind {
                    case .header(let level):
                        mutable.addAttribute(
                            .font,
                            value: GlanceTheme.Typography.heading(level),
                            range: nsRange
                        )
                        mutable.addAttribute(
                            .paragraphStyle,
                            value: GlanceTheme.Reading.headingParagraphStyle(level: level),
                            range: nsRange
                        )
                    case .codeBlock:
                        applyCodeStyle(mutable, range: nsRange, block: true)
                    case .blockQuote:
                        mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: nsRange)
                        mutable.addAttribute(
                            .paragraphStyle,
                            value: GlanceTheme.Reading.quoteParagraphStyle(),
                            range: nsRange
                        )
                    case .listItem, .unorderedList, .orderedList:
                        mutable.addAttribute(
                            .paragraphStyle,
                            value: GlanceTheme.Reading.listParagraphStyle(),
                            range: nsRange
                        )
                    default:
                        break
                    }
                }
            }
            if let inline = run.inlinePresentationIntent, inline.contains(.code) {
                applyCodeStyle(mutable, range: nsRange, block: false)
            }
            if run.link != nil {
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
                mutable.addAttribute(.foregroundColor, value: NSColor.linkColor, range: nsRange)
            }
        }

        applyCheckboxGlyphs(mutable)
        return mutable
    }

    private static func applyCheckboxGlyphs(_ storage: NSMutableAttributedString) {
        let ns = storage.string as NSString
        for (glyph, color) in [("☐", NSColor.secondaryLabelColor), ("☑", NSColor.tertiaryLabelColor)] {
            var location = 0
            while location < ns.length {
                let remaining = NSRange(location: location, length: ns.length - location)
                let found = ns.range(of: glyph, options: [], range: remaining)
                if found.location == NSNotFound { break }
                storage.addAttribute(.foregroundColor, value: color, range: found)
                location = NSMaxRange(found)
            }
        }
    }

    private static func applyCodeStyle(_ storage: NSMutableAttributedString, range: NSRange, block: Bool) {
        storage.addAttribute(.font, value: GlanceTheme.Typography.code, range: range)
        storage.addAttribute(
            .backgroundColor,
            value: NSColor.labelColor.withAlphaComponent(block ? 0.05 : 0.06),
            range: range
        )
        if block {
            storage.addAttribute(
                .paragraphStyle,
                value: GlanceTheme.Reading.codeParagraphStyle(),
                range: range
            )
        }
    }
}
