# Glance

**Pin what matters. Keep it in sight.**

A lightweight, local-first floating panel app for macOS.

Glance is not another notes app. It is an always-on-top information layer: put the text, todos, or reference images you need to keep seeing on independent panels, pin them anywhere on screen, and they stay there while you work in the browser, editor, or chat.

## Highlights

- Native macOS
- Always on top
- Local-first
- Text and images
- No account
- No cloud
- Open source

## V0.1

The first version only proves the core loop:

Create a panel → put content in it → drag it where you want → it stays floating → quit and reopen, everything is still there.

Status-item menu:

```text
新建文字面板
新建图片面板
────────────
显示全部 / 隐藏全部
────────────
设置…
退出
```

The Dock icon is hidden. There is no traditional main window.

## Requirements

- macOS 14 or later
- To build from source: Xcode 15+ **or** the Command Line Tools (`swift`)

## Build and run

```bash
cd Glance
chmod +x scripts/package-app.sh
./scripts/package-app.sh
open dist/Glance.app
```

If you have Xcode:

```bash
open Glance.xcodeproj
```

Then run the Glance scheme. The app is an agent (`LSUIElement`): look for the pin icon in the menu bar, not in the Dock.

```bash
swift test
```

or:

```bash
./scripts/run-tests.sh
```

## Data

Everything lives on disk:

```text
~/Library/Application Support/Glance/
├── Database/
│   ├── panels.json          schemaVersion envelope
│   └── panels.backup.json
└── Panels/
    └── {panel-id}/
        ├── content.rtf
        └── image.png
```

Images are copied into this directory. Deleting the original file does not blank the panel.

There is no save button. Moves, resizes, and text edits are debounced and flushed on quit.

## Architecture

Windows are AppKit `NSPanel`s. SwiftUI is used for settings. Panel metadata is stored as JSON so the project builds with either Xcode or Command Line Tools; payload files stay in Application Support so future panel types (code, PDF, markdown) do not explode the database schema.

## License

MIT
