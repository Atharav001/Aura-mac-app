import SwiftUI
import AppKit

struct GlassmorphicModifier: ViewModifier {
    let opacity: Double
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let cornerRadius: CGFloat
    @State private var settings = AppSettingsManager.shared

    init(opacity: Double = 0.18, material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .withinWindow, cornerRadius: CGFloat = 16) {
        self.opacity = opacity
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        if settings.glassmorphismEnabled {
            content
                .background(
                    ZStack {
                        Color.black.opacity(0.85)
                        VisualEffectView(material: material, blendingMode: blendingMode, cornerRadius: cornerRadius)
                            .opacity(opacity)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.primary.opacity(0.07), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(Color.black)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat = 16

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
    }
}

extension View {
    func glassmorphic(
        opacity: Double = 0.18,
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(GlassmorphicModifier(opacity: opacity, material: material, blendingMode: blendingMode, cornerRadius: cornerRadius))
    }
}
