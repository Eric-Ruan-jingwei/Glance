import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class ClipboardHistoryModelTests: XCTestCase {
    private let samplePNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    func testTextHashUsesExactUTF8Bytes() {
        let spaced = "  hello\nworld  "
        XCTAssertNotEqual(
            ClipboardHistoryHasher.hash(text: spaced),
            ClipboardHistoryHasher.hash(text: spaced.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        XCTAssertEqual(ClipboardHistoryHasher.hash(text: "Hello"), ClipboardHistoryHasher.hash(text: "Hello"))
    }

    func testSearchIsCaseInsensitiveSubstringOnFullText() {
        let record = ClipboardHistoryRecord(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            lastCopiedAt: Date(),
            isFavorite: false,
            favoritedAt: nil,
            contentHash: "h",
            text: "Hello\nGlance Shelf",
            assetPath: nil
        )
        XCTAssertTrue(ClipboardHistorySearch.matches(record, query: "glance"))
        XCTAssertTrue(ClipboardHistorySearch.matches(record, query: "SHELF"))
        XCTAssertFalse(ClipboardHistorySearch.matches(record, query: "missing"))
        let image = ClipboardHistoryRecord(
            id: UUID(),
            kind: .image,
            createdAt: Date(),
            lastCopiedAt: Date(),
            isFavorite: false,
            favoritedAt: nil,
            contentHash: "i",
            text: nil,
            assetPath: "Assets/x.png"
        )
        XCTAssertTrue(ClipboardHistorySearch.matches(image, query: ""))
        XCTAssertTrue(ClipboardHistorySearch.matches(image, query: "   "))
        XCTAssertFalse(ClipboardHistorySearch.matches(image, query: "png"))
    }

    func testRetentionKeepsOneHundredNonfavoritesAndExemptsFavorites() {
        var records: [ClipboardHistoryRecord] = []
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<101 {
            records.append(
                ClipboardHistoryRecord(
                    id: UUID(),
                    kind: .text,
                    createdAt: start,
                    lastCopiedAt: start.addingTimeInterval(TimeInterval(index)),
                    isFavorite: false,
                    favoritedAt: nil,
                    contentHash: "n-\(index)",
                    text: "item \(index)",
                    assetPath: nil
                )
            )
        }
        let favoriteID = UUID()
        records.append(
            ClipboardHistoryRecord(
                id: favoriteID,
                kind: .text,
                createdAt: start,
                lastCopiedAt: start,
                isFavorite: true,
                favoritedAt: start,
                contentHash: "fav",
                text: "keep",
                assetPath: nil
            )
        )
        let evicted = ClipboardHistoryRetention.idsToEvict(from: records)
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(records.first { $0.lastCopiedAt == start && !$0.isFavorite }?.id, evicted[0])
        XCTAssertFalse(evicted.contains(favoriteID))
    }

    func testPrivacyMarkersSkipKnownTypes() {
        XCTAssertTrue(
            ClipboardPrivacyMarkers.shouldSkip(typeStrings: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"])
        )
        XCTAssertTrue(
            ClipboardPrivacyMarkers.shouldSkip(typeStrings: ["org.nspasteboard.TransientType"])
        )
        XCTAssertFalse(ClipboardPrivacyMarkers.shouldSkip(typeStrings: ["public.utf8-plain-text", "public.png"]))
    }

    func testMonitorPolicyRequiresEnabledBaselineAndChange() {
        XCTAssertFalse(ClipboardHistoryMonitorPolicy.shouldRead(enabled: false, lastChangeCount: 1, currentChangeCount: 2))
        XCTAssertFalse(ClipboardHistoryMonitorPolicy.shouldRead(enabled: true, lastChangeCount: nil, currentChangeCount: 2))
        XCTAssertFalse(ClipboardHistoryMonitorPolicy.shouldRead(enabled: true, lastChangeCount: 3, currentChangeCount: 3))
        XCTAssertTrue(ClipboardHistoryMonitorPolicy.shouldRead(enabled: true, lastChangeCount: 3, currentChangeCount: 4))
    }

    func testHistoryShortcutIsOptionCommandVAndHotKeyFour() {
        XCTAssertEqual(ShortcutAction.clipboardHistory.title, "剪贴板")
        XCTAssertEqual(ShortcutDefaults.clipboardHistory.key, "v")
        XCTAssertEqual(GlanceConstants.clipboardHistoryShortcutDisplay, "⌥⌘V")
        XCTAssertEqual(GlanceHotKeyID.clipboardHistory.rawValue, 4)
        XCTAssertEqual(GlanceHotKeyID.fileShelf.rawValue, 5)
        XCTAssertEqual(GlanceHotKeyID.snippets.rawValue, 6)
        XCTAssertEqual(GlanceHotKeyID.clipboardCapture.rawValue, 3)
        XCTAssertEqual(ShortcutAction.clipboardCapture.title, "从当前剪贴板创建")
    }

    func testHistoryContentReusesExistingPanelRouting() {
        XCTAssertEqual(ClipboardCaptureRouter.initialContent(for: .text("Hello")), .plainText("Hello"))
        XCTAssertEqual(ClipboardCaptureRouter.kindIdentifier(for: .text("Hello")), PanelKind.text)
        XCTAssertEqual(ClipboardCaptureRouter.initialContent(for: .png(samplePNG)), .imagePNG(samplePNG))
        XCTAssertEqual(ClipboardCaptureRouter.kindIdentifier(for: .png(samplePNG)), PanelKind.image)
    }
}

@MainActor
final class ClipboardHistoryStoreAndServiceTests: XCTestCase {
    private let samplePNG = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )!

    func testTextIsRetainedExactlyAndWhitespaceOnlyIsIgnored() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        XCTAssertNil(service.record(.text("   \n\t")))
        let recorded = try XCTUnwrap(service.record(.text("  hello\nworld  ")))
        XCTAssertEqual(recorded.text, "  hello\nworld  ")
        XCTAssertEqual(service.records.count, 1)
    }

    func testSameTextDedupesAndUpdatesLastCopiedAtWhilePreservingFavorite() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)
        let created = try XCTUnwrap(service.record(.text("Hello"), at: first))
        service.toggleFavorite(id: created.id, at: first)
        let again = try XCTUnwrap(service.record(.text("Hello"), at: second))
        XCTAssertEqual(service.records.count, 1)
        XCTAssertEqual(again.id, created.id)
        XCTAssertEqual(again.createdAt, first)
        XCTAssertEqual(again.lastCopiedAt, second)
        XCTAssertTrue(again.isFavorite)
        XCTAssertEqual(again.favoritedAt, first)
    }

    func testSameImageDedupesByNormalizedPNGHash() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let first = try XCTUnwrap(service.record(.png(samplePNG), at: Date(timeIntervalSince1970: 1)))
        let second = try XCTUnwrap(service.record(.png(samplePNG), at: Date(timeIntervalSince1970: 2)))
        XCTAssertEqual(service.records.count, 1)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.lastCopiedAt, Date(timeIntervalSince1970: 2))
        XCTAssertTrue(FileManager.default.fileExists(atPath: service.store.assetURL(for: first)!.path))
    }

    func testOversizedImageIsNotRecorded() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let huge = Data(repeating: 1, count: ClipboardHistoryPolicy.maximumStoredImageBytes + 1)
        XCTAssertNil(service.record(.png(huge)))
        XCTAssertTrue(service.records.isEmpty)
    }

    func testOneHundredFirstNonfavoriteEvictsOldestAndFavoritesStay() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let start = Date(timeIntervalSince1970: 1_000)
        let favorite = try XCTUnwrap(service.record(.text("keep"), at: start))
        service.toggleFavorite(id: favorite.id, at: start)
        for index in 0..<100 {
            _ = service.record(.text("item \(index)"), at: start.addingTimeInterval(TimeInterval(index + 1)))
        }
        XCTAssertEqual(service.records.filter { !$0.isFavorite }.count, 100)
        XCTAssertTrue(service.records.contains { $0.id == favorite.id && $0.isFavorite })
        _ = service.record(.text("overflow"), at: start.addingTimeInterval(200))
        XCTAssertEqual(service.records.filter { !$0.isFavorite }.count, 100)
        XCTAssertTrue(service.records.contains { $0.id == favorite.id })
        XCTAssertFalse(service.records.contains { $0.text == "item 0" })
        XCTAssertTrue(service.records.contains { $0.text == "overflow" })
    }

    func testUnfavoriteBecomesEligibleForEviction() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let start = Date(timeIntervalSince1970: 5_000)
        let favorite = try XCTUnwrap(service.record(.text("old favorite"), at: start))
        service.toggleFavorite(id: favorite.id, at: start)
        service.toggleFavorite(id: favorite.id, at: start.addingTimeInterval(1))
        XCTAssertFalse(service.records[0].isFavorite)
        XCTAssertNil(service.records[0].favoritedAt)
        for index in 0..<100 {
            _ = service.record(.text("fresh \(index)"), at: start.addingTimeInterval(TimeInterval(index + 10)))
        }
        XCTAssertFalse(service.records.contains { $0.id == favorite.id })
    }

    func testDeleteImageRemovesMetadataThenAsset() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let record = try XCTUnwrap(service.record(.png(samplePNG)))
        let assetURL = try XCTUnwrap(service.store.assetURL(for: record))
        XCTAssertTrue(FileManager.default.fileExists(atPath: assetURL.path))
        service.delete(id: record.id)
        XCTAssertTrue(service.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: assetURL.path))
    }

    func testMetadataSaveFailureDoesNotDeleteImageAsset() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboard-\(UUID().uuidString)", isDirectory: true)
        var failSave = false
        let store = ClipboardHistoryStore(root: root, writePrimaryMetadata: { data, url in
            if failSave { throw ClipboardHistoryStoreError.writeFailed }
            try data.write(to: url, options: .atomic)
        })
        let defaultsName = "GlanceClipboardDefaults-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        let service = ClipboardHistoryService(
            store: store,
            preferences: ClipboardHistoryPreferenceStore(defaults: defaults)
        )
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let record = try XCTUnwrap(service.record(.png(samplePNG)))
        let assetURL = try XCTUnwrap(service.store.assetURL(for: record))
        failSave = true
        service.delete(id: record.id)
        XCTAssertEqual(service.records.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: assetURL.path))
    }

    func testClearRecentKeepsFavoritesAndClearAllRemovesEverything() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let favorite = try XCTUnwrap(service.record(.text("fav")))
        service.toggleFavorite(id: favorite.id)
        _ = service.record(.text("recent"))
        let image = try XCTUnwrap(service.record(.png(samplePNG)))
        service.clearRecent()
        XCTAssertEqual(service.records.map(\.id), [favorite.id])
        XCTAssertNil(service.store.assetURL(for: image).flatMap { url in
            FileManager.default.fileExists(atPath: url.path) ? url : nil
        })
        service.clearAll()
        XCTAssertTrue(service.records.isEmpty)
        let assets = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Assets").path)
        XCTAssertTrue(assets.isEmpty)
    }

    func testFutureSchemaDoesNotOverwriteAndCorruptRecoversWithoutTouchingPanels() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = root.appendingPathComponent("history.json")
        let future = """
        { "schemaVersion": 9, "items": [] }
        """
        try Data(future.utf8).write(to: metadata)
        let store = ClipboardHistoryStore(root: root)
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertEqual(store.lastLoadOutcome, .unsupportedFutureSchema(9))
        XCTAssertFalse(store.isWritable)
        XCTAssertThrowsError(try store.save([]))
        XCTAssertEqual(try String(contentsOf: metadata, encoding: .utf8), future)

        let corruptRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: corruptRoot, withIntermediateDirectories: true)
        let corruptURL = corruptRoot.appendingPathComponent("history.json")
        try Data("{".utf8).write(to: corruptURL)
        let panelRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlancePanels-\(UUID().uuidString)", isDirectory: true)
        let payload = try PayloadStore(applicationSupportRoot: panelRoot)
        let repository = try PanelRepository(fileURL: payload.metadataURL)
        let recovered = ClipboardHistoryStore(root: corruptRoot)
        XCTAssertTrue(recovered.load().isEmpty)
        XCTAssertEqual(recovered.lastLoadOutcome, .recoveredFromCorruption)
        XCTAssertEqual((try? repository.all())?.count, 0)
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: corruptRoot)
        try? FileManager.default.removeItem(at: panelRoot)
    }

    func testSchemaOneRoundTrip() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        _ = service.record(.text("round trip"))
        let data = try Data(contentsOf: root.appendingPathComponent("history.json"))
        let decoded = try ClipboardHistoryCodec.decode(from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.items.first?.text, "round trip")
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
    }

    func testOwnWriteIsAdoptedAndDoesNotCreateADuplicate() throws {
        let (service, root, defaultsName) = try makeService()
        defer { cleanup(root: root, defaultsName: defaultsName) }
        let record = try XCTUnwrap(service.record(.text("Hello")))
        let content = try XCTUnwrap(service.reuse(record.id, at: Date(timeIntervalSince1970: 50)))
        let pasteboard = NSPasteboard.withUniqueName()
        let written = MacClipboardWriter.write(content, to: pasteboard)
        XCTAssertFalse(
            ClipboardHistoryMonitorPolicy.shouldRead(
                enabled: true,
                lastChangeCount: written,
                currentChangeCount: pasteboard.changeCount
            )
        )
        XCTAssertEqual(service.records.count, 1)
        XCTAssertEqual(service.records[0].lastCopiedAt, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(pasteboard.string(forType: .string), "Hello")
    }

    func testMonitorTickReadsOnlyOnChangeCountAndNeverRetroactively() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("already there", forType: .string)
        let baseline = pasteboard.changeCount
        var captured: [ClipboardCaptureContent] = []
        let monitor = ClipboardHistoryMonitor(
            pasteboard: pasteboard,
            interval: 30,
            isEnabled: { true }
        )
        monitor.onCapture = { captured.append($0) }
        monitor.start(baselineChangeCount: baseline)
        monitor.tick()
        XCTAssertTrue(captured.isEmpty)

        pasteboard.clearContents()
        pasteboard.setString("Hello", forType: .string)
        monitor.tick()
        XCTAssertEqual(captured, [.text("Hello")])

        monitor.tick()
        XCTAssertEqual(captured, [.text("Hello")])
        monitor.stop()
    }

    func testDisabledMonitorDoesNotCapture() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)
        var captured = 0
        let monitor = ClipboardHistoryMonitor(
            pasteboard: pasteboard,
            interval: 30,
            isEnabled: { false }
        )
        monitor.onCapture = { _ in captured += 1 }
        monitor.start(baselineChangeCount: pasteboard.changeCount)
        pasteboard.clearContents()
        pasteboard.setString("after", forType: .string)
        monitor.tick()
        XCTAssertEqual(captured, 0)
        monitor.stop()
    }

    func testIngestSkipsPrivacyAndOversizedRawImage() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes(
            [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
            owner: nil
        )
        pasteboard.setString("secret", forType: .string)
        XCTAssertEqual(ClipboardHistoryIngest.read(pasteboard), .skippedPrivacy)

        let imageBoard = NSPasteboard.withUniqueName()
        imageBoard.clearContents()
        imageBoard.declareTypes([.png], owner: nil)
        imageBoard.setData(
            Data(repeating: 2, count: ClipboardHistoryPolicy.maximumStoredImageBytes + 8),
            forType: .png
        )
        XCTAssertEqual(ClipboardHistoryIngest.read(imageBoard), .skippedOversizedImage)
    }

    func testIngestKeepsSmallPNGWhenAnotherRepresentationIsOversized() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        pasteboard.setData(samplePNG, forType: .png)
        pasteboard.setData(
            Data(repeating: 3, count: ClipboardHistoryPolicy.maximumStoredImageBytes + 16),
            forType: .tiff
        )
        XCTAssertEqual(ClipboardHistoryIngest.read(pasteboard), .captured(.png(samplePNG)))
        XCTAssertEqual(MacClipboardReader.read(pasteboard), .png(samplePNG))
    }

    func testIngestUsesValidSecondaryRepresentationWhenPNGIsOversized() {
        let jpeg = tinyJPEG()
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, NSPasteboard.PasteboardType("public.jpeg")], owner: nil)
        pasteboard.setData(
            Data(repeating: 4, count: ClipboardHistoryPolicy.maximumStoredImageBytes + 16),
            forType: .png
        )
        pasteboard.setData(jpeg, forType: NSPasteboard.PasteboardType("public.jpeg"))
        switch ClipboardHistoryIngest.read(pasteboard) {
        case .captured(.png(let data)):
            XCTAssertTrue(MediaStore.looksLikePNG(data))
            XCTAssertLessThanOrEqual(data.count, ClipboardHistoryPolicy.maximumStoredImageBytes)
        default:
            XCTFail("oversized PNG should fall through to a valid JPEG representation")
        }
    }

    func testIngestFallsBackToTextWhenImageIsUnreadable() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.tiff, .string], owner: nil)
        pasteboard.setData(Data([0x00, 0x01]), forType: .tiff)
        pasteboard.setString("hello", forType: .string)
        XCTAssertEqual(ClipboardHistoryIngest.read(pasteboard), .captured(.text("hello")))
        XCTAssertEqual(MacClipboardReader.read(pasteboard), .text("hello"))
    }

    private func tinyJPEG() -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        return NSBitmapImageRep(data: tiff)!.representation(using: .jpeg, properties: [:])!
    }

    func testMenuAndGuideExposeClipboardHistory() {
        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            onQuickCapture: {},
            onShowClipboardHistory: {},
            onCaptureClipboard: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {}
        )
        XCTAssertEqual(menu.items[0].title, "快速记录…")
        XCTAssertEqual(menu.items.first { $0.title == "剪贴板…" }?.title, "剪贴板…")
        XCTAssertEqual(menu.items.first { $0.title == "文件架…" }?.title, "文件架…")
        XCTAssertEqual(menu.items.first { $0.title == "片段库…" }?.title, "片段库…")
        XCTAssertNotNil(menu.items.first { $0.title == "面板" }?.submenu)
        let history = menu.items.first { $0.title == "剪贴板…" }
        XCTAssertEqual(history?.keyEquivalent, "v")
        XCTAssertEqual(history?.keyEquivalentModifierMask, [.option, .command])
        let capture = GlanceMenuQuery.item(titled: "从当前剪贴板创建…", in: menu)
        XCTAssertEqual(capture?.keyEquivalent, "b")

        let item = GuideShortcutCatalog.item(id: "clipboardHistory")
        if case .dynamic(let action) = item?.source {
            XCTAssertEqual(action, .clipboardHistory)
        } else {
            XCTFail("clipboardHistory must read ShortcutCoordinator")
        }
        let custom = GlanceShortcut(key: "v", command: false, option: true, control: true, shift: false)
        XCTAssertEqual(
            item?.tokens { action in
                action == .clipboardHistory ? custom : ShortcutDefaults.shortcut(for: action)
            }.map(\.display),
            ["⌃", "⌥", "V"]
        )
    }

    private func makeService() throws -> (ClipboardHistoryService, URL, String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlanceClipboard-\(UUID().uuidString)", isDirectory: true)
        let defaultsName = "GlanceClipboardDefaults-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        let service = ClipboardHistoryService(
            store: ClipboardHistoryStore(root: root),
            preferences: ClipboardHistoryPreferenceStore(defaults: defaults)
        )
        return (service, root, defaultsName)
    }

    private func cleanup(root: URL, defaultsName: String) {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: defaultsName)?.removePersistentDomain(forName: defaultsName)
    }
}
