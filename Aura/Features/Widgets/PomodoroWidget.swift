import SwiftUI

struct PomodoroWidget: View {
    @State private var viewModel = PomodoroViewModel()
    @State private var editText = ""
    @FocusState private var isEditingFocused: Bool
    let initialDuration: TimeInterval?

    init(initialDuration: TimeInterval? = nil) {
        self.initialDuration = initialDuration
        if let dur = initialDuration {
            _viewModel = State(initialValue: {
                let vm = PomodoroViewModel()
                vm.totalTime = dur
                vm.timeRemaining = dur
                return vm
            }())
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            phaseIndicator

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                phaseColor(viewModel.phase).opacity(0.45),
                                phaseColor(viewModel.phase).opacity(0.9),
                                .cyan.opacity(0.5)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: viewModel.progress)

                VStack(spacing: 4) {
                    if viewModel.isEditingDuration {
                        TextField("", text: $editText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(width: 100)
                            .focused($isEditingFocused)
                            .onSubmit { commitEdit() }
                            .onAppear {
                                editText = "\(viewModel.editableMinutes)"
                                isEditingFocused = true
                            }
                        Text("min · Enter to save")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.linear(duration: 0.15), value: viewModel.timeRemaining)
                            .onTapGesture {
                                viewModel.isEditingDuration = true
                                editText = "\(max(1, Int(viewModel.timeRemaining / 60)))"
                            }
                            .help("Click to edit duration")

                        Text(viewModel.state.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 16) {
                if viewModel.state == .idle || viewModel.state == .finished {
                    widgetButton(icon: "play.fill", label: "Start") {
                        viewModel.start()
                    }
                } else {
                    widgetButton(
                        icon: viewModel.state == .running ? "pause.fill" : "play.fill",
                        label: viewModel.state == .running ? "Pause" : "Resume"
                    ) {
                        viewModel.togglePause()
                    }

                    widgetButton(icon: "arrow.counterclockwise", label: "Reset", tint: .white.opacity(0.5)) {
                        viewModel.reset()
                    }
                }
            }

            phasePicker

            Toggle(isOn: $viewModel.autoContinue) {
                Text("Auto loop focus ↔ break")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(.blue.opacity(0.7))

            if viewModel.isAlarmPlaying {
                alarmControls
            } else if viewModel.state == .idle {
                alarmSelectButton
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            if viewModel.state == .idle, let dur = initialDuration {
                viewModel.start(duration: dur)
            }
        }
    }

    private func commitEdit() {
        let minutes = Int(editText.trimmingCharacters(in: .whitespaces)) ?? viewModel.editableMinutes
        viewModel.applyEditedMinutes(minutes)
        if viewModel.state == .idle {
            // keep idle ready with new duration
        }
    }

    private var alarmControls: some View {
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

    private var alarmSelectButton: some View {
        Button {
            viewModel.selectAlarmSound()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.alarmURL != nil ? "music.note.list" : "bell")
                    .font(.system(size: 10, weight: .semibold))
                Text(viewModel.alarmURL?.lastPathComponent ?? "Set Alarm Sound")
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

    private var phaseIndicator: some View {
        HStack(spacing: 6) {
            ForEach(PomodoroViewModel.Phase.allCases, id: \.self) { phase in
                Circle()
                    .fill(phaseColor(phase))
                    .frame(width: 8, height: 8)
                    .opacity(viewModel.phase == phase ? 1 : 0.2)
            }
            Text(viewModel.phase.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.leading, 4)
            Spacer()
            if viewModel.cycleCount > 0 {
                Text("Cycle \(viewModel.cycleCount)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 4)
    }

    private var phasePicker: some View {
        HStack(spacing: 8) {
            phaseButton("Focus", phase: .focus)
            phaseButton("Short", phase: .shortBreak)
            phaseButton("Long", phase: .longBreak)
        }
    }

    private func phaseButton(_ label: String, phase: PomodoroViewModel.Phase) -> some View {
        Button {
            viewModel.switchToPhase(phase)
        } label: {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(viewModel.phase == phase ? .white : .white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(viewModel.phase == phase ? phaseColor(phase).opacity(0.25) : .white.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }

    private func phaseColor(_ phase: PomodoroViewModel.Phase) -> Color {
        switch phase {
        case .focus: return .blue
        case .shortBreak: return .green
        case .longBreak: return .cyan
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
        case .running: return "Running"
        case .paused: return "Paused"
        case .finished: return "Complete!"
        }
    }
}
