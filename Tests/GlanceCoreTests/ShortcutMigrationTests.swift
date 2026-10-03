import AppKit
import Carbon
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class ShortcutMigrationTests: XCTestCase {
    private let optionCommandK = ShortcutDefaults.globalSearch
    private let controlOptionK = GlanceShortcut(
        key: "k",
        command: false,
        option: true,
        control: true,
        shift: false
    )
    private let controlOptionJ = GlanceShortcut(
        key: "j",
        command: false,
        option: true,
        control: true,
        shift: false
    )
    private let controlOptionQ = GlanceShortcut(
        key: "q",
        command: false,
        option: true,
        control: true,
        shift: false
    )

    func testExplicitDefaultCollisionLeavesSearchInactiveWithoutWritingPreference() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.store.setShortcut(optionCommandK, for: .quickCapture)
        let before = preferenceSnapshot(harness.defaults)

        harness.coordinator.start()

        XCTAssertEqual(harness.coordinator.configuredShortcut(for: .quickCapture), optionCommandK)
        XCTAssertEqual(harness.coordinator.activeShortcut(for: .quickCapture), optionCommandK)
        XCTAssertEqual(harness.coordinator.configuredShortcut(for: .globalSearch), optionCommandK)
        XCTAssertNil(harness.coordinator.activeShortcut(for: .globalSearch))
        XCTAssertEqual(
            harness.coordinator.runtimeIssue(for: .globalSearch),
            .conflictsWithExplicit(.quickCapture)
        )
        XCTAssertEqual(
            harness.coordinator.errorMessage,
            "“搜索 Glance”的默认快捷键与“快速记录”的已有快捷键冲突，当前未生效。可在设置中重新指定。"
        )
        XCTAssertEqual(
            harness.coordinator.runtimeIssue(for: .globalSearch)?.settingsCaption,
            "⚠ 与“快速记录”的快捷键冲突，当前未生效"
        )
        XCTAssertEqual(preferenceSnapshot(harness.defaults) as NSDictionary, before as NSDictionary)
        XCTAssertNotNil(harness.defaults.object(forKey: ShortcutAction.quickCapture.preferenceKey))
        XCTAssertNil(harness.defaults.object(forKey: ShortcutAction.globalSearch.preferenceKey))
        XCTAssertNil(harness.coordinator.shortcuts[.globalSearch])
    }

    func testUpgradeCollisionMenuOmitsInactiveSearchKeyEquivalent() {
        let harness = collisionHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        let menu = populatedMenu(shortcuts: harness.coordinator.shortcuts)
        let capture = menu.items.first { $0.title == "快速记录…" }
        let search = menu.items.first { $0.title == "搜索 Glance…" }
        XCTAssertEqual(capture?.keyEquivalent, "k")
        XCTAssertEqual(capture?.keyEquivalentModifierMask, [.option, .command])
        XCTAssertEqual(search?.keyEquivalent, "")
        XCTAssertEqual(search?.isEnabled, true)
    }

    func testUpgradeCollisionGuideShowsSearchInactive() {
        let harness = collisionHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        let resolution = guideResolution(harness.coordinator)
        let search = GuideShortcutCatalog.item(id: "globalSearch")
        let capture = GuideShortcutCatalog.item(id: "quickCapture")
        XCTAssertEqual(search?.tokens(resolvedBy: resolution).map(\.display), ["未生效"])
        XCTAssertEqual(search?.resolvedDetail(resolvedBy: resolution), GuideShortcutItem.inactiveShortcutDetail)
        XCTAssertEqual(
            capture?.tokens(resolvedBy: resolution).map(\.display),
            ["⌥", "⌘", "K"]
        )
    }

    func testUpgradeCollisionSettingsKeepsConfiguredSearchAndConflictIssue() {
        let harness = collisionHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        XCTAssertEqual(harness.coordinator.configuredShortcut(for: .globalSearch), optionCommandK)
        XCTAssertNil(harness.coordinator.activeShortcut(for: .globalSearch))
        XCTAssertEqual(
            harness.coordinator.runtimeIssue(for: .globalSearch),
            .conflictsWithExplicit(.quickCapture)
        )
        XCTAssertTrue(
            harness.coordinator.runtimeIssue(for: .globalSearch)?.settingsCaption.contains("快速记录") == true
        )
    }

    func testUserCanBindInactiveSearchWithoutRestart() throws {
        let harness = collisionHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        try harness.coordinator.apply(controlOptionK, for: .globalSearch)

        XCTAssertEqual(harness.store.explicitShortcut(for: .globalSearch), controlOptionK)
        XCTAssertEqual(harness.coordinator.activeShortcut(for: .globalSearch), controlOptionK)
        XCTAssertEqual(harness.coordinator.activeShortcut(for: .quickCapture), optionCommandK)
        XCTAssertNil(harness.coordinator.runtimeIssue(for: .globalSearch))
        let menu = populatedMenu(shortcuts: harness.coordinator.shortcuts)
        let search = menu.items.first { $0.title == "搜索 Glance…" }
        XCTAssertEqual(search?.keyEquivalent, "k")
        XCTAssertEqual(search?.keyEquivalentModifierMask, [.control, .option])
        let resolution = guideResolution(harness.coordinator)
        XCTAssertEqual(
            GuideShortcutCatalog.item(id: "globalSearch")?.tokens(resolvedBy: resolution).map(\.display),
            ["⌃", "⌥", "K"]
        )
    }

    func testMovingOldActionReactivatesImplicitSearchDefaultWithoutWritingPreference() throws {
        let harness = collisionHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        try harness.coordinator.apply(controlOptionJ, for: .quickCapture)

        XCTAssertEqual(harness.coordinator.activeShortcut(for: .quickCapture), controlOptionJ)
        XCTAssertEqual(harness.coordinator.activeShortcut(for: .globalSearch), optionCommandK)
        XCTAssertNil(harness.store.explicitShortcut(for: .globalSearch))
        XCTAssertNil(harness.defaults.object(forKey: ShortcutAction.globalSearch.preferenceKey))
        XCTAssertNil(harness.coordinator.runtimeIssue(for: .globalSearch))
    }

    func testExplicitWinsIndependentOfPlannerOrder() {
        let explicit: [ShortcutAction: GlanceShortcut] = [.quickCapture: optionCommandK]
        let forward = ShortcutRegistrationPlanner.plan(
            explicit: explicit,
            order: Array(ShortcutAction.allCases)
        )
        let reversed = ShortcutRegistrationPlanner.plan(
            explicit: explicit,
            order: Array(ShortcutAction.allCases.reversed())
        )
        XCTAssertEqual(forward.explicitOwners[.quickCapture], optionCommandK)
        XCTAssertEqual(reversed.explicitOwners[.quickCapture], optionCommandK)
        XCTAssertEqual(forward.implicitConflicts[.globalSearch], .quickCapture)
        XCTAssertEqual(reversed.implicitConflicts[.globalSearch], .quickCapture)
        XCTAssertNil(forward.implicitAttempts[.globalSearch])
        XCTAssertNil(reversed.implicitAttempts[.globalSearch])
        XCTAssertNil(forward.explicitOwners[.globalSearch])
        XCTAssertNil(reversed.explicitOwners[.globalSearch])
    }

    func testExplicitReservationSurvivesCarbonRegistrationFailure() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.store.setShortcut(optionCommandK, for: .quickCapture)
        harness.fake.failingIDs = [GlanceHotKeyID.quickCapture.rawValue]
        harness.coordinator.start()

        XCTAssertNil(harness.coordinator.activeShortcut(for: .quickCapture))
        XCTAssertNil(harness.coordinator.activeShortcut(for: .globalSearch))
        XCTAssertEqual(
            harness.coordinator.runtimeIssue(for: .globalSearch),
            .conflictsWithExplicit(.quickCapture)
        )
        XCTAssertNil(harness.fake.registered[GlanceHotKeyID.globalSearch.rawValue])
        XCTAssertNil(harness.defaults.object(forKey: ShortcutAction.globalSearch.preferenceKey))
    }

    func testCustomFallbackRespectsOtherExplicitReservations() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.store.setShortcut(controlOptionQ, for: .quickCapture)
        harness.store.setShortcut(ShortcutDefaults.quickCapture, for: .links)
        harness.fake.failingIDs = [GlanceHotKeyID.quickCapture.rawValue]
        harness.coordinator.start()

        XCTAssertNil(harness.coordinator.activeShortcut(for: .quickCapture))
        XCTAssertEqual(harness.coordinator.activeShortcut(for: .links), ShortcutDefaults.quickCapture)
        XCTAssertEqual(
            harness.coordinator.runtimeIssue(for: .quickCapture),
            .conflictsWithExplicit(.links)
        )
        XCTAssertEqual(harness.store.explicitShortcut(for: .quickCapture), controlOptionQ)
        XCTAssertEqual(harness.store.explicitShortcut(for: .links), ShortcutDefaults.quickCapture)
    }

    func testDuplicateExplicitLegacyStateKeepsBothPreferences() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.store.setShortcut(optionCommandK, for: .quickCapture)
        harness.store.setShortcut(optionCommandK, for: .links)
        let before = preferenceSnapshot(harness.defaults)
        harness.coordinator.start()

        XCTAssertEqual(harness.coordinator.activeShortcut(for: .quickCapture), optionCommandK)
        XCTAssertNil(harness.coordinator.activeShortcut(for: .links))
        XCTAssertEqual(
            harness.coordinator.runtimeIssue(for: .links),
            .conflictsWithExplicit(.quickCapture)
        )
        XCTAssertEqual(preferenceSnapshot(harness.defaults) as NSDictionary, before as NSDictionary)
        XCTAssertEqual(harness.store.explicitShortcut(for: .quickCapture), optionCommandK)
        XCTAssertEqual(harness.store.explicitShortcut(for: .links), optionCommandK)
    }

    func testActiveMapOmitsUnregisteredActions() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.fake.failingIDs = [GlanceHotKeyID.globalSearch.rawValue]
        harness.coordinator.start()

        XCTAssertNil(harness.coordinator.shortcuts[.globalSearch])
        XCTAssertNil(harness.coordinator.activeShortcut(for: .globalSearch))
        XCTAssertEqual(harness.coordinator.configuredShortcut(for: .globalSearch), optionCommandK)
        XCTAssertEqual(harness.coordinator.runtimeIssue(for: .globalSearch), .registrationFailed)
        let search = populatedMenu(shortcuts: harness.coordinator.shortcuts)
            .items.first { $0.title == "搜索 Glance…" }
        XCTAssertEqual(search?.keyEquivalent, "")
        XCTAssertEqual(search?.isEnabled, true)
        let resolution = guideResolution(harness.coordinator)
        XCTAssertEqual(
            GuideShortcutCatalog.item(id: "globalSearch")?.tokens(resolvedBy: resolution).map(\.display),
            ["未生效"]
        )
    }

    func testCleanInstallRegistersEveryDefaultShortcut() {
        let harness = makeHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        harness.coordinator.start()
        for action in ShortcutAction.allCases {
            XCTAssertEqual(
                harness.coordinator.activeShortcut(for: action),
                ShortcutDefaults.shortcut(for: action),
                action.rawValue
            )
            XCTAssertNil(harness.store.explicitShortcut(for: action), action.rawValue)
            XCTAssertNil(harness.coordinator.runtimeIssue(for: action), action.rawValue)
        }
        XCTAssertEqual(GlanceHotKeyID.globalSearch.rawValue, 8)
        XCTAssertEqual(ShortcutDisplayFormatter.display(ShortcutDefaults.globalSearch), "⌥⌘K")
    }

    func testExistingCustomValuesDoNotConflictWithNewDefault() {
        let (store, defaults, name) = isolatedStore()
        defer { defaults.removePersistentDomain(forName: name) }
        store.setShortcut(controlOptionJ, for: .quickCapture)
        XCTAssertEqual(store.shortcut(for: .quickCapture), controlOptionJ)
        XCTAssertEqual(store.shortcut(for: .globalSearch), optionCommandK)
        XCTAssertNil(store.explicitShortcut(for: .globalSearch))

        let fake = FakeHotKeyRegistrar()
        let manager = ShortcutManager(registrar: fake, bindSystemHandler: false)
        let coordinator = ShortcutCoordinator(store: store, manager: manager)
        coordinator.start()
        XCTAssertEqual(coordinator.activeShortcut(for: .quickCapture), controlOptionJ)
        XCTAssertEqual(coordinator.activeShortcut(for: .globalSearch), optionCommandK)
    }

    func testCollisionStateSurvivesRestartWithoutPreferenceMutation() {
        let (store, defaults, name) = isolatedStore()
        defer { defaults.removePersistentDomain(forName: name) }
        store.setShortcut(optionCommandK, for: .quickCapture)
        let first = ShortcutCoordinator(
            store: store,
            manager: ShortcutManager(registrar: FakeHotKeyRegistrar(), bindSystemHandler: false)
        )
        first.start()
        let afterFirst = preferenceSnapshot(defaults)

        let second = ShortcutCoordinator(
            store: store,
            manager: ShortcutManager(registrar: FakeHotKeyRegistrar(), bindSystemHandler: false)
        )
        second.start()
        XCTAssertEqual(second.activeShortcut(for: .quickCapture), optionCommandK)
        XCTAssertNil(second.activeShortcut(for: .globalSearch))
        XCTAssertEqual(second.runtimeIssue(for: .globalSearch), .conflictsWithExplicit(.quickCapture))
        XCTAssertEqual(preferenceSnapshot(defaults) as NSDictionary, afterFirst as NSDictionary)
        XCTAssertNil(defaults.object(forKey: ShortcutAction.globalSearch.preferenceKey))
    }

    func testResolvedSearchShortcutSurvivesRestart() throws {
        let (store, defaults, name) = isolatedStore()
        defer { defaults.removePersistentDomain(forName: name) }
        store.setShortcut(optionCommandK, for: .quickCapture)
        let firstManager = ShortcutManager(registrar: FakeHotKeyRegistrar(), bindSystemHandler: false)
        let first = ShortcutCoordinator(store: store, manager: firstManager)
        first.start()
        try first.apply(controlOptionK, for: .globalSearch)

        let second = ShortcutCoordinator(
            store: store,
            manager: ShortcutManager(registrar: FakeHotKeyRegistrar(), bindSystemHandler: false)
        )
        second.start()
        XCTAssertEqual(second.configuredShortcut(for: .globalSearch), controlOptionK)
        XCTAssertEqual(second.activeShortcut(for: .globalSearch), controlOptionK)
        XCTAssertEqual(second.activeShortcut(for: .quickCapture), optionCommandK)
        XCTAssertNil(second.runtimeIssue(for: .globalSearch))
    }

    func testAssigningConflictingSearchShortcutIsRejectedImmediately() {
        let harness = collisionHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.name) }
        XCTAssertThrowsError(try harness.coordinator.apply(optionCommandK, for: .globalSearch)) { error in
            XCTAssertEqual(error as? ShortcutError, .duplicate(.quickCapture))
        }
        XCTAssertNil(harness.store.explicitShortcut(for: .globalSearch))
        XCTAssertNil(harness.coordinator.activeShortcut(for: .globalSearch))
    }

    func testSchemaVersionsStayUnchangedByShortcutMigration() {
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
        XCTAssertEqual(ClipboardHistoryDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(FileShelfDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(SnippetDatabase.currentSchemaVersion, 1)
        XCTAssertEqual(LinkDatabase.currentSchemaVersion, 1)
    }

    private func collisionHarness() -> (
        store: ShortcutStore,
        defaults: UserDefaults,
        name: String,
        fake: FakeHotKeyRegistrar,
        manager: ShortcutManager,
        coordinator: ShortcutCoordinator
    ) {
        let harness = makeHarness()
        harness.store.setShortcut(optionCommandK, for: .quickCapture)
        harness.coordinator.start()
        return harness
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

    private func preferenceSnapshot(_ defaults: UserDefaults) -> [String: Any] {
        var snapshot: [String: Any] = [:]
        for action in ShortcutAction.allCases {
            if let value = defaults.object(forKey: action.preferenceKey) {
                snapshot[action.preferenceKey] = value
            }
        }
        return snapshot
    }

    private func populatedMenu(shortcuts: [ShortcutAction: GlanceShortcut]) -> NSMenu {
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
        return menu
    }

    private func guideResolution(_ coordinator: ShortcutCoordinator) -> (ShortcutAction) -> GuideShortcutResolution {
        { action in
            if let active = coordinator.activeShortcut(for: action) {
                return .active(active)
            }
            return .inactive
        }
    }
}
