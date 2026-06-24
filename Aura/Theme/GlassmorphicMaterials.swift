import SwiftUI

struct GlassmorphicModifier: ViewModifier {
    let opacity: Double
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    @State private var settings = AppSettingsManager.shared

    init(opacity: Double = 0.15, material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .withinWindow) {
        self.opacity = opacity
        self.material = material
        self.blendingMode = blendingMode
    }

    func body(content: Content) -> some View {
        if settings.glassmorphismEnabled {
            content
                .background(
                    VisualEffectView(material: material, blendingMode: blendingMode)
                        .opacity(opacity)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            content
                .background(Color(nsColor: .windowBackgroundColor))
        }
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
        view.layer?.cornerRadius = 16
        view.layer?.cornerCurve = .continuous
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension View {
    func glassmorphic(
        opacity: Double = 0.15,
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    ) -> some View {
        modifier(GlassmorphicModifier(opacity: opacity, material: material, blendingMode: blendingMode))
    }
}
