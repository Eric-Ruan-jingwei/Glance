import AppKit

enum MarkdownPreviewAppearance {
    static func nsAttributedString(from source: String) -> NSAttributedString {
        let parsed = MarkdownDocument.attributedPreview(from: source)
        let mutable = NSMutableAttributedString(parsed)
        let full = NSRange(location: 0, length: mutable.length)
        guard full.length > 0 else { return mutable }

        mutable.addAttribute(.font, value: GlanceConstants.textBodyFont, range: full)
        mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)

        for run in parsed.runs {
            let nsRange = NSRange(run.range, in: parsed)
            guard nsRange.location != NSNotFound,
                  NSMaxRange(nsRange) <= mutable.length else { continue }
            if let intent = run.presentationIntent {
                for component in intent.components {
                    switch component.kind {
                    case .header(let level):
                        let sizes: [CGFloat] = [24, 20, 17, 15, 13, 13]
                        let size = sizes[max(0, min(level - 1, sizes.count - 1))]
                        mutable.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: size), range: nsRange)
                    case .codeBlock:
                        applyCodeStyle(mutable, range: nsRange)
                    case .blockQuote:
                        mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: nsRange)
                    default:
                        break
                    }
                }
            }
            if let inline = run.inlinePresentationIntent, inline.contains(.code) {
                applyCodeStyle(mutable, range: nsRange)
            }
        }

        return mutable
    }

    private static func applyCodeStyle(_ storage: NSMutableAttributedString, range: NSRange) {
        storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: range)
        storage.addAttribute(.backgroundColor, value: NSColor.labelColor.withAlphaComponent(0.08), range: range)
    }
}
