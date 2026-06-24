import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiPiece] = []
    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { piece in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(piece.color.opacity(0.6))
                        .frame(width: piece.size, height: piece.size * 0.6)
                        .rotationEffect(animate ? piece.rotation : .zero)
                        .offset(animate ? piece.offset : .zero)
                        .opacity(animate ? piece.opacity : 1)
                }
            }
            .onAppear {
                spawnBurst(in: geometry.size)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.3)) {
                    animate = true
                }
            }
        }
    }

    private func spawnBurst(in size: CGSize) {
        let colors: [Color] = [.blue, .cyan, .purple, .white, .mint]

        var newPieces: [ConfettiPiece] = []
        for i in 0..<24 {
            let angle = Double(i) * 15.0 + Double.random(in: -5...5)
            let distance = CGFloat.random(in: 40...140)
            let rad = angle * .pi / 180
            let dx = cos(rad) * distance
            let dy = sin(rad) * distance + CGFloat.random(in: -20...20)

            newPieces.append(ConfettiPiece(
                offset: CGSize(width: dx, height: dy),
                rotation: .degrees(Double.random(in: 0...720)),
                opacity: Double.random(in: 0.3...0.8),
                color: colors.randomElement() ?? .white,
                size: CGFloat.random(in: 4...9)
            ))
        }
        particles = newPieces
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let offset: CGSize
    let rotation: Angle
    let opacity: Double
    let color: Color
    let size: CGFloat
}
