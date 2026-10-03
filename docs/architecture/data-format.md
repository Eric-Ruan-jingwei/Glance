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
        ├── image.png
        ├── document.pdf
        └── pdf.json
```

`{panel-id}` is the panel UUID string.

Tests may override the root with `GLANCE_DATA_ROOT`. Production user data is never used as that override.

## Metadata: JSON

`Database/panels.json` is UTF-8 JSON.

- Current envelope: `{ "schemaVersion": 5, "workspaces": [ ... ], "panels": [ ... ] }`
- Schema 4 envelopes are accepted and migrated in one hop to schema 5: missing `tags` becomes `[]`. Other panel fields including `customTitle`, workspace records, and timestamps are unchanged. The repository rewrites recovered/migrated metadata as schema 5
- Schema 3 envelopes are accepted and migrated in one hop to schema 5: missing `customTitle` becomes `nil`, missing `tags` becomes `[]`. Other panel fields, workspace records, and timestamps are unchanged
- Schema 2 envelopes are accepted and migrated in memory: a Default workspace (`id: "default"`, name `默认`) is created, every existing panel gets `workspaceID: "default"`, `customTitle` is `nil`, and `tags` is `[]`. Other panel fields and timestamps are unchanged
- Schema 1 envelopes are accepted and migrated in one hop to schema 5: missing `isHidden` becomes `false`, missing `workspaceID` becomes `"default"`, `customTitle` is `nil`, `tags` is `[]`
- V0.1 raw arrays of panel objects are still accepted and rewritten as schema 5
- Envelopes with `schemaVersion` greater than 5 are **rejected**. The file is left untouched; Glance does not quarantine it or write an empty schema 5 database over it

Each panel object stores geometry as **flat** numbers, not a nested `frame` object:

```text
x, y, width, height
```

These are portable numeric fields, but coordinates are platform/display-layout restoration hints, not a guarantee of pixel-identical placement across operating systems.

Other fields include `id`, `kindIdentifier`, `displayIdentifier`, `isPinned`, `isLocked`, `isCollapsed`, `isPassThrough`, `isHidden`, `workspaceID`, `customTitle`, `tags`, `opacity`, `themeIdentifier`, `payloadPath`, `payloadVersion`, `createdAt`, `updatedAt`.

`customTitle` is an optional display-name override stored on `PanelRecord`. It is **not** derived from payload content and does not rewrite Text, Markdown, Todo, Image, or PDF files. `nil` (omitted on encode) means the panel uses its automatic, payload-derived title. Blank or whitespace-only values are treated as `nil` on read. User writes reject titles longer than 80 characters; oversized values already on disk are kept so a hand-edited file cannot take the whole database down.

`tags` is a JSON string array on `PanelRecord`. It is lightweight, multi-value metadata for search and Manager filtering. It is **not** a second workspace: a panel still belongs to exactly one workspace, and tags never change `effectiveVisible`. Empty panels encode `"tags": []`. There is no separate tag registry, UUID, color, or `tags.json`. Read path trims, collapses newlines, drops blanks, and case-insensitive-dedupes while keeping first-seen casing and insertion order. User writes reject tags longer than 24 characters and more than 12 tags per panel; oversized values already on disk are kept.

`isHidden` is persistent per-panel visibility. `false` means the panel should be shown unless it belongs to an inactive workspace or Global Hide is active. Global Hide / Show is runtime-only and is **not** stored on `PanelRecord`.

`workspaceID` is required. Each panel belongs to exactly one workspace. The Default workspace uses the stable id `default`.

`workspaces` is an array of `{ id, name, createdAt, updatedAt }`. The Default workspace always exists, cannot be renamed or deleted, and is named `默认`. User workspaces use UUID ids.

The active workspace is **not** stored in `panels.json`. It is a device preference (`UserDefaults` key `com.glance.workspace.activeID`).

Example panel object:

```json
{
  "id": "0D74D7D4-33F4-4795-A657-D40F456187A7",
  "kindIdentifier": "com.glance.panel.text",
  "x": 1130,
  "y": 683,
  "width": 320,
  "height": 220,
  "displayIdentifier": "1",
  "isPinned": true,
  "isLocked": false,
  "isCollapsed": false,
  "isPassThrough": false,
  "isHidden": false,
  "workspaceID": "default",
  "customTitle": "论文",
  "tags": ["具身智能", "论文", "必读"],
  "opacity": 1,
  "themeIdentifier": "system",
  "payloadPath": "Panels/0D74D7D4-33F4-4795-A657-D40F456187A7",
  "payloadVersion": 1,
  "createdAt": "2026-10-02T15:32:51Z",
  "updatedAt": "2026-10-02T15:32:51Z"
}
```

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

## PDF payload

```text
kindIdentifier: com.glance.panel.pdf
payloadVersion: 1
Panels/{panel-id}/document.pdf
Panels/{panel-id}/pdf.json
```

`document.pdf` is a full copy of the imported file. `pdf.json` is payload-local metadata, not PanelRecord schema:

```json
{
  "version": 1,
  "displayName": "Physical AI Survey.pdf",
  "pageCount": 42
}
```

`displayName` is the chosen filename. `pageCount` is recorded at import so Panel Manager does not open every PDF. Missing or unreadable `pdf.json` does not rewrite the sidecar; a readable `document.pdf` can still be shown. Unreadable existing PDF files are left on disk and not overwritten. PDFs are imported only through the file picker, not Clipboard Capture.

## Kinds

Current `kindIdentifier` values:

```text
com.glance.panel.text
com.glance.panel.markdown
com.glance.panel.todo
com.glance.panel.image
com.glance.panel.pdf
```

Unknown kinds still restore as metadata so a newer client’s panels are not deleted by an older build.

## Quick Capture

Quick Capture is a transient input window. It is **not** stored in `panels.json`, has no `PanelRecord`, and has no payload directory. Closing it discards the draft.

A successful submit creates a normal Text or Todo panel using the existing payload files (`content.rtf` or `todo.json`). New panels always have `isHidden = false`, `customTitle = nil`, `tags = []`, and `workspaceID` equal to the current active workspace (or `default` if that id is missing). `schemaVersion` remains `5`.

## Panel Library

The Panel Manager / Library window is a derived view of existing metadata and payloads. It is **not** stored in `panels.json`. Summaries are rebuilt at runtime from an immutable `PanelSummaryInput` snapshot plus payload inspection. That snapshot is not Codable and is not written to disk. `schemaVersion` remains `5`.

Title model:

```text
Automatic title = derived from payload, not persisted
Custom title    = PanelRecord.customTitle metadata
Effective title = customTitle ?? automaticTitle
```

Search matches the effective title, automatic title, subtitle, preview, and tags. Tag filter is exact (case-insensitive) and applies only within the current workspace, together with type and search. Manager hide/show writes `PanelRecord.isHidden` and updates `updatedAt`. Rename writes `customTitle` only. Editing tags writes `tags` only. Global concealment is not reflected as `isHidden` on summaries. Inactive-workspace membership is not shown as `eye.slash`.

## Panel snap and layout

Edge snap and layout presets are interaction-only. They write the resulting `x` / `y` / `width` / `height` and do not add `isSnapped`, `layoutPreset`, or similar fields. `schemaVersion` remains `5`.

## Clipboard Capture

Clipboard Capture is a user-triggered one-shot read. It is **not** stored as clipboard history and does not add a `source` field. Capture priority is valid image → valid text → unsupported. A successful capture creates a normal Text (`content.rtf`) or Image (`image.png`) panel with `isHidden = false`, `customTitle = nil`, `tags = []`, and `workspaceID` equal to the current active workspace. `schemaVersion` remains `5`.

## Clipboard Shelf

Clipboard history is a separate data domain from panels.

```text
Clipboard/history.json
Clipboard/Assets/<uuid>.png
```

The envelope is `{ "schemaVersion": 1, "items": [ ... ] }`. This schema is independent of `PanelDatabase.currentSchemaVersion`, which remains **5**. Future clipboard schemas are rejected without rewriting the file. Recording is off by default (`com.glance.clipboardHistory.enabled`).

## File Shelf

File Shelf is a separate data domain. It stores references to user files, not copies.

```text
FileShelf/shelf.json
FileShelf/Bookmarks/<uuid>.bookmark
```

The envelope is `{ "schemaVersion": 1, "items": [ ... ] }`. This schema is independent of both Panel schema **5** and Clipboard schema **1**. Future File Shelf schemas are rejected without rewriting the file. Bookmark bytes stay in sidecar files, not in JSON. Removing a record deletes only the metadata and bookmark sidecar.

Each item stores `id`, `originalPath`, `displayName`, `fileSize`, `contentTypeIdentifier`, `createdAt`, `lastUsedAt`, `isFavorite`, and `favoritedAt`. It does not store bookmark data, custom titles, tags, or workspace membership.

## Snippets

Snippets are a separate data domain. They are explicitly created text assets, not clipboard history.

```text
Snippets/snippets.json
```

The envelope is `{ "schemaVersion": 1, "items": [ ... ] }`. This schema is independent of Panel schema **5**, Clipboard schema **1**, and File Shelf schema **1**. Future snippet schemas are rejected without rewriting the file. Body text is stored exactly in JSON; Glance does not trim whitespace. There is no automatic eviction.

Each item stores `id`, `title`, `content`, `createdAt`, `updatedAt`, `lastUsedAt`, and `isPinned`.

## Links

Links are a separate data domain. They are explicitly saved HTTP/HTTPS resources, not browser history.

```text
Links/links.json
```

The envelope is `{ "schemaVersion": 1, "items": [ ... ] }`. This schema is independent of Panel schema **5**, Clipboard schema **1**, File Shelf schema **1**, and Snippets schema **1**. Future link schemas are rejected without rewriting the file. Glance does not fetch webpage metadata, favicons, or HTML. There is no automatic eviction or URL dedupe.

Each item stores `id`, `title`, `urlString`, `createdAt`, `updatedAt`, `lastOpenedAt`, and `isPinned`.

## Global Search

Global Search is a runtime recall layer, not a data domain. It reads the five existing sources in memory and does not write:

```text
Search/
```

There is no search envelope, no FTS database, and no schema version. Closing the search window discards the in-memory documents. The next open rebuilds them from Clipboard, File Shelf, Snippets, Links, and Panel summaries.

## Future clients

Any future Windows (or other) client should read and write this JSON + RTF + Markdown + Todo JSON + PNG + PDF layout. Windowing, shortcuts, and tray code are platform-specific; the files are not.
