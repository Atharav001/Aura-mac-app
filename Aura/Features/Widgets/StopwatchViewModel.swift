import Foundation
import Combine
import AVFoundation
import AppKit
import UniformTypeIdentifiers

@Observable
final class StopwatchViewModel {
    enum Mode: Equatable {
        case stopwatch
        case countdown(target: TimeInterval)
    }

    var elapsed: TimeInterval = 0
    var timeRemaining: TimeInterval = 0
    var isRunning = false
    var laps: [TimeInterval] = []
    var mode: Mode = .stopwatch
    var alarmURL: URL?
    var alarmPlayer: AVAudioPlayer?

    private var cancellable: AnyCancellable?
    private var startDate: Date?
    private var initialElapsed: TimeInterval = 0

    var formattedTime: String {
        let display: TimeInterval = {
            if case .countdown = mode { return max(0, timeRemaining) }
            return elapsed
        }()
        let minutes = Int(display) / 60
        let seconds = Int(display) % 60
        let centiseconds = Int((display - floor(display)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    var totalTimeForMode: TimeInterval {
        switch mode {
        case .stopwatch: return elapsed
        case .countdown(let target): return target
        }
    }

    var progress: Double {
        switch mode {
        case .stopwatch: return 0
        case .countdown(let target):
            guard target > 0 else { return 0 }
            return 1.0 - (max(0, timeRemaining) / target)
        }
    }

    var isCountdownFinished: Bool {
        if case .countdown = mode, timeRemaining <= 0, !isRunning {
            return true
        }
        return false
    }

    func setMode(_ newMode: Mode) {
        stop()
        mode = newMode
        switch newMode {
        case .stopwatch:
            elapsed = 0
            timeRemaining = 0
        case .countdown(let target):
            elapsed = 0
            timeRemaining = target
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        switch mode {
        case .stopwatch:
            startDate = Date().addingTimeInterval(-elapsed)
        case .countdown:
            startDate = Date().addingTimeInterval(-(elapsed))
        }
        startTimer()
    }

    func stop() {
        isRunning = false
        cancellable?.cancel()
    }

    func reset() {
        stop()
        elapsed = 0
        laps = []
        startDate = nil
        switch mode {
        case .stopwatch:
            break
        case .countdown(let target):
            timeRemaining = target
        }
    }

    func lap() {
        laps.append(elapsed)
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

    func playAlarm() {
        if let url = alarmURL {
            alarmPlayer = try? AVAudioPlayer(contentsOf: url)
            alarmPlayer?.play()
        } else {
            NSSound.beep()
        }
    }

    var isAlarmPlaying: Bool { alarmPlayer?.isPlaying ?? false }

    func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
    }

    private func startTimer() {
        cancellable?.cancel()
        cancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard let startDate else { return }
        let nowElapsed = Date().timeIntervalSince(startDate)

        switch mode {
        case .stopwatch:
            elapsed = nowElapsed
        case .countdown(let target):
            timeRemaining = max(0, target - nowElapsed)
            elapsed = nowElapsed
            if timeRemaining <= 0 {
                stop()
                playAlarm()
            }
        }
    }
}
