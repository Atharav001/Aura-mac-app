import SwiftUI
import AppKit

struct WidgetContainer<Content: View>: View {
    @State private var viewModel = WidgetState()
    @State private var panelWindow: NSWindow?
    @State private var showControls = false

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom title chrome (replaces system traffic lights)
            HStack(spacing: 8) {
                Button {
                    guard let panel = panelWindow as? FloatingPanel else { return }
                    PanelManager.shared.closePanel(id: panel.panelID)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Close")

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showControls.toggle()
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(showControls ? .white.opacity(0.9) : .white.opacity(0.55))
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(showControls ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Opacity & blur")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)

            content
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if showControls {
                Divider()
                    .overlay(.white.opacity(0.08))
                    .padding(.horizontal, 12)

                controls
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(WindowAccessor { window in
            panelWindow = window
            window?.alphaValue = viewModel.opacity
            if let panel = window as? FloatingPanel {
                panel.setAlwaysOnTop(true)
                panel.level = viewModel.isPinned ? .statusBar : .floating
            }
        })
        .glassmorphic(
            opacity: max(0.14, viewModel.blurIntensity * 0.55),
            material: viewModel.blurIntensity > 0.45 ? .hudWindow : .sidebar,
            cornerRadius: 18
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: viewModel.isPinned) { _, isPinned in
            if let panel = panelWindow as? FloatingPanel {
                panel.level = isPinned ? .statusBar : .floating
                panel.setAlwaysOnTop(true)
            }
        }
        .onChange(of: viewModel.opacity) { _, newOpacity in
            panelWindow?.alphaValue = newOpacity
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showControls)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            controlRow(icon: "eye", label: "Opacity", value: $viewModel.opacity, range: 0.25...1.0)
            controlRow(icon: "circle.dotted", label: "Blur", value: $viewModel.blurIntensity, range: 0.0...1.0)

            Text("Drag edges or corners to resize")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.isPinned.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 9, weight: .semibold))
                    Text(viewModel.isPinned ? "Pinned on top" : "Pin above windows")
                        .font(.system(size: 10, weight: .regular))
                }
                .foregroundStyle(viewModel.isPinned ? .blue.opacity(0.85) : .white.opacity(0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(viewModel.isPinned ? .blue.opacity(0.15) : .white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func controlRow(icon: String, label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 44, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.white.opacity(0.35))
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
