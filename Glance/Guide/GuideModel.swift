import Combine
import Foundation

enum GuideSection: String, CaseIterable, Identifiable, Hashable {
    case gettingStarted
    case shortcuts
    case features

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted: return "开始使用"
        case .shortcuts: return "快捷键与操作"
        case .features: return "更多功能"
        }
    }

    var symbol: String {
        switch self {
        case .gettingStarted: return "flag"
        case .shortcuts: return "keyboard"
        case .features: return "square.stack"
        }
    }
}

enum GlanceGuideEntry {
    static let menuTitle = "使用指南…"
    static let settingsLinkTitle = "查看所有快捷键与操作…"
    static let windowTitle = "使用指南"
    static let finishTitle = "开始使用 Glance"
    static let skipTitle = "跳过"
    static let continueTitle = "继续"
    static let backTitle = "返回"
    static let openSettingsTitle = "修改全局快捷键…"
}

@MainActor
final class GuideModel: ObservableObject {
    static let onboardingPageCount = 4

    @Published var section: GuideSection
    @Published var isOnboarding: Bool
    @Published var onboardingStep: Int

    let onboardingState: OnboardingState
    var onDismiss: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    init(
        onboardingState: OnboardingState = OnboardingState(),
        section: GuideSection = .gettingStarted,
        isOnboarding: Bool = false
    ) {
        self.onboardingState = onboardingState
        self.section = section
        self.isOnboarding = isOnboarding
        self.onboardingStep = 0
    }

    var isLastOnboardingPage: Bool {
        onboardingStep >= Self.onboardingPageCount - 1
    }

    var onboardingPageLabel: String {
        "\(onboardingStep + 1) / \(Self.onboardingPageCount)"
    }

    func present(section: GuideSection?, onboarding: Bool) {
        isOnboarding = onboarding
        onboardingStep = 0
        self.section = section ?? (onboarding ? .gettingStarted : self.section)
        if onboarding {
            self.section = .gettingStarted
        }
    }

    func advanceOnboarding() {
        guard isOnboarding else { return }
        if isLastOnboardingPage {
            finishOnboarding()
            return
        }
        onboardingStep += 1
    }

    func retreatOnboarding() {
        guard isOnboarding else { return }
        onboardingStep = max(0, onboardingStep - 1)
    }

    func skipOnboarding() {
        finishOnboarding()
    }

    func finishOnboarding() {
        completeOnboardingIfNeeded()
        onDismiss()
    }

    func completeOnboardingIfNeeded() {
        guard isOnboarding else { return }
        onboardingState.markCompleted()
        isOnboarding = false
    }

    func handleEscape() {
        if isOnboarding {
            skipOnboarding()
        } else {
            onDismiss()
        }
    }

    func handleReturn() {
        if isOnboarding {
            advanceOnboarding()
        }
    }
}
