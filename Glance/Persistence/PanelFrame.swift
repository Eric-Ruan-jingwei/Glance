import Foundation

/// Portable layout numbers shared by placement and display recovery.
enum GlanceLayout {
    static let spawnMargin: Double = 20
    static let cascadeOffset: Double = 24
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
}
