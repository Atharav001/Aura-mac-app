import SwiftUI
import UserNotifications

@main
struct AuraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
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
    }

    @MainActor
    @objc func handleStartPomodoro() {
        PanelManager.shared.spawnPanel(size: NSSize(width: 260, height: 320)) {
            WidgetContainer {
                PomodoroWidget(initialDuration: 25 * 60)
            }
        }
    }

    @MainActor
    @objc func handleStartDeepWork() {
        PanelManager.shared.spawnPanel(size: NSSize(width: 260, height: 320)) {
            WidgetContainer {
                PomodoroWidget(initialDuration: 50 * 60)
            }
        }
    }
}
