import Foundation

struct OnboardingState {
    static let completedKey = "com.glance.onboarding.completed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldPresent: Bool {
        !defaults.bool(forKey: Self.completedKey)
    }

    func markCompleted() {
        defaults.set(true, forKey: Self.completedKey)
    }
}
