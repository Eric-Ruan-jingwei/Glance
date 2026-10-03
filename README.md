# Glance

**Pin what matters. Keep it in sight.**

A lightweight, local-first floating panel app for **macOS**.

Glance is not another notes app. It is an always-on-top information layer: put the text, reference images, or PDFs you need to keep seeing on independent panels, pin them anywhere on screen, and they stay there while you work in the browser, editor, or chat.

There is no Windows client yet. Shared data contracts are documented so a future Windows app can reuse them.

## Highlights

- Native macOS
- Always on top
- Local-first
- Text, Markdown, Todo, images, and PDF
- Quick Capture from any app
- Clipboard Capture
- Customizable global shortcuts
- Panel Manager
- No account
- No cloud
- Open source

## V0.10 已支持

- Text panel
- Markdown panel (rendered preview, double-click to edit raw UTF-8 `.md`)
- Todo panel (interactive checklist with inline add/edit/complete/delete)
- Image panel
- PDF panel
- Quick Capture — capture text or a Todo without first creating an empty panel. Default: `⌥⌘J`
- Clipboard Capture — create a Text or Image panel from the current clipboard. Default: `⌥⌘B`
- Panel Manager — browse, search, reveal, and delete existing panels from one place
- Panel edge snapping
- Panel layout presets
- Always on top
- Lock
- Click-through
- Option temporary interaction
- Opacity
- Global hide/show. Default: `⌥⌘G`
- Customizable global shortcuts
- Launch at login
- Local persistence
- Multi-display recovery

The core loop is still: create a panel → put content in it → drag it where you want → it stays floating → quit and reopen, everything is still there.

Quick Capture skips the empty-panel step: use the Quick Capture shortcut from any app, type, press Enter.

Clipboard Capture skips typing: copy in another app, then use Clipboard Capture.

Default shortcuts:

```text
Quick Capture       ⌥⌘J
Clipboard Capture   ⌥⌘B
Hide / Show         ⌥⌘G
```

These can be changed in Settings.

Status-item menu (defaults shown):

```text
快速记录…              ⌥⌘J
从剪贴板创建…          ⌥⌘B
────────────
管理面板…
────────────
新建文字面板
新建 Markdown 面板
新建待办面板
新建图片面板
新建 PDF 面板…
────────────
显示全部 / 隐藏全部    ⌥⌘G
────────────
设置…
退出
```

The Dock icon is hidden. There is no traditional main window.

### Quick Capture

The default shortcut `⌥⌘J` opens a transient capture window on the display under the pointer. It is not a panel: it is not stored in `panels.json`, has no payload directory, and is discarded on close.

- Default mode is **Text**. `⌘2` (or the 待办 segment) switches to **Todo**. `⌘1` returns to Text.
- `Enter` creates one panel and closes capture. `Shift+Enter` inserts a newline in Text mode.
- Empty or whitespace-only input does not create a panel.
- `Escape` or a click outside capture closes it and drops the draft.
- If Glance is globally hidden (Hide / Show, default `⌥⌘G`), capture still appears. A submitted panel is created but stays hidden until you show all panels again.

### Clipboard Capture

Copy text or an image in any app, then trigger Clipboard Capture to create a Glance panel immediately.

Clipboard is only read when you invoke the command. Glance does not maintain clipboard history.

- Default: `⌥⌘B` (not `⌥⌘V`) so Finder’s Move Item Here / Paste Style keeps working.
- A valid image takes priority over text. If an image representation is unreadable but valid text is also present, Glance falls back to the text.
- Empty or unsupported clipboard content does not create a panel.
- If Glance is globally hidden, the new panel is created but stays concealed.

### PDF Panel

Import a local PDF into Glance and keep it floating as a reference document.

PDFs are copied into Glance's local data directory. Deleting the original file does not blank the panel.

- `新建 PDF 面板…` opens a file picker. Cancel creates nothing.
- Password-protected PDFs are rejected. V0.9 does not unlock or annotate them.
- Reading uses PDFKit: continuous vertical scroll, auto-scale, text selection, and copy.
- Reading position is not saved; reopening starts at the first page.

### Panel Manager

`管理面板…` opens a regular macOS window (not a floating panel). It is not stored in `panels.json`. Browse panels, filter by type, search titles, bring a panel forward, or delete it with the same confirmation as the panel menu. Titles are derived from existing payload content; there is no separate rename field.

If all floating panels are hidden with Hide / Show, the manager stays visible. Revealing one panel from the manager shows only that panel and does not turn Show All back on.

### Shortcuts

Global shortcuts can be customized in Settings. Glance does not request Accessibility permission.

Click a shortcut, press the new combination, and it takes effect immediately. Escape cancels. Restore defaults returns to `⌥⌘J` / `⌥⌘B` / `⌥⌘G`. Combinations must include at least two of Command, Option, and Control. Glance will not assign the same combination to two commands.

### Layout

Drag a panel near a screen edge and release to snap it into place. Size stays the same; only position changes. Corners snap when the panel is close to two edges at once. Hold Control while releasing to bypass snapping for that drag.

Right-click a panel:

```text
布局
→ 左上角 / 右上角 / 左下角 / 右下角 / 居中
```

Presets use the current display’s visible frame (avoiding the Dock and menu bar). Locked panels cannot be moved, so the layout menu is disabled.

### Panel control

Each panel can be pinned, locked, made click-through, and faded independently. Those flags are stored on the panel record and restored after relaunch.

- **Markdown** shows a rendered preview. Double-click to edit the raw Markdown source. Payload is UTF-8 `content.md`.
- **Todo** is a lightweight on-screen checklist: add, inline edit, complete, and delete. Payload is UTF-8 `todo.json`. There is no reorder, due date, reminder, or priority system.
- **PDF** is a local copy of the imported document. Payload is `document.pdf` plus `pdf.json` (filename and page count). There is no annotation, OCR, or full-text search.
- **Lock** prevents accidental drag, resize, text editing, checklist toggles, Markdown source edits, Todo mutations, and image replace. PDF reading (scroll, select, copy) still works. Right-click, unlock, opacity, pin, click-through, delete, and panel settings still work.
- **Click-through** ignores mouse events until you hold Option. Lock still wins: Option can open the menu and settings, but cannot move, resize, or edit a locked panel.
- **Opacity** ranges from 30% to 100% (`window.alphaValue`). The slider in panel settings updates live and persists after you release.

### App settings

Glance settings include launch at login (`SMAppService.mainApp`), customizable global shortcuts (defaults `⌥⌘J`, `⌥⌘B`, and `⌥⌘G`), the local data folder, and the version from the app bundle.

## Download

Prebuilt releases are planned. Until then, build from source.

## Build from source

Requires **macOS 14+** and either **Xcode** or the **Xcode Command Line Tools**.

```bash
git clone https://github.com/Eric-Ruan-jingwei/Glance.git
cd Glance
./scripts/package-macos.sh
open dist/Glance.app
```

Glance is an agent (`LSUIElement`): look for the pin icon in the menu bar, not in the Dock.

Optional:

```bash
./scripts/build-macos.sh
./scripts/test-macos.sh
open Glance.xcodeproj
```

## Data

Everything lives on disk. See [docs/architecture/data-format.md](docs/architecture/data-format.md) for the portable contract.

```text
~/Library/Application Support/Glance/
├── Database/
│   ├── panels.json          schemaVersion envelope
│   └── panels.backup.json
└── Panels/
    └── {panel-id}/
        ├── content.rtf
        ├── content.md
        ├── todo.json
        ├── image.png
        ├── document.pdf
        └── pdf.json
```

Images and PDFs are copied into this directory. Deleting the original file does not blank the panel.

There is no save button. Moves, resizes, and text edits are debounced and flushed on quit.

## Architecture

macOS UI is AppKit (`NSPanel`) plus SwiftUI settings. Product models and JSON persistence are shared Core types; AppKit adapters convert `PanelFrame` to `NSRect`. See [docs/architecture/core-platform-boundary.md](docs/architecture/core-platform-boundary.md).

## License

MIT
