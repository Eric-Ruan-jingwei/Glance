import Foundation

/// Portable layout numbers shared by placement, recovery, and edge snap.
enum GlanceLayout {
    static let spawnMargin: Double = 20
    static let cascadeOffset: Double = 24
    static let snapMargin: Double = 16
    static let snapThreshold: Double = 16
}

/// Platform-agnostic panel rectangle. Persisted as flat `x` / `y` / `width` / `height`.
struct PanelFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }

    func intersection(_ other: PanelFrame) -> PanelFrame? {
        let left = max(minX, other.minX)
        let bottom = max(minY, other.minY)
        let overlapWidth = min(maxX, other.maxX) - left
        let overlapHeight = min(maxY, other.maxY) - bottom
        guard overlapWidth > 0, overlapHeight > 0 else { return nil }
        return PanelFrame(x: left, y: bottom, width: overlapWidth, height: overlapHeight)
    }
}
