import SwiftUI
import Combine

@MainActor
final class PanelSettingsModel: ObservableObject {
    @Published var isPinned: Bool
    @Published var isLocked: Bool
    @Published var isPassThrough: Bool
    @Published var opacity: Double

    init(isPinned: Bool, isLocked: Bool, isPassThrough: Bool, opacity: Double) {
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isPassThrough = isPassThrough
        self.opacity = PanelOpacity.clamp(opacity)
    }
}

struct PanelSettingsView: View {
    @ObservedObject var model: PanelSettingsModel
    var onPinned: (Bool) -> Void
    var onLocked: (Bool) -> Void
    var onPassThrough: (Bool) -> Void
    var onOpacity: (Double) -> Void
    var onOpenFolder: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("置顶", isOn: pinnedBinding)
            Toggle("锁定", isOn: lockedBinding)
            Toggle("点击穿透", isOn: passThroughBinding)

            VStack(alignment: .leading, spacing: 6) {
                Text("透明度")
                HStack {
                    Text("30%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: opacityBinding, in: PanelOpacity.minimum...PanelOpacity.maximum, step: 0.05)
                    Text("100%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("打开内容文件夹", action: onOpenFolder)
            Button("删除面板", role: .destructive, action: onDelete)
        }
        .padding(20)
        .frame(width: 280)
        .toggleStyle(.switch)
    }

    private var pinnedBinding: Binding<Bool> {
        Binding(get: { model.isPinned }, set: onPinned)
    }

    private var lockedBinding: Binding<Bool> {
        Binding(get: { model.isLocked }, set: onLocked)
    }

    private var passThroughBinding: Binding<Bool> {
        Binding(get: { model.isPassThrough }, set: onPassThrough)
    }

    private var opacityBinding: Binding<Double> {
        Binding(get: { model.opacity }, set: onOpacity)
    }
}
