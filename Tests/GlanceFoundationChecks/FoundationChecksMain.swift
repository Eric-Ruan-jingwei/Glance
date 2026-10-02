import Foundation
@testable import GlanceCore

@main
enum GlanceFoundationChecks {
    static func main() async {
        await MainActor.run {
            PanelRepositoryChecks.run()
            PanelFrameRecoveryChecks.run()
            PanelPlacementEngineChecks.run()
        }
        print("Glance foundation checks: \(CheckRun.passed) passed, \(CheckRun.failed) failed")
        if CheckRun.failed > 0 {
            exit(1)
        }
    }
}
