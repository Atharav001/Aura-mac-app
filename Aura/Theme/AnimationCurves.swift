import SwiftUI

struct AnimationCurves {
    static let notchExpand = Animation.spring(response: 0.45, dampingFraction: 0.65, blendDuration: 0.3)
    static let notchCollapse = Animation.spring(response: 0.38, dampingFraction: 0.72, blendDuration: 0.25)
    static let notchStretch = Animation.spring(response: 0.55, dampingFraction: 0.55, blendDuration: 0.4)
    static let panelSnap = Animation.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.2)
    static let duoModeSplit = Animation.spring(response: 0.5, dampingFraction: 0.58, blendDuration: 0.3)
    static let widgetAppear = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3)
    static let widgetDisappear = Animation.easeOut(duration: 0.25)
    static let ripple = Animation.spring(response: 0.6, dampingFraction: 0.55, blendDuration: 0.4)
    static let confetti = Animation.spring(response: 0.45, dampingFraction: 0.6, blendDuration: 0.3)
    static let hudSlide = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.25)
    static let bubbleMorph = Animation.interpolatingSpring(stiffness: 180, damping: 15)
}
