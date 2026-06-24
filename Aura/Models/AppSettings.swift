import Foundation

struct AppSettings: Codable {
    var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

// Typed settings helpers
extension DataStore {
    enum SettingKey: String {
        case defaultOpacity = "widget.defaultOpacity"
        case defaultBlur = "widget.defaultBlur"
        case defaultPin = "widget.defaultPin"
        case notchStyle = "notch.style"
        case notchHideDelay = "notch.hideDelay"
        case pomodoroFocusDuration = "pomodoro.focusDuration"
        case pomodoroShortBreakDuration = "pomodoro.shortBreakDuration"
        case pomodoroLongBreakDuration = "pomodoro.longBreakDuration"
        case pomodoroCyclesBeforeLongBreak = "pomodoro.cyclesBeforeLongBreak"
        case accentColor = "theme.accentColor"
        case glassmorphismEnabled = "theme.glassmorphismEnabled"
        case appearanceMode = "theme.appearanceMode"
        case dockVisible = "ui.dockVisible"
        case menuBarIconVisible = "ui.menuBarIconVisible"
        case spotifyEnabled = "integrations.spotify"
        case appleMusicEnabled = "integrations.appleMusic"
    }

    func string(for key: SettingKey) -> String? {
        settings.first(where: { $0.key == key.rawValue })?.value
    }

    func double(for key: SettingKey, default defaultValue: Double = 0) -> Double {
        guard let str = string(for: key), let val = Double(str) else { return defaultValue }
        return val
    }

    func bool(for key: SettingKey, default defaultValue: Bool = false) -> Bool {
        guard let str = string(for: key) else { return defaultValue }
        return str == "true" || str == "1"
    }

    func set(key: SettingKey, value: String) {
        var current = settings
        if let index = current.firstIndex(where: { $0.key == key.rawValue }) {
            current[index].value = value
        } else {
            current.append(AppSettings(key: key.rawValue, value: value))
        }
        settings = current
        save()
    }

    func set(key: SettingKey, value: Double) {
        set(key: key, value: String(value))
    }

    func set(key: SettingKey, value: Bool) {
        set(key: key, value: value ? "true" : "false")
    }
}
