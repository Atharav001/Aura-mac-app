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
                    drawCompletionWave(in: &context, size: size, time: now)
                    drawSparkles(in: &context, size: size, time: now)
                }
            }
            .allowsHitTesting(false)
        }
        .opacity(viewModel.isActive || viewModel.completionWaveStrength > 0.01 ? 1 : 0)
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
            let lineWidth = 1.5 * viewModel.rippleStrength * (1 - Double(i) * 0.2)

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
                lineWidth: max(0.5, lineWidth)
            )
        }
    }

    private func drawCompletionWave(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard viewModel.completionWaveStrength > 0.01 else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = max(size.width, size.height) * 0.8

        for i in 0..<5 {
            let phase = Double(i) * 0.2
            let progress = viewModel.completionWaveStrength * (1 - phase)
            guard progress > 0 else { continue }

            let radius = maxRadius * progress
            let opacity = Double(1 - progress) * 0.45
            let pulse = sin(time * 3 + Double(i) * 1.5) * 0.15 + 0.85
            let hue = (time * 15 + Double(i) * 36).truncatingRemainder(dividingBy: 360) / 360

            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            context.stroke(
                path,
                with: .color(Color(hue: hue, saturation: 0.7, brightness: 1).opacity(opacity * pulse)),
                lineWidth: max(0.5, 3 * viewModel.completionWaveStrength * CGFloat(1 - Double(i) * 0.15))
            )
        }
    }

    private func drawSparkles(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard viewModel.completionWaveStrength > 0.05 else { return }

        let count = 12
        let baseRadius = min(size.width, size.height) * 0.3

        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * .pi * 2 + time * 0.5
            let distance = baseRadius * viewModel.completionWaveStrength
            let x = size.width / 2 + cos(angle) * distance
            let y = size.height / 2 + sin(angle) * distance
            let sparkleSize: CGFloat = 2 + CGFloat(viewModel.completionWaveStrength * 3)
            let opacity = viewModel.completionWaveStrength * 0.6

            let hue = (time * 20 + Double(i) * 30).truncatingRemainder(dividingBy: 360) / 360
            let rect = CGRect(x: x - sparkleSize / 2, y: y - sparkleSize / 2, width: sparkleSize, height: sparkleSize)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(hue: hue, saturation: 0.8, brightness: 1).opacity(opacity))
            )
        }
    }
}
