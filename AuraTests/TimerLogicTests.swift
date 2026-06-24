// Requires XCTest or Swift Testing framework (available with full Xcode).
// Run: swift test (requires Xcode)
// Manual verification:
//   - PomodoroViewModel initial state: state == .idle, timeRemaining == 25*60, progress == 0
//   - PomodoroViewModel progress: timeRemaining=75/total=100 → progress=0.25
//   - PomodoroViewModel formattedTime: 1500→"25:00", 61→"01:01", 0→"00:00"
//   - PomodoroViewModel reset: restores state to idle, resets timeRemaining
//   - PomodoroViewModel togglePause: running↔paused state toggling