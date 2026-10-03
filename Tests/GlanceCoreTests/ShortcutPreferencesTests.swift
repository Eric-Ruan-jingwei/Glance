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
        XCTAssertEqual(ShortcutDefaults.clipboardCapture, GlanceShortcut(key: "b", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDefaults.hideShow, GlanceShortcut(key: "g", command: true, option: true, control: false, shift: false))
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.quickCapture), "⌥⌘J")
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.clipboardCapture), "⌥⌘B")
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.hideShow), "⌥⌘G")
        XCTAssertEqual(GlanceConstants.quickCaptureShortcutDisplay, "⌥⌘J")
        XCTAssertEqual(GlanceConstants.clipboardCaptureShortcutDisplay, "⌥⌘B")
        XCTAssertEqual(GlanceConstants.hideShowShortcutDisplay, "⌥⌘G")
        XCTAssertEqual(ShortcutAction.quickCapture.preferenceKey, "com.glance.shortcut.quickCapture")
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
        let hide = menu.items.first { $0.title == "隐藏全部" }
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
    }

    private func isolatedStore() -> (ShortcutStore, UserDefaults, String) {
        let name = "GlanceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (ShortcutStore(defaults: defaults), defaults, name)
    }
}
