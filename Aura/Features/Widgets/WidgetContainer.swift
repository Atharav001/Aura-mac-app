import SwiftUI
import AppKit

struct WidgetContainer<Content: View>: View {
    @State private var viewModel = WidgetState()
    @State private var panelWindow: NSWindow?
    @State private var showControls = false
    @State private var liveZoom: CGFloat = 1.0

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 16)

            if showControls {
                Divider()
                    .overlay(.primary.opacity(0.08))
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
                panel.onZoomChanged = { scale in
                    Task { @MainActor in liveZoom = scale }
                }
                if viewModel.isPinned {
                    panel.setAlwaysOnTop(true)
                    panel.level = .statusBar
                }
            }
        })
        .glassmorphic(
            opacity: max(0.12, viewModel.blurIntensity * 0.55),
            material: viewModel.blurIntensity > 0.45 ? .hudWindow : .sidebar,
            cornerRadius: 18
        )
        .overlay(alignment: .topLeading) {
            closeButton
        }
        .overlay(alignment: .topTrailing) {
            gearButton
        }
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

    private var closeButton: some View {
        Button {
            guard let panel = panelWindow as? FloatingPanel else { return }
            PanelManager.shared.closePanel(id: panel.panelID)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.secondary.opacity(0.7))
                .frame(width: 20, height: 20)
                .background(Circle().fill(.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help("Close")
        .padding(10)
    }

    private var gearButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showControls.toggle()
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(showControls ? Color.secondary.opacity(0.9) : Color.secondary.opacity(0.55))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(showControls ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .help("Opacity & blur")
        .padding(10)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            controlRow(icon: "eye", label: "Opacity", value: $viewModel.opacity, range: 0.25...1.0)
            controlRow(icon: "circle.dotted", label: "Blur", value: $viewModel.blurIntensity, range: 0.0...1.0)

            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
                Text("Zoom")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                Text(String(format: "%.0f%%", liveZoom * 100))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Scroll to zoom · Drag edges to resize")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
            }

            pinButton
        }
    }

    private var pinButton: some View {
        HStack {
            Button {
                viewModel.isPinned.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 9, weight: .semibold))
                    Text(viewModel.isPinned ? "Pinned on top" : "Pin above windows")
                        .font(.system(size: 10, weight: .regular))
                }
                .foregroundStyle(viewModel.isPinned ? .blue.opacity(0.8) : Color.secondary.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(viewModel.isPinned ? .blue.opacity(0.15) : .primary.opacity(0.05))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlRow(icon: String, label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.primary.opacity(0.3))
                .controlSize(.small)

            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)
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
