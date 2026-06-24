import SwiftUI
import UserNotifications

@main
struct AuraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = DataStore.shared
        _ = MenuBarManager.shared
        NotchManager.shared.setup()
        FocusManager.shared.setup()

        applyStoredAppearance()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartPomodoro),
            name: .startPomodoro,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartDeepWork),
            name: .startDeepWork,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePomodoroComplete),
            name: .pomodoroComplete,
            object: nil
        )
    }

    func applyStoredAppearance() {
        let mode = DataStore.shared.string(for: .appearanceMode) ?? "dark"
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }

    @MainActor
    @objc func handleStartPomodoro() {
        FocusManager.shared.startFocus()
        PanelManager.shared.spawnPanel(size: NSSize(width: 260, height: 360)) {
            WidgetContainer {
                PomodoroWidget(initialDuration: 25 * 60)
            }
        }
    }

    @MainActor
    @objc func handleStartDeepWork() {
        FocusManager.shared.startFocus()
        PanelManager.shared.spawnPanel(size: NSSize(width: 260, height: 360)) {
            WidgetContainer {
                PomodoroWidget(initialDuration: 50 * 60)
            }
        }
    }

    @objc func handlePomodoroComplete() {
        FocusManager.shared.viewModel.triggerCompletionWave()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            FocusManager.shared.stopFocus()
        }
    }
}
