import Foundation
import Combine

@Observable
final class StopwatchViewModel {
    var elapsed: TimeInterval = 0
    var isRunning = false
    var laps: [TimeInterval] = []

    private var cancellable: AnyCancellable?
    private var startDate: Date?

    var formattedTime: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let centiseconds = Int((elapsed - floor(elapsed)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startDate = Date().addingTimeInterval(-elapsed)
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
    }

    func lap() {
        laps.append(elapsed)
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
        elapsed = Date().timeIntervalSince(startDate)
    }
}
