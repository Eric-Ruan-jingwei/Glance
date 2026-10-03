import SwiftUI

struct LinkEditorView: View {
    @Binding var session: LinkEditorSession
    var onSave: () -> Void
    var onCancel: () -> Void
    @FocusState private var focus: LinkEditorFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Space.md) {
            VStack(alignment: .leading, spacing: GlanceTheme.Space.xs) {
                Text(LinkCopy.titleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(LinkCopy.titleLabel, text: titleBinding)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .title)
                    .accessibilityLabel(LinkCopy.titleLabel)
            }
            VStack(alignment: .leading, spacing: GlanceTheme.Space.xs) {
                Text(LinkCopy.urlLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(LinkCopy.urlLabel, text: $session.draft.urlString)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .url)
                    .accessibilityLabel(LinkCopy.urlLabel)
            }
            if let error = session.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel(error)
            }
            HStack {
                Spacer()
                Button(LinkCopy.cancelLabel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel(LinkCopy.cancelLabel)
                Button(LinkCopy.saveLabel, action: onSave)
                    .keyboardShortcut("s", modifiers: .command)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(LinkCopy.saveLabel)
            }
        }
        .padding(GlanceTheme.Space.lg)
        .frame(minWidth: 420, minHeight: 200)
        .onAppear {
            focus = session.focus
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { session.draft.title },
            set: { newValue in
                if newValue.count > LinkPolicy.maximumTitleLength {
                    session.draft.title = String(newValue.prefix(LinkPolicy.maximumTitleLength))
                } else {
                    session.draft.title = newValue
                }
            }
        )
    }
}
