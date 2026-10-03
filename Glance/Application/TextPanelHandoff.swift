import Foundation

struct TextPanelHandoff: Equatable {
    var customTitle: String?
    var content: String
    var kindIdentifier: String = PanelKind.text
}

enum SnippetPanelHandoff {
    static func request(from record: SnippetRecord) -> TextPanelHandoff {
        TextPanelHandoff(customTitle: record.title, content: record.content)
    }
}

enum LinkPanelHandoff {
    static func request(from record: LinkRecord) -> TextPanelHandoff {
        TextPanelHandoff(customTitle: record.title, content: record.urlString)
    }
}
