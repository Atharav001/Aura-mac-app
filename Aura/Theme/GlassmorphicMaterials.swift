import SwiftUI

struct GlassmorphicModifier: ViewModifier {
    let opacity: Double
    let blurRadius: CGFloat

    init(opacity: Double = 0.15, blurRadius: CGFloat = 30) {
        self.opacity = opacity
        self.blurRadius = blurRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                VisualEffectView(material: .ultraDark, blendingMode: .withinWindow)
                    .opacity(opacity)
            )
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension View {
    func glassmorphic(opacity: Double = 0.15, blurRadius: CGFloat = 30) -> some View {
        modifier(GlassmorphicModifier(opacity: opacity, blurRadius: blurRadius))
    }
}
