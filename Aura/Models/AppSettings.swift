import Foundation

struct AppSettings: Codable {
    var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

extension DataStore {
    enum SettingKey: String {
        // Widget defaults
        case defaultOpacity = "widget.defaultOpacity"
        case defaultBlur = "widget.defaultBlur"
        case defaultPin = "widget.defaultPin"

        // Notch
        case launchAtLogin = "launchAtLogin"
        case notchEnabled = "notch.enabled"
        case notchStyle = "notch.style"
        case notchHideDelay = "notch.hideDelay"
        case hoverExpandDelay = "notch.hoverExpandDelay"

        // Display Sizing
        case notchHeightOption = "display.notchHeight"
        case nonNotchDisplayHeight = "display.nonNotchDisplayHeight"
        case notchWidth = "display.notchWidth"
        case simulatedNotch = "display.simulatedNotch"
        case duoModeEnabled = "display.duoModeEnabled"
        case duoModeSplit = "display.duoModeSplit"

        // Material & Coloring
        case glassVariant = "appearance.glassVariant"
        case accentColor = "theme.accentColor"
        case borderColor = "appearance.borderColor"
        case borderWidth = "appearance.borderWidth"
        case glassmorphismEnabled = "theme.glassmorphismEnabled"
        case appearanceMode = "theme.appearanceMode"

        // Animations
        case simpleCloseAnim = "appearance.simpleCloseAnim"
        case disableOvershoot = "appearance.disableOvershoot"
        case windowShadow = "appearance.windowShadow"
        case cornerRadiusScaling = "appearance.cornerRadiusScaling"

        // Visibility
        case showTabs = "appearance.showTabs"
        case settingsIconInNotch = "appearance.settingsIconInNotch"
        case screenshotPrivacy = "appearance.screenshotPrivacy"

        // UI
        case dockVisible = "ui.dockVisible"
        case menuBarIconVisible = "ui.menuBarIconVisible"

        // General
        case extendHoverArea = "general.extendHoverArea"
        case enableHaptics = "general.enableHaptics"
        case openNotchOnHover = "general.openNotchOnHover"
        case rememberLastTab = "general.rememberLastTab"
        case lastActiveTab = "general.lastActiveTab"
        case enableGestures = "general.enableGestures"
        case mediaHorizontalGestures = "general.mediaHorizontalGestures"
        case closeGesture = "general.closeGesture"
        case gestureSensitivity = "general.gestureSensitivity"

        // Interactions
        case middleClickAction = "interactions.middleClickAction"

        // Integrations
        case spotifyEnabled = "integrations.spotify"
        case appleMusicEnabled = "integrations.appleMusic"

        // Media
        case musicSource = "media.musicSource"
        case showMediaControls = "media.showMediaControls"
        case liveActivityToggle1 = "media.liveActivityToggle1"
        case liveActivityToggle2 = "media.liveActivityToggle2"
        case liveActivityDefault = "media.liveActivityDefault"
        case liveActivityDuration = "media.liveActivityDuration"
        case hideInFullscreen = "media.hideInFullscreen"
        case showVisualizer = "media.showVisualizer"
        case skipIncrement = "media.skipIncrement"

        // Appearance media
        case coloredSpectrograms = "appearance.coloredSpectrograms"
        case playerTinting = "appearance.playerTinting"
        case blurBehindAlbum = "appearance.blurBehindAlbum"
        case sliderColorOption = "appearance.sliderColorOption"
        case useSpectrogram = "appearance.useSpectrogram"

        // Battery
        case showBatteryInNotch = "battery.showInNotch"
        case showBatteryPercentage = "battery.showPercentage"
        case showChargingIndicator = "battery.showChargingIndicator"
        case showTimeRemaining = "battery.showTimeRemaining"

        // Calendar
        case hideAllDayEvents = "calendar.hideAllDayEvents"
        case calendarTitleTruncation = "calendar.calendarTitleTruncation"

        // Pomodoro
        case pomodoroFocusDuration = "pomodoro.focusDuration"
        case pomodoroShortBreakDuration = "pomodoro.shortBreakDuration"
        case pomodoroLongBreakDuration = "pomodoro.longBreakDuration"
        case pomodoroCyclesBeforeLongBreak = "pomodoro.cyclesBeforeLongBreak"
        case timerAlertSoundID = "timer.alertSoundID"
        case timerAlertCustomPath = "timer.alertCustomPath"

        // Shelf (drop zone)
        case shelfEnabled = "shelf.enabled"
        case shelfAutoRemove = "shelf.autoRemoveOnDrag"

        // Clipboard
        case clipboardEnabled = "clipboard.enabled"
        case clipboardHistorySize = "clipboard.historySize"

        // Camera Mirror
        case cameraMirrorEnabled = "camera.mirrorEnabled"

        // System HUD
        case replaceSystemHUD = "system.replaceSystemHUD"

        // About
        case checkUpdatesAutomatically = "about.checkUpdatesAutomatically"
        case downloadBetaVersions = "about.downloadBetaVersions"
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
