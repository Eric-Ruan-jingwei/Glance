import AppKit
import SwiftUI

@MainActor
final class GuideWindowController: NSWindowController, NSWindowDelegate {
    private let model: GuideModel

    convenience init(
        coordinator: ShortcutCoordinator,
        onboardingState: OnboardingState = OnboardingState(),
        onOpenSettings: @escaping () -> Void = {}
    ) {
        let model = GuideModel(onboardingState: onboardingState)
        model.onOpenSettings = onOpenSettings
        let hosting = NSHostingController(
            rootView: GuideView(model: model, shortcuts: coordinator)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = GlanceGuideEntry.windowTitle
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 520))
        window.minSize = NSSize(width: 620, height: 440)
        window.backgroundColor = .windowBackgroundColor
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
        self.init(existingWindow: window, model: model)
        model.onDismiss = { [weak self] in
            self?.window?.close()
        }
        window.delegate = self
    }

    private init(existingWindow: NSWindow, model: GuideModel) {
        self.model = model
        super.init(window: existingWindow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var presentedSection: GuideSection {
        model.section
    }

    var isPresentingOnboarding: Bool {
        model.isOnboarding
    }

    func present(section: GuideSection? = nil, onboarding: Bool = false) {
        if window?.isVisible == true, model.isOnboarding, !onboarding {
            NSApp.activate(ignoringOtherApps: true)
            showWindow(nil)
            window?.makeKeyAndOrderFront(nil)
            return
        }
        model.present(section: section, onboarding: onboarding)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.completeOnboardingIfNeeded()
    }
}
