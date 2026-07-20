import SwiftUI

/// Animation curves tuned to match Boring Notch's feel
/// Open: spring(response: 0.42, dampingFraction: 0.8)
/// Close: spring(response: 0.45, dampingFraction: 1.0) — critically damped, no wobble
struct AnimationCurves {
    static let notchExpand = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    static let notchCollapse = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    static let notchInteractive = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    static let notchStretch = Animation.spring(response: 0.5, dampingFraction: 0.78, blendDuration: 0)
    static let contentReveal = Animation.smooth(duration: 0.35)
    static let panelSnap = Animation.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)
    static let duoModeSplit = Animation.spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0)
    static let widgetAppear = Animation.spring(response: 0.45, dampingFraction: 0.78, blendDuration: 0)
    static let widgetDisappear = Animation.easeOut(duration: 0.22)
    static let ripple = Animation.spring(response: 0.55, dampingFraction: 0.7, blendDuration: 0)
    static let confetti = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
    static let hudSlide = Animation.spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0)
    static let bubbleMorph = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.78)

    /// Respects "disable overshoot" / simple close settings
    static func notchStateAnimation(opening: Bool) -> Animation {
        if DataStore.shared.bool(for: .disableOvershoot, default: false) {
            return .easeInOut(duration: opening ? 0.28 : 0.22)
        }
        if !opening && DataStore.shared.bool(for: .simpleCloseAnim, default: true) {
            return notchCollapse
        }
        return opening ? notchExpand : notchCollapse
    }
}
