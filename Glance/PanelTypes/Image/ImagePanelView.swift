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
    private let caption = NSTextField(labelWithString: "")
    private let placeholder = GlanceMessagePlaceholder()
    private let media = MediaStore()
    private var hasImage = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init() {
        super.init(frame: .zero)
        setup()
        showEmpty()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPayload(from directory: URL) throws {
        do {
            if let image = try media.loadImage(from: directory) {
                apply(image, resizePanel: false)
            } else {
                showEmpty()
            }
        } catch {
            showUnreadable()
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
        wantsLayer = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.animates = false
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = GlanceTheme.Radius.control
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        caption.font = GlanceTheme.Typography.tertiary
        caption.textColor = .tertiaryLabelColor
        caption.alignment = .center
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.alphaValue = 0

        placeholder.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageView)
        addSubview(placeholder)
        addSubview(caption)
        let inset = GlanceTheme.Size.mediaInset
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            caption.centerXAnchor.constraint(equalTo: centerXAnchor),
            caption.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -GlanceTheme.Space.xs),
            caption.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: GlanceTheme.Space.sm),
            caption.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -GlanceTheme.Space.sm),
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: topAnchor),
            placeholder.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshCaption()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshCaption()
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
        PanelWindowDrag.moveThenFinishInteractive(window, with: event)
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
        imageView.isHidden = !hasImage
        placeholder.isHidden = hasImage
        caption.stringValue = dimensionLabel(for: image)
        refreshCaption()
        if resizePanel, let image {
            onRequestPreferredSize?(media.fittingSize(for: image))
        }
    }

    private func showEmpty() {
        apply(nil, resizePanel: false)
        placeholder.apply(
            symbol: "photo",
            title: GlanceEmptyCopy.imageEmptyTitle,
            detail: GlanceEmptyCopy.imageEmptyDetail
        )
        placeholder.isHidden = false
    }

    private func showUnreadable() {
        apply(nil, resizePanel: false)
        placeholder.apply(
            symbol: "exclamationmark.triangle",
            title: GlanceEmptyCopy.imageUnreadableTitle,
            detail: GlanceEmptyCopy.imageUnreadableDetail
        )
        placeholder.isHidden = false
    }

    private func refreshCaption() {
        caption.alphaValue = hasImage && isHovered && !caption.stringValue.isEmpty ? 1 : 0
    }

    private func dimensionLabel(for image: NSImage?) -> String {
        guard let image, let rep = image.representations.first else { return "" }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        guard width > 0, height > 0 else { return "" }
        return "\(width) × \(height)"
    }
}
