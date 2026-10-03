# Core / platform boundary

Glance is **macOS-first**. There is no Windows client in this repository. Shared types exist so a future Windows app can reuse product data and rules without rewriting them.

```text
Glance Product
│
├── Shared Core
│   ├── Models
│   ├── Persistence schema
│   ├── Interaction rules
│   └── Product logic
│
└── macOS Client
    ├── AppKit windows
    ├── Menu bar
    ├── Global shortcut
    ├── Launch at login
    ├── NSPanel
    └── macOS packaging
```

A Windows client is future work only.

## Shared Core

Responsible for:

```text
Panel metadata model
Panel state
Interaction policy
Persistence schema
Migration
Dirty state
Portable data contracts
```

Examples in this tree: `PanelRecord`, `PanelFrame`, `PanelDatabase`, `PanelRepository`, `PanelInteractionPolicy`, `PanelInteractionState`, `PanelModeTransition`, `PanelOpacity`, `PayloadDirtyFlag`, `PanelPlacementEngine` (geometry), `PanelSnapEngine`, `PanelLayoutPreset`, `PanelSnapConfiguration`, `PanelFrameRecovery` (geometry), `ApplicationDataLocation`, `PayloadStore`, `MarkdownPayloadFile`, `MarkdownDocument`, `TodoItem`, `TodoDocument`, `TodoMutation`, `TodoPayloadFile`, `QuickCaptureRequest`, `QuickCaptureKind`, `ClipboardCaptureContent`, `ClipboardCaptureRouter`, `PanelInitialContent`, `PanelCreationSession`, `PanelRevealPolicy`, `PanelSummary`, `PanelSummaryQuery`, `PanelSummaryText`, `PDFDocumentMetadata`, `PDFPayloadFile`, `ShortcutAction`, `GlanceShortcut`, `ShortcutStore`, `ShortcutValidator`.

These types should stay on Foundation (or pure Swift). They must not depend on `NSRect`, `NSWindow`, or other AppKit types.

## macOS Platform

Responsible for:

```text
Window creation
Always-on-top
Click-through implementation
Modifier keys
Global shortcut
Menu bar
Launch at login
Native file chooser
Pasteboard
AppKit rendering
PDFKit
PDFView
Screen APIs
Quick Capture window
Panel Library window
shortcut recorder UI
NSScreen.visibleFrame
drag / modifier flags for snap
```

AppKit adapters convert `PanelFrame` ↔ `NSRect`. Carbon hotkeys, `SMAppService`, `NSPasteboard`, `NSScreen`, SwiftUI settings windows, and the Quick Capture `NSPanel` stay here.

Quick Capture itself is not persisted. `QuickCaptureRequest` describes the product intent (create text or a todo). The macOS window writes an initial payload, then inserts a `PanelRecord`, only after a successful submit.

Clipboard Capture is also not persisted as a separate object. `ClipboardCaptureContent` is a one-shot intent. `MacClipboardReader` reads `NSPasteboard` only when the user invokes the command. Capture priority is valid image → valid text → unsupported.

PDF payload files (`document.pdf`, `pdf.json`) are portable. `MacPDFImporter` uses `NSOpenPanel` and PDFKit only to validate and render; it does not write PDFKit archives.

Global shortcut preferences (`ShortcutAction`, `GlanceShortcut`) are app settings, not panel data. They live in `UserDefaults`, outside `panels.json`. `MacShortcutAdapter` maps portable keys onto Carbon virtual key codes, `RegisterEventHotKey`, `NSEvent`, and `NSMenu` key equivalents. The shortcut recorder UI stays on macOS.

## Future Windows

Future Windows client should reuse Core models/data contracts and provide Windows-specific adapters for windowing, shortcuts, startup, tray, clipboard, and display APIs.

Do not pick a Windows UI stack in this document. The on-disk JSON + payload files are the contract.
