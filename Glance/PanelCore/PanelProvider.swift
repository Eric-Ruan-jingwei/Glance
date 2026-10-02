import AppKit

@MainActor
protocol PanelContentControlling: AnyObject {
    var view: NSView { get }
    var minimumSize: NSSize { get }
    var onPayloadChange: (() -> Void)? { get set }
    var onRequestEditing: (() -> Void)? { get set }
    var onRequestPreferredSize: ((NSSize) -> Void)? { get set }

    func loadPayload(from directory: URL)
    func savePayload(to directory: URL)
    func enterEditing()
    func exitEditing()
    func additionalContextMenuItems() -> [NSMenuItem]
    func handlePaste() -> Bool
}

protocol PanelProviding {
    static var kindIdentifier: String { get }
    static var defaultSize: NSSize { get }
    static var minimumSize: NSSize { get }
    static var payloadVersion: Int { get }

    @MainActor
    static func makeContent() -> PanelContentControlling
}

@MainActor
enum PanelProviderRegistry {
    @MainActor
    static func makeContent(kindIdentifier: String) -> PanelContentControlling {
        switch kindIdentifier {
        case PanelKind.text:
            return TextPanelProvider.makeContent()
        case PanelKind.image:
            return ImagePanelProvider.makeContent()
        default:
            return UnknownPanelContentController(kindIdentifier: kindIdentifier)
        }
    }

    static func minimumSize(for kindIdentifier: String) -> NSSize {
        switch kindIdentifier {
        case PanelKind.image:
            return ImagePanelProvider.minimumSize
        default:
            return TextPanelProvider.minimumSize
        }
    }

    static func defaultSize(for kindIdentifier: String) -> NSSize {
        switch kindIdentifier {
        case PanelKind.image:
            return ImagePanelProvider.defaultSize
        default:
            return TextPanelProvider.defaultSize
        }
    }

    static func payloadVersion(for kindIdentifier: String) -> Int {
        switch kindIdentifier {
        case PanelKind.image:
            return ImagePanelProvider.payloadVersion
        default:
            return TextPanelProvider.payloadVersion
        }
    }
}

@MainActor
final class UnknownPanelContentController: PanelContentControlling {
    let view: NSView
    let minimumSize: NSSize = GlanceConstants.textMinSize
    var onPayloadChange: (() -> Void)?
    var onRequestEditing: (() -> Void)?
    var onRequestPreferredSize: ((NSSize) -> Void)?

    init(kindIdentifier: String) {
        let label = NSTextField(wrappingLabelWithString: "未知面板类型\n\(kindIdentifier)")
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16)
        ])
        self.view = container
    }

    func loadPayload(from directory: URL) {}
    func savePayload(to directory: URL) {}
    func enterEditing() {}
    func exitEditing() {}
    func additionalContextMenuItems() -> [NSMenuItem] { [] }
    func handlePaste() -> Bool { false }
}
