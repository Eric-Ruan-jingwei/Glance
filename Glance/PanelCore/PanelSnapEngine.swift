import Foundation

enum PanelLayoutPreset: String, CaseIterable, Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center

    var menuTitle: String {
        switch self {
        case .topLeft: return "左上角"
        case .topRight: return "右上角"
        case .bottomLeft: return "左下角"
        case .bottomRight: return "右下角"
        case .center: return "居中"
        }
    }
}

struct PanelSnapConfiguration: Equatable {
    var threshold: Double
    var margin: Double

    static let standard = PanelSnapConfiguration(
        threshold: GlanceLayout.snapThreshold,
        margin: GlanceLayout.snapMargin
    )
}

/// Portable edge-snap and layout-preset geometry. Changes origin only; size is preserved.
enum PanelSnapEngine {
    static func snappedFrame(
        _ frame: PanelFrame,
        in visibleFrame: PanelFrame,
        configuration: PanelSnapConfiguration = .standard,
        enabled: Bool = true
    ) -> PanelFrame {
        guard enabled else { return frame }
        let x = snappedOrigin(
            panelMin: frame.minX,
            panelMax: frame.maxX,
            visibleMin: visibleFrame.minX,
            visibleMax: visibleFrame.maxX,
            size: frame.width,
            threshold: configuration.threshold,
            margin: configuration.margin,
            preferMinOnTie: true
        )
        let y = snappedOrigin(
            panelMin: frame.minY,
            panelMax: frame.maxY,
            visibleMin: visibleFrame.minY,
            visibleMax: visibleFrame.maxY,
            size: frame.height,
            threshold: configuration.threshold,
            margin: configuration.margin,
            preferMinOnTie: true
        )
        return PanelFrame(x: x, y: y, width: frame.width, height: frame.height)
    }

    static func frame(
        for preset: PanelLayoutPreset,
        panelFrame: PanelFrame,
        visibleFrame: PanelFrame,
        margin: Double = GlanceLayout.snapMargin
    ) -> PanelFrame {
        let width = panelFrame.width
        let height = panelFrame.height
        let x: Double
        let y: Double
        switch preset {
        case .topLeft:
            x = visibleFrame.minX + margin
            y = visibleFrame.maxY - margin - height
        case .topRight:
            x = visibleFrame.maxX - margin - width
            y = visibleFrame.maxY - margin - height
        case .bottomLeft:
            x = visibleFrame.minX + margin
            y = visibleFrame.minY + margin
        case .bottomRight:
            x = visibleFrame.maxX - margin - width
            y = visibleFrame.minY + margin
        case .center:
            x = visibleFrame.midX - width / 2
            y = visibleFrame.midY - height / 2
        }
        return PanelFrame(x: x, y: y, width: width, height: height)
    }

    private static func snappedOrigin(
        panelMin: Double,
        panelMax: Double,
        visibleMin: Double,
        visibleMax: Double,
        size: Double,
        threshold: Double,
        margin: Double,
        preferMinOnTie: Bool
    ) -> Double {
        let distMin = abs(panelMin - visibleMin)
        let distMax = abs(panelMax - visibleMax)
        let nearMin = distMin <= threshold
        let nearMax = distMax <= threshold
        let minTarget = visibleMin + margin
        let maxTarget = visibleMax - margin - size

        if nearMin && nearMax {
            if distMin < distMax || (distMin == distMax && preferMinOnTie) {
                return minTarget
            }
            return maxTarget
        }
        if nearMin { return minTarget }
        if nearMax { return maxTarget }
        return panelMin
    }
}
