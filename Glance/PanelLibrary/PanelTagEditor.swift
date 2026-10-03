import AppKit
import SwiftUI

enum PanelTagEditorPromptResult: Equatable {
    case cancelled
    case submitted([String])
}

final class PanelTagEditorSession: ObservableObject {
    @Published var draft: [String]
    @Published var input = ""
    @Published var errorMessage: String?
    let catalog: [String]

    init(tags: [String], catalog: [String]) {
        self.draft = PanelTags.normalized(tags)
        self.catalog = catalog
    }

    var suggestions: [String] {
        catalog.filter { candidate in
            !PanelTags.containsExact(draft, tag: candidate)
        }
    }

    func addFromInput() {
        add(PanelTags.parseInput(input))
        if errorMessage == nil {
            input = ""
        }
    }

    func addSuggestion(_ tag: String) {
        add([tag])
    }

    func remove(_ tag: String) {
        draft.removeAll { PanelTag.isEqual($0, tag) }
        errorMessage = nil
    }

    /// Parses draft plus pending input into the tags that Save should persist.
    /// Does not mutate `draft` or `input`.
    func tagsForCommit() throws -> [String] {
        var tags = draft
        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tags.append(contentsOf: PanelTags.parseInput(input))
        }
        return try PanelTags.validated(tags)
    }

    func attemptCommit() -> Result<[String], Error> {
        do {
            let tags = try tagsForCommit()
            errorMessage = nil
            return .success(tags)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法保存标签。"
            return .failure(error)
        }
    }

    private func add(_ tags: [String]) {
        errorMessage = nil
        guard !tags.isEmpty else { return }
        do {
            draft = try PanelTags.validated(draft + tags)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法添加标签。"
        }
    }
}

enum PanelTagEditorPrompt {
    static func runModal(currentTags: [String], catalog: [String]) -> PanelTagEditorPromptResult {
        let session = PanelTagEditorSession(tags: currentTags, catalog: catalog)
        var committedTags: [String]?
        let hosting = NSHostingController(
            rootView: PanelTagEditorView(
                session: session,
                onSave: { tags in
                    committedTags = tags
                    NSApp.stopModal(withCode: .OK)
                },
                onCancel: {
                    NSApp.stopModal(withCode: .cancel)
                }
            )
        )
        hosting.view.frame = NSRect(x: 0, y: 0, width: 440, height: 360)
        let window = NSWindow(contentViewController: hosting)
        window.title = "编辑标签"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 360))
        window.center()
        let delegate = CloseCancelsModalDelegate()
        window.delegate = delegate
        NSApp.activate(ignoringOtherApps: true)
        let response = NSApp.runModal(for: window)
        window.delegate = nil
        window.close()
        _ = delegate
        if response == .OK, let tags = committedTags {
            return .submitted(tags)
        }
        return .cancelled
    }

    static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if let tagError = error as? PanelTagError, tagError == .tagTooLong || tagError == .tooManyTags {
            alert.messageText = tagError.errorDescription ?? "无法保存标签。"
        } else if error is PanelTagError {
            alert.messageText = error.localizedDescription
        } else {
            alert.messageText = "无法保存标签。"
        }
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private final class CloseCancelsModalDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.stopModal(withCode: .cancel)
        return true
    }
}

private struct PanelTagEditorView: View {
    @ObservedObject var session: PanelTagEditorSession
    let onSave: ([String]) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.md) {
            Text("为这个面板设置标签。标签用于搜索和筛选，不会改变工作区或显示状态。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if session.draft.isEmpty {
                Text("还没有标签")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                TagFlowLayout {
                    ForEach(session.draft, id: \.self) { tag in
                        PanelTagChip(text: tag, onRemove: { session.remove(tag) })
                    }
                }
            }

            HStack(spacing: GlanceTheme.Space.sm) {
                TextField("新增标签…", text: $session.input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { session.addFromInput() }
                Button("添加") { session.addFromInput() }
                    .disabled(session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorMessage = session.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if !session.suggestions.isEmpty {
                Text("建议标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TagFlowLayout {
                    ForEach(Array(session.suggestions.prefix(12)), id: \.self) { tag in
                        PanelTagChip(text: tag, onAdd: { session.addSuggestion(tag) })
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("保存") {
                    if case .success(let tags) = session.attemptCommit() {
                        onSave(tags)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(GlanceTheme.Space.lg)
        .frame(width: 440, height: 360)
    }
}

enum PanelTagChipAccessibility: Equatable {
    case readOnly
    case remove
    case addSuggestion

    static func kind(onRemove: Bool, onAdd: Bool) -> PanelTagChipAccessibility {
        if onRemove { return .remove }
        if onAdd { return .addSuggestion }
        return .readOnly
    }

    var isButton: Bool {
        self != .readOnly
    }

    func label(for text: String) -> String {
        switch self {
        case .readOnly:
            return "标签：\(text)"
        case .remove:
            return "移除标签：\(text)"
        case .addSuggestion:
            return "添加标签：\(text)"
        }
    }

    func activate(onRemove: (() -> Void)?, onAdd: (() -> Void)?) {
        switch self {
        case .readOnly:
            break
        case .remove:
            onRemove?()
        case .addSuggestion:
            onAdd?()
        }
    }
}

struct PanelTagChip: View {
    let text: String
    var onRemove: (() -> Void)? = nil
    var onAdd: (() -> Void)? = nil

    private var accessibilityKind: PanelTagChipAccessibility {
        .kind(onRemove: onRemove != nil, onAdd: onAdd != nil)
    }

    var body: some View {
        switch accessibilityKind {
        case .remove:
            chipBody
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityKind.label(for: text))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default) {
                    accessibilityKind.activate(onRemove: onRemove, onAdd: onAdd)
                }
        case .addSuggestion:
            chipBody
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityKind.label(for: text))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default) {
                    accessibilityKind.activate(onRemove: onRemove, onAdd: onAdd)
                }
                .onTapGesture {
                    accessibilityKind.activate(onRemove: onRemove, onAdd: onAdd)
                }
        case .readOnly:
            chipBody
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityKind.label(for: text))
        }
    }

    private var chipBody: some View {
        HStack(spacing: GlanceTheme.Space.xxs) {
            Text(text)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .glanceChipStyle()
    }
}

struct TagFlowLayout: Layout {
    var spacing: CGFloat = GlanceTheme.Space.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(maxWidth: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
        }
        let width = maxWidth.isFinite && maxWidth < .greatestFiniteMagnitude ? maxWidth : usedWidth
        return (CGSize(width: width, height: y + rowHeight), origins)
    }
}
