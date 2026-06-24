import Foundation
import Combine
import UserNotifications
import AVFoundation
import AppKit
import UniformTypeIdentifiers

@Observable
final class PomodoroViewModel {
    enum State: Equatable {
        case idle, running, paused, finished
    }

    enum Phase: String, CaseIterable {
        case focus = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"
    }

    var state: State = .idle
    var phase: Phase = .focus
    var cycleCount: Int = 0
    var timeRemaining: TimeInterval = 25 * 60
    var totalTime: TimeInterval = 25 * 60
    var isAlarmPlaying = false

    private var alarmPlayer: AVAudioPlayer?
    var alarmURL: URL?

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalTime)
    }

    var onComplete: ((Phase) -> Void)?

    private var cancellable: AnyCancellable?
    private var startDate: Date?

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var totalTimeForPhase: TimeInterval {
        let focusDuration = DataStore.shared.double(for: .pomodoroFocusDuration, default: 25) * 60
        let shortBreakDuration = DataStore.shared.double(for: .pomodoroShortBreakDuration, default: 5) * 60
        let longBreakDuration = DataStore.shared.double(for: .pomodoroLongBreakDuration, default: 15) * 60
        switch phase {
        case .focus: return focusDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }

    func selectAlarmSound() {
        let panel = NSOpenPanel()
        let aiff = UTType(filenameExtension: "aiff") ?? .audio
        let wav = UTType(filenameExtension: "wav") ?? .audio
        let mp3 = UTType(filenameExtension: "mp3") ?? .audio
        panel.allowedContentTypes = [aiff, wav, mp3]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        alarmURL = panel.url
    }

    func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        isAlarmPlaying = false
    }

    func start(duration: TimeInterval? = nil) {
        let dur = duration ?? totalTimeForPhase
        totalTime = dur
        timeRemaining = dur
        state = .running
        startDate = Date()
        startTimer()
    }

    func togglePause() {
        if state == .running {
            state = .paused
            cancellable?.cancel()
        } else if state == .paused {
            state = .running
            startDate = Date().addingTimeInterval(-(totalTime - timeRemaining))
            startTimer()
        }
    }

    func reset() {
        cancellable?.cancel()
        stopAlarm()
        state = .idle
        phase = .focus
        cycleCount = 0
        timeRemaining = totalTimeForPhase
        totalTime = totalTimeForPhase
        startDate = nil
    }

    func switchToPhase(_ newPhase: Phase) {
        cancellable?.cancel()
        stopAlarm()
        phase = newPhase
        let dur = totalTimeForPhase
        totalTime = dur
        timeRemaining = dur
        state = .idle
        startDate = nil
    }

    private func startTimer() {
        cancellable?.cancel()
        cancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard let startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        timeRemaining = max(0, totalTime - elapsed)

        if timeRemaining <= 0 {
            cancellable?.cancel()
            state = .finished
            self.startDate = nil
            let completedPhase = phase
            playAlarm()
            onComplete?(completedPhase)
            NotificationCenter.default.post(name: .pomodoroComplete, object: nil)
            sendNotification()
            advanceCycle(from: completedPhase)
        }
    }

    private func advanceCycle(from completedPhase: Phase) {
        let cyclesBeforeLongBreak = Int(DataStore.shared.double(for: .pomodoroCyclesBeforeLongBreak, default: 4))
        switch completedPhase {
        case .focus:
            cycleCount += 1
            if cycleCount % max(cyclesBeforeLongBreak, 1) == 0 {
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .focus
        }
        let dur = totalTimeForPhase
        totalTime = dur
        timeRemaining = dur
    }

    private func playAlarm() {
        if let url = alarmURL {
            alarmPlayer = try? AVAudioPlayer(contentsOf: url)
            alarmPlayer?.numberOfLoops = -1
            alarmPlayer?.play()
            isAlarmPlaying = true
        } else {
            NSSound.beep()
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = phase == .focus ? "Focus Session Complete" : "Break Over"
        content.body = phase == .focus ? "Time for a break!" : "Ready to focus again?"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension Notification.Name {
    static let pomodoroComplete = Notification.Name("com.aura.pomodoroComplete")
}
