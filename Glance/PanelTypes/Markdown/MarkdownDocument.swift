import Foundation

enum MarkdownTaskList {
    /// Turns `- [ ]` / `- [x]` into box glyphs for preview only. Does not change saved source.
    static func displaySource(from source: String) -> String {
        let unchecked = try! NSRegularExpression(
            pattern: #"^(\s*(?:[-*+]|\d+[.)])\s+)\[ \]\s+"#,
            options: .anchorsMatchLines
        )
        let checked = try! NSRegularExpression(
            pattern: #"^(\s*(?:[-*+]|\d+[.)])\s+)\[[xX]\]\s+"#,
            options: .anchorsMatchLines
        )
        let ns = source as NSString
        let full = NSRange(location: 0, length: ns.length)
        let step = unchecked.stringByReplacingMatches(in: source, range: full, withTemplate: "$1☐ ")
        let stepNS = step as NSString
        return checked.stringByReplacingMatches(
            in: step,
            range: NSRange(location: 0, length: stepNS.length),
            withTemplate: "$1☑ "
        )
    }
}

enum MarkdownDocument {
    static func attributedPreview(from source: String) -> AttributedString {
        let display = MarkdownTaskList.displaySource(from: source)
        guard !display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AttributedString()
        }
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full
        options.failurePolicy = .returnPartiallyParsedIfPossible
        do {
            return try AttributedString(markdown: display, options: options)
        } catch {
            return AttributedString(display)
        }
    }
}
