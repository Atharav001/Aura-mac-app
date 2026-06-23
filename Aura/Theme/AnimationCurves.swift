import SwiftUI

struct AnimationCurves {
    static let notchExpand = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.3)
    static let notchCollapse = Animation.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.25)
    static let panelSnap = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
    static let widgetAppear = Animation.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.3)
    static let widgetDisappear = Animation.easeOut(duration: 0.2)
    static let ripple = Animation.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0.4)
    static let confetti = Animation.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.3)
}
