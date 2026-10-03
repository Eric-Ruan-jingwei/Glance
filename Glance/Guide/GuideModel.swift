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

enum GuideGettingStartedCopy {
    static let step1Title = "把常用信息和工具留在手边"
    static let step1Detail = "Glance 是一个常驻 macOS 的轻量个人办公工具入口。可以固定持续参考的内容，保存最近复制的信息和临时文件，把常用文字整理到片段库，也可以收藏经常访问的网页和在线资源。"
}

struct GuideFeatureCopy: Equatable {
    var title: String
    var symbol: String
    var body: String
}

enum GuideFeatureCatalog {
    static let items: [GuideFeatureCopy] = [
        GuideFeatureCopy(
            title: "剪贴板",
            symbol: "list.clipboard",
            body: "Glance 可以在本机保存你之后复制的文字和图片。常用内容可以收藏，并通过剪贴板窗口快速搜索和再次调用。内容只保存在本机。"
        ),
        GuideFeatureCopy(
            title: "文件架",
            symbol: "tray",
            body: "把稍后还要用的文件暂存在文件架里。Glance 只保存文件引用，不会复制原文件。从文件架移除记录也不会删除原文件。"
        ),
        GuideFeatureCopy(
            title: "片段库",
            symbol: "text.quote",
            body: "把会反复使用的文字主动保存为片段。片段可以编辑和置顶，复制后自己粘贴。它不是剪贴板历史，也不会被自动淘汰。"
        ),
        GuideFeatureCopy(
            title: "链接库",
            symbol: "link",
            body: "把经常访问的网页和在线资源主动保存下来。Glance 不会抓取网页标题或图标，打开时使用系统默认浏览器。"
        ),
        GuideFeatureCopy(
            title: "Workspaces",
            symbol: "square.on.square",
            body: "一个面板只属于一个工作区。切换工作区时，只显示当前工作区中的面板。适合把工作、学习、项目等不同上下文分开。"
        ),
        GuideFeatureCopy(
            title: "Tags",
            symbol: "tag",
            body: "一个面板可以拥有多个标签。标签用于搜索和筛选，不会影响面板是否显示。工作区决定当前能看见哪些面板；标签只负责整理和查找。"
        ),
        GuideFeatureCopy(
            title: "Panel Manager",
            symbol: "square.stack",
            body: "Panel Manager 用于集中搜索、筛选和整理已有面板。可以搜索、按类型筛选、移动工作区、批量隐藏或显示，以及批量编辑标签。"
        )
    ]
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
