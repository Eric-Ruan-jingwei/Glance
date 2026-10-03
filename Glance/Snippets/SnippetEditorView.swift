import SwiftUI

struct SnippetEditorView: View {
    @Binding var session: SnippetEditorSession
    var onSave: () -> Void
    var onCancel: () -> Void
    @FocusState private var focus: SnippetEditorFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.md) {
            VStack(alignment: .leading, spacing: GlanceTheme.Space.xs) {
                Text(SnippetCopy.titleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(SnippetCopy.titleLabel, text: titleBinding)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .title)
                    .accessibilityLabel(SnippetCopy.titleLabel)
            }
            VStack(alignment: .leading, spacing: GlanceTheme.Space.xs) {
                Text(SnippetCopy.contentLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $session.draft.content)
                    .font(.body)
                    .frame(minHeight: 180)
                    .focused($focus, equals: .body)
                    .accessibilityLabel(SnippetCopy.contentLabel)
                    .overlay(
                        RoundedRectangle(cornerRadius: GlanceTheme.Radius.control, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.25))
                    )
            }
            if let error = session.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel(error)
            }
            HStack {
                Spacer()
                Button(SnippetCopy.cancelLabel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel(SnippetCopy.cancelLabel)
                Button(SnippetCopy.saveLabel, action: onSave)
                    .keyboardShortcut("s", modifiers: .command)
                    .accessibilityLabel(SnippetCopy.saveLabel)
            }
        }
        .padding(GlanceTheme.Space.lg)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            focus = session.focus
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { session.draft.title },
            set: { newValue in
                if newValue.count > SnippetPolicy.maximumTitleLength {
                    session.draft.title = String(newValue.prefix(SnippetPolicy.maximumTitleLength))
                } else {
                    session.draft.title = newValue
                }
            }
        )
    }
}
