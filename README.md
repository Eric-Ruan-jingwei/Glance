# Glance

**Pin what matters. Keep it in sight.**

Glance is a lightweight, local-first personal workspace for **macOS**.

Capture with Quick Capture. Hold temporary work on the Clipboard and File Shelf. Keep reusable text and pages in Snippets and Links. Pin what you still need to see as Panels. Recall any of it with Global Search. Links are explicitly saved web resources. Glance does not fetch webpage metadata or favicons. Global Search searches existing local Glance data in memory and does not maintain a separate persistent search index. Clipboard History is not Snippets, and Snippets are not Links. Everything stays on this machine.

There is no Windows client yet. Shared data contracts are documented so a future Windows app can reuse them.

## Product model

- **Capture** — Quick Capture
- **Recall** — Global Search
- **Workspace tools** — Clipboard, File Shelf, Snippets, Links, Panels

Cross-module flow stays explicit and local:

- Clipboard → Snippet
- Clipboard → Link
- Clipboard → Panel
- Snippet → Panel
- Link → Panel
- Image / PDF File Shelf → Panel
- Global Search → Reveal in Source (`⌘Enter`)

Source records are not deleted or rewritten when you create a derived Panel. File Shelf items stay bookmarks; Panels store their own copy of imported images and PDFs.

## Highlights

- Native macOS
- Always on top
- Local-first
- Text, Markdown, Todo, images, and PDF
- Quick Capture from any app
- Global Search
- Clipboard Shelf
- File Shelf
- Snippets
- Links
- Clipboard Capture
- Customizable global shortcuts
- First-run onboarding
- In-app usage guide
- Central shortcut and interaction reference
- Per-panel hide/show
- Workspaces
- Panel Manager
- Multi-select in Panel Manager
- Batch visibility
- Batch workspace move
- Batch tag editing
- Custom panel titles
- Panel Tags
- Cross-module Create Panel
- Global Search Reveal in Source
- No account
- No cloud
- Open source

## V0.27.0

Release candidate. Cross-tool workflow integration (Quick Capture, Global Search actions, Drag & Drop, Menu Bar Home), UX polish, and RC hardening. App version is 0.27.0; database schemas are unchanged (Panel 5, Clipboard / File Shelf / Snippet / Link 1).

## V0.25.0

Real-use polish and pre-release hardening. No seventh top-level tool, no schema changes, and no Release Engineering.

Corrupt metadata that cannot be quarantined stays on disk and the affected domain becomes read-only. Off-screen panels are recovered only when they are no longer operable. Utility-window shortcuts bring an already-visible window forward instead of closing it, and Panel Manager scrolls the revealed search target into view.

## V0.24.0

Workflow integration and product hardening. No seventh top-level tool, no schema changes, and no Search database.

Snippet, Link, and Image/PDF File Shelf items can create Panels through the application coordinator. Global Search `⌘Enter` reveals a result in its source library. Utility windows share present/dismiss handoff, clipboard writes go through one helper that suppresses self-ingest, and default shortcut uniqueness is covered in CI.

## V0.23.1

0.23.1 preserves existing custom shortcuts when new actions introduce conflicting defaults. The status menu and Guide display only active registered global shortcuts. Inactive shortcut conflicts are surfaced in Settings.

## V0.23.0

Global Search: one in-memory recall layer across Clipboard, File Shelf, Snippets, Links, and every workspace’s panels. Empty query shows recent activity. Enter runs the natural action for that source. Panel summaries load asynchronously and only once per search session. Global Search has no persisted schema and does not add a Search directory. Panel, Clipboard, File Shelf, Snippets, and Links schemas are unchanged.

## V0.22.0

Links: save, name, search, pin, and open HTTP/HTTPS pages in the default browser. Drag a URL from a browser into the library, or save a clipboard URL through the editor. Glance does not fetch webpage metadata or favicons. Panel, Clipboard, File Shelf, and Snippets schemas are unchanged.

## V0.21.0

Snippets: save, edit, search, pin, and copy reusable plain text. Clipboard text can be saved as a snippet through the editor. Snippet copy writes the system clipboard without creating a new clipboard-history record. Panel, Clipboard, and File Shelf schemas are unchanged.

## V0.20.0

File Shelf: drag files in, search recent and favorite references, open, reveal in Finder, Quick Look, copy, and drag out. Glance stores bookmarks, not copies of the files. Panel and Clipboard schemas are unchanged.

## V0.19.1

The status menu now reads as a utility hub: Quick Capture, Clipboard, and Panels sit side by side. Clipboard history also picks a usable image representation instead of skipping a paste just because another representation is too large.

## V0.19.0

Clipboard Shelf: recent history, favorites, search, reuse, and create a panel from a saved item. Recording stays local and is off until you turn it on. Panel schema is unchanged.

## V0.18.10

Text checklist strikethroughs sit on the visual center of the letters.

## V0.18.9

Text checklist circles match the body type size.

## V0.18.8

Text checklist marks are circles. Completing an item grays the circle and draws a thicker strikethrough.

## V0.18.7

Text checklist marks are larger, and clicking them strikes through the line instead of inserting a check.

## V0.18.6

Clicking anywhere in a Text or Markdown body enters edit mode. Drag the panel from the title bar.

## V0.18.5

Clicking Text or Markdown content enters edit mode. Todo items still use a double-click.

## V0.18.4

Text checklist marks toggle on click while editing, and the hit target follows the text layout.

## V0.18.3

Quick Capture placeholder now lines up with the insertion caret.

## V0.18.2

Quick Capture Return submits even when the Guide window is open.

## V0.18.1

Expanded in-app shortcut and interaction reference.

## V0.18.0

First-run onboarding and an in-app usage guide. No schema or feature change beyond help.

- First-run onboarding
- In-app usage guide
- Central shortcut and interaction reference

## V0.17.2

Final UI and interaction polish before 1.0 release engineering. No schema or feature change.

- Tighter Text reading layout
- Automatic titles in floating panel chrome
- Quieter status menu and shared interaction details

## V0.17.1

Content and interaction polish on the P0 visual shell. No schema or feature change.

- Text and Markdown reading typography
- Quieter Todo, Image, and PDF content
- Hover actions without layout jump
- Batch toolbar and empty states

## V0.17

Visual foundation for floating panels, the status menu, and Panel Manager. No schema or feature change.

- Shared spacing, radius, and tag chrome
- Floating panel cards with a thinner hover chrome
- Native status-menu sections and symbols
- Panel Manager shell closer to Finder / Notes

## V0.16.1

Improved VoiceOver actions for removable and suggested tags.

## V0.16

Product hardening for the existing 1.0 feature set. No new panel types, no schema change.

- Improved Panel Manager responsiveness
- Safer large PDF imports
- Improved data recovery diagnostics
- Accessibility improvements

## 已支持

- Text panel
- Markdown panel (rendered preview, click to edit raw UTF-8 `.md`)
- Todo panel (interactive checklist with inline add/edit/complete/delete)
- Image panel
- PDF panel
- Quick Capture — capture text, a URL, or a file and choose whether it becomes a Snippet, Link, File Shelf item, or Panel. Default: `⌥⌘J`
- Global Search — recall Clipboard, File Shelf, Snippets, Links, and all-workspace Panels from one in-memory search. Default: `⌥⌘K`. No persistent search index.
- Clipboard Capture — create a Text or Image panel from the current clipboard. Default: `⌥⌘B`
- Panel Manager — browse, search, reveal, hide, delete, and move existing panels; the sidebar switches the active workspace. Multi-select a filtered result set and apply atomic batch hide/show, workspace move, and tag add/remove.
- Workspaces — organize panels by workspace and switch the visible set of panels without changing their content or per-panel hidden state
- Custom panel titles — give long-lived panels a stable custom name without modifying their underlying content. Clearing a custom title restores the automatic content-derived title
- Panel Tags — add multiple lightweight tags to panels for search and filtering without affecting workspace membership or visibility. The tag editor commits pending input when Save is pressed.
- Per-panel hide/show — hide a panel without deleting it; the state survives relaunch
- Panel edge snapping
- Panel layout presets
- Always on top
- Lock
- Click-through
- Option temporary interaction
- Opacity
- Global hide/show. Default: `⌥⌘G`. Temporary: it does not overwrite per-panel hidden state. Show All restores panels that are not individually hidden.
- Customizable global shortcuts
- Launch at login
- Local persistence
- Multi-display recovery

The core loop is still: create a panel → put content in it → drag it where you want → it stays floating → quit and reopen, everything is still there.

Quick Capture is a unified capture entry: classify the content, let the user pick the destination, then close. It still skips inventing a seventh top-level tool.

Clipboard Capture still creates a panel from whatever is on the system clipboard right now.

Clipboard Shelf is separate: after you turn on local recording, Glance keeps recent text and images, lets you favorite them, and writes a chosen item back to the system clipboard. It does not auto-paste.

File Shelf is the file counterpart. Drag a file in, or add it with `+`. Glance stores a reference and a macOS bookmark, not a copy. You can search recent and favorite files, open them, reveal them in Finder, Quick Look them, copy them, or drag them back out. Removing a shelf item does not delete the original file.

Snippets are long-lived text you save on purpose: an address, a reply, a prompt, a command. They are editable and never auto-deleted. Enter copies the exact text to the system clipboard; you paste it yourself. Clipboard History still means “what I recently copied.”

Links are long-lived web resources you save on purpose: a GitHub repo, a Figma file, a dashboard, a docs page. Enter opens the URL in the default browser. Glance does not fetch titles, favicons, or page previews.

Global Search is the recall layer over those five stores. `⌥⌘K` searches them together in memory. It does not search the rest of the Mac, the browser, or the web, and it does not keep a search database.

Default shortcuts:

```text
Quick Capture                 ⌥⌘J
Global Search                 ⌥⌘K
Clipboard                     ⌥⌘V
File Shelf                    ⌥⌘F
Snippets                      ⌥⌘S
Links                         ⌥⌘L
Create from current clipboard ⌥⌘B
Hide / Show                   ⌥⌘G
```

These can be changed in Settings.

Status-item menu (defaults shown):

```text
快速记录…                  ⌥⌘J
搜索 Glance…               ⌥⌘K
────────────
剪贴板…                    ⌥⌘V
文件架…                    ⌥⌘F
片段库…                    ⌥⌘S
链接库…                    ⌥⌘L
面板
  新建面板
    文字
    Markdown
    待办
    图片
    PDF…
  从当前剪贴板创建…        ⌥⌘B
  管理面板…
  工作区
    默认 ✓
    …
    ────────
    新建工作区…
  ────────
  隐藏全部 / 显示全部      ⌥⌘G
────────────
⚠ 数据恢复提示…      (only after backup recovery, corrupt metadata, or unsupported schema)
────────────
使用指南…
设置…
退出
```

The Dock icon is hidden. There is no traditional main window. The data-recovery item is omitted on a normal launch.

### Quick Capture

The default shortcut `⌥⌘J` opens a transient capture window on the display under the pointer. It is not a panel: it is not stored in `panels.json`, has no payload directory, and is discarded on close.

- Opening with an empty draft can prefill the current pasteboard (text, http(s) URL, or file URLs) without saving it.
- Glance classifies **Text**, **Link** (`http`/`https` only), or **Files**. `example.com` stays Text.
- Default actions: Text → Save as Snippet; Link → Save to Links; File → Add to File Shelf. Text also offers Create Text Panel and Create Todo Panel. A single image or PDF can Create Panel. Multiple files only go to File Shelf. Actions are never auto-executed.
- `↑` / `↓` move the current action. `Enter` or `⌘Enter` runs it. `Shift+Enter` inserts a newline while typing text, except when Create Todo Panel is selected — Todo stays single-line, so `Shift+Enter` submits.
- Empty or whitespace-only input does not save. A failed save keeps the draft and shows a short error.
- File Shelf capture bookmarks the original file; Glance does not move or delete it.
- `Escape` or a click outside capture closes it and drops the draft.
- If Glance is globally hidden (Hide / Show, default `⌥⌘G`), capture still appears. A submitted panel is created with `isHidden = false` but stays concealed until you show all panels again.

### Global Search

The default shortcut `⌥⌘K` opens a unified search window over Glance’s own local data. It does not own records, does not write a search index, and does not search Settings, Guide, the rest of the disk, the browser, or the network.

- Empty query shows the 20 most recently used items across Clipboard, File Shelf, Snippets, Links, and all workspaces’ panels, ordered by activity time. Pins and favorites do not boost Global Search.
- A non-empty query matches case-insensitively and diacritic-insensitively as a substring, ranked by title exact / prefix / substring then secondary fields, and returns at most 50 results.
- Enter restores clipboard content, opens a File Shelf file, copies a snippet, opens a link, or reveals a panel (switching workspace if needed). It does not open the source’s manager window.
- Missing files, invalid links, and Global Hide stay in the search window with a notice. Revealing a panel does not silently turn Global Hide off.
- Panel summaries load in the background using the existing Panel Manager loader. Query changes filter memory only.

## Privacy

Glance stays on this Mac.

Global Search:

- does not upload queries
- does not fetch web content
- does not scan arbitrary user files
- does not search File Shelf file contents
- does not OCR clipboard images

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

`管理面板…` opens a regular macOS window (not a floating panel). It is not stored in `panels.json`. The left sidebar lists workspaces; choosing one switches the active workspace and lists only that workspace’s panels. Browse panels, filter by type or tag, search titles and tags, hide or show a panel, rename it, edit its tags, move it to another workspace, bring a visible panel forward, or delete it with the same confirmation as the panel menu. Each panel has an automatic title derived from its payload. A custom title is optional metadata; it does not change the underlying Text, Markdown, Todo, Image, or PDF content. Search matches the custom name, the automatic title, and tags. Tags are not workspaces: they never hide or show panels.

An empty workspace is valid: the desktop shows no Glance panels, and the manager says **这个工作区还没有面板**.

### Workspaces

Each panel belongs to exactly one workspace. Switching workspaces changes which panels are on the desktop without rewriting their frames, payloads, or per-panel hidden flags.

- **默认** always exists, cannot be renamed or deleted, and uses the stable id `default`.
- Create a workspace from the status menu or the manager sidebar. Duplicate names are rejected.
- Deleting a user workspace moves its panels into **默认**; the panels themselves are not deleted.
- The active workspace is a device preference (`UserDefaults`), not part of `panels.json`.
- New panels (Text, Markdown, Todo, Image, PDF, Quick Capture, Clipboard Capture) join the current workspace.
- Effective visibility is: same workspace **and** not individually hidden **and** not globally concealed. Workspace switch does not cancel Global Hide.

### Panel visibility

Panels can be individually hidden without deleting them. Hidden panels stay in the manager (`eye.slash`) and come back with **显示**. Hide / Show (global) is temporary and does not overwrite per-panel hidden state. Show All restores panels that are in the active workspace and were not individually hidden; it does not cancel an individual hide. Switching workspace does not clear Global Hide. The manager stays visible during Global Hide. Showing a panel from the manager while Global Hide is active only clears that panel’s hidden flag; the window stays concealed until Show All.

Right-click a panel:

```text
重命名…
编辑标签…
移动到工作区
→ 默认 / …
隐藏此面板
```

Moving a panel out of the active workspace hides it immediately. Its `isHidden` flag is unchanged. Rename and tag edits are metadata only: locked panels can still be renamed or tagged, and Global Hide is not cleared.

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

- **Markdown** shows a rendered preview. Click to edit the raw Markdown source. Payload is UTF-8 `content.md`.
- **Todo** is a lightweight on-screen checklist: add, inline edit, complete, and delete. Payload is UTF-8 `todo.json`. There is no reorder, due date, reminder, or priority system.
- **PDF** is a local copy of the imported document. Payload is `document.pdf` plus `pdf.json` (filename and page count). There is no annotation, OCR, or full-text search.
- **Lock** prevents accidental drag, resize, text editing, checklist toggles, Markdown source edits, Todo mutations, and image replace. PDF reading (scroll, select, copy) still works. Right-click, unlock, opacity, pin, click-through, hide, rename, edit tags, delete, and panel settings still work.
- **Click-through** ignores mouse events until you hold Option. Lock still wins: Option can open the menu and settings, but cannot move, resize, or edit a locked panel.
- **Opacity** ranges from 30% to 100% (`window.alphaValue`). The slider in panel settings updates live and persists after you release.

### App settings

Glance settings include launch at login (`SMAppService.mainApp`), customizable global shortcuts (defaults `⌥⌘J`, `⌥⌘V`, `⌥⌘F`, `⌥⌘S`, `⌥⌘L`, `⌥⌘B`, and `⌥⌘G`), clipboard history recording, the local data folder, and the version from the app bundle.

## Install

### Download

Download Glance 0.27.0 Beta 1 from [GitHub Releases](https://github.com/Eric-Ruan-jingwei/Glance/releases/tag/v0.27.0-beta.1).

1. Open `Glance-0.27.0.dmg`
2. Drag Glance to Applications
3. Launch Glance from Applications

Glance is a menu bar app (`LSUIElement`): look for the pin icon in the menu bar, not in the Dock.

Requires **macOS 14 Sonoma or later**. The beta is **Universal 2** (Apple Silicon and Intel).

### Homebrew

```bash
brew install --cask Eric-Ruan-jingwei/glance/glance
```

```bash
brew uninstall --cask Eric-Ruan-jingwei/glance/glance
```

Uninstalling the app does not remove Glance user data (`~/Library/Application Support/Glance`).

Secondary, if you prefer to tap first:

```bash
brew tap Eric-Ruan-jingwei/glance
brew trust --cask Eric-Ruan-jingwei/glance/glance
brew install --cask glance
```

Prefer the fully-qualified install so Homebrew trusts only the Glance cask, not the whole tap.

### Beta notice

This build is ad-hoc signed and is not Apple notarized. Homebrew does not bypass Gatekeeper. On some macOS versions, the first launch may show a developer verification prompt. Use **System Settings → Privacy & Security → Open Anyway**.

Do not disable Gatekeeper or run `xattr` / `spctl --master-disable` workarounds.

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
│   ├── panels.json          schemaVersion 5 envelope (workspaces + panels)
│   └── panels.backup.json
├── Panels/
│   └── {panel-id}/
│       ├── content.rtf
│       ├── content.md
│       ├── todo.json
│       ├── image.png
│       ├── document.pdf
│       └── pdf.json
├── Clipboard/
│   ├── history.json         schemaVersion 1 clipboard shelf
│   └── Assets/
│       └── {item-id}.png
├── FileShelf/
│   ├── shelf.json           schemaVersion 1 file references
│   └── Bookmarks/
│       └── {item-id}.bookmark
├── Snippets/
│   └── snippets.json        schemaVersion 1 reusable text
└── Links/
    └── links.json           schemaVersion 1 saved web links
```

Global Search has no persisted user-data schema. There is no `Search/` directory, SQLite FTS index, or Spotlight copy.

Panel images and PDFs are copied into this directory. File Shelf stores only references and bookmarks; the original files stay where they are. Removing a File Shelf item does not delete the original file.

There is no save button. Moves, resizes, and text edits are debounced and flushed on quit.

## Architecture

macOS UI is AppKit (`NSPanel`) plus SwiftUI settings. Product models and JSON persistence are shared Core types; AppKit adapters convert `PanelFrame` to `NSRect`. See [docs/architecture/core-platform-boundary.md](docs/architecture/core-platform-boundary.md).

## License

MIT
