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

Examples in this tree: `PanelRecord`, `PanelTitle`, `PanelTag`, `PanelTags`, `PanelFrame`, `PanelDatabase`, `PanelRepository`, `WorkspaceRecord`, `WorkspaceName`, `WorkspaceCatalog`, `WorkspaceMembership`, `ActiveWorkspaceResolver`, `WorkspacePreferenceStore`, `PanelInteractionPolicy`, `PanelInteractionState`, `PanelModeTransition`, `PanelOpacity`, `PayloadDirtyFlag`, `PanelPlacementEngine` (geometry), `PanelPlacementOccupancy`, `PanelSnapEngine`, `PanelLayoutPreset`, `PanelSnapConfiguration`, `PanelFrameRecovery` (geometry), `ApplicationDataLocation`, `PayloadStore`, `MarkdownPayloadFile`, `MarkdownDocument`, `TodoItem`, `TodoDocument`, `TodoMutation`, `TodoPayloadFile`, `QuickCaptureRequest`, `QuickCaptureKind`, `ClipboardCaptureContent`, `ClipboardCaptureRouter`, `ClipboardHistoryRecord`, `ClipboardHistoryDatabase`, `ClipboardHistoryPolicy`, `ClipboardHistoryHasher`, `ClipboardHistorySearch`, `ClipboardHistoryRetention`, `FileShelfRecord`, `FileShelfDatabase`, `FileShelfPolicy`, `FileShelfIdentity`, `FileShelfClassifier`, `FileShelfSearch`, `FileShelfRetention`, `FileShelfDropParser`, `FileShelfDragPayload`, `FileShelfActionPolicy`, `SnippetRecord`, `SnippetDatabase`, `SnippetPolicy`, `SnippetDraft`, `SnippetValidation`, `SnippetTitleGenerator`, `SnippetSearch`, `SnippetSort`, `SnippetActionPolicy`, `WebLinkPolicy`, `LinkRecord`, `LinkDatabase`, `LinkDraft`, `LinkTitleGenerator`, `LinkSearch`, `LinkSort`, `LinkValidation`, `LinkDropParser`, `LinkOpenPolicy`, `PanelInitialContent`, `PanelCreationSession`, `PanelVisibilityPolicy`, `PanelVisibilityTransaction`, `PanelSummary`, `PanelSummaryInput`, `PanelSummaryQuery`, `PanelSummaryText`, `PanelSummaryLoader`, `ImagePixelSize`, `PDFDocumentMetadata`, `PDFDocumentInspector`, `PDFPayloadFile`, `PersistenceDiagnostic`, `ShortcutAction`, `GlanceShortcut`, `ShortcutStore`, `ShortcutValidator`, `GlobalSearchSource`, `GlobalSearchDocument`, `GlobalSearchEngine`, `GlobalSearchRanker`, `GlobalSearchSnapshotBuilder`, `GlobalSearchActionPlanner`.

These types should stay on Foundation (or pure Swift). They must not depend on `NSRect`, `NSWindow`, or other AppKit types.

Panel titles:

```text
Automatic title = derived from payload, not persisted
Custom title    = PanelRecord.customTitle metadata
Effective title = customTitle ?? automaticTitle
```

`PanelTitle` normalization (newline → space, trim, blank → `nil`, max length on user writes) is portable. Schema migration, effective-title overlay, and Manager search over both custom and automatic titles stay in Core. The rename prompt (`NSAlert`), panel context menu, and Panel Manager “重命名…” action stay on macOS.

Workspace vs tags:

```text
Workspace = single membership, visibility context
Tags      = zero or many string values, search/filter only
```

`PanelRecord.tags`, `PanelTags` normalization/validation, schema migration, tag filtering, tag search, and derived tag catalogs stay in Core. There is no `TagRecord`, `tags.json`, or tag UUID. The tag editor, tag chips, Manager tag filter menu, and context-menu “编辑标签…” action stay on macOS. Tag editor keeps unsaved draft/input local until explicit Save; Save flushes pending input into the committed tag list. Panel Manager multi-selection is session-only UI state. Batch metadata operations (hide/show, workspace move, add/remove tags) are atomic at the `panels.json` level: one in-memory mutation, one save, full rollback on failure.

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
workspace name dialogs
shortcut recorder UI
NSScreen.visibleFrame
drag / modifier flags for snap
NSWindow orderOut / orderFront
```

AppKit adapters convert `PanelFrame` ↔ `NSRect`. Carbon hotkeys, `SMAppService`, `NSPasteboard`, `NSScreen`, SwiftUI settings windows, and the Quick Capture `NSPanel` stay here.

Quick Capture itself is not persisted. The window classifies text, http(s) URLs, and local file URLs, then calls existing Snippet, Link, File Shelf, or Panel APIs. `QuickCaptureRequest` remains the Text-panel creation intent. Closing capture discards the draft.

Clipboard Capture is also not persisted as a separate object. `ClipboardCaptureContent` is a one-shot intent. `MacClipboardReader` reads `NSPasteboard` only when the user invokes the command. Capture priority is valid image → valid text → unsupported.

Clipboard Shelf history lives beside panels, not inside them. Core owns `ClipboardHistoryRecord`, hashing, search, favorites, and retention. `ClipboardHistoryMonitor`, `MacClipboardWriter`, ImageIO thumbnails, and the shelf window stay in the macOS adapter.

File Shelf is a third peer domain. Core owns `FileShelfRecord`, filename search, favorites, retention, drop parsing, and drag-payload policy. It stores a path string and metadata only — never `URL`, bookmark bytes, `NSImage`, or `UTType`. `MacFileReferenceAdapter` writes bookmark sidecars; `MacFileShelfActions` and the File Shelf window stay on macOS. Glance never copies the user’s original file into Application Support.

Snippets are a fourth peer domain. Core owns `SnippetRecord`, title generation, validation, search, pin sort, and draft commit. The library window and `MacClipboardWriter` stay on macOS. Snippet copy adopts the clipboard monitor change count so Glance does not re-ingest its own write. Clipboard History favorites are unchanged.

Links are a fifth peer domain. Core owns `LinkRecord`, `WebLinkPolicy`, title generation, search, pin sort, drop parsing, and open routing. The library window, `NSWorkspace` open, and clipboard write stay on macOS. Link copy adopts the clipboard monitor change count. Glance does not fetch webpage metadata.

Global Search is a sixth capability, not a sixth data domain. Core owns `GlobalSearchDocument`, ranking, snapshot projection, and action planning. It depends on the five existing domains and never the reverse. The search window, Carbon hotkey, and status-menu item stay on macOS. Search documents are not persisted.

Cross-module workflow actions live in `GlanceActionCoordinator`. Snippets, Links, and File Shelf do not import `PanelManager`. File Shelf → Panel copies into existing Panel storage. Global Search `⌘Enter` reveals a live record through each library’s `present(selecting:)` API. Clipboard self-writes go through `GlanceClipboardWriter` so the monitor adopts the change count.

PDF payload files (`document.pdf`, `pdf.json`) are portable. `MacPDFImporter` uses `NSOpenPanel` on the main actor. Validation and page-count inspection use Core Graphics (`CGPDFDocument`) so large copies can leave the main actor. `PDFView` stays on macOS for rendering. Glance does not write PDFKit archives.

Panel summaries:

```text
immutable PanelSummaryInput snapshot (MainActor)
→ background payload inspection (bounded TaskGroup)
→ MainActor apply with generation / cancel
```

Heavy payload inspection does not own mutable `PanelRecord` references. Image dimensions use ImageIO metadata (`CGImageSourceCreateWithURL`) rather than decoding a bitmap. Search, type filter, tag filter, and selection stay in-memory over the last applied summaries.

Persistence diagnostics are derived from `PanelRepository.lastLoadOutcome`. They are local, informational, and never auto-repair or delete user bytes. The status menu shows a recovery item only for backup recovery, quarantined corrupt metadata, or an unsupported future schema.

Panel window move uses `NSWindow.performWindowDrag(with:)` plus a mouse-up finish callback. There is no blocking `nextEvent` poll loop. Snap still runs at drag end; Control at release still bypasses snap.

Global shortcut preferences (`ShortcutAction`, `GlanceShortcut`) are app settings, not panel data. They live in `UserDefaults`, outside `panels.json`. `MacShortcutAdapter` maps portable keys onto Carbon virtual key codes, `RegisterEventHotKey`, `NSEvent`, and `NSMenu` key equivalents. The shortcut recorder UI stays on macOS. Recording temporarily suspends the target Carbon hotkey; a successful replace finishes that suspension without a second register, so the new combination can fire immediately. Settings and the status menu show the session’s active registration, not a stale preference snapshot.

Effective panel visibility is layered:

```text
effectiveVisible =
  panel.workspaceID == activeWorkspaceID
  && !panel.isHidden
  && !globalConcealed
```

These three states are independent. Switching workspace does not change `isHidden` or Global Hide. Global Hide does not change workspace membership. `PanelRecord.isHidden` and `workspaceID` are persistent. Global Hide / Show is a runtime override (`GlobalVisibilityController`) and is not stored on the panel. The active workspace id is a `UserDefaults` preference (`com.glance.workspace.activeID`), not part of `panels.json`. Schema 1 databases migrate missing `isHidden` to `false` and assign `workspaceID = default`. Schema 2 databases keep `isHidden` and assign every panel to the Default workspace. Schema 3 databases keep workspace membership and set `customTitle = nil`. Schema 4 databases keep `customTitle` and set `tags = []`. Tags do not participate in `effectiveVisible`. AppKit `NSWindow.orderOut` / `orderFrontRegardless`, the workspace status menu, Panel Manager sidebar, workspace name dialogs, panel title prompts, and tag editors stay on macOS.

## Future Windows

Future Windows client should reuse Core models/data contracts and provide Windows-specific adapters for windowing, shortcuts, startup, tray, clipboard, and display APIs.

Do not pick a Windows UI stack in this document. The on-disk JSON + payload files are the contract.
