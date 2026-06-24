import Foundation
import Combine
import UserNotifications

@Observable
final class PomodoroViewModel {
    enum State: Equatable {
        case idle, running, paused, finished
    }

    var state: State = .idle
    var timeRemaining: TimeInterval = 25 * 60
    var totalTime: TimeInterval = 25 * 60
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalTime)
    }

    private var cancellable: AnyCancellable?
    private var startDate: Date?

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(duration: TimeInterval = 25 * 60) {
        totalTime = duration
        timeRemaining = duration
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
        state = .idle
        timeRemaining = totalTime
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
            sendNotification()
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Complete"
        content.body = "Great job! Take a break."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
