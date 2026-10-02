# Glance

**Pin what matters. Keep it in sight.**

A lightweight, local-first floating panel app for macOS.

Glance is not another notes app. It is an always-on-top information layer: put the text or reference images you need to keep seeing on independent panels, pin them anywhere on screen, and they stay there while you work in the browser, editor, or chat.

## Highlights

- Native macOS
- Always on top
- Local-first
- Text and images
- No account
- No cloud
- Open source

## V0.2 已支持

- Text panel
- Image panel
- Always on top
- Lock
- Click-through
- Option temporary interaction
- Opacity
- Global hide/show shortcut
- Launch at login
- Local persistence
- Multi-display recovery

The core loop is still: create a panel → put content in it → drag it where you want → it stays floating → quit and reopen, everything is still there.

Status-item menu:

```text
新建文字面板
新建图片面板
────────────
显示全部 / 隐藏全部    ⌥⌘G
────────────
设置…
退出
```

The Dock icon is hidden. There is no traditional main window.

### Panel control

Each panel can be pinned, locked, made click-through, and faded independently. Those flags are stored on the panel record and restored after relaunch.

- **Lock** prevents accidental drag, resize, text editing, checklist toggles, and image replace. Right-click, unlock, opacity, pin, click-through, delete, and panel settings still work.
- **Click-through** ignores mouse events until you hold Option. Lock still wins: Option can open the menu and settings, but cannot move, resize, or edit a locked panel.
- **Opacity** ranges from 30% to 100% (`window.alphaValue`). The slider in panel settings updates live and persists after you release.

### App settings

Glance settings include launch at login (`SMAppService.mainApp`), the ⌥⌘G shortcut (not customizable in V0.2), the local data folder, and the version from the app bundle.

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

Windows are AppKit `NSPanel`s. SwiftUI is used for app settings and the small panel settings window. Panel metadata is stored as JSON so the project builds with either Xcode or Command Line Tools; payload files stay in Application Support.

## License

MIT
