import AppKit

enum TodoPanelProvider: PanelProviding {
    static let kindIdentifier = PanelKind.todo
    static let defaultSize = GlanceConstants.todoDefaultSize
    static let minimumSize = GlanceConstants.todoMinSize
    static let payloadVersion = GlanceConstants.payloadVersionTodo

    @MainActor
    static func makeContent() -> PanelContentControlling {
        TodoPanelView()
    }
}
