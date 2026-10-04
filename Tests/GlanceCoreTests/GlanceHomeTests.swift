import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class GlanceHomeTests: XCTestCase {
    func testPreferredIncludesFavoritesAndPinsOnly() {
        let snapshot = GlanceHomeSnapshotBuilder.build(
            clipboards: [
                clipboard(id: uid(1), text: "keep", favorite: true, copied: 10, favorited: 10),
                clipboard(id: uid(2), text: "skip", favorite: false, copied: 20)
            ],
            files: [
                file(id: uid(3), name: "brief.pdf", favorite: true, used: 11, favorited: 11),
                file(id: uid(4), name: "notes.txt", favorite: false, used: 21)
            ],
            snippets: [
                snippet(id: uid(5), title: "pinned snippet", pinned: true, used: 12),
                snippet(id: uid(6), title: "loose snippet", pinned: false, used: 22)
            ],
            links: [
                link(id: uid(7), title: "pinned link", pinned: true, opened: 13),
                link(id: uid(8), title: "loose link", pinned: false, opened: 23)
            ],
            panels: [
                homePanel(id: uid(9), title: "window pinned panel", updated: 99)
            ]
        )
        XCTAssertEqual(
            snapshot.preferred.map(\.id),
            [
                GlobalSearchResultID(source: .links, itemID: uid(7)),
                GlobalSearchResultID(source: .snippets, itemID: uid(5)),
                GlobalSearchResultID(source: .fileShelf, itemID: uid(3)),
                GlobalSearchResultID(source: .clipboard, itemID: uid(1))
            ]
        )
        XCTAssertFalse(snapshot.preferred.contains { $0.source == .panels })
        XCTAssertEqual(snapshot.preferred.map(\.title), [
            "pinned link",
            "pinned snippet",
            "brief.pdf",
            "keep"
        ])
    }

    func testPreferredUsesActivityFallbackAndCapsAtEight() {
        var clipboards: [ClipboardHistoryRecord] = []
        var files: [FileShelfRecord] = []
        for index in 1...5 {
            clipboards.append(
                clipboard(
                    id: uid(index),
                    text: "clip \(index)",
                    favorite: true,
                    copied: TimeInterval(index),
                    favorited: TimeInterval(index)
                )
            )
            files.append(
                file(
                    id: uid(10 + index),
                    name: "file \(index).pdf",
                    favorite: true,
                    used: TimeInterval(index),
                    favorited: nil
                )
            )
        }
        let preferred = GlanceHomeProjection.preferred(
            clipboards: clipboards,
            files: files,
            snippets: [
                snippet(id: uid(30), title: "alpha", pinned: true, used: 4.5)
            ],
            links: [
                link(id: uid(40), title: "zeta", pinned: true, opened: 3.5)
            ]
        )
        XCTAssertEqual(preferred.count, GlanceHomePolicy.maximumPreferredItems)
        XCTAssertEqual(
            preferred.map(\.title),
            [
                "clip 5",
                "file 5.pdf",
                "alpha",
                "clip 4",
                "file 4.pdf",
                "zeta",
                "clip 3",
                "file 3.pdf"
            ]
        )
    }

    func testPreferredTieBreaksBySourceTitleAndUUID() {
        let items = GlanceHomeProjection.preferred(
            clipboards: [
                clipboard(id: uid(2), text: "same", favorite: true, copied: 10, favorited: 50),
                clipboard(id: uid(1), text: "same", favorite: true, copied: 10, favorited: 50)
            ],
            files: [
                file(id: uid(3), name: "same", favorite: true, used: 10, favorited: 50)
            ],
            snippets: [],
            links: []
        )
        XCTAssertEqual(
            items.map(\.id),
            [
                GlobalSearchResultID(source: .clipboard, itemID: uid(1)),
                GlobalSearchResultID(source: .clipboard, itemID: uid(2)),
                GlobalSearchResultID(source: .fileShelf, itemID: uid(3))
            ]
        )
    }

    func testRecentMapsActivityDatesAndIncludesPanels() {
        let snapshot = GlanceHomeSnapshotBuilder.build(
            clipboards: [
                clipboard(id: uid(1), text: "copied", copied: 40)
            ],
            files: [
                file(id: uid(2), name: "used.pdf", used: 30)
            ],
            snippets: [
                snippet(id: uid(3), title: "snippet", used: 20)
            ],
            links: [
                link(id: uid(4), title: "link", opened: 10)
            ],
            panels: [
                homePanel(id: uid(5), title: "named panel", updated: 50)
            ]
        )
        XCTAssertEqual(snapshot.recent.map(\.source), [
            .panels,
            .clipboard,
            .fileShelf,
            .snippets,
            .links
        ])
        XCTAssertEqual(snapshot.recent.map(\.title), [
            "named panel",
            "copied",
            "used.pdf",
            "snippet",
            "link"
        ])
        XCTAssertEqual(
            snapshot.recent.map { $0.activityAt.timeIntervalSince1970 },
            [50, 40, 30, 20, 10]
        )
        XCTAssertEqual(
            snapshot.recent.map(\.id),
            [
                GlobalSearchResultID(source: .panels, itemID: uid(5)),
                GlobalSearchResultID(source: .clipboard, itemID: uid(1)),
                GlobalSearchResultID(source: .fileShelf, itemID: uid(2)),
                GlobalSearchResultID(source: .snippets, itemID: uid(3)),
                GlobalSearchResultID(source: .links, itemID: uid(4))
            ]
        )
    }

    func testRecentPerSourceCapPreventsClipboardMonopoly() {
        var clipboards: [ClipboardHistoryRecord] = []
        for index in 1...10 {
            clipboards.append(
                clipboard(
                    id: uid(index),
                    text: "clip \(index)",
                    copied: TimeInterval(100 + index)
                )
            )
        }
        let recent = GlanceHomeProjection.recent(
            clipboards: clipboards,
            files: [file(id: uid(20), name: "only.pdf", used: 50)],
            snippets: [snippet(id: uid(21), title: "only snippet", used: 40)],
            links: [link(id: uid(22), title: "only link", opened: 30)],
            panels: []
        )
        XCTAssertEqual(recent.filter { $0.source == .clipboard }.count, 2)
        XCTAssertEqual(recent.map(\.source), [
            .clipboard,
            .clipboard,
            .fileShelf,
            .snippets,
            .links
        ])
        XCTAssertEqual(recent.map(\.title), [
            "clip 10",
            "clip 9",
            "only.pdf",
            "only snippet",
            "only link"
        ])
        XCTAssertNotEqual(recent.filter { $0.source == .clipboard }.count, recent.count)
    }

    func testRecentUsesKindFallbackTitleWithoutPanelPayload() {
        let untitled = GlanceHomePanelCandidate(record: panelRecord(
            id: uid(1),
            title: nil,
            kind: PanelKind.markdown,
            updated: 8
        ))
        XCTAssertEqual(untitled.title, PanelSummaryFallback.markdown)
        let recent = GlanceHomeProjection.recent(
            clipboards: [],
            files: [],
            snippets: [],
            links: [],
            panels: [untitled]
        )
        XCTAssertEqual(recent.first?.title, PanelSummaryFallback.markdown)
        XCTAssertEqual(recent.first?.id, GlobalSearchResultID(source: .panels, itemID: uid(1)))
    }

    func testHomeItemTitlesUseExistingPreviewRules() {
        let text = clipboard(
            id: uid(1),
            text: "first line\nsecond line",
            copied: 1
        )
        let image = ClipboardHistoryRecord(
            id: uid(2),
            kind: .image,
            createdAt: Date(timeIntervalSince1970: 1),
            lastCopiedAt: Date(timeIntervalSince1970: 2),
            isFavorite: false,
            favoritedAt: nil,
            contentHash: "image",
            text: nil,
            assetPath: "Assets/x.png"
        )
        XCTAssertEqual(GlanceHomeTitle.clipboard(text), "first line")
        XCTAssertEqual(GlanceHomeTitle.clipboard(image), GlobalSearchCopy.clipboardImageTitle)
    }

    func testHomeMenuRevealsInSourceInsteadOfPrimaryActions() {
        let clipboardID = uid(1)
        let linkID = uid(2)
        let snapshot = GlanceHomeSnapshotBuilder.build(
            clipboards: [
                clipboard(id: clipboardID, text: "keep", favorite: true, copied: 20, favorited: 20)
            ],
            links: [
                link(id: linkID, title: "Glance", pinned: true, opened: 10)
            ]
        )
        var revealed: [GlobalSearchResultID] = []
        let copied = 0
        let openedBrowser = 0
        let menu = NSMenu()
        GlanceMenuFixtures.populate(
            menu,
            homeSnapshot: snapshot,
            onRevealHomeItem: { id in
                revealed.append(id)
                return .succeeded
            }
        )
        let preferred = GlanceMenuQuery.homeMenu(titled: GlanceHomeCopy.preferred, in: menu)
        invoke(preferred?.items.first { $0.title == "keep" })
        invoke(preferred?.items.first { $0.title == "Glance" })
        XCTAssertEqual(
            revealed,
            [
                GlobalSearchResultID(source: .clipboard, itemID: clipboardID),
                GlobalSearchResultID(source: .links, itemID: linkID)
            ]
        )
        XCTAssertEqual(copied, 0)
        XCTAssertEqual(openedBrowser, 0)
        XCTAssertEqual(preferred?.items.first { $0.title == "keep" }?.image != nil, true)
    }

    func testStaleHomeClickFailsClosedWithoutCrashing() {
        let snippetID = uid(8)
        let snapshot = GlanceHomeSnapshotBuilder.build(
            snippets: [
                snippet(id: snippetID, title: "gone", pinned: true, used: 5)
            ]
        )
        var revealed: GlobalSearchResultID?
        let menu = NSMenu()
        GlanceMenuFixtures.populate(
            menu,
            homeSnapshot: snapshot,
            onRevealHomeItem: { id in
                revealed = id
                return .failed(GlanceNoticeCopy.staleItem)
            }
        )
        invoke(GlanceMenuQuery.homeMenu(titled: GlanceHomeCopy.preferred, in: menu)?.items.first)
        XCTAssertEqual(revealed, GlobalSearchResultID(source: .snippets, itemID: snippetID))
    }

    func testRecentFileShelfClickRevealsFileNotOpen() {
        let fileID = uid(4)
        let snapshot = GlanceHomeSnapshotBuilder.build(
            files: [file(id: fileID, name: "deck.pdf", used: 9)]
        )
        var revealed: GlobalSearchResultID?
        let menu = NSMenu()
        GlanceMenuFixtures.populate(
            menu,
            homeSnapshot: snapshot,
            onRevealHomeItem: { id in
                revealed = id
                return .succeeded
            }
        )
        invoke(GlanceMenuQuery.homeMenu(titled: GlanceHomeCopy.recent, in: menu)?.items.first)
        XCTAssertEqual(revealed, GlobalSearchResultID(source: .fileShelf, itemID: fileID))
    }

    private func invoke(_ item: NSMenuItem?) {
        guard let item, let action = item.action else {
            XCTFail("Missing menu action")
            return
        }
        _ = item.target?.perform(action, with: item)
    }
}

private func uid(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", value))!
}

private func clipboard(
    id: UUID,
    text: String,
    favorite: Bool = false,
    copied: TimeInterval,
    favorited: TimeInterval? = nil
) -> ClipboardHistoryRecord {
    ClipboardHistoryRecord(
        id: id,
        kind: .text,
        createdAt: Date(timeIntervalSince1970: copied),
        lastCopiedAt: Date(timeIntervalSince1970: copied),
        isFavorite: favorite,
        favoritedAt: favorited.map { Date(timeIntervalSince1970: $0) },
        contentHash: text,
        text: text,
        assetPath: nil
    )
}

private func file(
    id: UUID,
    name: String,
    favorite: Bool = false,
    used: TimeInterval,
    favorited: TimeInterval? = nil
) -> FileShelfRecord {
    FileShelfRecord(
        id: id,
        originalPath: "/tmp/\(name)",
        displayName: name,
        fileSize: 12,
        contentTypeIdentifier: "com.adobe.pdf",
        createdAt: Date(timeIntervalSince1970: used),
        lastUsedAt: Date(timeIntervalSince1970: used),
        isFavorite: favorite,
        favoritedAt: favorited.map { Date(timeIntervalSince1970: $0) }
    )
}

private func snippet(
    id: UUID,
    title: String,
    pinned: Bool = false,
    used: TimeInterval
) -> SnippetRecord {
    SnippetRecord(
        id: id,
        title: title,
        content: title,
        createdAt: Date(timeIntervalSince1970: used),
        updatedAt: Date(timeIntervalSince1970: used),
        lastUsedAt: Date(timeIntervalSince1970: used),
        isPinned: pinned
    )
}

private func link(
    id: UUID,
    title: String,
    pinned: Bool = false,
    opened: TimeInterval
) -> LinkRecord {
    LinkRecord(
        id: id,
        title: title,
        urlString: "https://example.com/\(title)",
        createdAt: Date(timeIntervalSince1970: opened),
        updatedAt: Date(timeIntervalSince1970: opened),
        lastOpenedAt: Date(timeIntervalSince1970: opened),
        isPinned: pinned
    )
}

private func homePanel(
    id: UUID,
    title: String?,
    updated: TimeInterval
) -> GlanceHomePanelCandidate {
    GlanceHomePanelCandidate(record: panelRecord(id: id, title: title, updated: updated))
}

private func panelRecord(
    id: UUID,
    title: String?,
    kind: String = PanelKind.text,
    updated: TimeInterval,
    pinned: Bool = true
) -> PanelRecord {
    PanelRecord(
        id: id,
        kindIdentifier: kind,
        frame: PanelFrame(x: 0, y: 0, width: 240, height: 180),
        displayIdentifier: "main",
        payloadPath: "payload",
        payloadVersion: 1,
        isPinned: pinned,
        customTitle: title,
        updatedAt: Date(timeIntervalSince1970: updated)
    )
}
