import AppKit
import SwiftUI

enum GlanceMotion {
    static let duration: TimeInterval = 0.15

    static var isEnabled: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static var animation: Animation? {
        isEnabled ? .easeInOut(duration: duration) : nil
    }

    static func setAlpha(_ view: NSView, _ value: CGFloat) {
        if isEnabled {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                view.animator().alphaValue = value
            }
        } else {
            view.alphaValue = value
        }
    }
}
