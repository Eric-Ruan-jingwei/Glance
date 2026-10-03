import AppKit
import Carbon
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class ShortcutPreferencesTests: XCTestCase {
    private let controlOptionK = GlanceShortcut(
        key: "k",
        command: false,
        option: true,
        control: true,
        shift: false
    )

    func testDefaultShortcuts() {
        XCTAssertEqual(ShortcutDefaults.quickCapture, GlanceShortcut(key: "j", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDefaults.clipboardHistory, GlanceShortcut(key: "v", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDefaults.fileShelf, GlanceShortcut(key: "f", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDefaults.snippets, GlanceShortcut(key: "s", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDefaults.clipboardCapture, GlanceShortcut(key: "b", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDefaults.hideShow, GlanceShortcut(key: "g", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.quickCapture), "⌥⌘J")
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.clipboardHistory), "⌥⌘V")
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.fileShelf), "⌥⌘F")
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.snippets), "⌥⌘S")
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.clipboardCapture), "⌥⌘B")
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.hideShow), "⌥⌘G")
        XCTAssertEqual(GlanceConstants.quickCaptureShortcutDisplay, "⌥⌘J")
        XCTAssertEqual(GlanceConstants.clipboardHistoryShortcutDisplay, "⌥⌘V")
        XCTAssertEqual(GlanceConstants.fileShelfShortcutDisplay, "⌥⌘F")
        XCTAssertEqual(GlanceConstants.snippetsShortcutDisplay, "⌥⌘S")
        XCTAssertEqual(GlanceConstants.clipboardCaptureShortcutDisplay, "⌥⌘B")
        XCTAssertEqual(GlanceConstants.hideShowShortcutDisplay, "⌥⌘G")
        XCTAssertEqual(ShortcutAction.quickCapture.preferenceKey, "com.glance.shortcut.quickCapture")
        XCTAssertEqual(ShortcutAction.clipboardHistory.preferenceKey, "com.glance.shortcut.clipboardHistory")
        XCTAssertEqual(ShortcutAction.fileShelf.preferenceKey, "com.glance.shortcut.fileShelf")
        XCTAssertEqual(ShortcutAction.snippets.preferenceKey, "com.glance.shortcut.snippets")
        XCTAssertEqual(ShortcutAction.clipboardCapture.preferenceKey, "com.glance.shortcut.clipboardCapture")
        XCTAssertEqual(ShortcutAction.hideShow.preferenceKey, "com.glance.shortcut.hideShow")
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(controlOptionK)
        let decoded = try JSONDecoder().decode(GlanceShortcut.self, from: data)
        XCTAssertEqual(decoded, controlOptionK)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["key"] as? String, "k")
        XCTAssertEqual(object["command"] as? Bool, false)
        XCTAssertEqual(object["option"] as? Bool, true)
        XCTAssertEqual(object["control"] as? Bool, true)
        XCTAssertEqual(object["shift"] as? Bool, false)
        XCTAssertNil(object["keyCode"])
    }

    func testCanonicalEquality() {
        let upper = GlanceShortcut(key: "J", command: true, option: true, control: false, shift: false)
        let lower = GlanceShortcut(key: "j", command: true, option: true, control: false, shift: false)
        XCTAssertEqual(upper, lower)
        XCTAssertEqual(upper.canonicalKey, "j")
    }

    func testCustomPersistenceRoundTrip() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        store.setShortcut(controlOptionK, for: .quickCapture)
        let restored = ShortcutStore(defaults: defaults)
        XCTAssertEqual(restored.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(restored.shortcut(for: .clipboardCapture), ShortcutDefaults.clipboardCapture)
    }

    func testCorruptPreferenceFallsBackToDefault() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("not-json", forKey: ShortcutAction.quickCapture.preferenceKey)
        XCTAssertEqual(store.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        defaults.set(Data("{".utf8), forKey: ShortcutAction.hideShow.preferenceKey)
        XCTAssertEqual(store.shortcut(for: .hideShow), ShortcutDefaults.hideShow)
        let empty = GlanceShortcut(key: "", command: true, option: true, control: false, shift: false)
        if let data = try? JSONEncoder().encode(empty) {
            defaults.set(data, forKey: ShortcutAction.clipboardCapture.preferenceKey)
        }
        XCTAssertEqual(store.shortcut(for: .clipboardCapture), ShortcutDefaults.clipboardCapture)
    }

    func testInvalidAndDangerousShortcutsAreRejected() {
        XCTAssertEqual(
            ShortcutValidator.problem(with: GlanceShortcut(key: "j", command: false, option: false, control: false, shift: false)),
            .invalidCombination
        )
        XCTAssertEqual(
            ShortcutValidator.problem(with: GlanceShortcut(key: "j", command: false, option: false, control: false, shift: true)),
            .invalidCombination
        )
        XCTAssertEqual(
            ShortcutValidator.problem(with: GlanceShortcut(key: "c", command: true, option: false, control: false, shift: false)),
            .invalidCombination
        )
        XCTAssertEqual(
            ShortcutValidator.problem(with: GlanceShortcut(key: "v", command: true, option: false, control: false, shift: false)),
            .invalidCombination
        )
        XCTAssertEqual(
            ShortcutValidator.problem(with: GlanceShortcut(key: "q", command: true, option: false, control: false, shift: false)),
            .invalidCombination
        )
        XCTAssertEqual(
            ShortcutValidator.problem(with: GlanceShortcut(key: " ", command: true, option: true, control: false, shift: false)),
            .unsupportedKey
        )
        XCTAssertNil(ShortcutValidator.problem(with: controlOptionK))
        XCTAssertNil(ShortcutValidator.problem(with: ShortcutDefaults.quickCapture))
    }

    func testDuplicateDetectionLeavesPreferencesUnchanged() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let duplicate = ShortcutValidator.duplicate(
            of: ShortcutDefaults.clipboardCapture,
            excluding: .quickCapture,
            in: store.all()
        )
        XCTAssertEqual(duplicate, .clipboardCapture)
        XCTAssertEqual(store.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
    }

    func testFormatterOrder() {
        XCTAssertEqual(ShortcutDisplayFormatter.display(controlOptionK), "⌃⌥K")
        XCTAssertEqual(
            ShortcutDisplayFormatter.display(
                GlanceShortcut(key: "l", command: true, option: true, control: false, shift: true)
            ),
            "⌥⇧⌘L"
        )
        XCTAssertEqual(ShortcutDisplayFormatter.keyEquivalent(controlOptionK), "k")
    }

    func testCarbonMapping() {
        XCTAssertEqual(MacShortcutAdapter.carbonKeyCode(for: ShortcutDefaults.quickCapture), UInt32(kVK_ANSI_J))
        XCTAssertEqual(MacShortcutAdapter.carbonKeyCode(for: ShortcutDefaults.clipboardHistory), UInt32(kVK_ANSI_V))
        XCTAssertEqual(MacShortcutAdapter.carbonKeyCode(for: ShortcutDefaults.fileShelf), UInt32(kVK_ANSI_F))
        XCTAssertEqual(MacShortcutAdapter.carbonKeyCode(for: ShortcutDefaults.snippets), UInt32(kVK_ANSI_S))
        XCTAssertEqual(MacShortcutAdapter.carbonKeyCode(for: ShortcutDefaults.clipboardCapture), UInt32(kVK_ANSI_B))
        XCTAssertEqual(MacShortcutAdapter.carbonKeyCode(for: ShortcutDefaults.hideShow), UInt32(kVK_ANSI_G))
        XCTAssertEqual(MacShortcutAdapter.carbonKeyCode(for: controlOptionK), UInt32(kVK_ANSI_K))
        let quickModifiers = MacShortcutAdapter.carbonModifiers(for: ShortcutDefaults.quickCapture)
        XCTAssertEqual(quickModifiers & UInt32(cmdKey), UInt32(cmdKey))
        XCTAssertEqual(quickModifiers & UInt32(optionKey), UInt32(optionKey))
        XCTAssertEqual(quickModifiers & UInt32(controlKey), 0)
        let menu = MacShortcutAdapter.menuModifierMask(for: controlOptionK)
        XCTAssertTrue(menu.contains(.control))
        XCTAssertTrue(menu.contains(.option))
        XCTAssertFalse(menu.contains(.command))
    }

    func testClipboardHistoryRegistersAndDispatches() {
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        var shown = 0
        manager.onShowClipboardHistory = { shown += 1 }
        XCTAssertTrue(manager.register(ShortcutDefaults.clipboardHistory, for: .clipboardHistory))
        XCTAssertEqual(fake.registered[GlanceHotKeyID.clipboardHistory.rawValue]?.keyCode, UInt32(kVK_ANSI_V))
        manager.handleHotKeyForTesting(.clipboardHistory)
        XCTAssertEqual(shown, 1)
        manager.suspend(.clipboardHistory)
        manager.handleHotKeyForTesting(.clipboardHistory)
        XCTAssertEqual(shown, 1)
        try? manager.resume(.clipboardHistory)
        manager.handleHotKeyForTesting(.clipboardHistory)
        XCTAssertEqual(shown, 2)
    }

    func testFileShelfRegistersReplacesAndDispatchesHotKeyFive() throws {
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        var shown = 0
        manager.onShowFileShelf = { shown += 1 }
        XCTAssertTrue(manager.register(ShortcutDefaults.fileShelf, for: .fileShelf))
        XCTAssertEqual(fake.registered[GlanceHotKeyID.fileShelf.rawValue]?.keyCode, UInt32(kVK_ANSI_F))
        XCTAssertEqual(GlanceHotKeyID.fileShelf.rawValue, 5)
        manager.handleHotKeyForTesting(.fileShelf)
        XCTAssertEqual(shown, 1)

        let replaced = GlanceShortcut(key: "f", command: false, option: true, control: true, shift: false)
        try manager.replaceShortcut(for: .fileShelf, with: replaced)
        XCTAssertEqual(manager.registeredShortcut(for: .fileShelf), replaced)
        XCTAssertEqual(fake.registered[GlanceHotKeyID.fileShelf.rawValue]?.keyCode, UInt32(kVK_ANSI_F))

        manager.suspend(.fileShelf)
        manager.handleHotKeyForTesting(.fileShelf)
        XCTAssertEqual(shown, 1)
        try manager.resume(.fileShelf)
        manager.handleHotKeyForTesting(.fileShelf)
        XCTAssertEqual(shown, 2)

        XCTAssertEqual(
            ShortcutValidator.duplicate(
                of: ShortcutDefaults.fileShelf,
                excluding: .quickCapture,
                in: ShortcutDefaults.all
            ),
            .fileShelf
        )
    }

    func testSnippetsRegistersReplacesAndDispatchesHotKeySix() throws {
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        var shown = 0
        manager.onShowSnippets = { shown += 1 }
        XCTAssertTrue(manager.register(ShortcutDefaults.snippets, for: .snippets))
        XCTAssertEqual(fake.registered[GlanceHotKeyID.snippets.rawValue]?.keyCode, UInt32(kVK_ANSI_S))
        XCTAssertEqual(GlanceHotKeyID.snippets.rawValue, 6)
        manager.handleHotKeyForTesting(.snippets)
        XCTAssertEqual(shown, 1)

        let replaced = GlanceShortcut(key: "s", command: false, option: true, control: true, shift: false)
        try manager.replaceShortcut(for: .snippets, with: replaced)
        XCTAssertEqual(manager.registeredShortcut(for: .snippets), replaced)

        manager.suspend(.snippets)
        manager.handleHotKeyForTesting(.snippets)
        XCTAssertEqual(shown, 1)
        try manager.resume(.snippets)
        manager.handleHotKeyForTesting(.snippets)
        XCTAssertEqual(shown, 2)

        XCTAssertEqual(
            ShortcutValidator.duplicate(
                of: ShortcutDefaults.snippets,
                excluding: .quickCapture,
                in: ShortcutDefaults.all
            ),
            .snippets
        )
    }

    func testExistingShortcutPreferencesSurviveSnippetsMigration() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let customCapture = GlanceShortcut(key: "k", command: false, option: true, control: true, shift: false)
        let customClipboard = GlanceShortcut(key: "v", command: false, option: true, control: true, shift: false)
        let customShelf = GlanceShortcut(key: "f", command: false, option: true, control: true, shift: false)
        store.setShortcut(customCapture, for: .quickCapture)
        store.setShortcut(customClipboard, for: .clipboardHistory)
        store.setShortcut(customShelf, for: .fileShelf)
        let restored = ShortcutStore(defaults: defaults)
        XCTAssertEqual(restored.shortcut(for: .quickCapture), customCapture)
        XCTAssertEqual(restored.shortcut(for: .clipboardHistory), customClipboard)
        XCTAssertEqual(restored.shortcut(for: .fileShelf), customShelf)
        XCTAssertEqual(restored.shortcut(for: .snippets), ShortcutDefaults.snippets)
    }

    func testReplacementSuccessAndFailureRollback() throws {
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        XCTAssertTrue(manager.register(ShortcutDefaults.quickCapture, for: .quickCapture))
        XCTAssertEqual(fake.registered[GlanceHotKeyID.quickCapture.rawValue]?.keyCode, UInt32(kVK_ANSI_J))

        try manager.replaceShortcut(for: .quickCapture, with: controlOptionK)
        XCTAssertEqual(manager.registeredShortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(fake.registered[GlanceHotKeyID.quickCapture.rawValue]?.keyCode, UInt32(kVK_ANSI_K))

        fake.failNextRegister = true
        XCTAssertThrowsError(try manager.replaceShortcut(for: .quickCapture, with: ShortcutDefaults.hideShow)) { error in
            XCTAssertEqual(error as? ShortcutError, .registrationFailed)
        }
        XCTAssertEqual(manager.registeredShortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(fake.registered[GlanceHotKeyID.quickCapture.rawValue]?.keyCode, UInt32(kVK_ANSI_K))
    }

    func testSuccessfulReplaceAfterSuspendDispatches() throws {
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        var captures = 0
        manager.onQuickCapture = { captures += 1 }
        XCTAssertTrue(manager.register(ShortcutDefaults.quickCapture, for: .quickCapture))
        manager.suspend(.quickCapture)
        try manager.replaceShortcut(for: .quickCapture, with: controlOptionK)
        manager.finishSuspension(.quickCapture)
        XCTAssertFalse(manager.isSuspended(.quickCapture))
        manager.handleHotKeyForTesting(.quickCapture)
        XCTAssertEqual(captures, 1)
    }

    func testRestoreFailureIsReported() {
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        XCTAssertTrue(manager.register(ShortcutDefaults.quickCapture, for: .quickCapture))
        fake.failingIDs = [GlanceHotKeyID.quickCapture.rawValue]
        XCTAssertThrowsError(try manager.replaceShortcut(for: .quickCapture, with: controlOptionK)) { error in
            XCTAssertEqual(error as? ShortcutError, .restoreFailed)
        }
        XCTAssertNil(manager.registeredShortcut(for: .quickCapture))
    }

    func testRecorderInterpreter() {
        XCTAssertEqual(
            ShortcutRecorderInterpreter.interpret(
                escape: true,
                delete: false,
                key: "k",
                command: true,
                option: true,
                control: false,
                shift: false
            ),
            .cancel
        )
        XCTAssertEqual(
            ShortcutRecorderInterpreter.interpret(
                escape: false,
                delete: true,
                key: nil,
                command: false,
                option: false,
                control: false,
                shift: false
            ),
            .ignore
        )
        XCTAssertEqual(
            ShortcutRecorderInterpreter.interpret(
                escape: false,
                delete: false,
                key: " ",
                command: true,
                option: true,
                control: false,
                shift: false
            ),
            .reject(.unsupportedKey)
        )
        XCTAssertEqual(
            ShortcutRecorderInterpreter.interpret(
                escape: false,
                delete: false,
                key: "k",
                command: false,
                option: true,
                control: true,
                shift: false
            ),
            .capture(controlOptionK)
        )
    }

    func testMenuDisplaysCustomShortcut() {
        let menu = NSMenu()
        var shortcuts = ShortcutDefaults.all
        shortcuts[.quickCapture] = controlOptionK
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            onQuickCapture: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {},
            shortcuts: shortcuts
        )
        let item = menu.items.first { $0.title == "快速记录…" }
        XCTAssertEqual(item?.keyEquivalent, "k")
        XCTAssertEqual(item?.keyEquivalentModifierMask, [.control, .option])
        let hide = GlanceMenuQuery.item(titled: "隐藏全部", in: menu)
        XCTAssertEqual(hide?.keyEquivalent, "g")
        XCTAssertEqual(hide?.keyEquivalentModifierMask, [.option, .command])
    }

    private func makeStore() -> (ShortcutStore, UserDefaults, String) {
        let name = "GlanceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (ShortcutStore(defaults: defaults), defaults, name)
    }
}

@MainActor
final class ShortcutCoordinatorTests: XCTestCase {
    private let controlOptionK = GlanceShortcut(
        key: "k",
        command: false,
        option: true,
        control: true,
        shift: false
    )

    func testApplyPersistsAndResetRestoresDefaults() throws {
        let (store, defaults, name) = isolatedStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        let coordinator = ShortcutCoordinator(store: store, manager: manager)
        coordinator.start()
        try coordinator.apply(controlOptionK, for: .quickCapture)
        XCTAssertEqual(store.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(coordinator.shortcut(for: .quickCapture), controlOptionK)

        coordinator.resetAll()
        XCTAssertEqual(store.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertEqual(coordinator.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertEqual(manager.registeredShortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
    }

    func testDuplicateAndRegistrationFailureDoNotPersist() throws {
        let (store, defaults, name) = isolatedStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        let coordinator = ShortcutCoordinator(store: store, manager: manager)
        coordinator.start()

        XCTAssertThrowsError(try coordinator.apply(ShortcutDefaults.clipboardCapture, for: .quickCapture)) { error in
            XCTAssertEqual(error as? ShortcutError, .duplicate(.clipboardCapture))
        }
        XCTAssertEqual(store.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)

        fake.failNextRegister = true
        XCTAssertThrowsError(try coordinator.apply(controlOptionK, for: .quickCapture)) { error in
            XCTAssertEqual(error as? ShortcutError, .registrationFailed)
        }
        XCTAssertEqual(store.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertEqual(manager.registeredShortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
    }

    func testStartupRegistrationFailureFallsBackToDefaultWithoutWritingPreference() {
        let (store, defaults, name) = isolatedStore()
        defer { defaults.removePersistentDomain(forName: name) }
        store.setShortcut(controlOptionK, for: .quickCapture)
        let fake = FakeHotKeyRegistrar()
        fake.failNextRegister = true
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        let coordinator = ShortcutCoordinator(store: store, manager: manager)
        coordinator.start()
        XCTAssertEqual(store.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(manager.registeredShortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertEqual(coordinator.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertEqual(
            coordinator.errorMessage,
            "“快速记录”的自定义快捷键无法注册，本次运行暂时使用默认快捷键。"
        )
        XCTAssertEqual(quickCaptureMenuItem(shortcuts: coordinator.shortcuts)?.keyEquivalent, "j")
    }

    func testSuccessfulRecordingActivatesNewShortcutAndClearsSuspension() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        var captures = 0
        harness.manager.onQuickCapture = { captures += 1 }
        harness.coordinator.start()
        harness.coordinator.beginRecording(.quickCapture)
        XCTAssertTrue(harness.manager.isSuspended(.quickCapture))
        harness.manager.handleHotKeyForTesting(.quickCapture)
        XCTAssertEqual(captures, 0)

        harness.coordinator.commitRecording(controlOptionK, for: .quickCapture)

        XCTAssertFalse(harness.manager.isSuspended(.quickCapture))
        XCTAssertEqual(harness.manager.registeredShortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(harness.store.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(harness.coordinator.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(harness.fake.registered[GlanceHotKeyID.quickCapture.rawValue]?.keyCode, UInt32(kVK_ANSI_K))
        harness.manager.handleHotKeyForTesting(.quickCapture)
        XCTAssertEqual(captures, 1)
        XCTAssertEqual(quickCaptureMenuItem(shortcuts: harness.coordinator.shortcuts)?.keyEquivalent, "k")
        XCTAssertEqual(
            quickCaptureMenuItem(shortcuts: harness.coordinator.shortcuts)?.keyEquivalentModifierMask,
            [.control, .option]
        )
    }

    func testCancelRecordingRestoresOldShortcutAndDispatch() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        var captures = 0
        harness.manager.onQuickCapture = { captures += 1 }
        harness.coordinator.start()
        harness.coordinator.beginRecording(.quickCapture)
        harness.coordinator.cancelRecording(.quickCapture)
        XCTAssertFalse(harness.manager.isSuspended(.quickCapture))
        XCTAssertEqual(harness.manager.registeredShortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        harness.manager.handleHotKeyForTesting(.quickCapture)
        XCTAssertEqual(captures, 1)
        XCTAssertEqual(quickCaptureMenuItem(shortcuts: harness.coordinator.shortcuts)?.keyEquivalent, "j")
    }

    func testFailedRecordingRestoresOldShortcutDispatchAndPreference() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        var captures = 0
        harness.manager.onQuickCapture = { captures += 1 }
        harness.coordinator.start()
        harness.coordinator.beginRecording(.quickCapture)
        harness.fake.failNextRegister = true
        harness.coordinator.commitRecording(controlOptionK, for: .quickCapture)
        XCTAssertFalse(harness.manager.isSuspended(.quickCapture))
        XCTAssertEqual(harness.manager.registeredShortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertEqual(harness.store.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertEqual(harness.coordinator.shortcut(for: .quickCapture), ShortcutDefaults.quickCapture)
        XCTAssertNotNil(harness.coordinator.errorMessage)
        harness.manager.handleHotKeyForTesting(.quickCapture)
        XCTAssertEqual(captures, 1)
        XCTAssertEqual(quickCaptureMenuItem(shortcuts: harness.coordinator.shortcuts)?.keyEquivalent, "j")
    }

    func testRejectLeavesSuspensionUntilCancel() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        var captures = 0
        harness.manager.onQuickCapture = { captures += 1 }
        harness.coordinator.start()
        harness.coordinator.beginRecording(.quickCapture)
        XCTAssertTrue(harness.manager.isSuspended(.quickCapture))
        harness.coordinator.cancelRecording(.quickCapture)
        XCTAssertFalse(harness.manager.isSuspended(.quickCapture))
        harness.manager.handleHotKeyForTesting(.quickCapture)
        XCTAssertEqual(captures, 1)
    }

    func testRecordingOneActionThenAnotherDoesNotLeaveStaleSuspension() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        var captures = 0
        var clipboards = 0
        harness.manager.onQuickCapture = { captures += 1 }
        harness.manager.onCaptureClipboard = { clipboards += 1 }
        harness.coordinator.start()
        harness.coordinator.beginRecording(.quickCapture)
        harness.coordinator.beginRecording(.clipboardCapture)
        XCTAssertFalse(harness.manager.isSuspended(.quickCapture))
        XCTAssertTrue(harness.manager.isSuspended(.clipboardCapture))
        harness.manager.handleHotKeyForTesting(.quickCapture)
        XCTAssertEqual(captures, 1)
        harness.manager.handleHotKeyForTesting(.clipboardCapture)
        XCTAssertEqual(clipboards, 0)
        harness.coordinator.cancelRecording(.clipboardCapture)
        XCTAssertFalse(harness.manager.isSuspended(.clipboardCapture))
        harness.manager.handleHotKeyForTesting(.clipboardCapture)
        XCTAssertEqual(clipboards, 1)
    }

    func testFinishAndResumeAreIdempotent() throws {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.coordinator.start()
        let registers = harness.fake.registerCount
        harness.manager.finishSuspension(.quickCapture)
        harness.manager.finishSuspension(.quickCapture)
        try harness.manager.resume(.quickCapture)
        XCTAssertEqual(harness.fake.registerCount, registers)
        XCTAssertFalse(harness.manager.isSuspended(.quickCapture))
    }

    func testStartupPreferredSuccessAlignsStoreManagerCoordinatorAndMenu() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.store.setShortcut(controlOptionK, for: .quickCapture)
        harness.coordinator.start()
        XCTAssertEqual(harness.store.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(harness.manager.registeredShortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(harness.coordinator.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertNil(harness.coordinator.errorMessage)
        let item = quickCaptureMenuItem(shortcuts: harness.coordinator.shortcuts)
        XCTAssertEqual(item?.keyEquivalent, "k")
        XCTAssertEqual(item?.keyEquivalentModifierMask, [.control, .option])
    }

    func testStartupPreferredAndDefaultBothFailIsNonFatal() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.store.setShortcut(controlOptionK, for: .quickCapture)
        harness.fake.failingIDs = [GlanceHotKeyID.quickCapture.rawValue]
        harness.coordinator.start()
        XCTAssertEqual(harness.store.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertNil(harness.manager.registeredShortcut(for: .quickCapture))
        XCTAssertEqual(harness.coordinator.shortcut(for: .quickCapture), controlOptionK)
        XCTAssertEqual(harness.coordinator.errorMessage, "“快速记录”的快捷键当前未能注册。")
        let item = quickCaptureMenuItem(shortcuts: harness.coordinator.shortcuts)
        XCTAssertEqual(item?.title, "快速记录…")
        XCTAssertEqual(item?.isEnabled, true)
        XCTAssertEqual(item?.keyEquivalent, "k")
    }

    private func makeHarness() -> (
        store: ShortcutStore,
        defaults: UserDefaults,
        name: String,
        fake: FakeHotKeyRegistrar,
        manager: ShortcutManager,
        coordinator: ShortcutCoordinator
    ) {
        let (store, defaults, name) = isolatedStore()
        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        let coordinator = ShortcutCoordinator(store: store, manager: manager)
        return (store, defaults, name, fake, manager, coordinator)
    }

    private func isolatedStore() -> (ShortcutStore, UserDefaults, String) {
        let name = "GlanceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (ShortcutStore(defaults: defaults), defaults, name)
    }

    private func quickCaptureMenuItem(shortcuts: [ShortcutAction: GlanceShortcut]) -> NSMenuItem? {
        let menu = NSMenu()
        StatusMenuBuilder.populate(
            menu,
            allHidden: false,
            onQuickCapture: {},
            onManagePanels: {},
            onNewText: {},
            onNewMarkdown: {},
            onNewTodo: {},
            onNewImage: {},
            onToggleVisibility: {},
            onSettings: {},
            onQuit: {},
            shortcuts: shortcuts
        )
        return menu.items.first { $0.title == "快速记录…" }
    }
}
