import SwiftUI

struct WidgetContainer<Content: View>: View {
    @State private var viewModel = WidgetState()
    @State private var blurIntensity: Double = 0.5
    @State private var panelWindow: NSWindow?

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(16)

            Divider()
                .overlay(.white.opacity(0.08))
                .padding(.horizontal, 12)

            controls
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(WindowAccessor { window in
            panelWindow = window
            window?.alphaValue = viewModel.opacity
        })
        .glassmorphic(opacity: blurIntensity * 0.35)
        .onChange(of: viewModel.opacity) { _, newValue in
            panelWindow?.alphaValue = newValue
        }
    }

    private var controls: some View {
        VStack(spacing: 6) {
            controlRow(
                icon: "circle.lefthalf.filled",
                label: "Opacity",
                value: $viewModel.opacity,
                range: 0.2...1.0
            )
            controlRow(
                icon: "circle.dotted",
                label: "Blur",
                value: $blurIntensity,
                range: 0.0...1.0
            )
        }
    }

    private func controlRow(icon: String, label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 44, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.white.opacity(0.3))
                .controlSize(.small)

            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 36, alignment: .trailing)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [callback] in
            callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [callback] in
            callback(nsView.window)
        }
    }
}
