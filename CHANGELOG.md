# Changelog

Glance 的产品版本独立于数据库 schema。当前应用版本是 **0.27.0**（Build 51）；schema 仍为 Panel 5、Clipboard / File Shelf / Snippet / Link 1。

GitHub 上的 Beta 身份由 tag 表示，例如 `v0.27.0-beta.2`。应用包内的 `CFBundleShortVersionString` 仍是 `0.27.0`。

## 0.27.0 Beta 2

- 修复空待办面板点击「添加待办」后无法开始第一项的问题
- 修复非激活悬浮面板进入 Todo 编辑状态时的焦点与 First Responder 竞态
- 提升面板内真实控件相对于拖动 / Resize 区域的点击优先级

## 0.27.0

Release candidate. Cross-tool workflow integration (Quick Capture, Global Search actions, Drag & Drop, Menu Bar Home), UX polish, and RC hardening. App version is 0.27.0; database schemas are unchanged (Panel 5, Clipboard / File Shelf / Snippet / Link 1).

## 0.25.0

Real-use polish and pre-release hardening. No seventh top-level tool, no schema changes, and no Release Engineering.

Corrupt metadata that cannot be quarantined stays on disk and the affected domain becomes read-only. Off-screen panels are recovered only when they are no longer operable. Utility-window shortcuts bring an already-visible window forward instead of closing it, and Panel Manager scrolls the revealed search target into view.

## 0.24.0

Workflow integration and product hardening. No seventh top-level tool, no schema changes, and no Search database.

Snippet, Link, and Image/PDF File Shelf items can create Panels through the application coordinator. Global Search `⌘Enter` reveals a result in its source library. Utility windows share present/dismiss handoff, clipboard writes go through one helper that suppresses self-ingest, and default shortcut uniqueness is covered in CI.

## 0.23.1

0.23.1 preserves existing custom shortcuts when new actions introduce conflicting defaults. The status menu and Guide display only active registered global shortcuts. Inactive shortcut conflicts are surfaced in Settings.

## 0.23.0

Global Search: one in-memory recall layer across Clipboard, File Shelf, Snippets, Links, and every workspace’s panels. Empty query shows recent activity. Enter runs the natural action for that source. Panel summaries load asynchronously and only once per search session. Global Search has no persisted schema and does not add a Search directory. Panel, Clipboard, File Shelf, Snippets, and Links schemas are unchanged.

## 0.22.0

Links: save, name, search, pin, and open HTTP/HTTPS pages in the default browser. Drag a URL from a browser into the library, or save a clipboard URL through the editor. Glance does not fetch webpage metadata or favicons. Panel, Clipboard, File Shelf, and Snippets schemas are unchanged.

## 0.21.0

Snippets: save, edit, search, pin, and copy reusable plain text. Clipboard text can be saved as a snippet through the editor. Snippet copy writes the system clipboard without creating a new clipboard-history record. Panel, Clipboard, and File Shelf schemas are unchanged.

## 0.20.0

File Shelf: drag files in, search recent and favorite references, open, reveal in Finder, Quick Look, copy, and drag out. Glance stores bookmarks, not copies of the files. Panel and Clipboard schemas are unchanged.

## 0.19.1

The status menu now reads as a utility hub: Quick Capture, Clipboard, and Panels sit side by side. Clipboard history also picks a usable image representation instead of skipping a paste just because another representation is too large.

## 0.19.0

Clipboard Shelf: recent history, favorites, search, reuse, and create a panel from a saved item. Recording stays local and is off until you turn it on. Panel schema is unchanged.

## 0.18.10

Text checklist strikethroughs sit on the visual center of the letters.

## 0.18.9

Text checklist circles match the body type size.

## 0.18.8

Text checklist marks are circles. Completing an item grays the circle and draws a thicker strikethrough.

## 0.18.7

Text checklist marks are larger, and clicking them strikes through the line instead of inserting a check.

## 0.18.6

Clicking anywhere in a Text or Markdown body enters edit mode. Drag the panel from the title bar.

## 0.18.5

Clicking Text or Markdown content enters edit mode. Todo items still use a double-click.

## 0.18.4

Text checklist marks toggle on click while editing, and the hit target follows the text layout.

## 0.18.3

Quick Capture placeholder now lines up with the insertion caret.

## 0.18.2

Quick Capture Return submits even when the Guide window is open.

## 0.18.1

Expanded in-app shortcut and interaction reference.

## 0.18.0

First-run onboarding and an in-app usage guide. No schema or feature change beyond help.

- First-run onboarding
- In-app usage guide
- Central shortcut and interaction reference

## 0.17.2

Final UI and interaction polish before 1.0 release engineering. No schema or feature change.

- Tighter Text reading layout
- Automatic titles in floating panel chrome
- Quieter status menu and shared interaction details

## 0.17.1

Content and interaction polish on the P0 visual shell. No schema or feature change.

- Text and Markdown reading typography
- Quieter Todo, Image, and PDF content
- Hover actions without layout jump
- Batch toolbar and empty states

## 0.17

Visual foundation for floating panels, the status menu, and Panel Manager. No schema or feature change.

- Shared spacing, radius, and tag chrome
- Floating panel cards with a thinner hover chrome
- Native status-menu sections and symbols
- Panel Manager shell closer to Finder / Notes

## 0.16.1

Improved VoiceOver actions for removable and suggested tags.

## 0.16

Product hardening for the existing 1.0 feature set. No new panel types, no schema change.

- Improved Panel Manager responsiveness
- Safer large PDF imports
- Improved data recovery diagnostics
- Accessibility improvements
