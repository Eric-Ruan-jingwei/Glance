import AppKit

enum PanelInitialPayloadWriter {
    static func write(_ content: PanelInitialContent, to directory: URL) throws {
        switch content {
        case .none:
            return
        case .plainText(let text):
            try TextPayloadFile.writePlainText(text, to: directory)
        case .todoTitle(let title):
            var document = TodoDocument.empty
            guard TodoMutation.add(&document, text: title) != nil else { return }
            try TodoPayloadFile.writeDocument(document, to: directory)
        case .imagePNG(let data):
            guard !data.isEmpty, MediaStore.looksLikePNG(data) else { throw MediaStoreError.writeFailed }
            try data.write(
                to: directory.appendingPathComponent("image.png"),
                options: .atomic
            )
        }
    }
}
