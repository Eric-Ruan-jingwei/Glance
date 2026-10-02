import AppKit
import UniformTypeIdentifiers

@MainActor
final class ImagePanelView: NSView, PanelContentControlling {
    var view: NSView { self }
    let minimumSize: NSSize = GlanceConstants.imageMinSize
    var onPayloadChange: (() -> Void)?
    var onRequestEditing: (() -> Void)?
    var onRequestPreferredSize: ((NSSize) -> Void)?
    var allowsMove = true
    var allowsContentMutation = true

    private let imageView = NSImageView()
    private let placeholder = NSTextField(wrappingLabelWithString: "拖入、粘贴或右键选择图片")
    private let media = MediaStore()
    private var hasImage = false

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) throws {
        if let image = try media.loadImage(from: directory) {
            apply(image, resizePanel: false)
        } else {
            apply(nil, resizePanel: false)
        }
    }

    func savePayload(to directory: URL) throws {
        guard let image = imageView.image else { return }
        _ = try media.writePNG(image, to: directory)
    }

    func enterEditing() {}
    func exitEditing() {}

    func additionalContextMenuItems() -> [NSMenuItem] {
        let replace = NSMenuItem(title: "更换图片", action: #selector(replaceImage), keyEquivalent: "")
        replace.target = self
        let paste = NSMenuItem(title: "粘贴图片", action: #selector(pasteImage), keyEquivalent: "v")
        paste.keyEquivalentModifierMask = [.command]
        paste.target = self
        return [replace, paste]
    }

    func handlePaste() -> Bool {
        guard allowsContentMutation else { return false }
        guard let image = media.imageFromPasteboard() else { return false }
        apply(image, resizePanel: true)
        onPayloadChange?()
        return true
    }

    private func setup() {
        registerForDraggedTypes([.fileURL, .png, .tiff])

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.animates = false
        imageView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.alignment = .center
        placeholder.textColor = .tertiaryLabelColor
        placeholder.font = .systemFont(ofSize: 12)
        placeholder.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageView)
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholder.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            placeholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    override func rightMouseDown(with event: NSEvent) {
        if let chrome = window?.contentView as? PanelChromeView {
            chrome.rightMouseDown(with: event)
            return
        }
        super.rightMouseDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        guard allowsMove, let window else { return }
        PanelWindowDrag.move(window) {
            (window.windowController as? PanelWindowController)?.recoverAndApplyFrame()
        }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        allowsContentMutation ? .copy : []
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard allowsContentMutation else { return false }
        let pb = sender.draggingPasteboard
        if let image = media.imageFromPasteboard(pb) {
            apply(image, resizePanel: true)
            onPayloadChange?()
            return true
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           let image = media.image(fromFileURL: url) {
            apply(image, resizePanel: true)
            onPayloadChange?()
            return true
        }
        return false
    }

    @objc func paste(_ sender: Any?) {
        _ = handlePaste()
    }

    @objc private func pasteImage() {
        _ = handlePaste()
    }

    @objc private func replaceImage() {
        guard allowsContentMutation else { return }
        NSApp.activate(ignoringOtherApps: true)
        guard let url = media.chooseImageFile(), let image = media.image(fromFileURL: url) else { return }
        apply(image, resizePanel: true)
        onPayloadChange?()
    }

    private func apply(_ image: NSImage?, resizePanel: Bool) {
        imageView.image = image
        hasImage = image != nil
        placeholder.isHidden = hasImage
        if resizePanel, let image {
            onRequestPreferredSize?(media.fittingSize(for: image))
        }
    }
}
