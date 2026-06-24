import SwiftUI
import IOKit.ps

struct NotchView: View {
    let viewModel: NotchViewModel
    @State private var hoveredControl: String?
    @State private var systemTimer: Timer?
    @State private var appSettings = AppSettingsManager.shared

    var body: some View {
        notchContent
            .frame(width: viewModel.currentFrame.width, height: viewModel.currentFrame.height)
            .animation(.spring(response: 0.45, dampingFraction: 0.8, blendDuration: 0.3), value: viewModel.state)
            .onAppear {
                viewModel.updateSystemInfo()
                systemTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                    Task { @MainActor in
                        viewModel.updateSystemInfo()
                    }
                }
            }
            .onDisappear {
                systemTimer?.invalidate()
            }
    }

    @ViewBuilder
    private var notchContent: some View {
        if appSettings.notchStyle == "pill" {
            innerContent
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.5))
        } else {
            let s = UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 28, bottomTrailingRadius: 28, topTrailingRadius: 2, style: .continuous)
            innerContent
                .clipShape(s)
                .overlay(s.stroke(.white.opacity(0.08), lineWidth: 0.5))
        }
    }

    private var innerContent: some View {
        ZStack {
            Color.black
                .opacity(viewModel.state == .collapsed ? 1 : 0)

            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .opacity(viewModel.state == .collapsed ? 0 : 1)

            Group {
                switch viewModel.state {
                case .collapsed: EmptyView()
                case .expanded: expandedContent
                case .media: mediaContent
                }
            }
            .opacity(viewModel.state == .collapsed ? 0 : 1)
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.state)
    }

    @ViewBuilder
    private var expandedContent: some View {
        HStack(spacing: 12) {
            leftInfo

            Spacer()

            rightActions
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var leftInfo: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.currentTime)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))

                Text(viewModel.currentDate)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
            }

            if viewModel.batteryLevel > 0 {
                HStack(spacing: 4) {
                    Image(systemName: batteryIconName)
                        .font(.system(size: 10))
                        .foregroundColor(batteryColor)

                    Text("\(Int(viewModel.batteryLevel * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.leading, 4)
            }
        }
    }

    private var batteryIconName: String {
        if viewModel.batteryCharging { return "battery.100.bolt" }
        let pct = viewModel.batteryLevel
        if pct > 0.75 { return "battery.100" }
        if pct > 0.5 { return "battery.75" }
        if pct > 0.25 { return "battery.50" }
        if pct > 0.15 { return "battery.25" }
        return "battery.0"
    }

    private var batteryColor: Color {
        let pct = viewModel.batteryLevel
        if viewModel.batteryCharging { return .green }
        if pct > 0.2 { return .white.opacity(0.6) }
        return .orange
    }

    @ViewBuilder
    private var rightActions: some View {
        HStack(spacing: 8) {
            if viewModel.hasMedia {
                Button {
                    viewModel.state = .media
                } label: {
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(hoveredControl == "toMedia" ? 0.8 : 0.5))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredControl = hovering ? "toMedia" : nil
                }
            }

            // Quick actions
            quickActionButton(
                icon: "timer",
                label: "Pomodoro",
                action: { NotificationCenter.default.post(name: .startPomodoro, object: nil) }
            )

            quickActionButton(
                icon: "checklist",
                label: "Todo",
                action: {
                    PanelManager.shared.spawnPanel(size: NSSize(width: 300, height: 400)) {
                        WidgetContainer { TodoWidget() }
                    }
                }
            )
        }
    }

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredControl == label
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(isHovered ? 0.8 : 0.4))
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { hovering in
            hoveredControl = hovering ? label : nil
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                sourceAppIconView
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.nowPlayingTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(viewModel.nowPlayingArtist)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                artworkThumbnail
            }

            progressSlider
                .padding(.horizontal, 2)

            transportControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hoveredControl)
    }

    @ViewBuilder
    private var sourceAppIconView: some View {
        if let icon = viewModel.sourceAppIcon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: viewModel.mediaSource.iconName)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    @ViewBuilder
    private var artworkThumbnail: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.white.opacity(0.12))
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            )
    }

    @ViewBuilder
    private var progressSlider: some View {
        Slider(
            value: Binding(
                get: { viewModel.progress },
                set: { newProgress in
                    let time = newProgress * viewModel.duration
                    LocalAudioManager.shared.seek(to: time)
                }
            ),
            in: 0...1
        )
        .tint(.white.opacity(hoveredControl == "slider" ? 0.55 : 0.35))
        .controlSize(.small)
        .disabled(!viewModel.hasMedia || viewModel.mediaSource != .local)
        .onHover { hovering in
            hoveredControl = hovering ? "slider" : nil
        }
    }

    @ViewBuilder
    private var transportControls: some View {
        HStack(spacing: 20) {
            transportButton(icon: "backward.fill", id: "back", size: 11)
            transportButton(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", id: "playpause", size: 15, isPrimary: true)
            transportButton(icon: "forward.fill", id: "forward", size: 11)

            Spacer()

            if !viewModel.sourceAppName.isEmpty {
                Text(viewModel.sourceAppName)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white.opacity(0.3))
            }

            transportButton(icon: "xmark", id: "close", size: 8)
        }
    }

    private func transportButton(icon: String, id: String, size: CGFloat, isPrimary: Bool = false) -> some View {
        let isHovered = hoveredControl == id
        return Button {
            if id == "playpause" {
                viewModel.togglePlayPause()
            } else if id == "back" {
                viewModel.previousTrack()
            } else if id == "forward" {
                viewModel.nextTrack()
            } else if id == "close" {
                viewModel.hideMedia()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: isPrimary ? .semibold : .regular))
                .foregroundColor(isPrimary ? .white : .white.opacity(isHovered ? 0.8 : 0.5))
                .scaleEffect(isHovered && isPrimary ? 1.1 : 1.0)
                .shadow(color: isHovered && isPrimary ? .white.opacity(0.3) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredControl = hovering ? id : nil
        }
    }
}
