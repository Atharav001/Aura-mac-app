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
        let focusMins = DataStore.shared.double(for: .pomodoroFocusDuration, default: 25)
        PanelManager.shared.spawnPanel(size: NSSize(width: 280, height: 400)) {
            WidgetContainer {
                PomodoroWidget(initialDuration: focusMins * 60)
            }
        }
    }

    @MainActor
    @objc func handleStartDeepWork() {
        FocusManager.shared.startFocus()
        PanelManager.shared.spawnPanel(size: NSSize(width: 280, height: 400)) {
            WidgetContainer {
                PomodoroWidget(initialDuration: 50 * 60)
            }
        }
    }

    @objc func handlePomodoroComplete() {
        // Soft celebration only — do not tear down focus during auto-loop
        FocusManager.shared.viewModel.triggerCompletionWave()
    }
}
