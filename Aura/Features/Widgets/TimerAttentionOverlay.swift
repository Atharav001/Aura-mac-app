import SwiftUI

/// Full-window pulse / flash to grab attention when a timer ends (works even if muted).
struct TimerAttentionOverlay: View {
    @Binding var isActive: Bool
    @State private var pulse = false
    @State private var flashOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.4

    var body: some View {
        ZStack {
            // Bright edge flash
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.95),
                            .cyan.opacity(0.8),
                            .orange.opacity(0.85),
                            .white.opacity(0.95),
                        ],
                        center: .center
                    ),
                    lineWidth: pulse ? 6 : 2
                )
                .blur(radius: pulse ? 1 : 0)
                .opacity(isActive ? 1 : 0)

            // Soft fill wash
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(flashOpacity))
                .allowsHitTesting(false)

            // Expanding ring
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 3)
                .scaleEffect(ringScale)
                .opacity(isActive ? (1.2 - Double(ringScale) * 0.5) : 0)
                .frame(width: 120, height: 120)
                .allowsHitTesting(false)

            VStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8)
                    .scaleEffect(pulse ? 1.15 : 0.9)
                Text("Time’s up")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6)
            }
            .opacity(isActive ? 1 : 0)
            .offset(y: isActive ? 0 : 8)
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active { runAttentionSequence() }
        }
    }

    private func runAttentionSequence() {
        flashOpacity = 0.35
        ringScale = 0.35
        pulse = false

        withAnimation(.easeOut(duration: 0.18)) {
            flashOpacity = 0.55
            pulse = true
        }
        withAnimation(.easeOut(duration: 0.85)) {
            ringScale = 2.4
            flashOpacity = 0.08
        }

        // Second pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                pulse.toggle()
                flashOpacity = 0.4
            }
            withAnimation(.easeOut(duration: 0.7)) {
                flashOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.35)) {
                isActive = false
                pulse = false
                ringScale = 0.4
            }
        }
    }
}
