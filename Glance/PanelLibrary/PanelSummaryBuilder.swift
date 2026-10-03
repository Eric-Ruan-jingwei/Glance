import AppKit

enum PanelSummaryBuilder {
    static func summarize(record: PanelRecord, payloadDirectory: URL) -> PanelSummary {
        let base = PanelSummary(
            id: record.id,
            kindIdentifier: record.kindIdentifier,
            title: fallbackTitle(for: record.kindIdentifier),
            subtitle: nil,
            preview: "",
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            isLocked: record.isLocked,
            isPassThrough: record.isPassThrough,
            isPinned: record.isPinned,
            isUnreadable: false
        )
        switch record.kindIdentifier {
        case PanelKind.text:
            return summarizeText(base, directory: payloadDirectory)
        case PanelKind.markdown:
            return summarizeMarkdown(base, directory: payloadDirectory)
        case PanelKind.todo:
            return summarizeTodo(base, directory: payloadDirectory)
        case PanelKind.image:
            return summarizeImage(base, directory: payloadDirectory)
        case PanelKind.pdf:
            return summarizePDF(base, directory: payloadDirectory)
        default:
            return base
        }
    }

    private static func fallbackTitle(for kindIdentifier: String) -> String {
        switch kindIdentifier {
        case PanelKind.text: return PanelSummaryFallback.text
        case PanelKind.markdown: return PanelSummaryFallback.markdown
        case PanelKind.todo: return PanelSummaryFallback.todo
        case PanelKind.image: return PanelSummaryFallback.image
        case PanelKind.pdf: return PanelSummaryFallback.pdf
        default: return "面板"
        }
    }

    private static func summarizeText(_ base: PanelSummary, directory: URL) -> PanelSummary {
        do {
            guard let attributed = try TextPayloadFile.readAttributedString(from: directory) else {
                return base
            }
            let plain = attributed.string
            var summary = base
            summary.title = PanelSummaryText.firstNonEmptyLine(plain) ?? PanelSummaryFallback.text
            summary.preview = PanelSummaryText.truncated(plain, limit: 400)
            return summary
        } catch {
            return unreadable(base)
        }
    }

    private static func summarizeMarkdown(_ base: PanelSummary, directory: URL) -> PanelSummary {
        do {
            guard let source = try MarkdownPayloadFile.readSource(from: directory) else {
                return base
            }
            var summary = base
            summary.title = PanelSummaryText.markdownTitle(from: source) ?? PanelSummaryFallback.markdown
            summary.preview = PanelSummaryText.truncated(source, limit: 400)
            return summary
        } catch {
            return unreadable(base)
        }
    }

    private static func summarizeTodo(_ base: PanelSummary, directory: URL) -> PanelSummary {
        do {
            let document = try TodoPayloadFile.readDocument(from: directory) ?? .empty
            let derived = PanelSummaryText.todoTitle(items: document.items)
            var summary = base
            summary.title = derived.title
            summary.subtitle = derived.subtitle
            summary.preview = document.items.map(\.text).joined(separator: "\n")
            return summary
        } catch {
            return unreadable(base)
        }
    }

    private static func summarizeImage(_ base: PanelSummary, directory: URL) -> PanelSummary {
        let url = directory.appendingPathComponent("image.png")
        var summary = base
        summary.title = PanelSummaryFallback.image
        guard FileManager.default.fileExists(atPath: url.path) else {
            summary.subtitle = "PNG"
            return summary
        }
        guard let data = try? Data(contentsOf: url) else {
            return unreadable(base)
        }
        if let size = PNGImageSize.read(from: data) {
            summary.subtitle = "\(size.width) × \(size.height)"
            return summary
        }
        return unreadable(base)
    }

    private static func summarizePDF(_ base: PanelSummary, directory: URL) -> PanelSummary {
        let documentExists = PDFPayloadFile.documentExists(in: directory)
        let metadata: PDFDocumentMetadata?
        do {
            metadata = try PDFPayloadFile.readMetadata(from: directory)
        } catch {
            metadata = nil
        }

        var summary = base
        if !documentExists {
            summary.title = PanelSummaryFallback.pdfUnreadable
            summary.subtitle = PanelSummaryText.pdfSubtitle(pageCount: nil)
            summary.isUnreadable = true
            summary.preview = metadata?.displayName ?? ""
            return summary
        }

        if let metadata {
            summary.title = PanelSummaryText.pdfTitle(from: metadata.displayName)
            summary.subtitle = PanelSummaryText.pdfSubtitle(pageCount: metadata.pageCount)
            summary.preview = metadata.displayName
            return summary
        }

        summary.title = PanelSummaryFallback.pdf
        summary.subtitle = PanelSummaryText.pdfSubtitle(pageCount: nil)
        summary.preview = ""
        return summary
    }

    private static func unreadable(_ base: PanelSummary) -> PanelSummary {
        var summary = base
        summary.title = PanelSummaryFallback.unreadable
        summary.subtitle = nil
        summary.isUnreadable = true
        summary.preview = ""
        return summary
    }
}
