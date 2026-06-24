import SwiftUI

struct StopwatchWidget: View {
    @State private var viewModel = StopwatchViewModel()

    var body: some View {
        VStack(spacing: 20) {
            modePicker

            if case .countdown = viewModel.mode {
                ProgressView(value: viewModel.progress)
                    .tint(.cyan.opacity(0.6))
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
            }

            Text(viewModel.formattedTime)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(viewModel.isCountdownFinished ? .green : .white)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: viewModel.elapsed)

            if viewModel.isCountdownFinished {
                Text("Time's up!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green.opacity(0.7))

                if viewModel.isAlarmPlaying {
                    Button {
                        viewModel.stopAlarm()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Stop Alarm")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.red.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                stopwatchButton(icon: viewModel.isRunning ? "stop.fill" : "play.fill",
                                label: viewModel.isRunning ? "Stop" : "Start") {
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

            if case .countdown = viewModel.mode {
                alarmButton
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

    private var modePicker: some View {
        HStack(spacing: 8) {
            modeButton("Stopwatch", mode: .stopwatch)
            modeButton("Timer", mode: .countdown(target: 300))
            if case .countdown = viewModel.mode {
                timerPresets
            }
        }
    }

    private var timerPresets: some View {
        HStack(spacing: 4) {
            presetButton("1m", 60)
            presetButton("5m", 300)
            presetButton("10m", 600)
            presetButton("30m", 1800)
        }
    }

    private func presetButton(_ label: String, _ seconds: TimeInterval) -> some View {
        Button {
            viewModel.setMode(.countdown(target: seconds))
        } label: {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private func modeButton(_ label: String, mode: StopwatchViewModel.Mode) -> some View {
        Button {
            viewModel.setMode(mode)
        } label: {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(viewModel.mode == mode ? .white : .white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(viewModel.mode == mode ? .white.opacity(0.15) : .white.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }

    private var alarmButton: some View {
        Button {
            viewModel.selectAlarmSound()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.alarmURL != nil ? "music.note.list" : "bell")
                    .font(.system(size: 10, weight: .semibold))
                Text(viewModel.alarmURL?.lastPathComponent ?? "Alarm Sound")
                    .font(.system(size: 10, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(viewModel.alarmURL != nil ? .orange.opacity(0.7) : .white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
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
