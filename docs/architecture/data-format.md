# Data format

This is the portable on-disk contract. It does not use Apple-only binary serialization (no SwiftData, no keyed archives, no Core Data).

Default application data root (macOS):

```text
~/Library/Application Support/Glance/
```

Layout:

```text
Application data root
├── Database/
│   ├── panels.json
│   └── panels.backup.json
└── Panels/
    └── {panel-id}/
        ├── content.rtf
        ├── content.md
        ├── todo.json
        └── image.png
```

`{panel-id}` is the panel UUID string.

Tests may override the root with `GLANCE_DATA_ROOT`. Production user data is never used as that override.

## Metadata: JSON

`Database/panels.json` is UTF-8 JSON.

- Current envelope: `{ "schemaVersion": 1, "panels": [ ... ] }`
- V0.1 raw arrays of panel objects are still accepted and rewritten as schema 1
- Envelopes with `schemaVersion` greater than 1 are **rejected**. The file is left untouched; Glance does not quarantine it or write an empty schema 1 database over it

Each panel object stores geometry as **flat** numbers, not a nested `frame` object:

```text
x, y, width, height
```

These are portable numeric fields, but coordinates are platform/display-layout restoration hints, not a guarantee of pixel-identical placement across operating systems.

Other fields include `id`, `kindIdentifier`, `displayIdentifier`, `isPinned`, `isLocked`, `isCollapsed`, `isPassThrough`, `opacity`, `themeIdentifier`, `payloadPath`, `payloadVersion`, `createdAt`, `updatedAt`.

`displayIdentifier` is an opaque, platform-local display hint. It is not guaranteed to match across operating systems. If a future client cannot recognize it, fall back to the main or current display and recover/clamp geometry.

Dates are ISO-8601. `payloadPath` is relative to the application data root, typically `Panels/{uuid}`.

`panels.backup.json` stores a secondary copy of the latest successfully encoded metadata.

## Text payload: RTF

```text
Panels/{panel-id}/content.rtf
```

Rich text for text panels. Missing file means an empty new panel. An existing unreadable file is left on disk and not overwritten.

## Markdown payload: UTF-8

```text
kindIdentifier: com.glance.panel.markdown
payloadVersion: 1
Panels/{panel-id}/content.md
```

Plain UTF-8 Markdown source. Missing file means an empty new panel. An existing file that cannot be decoded as UTF-8 is left on disk and not overwritten.

## Todo payload: UTF-8 JSON

```text
kindIdentifier: com.glance.panel.todo
payloadVersion: 1
Panels/{panel-id}/todo.json
```

UTF-8 JSON with a payload-local `version` field (currently `1`) and an `items` array. Each item has `id`, `text`, `isCompleted`, and `createdAt` (ISO-8601). Missing file means an empty checklist. An existing file that cannot be parsed, or whose `version` is unsupported, is left on disk and not overwritten.

## Image payload: PNG

```text
Panels/{panel-id}/image.png
```

Copied into the panel directory. Deleting the original source file does not blank the panel. Unreadable existing files are not overwritten.

## Kinds

Current `kindIdentifier` values:

```text
com.glance.panel.text
com.glance.panel.markdown
com.glance.panel.todo
com.glance.panel.image
```

Unknown kinds still restore as metadata so a newer client’s panels are not deleted by an older build.

## Quick Capture

Quick Capture is a transient input window. It is **not** stored in `panels.json`, has no `PanelRecord`, and has no payload directory. Closing it discards the draft.

A successful submit creates a normal Text or Todo panel using the existing payload files (`content.rtf` or `todo.json`). `schemaVersion` remains `1`.

## Future clients

Any future Windows (or other) client should read and write this JSON + RTF + Markdown + Todo JSON + PNG layout. Windowing, shortcuts, and tray code are platform-specific; the files are not.
