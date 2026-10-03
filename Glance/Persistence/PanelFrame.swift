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
}
