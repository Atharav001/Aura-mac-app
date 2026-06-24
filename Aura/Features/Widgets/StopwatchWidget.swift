import SwiftUI

struct StopwatchWidget: View {
    @State private var viewModel = StopwatchViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.formattedTime)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: viewModel.elapsed)

            HStack(spacing: 12) {
                stopwatchButton(icon: viewModel.isRunning ? "stop.fill" : "play.fill", label: viewModel.isRunning ? "Stop" : "Start") {
                    if viewModel.isRunning {
                        viewModel.stop()
                    } else {
                        viewModel.start()
                    }
                }

                stopwatchButton(icon: "arrow.counterclockwise", label: "Reset", tint: .white.opacity(0.5)) {
                    viewModel.reset()
                }

                stopwatchButton(icon: "flag.fill", label: "Lap", tint: viewModel.isRunning ? .white : .white.opacity(0.3)) {
                    viewModel.lap()
                }
                .disabled(!viewModel.isRunning)
            }

            if !viewModel.laps.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(viewModel.laps.enumerated().reversed()), id: \.offset) { index, lap in
                            HStack {
                                Text("Lap \(index + 1)")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.4))
                                Spacer()
                                Text(formatLapTime(lap))
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.white.opacity(0.03))
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .padding(.vertical, 8)
    }

    private func stopwatchButton(icon: String, label: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(width: 52, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatLapTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time - floor(time)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}
