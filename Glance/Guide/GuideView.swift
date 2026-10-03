import SwiftUI

struct GuideView: View {
    @ObservedObject var model: GuideModel
    @ObservedObject var shortcuts: ShortcutCoordinator

    var body: some View {
        Group {
            if model.isOnboarding {
                onboarding
            } else {
                split
            }
        }
        .frame(minWidth: 620, minHeight: 440)
        .onExitCommand(perform: model.handleEscape)
    }

    private var split: some View {
        NavigationSplitView {
            List(selection: $model.section) {
                ForEach(GuideSection.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                        .accessibilityLabel(section.title)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 148, ideal: GlanceTheme.Size.sidebarIdeal, max: 220)
        } detail: {
            detail
        }
        .navigationTitle(GlanceGuideEntry.windowTitle)
    }

    @ViewBuilder
    private var detail: some View {
        switch model.section {
        case .gettingStarted:
            GuideGettingStartedView(shortcutProvider: shortcutProvider, paginated: false)
        case .shortcuts:
            GuideShortcutsView(shortcutProvider: shortcutProvider, onOpenSettings: model.onOpenSettings)
        case .features:
            GuideFeaturesView()
        }
    }

    private var onboarding: some View {
        VStack(spacing: 0) {
            GuideGettingStartedView(
                shortcutProvider: shortcutProvider,
                paginated: true,
                step: model.onboardingStep
            )
            .id(model.onboardingStep)
            .padding(GlanceTheme.Space.xl)
            .animation(GlanceMotion.animation, value: model.onboardingStep)
            footer
        }
        .onKeyPress(.leftArrow) {
            model.retreatOnboarding()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.advanceOnboarding()
            return .handled
        }
    }

    private var footer: some View {
        HStack {
            if model.isLastOnboardingPage {
                Button(GlanceGuideEntry.backTitle, action: model.retreatOnboarding)
            } else {
                Button(GlanceGuideEntry.skipTitle, action: model.skipOnboarding)
            }
            Spacer()
            Text(model.onboardingPageLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("第 \(model.onboardingStep + 1) 页，共 \(GuideModel.onboardingPageCount) 页")
            Spacer()
            if model.isLastOnboardingPage {
                Button(GlanceGuideEntry.finishTitle, action: model.finishOnboarding)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(GlanceGuideEntry.continueTitle, action: model.advanceOnboarding)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, GlanceTheme.Space.xl)
        .padding(.vertical, GlanceTheme.Space.md)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func shortcutProvider(_ action: ShortcutAction) -> GlanceShortcut {
        shortcuts.shortcut(for: action)
    }
}
