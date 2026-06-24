import SwiftUI

struct FocusOverlay: View {
    @State var viewModel: FocusViewModel

    var body: some View {
        ZStack {
            edgeDimGradient

            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, size in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    drawRipples(in: &context, size: size, time: now)
                }
            }
            .allowsHitTesting(false)
        }
        .opacity(viewModel.isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.6), value: viewModel.isActive)
    }

    @ViewBuilder
    private var edgeDimGradient: some View {
        let gradient = RadialGradient(
            colors: [
                .clear,
                .clear,
                .black.opacity(viewModel.dimOpacity * 0.3),
                .black.opacity(viewModel.dimOpacity)
            ],
            center: .center,
            startRadius: 50,
            endRadius: 600
        )
        Rectangle()
            .fill(gradient)
            .ignoresSafeArea()
    }

    private func drawRipples(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard viewModel.rippleStrength > 0.01 else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = max(size.width, size.height) * 0.6

        for i in 0..<3 {
            let phase = Double(i) * 0.3
            let progress = viewModel.rippleStrength * (1 - phase)
            guard progress > 0 else { continue }

            let radius = maxRadius * progress
            let opacity = Double(1 - progress) * 0.3

            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            context.stroke(
                path,
                with: .color(.white.opacity(opacity)),
                lineWidth: 1.5 * viewModel.rippleStrength
            )
        }
    }
}
