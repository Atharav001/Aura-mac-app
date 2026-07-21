import SwiftUI

/// Scales widget content from a design baseline so timers stay readable when the panel is resized.
struct AdaptiveWidgetScale: ViewModifier {
    let size: CGSize
    let designWidth: CGFloat
    let designHeight: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat

    func body(content: Content) -> some View {
        let raw = min(size.width / designWidth, size.height / designHeight)
        let scale = min(max(raw, minScale), maxScale)

        content
            .frame(width: designWidth, alignment: .top)
            .environment(\.widgetScale, scale)
            .scaleEffect(scale, anchor: .top)
            .frame(
                width: designWidth * scale,
                height: designHeight * scale,
                alignment: .top
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct WidgetScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var widgetScale: CGFloat {
        get { self[WidgetScaleKey.self] }
        set { self[WidgetScaleKey.self] = newValue }
    }
}

extension View {
    func adaptiveWidgetScale(
        in size: CGSize,
        designWidth: CGFloat = 260,
        designHeight: CGFloat = 340,
        minScale: CGFloat = 0.68,
        maxScale: CGFloat = 1.45
    ) -> some View {
        modifier(AdaptiveWidgetScale(
            size: size,
            designWidth: designWidth,
            designHeight: designHeight,
            minScale: minScale,
            maxScale: maxScale
        ))
    }
}
