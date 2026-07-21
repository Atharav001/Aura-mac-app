import SwiftUI
import UserNotifications
import AppKit

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
    /// Retained so AppKit never treats “zero windows” as a reason to exit a menu-bar app.
    private var keepAliveWindow: NSWindow?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar / notch app: stay alive without a dock icon unless the user opts in.
        let dockVisible = DataStore.shared.bool(for: .dockVisible, default: false)
        NSApp.setActivationPolicy(dockVisible ? .regular : .accessory)

        installKeepAliveWindow()

        _ = DataStore.shared
        _ = MenuBarManager.shared
        MenuBarIconFactory.applyApplicationIcon()
        // Boring Notch Dynamic Island (vendored from TheBoredTeam/boring.notch)
        BoringNotchHost.shared.setup()
        FocusManager.shared.setup()

        applyStoredAppearance()

        if dockVisible {
            MenuBarIconFactory.applyApplicationIcon()
        }

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

    /// Invisible retained window — closing Pomodoro/Stopwatch/etc. must not quit Aura.
    private func installKeepAliveWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .ignoresCycle, .canJoinAllSpaces]
        window.orderOut(nil)
        keepAliveWindow = window
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
