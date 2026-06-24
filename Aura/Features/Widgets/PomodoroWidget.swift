import SwiftUI

struct PomodoroWidget: View {
    @State private var viewModel = PomodoroViewModel()
    let initialDuration: TimeInterval?

    init(initialDuration: TimeInterval? = nil) {
        self.initialDuration = initialDuration
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        AngularGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.6), .cyan.opacity(0.6)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: viewModel.progress)

                VStack(spacing: 4) {
                    Text(viewModel.formattedTime)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.15), value: viewModel.timeRemaining)

                    Text(viewModel.state.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 16) {
                if viewModel.state == .idle || viewModel.state == .finished {
                    widgetButton(icon: "play.fill", label: "Start") {
                        viewModel.start(duration: viewModel.totalTime)
                    }
                } else {
                    widgetButton(icon: viewModel.state == .running ? "pause.fill" : "play.fill", label: viewModel.state == .running ? "Pause" : "Resume") {
                        viewModel.togglePause()
                    }

                    widgetButton(icon: "arrow.counterclockwise", label: "Reset", tint: .white.opacity(0.5)) {
                        viewModel.reset()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if let duration = initialDuration {
                viewModel.start(duration: duration)
            }
        }
    }

    private func widgetButton(icon: String, label: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(width: 56, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension PomodoroViewModel.State {
    var label: String {
        switch self {
        case .idle: return "Ready"
        case .running: return "Focus"
        case .paused: return "Paused"
        case .finished: return "Complete!"
        }
    }
}
