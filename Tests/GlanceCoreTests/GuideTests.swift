import AppKit
import XCTest

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

@MainActor
final class OnboardingStateTests: XCTestCase {
    func testFreshInstallShouldPresent() throws {
        try withIsolatedDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            XCTAssertTrue(state.shouldPresent)
            XCTAssertFalse(defaults.bool(forKey: OnboardingState.completedKey))
        }
    }

    func testCompletedStateDoesNotPresent() throws {
        try withIsolatedDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            state.markCompleted()
            XCTAssertFalse(state.shouldPresent)
            XCTAssertTrue(defaults.bool(forKey: OnboardingState.completedKey))
        }
    }

    func testMarkCompletedPersistsForNewReader() throws {
        try withIsolatedDefaults { defaults in
            OnboardingState(defaults: defaults).markCompleted()
            let reread = OnboardingState(defaults: defaults)
            XCTAssertFalse(reread.shouldPresent)
        }
    }

    func testOnboardingLivesInUserDefaultsNotPersistence() {
        XCTAssertEqual(OnboardingState.completedKey, "com.glance.onboarding.completed")
        XCTAssertEqual(PanelDatabase.currentSchemaVersion, 5)
    }
}

@MainActor
final class GuideTests: XCTestCase {
    private let controlOptionK = GlanceShortcut(
        key: "k",
        command: false,
        option: true,
        control: true,
        shift: false
    )

    func testGuideSectionsExist() {
        XCTAssertEqual(
            GuideSection.allCases.map(\.title),
            ["开始使用", "快捷键与操作", "更多功能"]
        )
    }

    func testGuideNavigationSwitchesSections() throws {
        try withIsolatedDefaults { defaults in
            let model = GuideModel(onboardingState: OnboardingState(defaults: defaults))
            XCTAssertEqual(model.section, .gettingStarted)
            model.present(section: .shortcuts, onboarding: false)
            XCTAssertEqual(model.section, .shortcuts)
            model.present(section: .features, onboarding: false)
            XCTAssertEqual(model.section, .features)
            model.present(section: .gettingStarted, onboarding: false)
            XCTAssertEqual(model.section, .gettingStarted)
        }
    }

    func testSkipMarksOnboardingCompleteAndDismisses() throws {
        try withIsolatedDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            let model = GuideModel(onboardingState: state, isOnboarding: true)
            var dismissed = false
            model.onDismiss = { dismissed = true }
            model.skipOnboarding()
            XCTAssertTrue(dismissed)
            XCTAssertFalse(state.shouldPresent)
            XCTAssertFalse(model.isOnboarding)
        }
    }

    func testFinishMarksOnboardingComplete() throws {
        try withIsolatedDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            let model = GuideModel(onboardingState: state, isOnboarding: true)
            model.onboardingStep = GuideModel.onboardingPageCount - 1
            model.advanceOnboarding()
            XCTAssertFalse(state.shouldPresent)
            XCTAssertFalse(model.isOnboarding)
        }
    }

    func testCloseDuringOnboardingMarksComplete() throws {
        try withIsolatedDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            let model = GuideModel(onboardingState: state, isOnboarding: true)
            model.completeOnboardingIfNeeded()
            XCTAssertFalse(state.shouldPresent)
            XCTAssertFalse(model.isOnboarding)
        }
    }

    func testManualGuideOpenDoesNotRequireIncompleteOnboarding() throws {
        try withIsolatedDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            state.markCompleted()
            let model = GuideModel(onboardingState: state)
            model.present(section: .gettingStarted, onboarding: false)
            XCTAssertFalse(model.isOnboarding)
            XCTAssertEqual(model.section, .gettingStarted)
            XCTAssertFalse(state.shouldPresent)
        }
    }

    func testGlobalShortcutsUseProviderNotHardCodedDefaults() {
        let provider: (ShortcutAction) -> GlanceShortcut = { action in
            action == .quickCapture ? self.controlOptionK : ShortcutDefaults.shortcut(for: action)
        }
        let item = GuideShortcutCatalog.global.first { $0.id == "quickCapture" }
        XCTAssertEqual(item?.tokens(using: provider).map(\.display), ["⌃", "⌥", "K"])
        XCTAssertNotEqual(
            item?.tokens(using: provider).map(\.display).joined(),
            ShortcutDisplayFormatter.display(ShortcutDefaults.quickCapture)
        )
        if case .dynamic(let action) = item?.source {
            XCTAssertEqual(action, .quickCapture)
        } else {
            XCTFail("Quick Capture must read the live shortcut")
        }
    }

    func testCatalogLocksPanelAndQuickCaptureOperations() {
        let provider = ShortcutDefaults.shortcut(for:)
        let option = GuideShortcutCatalog.item(id: "optionPassThrough")
        let control = GuideShortcutCatalog.item(id: "controlSnapBypass")
        let newline = GuideShortcutCatalog.item(id: "qcNewline")
        XCTAssertEqual(option?.tokens(using: provider).map(\.spoken), ["Option"])
        XCTAssertTrue(option?.detail?.contains("仅在开启点击穿透时生效") == true)
        XCTAssertEqual(control?.tokens(using: provider).map(\.spoken), ["Control"])
        XCTAssertTrue(control?.detail?.contains("暂时关闭边缘吸附") == true)
        XCTAssertEqual(
            GuideShortcutCatalog.item(id: "qcText")?.tokens(using: provider).map(\.display),
            ["⌘", "1"]
        )
        XCTAssertEqual(
            GuideShortcutCatalog.item(id: "qcTodo")?.tokens(using: provider).map(\.display),
            ["⌘", "2"]
        )
        XCTAssertEqual(
            GuideShortcutCatalog.item(id: "qcCreate")?.tokens(using: provider).map(\.display),
            ["↩"]
        )
        XCTAssertEqual(newline?.tokens(using: provider).map(\.display), ["⇧", "↩"])
        XCTAssertEqual(newline?.detail, "文字模式下换行")
        XCTAssertEqual(GuideShortcutCatalog.item(id: "qcCancel")?.title, "取消 Quick Capture")
        XCTAssertEqual(
            GuideShortcutCatalog.item(id: "qcCancel")?.tokens(using: provider).map(\.display),
            ["Esc"]
        )
        XCTAssertEqual(
            GuideShortcutCatalog.item(id: "bold")?.tokens(using: provider).map(\.display),
            ["⌘", "B"]
        )
    }

    func testCatalogDescribesDoubleClickEditingAccurately() {
        let provider = ShortcutDefaults.shortcut(for:)
        let textMarkdown = GuideShortcutCatalog.item(id: "editTextMarkdown")
        let todo = GuideShortcutCatalog.item(id: "editTodo")
        XCTAssertEqual(textMarkdown?.title, "编辑文字 / Markdown")
        XCTAssertEqual(textMarkdown?.tokens(using: provider).map(\.display), ["双击内容"])
        XCTAssertEqual(todo?.title, "编辑待办")
        XCTAssertEqual(todo?.tokens(using: provider).map(\.display), ["双击待办项"])
        XCTAssertEqual(GuideShortcutCatalog.groups.first { $0.id == "panel" }?.title, "面板操作")
    }

    func testCatalogIncludesMarkdownEditingExit() {
        let item = GuideShortcutCatalog.item(id: "markdownEndEditing")
        XCTAssertEqual(item?.title, "结束 Markdown 编辑")
        XCTAssertNil(item?.detail)
        XCTAssertEqual(
            item?.tokens(using: ShortcutDefaults.shortcut(for:)).map(\.display),
            ["Esc"]
        )
        XCTAssertEqual(
            item?.accessibilityLabel(using: ShortcutDefaults.shortcut(for:)),
            "结束 Markdown 编辑，快捷键 Escape"
        )
    }

    func testCatalogIncludesTodoEditingCommands() {
        let provider = ShortcutDefaults.shortcut(for:)
        let commit = GuideShortcutCatalog.item(id: "todoCommit")
        let cancel = GuideShortcutCatalog.item(id: "todoCancel")
        XCTAssertEqual(commit?.title, "保存待办 / 继续添加")
        XCTAssertEqual(commit?.detail, "新增待办时，保存后继续创建下一项")
        XCTAssertEqual(commit?.tokens(using: provider).map(\.display), ["↩"])
        XCTAssertEqual(cancel?.title, "取消待办编辑")
        XCTAssertEqual(cancel?.detail, "恢复编辑前的内容")
        XCTAssertEqual(cancel?.tokens(using: provider).map(\.display), ["Esc"])
        XCTAssertEqual(
            cancel?.accessibilityLabel(using: provider),
            "取消待办编辑，恢复编辑前的内容，快捷键 Escape"
        )
    }

    func testCatalogIncludesTextEditingExitAndChecklistToggle() {
        let provider = ShortcutDefaults.shortcut(for:)
        let textEsc = GuideShortcutCatalog.item(id: "textEndEditing")
        let checklist = GuideShortcutCatalog.item(id: "textChecklistToggle")
        XCTAssertEqual(textEsc?.title, "结束文字编辑")
        XCTAssertEqual(textEsc?.tokens(using: provider).map(\.display), ["Esc"])
        XCTAssertEqual(checklist?.title, "切换文字清单")
        XCTAssertEqual(checklist?.detail, "阅读模式下点击清单符号")
        XCTAssertEqual(checklist?.tokens(using: provider).map(\.display), ["单击清单符号"])
        XCTAssertEqual(GuideShortcutCatalog.groups.first { $0.id == "editing" }?.title, "编辑")
        XCTAssertEqual(
            GuideShortcutCatalog.groups.first { $0.id == "editing" }?.items.map(\.id),
            ["bold", "textEndEditing", "markdownEndEditing", "todoCommit", "todoCancel"]
        )
    }

    func testShortcutRowAccessibilityGroupsKeycaps() {
        let label = GuideShortcutCatalog.global[0].accessibilityLabel { _ in ShortcutDefaults.quickCapture }
        XCTAssertEqual(label, "快速记录，快捷键 Option Command J")
        let option = GuideShortcutCatalog.panel.first { $0.id == "optionPassThrough" }?
            .accessibilityLabel(using: ShortcutDefaults.shortcut(for:))
        XCTAssertTrue(option?.contains("临时操作穿透面板") == true)
        XCTAssertTrue(option?.contains("Option") == true)
        XCTAssertFalse(option?.contains("⌥") == true)
    }

    func testFormatterTokensMatchGuideKeycaps() {
        XCTAssertEqual(ShortcutDisplayFormatter.tokens(controlOptionK), ["⌃", "⌥", "K"])
        XCTAssertEqual(ShortcutDisplayFormatter.spoken(controlOptionK), "Control Option K")
        XCTAssertEqual(
            GuideKeycap.tokens(from: controlOptionK).map(\.display),
            ShortcutDisplayFormatter.tokens(controlOptionK)
        )
    }

    func testStatusMenuIncludesGuideAboveSettings() {
        let menu = NSMenu()
        var opened = false
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
            onOpenGuide: { opened = true },
            onQuit: {}
        )
        let guide = menu.items.first { $0.title == GlanceGuideEntry.menuTitle }
        let settings = menu.items.first { $0.title == "设置…" }
        XCTAssertNotNil(guide)
        XCTAssertNotNil(settings)
        XCTAssertLessThan(
            menu.items.firstIndex(where: { $0.title == GlanceGuideEntry.menuTitle }) ?? .max,
            menu.items.firstIndex(where: { $0.title == "设置…" }) ?? .min
        )
        XCTAssertEqual(menu.items.last?.title, "退出")
        invoke(guide)
        XCTAssertTrue(opened)
    }

    func testGuideWindowIsSingletonAndNormalLevel() throws {
        try withIsolatedDefaults { defaults in
            let controller = makeGuideController(defaults: defaults)
            defer { controller.window?.close() }
            controller.present(onboarding: true)
            let window = try XCTUnwrap(controller.window)
            XCTAssertTrue(controller.isPresentingOnboarding)
            XCTAssertEqual(window.level, .normal)
            XCTAssertEqual(window.title, GlanceGuideEntry.windowTitle)
            let identifier = ObjectIdentifier(window)
            controller.present()
            controller.present(section: .shortcuts)
            XCTAssertTrue(controller.isPresentingOnboarding)
            XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(controller.window)), identifier)
        }
    }

    func testClosingOnboardingWindowMarksComplete() throws {
        try withIsolatedDefaults { defaults in
            let state = OnboardingState(defaults: defaults)
            let controller = makeGuideController(defaults: defaults, state: state)
            controller.present(onboarding: true)
            XCTAssertTrue(state.shouldPresent)
            controller.window?.close()
            XCTAssertFalse(state.shouldPresent)
            controller.present(section: .shortcuts)
            XCTAssertEqual(controller.presentedSection, .shortcuts)
            XCTAssertFalse(controller.isPresentingOnboarding)
            let window = try XCTUnwrap(controller.window)
            controller.present(section: .features)
            XCTAssertEqual(ObjectIdentifier(try XCTUnwrap(controller.window)), ObjectIdentifier(window))
            controller.window?.close()
        }
    }

    func testSettingsCallbackOpensGuideShortcuts() throws {
        try withIsolatedDefaults { defaults in
            let controller = makeGuideController(defaults: defaults)
            defer { controller.window?.close() }
            OnboardingState(defaults: defaults).markCompleted()
            var openedShortcuts = false
            let onOpenGuideShortcuts = {
                openedShortcuts = true
                controller.present(section: .shortcuts)
            }
            XCTAssertEqual(GlanceGuideEntry.settingsLinkTitle, "查看所有快捷键与操作…")
            onOpenGuideShortcuts()
            XCTAssertTrue(openedShortcuts)
            XCTAssertEqual(controller.presentedSection, .shortcuts)
        }
    }

    private func makeGuideController(
        defaults: UserDefaults,
        state: OnboardingState? = nil
    ) -> GuideWindowController {
        let store = ShortcutStore(defaults: defaults)
        let coordinator = ShortcutCoordinator(store: store, manager: ShortcutManager())
        return GuideWindowController(
            coordinator: coordinator,
            onboardingState: state ?? OnboardingState(defaults: defaults)
        )
    }
}

private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let name = "com.glance.tests.onboarding.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    defer { defaults.removePersistentDomain(forName: name) }
    try body(defaults)
}

private func invoke(_ item: NSMenuItem?) {
    guard let item, let action = item.action else {
        XCTFail("Missing menu action")
        return
    }
    _ = item.target?.perform(action, with: item)
}
