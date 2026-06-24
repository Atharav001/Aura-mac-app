import Observation
import SwiftUI

@MainActor @Observable
final class FocusViewModel {
    var isActive: Bool = false
    var rippleStrength: CGFloat = 0
    var dimOpacity: CGFloat = 0
    var completionWaveStrength: CGFloat = 0

    func startFocus() {
        isActive = true
        withAnimation(.easeInOut(duration: 0.8)) {
            dimOpacity = 0.4
        }
        triggerRipple()
    }

    func endFocus() {
        withAnimation(.easeInOut(duration: 0.6)) {
            dimOpacity = 0
        }
        scheduleEndFocus()
    }

    nonisolated func scheduleEndFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.isActive = false
                self.rippleStrength = 0
                self.completionWaveStrength = 0
            }
        }
    }

    func triggerRipple() {
        withAnimation(AnimationCurves.ripple) {
            rippleStrength = 1
        }
        scheduleRippleEnd()
    }

    func triggerCompletionWave() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.5, blendDuration: 0.4)) {
            completionWaveStrength = 1
        }
        scheduleCompletionWaveEnd()
    }

    nonisolated func scheduleRippleEnd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                withAnimation(.easeOut(duration: 0.5)) {
                    self.rippleStrength = 0
                }
            }
        }
    }

    nonisolated func scheduleCompletionWaveEnd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                withAnimation(.easeOut(duration: 1.0)) {
                    self.completionWaveStrength = 0
                }
            }
        }
    }
}
